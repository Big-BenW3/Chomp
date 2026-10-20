/// Feed state management using Riverpod.
///
/// Provides the user's activity feed as a [FutureProvider] backed by
/// `GET /feed`. The feed mixes server-generated scan completions with
/// GitHub webhook events (commits, PRs, issues) that the backend fans
/// out to every user watching the repo.
///
/// Auto-disposed when the feed screen is not visible.

library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/feed_item.dart';
import 'repo_provider.dart';

/// Provider for the user's activity feed.
///
/// Automatically fetches feed items from the backend when watched.
/// Uses [FutureProvider.autoDispose] to cancel requests when the
/// feed screen is not visible.
final feedProvider = FutureProvider.autoDispose<List<FeedItem>>((ref) async {
  final data = ref.watch(chompDataServiceProvider);
  return data.getFeed();
});
