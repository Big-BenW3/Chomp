/// Activity feed.
///
/// Chronological stream of scan completions (and later commits/PRs/
/// issues via webhooks). Pull-to-refresh re-runs the provider; first
/// load shows shimmer tiles, empty feed gets a guided empty state.

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/feed_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/feed_item_tile.dart';
import '../../widgets/reveal.dart';
import '../../widgets/skeleton.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: scheme.outline, height: 1),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(feedProvider.future),
        child: feed.when(
          loading: () => ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 20),
            itemCount: 6,
            itemBuilder: (context, index) => const FeedTileSkeleton(),
          ),
          error: (e, _) => EmptyState(
            icon: Icons.cloud_off_rounded,
            title: "Couldn't load the feed",
            subtitle: 'Check the connection and try again.',
            actionLabel: 'Retry',
            onAction: () => ref.refresh(feedProvider.future),
          ),
          data: (items) => items.isEmpty
              ? const EmptyState(
                  icon: Icons.bolt_rounded,
                  title: 'All quiet',
                  subtitle:
                      'The feed fills when Chomp scans your watched repos — new findings, score changes and activity land here.',
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: 20, bottom: 24),
                  itemCount: items.length,
                  itemBuilder: (context, index) => Reveal(
                    delayMs: (index * 45).clamp(0, 300).toDouble(),
                    child: FeedItemTile(item: items[index]),
                  ),
                ),
        ),
      ),
    );
  }
}
