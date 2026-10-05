import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../onboarding/data/onboarding_repository.dart';
import '../../data/profile_repository.dart';

/// Haptic intensity (settings spec S4).
enum HapticsMode {
  full('Full Tactility'),
  subtle('Subtle Haptics'),
  off('Disabled');

  final String label;
  const HapticsMode(this.label);

  static HapticsMode parse(Object? v) => values.firstWhere((m) => m.name == v, orElse: () => HapticsMode.full);
}

/// Push categories with the spec S3 defaults.
enum NotificationKind {
  friendFinale('friend_finale', 'Friend Finished Finale', true),
  friendUpsetOnMyNumberOne('friend_upset_on_my_one', 'Friend Upset on Your #1', true),
  spicyUpsets('spicy_upsets', 'Spicy Upsets in Circle', true),
  leavingSoon('leaving_soon', 'Leaving Soon Alert', true),
  commentReplies('comment_replies', 'Comment Replies & Tags', true),
  weeklyDigest('weekly_digest', 'Weekly Squad Digest', false),
  marketing('marketing', 'Marketing & New Features', false);

  final String key;
  final String label;
  final bool defaultOn;
  const NotificationKind(this.key, this.label, this.defaultOn);
}

/// Theme selection mode (settings spec §2; FE-THEME-01).
enum TellyThemeMode {
  system('System'),
  dark('Dark'),
  light('Light');

  final String label;
  const TellyThemeMode(this.label);

  static TellyThemeMode parse(Object? v) =>
      values.firstWhere((m) => m.name == v, orElse: () => TellyThemeMode.dark);
}

/// `users.preferences` (settings spec §2; FE-608, FE-THEME-01). Unknown keys are preserved on save.
class AppPreferences {
  final TellyThemeMode themeMode;
  final HapticsMode haptics;
  final bool reducedMotion;
  final String region;
  final bool includeRentals;
  final bool quietHours;
  final bool biometricEnabled;
  final Map<NotificationKind, bool> notifications;

  const AppPreferences({
    this.themeMode = TellyThemeMode.dark,
    this.haptics = HapticsMode.full,
    this.reducedMotion = false,
    this.region = 'US',
    this.includeRentals = false,
    this.quietHours = false,
    this.biometricEnabled = false,
    this.notifications = const {},
  });

  static const regions = ['US', 'GB', 'CA', 'AU', 'DE', 'FR', 'JP'];

  bool notificationOn(NotificationKind k) => notifications[k] ?? k.defaultOn;

  factory AppPreferences.fromJson(Map<String, dynamic> j) {
    final n = (j['notifications'] as Map?) ?? const {};
    return AppPreferences(
      themeMode: TellyThemeMode.parse(j['theme_mode']),
      haptics: HapticsMode.parse(j['haptics']),
      reducedMotion: (j['reduced_motion'] as bool?) ?? false,
      region: (j['region'] as String?) ?? 'US',
      includeRentals: (j['include_rentals'] as bool?) ?? false,
      quietHours: (j['quiet_hours'] as bool?) ?? false,
      biometricEnabled: (j['biometric_enabled'] as bool?) ?? false,
      notifications: {
        for (final k in NotificationKind.values)
          if (n[k.key] is bool) k: n[k.key] as bool,
      },
    );
  }

  Map<String, dynamic> toJson() => {
        'theme_mode': themeMode.name,
        'haptics': haptics.name,
        'reduced_motion': reducedMotion,
        'region': region,
        'include_rentals': includeRentals,
        'quiet_hours': quietHours,
        'biometric_enabled': biometricEnabled,
        'notifications': {for (final k in NotificationKind.values) k.key: notificationOn(k)},
      };

  AppPreferences copyWith({
    TellyThemeMode? themeMode,
    HapticsMode? haptics,
    bool? reducedMotion,
    String? region,
    bool? includeRentals,
    bool? quietHours,
    bool? biometricEnabled,
    Map<NotificationKind, bool>? notifications,
  }) =>
      AppPreferences(
        themeMode: themeMode ?? this.themeMode,
        haptics: haptics ?? this.haptics,
        reducedMotion: reducedMotion ?? this.reducedMotion,
        region: region ?? this.region,
        includeRentals: includeRentals ?? this.includeRentals,
        quietHours: quietHours ?? this.quietHours,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        notifications: notifications ?? this.notifications,
      );
}

/// Loads and saves [AppPreferences]; edits are optimistic and roll back on failure.
class PreferencesController extends AsyncNotifier<AppPreferences> {
  @override
  Future<AppPreferences> build() async {
    try {
      final repo = ref.watch(profileRepositoryProvider);
      final json = await repo.fetchPreferences();
      return AppPreferences.fromJson(json);
    } catch (_) {
      return const AppPreferences();
    }
  }

  Future<void> edit(AppPreferences Function(AppPreferences) change) async {
    final before = state.valueOrNull ?? const AppPreferences();
    final after = change(before);
    state = AsyncData(after);
    try {
      await ref.read(profileRepositoryProvider).updatePreferences(after.toJson());
    } catch (_) {
      state = AsyncData(before);
      rethrow;
    }
  }

  Future<void> setNotification(NotificationKind kind, bool on) =>
      edit((p) => p.copyWith(notifications: {...p.notifications, kind: on}));

  Future<void> setAllNotifications(bool on) => edit((p) => p.copyWith(notifications: {
        for (final kind in NotificationKind.values) kind: on,
      }));
}

final preferencesProvider = AsyncNotifierProvider<PreferencesController, AppPreferences>(PreferencesController.new);

/// My persisted streaming subscriptions (`user_streaming_subscriptions`), edited in
/// Settings S2 and read by the queue/co-watch filters.
class SubscriptionsController extends AsyncNotifier<StreamingSetup> {
  @override
  Future<StreamingSetup> build() => ref.watch(onboardingRepositoryProvider).fetchStreamingSetup();

  Future<void> save(Set<String> platformIds, {bool? includeFree}) async {
    final before = state.valueOrNull ?? const StreamingSetup({}, includeFreePlatforms: false);
    final after = StreamingSetup(platformIds, includeFreePlatforms: includeFree ?? before.includeFreePlatforms);
    state = AsyncData(after);
    try {
      await ref
          .read(onboardingRepositoryProvider)
          .saveStreamingSetup(platformIds: after.platformIds, includeFreePlatforms: after.includeFreePlatforms);
    } catch (_) {
      state = AsyncData(before);
      rethrow;
    }
  }
}

final subscriptionsProvider =
    AsyncNotifierProvider<SubscriptionsController, StreamingSetup>(SubscriptionsController.new);
