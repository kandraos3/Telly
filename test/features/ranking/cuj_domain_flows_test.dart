import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/core/sync/connectivity_signal.dart';
import 'package:telly_app/core/sync/mutation_transport.dart';
import 'package:telly_app/core/sync/sync_engine.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/features/ranking/data/ranking_repository.dart';
import 'package:telly_app/features/cowatch/domain/two_to_watch_engine.dart';
import 'package:telly_app/features/ranking/domain/binary_insertion_tournament.dart';
import 'package:telly_app/features/ranking/domain/score_curve_calculator.dart';
import 'package:telly_app/features/ranking/domain/sentiment_bracket.dart';

import '../../fakes/fake_auth_repository.dart';

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
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final online = StreamController<bool>();
      addTearDown(online.close);
      final applied = <String>[];
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        connectivityProvider.overrideWith((ref) => online.stream),
        mutationTransportProvider.overrideWithValue(_RecordingTransport(applied)),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(
          signedInUserId: 'u1',
          profile: UserProfile(id: 'u1', username: 'maya', displayName: 'Maya', createdAt: DateTime(2026)),
        )),
      ]);
      addTearDown(container.dispose);
      container.listen(syncEngineProvider, (_, __) {});

      // 1. Airplane mode
      online.add(false);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // 2. Three offline logs: the canon updates instantly, mutations wait in the WAL
      final repo = container.read(rankingRepositoryProvider);
      final ids = <String>[];
      for (final (id, title) in [(76331, 'Succession'), (110492, 'Peacemaker'), (85937, 'Demon Slayer')]) {
        ids.add((await repo.commitPlacement(
          candidate: CanonCandidate(titleId: id, mediaType: 'tv', title: title),
          targetRank: 1,
        ))
            .mutationId);
      }
      expect((await repo.getCanon('tv')).map((r) => r.title), ['Demon Slayer', 'Peacemaker', 'Succession']);
      expect(await db.pendingMutationDao.count(), 3);
      expect(applied, isEmpty);

      // 3. Reconnect: the queue flushes in order and the canon is marked synced
      online.add(true);
      // A loaded CI runner can take seconds: wait on the condition with a generous deadline and
      // stop as soon as it holds (#157, as #123 did for the emulator suite).
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (applied.length < 3 && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(applied, ids);
      expect(await db.pendingMutationDao.count(), 0);
      expect((await repo.getCanon('tv')).every((r) => r.syncStatus == 'SYNCED'), isTrue);
    });
  });
}

class _RecordingTransport implements MutationTransport {
  _RecordingTransport(this.applied);
  final List<String> applied;

  @override
  Future<void> apply(PendingMutation mutation) async => applied.add(mutation.id);
}
