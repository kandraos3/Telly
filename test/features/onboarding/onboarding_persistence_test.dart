import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/features/logging/data/title_repository.dart';
import 'package:telly_app/features/logging/domain/title_search_result.dart';
import 'package:telly_app/features/onboarding/data/canon_import_service.dart';
import 'package:telly_app/features/onboarding/data/onboarding_repository.dart';
import 'package:telly_app/features/onboarding/data/top_50_seeds.dart';
import 'package:telly_app/features/onboarding/presentation/controllers/onboarding_controllers.dart';
import 'package:telly_app/features/ranking/data/ranking_repository.dart';
import 'package:telly_app/features/ranking/presentation/controllers/duel_controller.dart';

import '../../helpers/canon_seed.dart';

/// Resolves "Film N" to movie id N; anything else is unknown.
class NumberedCatalog implements TitleRepository {
  @override
  Future<TitleSearchOutcome> search(String query) async {
    final n = int.tryParse(query.replaceFirst('Film ', ''));
    return TitleSearchOutcome([
      if (n != null) TitleSearchResult(id: n, mediaType: 'movie', title: query, releaseYear: '20${10 + n}'),
    ]);
  }

  @override
  Future<TitleCredits> fetchCredits(int id, String mediaType) async => TitleCredits.empty;
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  group('FE-606: RankingRepository.appendCanon', () {
    test('appends below the existing canon, skips titles already ranked, queues in rank order', () async {
      await seedCanon(db, 'movie', ['Existing'], baseId: 1);
      final repo = RankingRepository(db);
      final added = await repo.appendCanon(mediaType: 'movie', ordered: const [
        CanonCandidate(titleId: 1, mediaType: 'movie', title: 'Existing'),
        CanonCandidate(titleId: 2, mediaType: 'movie', title: 'B'),
        CanonCandidate(titleId: 3, mediaType: 'movie', title: 'C'),
      ], duels: const [
        LoggedDuel(winnerTitleId: 2, loserTitleId: 3),
      ]);
      expect(added, 2);
      final canon = await repo.getCanon('movie');
      expect(canon.map((r) => (r.showId, r.rankPosition)), [(1, 1), (2, 2), (3, 3)]);
      expect(canon.last.calculatedScore, lessThan(canon.first.calculatedScore));

      final queue = await db.pendingMutationDao.getAllFifo();
      final payloads = [for (final m in queue) jsonDecode(m.payload) as Map<String, dynamic>];
      expect(payloads.map((p) => (p['title_id'], p['target_rank'])), [(2, 2), (3, 3)]);
      expect(payloads.first['duels'], isEmpty);
      expect((payloads.last['duels'] as List).single, containsPair('winner_title_id', 2));
    });

    test('rejects a title from the other canon', () {
      expect(
        () => RankingRepository(db).appendCanon(
          mediaType: 'movie',
          ordered: const [CanonCandidate(titleId: 1, mediaType: 'tv', title: 'Severance')],
        ),
        throwsArgumentError,
      );
    });
  });

  group('FE-606: CanonImportService', () {
    test('a 10-row Letterboxd CSV creates 10 movie rankings ordered by rating', () async {
      final rows = [
        'Date,Name,Year,Letterboxd URI,Rating',
        for (var n = 1; n <= 10; n++) '2024-01-${n.toString().padLeft(2, '0')},Film $n,20${10 + n},https://boxd.it/$n,${n / 2}',
      ];
      final service = CanonImportService(NumberedCatalog(), RankingRepository(db));
      final result = await service.importLetterboxd(rows.join('\n'));

      expect(result.added, 10);
      expect(result.unmatched, isEmpty);
      final canon = await db.localRankingDao.getRankingsByCanon('movie');
      expect(canon, hasLength(10));
      expect(canon.first.title, 'Film 10', reason: '5.0 stars ranks first');
      expect(canon.map((r) => r.rankPosition), List.generate(10, (i) => i + 1));
      expect(canon.first.bracket, 'masterpiece');
      expect(await db.pendingMutationDao.count(), 10);
      expect(await db.localRankingDao.getRankingsByCanon('tv'), isEmpty);
    });

    test('rewatches collapse to one ranking and unknown films are reported', () async {
      final csv = [
        'Date,Name,Year,Letterboxd URI,Rating',
        '2024-01-01,Film 1,2011,u,3',
        '2024-02-01,Film 1,2011,u,4.5',
        '2024-03-01,Some Obscure Short,1999,u,4',
      ].join('\n');
      final result = await CanonImportService(NumberedCatalog(), RankingRepository(db)).importLetterboxd(csv);
      expect(result.added, 1);
      expect(result.unmatched, ['Some Obscure Short']);
      expect((await db.localRankingDao.getRankingsByCanon('movie')).single.bracket, 'masterpiece');
    });
  });

