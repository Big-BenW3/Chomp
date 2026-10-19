/// Firebase Cloud Messaging service.
///
/// Handles sending push notifications to user devices via Firebase.
/// Used to alert users when:
/// - New scan findings are discovered
/// - Security scores drop significantly
///
/// Requires Firebase Admin SDK initialization with a service account.

import admin from 'firebase-admin';
import { query } from '../db.js';

let initialised = false;

/// Initializes Firebase Admin SDK if not already initialized.
///
/// Reads the service account credentials from the FIREBASE_SERVICE_ACCOUNT_JSON
/// environment variable (JSON string).
function ensureInit() {
  if (initialised) return;
  admin.initializeApp({
    credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON)),
  });
  initialised = true;
}

/// Identifies errors that mean the token is dead: the app was
/// uninstalled, signed out, or FCM expired the registration. Stale
/// tokens used to accumulate forever and error on every send.
function isDeadToken(err) {
  const code = err?.code ?? err?.errorInfo?.code ?? '';
  return (
    typeof code === 'string' &&
    (code.includes('registration-token-not-registered') ||
      code.includes('invalid-argument') ||
      code.includes('unregistered'))
  );
}

/// Sends a push notification to a device.
///
/// Kills the device_tokens row when FCM reports the token is dead so
/// future notification fan-outs stop wasting attempts on it.
///
/// @param {string} token - FCM device token
/// @param {string} title - Notification title
/// @param {string} body - Notification body text
export async function sendPush(token, title, body) {
  ensureInit();
  try {
    await admin.messaging().send({ token, notification: { title, body } });
  } catch (err) {
    if (isDeadToken(err)) {
      await query('delete from device_tokens where fcm_token = $1', [token]).catch(() => {});
      return;
    }
    // Other failures (rate limits, transient) — keep the token, drop the send.
    console.error('FCM send failed', err);
  }
}