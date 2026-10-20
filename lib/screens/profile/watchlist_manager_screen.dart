/// Watchlist manager.
///
/// Three sections: auto-watched (magenta, not toggleable), manually
/// watched (removable), and everything else (addable). The manual
/// section shows a guided empty state when empty; the count lives in
/// the app bar.

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/repo.dart';
import '../../providers/repo_provider.dart';
import '../../widgets/reveal.dart';

class WatchlistManagerScreen extends ConsumerWidget {
  const WatchlistManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repoState = ref.watch(repoProvider);

    // Load repos from cache if not already loaded.
    if (repoState.repos.isEmpty && !repoState.isLoading) {
      ref.read(repoProvider.notifier).loadFromCache();
    }
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final notifier = ref.read(repoProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Watchlist (${repoState.watchlistCount}/${AppConstants.maxWatchlistTotal})'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (repoState.autoWatched.isNotEmpty) ...[
            const _SectionHeader('AUTO-WATCHED',
                'Top ${AppConstants.autoWatchCount} most active'),
            ...repoState.autoWatched.map(
              (r) => Reveal(child: _RepoRow(repo: r, removable: false)),
            ),
            const SizedBox(height: 20),
          ],
          const _SectionHeader(
              'MANUALLY WATCHED', '${AppConstants.maxManualWatchlist} max'),
          if (repoState.manuallyWatched.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.card),
                color: tokens.surface,
                border: Border.all(color: scheme.outline),
              ),
              child: Column(
                children: [
                  const Icon(Icons.bookmark_add_outlined,
                      color: AppColors.brand, size: 26),
                  const SizedBox(height: 8),
                  Text('Nothing watched manually yet',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Add repos below — Chomp will keep an eye on them hourly.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                  ),
                ],
              ),
            )
          else
            ...repoState.manuallyWatched.map(
              (r) => Reveal(
                  child: _RepoRow(
                      repo: r,
                      removable: true,
                      onRemove: () => notifier.toggleWatch(r))),
            ),
          const SizedBox(height: 20),
          const _SectionHeader('OTHER REPOS', 'tap to watch'),
          if (repoState.unwatched.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Every repo is being watched. Nice.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
              ),
            )
          else
            ...repoState.unwatched.map(
              (r) => Reveal(
                  child: _RepoRow(
                      repo: r,
                      removable: false,
                      onAdd: () => notifier.toggleWatch(r))),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              subtitle,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.3),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RepoRow extends StatelessWidget {
  const _RepoRow(
      {required this.repo, required this.removable, this.onRemove, this.onAdd});

  final Repo repo;
  final bool removable;
  final VoidCallback? onRemove;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.shell),
        border: Border.all(color: scheme.outline),
        color: tokens.surfaceHigh.withValues(alpha: 0.5),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          color: tokens.surface,
        ),
        child: Row(
          children: [
            Icon(
              Icons.bolt_rounded,
              size: 18,
              color: removable ? AppColors.danger : AppColors.brand,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                repo.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (repo.isAutoWatched)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  'AUTO',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            if (removable)
              IconButton(
                tooltip: 'Remove from watchlist',
                icon: Icon(Icons.remove_circle_outline_rounded,
                    color: AppColors.danger.withValues(alpha: 0.8)),
                onPressed: onRemove,
              )
            else if (onAdd != null)
              IconButton(
                tooltip: 'Add to watchlist',
                icon: const Icon(Icons.add_circle_outline_rounded,
                    color: AppColors.brand),
                onPressed: onAdd,
              ),
          ],
        ),
      ),
    );
  }
}
