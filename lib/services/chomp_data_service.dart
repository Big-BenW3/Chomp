/// Data access service for reading app data from the backend.
///
/// This service provides methods to fetch repositories, scan history,
/// alerts, and feed items from the Chomp backend. All data is stored
/// in Neon Postgres and accessed via REST endpoints.
///
/// The client never opens a direct Postgres connection — mobile apps
/// and raw database drivers/credentials don't mix. All database
/// operations happen server-side.

library;

import '../models/repo.dart';
import '../models/scan_result.dart';
import '../models/alert.dart';
import '../models/feed_item.dart';
import '../models/commit_activity.dart';
import 'api_client.dart';

/// Service for reading app data via the backend API.
///
/// Wraps all GET endpoints that retrieve data from Neon. For write
/// operations (watch/unwatch), see [RepoNotifier] in the providers.
class ChompDataService {
  final _api = ApiClient.instance;

  /// Fetches all repositories for the current user.
  ///
  /// Returns repos with their watch status flags (auto/manual).
  /// Used to populate the home screen repo list.
  Future<List<Repo>> getRepos() async {
    final res = await _api.get('/repos') as Map<String, dynamic>;
    return (res['repos'] as List)
        .map((e) => Repo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches scan history for a specific repository.
  ///
  /// [limit] controls how many past scans to return (default: 30).
  /// Results are ordered by scan time, most recent first.
  Future<List<ScanResult>> getScanHistory(String repoId,
      {int limit = 30}) async {
    final res = await _api.get('/repos/$repoId/scans?limit=$limit')
        as Map<String, dynamic>;
    return (res['scans'] as List)
        .map((e) => ScanResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches the most recent scan result for a repository.
  ///
  /// Returns null if the repo has never been scanned.
  /// Used to display the latest scores on the repo detail screen.
  Future<ScanResult?> getLatestScan(String repoId) async {
    final history = await getScanHistory(repoId, limit: 1);
    return history.isEmpty ? null : history.first;
  }

  /// Fetches all alerts for a specific repository.
  ///
  /// Alerts are created when scans discover new findings or when
  /// security scores drop significantly.
  Future<List<ChompAlert>> getAlerts(String repoId) async {
    final res = await _api.get('/repos/$repoId/alerts') as Map<String, dynamic>;
    return (res['alerts'] as List)
        .map((e) => ChompAlert.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches the user's activity feed.
  ///
  /// [limit] controls how many items to return (default: 50).
  /// Currently only includes scan_complete items; other types
  /// require GitHub webhook integration.
  Future<List<FeedItem>> getFeed({int limit = 50}) async {
    final res = await _api.get('/feed?limit=$limit') as Map<String, dynamic>;
    return (res['items'] as List)
        .map((e) => FeedItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Adds a repository to the user's manual watchlist.
  ///
  /// The backend enforces the maximum watchlist size limit.
  Future<void> addToWatchlist(String repoId) =>
      _api.post('/repos/$repoId/watch', {});

  /// Removes a repository from the user's manual watchlist.
  Future<void> removeFromWatchlist(String repoId) =>
      _api.post('/repos/$repoId/unwatch', {});

  /// Fetches recent commit activity for a repository.
  ///
  /// [days] is the look-back window (1-90, default 30).
  Future<CommitActivity> getCommitActivity(String repoId, {int days = 30}) async {
    final res = await _api.get('/repos/$repoId/commits?days=$days')
        as Map<String, dynamic>;
    return CommitActivity.fromJson(res);
  }

  /// Marks an alert resolved.
  ///
  /// Returns the updated alert so callers can keep optimistic state in
  /// sync with the server.
  Future<ChompAlert> resolveAlert(String repoId, String alertId) async {
    final res =
        await _api.post('/repos/$repoId/alerts/$alertId/resolve', {})
            as Map<String, dynamic>;
    return ChompAlert.fromJson(res['alert'] as Map<String, dynamic>);
  }

  /// Re-opens a previously resolved alert.
  Future<ChompAlert> unresolveAlert(String repoId, String alertId) async {
    final res =
        await _api.post('/repos/$repoId/alerts/$alertId/unresolve', {})
            as Map<String, dynamic>;
    return ChompAlert.fromJson(res['alert'] as Map<String, dynamic>);
  }
}
