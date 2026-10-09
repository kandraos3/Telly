import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/features/tracking/data/tracking_repository.dart';
import 'package:telly_app/features/tracking/domain/tracking_item.dart';
import 'package:telly_app/features/tracking/domain/tracking_models.dart';

/// #228: the local-first tracking repository (features/11 §4, §9.2).
void main() {
  late AppDatabase db;
  late LocalFirstTrackingRepository repo;
  late List<http.Request> requests;
  late Map<String, http.Response Function(http.Request)> routes;
  var now = DateTime(2026, 10, 9, 12);

  SupabaseClient fakeClient() => SupabaseClient(
        'http://supabase.test',
        'anon-key',
        httpClient: MockClient((req) async {
          requests.add(req);
          final handler = routes[req.url.path];
          if (handler == null) return http.Response('{"message":"no route"}', 404, headers: _json, request: req);
          final r = handler(req);
          return http.Response(r.body, r.statusCode, headers: r.headers, request: req);
        }),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

  http.Response ok(Object? body) => http.Response(jsonEncode(body), 200, headers: _json);

  // An ended series: S1 has 3 episodes, S2 has 4; every season started long ago, so all have aired.
  TrackingStartRequest show({EpisodeRef? place, bool rewatch = false, int id = 100}) => TrackingStartRequest(
        titleId: id,
        mediaType: 'tv',
        title: 'Ended Show',
        titleStatus: 'Ended',
        seasons: [
          SeasonInfo(number: 1, episodeCount: 3, airDate: DateTime(2000)),
          SeasonInfo(number: 2, episodeCount: 4, airDate: DateTime(2001)),
        ],
        place: place,
        rewatch: rewatch,
      );

  const movie = TrackingStartRequest(titleId: 200, mediaType: 'movie', title: 'A Film', runtimeMinutes: 166);

  Future<List<PendingMutation>> queue() => db.pendingMutationDao.getAllFifo();
  Map<String, dynamic> payload(PendingMutation m) => jsonDecode(m.payload) as Map<String, dynamic>;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    requests = [];
    routes = {};
    now = DateTime(2026, 10, 9, 12);
    repo = LocalFirstTrackingRepository(db, fakeClient(), clock: () => now);
  });
  tearDown(() => db.close());

  group('start', () {
    test('from the beginning: cached at once, queued, and the Queue entry goes', () async {
      await db.into(db.watchlistCache).insert(WatchlistCacheCompanion.insert(titleId: 100, mediaType: 'tv', title: 'Ended Show'));

      final item = await repo.start(show());

      expect(item.state, TrackingState.watching);
      expect(item.place, isNull);
      expect(item.pending, isTrue);
      expect(item.nextEpisode!.ref, const EpisodeRef(1, 1));
      expect((await repo.getOne(100, 'tv'))!.pending, isTrue);
      expect(await db.select(db.watchlistCache).get(), isEmpty, reason: 'starting leaves the Queue');
      final m = (await queue()).single;
      expect(m.kind, MutationKind.trackingStart);
      expect(payload(m), {
        'title_id': 100,
        'media_type': 'tv',
        'last_season': null,
        'last_episode': null,
        'rewatch': false,
      });
    });

    test('partway: the place is where you left off, and nothing before it is recorded', () async {
      final item = await repo.start(show(place: const EpisodeRef(2, 3)));
      expect(item.place, const EpisodeRef(2, 3));
      expect(item.watched, 6);
      expect(item.nextEpisode!.ref, const EpisodeRef(2, 4));
      expect(payload((await queue()).single)['last_season'], 2);
      expect(payload((await queue()).single)['last_episode'], 3);
    });

    test('at the last episode of an ended show it is finished at once', () async {
      final item = await repo.start(show(place: const EpisodeRef(2, 4)));
      expect(item.state, TrackingState.finished);
      expect(item.finishedAt, now);
      expect(item.nextEpisode, isNull);
    });

    test('a place past the known episodes is clamped', () async {
      final item = await repo.start(show(place: const EpisodeRef(1, 99)));
      expect(item.place, const EpisodeRef(1, 3));
    });

    test('starting a title that is already tracked changes nothing', () async {
      await repo.start(show(place: const EpisodeRef(1, 2)));
      final again = await repo.start(show());
      expect(again.place, const EpisodeRef(1, 2));
      expect(await queue(), hasLength(1));
    });

    test('"Watch again" on a finished title resets the place and flags the rewatch', () async {
      final finished = await repo.start(show(place: const EpisodeRef(2, 4)));
      expect(finished.state, TrackingState.finished);

      final again = await repo.start(show(rewatch: true));
      expect(again.state, TrackingState.watching);
      expect(again.place, isNull);
      expect(again.isRewatch, isTrue);
      expect(again.finishedAt, isNull);
      final kinds = (await queue()).map((m) => m.kind).toList();
      expect(kinds, [MutationKind.trackingStart, MutationKind.trackingStart]);
      expect(payload((await queue()).last)['rewatch'], isTrue);
    });

    test('a movie has no place and starts watching', () async {
      final item = await repo.start(movie);
      expect(item.isMovie, isTrue);
      expect(item.state, TrackingState.watching);
      expect(item.place, isNull);
      expect(item.nextEpisode, isNull);
      expect(payload((await queue()).single), {
        'title_id': 200,
        'media_type': 'movie',
        'last_season': null,
        'last_episode': null,
        'rewatch': false,
      });
    });

    test('a movie and a series with the same id are separate rows', () async {
      await repo.start(show(id: 5));
      await repo.start(const TrackingStartRequest(titleId: 5, mediaType: 'movie', title: 'Same id'));
      expect((await db.trackingCacheDao.getAll()).map((r) => r.mediaType).toSet(), {'tv', 'movie'});
    });
  });

  group('moving the place', () {
    test('forward one episode: queued with the absolute place, bar and counts follow', () async {
      final started = await repo.start(show(place: const EpisodeRef(1, 1)));
      final moved = await repo.setPlace(started, const EpisodeRef(1, 2));
      expect(moved.place, const EpisodeRef(1, 2));
      expect(moved.watched, 2);
      expect(moved.nextEpisode!.ref, const EpisodeRef(1, 3));
      final m = (await queue()).last;
      expect(m.kind, MutationKind.trackingPlace);
      expect(payload(m), {'title_id': 100, 'media_type': 'tv', 'last_season': 1, 'last_episode': 2});
    });

    test('the last episode finishes an ended show, and un-logging it brings it back', () async {
      final started = await repo.start(show(place: const EpisodeRef(2, 3)));
      final done = await repo.setPlace(started, const EpisodeRef(2, 4));
      expect(done.state, TrackingState.finished);
      expect(done.finishedAt, now);

      now = now.add(const Duration(hours: 1));
      final back = await repo.setPlace(done, const EpisodeRef(2, 3));
      expect(back.state, TrackingState.watching);
      expect(back.finishedAt, isNull);
    });

    test('a finished title keeps its original finish time when moved within the end', () async {
      final started = await repo.start(show(place: const EpisodeRef(2, 4)));
      now = now.add(const Duration(days: 1));
      final same = await repo.setPlace(started, const EpisodeRef(2, 4));
      expect(same.finishedAt, started.finishedAt);
    });

    test('a forward move clears the new-episodes flag; a move back keeps it', () async {
      await db.trackingCacheDao.upsert(TrackingCacheCompanion.insert(
        titleId: 100,
        mediaType: 'tv',
        title: 'Ended Show',
        titleStatus: const Value('Ended'),
        lastSeason: const Value(1),
        lastEpisode: const Value(2),
        newEpisodesSince: Value(DateTime(2026, 10, 8)),
        seasons: Value(jsonEncode([
          {'number': 1, 'episode_count': 3, 'air_date': '2000-01-01'},
          {'number': 2, 'episode_count': 4, 'air_date': '2001-01-01'},
        ])),
        watched: const Value(2),
      ));
      final item = (await repo.getOne(100, 'tv'))!;

      final back = await repo.setPlace(item, const EpisodeRef(1, 1));
      expect(back.newEpisodesSince, isNotNull, reason: 'going back is not catching up');
      final forward = await repo.setPlace(back, const EpisodeRef(1, 3));
      expect(forward.newEpisodesSince, isNull);
    });

    test('back to the very beginning sends a null place', () async {
      final started = await repo.start(show(place: const EpisodeRef(1, 1)));
      final reset = await repo.setPlace(started, null);
      expect(reset.place, isNull);
      expect(payload((await queue()).last)['last_season'], isNull);
    });

    test('uses cached episodes: an unaired episode is not the next one', () async {
      // S1 is cached with E3 airing tomorrow, so after E2 there is nothing to watch yet.
      await db.episodeCacheDao.write(
        100,
        1,
        jsonEncode([
          {'episode_number': 1, 'name': 'One', 'air_date': '2020-01-01'},
          {'episode_number': 2, 'name': 'Two', 'air_date': '2020-01-08'},
          {'episode_number': 3, 'name': 'Three', 'air_date': '2026-10-10'},
        ]),
        now,
      );
      final started = await repo.start(TrackingStartRequest(
        titleId: 100,
        mediaType: 'tv',
        title: 'Weekly Show',
        titleStatus: 'Returning Series',
        seasons: [SeasonInfo(number: 1, episodeCount: 3, airDate: DateTime(2020))],
        place: const EpisodeRef(1, 1),
      ));
      expect(started.nextEpisode!.name, 'Two', reason: 'the next episode comes with its cached name');
      final caught = await repo.setPlace(started, const EpisodeRef(1, 2));
      expect(caught.state, TrackingState.caughtUp);
      expect(caught.nextEpisode, isNull);
    });
  });

  group('rewatch, finish, stop, revive', () {
    test('logRewatch queues the episode and leaves the place alone', () async {
      final item = await repo.start(show(place: const EpisodeRef(2, 2)));
      await repo.logRewatch(item, const EpisodeRef(1, 1));
      expect((await repo.getOne(100, 'tv'))!.place, const EpisodeRef(2, 2));
      final m = (await queue()).last;
      expect(m.kind, MutationKind.trackingRewatch);
      expect(payload(m), {'title_id': 100, 'media_type': 'tv', 'season': 1, 'episode': 1});
    });

    test('finishing a series puts the place at its last aired episode', () async {
      final item = await repo.start(show(place: const EpisodeRef(1, 1)));
      final done = await repo.finish(item);
      expect(done.place, const EpisodeRef(2, 4));
      expect(done.state, TrackingState.finished);
      final m = (await queue()).last;
      expect(m.kind, MutationKind.trackingFinish);
      expect(payload(m), {'title_id': 100, 'media_type': 'tv'});
    });

    test('finishing a movie marks it finished', () async {
      final item = await repo.start(movie);
      final done = await repo.finish(item);
      expect(done.state, TrackingState.finished);
      expect(done.finishedAt, now);
      expect(done.place, isNull);
      expect((await queue()).last.kind, MutationKind.trackingFinish);
    });

    test('a finished movie can be watched again', () async {
      final finished = await repo.finish(await repo.start(movie));
      expect(finished.state, TrackingState.finished);
      final again = await repo.start(const TrackingStartRequest(
          titleId: 200, mediaType: 'movie', title: 'A Film', rewatch: true));
      expect(again.state, TrackingState.watching);
      expect(again.isRewatch, isTrue);
      expect(again.finishedAt, isNull);
    });

    test('stopping removes the row and queues the stop; the Queue is not refilled', () async {
      final item = await repo.start(show());
      await repo.stop(item);
      expect(await repo.getOne(100, 'tv'), isNull);
      expect((await queue()).last.kind, MutationKind.trackingStop);
      expect(await db.select(db.watchlistCache).get(), isEmpty);
    });

    test('revive tracks from the drop point', () async {
      final item = await repo.revive(show(place: const EpisodeRef(1, 2)));
      expect(item.place, const EpisodeRef(1, 2));
      expect(item.state, TrackingState.watching);
      final m = (await queue()).single;
      expect(m.kind, MutationKind.trackingRevive);
      expect(payload(m), {'title_id': 100, 'media_type': 'tv'});
    });
  });

  group('hydrate', () {
    Map<String, dynamic> serverItem(int id, {String media = 'tv', int? season, int? episode, String title = 'Server'}) => {
          'title_id': id,
          'media_type': media,
          'last_season': season,
          'last_episode': episode,
          'state': 'WATCHING',
          'is_rewatch': false,
          'new_episodes_since': '2026-10-08T05:23:00Z',
          'started_at': '2026-09-01T10:00:00Z',
          'last_progress_at': '2026-10-08T21:40:00Z',
          'finished_at': null,
          'title': title,
          'poster_path': '/p.jpg',
          'backdrop_path': null,
          'title_status': 'Returning Series',
          'runtime_minutes': null,
          'number_of_seasons': 2,
          'seasons': media == 'tv'
              ? [
                  {'number': 1, 'episode_count': 3, 'air_date': '2000-01-01'},
                  {'number': 2, 'episode_count': 4, 'air_date': '2001-01-01'},
                ]
              : null,
          'watched': media == 'tv' ? 2 : null,
          'aired_total': media == 'tv' ? 7 : null,
          'next_episode': media == 'tv'
              ? {
                  'season': 1,
                  'episode': 3,
                  'name': 'Third',
                  'still_path': '/s.jpg',
                  'air_date': '2000-01-15',
                  'runtime_minutes': 45,
                }
              : null,
          'last_aired': media == 'tv' ? {'season': 2, 'episode': 4} : null,
          'ranked': true,
          'rank_position': 4,
          'calculated_score': 9.31,
        };

    test('fills the cache from get_my_tracking', () async {
      routes['/rest/v1/rpc/get_my_tracking'] = (_) => ok({
            'today': '2026-10-09',
            'items': [serverItem(1, season: 1, episode: 2), serverItem(2, media: 'movie', title: 'Film')],
          });
      await repo.hydrate();

      final tv = (await repo.getOne(1, 'tv'))!;
      expect(tv.title, 'Server');
      expect(tv.place, const EpisodeRef(1, 2));
      expect(tv.watched, 2);
      expect(tv.airedTotal, 7);
      expect(tv.nextEpisode!.name, 'Third');
      expect(tv.nextEpisode!.airDate, DateTime(2000, 1, 15));
      expect(tv.lastAired, const EpisodeRef(2, 4));
      expect(tv.seasons.map((s) => s.episodeCount), [3, 4]);
      expect(tv.isRanked, isTrue);
      expect(tv.rankPosition, 4);
      expect(tv.score, 9.31);
      expect(tv.newEpisodesSince!.isAtSameMomentAs(DateTime.utc(2026, 10, 8, 5, 23)), isTrue);
      expect(tv.pending, isFalse);
      final film = (await repo.getOne(2, 'movie'))!;
      expect(film.seasons, isEmpty);
      expect(film.watched, isNull);
      expect(film.nextEpisode, isNull);
    });

    test('keeps a title with pending changes, drops one stopped elsewhere', () async {
      await repo.start(show(id: 1, place: const EpisodeRef(2, 1))); // pending locally
      await db.trackingCacheDao.upsert(TrackingCacheCompanion.insert(titleId: 3, mediaType: 'tv', title: 'Stopped elsewhere'));
      routes['/rest/v1/rpc/get_my_tracking'] = (_) => ok({
            'today': '2026-10-09',
            'items': [serverItem(1, season: 1, episode: 1), serverItem(4, season: 1, episode: 1, title: 'New')],
          });

      await repo.hydrate();

      final kept = (await repo.getOne(1, 'tv'))!;
      expect(kept.place, const EpisodeRef(2, 1), reason: 'the local copy is newer than the server');
      expect(kept.pending, isTrue);
      expect(await repo.getOne(3, 'tv'), isNull);
      expect((await repo.getOne(4, 'tv'))!.title, 'New');
    });

    test('a network failure leaves the cache alone', () async {
      await repo.start(show());
      routes['/rest/v1/rpc/get_my_tracking'] = (_) => http.Response('down', 500, headers: _json);
      await expectLater(repo.hydrate(), throwsA(isA<PostgrestException>()));
      expect(await repo.getOne(100, 'tv'), isNotNull);
    });
  });

  group('episodes', () {
    List<Map<String, Object?>> season1() => [
          {'episode_number': 1, 'name': 'Pilot', 'overview': 'o', 'still_path': '/1.jpg', 'air_date': '2020-01-01', 'runtime_minutes': 50},
          {'episode_number': 2, 'name': 'Two', 'overview': null, 'still_path': null, 'air_date': null, 'runtime_minutes': null},
        ];

    http.Response seasonResponse() => ok({'title_id': 100, 'season_number': 1, 'episodes': season1()});

    test('loadSeason fetches through tmdb-season, caches, and serves the cache while fresh', () async {
      routes['/functions/v1/tmdb-season'] = (req) {
        expect(req.url.queryParameters, {'id': '100', 'season': '1'});
        return seasonResponse();
      };
      final first = await repo.loadSeason(100, 1);
      expect(first.map((e) => e.name), ['Pilot', 'Two']);
      expect(first.first.airDate, DateTime(2020));
      expect(first.first.runtimeMinutes, 50);
      expect(first.last.airDate, isNull);

      now = now.add(const Duration(days: 6));
      await repo.loadSeason(100, 1);
      expect(requests.where((r) => r.url.path.endsWith('tmdb-season')), hasLength(1), reason: 'still fresh at 6 days');

      now = now.add(const Duration(days: 2));
      await repo.loadSeason(100, 1);
      expect(requests.where((r) => r.url.path.endsWith('tmdb-season')), hasLength(2), reason: 'stale after 7 days');
    });

    test('offline: stale episodes are better than none, and nothing cached is an empty list', () async {
      expect(await repo.loadSeason(100, 1), isEmpty);

      await db.episodeCacheDao.write(100, 1, jsonEncode(season1()), now.subtract(const Duration(days: 30)));
      routes['/functions/v1/tmdb-season'] = (_) => http.Response('{"error":"down"}', 502, headers: _json);
      expect((await repo.loadSeason(100, 1)).map((e) => e.name), ['Pilot', 'Two']);
    });

    test('scheduleFor carries the seasons and every cached episode', () async {
      final item = await repo.start(show(place: const EpisodeRef(1, 1)));
      await db.episodeCacheDao.write(100, 1, jsonEncode(season1()), now);
      final schedule = await repo.scheduleFor(item);
      expect(schedule.seasons.map((s) => s.number), [1, 2]);
      expect(schedule.episodes[1]!.map((e) => e.name), ['Pilot', 'Two']);
      expect(schedule.status, 'Ended');
    });
  });

  group('reads', () {
    test('watchers: friends only, with the total, and no place', () async {
      routes['/rest/v1/rpc/get_title_watchers'] = (req) {
        expect(jsonDecode(req.body), {'p_title_id': 100, 'p_media_type': 'tv'});
        return ok([
          {'watcher_id': 'u-b', 'username': 'maya', 'display_name': 'Maya', 'avatar_url': null, 'total_watchers': 5},
          {'watcher_id': 'u-c', 'username': 'jordan', 'display_name': null, 'avatar_url': '/a.jpg', 'total_watchers': 5},
        ]);
      };
      final w = await repo.watchers(100, 'tv');
      expect(w.total, 5);
      expect(w.watchers.map((x) => x.username), ['maya', 'jordan']);
    });

    test('watchers: none means a zero total', () async {
      routes['/rest/v1/rpc/get_title_watchers'] = (_) => ok(<Object>[]);
      final w = await repo.watchers(100, 'tv');
      expect(w.total, 0);
      expect(w.watchers, isEmpty);
    });

    test('stats: a year, and a week with minutes', () async {
      routes['/rest/v1/rpc/get_tracking_stats'] = (req) {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        return body.containsKey('p_year') ? ok({'episodes': 312}) : ok({'episodes': 9, 'minutes': 470});
      };
      final year = await repo.stats('tv', year: 2026);
      expect(year.episodes, 312);
      expect(year.minutes, isNull);
      final week = await repo.stats('tv');
      expect([week.episodes, week.minutes], [9, 470]);
      routes['/rest/v1/rpc/get_tracking_stats'] = (_) => ok({'movies_finished': 4});
      expect((await repo.stats('movie', year: 2026)).moviesFinished, 4);
    });
  });

  test('TrackingItem: progress and episodes left follow the server counts', () {
    final item = TrackingItem.fromServerJson({
      'title_id': 1,
      'media_type': 'tv',
      'state': 'WATCHING',
      'title': 'X',
      'watched': 14,
      'aired_total': 19,
    });
    expect(item.progress, closeTo(14 / 19, 1e-9));
    expect(item.episodesLeft, 5);
    final movieItem = TrackingItem.fromServerJson({'title_id': 2, 'media_type': 'movie', 'state': 'WATCHING', 'title': 'F'});
    expect(movieItem.progress, 0);
    expect(movieItem.episodesLeft, isNull);
  });
}

const _json = {'content-type': 'application/json'};
