/// Repository routes.
///
/// Handles repository synchronization and watchlist management:
/// - POST /github/sync-repos - Sync repos from GitHub
/// - GET /repos - List all repos for the user
/// - POST /repos/:id/watch - Add repo to watchlist
/// - POST /repos/:id/unwatch - Remove repo from watchlist
/// - GET /repos/:id/scans - Get scan history for a repo
/// - GET /repos/:id/alerts - Get alerts for a repo

import { Router } from 'express';
import { requireAuth } from '../middleware/auth.js';
import { asyncHandler } from '../middleware/asyncHandler.js';
import { query } from '../db.js';
import { decryptToken } from '../lib/crypto.js';
import { fetchRepos, fetchCommits } from '../lib/githubClient.js';
import { AUTO_WATCH_COUNT, MAX_MANUAL_WATCHLIST } from '../lib/constants.js';

export const reposRouter = Router();

/// Sync repositories from GitHub.
///
/// Fetches the user's repos from GitHub, upserts them into the database,
/// and sets auto-watch flags for the top N most recently active repos.
///
/// @route POST /github/sync-repos
/// @returns {Object} Updated repo list
reposRouter.post('/github/sync-repos', requireAuth, async (req, res) => {
  try {
    const userRow = (await query('select * from users where id = $1', [req.userId])).rows[0];
    const accessToken = decryptToken(userRow.access_token_encrypted);
    const githubRepos = await fetchRepos(accessToken);

    // Sort by last push date and mark top N as auto-watched
    const sorted = [...githubRepos].sort((a, b) => new Date(b.pushed_at) - new Date(a.pushed_at));
    const autoWatchedIds = new Set(sorted.slice(0, AUTO_WATCH_COUNT).map((r) => r.id));

    // Upsert each repo into database
    for (const repo of githubRepos) {
      await query(
        `insert into repos (user_id, github_repo_id, name, full_name, description, language, default_branch, is_auto_watched, last_pushed_at)
         values ($1,$2,$3,$4,$5,$6,$7,$8,$9)
         on conflict (user_id, github_repo_id) do update set
           name = excluded.name,
           full_name = excluded.full_name,
           description = excluded.description,
           language = excluded.language,
           default_branch = excluded.default_branch,
           is_auto_watched = excluded.is_auto_watched,
           last_pushed_at = excluded.last_pushed_at`,
        [
          req.userId,
          repo.id,
          repo.name,
          repo.full_name,
          repo.description,
          repo.language,
          repo.default_branch,
          autoWatchedIds.has(repo.id),
          repo.pushed_at,
        ],
      );
    }

    const result = await query('select * from repos where user_id = $1 order by last_pushed_at desc', [
      req.userId,
    ]);
    res.json({ repos: result.rows.map(toRepoJson) });
  } catch (err) {
    console.error('sync-repos failed', err);
    res.status(500).json({ error: 'Failed to sync repos from GitHub' });
  }
});

/// List all repositories for the authenticated user.
///
/// @route GET /repos
/// @returns {Object} List of repos with watch status
reposRouter.get('/repos', requireAuth, asyncHandler(async (req, res) => {
  const result = await query('select * from repos where user_id = $1 order by last_pushed_at desc', [
    req.userId,
  ]);
  res.json({ repos: result.rows.map(toRepoJson) });
}));

/// Add a repository to the manual watchlist.
///
/// Enforces the maximum manual watchlist size limit.
///
/// @route POST /repos/:id/watch
/// @returns {Object} Success status
reposRouter.post('/repos/:id/watch', requireAuth, asyncHandler(async (req, res) => {
  const countRow = await query(
    'select count(*) from repos where user_id = $1 and is_manually_watched = true',
    [req.userId],
  );
  if (Number(countRow.rows[0].count) >= MAX_MANUAL_WATCHLIST) {
    return res.status(400).json({ error: `Watchlist is full (${MAX_MANUAL_WATCHLIST} max)` });
  }
  await query('update repos set is_manually_watched = true where id = $1 and user_id = $2', [
    req.params.id,
    req.userId,
  ]);
  res.json({ ok: true });
}));

/// Remove a repository from the manual watchlist.
///
/// @route POST /repos/:id/unwatch
/// @returns {Object} Success status
reposRouter.post('/repos/:id/unwatch', requireAuth, asyncHandler(async (req, res) => {
  await query('update repos set is_manually_watched = false where id = $1 and user_id = $2', [
    req.params.id,
    req.userId,
  ]);
  res.json({ ok: true });
}));

