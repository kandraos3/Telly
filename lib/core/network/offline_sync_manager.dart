library offline_sync_manager;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Representation of an offline duel mutation awaiting backend flush.
class OfflineDuelEntry {
  final String id;
  final int winnerTitleId;
  final int loserTitleId;
  final String mediaType; // 'movie' or 'tv'
  final int roundNumber;
  final DateTime createdAt;
  final String syncStatus; // 'PENDING' or 'SYNCED'

  const OfflineDuelEntry({
    required this.id,
    required this.winnerTitleId,
    required this.loserTitleId,
    required this.mediaType,
    required this.roundNumber,
    required this.createdAt,
    this.syncStatus = 'PENDING',
  });
}

/// Offline Write-Ahead Log (WAL) & Auto-Sync Manager.
/// Conforms to `FE-504` and `docs/technical_architecture/04_CLIENT_ARCHITECTURE_AND_OFFLINE_SYNC.md` §3.
class OfflineSyncManager {
  bool _isOnline = true;
  final List<OfflineDuelEntry> _queue = [];
  final Future<bool> Function(OfflineDuelEntry entry)? onSyncEntry;

  OfflineSyncManager({
    bool initialOnlineState = true,
    this.onSyncEntry,
  }) : _isOnline = initialOnlineState;

  bool get isOnline => _isOnline;
  List<OfflineDuelEntry> get pendingQueue => List.unmodifiable(_queue.where((e) => e.syncStatus == 'PENDING'));
  int get pendingCount => pendingQueue.length;

  /// Enqueues a pairwise duel mutation to the local Write-Ahead Log (WAL).
  /// If online and [autoFlush] is true, triggers immediate flush.
  Future<String> enqueueDuel({
    required int winnerTitleId,
    required int loserTitleId,
    required String mediaType,
    required int roundNumber,
    bool autoFlush = true,
  }) async {
    final entryId = const Uuid().v4();
    final entry = OfflineDuelEntry(
      id: entryId,
      winnerTitleId: winnerTitleId,
      loserTitleId: loserTitleId,
      mediaType: mediaType,
      roundNumber: roundNumber,
      createdAt: DateTime.now(),
      syncStatus: 'PENDING',
    );

    _queue.add(entry);

    if (_isOnline && autoFlush) {
      await flushQueue();
    }

    return entryId;
  }

  /// Sets current network connectivity state.
  /// When transitioning from offline to online, automatically flushes pending WAL transactions.
  Future<void> setOnlineStatus(bool online) async {
    final wasOffline = !_isOnline;
    _isOnline = online;

    if (wasOffline && _isOnline) {
      await flushQueue();
    }
  }

  /// Flushes pending queue entries to remote backend in strict sequential FIFO order.
  Future<int> flushQueue() async {
    if (!_isOnline) return 0;

    int syncedCount = 0;
    // Process in FIFO order (index 0 first)
    final pending = List<OfflineDuelEntry>.from(pendingQueue);

    for (final entry in pending) {
      if (!_isOnline) break;

      bool success = true;
      if (onSyncEntry != null) {
        success = await onSyncEntry!(entry);
      }

      if (success) {
        final index = _queue.indexWhere((e) => e.id == entry.id);
        if (index != -1) {
          _queue[index] = OfflineDuelEntry(
            id: entry.id,
            winnerTitleId: entry.winnerTitleId,
            loserTitleId: entry.loserTitleId,
            mediaType: entry.mediaType,
            roundNumber: entry.roundNumber,
            createdAt: entry.createdAt,
            syncStatus: 'SYNCED',
          );
          syncedCount++;
        }
      } else {
        // If an item fails, pause FIFO queue to maintain monotonic ordering
        break;
      }
    }

    // Purge completed entries from memory
    _queue.removeWhere((e) => e.syncStatus == 'SYNCED');
    return syncedCount;
  }
}

final offlineSyncManagerProvider = Provider<OfflineSyncManager>((ref) {
  return OfflineSyncManager();
});

