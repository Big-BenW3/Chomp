/// User settings routes.
///
/// Server-enforced notification preferences. The client's toggles and
/// threshold slider used to be session-only state that nothing acted
/// on; these endpoints make them real and the scan pipeline reads
/// them on every run (see scanRepo.js).
///
/// - GET /settings - Current user's settings (defaults if none saved yet)
/// - PUT /settings - Upsert settings

import { Router } from 'express';
import { requireAuth } from '../middleware/auth.js';
import { asyncHandler } from '../middleware/asyncHandler.js';
import { query } from '../db.js';

export const settingsRouter = Router();

/// Defaults mirrored from the DB schema and client constants.
export const SETTINGS_DEFAULTS = Object.freeze({
  notify_enabled: true,
  notify_on_new_issue: true,
  notify_on_score_drop: true,
  alert_threshold: 10,
});

/// Clamp the threshold to the values the client offers (0-30), with a
/// little slack for future options. Non-numeric garbage falls back to 10.
function clampThreshold(value) {
  const n = Number(value);
  if (!Number.isFinite(n)) return SETTINGS_DEFAULTS.alert_threshold;
  return Math.min(50, Math.max(0, Math.round(n)));
}

settingsRouter.get('/settings', requireAuth, asyncHandler(async (req, res) => {
  const row = (await query('select * from user_settings where user_id = $1', [req.userId])).rows[0];
  res.json(row ?? { user_id: req.userId, ...SETTINGS_DEFAULTS, updated_at: null });
}));

settingsRouter.put('/settings', requireAuth, asyncHandler(async (req, res) => {
  const body = req.body ?? {};

  const notifyEnabled =
    typeof body.notify_enabled === 'boolean'
      ? body.notify_enabled
      : SETTINGS_DEFAULTS.notify_enabled;
  const notifyOnNewIssue =
    typeof body.notify_on_new_issue === 'boolean'
      ? body.notify_on_new_issue
      : SETTINGS_DEFAULTS.notify_on_new_issue;
  const notifyOnScoreDrop =
    typeof body.notify_on_score_drop === 'boolean'
      ? body.notify_on_score_drop
      : SETTINGS_DEFAULTS.notify_on_score_drop;
  const alertThreshold = clampThreshold(body.alert_threshold);

  const row = (
    await query(
      `insert into user_settings (user_id, notify_enabled, notify_on_new_issue, notify_on_score_drop, alert_threshold)
       values ($1, $2, $3, $4, $5)
       on conflict (user_id) do update set
         notify_enabled = excluded.notify_enabled,
         notify_on_new_issue = excluded.notify_on_new_issue,
         notify_on_score_drop = excluded.notify_on_score_drop,
         alert_threshold = excluded.alert_threshold,
         updated_at = now()
       returning *`,
      [req.userId, notifyEnabled, notifyOnNewIssue, notifyOnScoreDrop, alertThreshold],
    )
  ).rows[0];

  res.json(row);
}));
