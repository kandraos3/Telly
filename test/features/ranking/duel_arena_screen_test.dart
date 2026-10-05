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
import 'package:telly_app/features/ranking/presentation/widgets/duel_arena_card.dart';

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

    testWidgets('FE-GESTURE-01: dragging card A moves only card A; card B and the VS badge stay put', (tester) async {
      final r = request(101, 'The Bear');
      await pumpArena(tester, candidate: r);
      final cardA = find.byKey(const Key('candidate_card_a'));
      final cardB = find.byKey(const Key('candidate_card_b'));
      final badge = find.byKey(const Key('duel_vs_badge'));
      final a0 = tester.getCenter(cardA), b0 = tester.getCenter(cardB), v0 = tester.getCenter(badge);

      final gesture = await tester.startGesture(a0);
      await gesture.moveBy(const Offset(0, -20)); // clears the drag slop
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();

      expect(tester.getCenter(cardA).dy, lessThan(a0.dy - 40));
      expect(tester.getCenter(cardB), b0);
      expect(tester.getCenter(badge), v0);
      // The idle card dims and the dragged card glows lime as the swipe builds.
      final dimmed = tester.widget<Opacity>(find.ancestor(of: cardB, matching: find.byType(Opacity)).first);
      expect(dimmed.opacity, lessThan(1));
      final glowing = tester.widget<DuelArenaCard>(cardA);
      expect(glowing.dragHighlight, greaterThan(0));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getCenter(cardA), a0, reason: 'short swipe springs back');
    });

    testWidgets('FE-GESTURE-01: a card cannot be dragged against its pick direction', (tester) async {
      final r = request(101, 'The Bear');
      final c = await pumpArena(tester, candidate: r);
      final cardA = find.byKey(const Key('candidate_card_a'));
      final cardB = find.byKey(const Key('candidate_card_b'));
      final a0 = tester.getCenter(cardA), b0 = tester.getCenter(cardB);

      final down = await tester.startGesture(a0);
      await down.moveBy(const Offset(0, 20));
      await down.moveBy(const Offset(0, 140));
      await tester.pump();
      expect(tester.getCenter(cardA), a0, reason: 'card A only rises');
      expect(tester.getCenter(cardB), b0, reason: 'card B is untouched by a drag on card A');
      await down.up();
      await tester.pumpAndSettle();
      expect(stateOf(c, r), isA<DuelActive>(), reason: 'dragging A downward never picks B');

      await tester.drag(cardB, const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(stateOf(c, r), isA<DuelActive>(), reason: 'dragging B upward never picks A');
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
