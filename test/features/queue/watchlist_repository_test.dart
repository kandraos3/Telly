import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/features/queue/data/watchlist_repository.dart';

void main() {
  late AppDatabase db;
  late List<http.Request> remoteRequests;
  late Object? remoteResponseData;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    remoteRequests = [];
    remoteResponseData = [];
  });

  tearDown(() => db.close());

  LocalFirstWatchlistRepository createRepo({String? userId = 'u1'}) {
    final client = SupabaseClient(
      'http://supabase.test',
      'anon-key',
      httpClient: MockClient((req) async {
        remoteRequests.add(req);
        return http.Response(
          jsonEncode(remoteResponseData),
          200,
          headers: {'content-type': 'application/json'},
          request: req,
        );
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    return LocalFirstWatchlistRepository(db, client, currentUserId: () => userId);
  }

  group('FE-609: WatchlistRepository tests', () {
    test('add persists locally as PENDING and enqueues watchlistAdd in WAL', () async {
      final repo = createRepo();

      await repo.add(
        titleId: 101,
        mediaType: 'tv',
        title: 'Slow Horses',
        posterPath: '/sh.jpg',
        recommendedBy: 'friend-42',
      );

      final inCache = await repo.isInWatchlist(101, 'tv');
      expect(inCache, isTrue);

      final rows = await repo.getWatchlist();
      expect(rows, hasLength(1));
      expect(rows.first.titleId, 101);
      expect(rows.first.mediaType, 'tv');
      expect(rows.first.title, 'Slow Horses');
      expect(rows.first.syncStatus, 'PENDING');

      final pending = await db.pendingMutationDao.getAllFifo();
      expect(pending, hasLength(1));
      expect(pending.first.kind, MutationKind.watchlistAdd);

      final payload = jsonDecode(pending.first.payload) as Map<String, dynamic>;
      expect(payload['title_id'], 101);
      expect(payload['media_type'], 'tv');
      expect(payload['recommended_by_user_id'], 'friend-42');
    });

    test('remove deletes local row and enqueues watchlistRemove in WAL', () async {
      final repo = createRepo();

      await repo.add(
        titleId: 101,
        mediaType: 'tv',
        title: 'Slow Horses',
      );
      expect(await repo.isInWatchlist(101, 'tv'), isTrue);

      await repo.remove(titleId: 101, mediaType: 'tv');
      expect(await repo.isInWatchlist(101, 'tv'), isFalse);

      final pending = await db.pendingMutationDao.getAllFifo();
      expect(pending, hasLength(2));
      expect(pending[1].kind, MutationKind.watchlistRemove);

      final payload = jsonDecode(pending[1].payload) as Map<String, dynamic>;
      expect(payload['title_id'], 101);
      expect(payload['media_type'], 'tv');
    });

    test('Dual-Canon Segregation partitions movies and tv shows', () async {
      final repo = createRepo();

      await repo.add(titleId: 201, mediaType: 'movie', title: 'Parasite');
      await repo.add(titleId: 101, mediaType: 'tv', title: 'Slow Horses');

      final movies = await repo.getWatchlist(mediaType: 'movie');
      expect(movies, hasLength(1));
      expect(movies.first.title, 'Parasite');
      expect(movies.first.mediaType, 'movie');

      final shows = await repo.getWatchlist(mediaType: 'tv');
      expect(shows, hasLength(1));
      expect(shows.first.title, 'Slow Horses');
      expect(shows.first.mediaType, 'tv');
    });

    test('watchWatchlist emits reactive updates', () async {
      final repo = createRepo();

      final streamEvents = <List<WatchlistEntry>>[];
      final sub = repo.watchWatchlist().listen(streamEvents.add);

      await pumpEventQueue();
      expect(streamEvents, hasLength(1));
      expect(streamEvents.first, isEmpty);

      await repo.add(titleId: 201, mediaType: 'movie', title: 'Parasite');
      await pumpEventQueue();
      expect(streamEvents.last, hasLength(1));
      expect(streamEvents.last.first.title, 'Parasite');

      await sub.cancel();
    });

    test('hydrate pulls remote titles into Drift and respects pending mutations', () async {
      remoteResponseData = [
        {
          'title_id': 301,
          'media_type': 'movie',
          'added_at': '2026-10-01T12:00:00.000Z',
          'titles': {'title': 'Dune', 'poster_path': '/dune.jpg'},
        },
        {
          'title_id': 401,
          'media_type': 'tv',
          'added_at': '2026-10-01T14:00:00.000Z',
          'titles': {'title': 'Severance', 'poster_path': '/severance.jpg'},
        },
      ];

      final repo = createRepo();

      // Enqueue a local pending deletion for Dune (301)
      await db.pendingMutationDao.enqueue(
        MutationKind.watchlistRemove,
        {'title_id': 301, 'media_type': 'movie'},
      );

      await repo.hydrate();

      final inCacheDune = await repo.isInWatchlist(301, 'movie');
      final inCacheSeverance = await repo.isInWatchlist(401, 'tv');

      // Dune was skipped because it was pending in the WAL
      expect(inCacheDune, isFalse);
      // Severance was hydrated as SYNCED
      expect(inCacheSeverance, isTrue);

      final sevRow = (await repo.getWatchlist(mediaType: 'tv')).first;
      expect(sevRow.title, 'Severance');
      expect(sevRow.syncStatus, 'SYNCED');
    });
  });
}

