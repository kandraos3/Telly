import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/core/sync/connectivity_signal.dart';
import 'package:telly_app/core/sync/mutation_transport.dart';
import 'package:telly_app/core/sync/sync_engine.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/features/ranking/data/ranking_repository.dart';

import '../../fakes/fake_auth_repository.dart';

/// Records what the "server" received; can fail a given call (1-based).
class FakeTransport implements MutationTransport {
  final applied = <String>[];
  final calls = <String>[];
  int? failOnCall;
  bool failAfterApplying = false;

  @override
  Future<void> apply(PendingMutation m) async {
    calls.add(m.id);
    if (failOnCall == calls.length) {
      if (failAfterApplying) applied.add(m.id); // server applied it, response lost
      throw Exception('network down');
    }
    applied.add(m.id);
  }
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('telly_sync_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  AppDatabase openFileDb() => AppDatabase(NativeDatabase(File('${tmp.path}/telly.sqlite')));

  FakeAuthRepository signedIn() => FakeAuthRepository(
        signedInUserId: 'u1',
        profile: UserProfile(id: 'u1', username: 'maya', displayName: 'Maya', createdAt: DateTime(2026)),
      );

  ProviderContainer containerFor(
    AppDatabase db,
    FakeTransport transport, {
    Stream<bool>? online,
    AuthRepository? auth,
  }) {
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      mutationTransportProvider.overrideWithValue(transport),
      connectivityProvider.overrideWith((ref) => online ?? Stream.value(true)),
      authRepositoryProvider.overrideWithValue(auth ?? signedIn()),
    ]);
    c.listen(syncEngineProvider, (_, __) {});
    return c;
  }

  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  Future<List<String>> enqueueThree(AppDatabase db) async {
    final repo = RankingRepository(db);
    final ids = <String>[];
    for (final (id, title) in [(1, 'Succession'), (2, 'The Bear'), (3, 'Severance')]) {
      final commit = await repo.commitPlacement(
        candidate: CanonCandidate(titleId: id, mediaType: 'tv', title: title),
        targetRank: 1,
      );
      ids.add(commit.mutationId);
    }
    return ids;
  }

  group('FE-605: SyncEngine', () {
    test('mutations survive closing the DB and flush in FIFO order after reopening', () async {
      final first = openFileDb();
      final ids = await enqueueThree(first);
      await first.close();

      final db = openFileDb();
      addTearDown(db.close);
      final transport = FakeTransport();
      final c = containerFor(db, transport);
      addTearDown(c.dispose);

      await until(() => transport.applied.length == 3);
      expect(transport.applied, ids);
      await until(() => c.read(syncEngineProvider).valueOrNull?.pending == 0);
      expect(await db.pendingMutationDao.count(), 0);
      final canon = await db.localRankingDao.getRankingsByCanon('tv');
      expect(canon.every((r) => r.syncStatus == 'SYNCED'), isTrue);
    });

    test('a mid-flush failure halts the flush and leaves the remaining entries intact', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final ids = await enqueueThree(db);
      final transport = FakeTransport()..failOnCall = 2;
      final c = containerFor(db, transport);
      addTearDown(c.dispose);

      await until(() => transport.calls.length == 2);
      await until(() => c.read(syncEngineProvider).valueOrNull?.isBlocked ?? false);

      expect(transport.calls, ids.take(2), reason: 'the third never overtakes the failed second');
      final remaining = await db.pendingMutationDao.getAllFifo();
      expect(remaining.map((m) => m.id), ids.skip(1));
      expect(remaining.first.attempts, 1);
      expect(remaining.first.lastError, contains('network down'));
      final status = c.read(syncEngineProvider).value!;
      expect(status.pending, 2);
      expect(status.nextRetryAt, isNotNull);
      final canon = await db.localRankingDao.getRankingsByCanon('tv');
      expect(canon.firstWhere((r) => r.showId == 1).syncStatus, 'SYNCED');
      expect(canon.firstWhere((r) => r.showId == 2).syncStatus, 'PENDING');
    });

    test('a retry replays the same client_mutation_id (server-side no-op if already applied)', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final ids = await enqueueThree(db);
      final transport = FakeTransport()
        ..failOnCall = 1
        ..failAfterApplying = true;
      final c = containerFor(db, transport);
      addTearDown(c.dispose);
      await until(() => transport.calls.isNotEmpty);
      await until(() => c.read(syncEngineProvider).valueOrNull?.isBlocked ?? false);

      await c.read(syncEngineProvider.notifier).flush(force: true);
      expect(transport.calls, [ids[0], ids[0], ids[1], ids[2]]);
      expect(await db.pendingMutationDao.count(), 0);
    });

    test('offline: nothing is sent until connectivity returns', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final online = StreamController<bool>();
      addTearDown(online.close);
      final transport = FakeTransport();
      final c = containerFor(db, transport, online: online.stream);
      addTearDown(c.dispose);

      online.add(false);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final ids = await enqueueThree(db);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(transport.calls, isEmpty);

      online.add(true);
      await until(() => transport.applied.length == 3);
      expect(transport.applied, ids);
    });

    test('nothing is sent while signed out', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      await enqueueThree(db);
      final transport = FakeTransport();
      final c = containerFor(db, transport, auth: FakeAuthRepository());
      addTearDown(c.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(transport.calls, isEmpty);
      expect(c.read(syncEngineProvider).valueOrNull?.pending, 3);
    });

    test('backoff doubles from 2 s and caps at 5 min', () {
      expect([1, 2, 3, 4].map((a) => SyncEngine.retryDelay(a).inSeconds), [2, 4, 8, 16]);
      expect(SyncEngine.retryDelay(20), const Duration(minutes: 5));
    });
  });
}
