/// Scan routes.
///
/// Handles manual scan triggers via Server-Sent Events (SSE):
/// - POST /scan/:repoId - Start a manual scan with live progress

import { Router } from 'express';
import { requireAuth } from '../middleware/auth.js';
import { query } from '../db.js';
import { decryptToken } from '../lib/crypto.js';
import { scanRepo } from '../lib/scanRepo.js';

export const scanRouter = Router();

/// Start a manual scan for a repository.
///
/// Opens an SSE connection and streams phase updates as the scan
/// progresses through fetching, analysis, and storage. A 15s comment
/// heartbeat keeps Render's proxy from timing out long AI calls.
///
/// @route POST /scan/:repoId
/// @returns {Stream} SSE stream of scan phase events
scanRouter.post('/scan/:repoId', requireAuth, async (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders?.();

  const send = (phase, message, payload) => {
    res.write(`event: ${phase}\n`);
    res.write(`data: ${JSON.stringify({ phase, message, ...(payload ? { result: payload } : {}) })}\n\n`);
  };

  // SSE comment lines are ignored by EventSource clients but reset
  // intermediary proxies' idle timers. AI calls can take minutes.
  const heartbeat = setInterval(() => {
    try {
      res.write(': ping\n\n');
    } catch {
      // response already dead — the scan still completes and writes to DB
    }
  }, 15_000);

  try {
    const repoRow = (
      await query('select * from repos where id = $1 and user_id = $2', [req.params.repoId, req.userId])
    ).rows[0];
    if (!repoRow) {
      send('error', 'Repo not found');
      return res.end();
    }

    const userRow = (await query('select * from users where id = $1', [req.userId])).rows[0];
    const accessToken = decryptToken(userRow.access_token_encrypted);

    try {
      await scanRepo(repoRow, accessToken, send);
      res.end();
    } catch (err) {
      if (err.code === 'SCAN_IN_PROGRESS') {
        send('error', err.message);
      } else {
        // Sanitized on purpose: raw err.message can carry upstream AI
        // API response bodies which must not reach the client.
        console.error('Manual scan failed', err);
        send('error', 'Scan failed — try again shortly.');
      }
      res.end();
    }
  } catch (err) {
    // Auth/DB-layer failures before the scan even started.
    console.error('Manual scan setup failed', err);
    send('error', 'Scan failed — try again shortly.');
    res.end();
  } finally {
    clearInterval(heartbeat);
  }
});