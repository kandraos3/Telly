import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/features/logging/domain/watch_status.dart';
import 'package:telly_app/features/ranking/data/ranking_repository.dart';
import 'package:telly_app/features/ranking/domain/editorial_tagging.dart';
import 'package:telly_app/features/ranking/domain/sentiment_bracket.dart';
import 'package:telly_app/features/ranking/presentation/controllers/duel_controller.dart';

import '../../helpers/canon_seed.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.inMemory();
    container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  DuelRequest request(int id, String mediaType, {SentimentBracket bracket = SentimentBracket.liked}) => DuelRequest(
        candidate: CanonCandidate(titleId: id, mediaType: mediaType, title: 'Candidate $id'),
        bracket: bracket,
        status: WatchStatus.defaultFor(mediaType),
      );

  /// Waits until the controller leaves its loading/committing states.
  Future<DuelState> settle(DuelRequest r) async {
    for (var i = 0; i < 100; i++) {
      final s = container.read(duelControllerProvider(r));
      if (s is! DuelInitial && s is! DuelResolving) return s;
      await Future<void>.delayed(Duration.zero);
    }
    return container.read(duelControllerProvider(r));
  }

  /// Subscribes (keeping the auto-dispose family alive) and waits for the first duel.
  Future<DuelState> start(DuelRequest r) {
    container.listen(duelControllerProvider(r), (_, __) {});
    return settle(r);
  }

  DuelController controller(DuelRequest r) => container.read(duelControllerProvider(r).notifier);

  group('FE-604: DuelController + RankingRepository', () {
    test('first title (N = 0) commits rank #1 / 10.00 with no duels and one pending mutation', () async {
      final done = await start(request(101, 'tv')) as DuelComplete;

      expect(done.finalRank, 1);
      expect(done.finalScore, 10.00);
      final canon = await db.localRankingDao.getRankingsByCanon('tv');
      expect(canon.single.showId, 101);
      expect(canon.single.syncStatus, 'PENDING');

      final queue = await db.pendingMutationDao.getAllFifo();
      expect(queue.single.kind, MutationKind.logTitle);
      final payload = jsonDecode(queue.single.payload) as Map<String, dynamic>;
      expect(payload['target_rank'], 1);
      expect(payload['status'], 'COMPLETED');
      expect(payload['duels'], isEmpty);
    });

    test('full log flow writes 1 ranking + N duels in 1 pending mutation atomically', () async {
      await seedCanon(db, 'tv', [for (var i = 1; i <= 20; i++) 'Show $i']);
      final r = request(999, 'tv', bracket: SentimentBracket.loved);
      var state = await start(r);

      final votes = <(int, int)>[];
      var candidateWins = true;
      while (state is DuelActive) {
        final opponent = state.currentOpponent.showId;
        votes.add(candidateWins ? (999, opponent) : (opponent, 999));
        await controller(r).voteWinner(candidateWins ? 999 : opponent);
        candidateWins = !candidateWins;
        state = await settle(r);
      }
      final done = state as DuelComplete;
      expect(votes, isNotEmpty);

      final canon = await db.localRankingDao.getRankingsByCanon('tv');
      expect(canon, hasLength(21));
      expect(canon.map((e) => e.rankPosition), List.generate(21, (i) => i + 1));
      expect(canon[done.finalRank - 1].showId, 999);
      expect(canon.where((e) => e.syncStatus == 'PENDING').map((e) => e.showId), [999]);

      final queue = await db.pendingMutationDao.getAllFifo();
      expect(queue, hasLength(1));
      final payload = jsonDecode(queue.single.payload) as Map<String, dynamic>;
      expect(payload['title_id'], 999);
      expect(payload['media_type'], 'tv');
      expect(payload['target_rank'], done.finalRank);
      final duels = (payload['duels'] as List).cast<Map<String, dynamic>>();
      expect(duels.map((d) => (d['winner_title_id'], d['loser_title_id'])), votes);
      expect(duels.map((d) => d['client_mutation_id']).toSet(), hasLength(votes.length));
      expect(duels.every((d) => d['media_type'] == 'tv'), isTrue);
    });

    test('a movie duel never loads tv opponents', () async {
      await seedCanon(db, 'tv', [for (var i = 1; i <= 10; i++) 'Series $i'], baseId: 100);
      await seedCanon(db, 'movie', [for (var i = 1; i <= 6; i++) 'Movie $i'], baseId: 500);
      final r = request(777, 'movie', bracket: SentimentBracket.liked);
      var state = await start(r);

      final seen = <String>[];
      while (state is DuelActive) {
        seen.add(state.currentOpponent.mediaType);
        expect(state.currentOpponent.showId, inInclusiveRange(500, 505));
        await controller(r).voteWinner(state.currentOpponent.showId);
        state = await settle(r);
      }
      expect(seen, isNotEmpty);
      expect(seen.toSet(), {'movie'});
      expect(await db.localRankingDao.getRankingsByCanon('tv'), hasLength(10));
      expect(await db.localRankingDao.getRankingsByCanon('movie'), hasLength(7));
    });

    test("Can't Compare records no duel", () async {
      await seedCanon(db, 'tv', ['A', 'B']);
      final r = request(42, 'tv', bracket: SentimentBracket.masterpiece);
      var state = await start(r);
      while (state is DuelActive) {
        await controller(r).skipOrTie();
        state = await settle(r);
      }
      expect(state, isA<DuelComplete>());
      final payload = jsonDecode((await db.pendingMutationDao.getAllFifo()).single.payload) as Map<String, dynamic>;
      expect(payload['duels'], isEmpty);
    });

    test('re-dueling a ranked title (Reset Duels) excludes it from opponents and commits a move', () async {
      await seedCanon(db, 'tv', ['A', 'B', 'C', 'D'], baseId: 1);
      await container.read(rankingRepositoryProvider).attachEditorial(
            titleId: 2,
            mediaType: 'tv',
            data: const EditorialTaggingData(mvpCharacter: 'Helly R.'),
          );
      for (final m in await db.pendingMutationDao.getAllFifo()) {
        await db.pendingMutationDao.remove(m.id);
      }

      const r = DuelRequest(
        candidate: CanonCandidate(titleId: 2, mediaType: 'tv', title: 'B'),
        bracket: SentimentBracket.masterpiece,
        status: WatchStatus.finished,
      );
      var state = await start(r);
      while (state is DuelActive) {
        expect(state.currentOpponent.showId, isNot(2));
        await controller(r).voteWinner(2);
        state = await settle(r);
      }
      final done = state as DuelComplete;
      expect(done.commit.wasMove, isTrue);
      expect(done.finalRank, 1);

      final canon = await db.localRankingDao.getRankingsByCanon('tv');
      expect(canon.map((e) => e.showId), [2, 1, 3, 4]);
      expect(canon.first.favoriteCharacter, 'Helly R.', reason: 'notes survive a reset');
      final queue = await db.pendingMutationDao.getAllFifo();
      expect(queue.single.kind, MutationKind.move);
      expect((jsonDecode(queue.single.payload) as Map)['new_rank'], 1);
    });
  });
}
