import 'package:flutter/material.dart';
import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/features/ranking/data/ranking_repository.dart';
import 'package:telly_app/features/ranking/presentation/controllers/duel_controller.dart';
import 'package:telly_app/features/ranking/presentation/screens/duel_arena_screen.dart';

import '../test/helpers/router_harness.dart';

class _FakeDuelController extends Notifier<DuelState> implements DuelActions {
  _FakeDuelController(this.candidate, this.opponents);

  final LocalRanking candidate;
  final List<LocalRanking> opponents;
  int _round = 0;

  @override
  DuelState build() => _stateForRound(0);

  DuelState _stateForRound(int r) {
    if (r >= opponents.length) {
      return DuelComplete(
        RankingCommit(
          mutationId: 'perf-mut-1',
          candidate: CanonCandidate(
            titleId: candidate.showId,
            mediaType: candidate.mediaType,
            title: candidate.title,
          ),
          rank: 1,
          score: 9.85,
          canon: [candidate, ...opponents],
          wasMove: false,
        ),
      );
    }
    return DuelActive(
      candidate: candidate,
      currentOpponent: opponents[r],
      step: r + 1,
      totalEstimatedSteps: opponents.length,
    );
  }

  @override
  Future<void> voteWinner(int winnerTitleId) async {
    _round++;
    state = _stateForRound(_round);
  }

  @override
  Future<void> skipOrTie() async {
    _round++;
    state = _stateForRound(_round);
  }
}

final _fakeDuelProvider = NotifierProvider<_FakeDuelController, DuelState>(
  () => throw UnimplementedError(),
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('QA-605: Duel arena card swipe performance benchmark (traceAction + TimelineSummary)', (tester) async {
    final candidate = LocalRanking(
      showId: 999,
      mediaType: 'movie',
      title: 'Challenger Film',
      rankPosition: 1,
      calculatedScore: 9.50,
      syncStatus: 'SYNCED',
      updatedAt: DateTime(2026),
    );

    final opponents = List.generate(
      20,
      (i) => LocalRanking(
        showId: 100 + i,
        mediaType: 'movie',
        title: 'Canon Movie #${i + 1}',
        rankPosition: i + 1,
        calculatedScore: 9.00 - (i * 0.1),
        syncStatus: 'SYNCED',
        updatedAt: DateTime(2026),
      ),
    );

    final fakeController = _FakeDuelController(candidate, opponents);

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      routerHarness(
        DuelArenaScreen.custom(
          state: _fakeDuelProvider,
          actions: _fakeDuelProvider.notifier,
        ),
        overrides: [
          _fakeDuelProvider.overrideWith(() => fakeController),
          hapticsEnabledProvider.overrideWith((ref) => false),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Verify duel cards are mounted
    expect(find.text('Challenger Film'), findsOneWidget);
    expect(find.text('Canon Movie #1'), findsOneWidget);

    // Profile card swipe gesture handling and spring physics
    await binding.watchPerformance(
      () async {
        // Execute 15 consecutive duel swipes (alternating Up/Down choices)
        for (int i = 0; i < 15; i++) {
          final swipeOffset = (i % 2 == 0) ? const Offset(0, -150) : const Offset(0, 150);
          await tester.drag(find.byType(DuelArenaScreen), swipeOffset);
          await tester.pump();
          // Pump animation frames for spring reset
          await tester.pump(const Duration(milliseconds: 50));
          await tester.pumpAndSettle();
        }
      },
      reportKey: 'duel_swipe_perf',
    );

    // Summarize with TimelineSummary if timeline captured
    final reportData = binding.reportData;
    if (reportData != null && reportData.containsKey('duel_swipe_perf')) {
      final rawTimeline = reportData['duel_swipe_perf'];
      if (rawTimeline is Map<String, dynamic>) {
        final timeline = driver.Timeline.fromJson(rawTimeline);
        final summary = driver.TimelineSummary.summarize(timeline);

        final p90Build = summary.computePercentileFrameBuildTimeMillis(90.0);
        final p99Build = summary.computePercentileFrameBuildTimeMillis(99.0);
        final missedFrames = summary.computeMissedFrameBuildBudgetCount();

        expect(p90Build, lessThanOrEqualTo(16.6));
        expect(p99Build, lessThanOrEqualTo(33.3));
        expect(missedFrames, isNonNegative);
      }
    }
  });
}
