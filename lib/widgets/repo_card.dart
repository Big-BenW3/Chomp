/// Repository card — the home list hero.
///
/// Double-bezel shell: a hairline outer enclosure hugging a surfaced
/// core. Watch state reads as pills (magenta = auto, outline = manual),
/// language as a tinted tile, and the last push as compact relative
/// time. Tap ripples inward.

library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../models/repo.dart';
import '../utils/time.dart';
import 'chomp_card.dart';

class RepoCard extends StatelessWidget {
  const RepoCard({super.key, required this.repo, this.onTap});

  final Repo repo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: ChompCard(
        onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LanguageTile(
                  language: repo.language,
                  name: repo.name,
                  isDark: isDark,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        repo.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (repo.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          repo.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.55)),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (repo.isAutoWatched)
                            const _WatchPill(
                                label: 'AUTO',
                                filled: true,
                                color: AppColors.brand)
                          else if (repo.isManuallyWatched)
                            const _WatchPill(
                                label: 'WATCHED',
                                filled: false,
                                color: AppColors.brand),
                          if (repo.lastPushedAt != null) ...[
                            if (repo.isWatched) const SizedBox(width: 8),
                            Text(
                              relativeTime(repo.lastPushedAt!),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color:
                                        scheme.onSurface.withValues(alpha: 0.4),
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurface.withValues(alpha: 0.25),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile(
      {required this.language, required this.name, required this.isDark});

  final String? language;
  final String name;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final code = (language?.isNotEmpty ?? false)
        ? language![0].toUpperCase()
        : (name.isNotEmpty ? name[0].toUpperCase() : '?');

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.darkSurfaceHigh, AppColors.darkSurface]
              : [AppColors.lightSurfaceHigh, AppColors.lightSurface],
        ),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      alignment: Alignment.center,
      child: Text(
        code,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.brand,
        ),
      ),
    );
  }
}

class _WatchPill extends StatelessWidget {
  const _WatchPill(
      {required this.label, required this.filled, required this.color});

  final String label;
  final bool filled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        color: filled ? color.withValues(alpha: 0.14) : Colors.transparent,
        border: filled ? null : Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
