import { Router } from 'express';
import crypto from 'crypto';
import { query } from '../db.js';

const router = Router();
const WEBHOOK_SECRET = process.env.GITHUB_WEBHOOK_SECRET;

/// GitHub webhook receiver.
///
/// Ingests repository events GitHub POSTs to this endpoint and fans
/// them out as feed items for every user who watches the repo:
/// - `push`         → commit feed item
/// - `pull_request` → pr feed item (opened/closed/merged/…)
/// - `issues`       → issue feed item (opened/closed/…, PR-linked
///   issues are skipped — they already arrived as pull_request events)
///
/// Security: verifies GitHub's HMAC-SHA256 signature over the raw
/// request body before touching the DB. Handler failures are caught
/// so a bad payload can't crash the server (Express 4 doesn't catch
/// async rejections).

/// Constant-time comparison to avoid timing attacks on the signature.
function safeEqual(a, b) {
  const bufA = Buffer.from(a ?? '');
  const bufB = Buffer.from(b ?? '');
  if (bufA.length !== bufB.length) return false;
  return crypto.timingSafeEqual(bufA, bufB);
}

router.post('/github/webhook', async (req, res) => {
  if (!WEBHOOK_SECRET) {
    console.error('GITHUB_WEBHOOK_SECRET is not set; refusing webhook.');
    return res.status(500).send('Server misconfiguration');
  }

  // `req.body` is a Buffer here because index.js applies the raw body
  // parser for this route. Verifying the HMAC over the raw bytes is what
  // GitHub expects — re-serializing loses the exact byte sequence.
  const signature = req.headers['x-hub-signature-256'];
  const rawBody = req.body;
  if (!Buffer.isBuffer(rawBody)) {
    return res.status(400).send('Expected raw body');
  }

  const hmac = crypto.createHmac('sha256', WEBHOOK_SECRET);
  const digest = 'sha256=' + hmac.update(rawBody).digest('hex');

  if (!safeEqual(signature, digest)) return res.status(401).send('Invalid signature');

  let payload;
  try {
    payload = JSON.parse(rawBody.toString('utf8'));
  } catch {
    return res.status(400).send('Invalid JSON');
  }

  const event = req.headers['x-github-event'];
  const repoFullName = payload.repository?.full_name;

  if (!repoFullName) return res.status(200).send('OK');

  try {
    const repos = await query(
      'SELECT id, user_id FROM repos WHERE full_name = $1 AND (is_auto_watched = true OR is_manually_watched = true)',
      [repoFullName]
    );

    if (repos.rows.length !== 0) {
      switch (event) {
        case 'push':
          const headCommit = payload.head_commit;
          for (const row of repos.rows) {
            await query(
              `INSERT INTO feed_items (user_id, repo_id, type, title, github_url)
               VALUES ($1, $2, 'commit', $3, $4)`,
              [row.user_id, row.id, headCommit?.message || 'New push', headCommit?.url]
            );
          }
          break;
        case 'pull_request':
          const pr = payload.pull_request;
          if (pr) {
            const action = payload.action ?? 'updated';
            for (const row of repos.rows) {
              await query(
                `INSERT INTO feed_items (user_id, repo_id, type, title, github_url)
                 VALUES ($1, $2, 'pr', $3, $4)`,
                [
                  row.user_id,
                  row.id,
                  action === 'opened' ? `New pull request: ${pr.title}` : `Pull request ${action}: ${pr.title}`,
                  pr.html_url,
                ]
              );
            }
          }
          break;
        case 'issues':
          const issue = payload.issue;
          if (issue && !issue.pull_request) {
            const action = payload.action ?? 'updated';
            for (const row of repos.rows) {
              await query(
                `INSERT INTO feed_items (user_id, repo_id, type, title, github_url)
                 VALUES ($1, $2, 'issue', $3, $4)`,
                [
                  row.user_id,
                  row.id,
                  action === 'opened' ? `New issue: ${issue.title}` : `Issue ${action}: ${issue.title}`,
                  issue.html_url,
                ]
              );
            }
          }
          break;
      }
    }
  } catch (err) {
    // Express 4 does not catch async rejections — without this try/catch a
    // failed DB query inside an unhandled promise would crash the process.
    console.error('webhook handler failed', err);
    return res.status(500).send('Server error');
  }

  res.status(200).send('OK');
});

export { router as webhookRouter };