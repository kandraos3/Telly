import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/features/logging/data/title_repository.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final results = {
    'page': 1,
    'results': [
      {'id': 1396, 'media_type': 'tv', 'title': 'Breaking Bad', 'release_year': '2008', 'poster_path': '/bb.jpg'},
      {'id': 1396, 'media_type': 'movie', 'title': 'Colliding Movie', 'release_year': '1999', 'poster_path': null},
      {'id': 1429, 'media_type': 'tv', 'title': 'Attack on Titan', 'release_year': '2013', 'is_anime': true},
    ],
  };

  FunctionsClient functions(Future<http.Response> Function(http.Request) handler) =>
      FunctionsClient('https://x.supabase.co/functions/v1', const {}, httpClient: MockClient(handler));

  group('FE-603: SupabaseTitleRepository', () {
    test('GETs tmdb-search with the query, parses movie/tv results and caches them in Drift', () async {
      late http.Request seen;
      final repo = SupabaseTitleRepository(
        functions((req) async {
          seen = req;
          return http.Response(jsonEncode(results), 200, headers: {'content-type': 'application/json'}, request: req);
        }),
        db.localTitleDao,
      );

      final outcome = await repo.search('  breaking ');

      expect(seen.method, 'GET');
      expect(seen.url.path, endsWith('/tmdb-search'));
      expect(seen.url.queryParameters['query'], 'breaking');
      expect(outcome.fromLocalCache, isFalse);
      expect(outcome.results.map((r) => (r.id, r.mediaType)), [(1396, 'tv'), (1396, 'movie'), (1429, 'tv')]);
      expect(outcome.results.last.isAnime, isTrue);

      // Composite key keeps the colliding movie/tv ids apart.
      expect((await db.localTitleDao.getTitleById(1396, 'tv'))!.title, 'Breaking Bad');
      expect((await db.localTitleDao.getTitleById(1396, 'movie'))!.title, 'Colliding Movie');
    });

    test('falls back to the local cache when the edge function is unreachable', () async {
      await db.localTitleDao.upsertTitle(
        CachedTitlesCompanion.insert(id: 1396, mediaType: 'tv', title: 'Breaking Bad'),
      );
      final repo = SupabaseTitleRepository(
        functions((req) async => throw http.ClientException('offline')),
        db.localTitleDao,
      );

      final outcome = await repo.search('breaking');
      expect(outcome.fromLocalCache, isTrue);
      expect(outcome.results.single.title, 'Breaking Bad');
    });

    test('a non-2xx response also falls back to the cache', () async {
      final repo = SupabaseTitleRepository(
        functions((req) async => http.Response('{"error":"rate"}', 429, request: req)),
        db.localTitleDao,
      );
      final outcome = await repo.search('anything');
      expect(outcome.fromLocalCache, isTrue);
      expect(outcome.results, isEmpty);
    });

    test('a blank query does not hit the network', () async {
      var calls = 0;
      final repo = SupabaseTitleRepository(
        functions((req) async {
          calls++;
          return http.Response('{}', 200, request: req);
        }),
        db.localTitleDao,
      );
      expect((await repo.search('   ')).results, isEmpty);
      expect(calls, 0);
    });
  });
}
