import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/network/offline_sync_manager.dart';

void main() {
  group('FE-504 & QA-505: Offline Write-Ahead Log (WAL) & FIFO Auto-Sync Tests', () {
    test('enqueues duels when offline without loss and flushes in FIFO order on reconnect', () async {
      final processedIds = <String>[];
      final syncManager = OfflineSyncManager(
        initialOnlineState: false, // Start offline (airplane mode)
        onSyncEntry: (entry) async {
          processedIds.add(entry.id);
          return true;
        },
      );

      expect(syncManager.isOnline, isFalse);
      expect(syncManager.pendingCount, 0);

      // Enqueue 3 duels while offline
      final id1 = await syncManager.enqueueDuel(
        winnerTitleId: 101,
        loserTitleId: 102,
        mediaType: 'tv',
        roundNumber: 1,
      );
      final id2 = await syncManager.enqueueDuel(
        winnerTitleId: 103,
        loserTitleId: 104,
        mediaType: 'tv',
        roundNumber: 2,
      );
      final id3 = await syncManager.enqueueDuel(
        winnerTitleId: 201,
        loserTitleId: 202,
        mediaType: 'movie',
        roundNumber: 1,
      );

      // Verify all 3 pending
      expect(syncManager.pendingCount, 3);
      expect(processedIds, isEmpty);

      // Simulate reconnecting to the internet
      await syncManager.setOnlineStatus(true);

      expect(syncManager.isOnline, isTrue);
      expect(syncManager.pendingCount, 0); // Flushed!

      // Assert FIFO order: id1 -> id2 -> id3
      expect(processedIds, equals([id1, id2, id3]));
    });

    test('retains remaining queue if a network failure occurs during flush', () async {
      int attempt = 0;
      final syncManager = OfflineSyncManager(
        initialOnlineState: false,
        onSyncEntry: (entry) async {
          attempt++;
          // Fail the 2nd duel
          return attempt != 2;
        },
      );

      await syncManager.enqueueDuel(
        winnerTitleId: 1,
        loserTitleId: 2,
        mediaType: 'tv',
        roundNumber: 1,
      );
      await syncManager.enqueueDuel(
        winnerTitleId: 3,
        loserTitleId: 4,
        mediaType: 'tv',
        roundNumber: 2,
      );
      await syncManager.enqueueDuel(
        winnerTitleId: 5,
        loserTitleId: 6,
        mediaType: 'tv',
        roundNumber: 3,
      );

      // Trigger flush
      await syncManager.setOnlineStatus(true);

      // 1st succeeded, 2nd failed -> 2 items remain in queue (item 2 and item 3)
      expect(syncManager.pendingCount, 2);
    });
  });
}

