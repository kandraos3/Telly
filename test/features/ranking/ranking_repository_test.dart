import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:telly_app/features/profile/presentation/controllers/profile_controller.dart';
import 'package:telly_app/features/ranking/data/canon_hydration.dart';
import 'package:telly_app/features/ranking/data/ranking_repository.dart';
import 'package:telly_app/features/ranking/domain/canon_type.dart';
import 'package:telly_app/features/ranking/domain/editorial_tagging.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../helpers/canon_seed.dart';

class FakeRemoteCanon implements RemoteCanonSource {
  FakeRemoteCanon(this.rows);
  final List<RemoteRanking> rows;
  final calls = <String>[];

  @override
  Future<List<RemoteRanking>> fetchMyCanon(String userId) async {
    calls.add(userId);
    return rows;
  }
}

void main() {
  late AppDatabase db;
  late RankingRepository repo;

  setUp(() {
    db = AppDatabase.inMemory();
    repo = RankingRepository(db);
  });
  tearDown(() => db.close());

  Future<List<int>> ids(String mediaType) async =>
      (await repo.getCanon(mediaType)).map((r) => r.showId).toList();
  Future<List<PendingMutation>> queue() => db.pendingMutationDao.getAllFifo();
  Map<String, dynamic> payloadOf(PendingMutation m) => jsonDecode(m.payload) as Map<String, dynamic>;

  group('FE-604: RankingRepository', () {
    test('move re-ranks, re-scores and queues a move mutation', () async {
      await seedCanon(db, 'tv', ['A', 'B', 'C', 'D'], baseId: 1);
      await repo.move(mediaType: 'tv', titleId: 4, newRank: 1);

      final canon = await repo.getCanon('tv');
      expect(canon.map((r) => r.showId), [4, 1, 2, 3]);
      expect(canon.map((r) => r.rankPosition), [1, 2, 3, 4]);
      expect(canon.first.calculatedScore, 10.00);
      expect(canon.first.syncStatus, 'PENDING');
      final m = (await queue()).single;
      expect(m.kind, MutationKind.move);
      expect(payloadOf(m), {'title_id': 4, 'media_type': 'tv', 'new_rank': 1});
    });

    test('FE-LOG-02: commitPlacement queues the broadcast choice with a new log', () async {
      await repo.commitPlacement(
        candidate: const CanonCandidate(titleId: 7, mediaType: 'tv', title: 'Quiet'),
        targetRank: 1,
        broadcast: false,
      );
      await repo.commitPlacement(
        candidate: const CanonCandidate(titleId: 8, mediaType: 'tv', title: 'Loud'),
        targetRank: 1,
      );
      final logs = (await queue()).where((m) => m.kind == MutationKind.logTitle).map(payloadOf).toList();
      expect(logs.map((p) => p['broadcast']), [false, true]);
    });

    test('#150: each duel names the title being placed, never an opponent', () async {
      await seedCanon(db, 'tv', ['A', 'B'], baseId: 1);
      await repo.commitPlacement(
        candidate: const CanonCandidate(titleId: 9, mediaType: 'tv', title: 'New'),
        targetRank: 2,
        duels: const [
          LoggedDuel(winnerTitleId: 1, loserTitleId: 9),
          LoggedDuel(winnerTitleId: 9, loserTitleId: 2),
          // Not involving the candidate: sent without a placed title, so the server's CHECK holds.
          LoggedDuel(winnerTitleId: 1, loserTitleId: 2),
        ],
      );
      final duels = (payloadOf((await queue()).single)['duels'] as List).cast<Map<String, dynamic>>();
      expect(duels.map((d) => d['placed_title_id']), [9, 9, null]);
      expect(duels.last.containsKey('placed_title_id'), isFalse);
    });

    test('FE-SHARE-01: leaderboard() centres a 5-row window and slides at the canon edges', () async {
      await seedCanon(db, 'tv', ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'], baseId: 1);
      Future<List<int>> windowFor(int titleId, int rank) async {
        final commit = await repo.commitPlacement(
          candidate: CanonCandidate(titleId: titleId, mediaType: 'tv', title: 'New $titleId'),
          targetRank: rank,
        );
        final rows = commit.leaderboard();
        expect(rows.where((r) => r.isNew).single.rank, rank);
        await repo.remove(mediaType: 'tv', titleId: titleId);
        return rows.map((r) => r.rank).toList();
      }

      expect(await windowFor(100, 5), [3, 4, 5, 6, 7], reason: 'two above, two below');
      expect(await windowFor(101, 1), [1, 2, 3, 4, 5], reason: 'top slides down');
      expect(await windowFor(102, 9), [5, 6, 7, 8, 9], reason: 'bottom slides up');
      expect(await windowFor(103, 2), [1, 2, 3, 4, 5]);
    });

    test('FE-SHARE-01: leaderboard() shows every row of a tiny canon', () async {
      await seedCanon(db, 'movie', ['Solo'], baseId: 1);
      final commit = await repo.commitPlacement(
        candidate: const CanonCandidate(titleId: 50, mediaType: 'movie', title: 'Duo'),
        targetRank: 2,
      );
      expect(commit.leaderboard().map((r) => (r.rank, r.title, r.isNew)), [(1, 'Solo', false), (2, 'Duo', true)]);
    });

    test('moving an unknown title is a no-op', () async {
      await seedCanon(db, 'tv', ['A'], baseId: 1);
      await repo.move(mediaType: 'tv', titleId: 99, newRank: 1);
      expect(await queue(), isEmpty);
    });

    test('remove closes the rank gap and queues a delete', () async {
      await seedCanon(db, 'movie', ['A', 'B', 'C'], baseId: 1);
      await repo.remove(mediaType: 'movie', titleId: 2);
      final canon = await repo.getCanon('movie');
      expect(canon.map((r) => (r.showId, r.rankPosition)), [(1, 1), (3, 2)]);
      expect((await queue()).single.kind, MutationKind.delete);
    });

    test('canons are partitioned: a tv move never touches the movie canon', () async {
      await seedCanon(db, 'tv', ['T1', 'T2'], baseId: 1);
      await seedCanon(db, 'movie', ['M1', 'M2'], baseId: 1); // same ids, other canon
      await repo.move(mediaType: 'tv', titleId: 2, newRank: 1);
      expect(await ids('tv'), [2, 1]);
      expect(await ids('movie'), [1, 2]);
    });

    test('attachEditorial stores the MVP locally and queues the editorial columns', () async {
      await seedCanon(db, 'movie', ['Oppenheimer'], baseId: 872585);
      await repo.attachEditorial(
        titleId: 872585,
        mediaType: 'movie',
        data: const EditorialTaggingData(
          viewingVenue: ViewingVenue.imax,
          vibeTags: ['Mind-Bending'],
          mvpCharacter: 'Cillian Murphy as J. Robert Oppenheimer',
          review: '  Loud. Perfect.  ',
        ),
      );
      expect((await repo.getCanon('movie')).single.favoriteCharacter, 'Cillian Murphy as J. Robert Oppenheimer');
      final m = (await queue()).single;
      expect(m.kind, MutationKind.editorial);
      expect(payloadOf(m), containsPair('venue', 'IMAX'));
      expect(payloadOf(m), containsPair('review_short', 'Loud. Perfect.'));
      expect(payloadOf(m), containsPair('tags', ['Mind-Bending']));
    });

    test('a failed queue write rolls the canon change back (one transaction)', () async {
      await seedCanon(db, 'tv', ['A', 'B'], baseId: 1);
      await db.customStatement(
        "CREATE TRIGGER fail_queue BEFORE INSERT ON pending_mutations BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );

      await expectLater(
        repo.commitPlacement(candidate: const CanonCandidate(titleId: 9, mediaType: 'tv', title: 'New'), targetRank: 1),
        throwsA(anything),
      );
      await expectLater(repo.move(mediaType: 'tv', titleId: 2, newRank: 1), throwsA(anything));

      final canon = await repo.getCanon('tv');
      expect(canon.map((r) => (r.showId, r.rankPosition, r.syncStatus)), [(1, 1, 'SYNCED'), (2, 2, 'SYNCED')]);
      expect(await queue(), isEmpty);
    });

    test('rejects media types outside the dual canon', () {
      expect(() => repo.move(mediaType: 'anime', titleId: 1, newRank: 1), throwsArgumentError);
    });

    test('pull-hydration replaces local canons when nothing is pending', () async {
      await seedCanon(db, 'tv', ['Stale'], baseId: 1);
      final replaced = await repo.replaceFromRemote(const [
        RemoteRanking(titleId: 1396, mediaType: 'tv', title: 'Breaking Bad', rank: 1, score: 10.0),
        RemoteRanking(titleId: 27205, mediaType: 'movie', title: 'Inception', rank: 1, score: 10.0),
        RemoteRanking(titleId: 1399, mediaType: 'tv', title: 'Game of Thrones', rank: 2, score: 9.1),
      ]);
      expect(replaced, isTrue);
      expect(await ids('tv'), [1396, 1399]);
      expect(await ids('movie'), [27205]);
      expect((await repo.getCanon('tv')).every((r) => r.syncStatus == 'SYNCED'), isTrue);
    });

    test('pull-hydration never overwrites unsynced local changes', () async {
      await seedCanon(db, 'tv', ['A', 'B'], baseId: 1);
      await repo.move(mediaType: 'tv', titleId: 2, newRank: 1);
      final replaced = await repo.replaceFromRemote(const [
        RemoteRanking(titleId: 1396, mediaType: 'tv', title: 'Breaking Bad', rank: 1, score: 10.0),
      ]);
      expect(replaced, isFalse);
      expect(await ids('tv'), [2, 1]);
    });
  });

  group('FE-604: providers', () {
    test('profile canon streams from Drift and updates after a commit', () async {
      final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
      addTearDown(container.dispose);
      container.listen(profileCanonProvider, (_, __) {});
      await seedCanon(db, 'tv', ['A', 'B'], baseId: 1);
      await pumpEventQueue();
      expect(container.read(profileCanonProvider).series.map((e) => e.title), ['A', 'B']);

      await container.read(rankingRepositoryProvider).commitPlacement(
            candidate: const CanonCandidate(titleId: 9, mediaType: 'tv', title: 'New'),
            targetRank: 1,
          );
      await pumpEventQueue();
      final series = container.read(profileCanonProvider).series;
      expect(series.map((e) => e.title), ['New', 'A', 'B']);
      expect(series.first.calculatedScore, 10.00);
      expect(container.read(profileCanonProvider).movies, isEmpty);
    });

    test('profile drag-and-drop goes through the repository', () async {
      final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
      addTearDown(container.dispose);
      container.listen(profileCanonProvider, (_, __) {});
      await seedCanon(db, 'movie', ['A', 'B', 'C'], baseId: 1);
      await pumpEventQueue();

      await container.read(profileCanonProvider.notifier).moveTitle(canon: CanonType.movie, titleId: 3, newRank: 1);
      expect(await ids('movie'), [3, 1, 2]);
      expect((await queue()).single.kind, MutationKind.move);
    });

    test('hydration runs on sign-in with the signed-in user id', () async {
      final remote = FakeRemoteCanon(const [
        RemoteRanking(titleId: 1396, mediaType: 'tv', title: 'Breaking Bad', rank: 1, score: 10.0),
      ]);
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        remoteCanonSourceProvider.overrideWithValue(remote),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(
          signedInUserId: 'u1',
          profile: UserProfile(id: 'u1', username: 'maya', displayName: 'Maya', createdAt: DateTime(2026)),
        )),
      ]);
      addTearDown(container.dispose);
      container.listen(authControllerProvider, (_, __) {});
      await pumpEventQueue();

      expect(await container.read(canonHydrationProvider.future), isTrue);
      expect(remote.calls, ['u1']);
      expect(await ids('tv'), [1396]);
    });
  });

  group('FE-604: Drift schema v1 → v2 migration', () {
    test('creates PendingMutations, carries unsent legacy duels over and drops the old queue', () async {
      final v1 = File('test/fixtures/drift_schema_v1.sql').readAsStringSync();
      final legacy = AppDatabase(NativeDatabase.memory(setup: (raw) {
        for (final stmt in v1.split(';').map((s) => s.trim()).where((s) => s.startsWith('CREATE'))) {
          raw.execute(stmt);
        }
        raw.execute("INSERT INTO local_rankings (show_id, media_type, title, rank_position, calculated_score) "
            "VALUES (1, 'tv', 'Succession', 1, 10.0)");
        raw.execute("INSERT INTO offline_duel_queue (id, winner_title_id, loser_title_id, media_type, round_number, "
            "sync_status) VALUES ('a', 1, 2, 'tv', 1, 'PENDING'), ('b', 3, 4, 'movie', 1, 'SYNCED')");
        raw.execute('PRAGMA user_version = 1');
      }));
      addTearDown(legacy.close);

      final pending = await legacy.pendingMutationDao.getAllFifo();
      expect(pending, hasLength(1), reason: 'only unsent duels are carried over');
      expect(pending.single.kind, MutationKind.duels);
      final duel = ((jsonDecode(pending.single.payload) as Map)['duels'] as List).single as Map;
      expect(duel, containsPair('winner_title_id', 1));
      expect(duel, containsPair('media_type', 'tv'));
      expect(duel['client_mutation_id'], isA<String>());

      final ranking = (await legacy.localRankingDao.getRankingsByCanon('tv')).single;
      expect(ranking.title, 'Succession');
      expect(ranking.favoriteCharacter, isNull);

      final tables = await legacy.customSelect("SELECT name FROM sqlite_master WHERE type = 'table'").get();
      expect(tables.map((r) => r.read<String>('name')), isNot(contains('offline_duel_queue')));
    });
  });
}
