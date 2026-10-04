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

/// `users.preferences` (settings spec §2; FE-608). Unknown keys are preserved on save.
class AppPreferences {
  final HapticsMode haptics;
  final bool reducedMotion;
  final String region;
  final bool includeRentals;
  final bool quietHours;
  final Map<NotificationKind, bool> notifications;

  const AppPreferences({
    this.haptics = HapticsMode.full,
    this.reducedMotion = false,
    this.region = 'US',
    this.includeRentals = false,
    this.quietHours = false,
    this.notifications = const {},
  });

  static const regions = ['US', 'GB', 'CA', 'AU', 'DE', 'FR', 'JP'];

  bool notificationOn(NotificationKind k) => notifications[k] ?? k.defaultOn;

  factory AppPreferences.fromJson(Map<String, dynamic> j) {
    final n = (j['notifications'] as Map?) ?? const {};
    return AppPreferences(
      haptics: HapticsMode.parse(j['haptics']),
      reducedMotion: (j['reduced_motion'] as bool?) ?? false,
      region: (j['region'] as String?) ?? 'US',
      includeRentals: (j['include_rentals'] as bool?) ?? false,
      quietHours: (j['quiet_hours'] as bool?) ?? false,
      notifications: {
        for (final k in NotificationKind.values)
          if (n[k.key] is bool) k: n[k.key] as bool,
      },
    );
  }

  Map<String, dynamic> toJson() => {
        'haptics': haptics.name,
        'reduced_motion': reducedMotion,
        'region': region,
        'include_rentals': includeRentals,
        'quiet_hours': quietHours,
        'notifications': {for (final k in NotificationKind.values) k.key: notificationOn(k)},
      };

  AppPreferences copyWith({
    HapticsMode? haptics,
    bool? reducedMotion,
    String? region,
    bool? includeRentals,
    bool? quietHours,
    Map<NotificationKind, bool>? notifications,
  }) =>
      AppPreferences(
        haptics: haptics ?? this.haptics,
        reducedMotion: reducedMotion ?? this.reducedMotion,
        region: region ?? this.region,
        includeRentals: includeRentals ?? this.includeRentals,
        quietHours: quietHours ?? this.quietHours,
        notifications: notifications ?? this.notifications,
      );
}

/// Loads and saves [AppPreferences]; edits are optimistic and roll back on failure.
class PreferencesController extends AsyncNotifier<AppPreferences> {
  @override
  Future<AppPreferences> build() async =>
      AppPreferences.fromJson(await ref.watch(profileRepositoryProvider).fetchPreferences());

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
