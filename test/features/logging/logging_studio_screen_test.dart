import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/features/profile/data/graveyard_repository.dart';
import 'package:telly_app/core/widgets/telly_primary_button.dart';
import 'package:telly_app/features/logging/data/title_repository.dart';
import 'package:telly_app/features/logging/presentation/screens/logging_studio_screen.dart';

import '../../fakes/fake_graveyard_repository.dart';
import '../../fakes/fake_title_repository.dart';
import '../../helpers/router_harness.dart';

void main() {
  late FakeTitleRepository repo;
  late FakeGraveyardRepository graveyard;
  late AppDatabase db;
  setUp(() {
    repo = FakeTitleRepository();
    graveyard = FakeGraveyardRepository();
    db = AppDatabase.inMemory();
  });
  tearDown(() => db.close());

  Future<void> pumpStudio(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(routerHarness(
      const LoggingStudioScreen(),
      overrides: [
        titleRepositoryProvider.overrideWithValue(repo),
        graveyardRepositoryProvider.overrideWithValue(graveyard),
        databaseProvider.overrideWithValue(db),
      ],
    ));
    await tester.pumpAndSettle();
  }

  Future<void> searchAndPick(WidgetTester tester, String query, String resultKey) async {
    await tester.enterText(find.byKey(const Key('logging_search_field')), query);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(resultKey)));
    await tester.pumpAndSettle();
  }

  TellyPrimaryButton cta(WidgetTester tester) =>
      tester.widget<TellyPrimaryButton>(find.byKey(const Key('begin_duels_button')));

  group('FE-603: SCR-09 Logging Studio', () {
    testWidgets('typing a burst issues one search, 150 ms after the last keystroke', (tester) async {
      await pumpStudio(tester);
      final field = find.byKey(const Key('logging_search_field'));
      for (final partial in ['th', 'the', 'the b', 'the be', 'the bear']) {
        await tester.enterText(field, partial);
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(repo.queries, isEmpty);

      await tester.pump(const Duration(milliseconds: 49));
      expect(repo.queries, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(repo.queries, ['the bear']);
      expect(find.text('The Bear'), findsOneWidget);
      expect(find.text('2022 · Series'), findsOneWidget);
    });

    testWidgets('queries shorter than 2 characters never search', (tester) async {
      await pumpStudio(tester);
      await tester.enterText(find.byKey(const Key('logging_search_field')), 'x');
      await tester.pump(const Duration(milliseconds: 300));
      expect(repo.queries, isEmpty);
    });

    testWidgets('offline results are labelled as coming from the local cache', (tester) async {
      repo.offline = true;
      await pumpStudio(tester);
      await tester.enterText(find.byKey(const Key('logging_search_field')), 'bear');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('logging_offline_notice')), findsOneWidget);
    });

    testWidgets('CTA stays disabled until a title and a bracket are chosen', (tester) async {
      await pumpStudio(tester);
      expect(find.byKey(const Key('begin_duels_button')), findsNothing);

      await searchAndPick(tester, 'bear', 'search_result_tv_136315');
      expect(find.text('Selected: THE BEAR (2022)'), findsOneWidget);
      expect(cta(tester).onPressed, isNull, reason: 'no bracket yet');

      await tester.tap(find.byKey(const Key('bracket_loved')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bracket_selected_check')), findsOneWidget);
      expect(cta(tester).onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('begin_duels_button')));
      await tester.pumpAndSettle();
      expect(find.text('route:/log/duel'), findsOneWidget);
    });

    testWidgets('a series shows the 4 series statuses and the 4 SCR-09 bracket cards', (tester) async {
      await pumpStudio(tester);
      await searchAndPick(tester, 'bear', 'search_result_tv_136315');
      for (final s in ['finished', 'upToDate', 'season', 'dropped']) {
        expect(find.byKey(Key('status_$s')), findsOneWidget, reason: s);
      }
      expect(find.byKey(const Key('status_firstTime')), findsNothing);
      expect(find.text('👑 Masterpiece / Top 10%'), findsOneWidget);
      expect(find.text('🤷 Meh / Bottom 25%'), findsOneWidget);
      expect(find.byKey(const Key('bracket_regret')), findsNothing);
    });

    testWidgets('a movie selection shows movie statuses only', (tester) async {
      await pumpStudio(tester);
      await searchAndPick(tester, 'incep', 'search_result_movie_27205');
      expect(find.byKey(const Key('status_firstTime')), findsOneWidget);
      expect(find.byKey(const Key('status_rewatch')), findsOneWidget);
      for (final s in ['finished', 'upToDate', 'season', 'dropped']) {
        expect(find.byKey(Key('status_$s')), findsNothing, reason: s);
      }
    });

    testWidgets('Watched Specific Season exposes a season stepper', (tester) async {
      await pumpStudio(tester);
      await searchAndPick(tester, 'bear', 'search_result_tv_136315');
      expect(find.byKey(const Key('season_label')), findsNothing);
      await tester.tap(find.byKey(const Key('status_season')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('season_increment')));
      await tester.pumpAndSettle();
      expect(find.text('Season 2'), findsOneWidget);
    });

    testWidgets('Dropped routes to the Graveyard sheet, then to SCR-18', (tester) async {
      await pumpStudio(tester);
      await searchAndPick(tester, 'bear', 'search_result_tv_136315');
      await tester.tap(find.byKey(const Key('status_dropped')));
      await tester.pumpAndSettle();
      expect(find.text('🪦 Bury in The TV Graveyard'), findsOneWidget);

      await tester.ensureVisible(find.text('🪦 Bury in The TV Graveyard'));
      await tester.tap(find.text('🪦 Bury in The TV Graveyard'));
      await tester.pumpAndSettle();
      expect(find.text('route:/canon/graveyard'), findsOneWidget);
      expect(graveyard.shows.single.titleId, 136315, reason: 'persisted to user_dropped_shows');
    });

    testWidgets('Change returns to search with the previous results', (tester) async {
      await pumpStudio(tester);
      await searchAndPick(tester, 'bear', 'search_result_tv_136315');
      await tester.tap(find.byKey(const Key('logging_change_title')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('search_result_tv_136315')), findsOneWidget);
    });
  });
}