/// Get scan history for a repository.
///
/// @route GET /repos/:id/scans
/// @param {number} limit - Max number of scans to return (default: 30)
/// @returns {Object} List of scan results
reposRouter.get('/repos/:id/scans', requireAuth, asyncHandler(async (req, res) => {
  const limit = Number(req.query.limit ?? 30);
  if (!Number.isFinite(limit) || limit <= 0) {
    return res.status(400).json({ error: 'Invalid limit' });
  }
  // Join through repos so the query is scoped to the caller: scan_results
  // has no user_id of its own, so without this filter any authenticated
  // user who learned another user's repo id could read their scan history.
  const result = await query(
    `select s.* from scan_results s
       join repos r on r.id = s.repo_id
      where s.repo_id = $1 and r.user_id = $2
      order by s.scanned_at desc limit $3`,
    [req.params.id, req.userId, limit],
  );
  res.json({ scans: result.rows });
}));

/// Get alerts for a repository.
///
/// @route GET /repos/:id/alerts
/// @returns {Object} List of alerts
reposRouter.get('/repos/:id/alerts', requireAuth, asyncHandler(async (req, res) => {
  // Scope through repos so alerts belong to the caller (see /scans).
  const result = await query(
    `select a.* from alerts a
       join repos r on r.id = a.repo_id
      where a.repo_id = $1 and r.user_id = $2
      order by a.created_at desc`,
    [req.params.id, req.userId],
  );
  res.json({ alerts: result.rows });
}));

/// Mark an alert resolved.
///
/// @route POST /repos/:id/alerts/:alertId/resolve
/// @returns {Object} The updated alert
reposRouter.post('/repos/:id/alerts/:alertId/resolve', requireAuth, asyncHandler(async (req, res) => {
  const result = await query(
    `update alerts a set resolved = true, resolved_at = now()
        from repos r
       where a.id = $1 and a.repo_id = r.id and r.id = $2 and r.user_id = $3
       returning a.*`,
    [req.params.alertId, req.params.id, req.userId],
  );
  if (result.rows.length === 0) return res.status(404).json({ error: 'Alert not found' });
  res.json({ alert: result.rows[0] });
}));

/// Re-open an alert (unresolve).
///
/// @route POST /repos/:id/alerts/:alertId/unresolve
/// @returns {Object} The updated alert
reposRouter.post('/repos/:id/alerts/:alertId/unresolve', requireAuth, asyncHandler(async (req, res) => {
  const result = await query(
    `update alerts a set resolved = false, resolved_at = null
        from repos r
       where a.id = $1 and a.repo_id = r.id and r.id = $2 and r.user_id = $3
       returning a.*`,
    [req.params.alertId, req.params.id, req.userId],
  );
  if (result.rows.length === 0) return res.status(404).json({ error: 'Alert not found' });
  res.json({ alert: result.rows[0] });
}));

/// Get recent commit activity for a repository.
///
/// Returns one bucket per day with a commit count — ready for the
/// client heatmap. Bucketing happens server-side so the payload stays
/// small and any future client can trust a stable shape.
///
/// @route GET /repos/:id/commits?days=30
/// @returns {Object} { activity: [{date: 'YYYY-MM-DD', count}], total }
reposRouter.get('/repos/:id/commits', requireAuth, asyncHandler(async (req, res) => {
  const days = Number(req.query.days ?? 30);
  if (!Number.isFinite(days) || days <= 0 || days > 90) {
    return res.status(400).json({ error: 'Invalid days (1-90)' });
  }
  // Verify ownership before touching GitHub.
  const repoRow = (
    await query('select * from repos where id = $1 and user_id = $2', [req.params.id, req.userId])
  ).rows[0];
  if (!repoRow) return res.status(404).json({ error: 'Repo not found' });

  const userRow = await query('select access_token_encrypted from users where id = $1', [req.userId]);
  if (userRow.rows.length === 0) return res.status(401).json({ error: 'Unauthorized' });
  const accessToken = decryptToken(userRow.rows[0].access_token_encrypted);

  const commits = await fetchCommits(accessToken, repoRow.full_name, { days });

  // Bucket by local commit date. Cap each day's displayed count at a
  // sane max so a single huge day doesn't blow the heatmap scale.
  const MAX_PER_DAY = 30;
  const byDay = new Map();
  let total = 0;
  for (const c of commits) {
    const date = (c?.commit?.committer?.date ?? c?.commit?.author?.date ?? '')?.slice(0, 10);
    if (!date) continue;
    byDay.set(date, Math.min((byDay.get(date) ?? 0) + 1, MAX_PER_DAY));
    total += 1;
  }
  const activity = [...byDay.entries()]
    .map(([date, count]) => ({ date, count }))
    .sort((a, b) => (a.date < b.date ? -1 : 1));

  res.json({ activity, total });
}));

/// Converts a database row to a JSON-serializable repo object.
function toRepoJson(row) {
  return {
    id: row.id,
    github_repo_id: Number(row.github_repo_id),
    name: row.name,
    full_name: row.full_name,
    description: row.description,
    language: row.language,
    default_branch: row.default_branch,
    is_auto_watched: row.is_auto_watched,
    is_manually_watched: row.is_manually_watched,
    last_pushed_at: row.last_pushed_at,
  };
}