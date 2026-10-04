import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart' hide JsonKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../database/database.dart';
import '../database/database_provider.dart';
import 'connectivity_signal.dart';
import 'mutation_transport.dart';

class SyncStatus {
  final int pending;
  final bool flushing;
  final String? lastError;
  final DateTime? nextRetryAt;

  const SyncStatus({this.pending = 0, this.flushing = false, this.lastError, this.nextRetryAt});

  bool get isBlocked => lastError != null;
}

/// Drains the Drift [PendingMutations] write-ahead log to Supabase (FE-605, TA-04 §3).
///
/// - Strict FIFO; stops at the first failure so later mutations never overtake it.
/// - Failures back off exponentially ([retryDelay]); a reconnect, app resume or sign-in
///   retries immediately.
/// - New local mutations (the repository's enqueue) trigger a flush by themselves.
/// - On success the mutation row is deleted and its ranking marked `SYNCED` once no other
///   pending mutation references that title.
class SyncEngine extends AsyncNotifier<SyncStatus> {
  Timer? _retryTimer;
  bool _flushing = false;
  bool _online = true;
  bool _signedIn = false;
  String? _lastError;

  PendingMutationDao get _queue => ref.read(databaseProvider).pendingMutationDao;

  /// 2 s, 4 s, 8 s … capped at 5 minutes.
  static Duration retryDelay(int attempts) =>
      Duration(seconds: math.min(300, 2 * math.pow(2, math.max(0, attempts - 1)).toInt()));

  @override
  Future<SyncStatus> build() async {
    _signedIn = ref.watch(authControllerProvider.select((s) => s.isSignedIn));
    final queue = ref.watch(databaseProvider).pendingMutationDao;

    ref.listen<AsyncValue<bool>>(connectivityProvider, (previous, next) {
      final wasOnline = _online;
      _online = next.valueOrNull ?? _online;
      if (_online && !wasOnline) flush(force: true);
    });

    final countSub = queue.watchCount().listen((count) {
      _publish(count);
      if (count > 0 && _retryTimer == null) flush();
    });
    ref.onDispose(() {
      countSub.cancel();
      _retryTimer?.cancel();
      _retryTimer = null;
    });

    if (_signedIn) scheduleMicrotask(() => flush(force: true));
    return SyncStatus(pending: await queue.count(), lastError: _lastError);
  }

  void _publish(int pending, {DateTime? nextRetryAt}) {
    state = AsyncData(SyncStatus(
      pending: pending,
      flushing: _flushing,
      lastError: _lastError,
      nextRetryAt: nextRetryAt ?? state.valueOrNull?.nextRetryAt,
    ));
  }

  /// Flushes the queue. [force] skips a pending backoff (reconnect, resume, sign-in).
  Future<void> flush({bool force = false}) async {
    if (_flushing || !_signedIn || !_online) return;
    if (_retryTimer != null && !force) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    _flushing = true;
    try {
      while (true) {
        final head = (await _queue.getAllFifo()).firstOrNull;
        if (head == null) break;
        try {
          await ref.read(mutationTransportProvider).apply(head);
        } catch (e) {
          _lastError = '$e';
          await _queue.recordFailure(head.id, _lastError!);
          final delay = retryDelay(head.attempts + 1);
          _retryTimer = Timer(delay, () {
            _retryTimer = null;
            flush();
          });
          _publish(await _queue.count(), nextRetryAt: DateTime.now().add(delay));
          return;
        }
        await _acknowledge(head);
        _lastError = null;
      }
      _publish(0, nextRetryAt: null);
    } finally {
      _flushing = false;
    }
  }

  Future<void> _acknowledge(PendingMutation done) async {
    final db = ref.read(databaseProvider);
    await db.transaction(() async {
      await _queue.remove(done.id);
      final p = jsonDecode(done.payload) as Map<String, dynamic>;
      final titleId = p['title_id'];
      final mediaType = p['media_type'];
      if (titleId is! int || mediaType is! String) return;
      final stillPending = (await _queue.getAllFifo()).any((m) {
        final o = jsonDecode(m.payload) as Map<String, dynamic>;
        return o['title_id'] == titleId && o['media_type'] == mediaType;
      });
      if (stillPending) return;
      await (db.update(db.localRankings)..where((t) => t.showId.equals(titleId) & t.mediaType.equals(mediaType)))
          .write(const LocalRankingsCompanion(syncStatus: Value('SYNCED')));
    });
  }
}

final syncEngineProvider = AsyncNotifierProvider<SyncEngine, SyncStatus>(SyncEngine.new);
