import 'dart:convert';
import 'dart:io';
import 'dart:math';

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

class PartitionStressTransport implements MutationTransport {
  final applied = <String>[];
  final calls = <String>[];
  int? failOnCall;

  @override
  Future<void> apply(PendingMutation m) async {
    calls.add(m.id);
    if (failOnCall != null && calls.length == failOnCall) {
      throw Exception('Simulated network partition on call #$failOnCall');
    }
    applied.add(m.id);
  }
}

void main() {
  group('QA-606: Offline WAL Persistence & Partition Stress', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('telly_wal_stress_');
    });

    tearDown(() {
      if (tmpDir.existsSync()) {
        tmpDir.deleteSync(recursive: true);
      }
    });

    FakeAuthRepository testAuth() => FakeAuthRepository(
          signedInUserId: 'usr_stress_test',
          profile: UserProfile(
            id: 'usr_stress_test',
            username: 'wal_tester',
            displayName: 'WAL Tester',
            createdAt: DateTime(2026),
          ),
        );

    ProviderContainer createSyncContainer(
      AppDatabase db,
      PartitionStressTransport transport,
    ) {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          mutationTransportProvider.overrideWithValue(transport),
          connectivityProvider.overrideWith((ref) => Stream.value(true)),
          authRepositoryProvider.overrideWithValue(testAuth()),
        ],
      );
      container.listen(syncEngineProvider, (_, __) {});
      return container;
    }

    test('20 consecutive randomized runs: file-backed Drift survives restart, partitions at item 20, and recovers with zero loss in FIFO order', () async {
      for (int run = 1; run <= 20; run++) {
        final random = Random(42 + run);
        final dbFile = File('${tmpDir.path}/telly_stress_run_$run.sqlite');

        // -------------------------------------------------------------
        // Step 1: Open file-backed Drift DB and populate 50 duels + 5 rankings
        // -------------------------------------------------------------
        var db = AppDatabase(NativeDatabase(dbFile));
        final repo = RankingRepository(db);

        final expectedMutationIds = <String>[];
        int totalDuelsEnqueued = 0;

        // Commit 5 rankings with 10 duels each = 50 duels across 5 ranking placements
        for (int rankIdx = 1; rankIdx <= 5; rankIdx++) {
          final showId = 2000 + rankIdx;
          final duels = List.generate(10, (dIdx) {
            totalDuelsEnqueued++;
            return LoggedDuel(
              winnerTitleId: showId,
              loserTitleId: 1000 + (rankIdx * 10) + dIdx,
              decisionTimeMs: 150 + random.nextInt(300),
            );
          });

          // Randomize target insertion position (between 1 and rankIdx)
          final targetRank = 1 + random.nextInt(rankIdx);

          final commit = await repo.commitPlacement(
            candidate: CanonCandidate(
              titleId: showId,
              mediaType: 'tv',
              title: 'Stress Show #$showId',
            ),
            targetRank: targetRank,
            duels: duels,
          );
          expectedMutationIds.add(commit.mutationId);
        }

        expect(totalDuelsEnqueued, equals(50), reason: 'Exactly 50 offline duels must be recorded');
        expect(expectedMutationIds.length, equals(5));

        // Enqueue 20 additional standalone mutations (e.g. duels and moves) to test partition on item 20
        for (int extra = 1; extra <= 20; extra++) {
          final mutId = await db.pendingMutationDao.enqueue(
            MutationKind.duels,
            {
              'batch_id': 'extra_batch_$extra',
              'count': extra,
              'seed': random.nextInt(1000),
            },
          );
          expectedMutationIds.add(mutId);
        }

        expect(expectedMutationIds.length, equals(25));
        expect(await db.pendingMutationDao.count(), equals(25));

        // Assert local SQLite optimistic canon is intact before restart
        final canonBeforeClose = await db.localRankingDao.getRankingsByCanon('tv');
        expect(canonBeforeClose.length, equals(5));
        for (int i = 0; i < 5; i++) {
          expect(canonBeforeClose[i].rankPosition, equals(i + 1), reason: 'Ranks must be contiguous 1..5');
        }

        // -------------------------------------------------------------
        // Step 2: Close DB connection to simulate app kill / background purge
        // -------------------------------------------------------------
        await db.close();

        // -------------------------------------------------------------
        // Step 3: Reopen file-backed DB from disk and verify WAL persistence
        // -------------------------------------------------------------
        db = AppDatabase(NativeDatabase(dbFile));

        final persistedQueue = await db.pendingMutationDao.getAllFifo();
        expect(persistedQueue.length, equals(25), reason: 'All 25 mutations must survive process restart');
        expect(persistedQueue.map((m) => m.id).toList(), equals(expectedMutationIds), reason: 'FIFO order must be preserved across reboot');

        // Verify the 50 duels survived in the payloads of the first 5 mutations
        int verifiedDuelsCount = 0;
        for (int i = 0; i < 5; i++) {
          final payload = jsonDecode(persistedQueue[i].payload) as Map<String, dynamic>;
          final duelsList = payload['duels'] as List;
          verifiedDuelsCount += duelsList.length;
        }
        expect(verifiedDuelsCount, equals(50), reason: 'All 50 duels must persist intact in the WAL');

        // -------------------------------------------------------------
        // Step 4: Network partition mid-flush (fake RPC fails on item 20)
        // -------------------------------------------------------------
        final transport = PartitionStressTransport()..failOnCall = 20;
        final container = createSyncContainer(db, transport);

        // Wait for sync engine to attempt flush and hit partition at call #20
        for (int tick = 0; tick < 200 && transport.calls.length < 20; tick++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }

        expect(transport.calls.length, equals(20), reason: 'Sync must halt exactly at item 20');
        expect(transport.applied.length, equals(19), reason: 'First 19 items successfully applied');
        expect(transport.applied, equals(expectedMutationIds.take(19).toList()));

        // Verify queue status during partition: remaining 6 items intact in exact FIFO order
        final remainingDuringPartition = await db.pendingMutationDao.getAllFifo();
        expect(remainingDuringPartition.length, equals(6));
        expect(remainingDuringPartition.map((m) => m.id).toList(), equals(expectedMutationIds.skip(19).toList()));
        expect(remainingDuringPartition.first.attempts, equals(1));
        expect(remainingDuringPartition.first.lastError, contains('Simulated network partition'));

        // -------------------------------------------------------------
        // Step 5: Network recovers → complete flush with zero loss
        // -------------------------------------------------------------
        transport.failOnCall = null; // Partition resolved!

        await container.read(syncEngineProvider.notifier).flush(force: true);

        for (int tick = 0; tick < 200 && transport.applied.length < 25; tick++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }

        expect(transport.applied.length, equals(25), reason: 'All 25 mutations must be applied');
        expect(transport.applied, equals(expectedMutationIds), reason: 'Full sequence must match original FIFO order');
        expect(await db.pendingMutationDao.count(), equals(0), reason: 'WAL queue must be completely empty');

        // Assert local canon is contiguous and marked SYNCED
        final canonFinal = await db.localRankingDao.getRankingsByCanon('tv');
        expect(canonFinal.length, equals(5));
        for (int i = 0; i < 5; i++) {
          expect(canonFinal[i].rankPosition, equals(i + 1));
          expect(canonFinal[i].syncStatus, equals('SYNCED'));
          expect(canonFinal[i].calculatedScore, greaterThan(0.0));
        }

        container.dispose();
        await db.close();
      }
    });
  });
}
