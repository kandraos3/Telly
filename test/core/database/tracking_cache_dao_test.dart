import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';

// features/11 §9.2: TrackingCache (one row per tracked title) and EpisodeCache (one season per row).
void main() {
  TrackingCacheCompanion row(int id, {String media = 'tv', String title = 'Show', String sync = 'SYNCED', int? season, int? episode}) =>
      TrackingCacheCompanion.insert(
        titleId: id,
        mediaType: media,
        title: title,
        lastSeason: Value(season),
        lastEpisode: Value(episode),
        syncStatus: Value(sync),
      );

  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('TrackingCacheDao', () {
    test('stores one row per title and canon, and updates it in place', () async {
      final dao = db.trackingCacheDao;
      await dao.upsert(row(1, season: 1, episode: 2));
      await dao.upsert(row(1, media: 'movie', title: 'A film with the same id'));
      await dao.upsert(row(1, season: 2, episode: 1));

      expect((await dao.getAll()).length, 2, reason: 'a movie and a series may share an id');
      final tv = await dao.getOne(1, 'tv');
      expect([tv!.lastSeason, tv.lastEpisode], [2, 1]);
      expect((await dao.getOne(1, 'movie'))!.lastSeason, isNull);
      expect(await dao.getOne(2, 'tv'), isNull);
    });

    test('defaults: WATCHING, not ranked, not a rewatch, SYNCED', () async {
      await db.trackingCacheDao.upsert(TrackingCacheCompanion.insert(titleId: 5, mediaType: 'tv', title: 'x'));
      final r = (await db.trackingCacheDao.getOne(5, 'tv'))!;
      expect([r.state, r.ranked, r.isRewatch, r.syncStatus], ['WATCHING', false, false, 'SYNCED']);
    });

    test('watchAll lists the newest progress first, and watchOne follows one title', () async {
      final dao = db.trackingCacheDao;
      await dao.upsert(TrackingCacheCompanion.insert(
          titleId: 1, mediaType: 'tv', title: 'old', lastProgressAt: Value(DateTime(2026, 1, 1))));
      await dao.upsert(TrackingCacheCompanion.insert(
          titleId: 2, mediaType: 'tv', title: 'new', lastProgressAt: Value(DateTime(2026, 6, 1))));

      expect((await dao.watchAll().first).map((r) => r.title), ['new', 'old']);

      final seen = <int?>[];
      final sub = dao.watchOne(1, 'tv').listen((r) => seen.add(r?.lastEpisode));
      await pumpEventQueue();
      await dao.upsert(row(1, season: 1, episode: 3));
      await pumpEventQueue();
      await sub.cancel();
      expect(seen, [null, 3]);
    });

    test('remove deletes one title and markSynced flips only that title', () async {
      final dao = db.trackingCacheDao;
      await dao.upsert(row(1, sync: 'PENDING'));
      await dao.upsert(row(2, sync: 'PENDING'));
      await dao.markSynced(1, 'tv');
      expect((await dao.getOne(1, 'tv'))!.syncStatus, 'SYNCED');
      expect((await dao.getOne(2, 'tv'))!.syncStatus, 'PENDING');
      expect(await dao.remove(2, 'tv'), 1);
      expect(await dao.getOne(2, 'tv'), isNull);
    });

    test('replaceSynced swaps in the server copy but protects titles with pending changes', () async {
      final dao = db.trackingCacheDao;
      await dao.upsert(row(1, title: 'stale', season: 1, episode: 1)); // the server moved it on
      await dao.upsert(row(2, title: 'local only', sync: 'PENDING', season: 2, episode: 2)); // unconfirmed
      await dao.upsert(row(3, title: 'stopped elsewhere')); // gone from the server
      await dao.upsert(row(4, title: 'pending and gone', sync: 'PENDING')); // protected too

      await dao.replaceSynced(
        [row(1, title: 'fresh', season: 1, episode: 3), row(2, title: 'server copy', season: 1, episode: 1), row(5, title: 'new')],
        {(2, 'tv'), (4, 'tv')},
      );

      final byId = {for (final r in await dao.getAll()) r.titleId: r};
      expect(byId.keys.toSet(), {1, 2, 4, 5});
      expect(byId[1]!.title, 'fresh');
      expect(byId[2]!.title, 'local only', reason: 'a pending title keeps the local copy');
      expect([byId[2]!.lastSeason, byId[2]!.lastEpisode], [2, 2]);
      expect(byId[4]!.title, 'pending and gone');
    });
  });

  test('replaceSynced keeps a row that turned pending after the keep set was worked out', () async {
    final dao = db.trackingCacheDao;
    await dao.upsert(row(1, season: 1, episode: 1));
    // The user acts while hydrate is in flight: the row is PENDING but not in the caller's keep set.
    await dao.upsert(row(1, season: 1, episode: 5, sync: 'PENDING'));
    await dao.upsert(row(2, sync: 'PENDING'));

    await dao.replaceSynced([row(1, season: 1, episode: 2)], const {});

    final one = (await dao.getOne(1, 'tv'))!;
    expect([one.lastSeason, one.lastEpisode], [1, 5], reason: 'the newer local copy wins');
    expect(await dao.getOne(2, 'tv'), isNotNull, reason: 'and a pending title missing from the server stays');
  });

  group('EpisodeCacheDao', () {
    test('keeps one JSON document per season and overwrites it', () async {
      final dao = db.episodeCacheDao;
      expect(await dao.read(1, 1), isNull);
      await dao.write(1, 1, '[1]', DateTime(2026, 10, 1));
      await dao.write(1, 2, '[2]', DateTime(2026, 10, 1));
      await dao.write(1, 1, '[1,1]', DateTime(2026, 10, 8));

      final s1 = await dao.read(1, 1);
      expect(s1!.json, '[1,1]');
      expect(s1.fetchedAt, DateTime(2026, 10, 8));
      expect((await dao.readTitle(1)).map((r) => r.seasonNumber).toSet(), {1, 2});
      expect(await dao.readTitle(2), isEmpty);
    });
  });

  test('wipeLocalData also clears tracking and episodes', () async {
    await db.trackingCacheDao.upsert(row(1));
    await db.episodeCacheDao.write(1, 1, '[]', DateTime(2026));
    await db.wipeLocalData();
    expect(await db.trackingCacheDao.getAll(), isEmpty);
    expect(await db.episodeCacheDao.readTitle(1), isEmpty);
  });

  test('upgrading a version 4 database creates the tracking and episode caches', () async {
    final dir = await Directory.systemTemp.createTemp('telly_db_v4');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/app.sqlite');

    // Make a current database, then roll it back to what version 4 had.
    final v4 = AppDatabase(NativeDatabase(file));
    await v4.customStatement('DROP TABLE tracking_cache');
    await v4.customStatement('DROP TABLE episode_cache');
    await v4.customStatement('PRAGMA user_version = 4');
    await v4.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    await upgraded.trackingCacheDao.upsert(row(9, season: 1, episode: 1));
    await upgraded.episodeCacheDao.write(9, 1, '[]', DateTime(2026, 10, 9));
    expect((await upgraded.trackingCacheDao.getOne(9, 'tv'))!.lastEpisode, 1);
    expect((await upgraded.episodeCacheDao.read(9, 1))!.json, '[]');
  });
}
