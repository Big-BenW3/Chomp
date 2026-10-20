/// Repository scan orchestrator.
///
/// Coordinates the full scan pipeline for a single repository:
/// 1. Fetch repo data from GitHub (README, file tree, commits)
/// 2. Pick sample files for AI analysis
/// 3. Run NVIDIA for code quality + security scores
/// 4. Run Groq for documentation + test ratings
/// 5. Store results in Neon database
/// 6. Create alerts for new findings
/// 7. Send push notifications if needed
///
/// This is the heart of the Chomp app - where all the AI magic happens.

import { query } from '../db.js';
import { fetchReadme, fetchRepoTree, fetchFileContent } from './githubClient.js';
import { analyseCodeAndSecurity } from './nvidiaClient.js';
import { evaluateDocsAndTests } from './groqClient.js';
import { sendPush } from './fcm.js';

/// Defaults matching user_settings columns; used when the user has
/// never saved settings.
const SETTINGS_DEFAULTS = Object.freeze({
  notify_enabled: true,
  notify_on_new_issue: true,
  notify_on_score_drop: true,
  alert_threshold: 10,
});

/// Repos with a scan currently running. Guards against the hourly cron
/// racing a manual stream — two scanners on the same repo would both
/// diff against the same "previous" row and produce duplicate alerts.
const activeScans = new Set();

/// True when a scan for this repo row is already running.
export function isScanRunning(repoId) {
  return activeScans.has(repoId);
}

/// Normalizes a finding string for comparison. LLMs reword, re-capitalize
/// and re-punctuate findings between runs; exact matching treated every
/// rephrase as a brand-new alert and spammed pushes. Normalizing makes
/// "Row stored unencrypted" ↔ "row stored unencrypted." dedupe.
function normalizeFinding(finding) {
  return String(finding).toLowerCase().replaceAll(/[^\p{L}\p{N}]+/gu, '');
}

/**
 * Runs a full scan for one repo. `onPhase(phase, message, payload?)` is
 * called at each step — the SSE route uses it to stream live updates
 * to the phone; the hourly cron job ignores it (default no-op).
 *
 * Throws an error with `code === 'SCAN_IN_PROGRESS'` if another scan
 * of the same repo is already underway.
 *
 * @param {Object} repoRow - Repository database row
 * @param {string} accessToken - GitHub access token
 * @param {Function} onPhase - Callback for scan phase updates
 * @returns {Promise<Object>} Inserted scan result row
 */
export async function scanRepo(repoRow, accessToken, onPhase = () => {}) {
  if (activeScans.has(repoRow.id)) {
    const err = new Error('Scan already in progress for this repository');
    err.code = 'SCAN_IN_PROGRESS';
    throw err;
  }
  activeScans.add(repoRow.id);
  try {
    return await runScan(repoRow, accessToken, onPhase);
  } finally {
    activeScans.delete(repoRow.id);
  }
}

async function runScan(repoRow, accessToken, onPhase) {
  onPhase('fetching', `Fetching ${repoRow.full_name} from GitHub...`);
  const [readme, fileTree] = await Promise.all([
    fetchReadme(accessToken, repoRow.full_name),
    fetchRepoTree(accessToken, repoRow.full_name, repoRow.default_branch),
  ]);
  onPhase('ingesting', `Ingesting ${fileTree.length} files...`);
  const sampleFiles = await pickSampleFiles(accessToken, repoRow.full_name, fileTree);

  onPhase('analysing', 'Analysing repository structure...');
  onPhase('code_review', 'Running code review (NVIDIA)...');
  onPhase('security_check', 'Running security check (NVIDIA)...');
  const nvidiaResult = await analyseCodeAndSecurity({
    fullName: repoRow.full_name,
    fileTree: fileTree.map((f) => f.path),
    sampleFiles,
  });

  onPhase('docs_eval', 'Evaluating documentation (Groq)...');
  const groqResult = await evaluateDocsAndTests({
    fullName: repoRow.full_name,
    readme,
    fileTree,
  });
  onPhase('tests_eval', 'Evaluating test coverage (Groq)...');

  const findings = [
    ...(nvidiaResult.security_findings ?? []),
    ...(nvidiaResult.code_quality_findings ?? []),
  ];

  const [previous, userSettings] = await Promise.all([
    query('select * from scan_results where repo_id = $1 order by scanned_at desc limit 1', [
      repoRow.id,
    ]),
    // Settings are best-effort: an unmigrated database missing the
    // user_settings table must not take the whole pipeline down, so
    // failures here collapse to the defaults below.
    query('select * from user_settings where user_id = $1', [repoRow.user_id]).catch(() => ({ rows: [] })),
  ]);
  const settings = userSettings.rows[0] ?? SETTINGS_DEFAULTS;

  const inserted = (
    await query(
      `insert into scan_results (repo_id, security_score, code_quality_score, docs_rating, docs_reasoning, tests_rating, tests_reasoning, findings)
       values ($1,$2,$3,$4,$5,$6,$7,$8) returning *`,
      [
        repoRow.id,
        nvidiaResult.security_score,
        nvidiaResult.code_quality_score,
        groqResult.docs_rating,
        groqResult.docs_reasoning,
        groqResult.tests_rating,
        groqResult.tests_reasoning,
        JSON.stringify(findings),
      ],
    )
  ).rows[0];

  await query(
    `insert into feed_items (user_id, repo_id, type, title, github_url) values ($1,$2,'scan_complete',$3,$4)`,
    [repoRow.user_id, repoRow.id, `Scan complete — Security ${nvidiaResult.security_score ?? '—'}`, null],
  );

  await maybeCreateAlertsAndNotify(repoRow, previous.rows[0], inserted, findings, settings);

  onPhase('complete', `Done — ${findings.length} findings`, inserted);
  return inserted;
}

