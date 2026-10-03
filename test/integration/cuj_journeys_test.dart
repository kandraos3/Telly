import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/network/offline_sync_manager.dart';
import 'package:telly_app/features/cowatch/domain/two_to_watch_engine.dart';
import 'package:telly_app/features/ranking/domain/binary_insertion_tournament.dart';
import 'package:telly_app/features/ranking/domain/score_curve_calculator.dart';
import 'package:telly_app/features/ranking/domain/sentiment_bracket.dart';

void main() {
  group('Critical User Journeys E2E Integration Suite (QA-501)', () {
    // -------------------------------------------------------------------------
    // CUJ-01: Cold-Start Onboarding to Canon Calibration
    // -------------------------------------------------------------------------
    test('CUJ-01: Cold-Start Onboarding to Canon Calibration', () async {
      // 1. User picks 8 seed titles
      final seedTitles = [
        'Succession',
        'Severance',
        'The Bear',
        'Breaking Bad',
        'Better Call Saul',
        'The Sopranos',
        'The Wire',
        'Mad Men',
      ];
      expect(seedTitles.length, equals(8));

      // 2. Tournament initiates with logarithmic comparisons O(log N)
      final rankedList = <String>[seedTitles.first];

      for (int i = 1; i < seedTitles.length; i++) {
        final title = seedTitles[i];
        var tournament = BinaryInsertionTournament<String>(
          existingCanon: rankedList,
          candidate: title,
        );

        while (!tournament.isComplete) {
          final opponent = tournament.currentOpponent!;
          // Deterministic user preference: earlier in alphabetical order wins
          if (title.compareTo(opponent) < 0) {
            tournament = tournament.onCandidateWins();
          } else {
            tournament = tournament.onOpponentWins();
          }
        }

        rankedList.insert(tournament.insertionIndex!, title);
      }

      // 3. Canon reveal & score calculation
      expect(rankedList.length, equals(8));
      final scoreRank1 = ScoreCurveCalculator.calculateScore(
        1,
        rankedList.length,
        applyBayesianPrior: false,
      );
      final scoreRank8 = ScoreCurveCalculator.calculateScore(
        8,
        rankedList.length,
        applyBayesianPrior: false,
      );

      expect(scoreRank1, equals(10.00));
      expect(scoreRank8, equals(1.00));
    });

    // -------------------------------------------------------------------------
    // CUJ-02: Complete Movie Logging & Slot Insertion
    // -------------------------------------------------------------------------
    test('CUJ-02: Log Movie, Head-to-Head Duels & Slot Insertion', () async {
      final existingCanon = List.generate(25, (i) => 'Existing Movie #${i + 1}');
      const newMovie = 'Dune: Part Two';

      // 1. Initial tier: User selects Masterpiece bracket
      var tournament = BinaryInsertionTournament<String>(
        existingCanon: existingCanon,
        candidate: newMovie,
        seedBracket: SentimentBracket.masterpiece,
      );

      int duelCount = 0;
      while (!tournament.isComplete) {
        duelCount++;
        // User prefers Dune: Part Two over all opponents
        tournament = tournament.onCandidateWins();
      }

      // Assert logarithmic bounded comparisons (ceil(log2(rangeSize+1)) <= 4)
      expect(duelCount, lessThanOrEqualTo(4));
      expect(tournament.insertionIndex, equals(0)); // Wins and lands at #1

      // Insert into canon
      existingCanon.insert(tournament.insertionIndex!, newMovie);
      expect(existingCanon.first, equals('Dune: Part Two'));
      expect(existingCanon.length, equals(26));

      // Recalculate dynamic scores
      final topScore = ScoreCurveCalculator.calculateScore(
        1,
        existingCanon.length,
        applyBayesianPrior: false,
      );
      final secondScore = ScoreCurveCalculator.calculateScore(
        2,
        existingCanon.length,
        applyBayesianPrior: false,
      );
      expect(topScore, equals(10.00));
      expect(secondScore, lessThan(10.00));
    });

    // -------------------------------------------------------------------------
    // CUJ-03: Two-to-Watch Co-Watching Decider with Filters & Quick Swipe
    // -------------------------------------------------------------------------
    test('CUJ-03: Two-to-Watch Decider Candidate Selection & Match', () async {
      final candidates = [
        const CoWatchCandidate(
          showId: 1,
          title: 'Past Lives',
          mediaType: 'movie',
          runtimeMinutes: 106,
          network: 'A24',
          availableProviders: ['netflix', 'max'],
          inWatchlistA: true,
        ),
        const CoWatchCandidate(
          showId: 2,
          title: 'Run Lola Run',
          mediaType: 'movie',
          runtimeMinutes: 81,
          network: 'Sony Pictures Classics',
          availableProviders: ['max'],
          inWatchlistA: true,
          inWatchlistB: true,
        ),
        const CoWatchCandidate(
          showId: 3,
          title: 'Oppenheimer',
          mediaType: 'movie',
          runtimeMinutes: 180,
          network: 'Universal',
          availableProviders: ['prime_video'],
          inWatchlistA: true,
        ),
        const CoWatchCandidate(
          showId: 4,
          title: 'Severance',
          mediaType: 'tv',
          runtimeMinutes: 50,
          network: 'Apple TV+',
          availableProviders: ['apple_tv_plus'],
          inWatchlistB: true,
        ),
      ];

      final providersA = {'netflix', 'max'};
      final providersB = {'netflix', 'max', 'hulu'};
      final sharedProviders = TwoToWatchEngine.computeSharedProviders(
        providersA: providersA,
        providersB: providersB,
      );
      expect(sharedProviders, containsAll(['netflix', 'max']));

      // Filter: Format = Movie Night, runtime < 90m (Breezy)
      final recommendations = TwoToWatchEngine.scoreCandidates(
        candidates: candidates,
        activeSharedProviders: sharedProviders,
        format: CoWatchFormat.movieNight,
        runtimeBudget: RuntimeBudget.breezy,
      );

      expect(recommendations.length, equals(1));
      expect(recommendations.first.candidate.title, equals('Run Lola Run'));
      expect(recommendations.first.candidate.runtimeMinutes, equals(81));

      // Simulate mutual right swipe
      final userASwipedRight = recommendations.any((r) => r.candidate.showId == 2);
      const userBSwipedRight = true;
      final isMatch = userASwipedRight && userBSwipedRight;

      expect(isMatch, isTrue);
    });

    // -------------------------------------------------------------------------
    // CUJ-04: Airplane Mode Offline Logging & Sync Resilience
    // -------------------------------------------------------------------------
    test('CUJ-04: Airplane Mode Offline WAL Persistence & Reconnect Flush', () async {
      final flushedEntries = <OfflineDuelEntry>[];

      // 1. Initialize offline manager in airplane mode
      final syncManager = OfflineSyncManager(
        initialOnlineState: false,
        onSyncEntry: (entry) async {
          flushedEntries.add(entry);
          return true;
        },
      );

      expect(syncManager.isOnline, isFalse);

      // 2. Perform 3 offline duel mutations
      await syncManager.enqueueDuel(
        winnerTitleId: 76331,
        loserTitleId: 110492,
        mediaType: 'tv',
        roundNumber: 1,
      );
      await syncManager.enqueueDuel(
        winnerTitleId: 110492,
        loserTitleId: 85937,
        mediaType: 'tv',
        roundNumber: 2,
      );
      await syncManager.enqueueDuel(
        winnerTitleId: 85937,
        loserTitleId: 94997,
        mediaType: 'tv',
        roundNumber: 3,
      );

      expect(syncManager.pendingCount, equals(3));
      expect(flushedEntries, isEmpty);

      // 3. Reconnect to network (setOnlineStatus automatically flushes queue)
      await syncManager.setOnlineStatus(true);
      expect(syncManager.isOnline, isTrue);

      expect(syncManager.pendingCount, equals(0));
      expect(flushedEntries.length, equals(3));
      expect(flushedEntries[0].winnerTitleId, equals(76331));
      expect(flushedEntries[1].winnerTitleId, equals(110492));
      expect(flushedEntries[2].winnerTitleId, equals(85937));
    });
  });
}
