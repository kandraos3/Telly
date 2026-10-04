import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/logging/domain/watch_status.dart';
import 'package:telly_app/features/ranking/data/ranking_repository.dart';
import 'package:telly_app/features/ranking/domain/sentiment_bracket.dart';
import 'package:telly_app/features/ranking/presentation/controllers/duel_controller.dart';
import 'package:telly_app/features/ranking/presentation/screens/duel_arena_screen.dart';

import '../../helpers/canon_seed.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  DuelRequest request(int id, String title) => DuelRequest(
        candidate: CanonCandidate(titleId: id, mediaType: 'tv', title: title),
        bracket: SentimentBracket.masterpiece,
        status: WatchStatus.finished,
      );

  /// Pumps the arena for [candidate] against a one-title canon and returns its container.
  Future<ProviderContainer> pumpArena(
    WidgetTester tester, {
    required DuelRequest candidate,
    String opponent = 'Succession',
    ValueChanged<DuelComplete>? onComplete,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await seedCanon(db, 'tv', [opponent], baseId: 102);

    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      hapticsEnabledProvider.overrideWith((ref) => false),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: TellyTheme.dark,
        home: DuelArenaScreen(request: candidate, onDuelComplete: onComplete),
      ),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  DuelState stateOf(ProviderContainer c, DuelRequest r) => c.read(duelControllerProvider(r));

  group('FE-201 / FE-202 / QA-204 / FE-604: SCR-10 DuelArenaScreen', () {
    testWidgets("renders both cards, VS badge, step counter and Can't Compare", (tester) async {
      await pumpArena(tester, candidate: request(101, 'Severance'));

      expect(find.byKey(const Key('candidate_card_a')), findsOneWidget);
      expect(find.byKey(const Key('candidate_card_b')), findsOneWidget);
      expect(find.text('Severance'), findsOneWidget);
      expect(find.text('Succession'), findsOneWidget);
      expect(find.byKey(const Key('duel_vs_badge')), findsOneWidget);
      expect(find.text('━  VS  ━'), findsOneWidget);
      expect(find.text('DUEL 1 OF 1'), findsOneWidget);
      expect(find.byKey(const Key('cant_compare_button')), findsOneWidget);
    });

    testWidgets('tapping card A picks the candidate, commits rank #1 and reports completion', (tester) async {
      final r = request(101, 'The Bear');
      DuelComplete? completed;
      final c = await pumpArena(tester, candidate: r, opponent: 'Fleabag', onComplete: (d) => completed = d);

      await tester.tap(find.byKey(const Key('candidate_card_a')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      final done = stateOf(c, r) as DuelComplete;
      expect(done.finalRank, 1);
      expect(completed?.finalRank, 1);
      expect((await db.localRankingDao.getRankingsByCanon('tv')).map((e) => e.title), ['The Bear', 'Fleabag']);
    });

    testWidgets('swiping UP selects card A', (tester) async {
      final r = request(101, 'The Bear');
      final c = await pumpArena(tester, candidate: r);
      await tester.drag(find.byKey(const Key('candidate_card_a')), const Offset(0, -150));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect((stateOf(c, r) as DuelComplete).finalRank, 1);
    });

    testWidgets('swiping DOWN selects card B (the opponent)', (tester) async {
      final r = request(101, 'The Bear');
      final c = await pumpArena(tester, candidate: r);
      await tester.drag(find.byKey(const Key('candidate_card_b')), const Offset(0, 150));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect((stateOf(c, r) as DuelComplete).finalRank, 2);
    });

    testWidgets('a short drag springs back without selecting', (tester) async {
      final r = request(101, 'The Bear');
      final c = await pumpArena(tester, candidate: r);
      await tester.drag(find.byKey(const Key('candidate_card_a')), const Offset(0, 30));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(stateOf(c, r), isA<DuelActive>());
    });

    testWidgets("Can't Compare / Equal advances without a duel", (tester) async {
      final r = request(101, 'The Bear');
      final c = await pumpArena(tester, candidate: r);
      await tester.tap(find.byKey(const Key('cant_compare_button')));
      await tester.pumpAndSettle();
      expect(stateOf(c, r), isA<DuelComplete>());
    });
  });
}
