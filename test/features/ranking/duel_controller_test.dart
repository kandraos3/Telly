import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/features/ranking/domain/canon_type.dart';
import 'package:telly_app/features/ranking/presentation/controllers/duel_controller.dart';

void main() {
  late AppDatabase db;
  late LocalRankingDao rankingDao;
  late DuelController controller;

  setUp(() {
    db = AppDatabase.inMemory();
    rankingDao = db.localRankingDao;
    controller = DuelController(rankingDao: rankingDao);
  });

  tearDown(() async {
    await db.close();
  });

  group('ALGO-205: DuelController Riverpod State Machine', () {
    test('Initial state is DuelInitial', () {
      expect(controller.state, isA<DuelInitial>());
    });

    test('initTournament with empty canon resolves immediately to Rank 1 and Score 10.00', () async {
      final candidate = LocalRanking(
        showId: 101,
        mediaType: 'tv',
        title: 'Succession',
        posterPath: null,
        rankPosition: 0,
        calculatedScore: 0.0,
        syncStatus: 'PENDING',
        updatedAt: DateTime.now(),
      );

      await controller.initTournament(
        candidate: candidate,
        existingCanon: [],
      );

      expect(controller.state, isA<DuelComplete>());
      final complete = controller.state as DuelComplete;
      expect(complete.finalRank, equals(1));
      expect(complete.finalScore, equals(10.00));
      expect(complete.insertedIndex, equals(0));
      expect(complete.updatedCanon.length, equals(1));

      // Verify persisted to local SQLite
      final inDb = await rankingDao.getRankingsByCanon('tv');
      expect(inDb.length, equals(1));
      expect(inDb.first.showId, equals(101));
      expect(inDb.first.rankPosition, equals(1));
    });

    test('initTournament rejects cross-canon pairing with CrossCanonDuelException', () async {
      final movieCandidate = LocalRanking(
        showId: 201,
        mediaType: 'movie',
        title: 'The Dark Knight',
        posterPath: null,
        rankPosition: 0,
        calculatedScore: 0.0,
        syncStatus: 'PENDING',
        updatedAt: DateTime.now(),
      );

      final seriesItem = LocalRanking(
        showId: 101,
        mediaType: 'tv',
        title: 'Succession',
        posterPath: null,
        rankPosition: 1,
        calculatedScore: 10.00,
        syncStatus: 'SYNCED',
        updatedAt: DateTime.now(),
      );

      expect(
        () => controller.initTournament(
          candidate: movieCandidate,
          existingCanon: [seriesItem],
        ),
        throwsA(isA<CrossCanonDuelException>()),
      );
    });

    test('Full multi-step tournament steps through duels and logs to offline queue', () async {
      // Setup 7 existing TV shows ranked 1 to 7
      final existingCanon = List.generate(7, (i) {
        return LocalRanking(
          showId: 100 + i,
          mediaType: 'tv',
          title: 'Existing Show #${i + 1}',
          posterPath: null,
          rankPosition: i + 1,
          calculatedScore: 10.00 - (i * 1.2),
          syncStatus: 'SYNCED',
          updatedAt: DateTime.now(),
        );
      });

      final newCandidate = LocalRanking(
        showId: 999,
        mediaType: 'tv',
        title: 'The Bear',
        posterPath: '/the_bear.jpg',
        rankPosition: 0,
        calculatedScore: 0.0,
        syncStatus: 'PENDING',
        updatedAt: DateTime.now(),
      );

      await controller.initTournament(
        candidate: newCandidate,
        existingCanon: existingCanon,
      );

      // Verify active state
      expect(controller.state, isA<DuelActive>());
      var active = controller.state as DuelActive;
      expect(active.candidate.showId, equals(999));
      expect(active.step, equals(1));

      // Vote 1: Candidate wins against midpoint (index 3: Existing Show #4)
      await controller.voteWinner(999);

      // Verify offline duel queue has 1 record
      var pendingDuels = await rankingDao.getPendingOfflineDuels();
      expect(pendingDuels.length, equals(1));
      expect(pendingDuels.first.winnerTitleId, equals(999));
      expect(pendingDuels.first.loserTitleId, equals(existingCanon[3].showId));

      // Vote 2: Opponent wins
      expect(controller.state, isA<DuelActive>());
      active = controller.state as DuelActive;
      await controller.voteWinner(active.currentOpponent.showId);

      pendingDuels = await rankingDao.getPendingOfflineDuels();
      expect(pendingDuels.length, equals(2));

      // Vote 3: Candidate wins
      expect(controller.state, isA<DuelActive>());
      active = controller.state as DuelActive;
      await controller.voteWinner(999);

      // After 3 comparisons on 7 items (ceil(log2(8)) = 3), tournament must complete!
      expect(controller.state, isA<DuelComplete>());
      final complete = controller.state as DuelComplete;
      expect(complete.candidate.showId, equals(999));
      expect(complete.updatedCanon.length, equals(8));

      // Verify all 8 ranks in SQLite are sequential from 1 to 8 with no duplicates
      final rankingsInDb = await rankingDao.getRankingsByCanon('tv');
      expect(rankingsInDb.length, equals(8));
      for (int i = 0; i < 8; i++) {
        expect(rankingsInDb[i].rankPosition, equals(i + 1));
        expect(rankingsInDb[i].calculatedScore, greaterThan(0.0));
      }
    });

    test('skipOrTie steps to neighbor and resolves adjacent on repeat tie', () async {
      final existingCanon = [
        LocalRanking(
          showId: 101,
          mediaType: 'movie',
          title: 'Movie 1',
          posterPath: null,
          rankPosition: 1,
          calculatedScore: 10.00,
          syncStatus: 'SYNCED',
          updatedAt: DateTime.now(),
        ),
        LocalRanking(
          showId: 102,
          mediaType: 'movie',
          title: 'Movie 2',
          posterPath: null,
          rankPosition: 2,
          calculatedScore: 5.50,
          syncStatus: 'SYNCED',
          updatedAt: DateTime.now(),
        ),
        LocalRanking(
          showId: 103,
          mediaType: 'movie',
          title: 'Movie 3',
          posterPath: null,
          rankPosition: 3,
          calculatedScore: 1.00,
          syncStatus: 'SYNCED',
          updatedAt: DateTime.now(),
        ),
      ];

      final candidate = LocalRanking(
        showId: 999,
        mediaType: 'movie',
        title: 'New Movie',
        posterPath: null,
        rankPosition: 0,
        calculatedScore: 0.0,
        syncStatus: 'PENDING',
        updatedAt: DateTime.now(),
      );

      await controller.initTournament(
        candidate: candidate,
        existingCanon: existingCanon,
      );

      expect(controller.state, isA<DuelActive>());

      // First tie: steps to neighbor
      await controller.skipOrTie();
      expect(controller.state, isA<DuelActive>());

      // Second tie: resolves adjacent
      await controller.skipOrTie();
      expect(controller.state, isA<DuelComplete>());
    });
  });
}
