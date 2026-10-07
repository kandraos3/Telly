library telemetry_service;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Product analytics event model.
class TelemetryEvent {
  final String name;
  final Map<String, dynamic> properties;
  final DateTime timestamp;

  const TelemetryEvent({
    required this.name,
    required this.properties,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'event': name,
        'properties': properties,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Telemetry and product analytics service (PostHog compatible).
/// Conforms to `DEV-503`, `DEV-601`, and `docs/technical_architecture/05_DEPLOYMENT_DEVOPS_AND_LAUNCH_CHECKLIST.md` §3.2.
class TelemetryService {
  static final TelemetryService _instance = TelemetryService._internal();
  factory TelemetryService() => _instance;
  TelemetryService._internal();

  bool _initialized = false;
  Posthog? _posthog;
  final List<TelemetryEvent> _events = [];
  final StreamController<TelemetryEvent> _eventStreamController =
      StreamController<TelemetryEvent>.broadcast();

  bool get isInitialized => _initialized;
  List<TelemetryEvent> get recordedEvents => List.unmodifiable(_events);
  Stream<TelemetryEvent> get eventStream => _eventStreamController.stream;

  /// Initialize analytics SDK with PostHog client (no IDFA).
  Future<void> initialize({
    required String apiKey,
    String host = 'https://app.posthog.com',
    Posthog? posthogClient,
  }) async {
    _initialized = true;
    _events.clear();

    if (apiKey.isNotEmpty) {
      _posthog = posthogClient ?? Posthog();
      final config = PostHogConfig(apiKey);
      config.host = host;
      // Guarantee zero third-party ad tracking and no IDFA collection
      config.captureApplicationLifecycleEvents = false;
      try {
        await _posthog!.setup(config);
      } catch (_) {}
    }
  }

  /// Track when a user finishes onboarding.
  void trackOnboardingCompleted({
    required int canonSeedCount,
    required int durationSeconds,
  }) {
    _track('onboarding_completed', {
      'canon_seed_count': canonSeedCount,
      'duration_seconds': durationSeconds,
    });
  }

  /// Track when a duel battle concludes.
  void trackDuelBattleWon({
    required int winnerId,
    required int loserId,
    required bool isUpset,
  }) {
    _track('duel_battle_won', {
      'winner_id': winnerId,
      'loser_id': loserId,
      'is_upset': isUpset,
    });
  }

  /// Track when a ranking entry is published with score.
  void trackCanonPublished({
    required int rankSlot,
    required double score,
    required bool hasHotTake,
  }) {
    _track('canon_published', {
      'rank_slot': rankSlot,
      'score': score,
      'has_hot_take': hasHotTake,
    });
  }

  /// Track when a Two-to-Watch co-watch session is launched.
  void trackTwoToWatchStarted({
    required int friendCount,
    required int sharedProvidersCount,
  }) {
    _track('two_to_watch_started', {
      'friend_count': friendCount,
      'shared_providers_count': sharedProvidersCount,
    });
  }

  /// Track high-resolution story export.
  void trackStoryCardExported({
    required String templateType,
  }) {
    _track('story_card_exported', {
      'template_type': templateType,
    });
  }

  /// A medal's unlock moment was shown (features/10 §11, #139).
  void trackMedalUnlocked({required String achievementId, required String tier, required String kind}) {
    _track('medal_unlocked', {'achievement_id': achievementId, 'tier': tier, 'kind': kind});
  }

  /// A medal was pinned to the profile (features/10 §11, #139).
  void trackMedalPinned({required String achievementId, required int slot}) {
    _track('medal_pinned', {'achievement_id': achievementId, 'slot': slot});
  }

  /// A challenge was joined (features/10 §11, #144).
  void trackChallengeJoined({required String slug, required bool squad}) {
    _track('challenge_joined', {'slug': slug, 'squad': squad});
  }

  /// A challenge was finished: its medal's unlock moment showed (features/10 §11, #144).
  void trackChallengeCompleted({required String achievementId}) {
    _track('challenge_completed', {'achievement_id': achievementId});
  }

  /// A weekly quest was completed (features/10 §11, #146).
  void trackQuestCompleted({required String questKey, required int xp}) {
    _track('quest_completed', {'quest_key': questKey, 'xp': xp});
  }

  /// The user's level went up (features/10 §11, #146).
  void trackLevelUp({required int from, required int to}) {
    _track('level_up', {'from': from, 'to': to});
  }

  /// The weekly streak grew (features/10 §11, #146).
  void trackStreakExtended({required int weeks}) {
    _track('streak_extended', {'weeks': weeks});
  }

  /// A cosmetic reward was equipped (features/10 §11, #147).
  void trackRewardEquipped({required String rewardId}) {
    _track('reward_equipped', {'reward_id': rewardId});
  }

  void _track(String name, Map<String, dynamic> properties) {
    final event = TelemetryEvent(
      name: name,
      properties: properties,
      timestamp: DateTime.now(),
    );
    _events.add(event);
    _eventStreamController.add(event);

    if (_posthog != null) {
      try {
        _posthog!.capture(
          eventName: name,
          properties: properties.map((k, v) => MapEntry(k, v as Object)),
        );
      } catch (_) {}
    }
  }

  /// Reset telemetry state (for testing).
  void reset() {
    _initialized = false;
    _posthog = null;
    _events.clear();
  }
}

final telemetryServiceProvider = Provider<TelemetryService>((ref) => TelemetryService());

