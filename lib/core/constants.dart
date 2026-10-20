/// Core application constants and API endpoint definitions.
///
/// One home for static values shared across the client: watchlist
/// limits (mirroring `server/lib/constants.js`) and every backend
/// route path the app talks to. Keep both halves in sync with the
/// server's route definitions in `server/routes/`.

library;

class AppConstants {
  /// Number of most recently active repos automatically added to watchlist.
  static const autoWatchCount = 3;

  /// Maximum number of repos a user can manually add to their watchlist.
  static const maxManualWatchlist = 4;

  /// Combined maximum watchlist size (auto + manual).
  static const maxWatchlistTotal = autoWatchCount + maxManualWatchlist;
}

/// Backend API endpoint paths.
///
/// These are appended to the base URL from `Env.apiBaseUrl` to form
/// complete request URLs. All endpoints are defined here to avoid
/// magic strings scattered across services.
class ApiEndpoints {
  /// Exchange GitHub OAuth code for a Chomp session token.
  static const githubOAuthExchange = '/github/oauth/exchange';

  /// Trigger a GitHub repo sync for the current user.
  static const githubSyncRepos = '/github/sync-repos';

  /// Start a manual scan for a specific repo (SSE stream).
  /// The actual route is `/scan/{repoId}`.
  static const scanRepo = '/scan';

  /// Register an FCM device token for push notifications.
  static const registerDevice = '/notifications/register-device';

  /// Fetch the current authenticated user's profile.
  static const me = '/me';
}

