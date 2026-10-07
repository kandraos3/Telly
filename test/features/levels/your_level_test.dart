import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/analytics/telemetry_service.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/levels/data/levels_repository.dart';
import 'package:telly_app/features/levels/domain/level_models.dart';
import 'package:telly_app/features/levels/presentation/controllers/levels_controller.dart';
import 'package:telly_app/features/levels/presentation/screens/friends_this_week_screen.dart';
import 'package:telly_app/features/levels/presentation/screens/your_level_screen.dart';
import 'package:telly_app/features/squads/domain/squad_models.dart';

import 'levels_fixtures.dart';

void main() {
  late AppDatabase db;
  setUp(() {
    db = AppDatabase.inMemory();
    TelemetryService().reset();
  });
  tearDown(() => db.close());

  group('#146 level model', () {
    test('progress inside the level, with grouped digits', () {
      final l = sampleLevel().level;
      expect(l.progressLabel, '2,340 / 3,000 XP to Level 13');
      expect(l.fraction, closeTo(0.78, 0.001));
      expect(groupDigits(1234567), '1,234,567');
    });
  });

  group('#146 YourLevelController', () {
    ProviderContainer container(FakeLevelsRepository repo) {
      final c = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        levelsRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('the first load records what it saw without events; later changes report them', () async {
      final repo = FakeLevelsRepository(sampleLevel(level: 11, total: 14000, streak: 5, questDone: false));
      var c = container(repo);
      await c.read(yourLevelControllerProvider.future);
      expect(TelemetryService().recordedEvents, isEmpty);

      repo.level = sampleLevel();
      c = container(repo);
      await c.read(yourLevelControllerProvider.future);
      expect(TelemetryService().recordedEvents.map((e) => e.toJson()['event']),
          unorderedEquals(['level_up', 'streak_extended', 'quest_completed']));
    });

    test('offline: the cached snapshot, read-only', () async {
      final repo = FakeLevelsRepository();
      await container(repo).read(yourLevelControllerProvider.future);
      repo.error = Exception('offline');
      final cached = await container(repo).read(yourLevelControllerProvider.future);
      expect(cached.offline, isTrue);
      expect(cached.level.level, 12);
    });
  });

  List<Override> overrides(FakeLevelsRepository repo, {List<Squad> squads = const []}) => [
        hapticsEnabledProvider.overrideWith((ref) => false),
        databaseProvider.overrideWithValue(db),
        levelsRepositoryProvider.overrideWithValue(repo),
        weeklyTableSquadsProvider.overrideWith((ref) async => squads),
      ];

  Future<void> pump(WidgetTester tester, Widget screen, List<Override> o) async {
    tester.view.physicalSize = const Size(393, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
        key: UniqueKey(), overrides: o, child: MaterialApp(theme: TellyTheme.dark, home: screen)));
    await tester.pumpAndSettle();
  }

  group('#146 SCR-27 Your level', () {
    testWidgets('level card, streak strip with the freeze, and three quests', (tester) async {
      await pump(tester, const YourLevelScreen(), overrides(FakeLevelsRepository()));
      expect(find.text('Cinephile'), findsOneWidget);
      expect(find.text('2,340 / 3,000 XP to Level 13'), findsOneWidget);
      expect(find.text('▲ 6 weeks'), findsOneWidget);
      expect(find.text('❄'), findsOneWidget);
      expect(find.text('Now'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('1 of 3'), findsOneWidget);
      expect(find.text('+50'), findsOneWidget);
    });

    testWidgets('? explains how XP is earned', (tester) async {
      await pump(tester, const YourLevelScreen(), overrides(FakeLevelsRepository()));
      await tester.tap(find.byKey(const Key('level_rules')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('xp_rules')), findsOneWidget);
      expect(find.text('Rank a title (max 10 a week)'), findsOneWidget);
    });

    testWidgets('error with nothing cached: retry', (tester) async {
      await pump(tester, const YourLevelScreen(), overrides(FakeLevelsRepository()..error = Exception('down')));
      expect(find.byKey(const Key('level_error')), findsOneWidget);
    });
  });

  group('#146 Friends this week', () {
    testWidgets('rank, level, streak and weekly XP, with my row marked', (tester) async {
      await pump(tester, const FriendsThisWeekScreen(), overrides(FakeLevelsRepository()));
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Level 18 · ▲ 11 weeks'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('week_xp_m'))).data, '640');
      expect(find.byKey(const Key('week_segments')), findsNothing, reason: 'no squads, no segments');
      expect(find.textContaining('Resets Monday'), findsOneWidget);
    });

    testWidgets('a squad segment shows that squad\'s table', (tester) async {
      final repo = FakeLevelsRepository()
        ..tables = {
          null: sampleWeek,
          'sq1': const [WeeklyRow(userId: 'c', displayName: 'Casey', weekXp: 90, rank: 1)],
        };
      final squad = Squad(id: 'sq1', name: 'Couch Potatoes', createdBy: 'u1', createdAt: DateTime(2026));
      await pump(tester, const FriendsThisWeekScreen(), overrides(repo, squads: [squad]));
      await tester.tap(find.byKey(const Key('week_segment_sq1')));
      await tester.pumpAndSettle();
      expect(find.text('Casey'), findsOneWidget);
      expect(find.textContaining('in this squad'), findsOneWidget);
    });
  });
}
