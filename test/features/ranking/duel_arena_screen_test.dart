import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/ranking/presentation/controllers/duel_controller.dart';
import 'package:telly_app/features/ranking/presentation/screens/duel_arena_screen.dart';

void main() {
  late AppDatabase db;
  late LocalRankingDao rankingDao;

  setUp(() {
    db = AppDatabase.inMemory();
    rankingDao = db.localRankingDao;
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestArena({
    required DuelController controller,
    VoidCallback? onCancel,
    VoidCallback? onComplete,
  }) {
    return ProviderScope(
      overrides: [
        duelControllerProvider.overrideWith((ref) => controller),
        hapticsEnabledProvider.overrideWith((ref) => false),
      ],
      child: MaterialApp(
        theme: TellyTheme.dark,
        home: DuelArenaScreen(
          onCancel: onCancel,
          onDuelComplete: onComplete,
        ),
      ),
    );
  }

  group('FE-201 / FE-202 / QA-204: SCR-10 DuelArenaScreen Widget & Gesture Tests', () {
    testWidgets('renders Candidate A, Candidate B, VS badge, step counter, and Can\'t Compare button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = DuelController(rankingDao: rankingDao);

      final candidate = LocalRanking(
        showId: 101,
        mediaType: 'tv',
        title: 'Severance',
        posterPath: '/severance.jpg',
        rankPosition: 0,
        calculatedScore: 0.0,
        syncStatus: 'PENDING',
        updatedAt: DateTime.now(),
      );

      final opponent = LocalRanking(
        showId: 102,
        mediaType: 'tv',
        title: 'Succession',
        posterPath: '/succession.jpg',
        rankPosition: 1,
        calculatedScore: 10.00,
        syncStatus: 'SYNCED',
        updatedAt: DateTime.now(),
      );

      await controller.initTournament(
        candidate: candidate,
        existingCanon: [opponent],
      );

      await tester.pumpWidget(buildTestArena(controller: controller));
      await tester.pump();

      // Assert Candidate Card A and B
      expect(find.byKey(const Key('candidate_card_a')), findsOneWidget);
      expect(find.byKey(const Key('candidate_card_b')), findsOneWidget);
      expect(find.text('Severance'), findsOneWidget);
      expect(find.text('Succession'), findsOneWidget);

      // Assert VS Badge
      expect(find.byKey(const Key('duel_vs_badge')), findsOneWidget);
      expect(find.text('━  VS  ━'), findsOneWidget);

      // Assert Step Counter
      expect(find.byKey(const Key('duel_step_counter_text')), findsOneWidget);
      expect(find.text('DUEL 1 OF 1'), findsOneWidget);

      // Assert Can't Compare button
      expect(find.byKey(const Key('cant_compare_button')), findsOneWidget);
    });

    testWidgets('Tapping Candidate Card A selects Card A as winner and completes duel', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = DuelController(rankingDao: rankingDao);

      final candidate = LocalRanking(
        showId: 101,
        mediaType: 'tv',
        title: 'The Bear',
        posterPath: null,
        rankPosition: 0,
        calculatedScore: 0.0,
        syncStatus: 'PENDING',
        updatedAt: DateTime.now(),
      );

      final opponent = LocalRanking(
        showId: 102,
        mediaType: 'tv',
        title: 'Fleabag',
        posterPath: null,
        rankPosition: 1,
        calculatedScore: 10.00,
        syncStatus: 'SYNCED',
        updatedAt: DateTime.now(),
      );

      await controller.initTournament(
        candidate: candidate,
        existingCanon: [opponent],
      );

      bool completeCalled = false;
      await tester.pumpWidget(buildTestArena(
        controller: controller,
        onComplete: () => completeCalled = true,
      ));
      await tester.pump();

      // Tap Candidate Card A
      await tester.tap(find.byKey(const Key('candidate_card_a')));
      // Pump past the 250ms animation delay
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(controller.state, isA<DuelComplete>());
      final complete = controller.state as DuelComplete;
      expect(complete.finalRank, equals(1)); // The Bear beat Fleabag -> Rank 1
      expect(completeCalled, isTrue);
    });

    testWidgets('Swiping UP selects Card A as winner', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = DuelController(rankingDao: rankingDao);

      final candidate = LocalRanking(
        showId: 101,
        mediaType: 'movie',
        title: 'Interstellar',
        posterPath: null,
        rankPosition: 0,
        calculatedScore: 0.0,
        syncStatus: 'PENDING',
        updatedAt: DateTime.now(),
      );

      final opponent = LocalRanking(
        showId: 102,
        mediaType: 'movie',
        title: 'Oppenheimer',
        posterPath: null,
        rankPosition: 1,
        calculatedScore: 10.00,
        syncStatus: 'SYNCED',
        updatedAt: DateTime.now(),
      );

      await controller.initTournament(
        candidate: candidate,
        existingCanon: [opponent],
      );

      await tester.pumpWidget(buildTestArena(controller: controller));
      await tester.pump();

      // Swipe UP with offset -150 (> 100 threshold)
      await tester.drag(find.byKey(const Key('candidate_card_a')), const Offset(0, -150));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(controller.state, isA<DuelComplete>());
      final complete = controller.state as DuelComplete;
      expect(complete.finalRank, equals(1));
    });

    testWidgets('Swiping DOWN selects Card B (opponent) as winner', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = DuelController(rankingDao: rankingDao);

      final candidate = LocalRanking(
        showId: 101,
        mediaType: 'movie',
        title: 'Interstellar',
        posterPath: null,
        rankPosition: 0,
        calculatedScore: 0.0,
        syncStatus: 'PENDING',
        updatedAt: DateTime.now(),
      );

      final opponent = LocalRanking(
        showId: 102,
        mediaType: 'movie',
        title: 'Oppenheimer',
        posterPath: null,
        rankPosition: 1,
        calculatedScore: 10.00,
        syncStatus: 'SYNCED',
        updatedAt: DateTime.now(),
      );

      await controller.initTournament(
        candidate: candidate,
        existingCanon: [opponent],
      );

      await tester.pumpWidget(buildTestArena(controller: controller));
      await tester.pump();

      // Swipe DOWN with offset +150 (> 100 threshold)
      await tester.drag(find.byKey(const Key('candidate_card_b')), const Offset(0, 150));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(controller.state, isA<DuelComplete>());
      final complete = controller.state as DuelComplete;
      expect(complete.finalRank, equals(2)); // Opponent won -> Rank 2
    });

    testWidgets('Drag < 50 dp snaps back with spring physics without selecting a winner', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = DuelController(rankingDao: rankingDao);

      final candidate = LocalRanking(
        showId: 101,
        mediaType: 'movie',
        title: 'Interstellar',
        posterPath: null,
        rankPosition: 0,
        calculatedScore: 0.0,
        syncStatus: 'PENDING',
        updatedAt: DateTime.now(),
      );

      final opponent = LocalRanking(
        showId: 102,
        mediaType: 'movie',
        title: 'Oppenheimer',
        posterPath: null,
        rankPosition: 1,
        calculatedScore: 10.00,
        syncStatus: 'SYNCED',
        updatedAt: DateTime.now(),
      );

      await controller.initTournament(
        candidate: candidate,
        existingCanon: [opponent],
      );

      await tester.pumpWidget(buildTestArena(controller: controller));
      await tester.pump();

      // Drag with small offset 30 dp (< 100 threshold)
      await tester.drag(find.byKey(const Key('candidate_card_a')), const Offset(0, 30));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // State remains DuelActive (no winner selected)
      expect(controller.state, isA<DuelActive>());
    });

    testWidgets('Tapping Can\'t Compare / Equal button triggers skipOrTie', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = DuelController(rankingDao: rankingDao);

      final candidate = LocalRanking(
        showId: 101,
        mediaType: 'movie',
        title: 'Interstellar',
        posterPath: null,
        rankPosition: 0,
        calculatedScore: 0.0,
        syncStatus: 'PENDING',
        updatedAt: DateTime.now(),
      );

      final opponent = LocalRanking(
        showId: 102,
        mediaType: 'movie',
        title: 'Oppenheimer',
        posterPath: null,
        rankPosition: 1,
        calculatedScore: 10.00,
        syncStatus: 'SYNCED',
        updatedAt: DateTime.now(),
      );

      await controller.initTournament(
        candidate: candidate,
        existingCanon: [opponent],
      );

      await tester.pumpWidget(buildTestArena(controller: controller));
      await tester.pump();

      // Tap Can't Compare button
      await tester.tap(find.byKey(const Key('cant_compare_button')));
      await tester.pumpAndSettle();

      // In a 1-item canon, tie completes adjacent immediately
      expect(controller.state, isA<DuelComplete>());
    });
  });
}
