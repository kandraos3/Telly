import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/network/supabase_providers.dart';
import '../../auth/presentation/controllers/auth_controller.dart';

/// One title in the local universal watchlist cache (FE-609).
class WatchlistEntry {
  final int titleId;
  final String mediaType; // 'movie' or 'tv'
  final String title;
  final String? posterPath;
  final DateTime savedAt;
  final String syncStatus; // 'SYNCED' or 'PENDING'

  const WatchlistEntry({
    required this.titleId,
    required this.mediaType,
    required this.title,
    this.posterPath,
    required this.savedAt,
    this.syncStatus = 'SYNCED',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchlistEntry &&
          runtimeType == other.runtimeType &&
          titleId == other.titleId &&
          mediaType == other.mediaType;

  @override
  int get hashCode => Object.hash(titleId, mediaType);
}

/// Local-first repository for universal queue / watchlist (FE-609).
/// Backed by Drift [WatchlistCache] + Supabase `user_watchlist` with offline WAL.
abstract interface class WatchlistRepository {
  Stream<List<WatchlistEntry>> watchWatchlist({String? mediaType});
  Future<List<WatchlistEntry>> getWatchlist({String? mediaType});
  Future<bool> isInWatchlist(int titleId, String mediaType);

  Future<void> add({
    required int titleId,
    required String mediaType,
    required String title,
    String? posterPath,
    String? recommendedBy,
  });

  Future<void> remove({
    required int titleId,
    required String mediaType,
  });

  /// Pulls remote rows from `user_watchlist` into local Drift `WatchlistCache`.
  Future<void> hydrate();
}

class LocalFirstWatchlistRepository implements WatchlistRepository {
  LocalFirstWatchlistRepository(
    this._db,
    this._client, {
    String? Function()? currentUserId,
  }) : _currentUserId = currentUserId ?? (() => _client.auth.currentUser?.id);

  final AppDatabase _db;
  final SupabaseClient _client;
  final String? Function() _currentUserId;

  @override
  Stream<List<WatchlistEntry>> watchWatchlist({String? mediaType}) {
    final query = _db.select(_db.watchlistCache);
    if (mediaType != null) {
      query.where((t) => t.mediaType.equals(mediaType));
    }
    query.orderBy([(t) => OrderingTerm(expression: t.savedAt, mode: OrderingMode.desc)]);
    return query.watch().map((rows) => rows.map(_fromRow).toList());
  }

  @override
  Future<List<WatchlistEntry>> getWatchlist({String? mediaType}) async {
    final query = _db.select(_db.watchlistCache);
    if (mediaType != null) {
      query.where((t) => t.mediaType.equals(mediaType));
    }
    query.orderBy([(t) => OrderingTerm(expression: t.savedAt, mode: OrderingMode.desc)]);
    final rows = await query.get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<bool> isInWatchlist(int titleId, String mediaType) async {
    final row = await (_db.select(_db.watchlistCache)
          ..where((t) => t.titleId.equals(titleId) & t.mediaType.equals(mediaType)))
        .getSingleOrNull();
    return row != null;
  }

  @override
  Future<void> add({
    required int titleId,
    required String mediaType,
    required String title,
    String? posterPath,
    String? recommendedBy,
  }) async {
    final mutationId = const Uuid().v4();
    await _db.transaction(() async {
      await _db.into(_db.watchlistCache).insertOnConflictUpdate(
            WatchlistCacheCompanion.insert(
              titleId: titleId,
              mediaType: mediaType,
              title: title,
              posterPath: Value(posterPath),
              savedAt: Value(DateTime.now()),
              syncStatus: const Value('PENDING'),
            ),
          );
      await _db.pendingMutationDao.enqueue(
        MutationKind.watchlistAdd,
        {
          'title_id': titleId,
          'media_type': mediaType,
          if (recommendedBy != null) 'recommended_by_user_id': recommendedBy,
        },
        id: mutationId,
      );
    });
  }

  @override
  Future<void> remove({
    required int titleId,
    required String mediaType,
  }) async {
    final mutationId = const Uuid().v4();
    await _db.transaction(() async {
      await (_db.delete(_db.watchlistCache)
            ..where((t) => t.titleId.equals(titleId) & t.mediaType.equals(mediaType)))
          .go();
      await _db.pendingMutationDao.enqueue(
        MutationKind.watchlistRemove,
        {
          'title_id': titleId,
          'media_type': mediaType,
        },
        id: mutationId,
      );
    });
  }

  @override
  Future<void> hydrate() async {
    final userId = _currentUserId();
    if (userId == null) return;
    try {
      final rows = await _client
          .from('user_watchlist')
          .select('title_id, media_type, added_at, titles(title, poster_path)')
          .eq('user_id', userId);

      final pending = await _db.pendingMutationDao.getAllFifo();
      final pendingKeys = <(int, String)>{};
      for (final m in pending) {
        if (m.kind == MutationKind.watchlistAdd || m.kind == MutationKind.watchlistRemove) {
          final p = jsonDecode(m.payload) as Map<String, dynamic>;
          if (p['title_id'] is int && p['media_type'] is String) {
            pendingKeys.add((p['title_id'] as int, p['media_type'] as String));
          }
        }
      }

      final companions = <WatchlistCacheCompanion>[];
      for (final r in rows) {
        final titleId = (r['title_id'] as num).toInt();
        final mediaType = r['media_type'] as String;
        if (pendingKeys.contains((titleId, mediaType))) continue;

        final titleMap = r['titles'] as Map?;
        final title = (titleMap?['title'] as String?) ?? 'Untitled';
        final posterPath = titleMap?['poster_path'] as String?;
        final addedAt = DateTime.tryParse(r['added_at'] as String? ?? '') ?? DateTime.now();

        companions.add(
          WatchlistCacheCompanion.insert(
            titleId: titleId,
            mediaType: mediaType,
            title: title,
            posterPath: Value(posterPath),
            savedAt: Value(addedAt),
            syncStatus: const Value('SYNCED'),
          ),
        );
      }
      if (companions.isNotEmpty) {
        await _db.batch((b) {
          b.insertAllOnConflictUpdate(_db.watchlistCache, companions);
        });
      }
    } catch (_) {
      // Graceful offline degradation: local cache remains intact.
    }
  }

  static WatchlistEntry _fromRow(WatchlistCacheData r) => WatchlistEntry(
        titleId: r.titleId,
        mediaType: r.mediaType,
        title: r.title,
        posterPath: r.posterPath,
        savedAt: r.savedAt,
        syncStatus: r.syncStatus,
      );
}

final watchlistRepositoryProvider = Provider<WatchlistRepository>(
  (ref) => LocalFirstWatchlistRepository(
    ref.watch(databaseProvider),
    ref.watch(supabaseClientProvider),
  ),
);

/// Hydrates Drift from the server once per signed-in user.
final watchlistHydrationProvider = FutureProvider<void>((ref) async {
  final userId = ref.watch(authControllerProvider.select((s) => s.isSignedIn ? s.user?.id : null));
  if (userId == null) return;
  await ref.read(watchlistRepositoryProvider).hydrate();
});