  group('FE-606: onboarding tournament persistence', () {
    test('selecting 3 movies + 4 series yields two canons with contiguous ranks', () async {
      final movies = kTop50SeedTitles.where((s) => s.mediaType == 'movie').take(3).toList();
      final series = kTop50SeedTitles.where((s) => s.mediaType == 'tv').take(4).toList();
      final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
      addTearDown(container.dispose);
      for (final s in [...movies, ...series]) {
        container.read(seedSelectionProvider.notifier).toggle(s);
      }
      container.listen(onboardingTournamentProvider, (_, __) {});

      var guard = 0;
      while (!container.read(onboardingTournamentProvider).done) {
        final duel = container.read(onboardingTournamentProvider).duel;
        if (duel is DuelActive) {
          expect(duel.currentOpponent.mediaType, duel.candidate.mediaType);
          await container.read(onboardingTournamentProvider.notifier).voteWinner(duel.candidate.showId);
        } else {
          await Future<void>.delayed(Duration.zero);
        }
        expect(++guard, lessThan(100));
      }

      final movieCanon = await db.localRankingDao.getRankingsByCanon('movie');
      final seriesCanon = await db.localRankingDao.getRankingsByCanon('tv');
      expect(movieCanon.map((r) => r.rankPosition), [1, 2, 3]);
      expect(seriesCanon.map((r) => r.rankPosition), [1, 2, 3, 4]);
      expect(movieCanon.map((r) => r.showId).toSet(), movies.map((m) => m.id).toSet());
      expect(seriesCanon.map((r) => r.showId).toSet(), series.map((m) => m.id).toSet());
      expect(await db.pendingMutationDao.count(), 7);
    });
  });

  group('FE-606: SupabaseOnboardingRepository', () {
    test('upserts the selection, drops the rest and merges the free-platform preference', () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'http://supabase.test',
        'anon-key',
        httpClient: MockClient((req) async {
          requests.add(req);
          final body = req.method == 'GET' ? '{"preferences":{"theme":"oled"}}' : '[]';
          return http.Response(body, 200, headers: {'content-type': 'application/json'}, request: req);
        }),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      await SupabaseOnboardingRepository(client, currentUserId: () => 'u1')
          .saveStreamingSetup(platformIds: {'netflix', 'crunchyroll'}, includeFreePlatforms: true);

      final upsert = requests[0];
      expect(upsert.method, 'POST');
      expect(upsert.url.path, '/rest/v1/user_streaming_subscriptions');
      expect((jsonDecode(upsert.body) as List).map((r) => r['platform_id']).toSet(), {'netflix', 'crunchyroll'});

      final prune = requests[1];
      expect(prune.method, 'DELETE');
      expect(prune.url.queryParameters['user_id'], 'eq.u1');
      expect(prune.url.queryParameters['platform_id'], 'not.in.(netflix,crunchyroll)');

      final update = requests.last;
      expect(update.method, 'PATCH');
      expect(jsonDecode(update.body), {
        'preferences': {'theme': 'oled', 'include_free_platforms': true},
      });
    });
  });
}
