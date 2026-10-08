import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';

// features/07 §7.5: the last get_explore_candidates payload per canon.
void main() {
  test('stores one payload per canon and overwrites it', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final dao = db.exploreCacheDao;

    expect(await dao.read('movie'), isNull);
    await dao.write('movie', '{"v":1}', DateTime(2026, 10, 8, 9));
    await dao.write('tv', '{"v":"tv"}', DateTime(2026, 10, 8, 9));
    await dao.write('movie', '{"v":2}', DateTime(2026, 10, 8, 12));

    final movie = await dao.read('movie');
    expect(movie!.json, '{"v":2}');
    expect(movie.savedAt, DateTime(2026, 10, 8, 12));
    expect((await dao.read('tv'))!.json, '{"v":"tv"}');
  });

  test('upgrading a version 3 database creates the explore cache', () async {
    final dir = await Directory.systemTemp.createTemp('telly_db_v3');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/app.sqlite');

    // Make a current database, then roll it back to what version 3 had.
    final v3 = AppDatabase(NativeDatabase(file));
    await v3.customStatement('DROP TABLE explore_cache');
    await v3.customStatement('PRAGMA user_version = 3');
    await v3.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    await upgraded.exploreCacheDao.write('tv', '{}', DateTime(2026, 10, 8));
    expect((await upgraded.exploreCacheDao.read('tv'))!.json, '{}');
  });
}
