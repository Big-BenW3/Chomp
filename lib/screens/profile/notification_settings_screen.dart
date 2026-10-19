/// Notification settings.
///
/// Toggles for push, new-issue and score-drop alerts, plus a segmented
/// threshold picker. All of it persists to the backend (`/settings`)
/// and is enforced by the hourly scan pipeline — the threshold picked
/// here is the one the server actually uses.

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/chomp_card.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final disabled = !settings.notificationsEnabled;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          ChompCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Push notifications'),
                  subtitle:
                      const Text('Master switch for pushes to this device'),
                  value: settings.notificationsEnabled,
                  onChanged: notifier.setNotificationsEnabled,
                ),
                Divider(color: scheme.outline, height: 1),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('New issues'),
                  subtitle:
                      const Text('Alert when a scan finds something new'),
                  value: disabled ? false : settings.notifyOnNewIssue,
                  onChanged: disabled ? null : notifier.setNotifyOnNewIssue,
                ),
                Divider(color: scheme.outline, height: 1),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Score drops'),
                  subtitle:
                      const Text('Alert when a security score falls hard'),
                  value: disabled ? false : settings.notifyOnScoreDrop,
                  onChanged: disabled ? null : notifier.setNotifyOnScoreDrop,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ChompCard(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MINIMUM SCORE DROP',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.45),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('Alert me when it drops by',
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: AppColors.brand.withValues(alpha: 0.12),
                        ),
                        child: Text(
                          '${settings.scoreDropThreshold}+ pts',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: AppColors.brand),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 10, label: Text('10')),
                      ButtonSegment(value: 20, label: Text('20')),
                      ButtonSegment(value: 30, label: Text('30')),
                    ],
                    selected: {settings.scoreDropThreshold},
                    onSelectionChanged: (selection) =>
                        notifier.setScoreDropThreshold(selection.first),
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
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill)),
                      ),
                    ),
                  ),
                ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Synced to your account — the hourly scan uses these settings when deciding what to push.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.4),
                ),
          ),
        ],
      ),
    );
  }
}
