/// Commit activity card.
///
/// Real GitHub commit data bucketed by day, rendered as the brand's
/// activity strip: each bar's height and saturation carries the day's
/// commit count. Loading renders the designed skeleton; a repo with
/// zero recent commits gets a guided empty state instead of fake data.

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/commit_activity.dart';
import 'chomp_card.dart';

class HeatmapStrip extends StatelessWidget {
  const HeatmapStrip({super.key, required this.activity});

  /// Commit buckets for the look-back window. Null while loading.
  final AsyncActivity activity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ChompCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'COMMIT ACTIVITY',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.45),
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              Text(
                'LAST 30 DAYS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.3),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          activity.when(
            loading: () => const _Placeholder(),
            error: (e, _) => const _Placeholder(dim: true),
            data: (a) => a.activity.isEmpty
                ? const _EmptyActivity(message: 'No commits in the last 30 days.')
                : _Bars(activity: a.activity),
          ),
        ],
      ),
    );
  }
}

/// AsyncValue<CommitActivity> passed by value (type alias to keep the
/// constructor signature readable).
typedef AsyncActivity = AsyncValue<CommitActivity>;

/// Day-bucketed bars. 30 columns; every bucket gets a bar even at zero
/// so the rhythm of quiet days stays legible.
class _Bars extends StatelessWidget {
  const _Bars({required this.activity});

  final List<CommitDay> activity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final max = activity
        .map((d) => d.count)
        .fold<int>(1, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final day in activity)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Tooltip(
                    message: '${day.date}: ${day.count} commit${day.count == 1 ? '' : 's'}',
                    child: AnimatedContainer(
                      duration: AppMotion.standard,
                      curve: AppMotion.curve,
                      height: 34 * (day.count / max).clamp(0.08, 1.0) + 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: day.count > 0
                            ? AppColors.brand.withValues(
                                alpha: 0.35 + (day.count / max) * 0.6)
                            : scheme.onSurface.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '$totalCommits commit${totalCommits == 1 ? '' : 's'} across $activeDays active day${activeDays == 1 ? '' : 's'}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.4),
              ),
        ),
      ],
    );
  }

  int get totalCommits => activity.fold<int>(0, (a, d) => a + d.count);
  int get activeDays => activity.length;
}

/// Loading / error placeholder — designed absence, not fake data.
class _Placeholder extends StatelessWidget {
  const _Placeholder({this.dim = false});

  final bool dim;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final alpha = dim ? 0.06 : 0.13;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < 30; i++)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  height: 30,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: scheme.onSurface.withValues(
                        alpha: alpha * (0.7 + (i % 4) * 0.1)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          dim ? 'Commit history unavailable right now.' : 'Loading commit history…',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.4),
              ),
        ),
      ],
    );
  }
}

/// Zero-activity state.
class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: scheme.onSurface.withValues(alpha: 0.04),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.45),
            ),
      ),
    );
  }
}
