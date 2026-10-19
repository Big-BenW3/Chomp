/// Server-side application constants.
///
/// Configuration values used throughout the backend. These mirror
/// the client-side AppConstants in lib/core/constants.dart but
/// include server-specific values like API keys and thresholds.

/// Maximum number of repos to auto-watch per user (top N most active).
export const AUTO_WATCH_COUNT = 3;

/// Maximum number of repos a user can manually add to their watchlist.
export const MAX_MANUAL_WATCHLIST = 4;

/// Security score drop threshold that triggers a notification.
/// If a repo's security score drops by this many points or more
/// between scans, the user receives a push notification.
export const SCORE_DROP_NOTIFY_THRESHOLD = 10;

/// Secrets/connection strings that MUST be present for the server to
/// run securely. Called once at startup; exits the process if any are
/// missing so misconfiguration can't silently weaken auth (e.g. an
/// undefined secret turning an `!==` guard into a no-op).
export function assertRequiredSecrets() {
  const required = [
    'NEON_DATABASE_URL',
    'SESSION_JWT_SECRET',
    'CRYPTO_SECRET',
    'CRON_SECRET',
    'GITHUB_WEBHOOK_SECRET',
    'GITHUB_CLIENT_ID',
    'GITHUB_CLIENT_SECRET',
    'NVIDIA_API_KEY',
    'GROQ_API_KEY',
    'FIREBASE_SERVICE_ACCOUNT_JSON',
  ];
  const missing = required.filter((key) => !process.env[key]);
  if (missing.length > 0) {
    console.error(
      `Missing required environment variables: ${missing.join(', ')}. ` +
        'Refusing to start.'
    );
    process.exit(1);
  }
}