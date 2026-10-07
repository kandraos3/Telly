import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/achievements/data/achievements_repository.dart';
import 'package:telly_app/features/achievements/domain/medal.dart';
import 'package:telly_app/features/achievements/presentation/screens/achievements_screen.dart';
import 'package:telly_app/features/queue/data/watchlist_repository.dart';

import '../../fakes/fake_watchlist_repository.dart';
import 'achievements_fixtures.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  Future<(FakeAchievementsRepository, FakeWatchlistRepository)> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeAchievementsRepository(withCollections())
      ..stillToWatch = {
        263: const [
          StillToWatch(titleId: 49026, title: 'The Dark Knight Rises', releaseYear: 2012),
          StillToWatch(titleId: 155, title: 'The Dark Knight', releaseYear: 2008, inQueue: true),
        ],
      };
    final queue = FakeWatchlistRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        hapticsEnabledProvider.overrideWith((ref) => false),
        databaseProvider.overrideWithValue(db),
        achievementsRepositoryProvider.overrideWithValue(repo),
        watchlistRepositoryProvider.overrideWithValue(queue),
      ],
      child: MaterialApp(theme: TellyTheme.dark, home: const AchievementsScreen()),
    ));
    await tester.pumpAndSettle();
    return (repo, queue);
  }

  group('#141 collections on SCR-23', () {
    test('closest to done first; finished collections last', () {
      expect(withCollections().collections.map((m) => m.id), [
        'collection_1241', // 7/8
        'collection_263', // 2/3
        'collection_87359', // 5/8
        'collection_10194', // 1/4
        'collection_119', // done
      ]);
    });

    testWidgets('a Collections section sits above Milestones, showing three until See all', (tester) async {
      await pump(tester);
      double top(String k) => tester.getTopLeft(find.byKey(Key(k))).dy;
      expect(top('achievements_section_collections'), lessThan(top('achievements_section_milestones')));
      expect(find.text('4 in progress'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('achievements_progress_collection_263'))).data, '2/3');
      expect(find.byKey(const Key('achievements_row_collection_10194')), findsNothing);

      await tester.tap(find.byKey(const Key('achievements_collections_see_all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('achievements_row_collection_10194')), findsOneWidget);
      expect(find.byKey(const Key('achievements_row_collection_119')), findsOneWidget);
      expect(find.byKey(const Key('achievements_collections_see_all')), findsNothing);
    });

    testWidgets('the collection sheet lists Still to watch with one-tap + Queue', (tester) async {
      final (_, queue) = await pump(tester);
      await tester.tap(find.byKey(const Key('achievements_row_collection_263')));
      await tester.pumpAndSettle();
      expect(find.text('Collection · Gold when complete'), findsOneWidget);
      expect(find.text('2 of 3 ranked'), findsOneWidget);
      expect(find.byKey(const Key('medal_sheet_still_to_watch')), findsOneWidget);
      expect(find.text('✓ In Queue'), findsOneWidget, reason: 'already queued');

      await tester.tap(find.byKey(const Key('medal_sheet_queue_49026')));
      await tester.pumpAndSettle();
      expect(queue.items.single.titleId, 49026);
      expect(find.text('✓ In Queue'), findsNWidgets(2));
    });

    testWidgets('a finished collection has no Still to watch', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('achievements_collections_see_all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('achievements_row_collection_119')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('medal_sheet_still_to_watch')), findsNothing);
      expect(find.text('Collection · Gold'), findsOneWidget);
    });
  });
}
