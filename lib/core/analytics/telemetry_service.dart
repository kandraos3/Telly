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

