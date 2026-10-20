/// Hourly scan batch runner.
///
/// Scans all watched repositories (auto + manual) on a schedule.
/// This is the "set it and forget it" engine that keeps the user's
/// watchlist up to date without manual intervention.
///
/// Can be run two ways:
/// 1. As a standalone cron process (node-cron) - see cron/standalone.js
/// 2. Via HTTP trigger - see routes/internalCron.js

import { query } from '../db.js';
import { decryptToken } from './crypto.js';
import { scanRepo, isScanRunning } from './scanRepo.js';

/// Runs a full scan of all watched repositories.
///
/// Queries the database for all repos that are either auto-watched
/// or manually watched, then runs a full scan on each one.
///
/// @returns {Promise<Object>} Results summary with scanned/failed counts
export async function runHourlyScan() {
  console.log(`[${new Date().toISOString()}] Starting hourly scan...`);
  const watched = await query(
    `select r.*, u.access_token_encrypted from repos r
     join users u on u.id = r.user_id
     where r.is_auto_watched = true or r.is_manually_watched = true`,
  );

  const results = { scanned: 0, failed: 0, skipped: 0 };
  for (const repoRow of watched.rows) {
    // A repo already being scanned by a manual request (or vice versa)
    // is skipped, not failed — the earlier scan's output covers it.
    if (isScanRunning(repoRow.id)) {
      results.skipped += 1;
      continue;
    }
    try {
      const accessToken = decryptToken(repoRow.access_token_encrypted);
      await scanRepo(repoRow, accessToken);
      results.scanned += 1;
    } catch (err) {
      console.error(`Failed to scan ${repoRow.full_name}`, err);
      results.failed += 1; // one bad repo shouldn't block the batch
    }
  }
  console.log(`[${new Date().toISOString()}] Hourly scan complete.`, results);
  return results;
}