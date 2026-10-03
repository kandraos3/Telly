import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/analytics/telemetry_service.dart';
import 'package:telly_app/core/monitoring/sentry_service.dart';

void main() {
  group('SentryService Monitoring Tests (DEV-503)', () {
    final sentry = SentryService();

    setUp(() async {
      sentry.reset();
      await sentry.initialize(
        dsn: 'https://mock@sentry.io/123456',
        environment: 'staging',
      );
    });

    test('initializes with correct environment', () {
      expect(sentry.isInitialized, isTrue);
      expect(sentry.environment, equals('staging'));
    });

    test('records navigation and duel breadcrumbs in buffer', () {
      sentry.addNavigationBreadcrumb('/duel-arena');
      sentry.addDuelBreadcrumb(
        showAId: 110492,
        showBId: 76331,
        winnerId: 110492,
        isUpset: true,
      );

      expect(sentry.breadcrumbs.length, equals(2));
      expect(sentry.breadcrumbs[0].category, equals('navigation'));
      expect(sentry.breadcrumbs[1].category, equals('duel'));
      expect(sentry.breadcrumbs[1].data?['is_upset'], isTrue);
    });

    test('captures exception with metadata', () async {
      await sentry.captureException(
        Exception('SQLite disk write failure'),
        null,
        {'action': 'rank_commit'},
      );

      expect(sentry.capturedExceptions.length, equals(1));
      expect(sentry.capturedExceptions.first['exception'], contains('SQLite disk write failure'));
      expect(sentry.capturedExceptions.first['extra']['action'], equals('rank_commit'));
    });
  });

  group('TelemetryService Product Analytics Tests (DEV-503)', () {
    final telemetry = TelemetryService();

    setUp(() async {
      telemetry.reset();
      await telemetry.initialize(apiKey: 'ph_mock_key_987');
    });

    test('tracks core product lifecycle events', () {
      telemetry.trackOnboardingCompleted(canonSeedCount: 5, durationSeconds: 42);
      telemetry.trackDuelBattleWon(winnerId: 101, loserId: 102, isUpset: true);
      telemetry.trackCanonPublished(rankSlot: 1, score: 10.0, hasHotTake: true);
      telemetry.trackTwoToWatchStarted(friendCount: 2, sharedProvidersCount: 3);
      telemetry.trackStoryCardExported(templateType: 'top9');

      expect(telemetry.recordedEvents.length, equals(5));

      final events = telemetry.recordedEvents;
      expect(events[0].name, equals('onboarding_completed'));
      expect(events[0].properties['canon_seed_count'], equals(5));

      expect(events[1].name, equals('duel_battle_won'));
      expect(events[1].properties['is_upset'], isTrue);

      expect(events[2].name, equals('canon_published'));
      expect(events[2].properties['score'], equals(10.0));

      expect(events[3].name, equals('two_to_watch_started'));
      expect(events[4].name, equals('story_card_exported'));
    });
  });
}