/**
 * Creates alerts for new findings and sends push notifications.
 *
 * Honors the user's server-backed settings. Findings are compared
 * against the previous scan after normalization, so an LLM rewording
 * a finding doesn't re-open the same alert and spam the user.
 *
 * @param {Object} repoRow - Repository database row
 * @param {Object} previous - Previous scan result (if any)
 * @param {Object} current - Current scan result
 * @param {Array} findings - List of findings from current scan
 * @param {Object} settings - User's user_settings row (or defaults)
 */
async function maybeCreateAlertsAndNotify(repoRow, previous, current, findings, settings) {
  const threshold = settings.alert_threshold ?? SETTINGS_DEFAULTS.alert_threshold;

  // Normalize new + previous findings, keeping each original so the
  // alert text stays the model's wording.
  const previousSet = new Set((previous?.findings ?? []).map(normalizeFinding));
  const seen = new Set();
  const newFindings = [];
  for (const finding of findings) {
    const key = normalizeFinding(finding);
    if (previousSet.has(key) || seen.has(key)) continue;
    seen.add(key);
    newFindings.push(finding);
  }

  const scoreDrop = (previous?.security_score ?? 0) - (current.security_score ?? 0);
  const scoreDropped =
    previous?.security_score != null &&
    current.security_score != null &&
    scoreDrop >= threshold && scoreDrop > 0;

  if (newFindings.length === 0 && !scoreDropped) return; // silent scan — nothing worth telling the user

  for (const finding of newFindings) {
    await query(
      `insert into alerts (repo_id, scan_result_id, message, severity) values ($1,$2,$3,$4)`,
      [repoRow.id, current.id, finding, 'warning'],
    );
  }

  // Pushes only fire if the user wants them. Alerts are still recorded
  // silently so the app surfaces them next session.
  if (settings.notify_enabled === false) return;

  const wantsNotify =
    (newFindings.length > 0 && settings.notify_on_new_issue !== false) || 
    (scoreDropped && settings.notify_on_score_drop !== false);
  if (!wantsNotify) return;

  const devices = await query('select fcm_token from device_tokens where user_id = $1', [
    repoRow.user_id,
  ]);
  const message = scoreDropped
    ? `${repoRow.name}: security score dropped to ${current.security_score}`
    : `${repoRow.name}: ${newFindings.length} new finding(s)`;

  for (const { fcm_token } of devices.rows) {
    await sendPush(fcm_token, repoRow.name, message);
  }
}

/**
 * Picks a small sample of files for AI analysis.
 *
 * Deliberately limited to avoid exceeding AI model context limits
 * and to keep API costs low. Prioritizes common code file types.
 *
 * @param {string} accessToken - GitHub access token
 * @param {string} fullName - Repository full name
 * @param {Array} fileTree - Complete file tree
 * @returns {Promise<Array>} Array of {path, content} objects
 */
async function pickSampleFiles(accessToken, fullName, fileTree) {
  // Deliberately small and cheap — full repos can blow past model
  // context limits and the free-tier rate limits on NVIDIA/Groq. Grab
  // a handful of the most relevant files rather than everything.
  const candidates = fileTree
    .filter((f) => f.type === 'blob')
    .filter((f) => /\.(dart|js|ts|py|go|rs|java|kt|swift|json|yaml|yml|toml)$/.test(f.path))
    .slice(0, 8);

  const files = [];
  for (const c of candidates) {
    const content = await fetchFileContent(accessToken, fullName, c.path);
    if (content != null) files.push({ path: c.path, content });
  }
  return files;
}