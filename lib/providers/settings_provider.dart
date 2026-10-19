/// App settings state management using Riverpod.
///
/// Manages user preferences for:
/// - Theme mode (light/dark/system)
/// - Notification settings (new issues, score drops)
/// - Score drop threshold for notifications
///
/// Theme mode persists to local storage. Notification preferences
/// remain in-memory until a `/settings` backend endpoint exists.

library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';

/// Available theme modes for the app.
enum ThemeModePref { light, dark, system }

/// User settings state.
///
/// Contains all configurable preferences for the app.
/// Default values are provided for all settings.
class SettingsState {
  /// Preferred theme mode. Defaults to dark — the brand identity.
  final ThemeModePref themeMode;

  /// Master switch for push notifications. Local to the device: the
  /// server only decides *whether to send*; FCM delivers regardless.
  final bool notificationsEnabled;

  /// Whether to notify when new issues are found in scans.
  final bool notifyOnNewIssue;

  /// Whether to notify when security scores drop significantly.
  final bool notifyOnScoreDrop;

  /// Minimum score drop (in points) to trigger a notification.
  final int scoreDropThreshold;

  const SettingsState({
    this.themeMode = ThemeModePref.dark,
    this.notificationsEnabled = true,
    this.notifyOnNewIssue = true,
    this.notifyOnScoreDrop = true,
    this.scoreDropThreshold = 10,
  });

  /// Creates a copy of this state with optional field overrides.
  SettingsState copyWith({
    ThemeModePref? themeMode,
    bool? notificationsEnabled,
    bool? notifyOnNewIssue,
    bool? notifyOnScoreDrop,
    int? scoreDropThreshold,
  }) =>
      SettingsState(
        themeMode: themeMode ?? this.themeMode,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        notifyOnNewIssue: notifyOnNewIssue ?? this.notifyOnNewIssue,
        notifyOnScoreDrop: notifyOnScoreDrop ?? this.notifyOnScoreDrop,
        scoreDropThreshold: scoreDropThreshold ?? this.scoreDropThreshold,
      );
}

/// Manages app settings and preferences.
///
/// Theme mode persists locally; notification preferences persist to the
/// backend (`/settings`) so the hourly scan pipeline actually honors
/// them — the threshold a user picks here is what the server uses.
class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier(this._api) : super(const SettingsState());

  final ApiClient _api;

  static const _themeKey = 'theme_mode';

  /// Loads persisted settings. Call once before `runApp` so the first
  /// frame renders with the user's chosen theme, then kicks off a
  /// background fetch of the server-backed prefs.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themeKey);
    final mode = ThemeModePref.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => ThemeModePref.dark,
    );
    state = state.copyWith(themeMode: mode);
    await _loadRemote();
  }

  /// Pulls notification prefs from the server. On failure (offline,
  /// signed out, signed in) we keep whatever is in state — the UI
  /// always shows *something* and the next load reconciles it.
  Future<void> _loadRemote() async {
    try {
      final data = await _api.get('/settings') as Map<String, dynamic>;
      state = state.copyWith(
        notificationsEnabled: data['notify_enabled'] as bool? ?? state.notificationsEnabled,
        notifyOnNewIssue: data['notify_on_new_issue'] as bool? ?? state.notifyOnNewIssue,
        notifyOnScoreDrop: data['notify_on_score_drop'] as bool? ?? state.notifyOnScoreDrop,
        scoreDropThreshold: data['alert_threshold'] as int? ?? state.scoreDropThreshold,
      );
    } catch (_) {
      // Server-backed prefs unavailable; keep local state.
    }
  }

  /// Updates the preferred theme mode and persists it.
  Future<void> setThemeMode(ThemeModePref mode) async {
    HapticFeedback.selectionClick();
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }

  /// Updates whether pushes are enabled at all.
  void setNotificationsEnabled(bool value) {
    HapticFeedback.selectionClick();
    state = state.copyWith(notificationsEnabled: value);
    _sync();
  }

  /// Updates whether to notify on new issues.
  void setNotifyOnNewIssue(bool value) {
    HapticFeedback.selectionClick();
    state = state.copyWith(notifyOnNewIssue: value);
    _sync();
  }

  /// Updates whether to notify on score drops.
  void setNotifyOnScoreDrop(bool value) {
    HapticFeedback.selectionClick();
    state = state.copyWith(notifyOnScoreDrop: value);
    _sync();
  }

  /// Updates the minimum score drop threshold for notifications.
  void setScoreDropThreshold(int value) {
    HapticFeedback.selectionClick();
    state = state.copyWith(scoreDropThreshold: value);
    _sync();
  }

  /// Pushes the notification prefs to the server (fire-and-forget: the
  /// UI stays responsive and a transient failure just means the server
  /// keeps its previous values until the next sync).
  Future<void> _sync() async {
    try {
      await _api.put('/settings', {
        'notify_enabled': state.notificationsEnabled,
        'notify_on_new_issue': state.notifyOnNewIssue,
        'notify_on_score_drop': state.notifyOnScoreDrop,
        'alert_threshold': state.scoreDropThreshold,
      });
    } catch (_) {
      // Optimistic: keep local state, reconcile on next load.
    }
  }
}

/// Provider for the current app settings.
///
/// Use this to watch settings changes and update the UI accordingly.
final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(ApiClient.instance),
);
