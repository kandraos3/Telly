import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/core/sync/connectivity_signal.dart';
import 'package:telly_app/core/sync/mutation_transport.dart';
import 'package:telly_app/core/sync/sync_engine.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/features/tracking/data/tracking_repository.dart';
import 'package:telly_app/features/tracking/domain/tracking_models.dart';
import 'package:telly_app/features/tracking/presentation/providers/tracking_providers.dart';

import '../../fakes/fake_auth_repository.dart';

/// Records what the "server" received.
class _Transport implements MutationTransport {
  final applied = <PendingMutation>[];

  @override
  Future<void> apply(PendingMutation m) async => applied.add(m);
}

/// #228: the tracking providers, optimistic updates and replay (features/11 §9.2, §9.3).
void main() {
  late AppDatabase db;
  late _Transport transport;
  late StreamController<bool> changes;
  late ProviderContainer container;

  final now = DateTime(2026, 10, 9, 12);

  SupabaseClient emptyServer() => SupabaseClient(
        'http://supabase.test',
        'anon-key',
        httpClient: MockClient((req) async => http.Response(
              jsonEncode({'today': '2026-10-09', 'items': <Object>[]}),
              200,
              headers: {'content-type': 'application/json'},
              request: req,
            )),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

  TrackingStartRequest show({EpisodeRef? place}) => TrackingStartRequest(
        titleId: 100,
        mediaType: 'tv',
        title: 'Ended Show',
        titleStatus: 'Ended',
        seasons: [
          SeasonInfo(number: 1, episodeCount: 3, airDate: DateTime(2000)),
          SeasonInfo(number: 2, episodeCount: 4, airDate: DateTime(2001)),
        ],
        place: place,
      );

  const movie = TrackingStartRequest(titleId: 200, mediaType: 'movie', title: 'A Film');

  /// Starts offline (as a phone in a tunnel), then follows [changes].
  Stream<bool> connectivity() async* {
    yield false;
    yield* changes.stream;
  }

  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 400 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  /// The engine is built and has seen the connection drop before any change is made.
  Future<void> startOfflineEngine() async {
    container.listen(syncEngineProvider, (_, __) {});
    await container.read(syncEngineProvider.future);
    await pumpEventQueue();
  }

  Future<TrackingController> controller() async {
    await container.read(trackingProvider.future);
    return container.read(trackingProvider.notifier);
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    transport = _Transport();
    changes = StreamController<bool>.broadcast();
    final repo = LocalFirstTrackingRepository(db, emptyServer(), clock: () => now);
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      trackingRepositoryProvider.overrideWithValue(repo),
      mutationTransportProvider.overrideWithValue(transport),
      connectivityProvider.overrideWith((ref) => connectivity()),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(
        signedInUserId: 'u1',
        profile: UserProfile(id: 'u1', username: 'maya', displayName: 'Maya', createdAt: DateTime(2026)),
      )),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await changes.close();
    await db.close();
  });

  group('state', () {
    test('starts empty, shows a started title at once, and selects it by title and canon', () async {
      final tracking = await controller();
      expect(container.read(trackingProvider).value, isEmpty);

      await tracking.start(show());
      await until(() => container.read(trackingProvider).value!.isNotEmpty);

      final item = container.read(titleTrackingProvider((100, 'tv')));
      expect(item, isNotNull);
      expect(item!.title, 'Ended Show');
      expect(container.read(titleTrackingProvider((100, 'movie'))), isNull, reason: 'same id, other canon');
      expect(container.read(titleTrackingProvider((999, 'tv'))), isNull);
    });

    test('a hydrate failure does not break the provider: the cache is the truth', () async {
      final repo = LocalFirstTrackingRepository(
          db,
          SupabaseClient('http://supabase.test', 'k',
              httpClient: MockClient((req) async => http.Response('down', 500, request: req)),
              authOptions: const AuthClientOptions(autoRefreshToken: false)),
          clock: () => now);
      await repo.start(show());
      final c = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        trackingRepositoryProvider.overrideWithValue(repo),
        mutationTransportProvider.overrideWithValue(transport),
        connectivityProvider.overrideWith((ref) => connectivity()),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      ]);
      addTearDown(c.dispose);
      expect((await c.read(trackingProvider.future)).single.title, 'Ended Show');
    });
  });

  group('marking and undoing', () {
    test('markNext moves on one episode and returns the item as it was', () async {
      final tracking = await controller();
      final started = await tracking.start(show(place: const EpisodeRef(1, 1)));

      final before = await tracking.markNext(started);

      expect(before!.place, const EpisodeRef(1, 1));
      await until(() => container.read(titleTrackingProvider((100, 'tv')))!.place == const EpisodeRef(1, 2));
      expect(container.read(titleTrackingProvider((100, 'tv')))!.place, const EpisodeRef(1, 2));
    });

    test('markNext does nothing for a movie or when nothing has aired next', () async {
      final tracking = await controller();
      final film = await tracking.start(movie);
      expect(await tracking.markNext(film), isNull);

      final done = await tracking.start(show(place: const EpisodeRef(2, 4)));
      expect(done.nextEpisode, isNull);
      expect(await tracking.markNext(done), isNull);
      expect((await db.pendingMutationDao.getAllFifo()).map((m) => m.kind),
          [MutationKind.trackingStart, MutationKind.trackingStart], reason: 'no place mutation was queued');
    });

    test('undo sends the previous absolute place, so the net change is zero', () async {
      final tracking = await controller();
      final started = await tracking.start(show(place: const EpisodeRef(1, 1)));
      final before = (await tracking.markNext(started))!;

      await tracking.undo(before);

      final queue = await db.pendingMutationDao.getAllFifo();
      expect(queue.map((m) => m.kind), [MutationKind.trackingStart, MutationKind.trackingPlace, MutationKind.trackingPlace]);
      final places = queue.skip(1).map((m) => jsonDecode(m.payload) as Map<String, dynamic>).toList();
      expect([places[0]['last_season'], places[0]['last_episode']], [1, 2]);
      expect([places[1]['last_season'], places[1]['last_episode']], [1, 1], reason: 'back where it began');
      await until(() => container.read(titleTrackingProvider((100, 'tv')))!.place == const EpisodeRef(1, 1));
      expect(container.read(titleTrackingProvider((100, 'tv')))!.place, const EpisodeRef(1, 1));
    });

    test('undo of the very first episode goes back to no place', () async {
      final tracking = await controller();
      final started = await tracking.start(show());
      final before = (await tracking.markNext(started))!;
      expect(before.place, isNull);
      await tracking.undo(before);
      final last = jsonDecode((await db.pendingMutationDao.getAllFifo()).last.payload) as Map<String, dynamic>;
      expect(last['last_season'], isNull);
      expect(last['last_episode'], isNull);
    });

    test('unlog moves the place to the episode before, across a season boundary, down to nothing', () async {
      final tracking = await controller();
      var item = await tracking.start(show(place: const EpisodeRef(2, 2)));

      item = await tracking.unlog(item, const EpisodeRef(2, 2));
      expect(item.place, const EpisodeRef(2, 1));
      item = await tracking.unlog(item, const EpisodeRef(2, 1));
      expect(item.place, const EpisodeRef(1, 3), reason: 'the last episode of the season before');
      item = await tracking.setPlace(item, const EpisodeRef(1, 1));
      item = await tracking.unlog(item, const EpisodeRef(1, 1));
      expect(item.place, isNull, reason: 'before the very first episode');
    });
  });

  group('replay through the sync engine', () {
    test('offline changes are applied in order once the connection returns', () async {
      await startOfflineEngine();
      final tracking = await controller();

      final started = await tracking.start(show(place: const EpisodeRef(1, 1)));
      final before = (await tracking.markNext(started))!;
      await tracking.undo(before);
      await pumpEventQueue();
      expect(transport.applied, isEmpty, reason: 'offline: nothing reaches the server');
      expect(container.read(titleTrackingProvider((100, 'tv')))!.pending, isTrue);

      changes.add(true);
      await until(() => transport.applied.length == 3);

      expect(transport.applied.map((m) => m.kind),
          [MutationKind.trackingStart, MutationKind.trackingPlace, MutationKind.trackingPlace]);
      await until(() => container.read(titleTrackingProvider((100, 'tv')))?.pending == false);
      expect(container.read(titleTrackingProvider((100, 'tv')))!.pending, isFalse, reason: 'acknowledged');
      expect(await db.pendingMutationDao.count(), 0);
    });

    test('a movie started and finished offline syncs in order, and a stop removes it', () async {
      await startOfflineEngine();
      final tracking = await controller();

      final started = await tracking.start(movie);
      final done = await tracking.finish(started);
      expect(done.state.dbValue, 'FINISHED');

      changes.add(true);
      await until(() => transport.applied.length == 2);
      expect(transport.applied.map((m) => m.kind), [MutationKind.trackingStart, MutationKind.trackingFinish]);

      await tracking.stop(done);
      await until(() => transport.applied.length == 3);
      expect(transport.applied.last.kind, MutationKind.trackingStop);
      await until(() => container.read(titleTrackingProvider((200, 'movie'))) == null);
      expect(container.read(titleTrackingProvider((200, 'movie'))), isNull);
    });
  });
}
