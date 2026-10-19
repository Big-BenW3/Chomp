/// Profile — identity, appearance, and account actions.
///
/// Header card leads with the GitHub identity; Appearance carries the
/// Light/Dark/System selector wired straight to the persisted theme.
/// Destructive action (disconnect) gets a confirm dialog, red-tinted.

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/user.dart';
import '../../widgets/chomp_card.dart';
import '../../widgets/reveal.dart';
import 'notification_settings_screen.dart';
import 'watchlist_manager_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: scheme.outline, height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          // Identity header.
          Reveal(
            child: ChompCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _Avatar(user: auth.user),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.user?.githubUsername ?? 'GitHub user',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          auth.user == null
                              ? 'Restore session on next sign-in'
                              : 'GitHub connected',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.5),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Appearance.
          Reveal(
            delayMs: 60,
            child: _SectionCard(
              title: 'APPEARANCE',
              children: [
                SegmentedButton<ThemeModePref>(
                  segments: const [
                    ButtonSegment(
                        value: ThemeModePref.light,
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('Light')),
                    ButtonSegment(
                        value: ThemeModePref.dark,
                        icon: Icon(Icons.dark_mode_outlined),
                        label: Text('Dark')),
                    ButtonSegment(
                        value: ThemeModePref.system,
                        icon: Icon(Icons.brightness_auto_outlined),
                        label: Text('System')),
                  ],
                  selected: {ref.watch(settingsProvider).themeMode},
                  onSelectionChanged: (selection) => ref
                      .read(settingsProvider.notifier)
                      .setThemeMode(selection.first),
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? AppColors.brand.withValues(alpha: 0.14)
                          : Colors.transparent,
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? AppColors.brand
                          : scheme.onSurface.withValues(alpha: 0.6),
                    ),
                    side: WidgetStateProperty.resolveWith(
                      (states) => BorderSide(
                        color: states.contains(WidgetState.selected)
                            ? AppColors.brand.withValues(alpha: 0.4)
                            : scheme.outline,
                      ),
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Actions.
          Reveal(
            delayMs: 120,
            child: _SectionCard(
              title: 'ACCOUNT',
              children: [
                _RowTile(
                  icon: Icons.list_alt_rounded,
                  title: 'Manage watchlist',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const WatchlistManagerScreen()),
                  ),
                ),
                _RowTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const NotificationSettingsScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Danger zone.
          Reveal(
            delayMs: 180,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.shell),
                border:
                    Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                color: AppColors.danger.withValues(alpha: 0.04),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  onTap: () => _confirmDisconnect(context, ref),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.link_off_rounded,
                            color: AppColors.danger, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'Disconnect GitHub',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDisconnect(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect GitHub?'),
        content: const Text(
            'You will be signed out and lose access to your watchlist until you connect again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authProvider.notifier).signOut();
    }
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});

  final ChompUser? user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = user?.avatarUrl;

    Widget inner;
    if (url != null && url.isNotEmpty) {
      inner = ClipOval(
        child: Image.network(url, width: 56, height: 56, fit: BoxFit.cover),
      );
    } else {
      inner = Icon(
        Icons.person_rounded,
        size: 28,
        color: scheme.onSurface.withValues(alpha: 0.6),
      );
    }

    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.surfaceContainerHigh,
        border: Border.all(color: scheme.outline),
      ),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: inner,
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.shell),
        border: Border.all(color: scheme.outline),
        color: tokens.surfaceHigh.withValues(alpha: 0.5),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          color: tokens.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            ...children,
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: scheme.onSurface.withValues(alpha: 0.6)),
      title: Text(title,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
      trailing: Icon(Icons.chevron_right_rounded,
          color: scheme.onSurface.withValues(alpha: 0.25)),
      onTap: onTap,
    );
  }
}
