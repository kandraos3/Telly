import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../monitoring/sentry_service.dart';

part 'database.g.dart';

// --- TABLE DEFINITIONS ---

class CachedTitles extends Table {
  IntColumn get id => integer()(); // TMDB ID
  TextColumn get title => text()();
  TextColumn get mediaType => text()(); // 'movie' or 'tv'
  TextColumn get posterPath => text().nullable()();
  TextColumn get backdropPath => text().nullable()();
  TextColumn get overview => text().nullable()();
  TextColumn get releaseDate => text().nullable()();
  TextColumn get genres => text().nullable()(); // JSON string
  TextColumn get streamingServices => text().nullable()(); // JSON string
  BoolColumn get isAnime => boolean().withDefault(const Constant(false))();
  IntColumn get totalSeasons => integer().nullable()();
  IntColumn get totalEpisodes => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id, mediaType};
}

class LocalRankings extends Table {
  IntColumn get showId => integer()();
  TextColumn get mediaType => text()(); // 'movie' or 'tv' (Dual-Canon Partition)
  TextColumn get title => text()();
  TextColumn get posterPath => text().nullable()();
  IntColumn get rankPosition => integer()(); // 1-indexed
  RealColumn get calculatedScore => real()(); // 1.00 - 10.00
  TextColumn get bracket => text().nullable()(); // 'top_10', 'top_25', etc.
  TextColumn get favoriteCharacter => text().nullable()(); // v2: SCR-11 MVP pick
  TextColumn get syncStatus => text().withDefault(const Constant('SYNCED'))(); // 'SYNCED', 'PENDING'
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {showId, mediaType};
}

/// Write-ahead log of canon mutations awaiting server replay (v2, FE-604/FE-605).
///
/// `seq` gives strict FIFO order; `id` is the `client_mutation_id` the server uses to
/// make replays idempotent (TA-02 invariant I-5). `payload` is the JSON body for the RPC.
class PendingMutations extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get id => text().unique()();
  TextColumn get kind => text()(); // see [MutationKind]
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}

/// Kinds of [PendingMutations] rows and the server call each replays to.
abstract final class MutationKind {
  /// `insert_user_ranking_atomic` (+ `record_pairwise_duels` for the payload's `duels`).
  static const logTitle = 'log_title';

  /// `move_user_ranking`.
  static const move = 'move';

  /// `delete_user_ranking`.
  static const delete = 'delete';

  /// `record_pairwise_duels` on its own (legacy v1 queue rows).
  static const duels = 'duels';

  /// UPDATE of the editorial columns on the caller's own `user_rankings` row.
  static const editorial = 'editorial';

  /// UPSERT into `user_watchlist` (FE-609).
  static const watchlistAdd = 'watchlist_add';

  /// DELETE from `user_watchlist` (FE-609).
  static const watchlistRemove = 'watchlist_remove';

  /// Watch tracking (#168, features/11 §9.2). Payloads carry absolute places, so replays converge.
  /// `start_tracking`.
  static const trackingStart = 'tracking_start';

  /// `set_tracking_place`.
  static const trackingPlace = 'tracking_place';

  /// `log_episode_rewatch`.
  static const trackingRewatch = 'tracking_rewatch';

  /// `finish_tracking`.
  static const trackingFinish = 'tracking_finish';

  /// `stop_tracking`.
  static const trackingStop = 'tracking_stop';

  /// `revive_dropped_show`.
  static const trackingRevive = 'tracking_revive';
}

class WatchlistCache extends Table {
  IntColumn get titleId => integer()();
  TextColumn get mediaType => text()();
  TextColumn get title => text()();
  TextColumn get posterPath => text().nullable()();
  DateTimeColumn get savedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get syncStatus => text().withDefault(const Constant('SYNCED'))();

  @override
  Set<Column> get primaryKey => {titleId, mediaType};
}

/// Last server snapshot per gamification screen, one JSON document per key (features/10
/// §9.9): shown read-only while offline.
class GamificationCache extends Table {
  TextColumn get key => text()();
  TextColumn get json => text()();
  DateTimeColumn get savedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

/// Last `get_explore_candidates` payload per canon (features/07 §7.5): Explore ranks it on open,
/// so rows show at once and offline; refetched when older than 6 h.
class ExploreCache extends Table {
  TextColumn get mediaType => text()();
  TextColumn get json => text()();
  DateTimeColumn get savedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {mediaType};
}

/// The caller's tracked titles (features/11 §9.2): one row per title, mirroring
/// `get_my_tracking`. Writes land here first (0 ms UI) and are replayed by the sync engine.
/// `seasons`, `nextEpisode` and `lastAired` hold the server's JSON for that part of the item.
class TrackingCache extends Table {
  IntColumn get titleId => integer()();
  TextColumn get mediaType => text()(); // 'movie' or 'tv' (Dual-Canon Partition)
  TextColumn get title => text()();
  TextColumn get posterPath => text().nullable()();
  TextColumn get backdropPath => text().nullable()();
  TextColumn get titleStatus => text().nullable()(); // TMDB status: 'Ended', 'Returning Series', ...
  IntColumn get runtimeMinutes => integer().nullable()();
  IntColumn get lastSeason => integer().nullable()();
  IntColumn get lastEpisode => integer().nullable()();
  TextColumn get state => text().withDefault(const Constant('WATCHING'))(); // tracking_state_enum
  BoolColumn get isRewatch => boolean().withDefault(const Constant(false))();
  DateTimeColumn get newEpisodesSince => dateTime().nullable()();
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastProgressAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  TextColumn get seasons => text().nullable()(); // JSON [{number, episode_count, air_date}]
  IntColumn get watched => integer().nullable()();
  IntColumn get airedTotal => integer().nullable()();
  TextColumn get nextEpisode => text().nullable()(); // JSON {season, episode, name, still_path, ...}
  TextColumn get lastAired => text().nullable()(); // JSON {season, episode}
  BoolColumn get ranked => boolean().withDefault(const Constant(false))();
  IntColumn get rankPosition => integer().nullable()();
  RealColumn get score => real().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('SYNCED'))(); // 'SYNCED', 'PENDING'

  @override
  Set<Column> get primaryKey => {titleId, mediaType};
}

/// One season's episodes from `tmdb-season`, one JSON document per season (features/11 §9.2).
/// Refetched when older than 7 days.
class EpisodeCache extends Table {
  IntColumn get titleId => integer()();
  IntColumn get seasonNumber => integer()();
  TextColumn get json => text()();
  DateTimeColumn get fetchedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {titleId, seasonNumber};
}

// --- DAOS ---

@DriftAccessor(tables: [LocalRankings])
class LocalRankingDao extends DatabaseAccessor<AppDatabase> with _$LocalRankingDaoMixin {
  LocalRankingDao(super.db);

  /// Watch live canon rankings strictly filtered by media_type (Dual-Canon Segregation).
  Stream<List<LocalRanking>> watchRankingsByCanon(String mediaType) {
    return (select(localRankings)
          ..where((tbl) => tbl.mediaType.equals(mediaType))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.rankPosition)]))
        .watch();
  }

  /// Query snapshot of current canon rankings.
  Future<List<LocalRanking>> getRankingsByCanon(String mediaType) {
    return (select(localRankings)
          ..where((tbl) => tbl.mediaType.equals(mediaType))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.rankPosition)]))
        .get();
  }

  /// Insert or update a single ranking slot.
  Future<void> upsertRanking(LocalRankingsCompanion entry) {
    return into(localRankings).insertOnConflictUpdate(entry);
  }

  /// Remove an entry from the canon.
  Future<int> deleteRanking(int showId, String mediaType) {
    return (delete(localRankings)
          ..where((tbl) => tbl.showId.equals(showId) & tbl.mediaType.equals(mediaType)))
        .go();
  }

  /// Atomically update order for an entire canon rebalance.
  Future<void> updateBatchRanks(List<LocalRankingsCompanion> entries) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(localRankings, entries);
    });
  }

  /// Clear all rankings for a canon (e.g. on reset).
  Future<int> clearCanon(String mediaType) {
    return (delete(localRankings)..where((tbl) => tbl.mediaType.equals(mediaType))).go();
  }

}

@DriftAccessor(tables: [PendingMutations])
class PendingMutationDao extends DatabaseAccessor<AppDatabase> with _$PendingMutationDaoMixin {
  PendingMutationDao(super.db);

  /// Appends a mutation and returns its client mutation id.
  Future<String> enqueue(String kind, Map<String, Object?> payload, {String? id}) async {
    final mutationId = id ?? const Uuid().v4();
    await into(pendingMutations).insert(
      PendingMutationsCompanion.insert(id: mutationId, kind: kind, payload: jsonEncode(payload)),
    );
    return mutationId;
  }

  /// All pending mutations, oldest first.
  Future<List<PendingMutation>> getAllFifo() =>
      (select(pendingMutations)..orderBy([(t) => OrderingTerm(expression: t.seq)])).get();

  Stream<int> watchCount() => pendingMutations.count().watchSingle();

  Future<int> count() => pendingMutations.count().getSingle();

  Future<void> remove(String id) => (delete(pendingMutations)..where((t) => t.id.equals(id))).go();

  Future<void> recordFailure(String id, String error) => (update(pendingMutations)..where((t) => t.id.equals(id)))
      .write(PendingMutationsCompanion.custom(attempts: pendingMutations.attempts + const Constant(1), lastError: Variable(error)));
}

@DriftAccessor(tables: [CachedTitles])
class LocalTitleDao extends DatabaseAccessor<AppDatabase> with _$LocalTitleDaoMixin {
  LocalTitleDao(super.db);

  Stream<List<CachedTitle>> watchTitlesByMediaType(String mediaType) {
    return (select(cachedTitles)
          ..where((tbl) => tbl.mediaType.equals(mediaType))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.title)]))
        .watch();
  }

  Future<CachedTitle?> getTitleById(int id, String mediaType) {
    return (select(cachedTitles)
          ..where((tbl) => tbl.id.equals(id) & tbl.mediaType.equals(mediaType)))
        .getSingleOrNull();
  }

  Future<void> upsertTitle(CachedTitlesCompanion entry) {
    return into(cachedTitles).insertOnConflictUpdate(entry);
  }

  Future<void> upsertBatchTitles(List<CachedTitlesCompanion> entries) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(cachedTitles, entries);
    });
  }

  Future<List<CachedTitle>> searchTitles(String query, {String? mediaType}) {
    final search = select(cachedTitles);
    if (mediaType != null) {
      search.where((tbl) => tbl.mediaType.equals(mediaType));
    }
    search.where((tbl) => tbl.title.like('%$query%'));
    return search.get();
  }
}

@DriftAccessor(tables: [ExploreCache])
class ExploreCacheDao extends DatabaseAccessor<AppDatabase> with _$ExploreCacheDaoMixin {
  ExploreCacheDao(super.db);

  Future<ExploreCacheData?> read(String mediaType) =>
      (select(exploreCache)..where((t) => t.mediaType.equals(mediaType))).getSingleOrNull();

  Future<void> write(String mediaType, String json, DateTime savedAt) => into(exploreCache)
      .insertOnConflictUpdate(ExploreCacheCompanion.insert(mediaType: mediaType, json: json, savedAt: Value(savedAt)));
}

@DriftAccessor(tables: [TrackingCache])
class TrackingCacheDao extends DatabaseAccessor<AppDatabase> with _$TrackingCacheDaoMixin {
  TrackingCacheDao(super.db);

  Stream<List<TrackingCacheData>> watchAll() =>
      (select(trackingCache)..orderBy([(t) => OrderingTerm.desc(t.lastProgressAt)])).watch();

  Future<List<TrackingCacheData>> getAll() =>
      (select(trackingCache)..orderBy([(t) => OrderingTerm.desc(t.lastProgressAt)])).get();

  Stream<TrackingCacheData?> watchOne(int titleId, String mediaType) => (select(trackingCache)
        ..where((t) => t.titleId.equals(titleId) & t.mediaType.equals(mediaType)))
      .watchSingleOrNull();

  Future<TrackingCacheData?> getOne(int titleId, String mediaType) => (select(trackingCache)
        ..where((t) => t.titleId.equals(titleId) & t.mediaType.equals(mediaType)))
      .getSingleOrNull();

  Future<void> upsert(TrackingCacheCompanion entry) => into(trackingCache).insertOnConflictUpdate(entry);

  Future<int> remove(int titleId, String mediaType) => (delete(trackingCache)
        ..where((t) => t.titleId.equals(titleId) & t.mediaType.equals(mediaType)))
      .go();

  /// Replaces the cache with [rows], except titles in [keep] (they have mutations still pending,
  /// so the local copy is newer than the server's). Rows not in [rows] and not in [keep] are
  /// deleted: they were stopped on another device.
  ///
  /// A row that turned PENDING after [keep] was worked out (the user acted while the server call
  /// was in flight) is kept too, so a refresh never undoes a change that is still being queued.
  Future<void> replaceSynced(List<TrackingCacheCompanion> rows, Set<(int, String)> keep) =>
      transaction(() async {
        final incoming = {for (final r in rows) (r.titleId.value, r.mediaType.value)};
        final existing = await getAll();
        final protected = {
          ...keep,
          for (final e in existing)
            if (e.syncStatus == 'PENDING') (e.titleId, e.mediaType),
        };
        for (final e in existing) {
          final key = (e.titleId, e.mediaType);
          if (!incoming.contains(key) && !protected.contains(key)) await remove(e.titleId, e.mediaType);
        }
        for (final r in rows) {
          if (!protected.contains((r.titleId.value, r.mediaType.value))) await upsert(r);
        }
      });

  Future<void> markSynced(int titleId, String mediaType) => (update(trackingCache)
        ..where((t) => t.titleId.equals(titleId) & t.mediaType.equals(mediaType)))
      .write(const TrackingCacheCompanion(syncStatus: Value('SYNCED')));
}

@DriftAccessor(tables: [EpisodeCache])
class EpisodeCacheDao extends DatabaseAccessor<AppDatabase> with _$EpisodeCacheDaoMixin {
  EpisodeCacheDao(super.db);

  Future<EpisodeCacheData?> read(int titleId, int seasonNumber) => (select(episodeCache)
        ..where((t) => t.titleId.equals(titleId) & t.seasonNumber.equals(seasonNumber)))
      .getSingleOrNull();

  Future<List<EpisodeCacheData>> readTitle(int titleId) =>
      (select(episodeCache)..where((t) => t.titleId.equals(titleId))).get();

  Future<void> write(int titleId, int seasonNumber, String json, DateTime fetchedAt) =>
      into(episodeCache).insertOnConflictUpdate(
        EpisodeCacheCompanion.insert(
          titleId: titleId,
          seasonNumber: seasonNumber,
          json: json,
          fetchedAt: Value(fetchedAt),
        ),
      );
}

// --- MASTER DATABASE ---

@DriftDatabase(
  tables: [
    CachedTitles,
    LocalRankings,
    PendingMutations,
    WatchlistCache,
    GamificationCache,
    ExploreCache,
    TrackingCache,
    EpisodeCache,
  ],
  daos: [
    LocalRankingDao,
    LocalTitleDao,
    PendingMutationDao,
    ExploreCacheDao,
    TrackingCacheDao,
    EpisodeCacheDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          try {
            if (from < 2) await _migrateV1ToV2(m);
            if (from < 3) await m.createTable(gamificationCache);
            if (from < 4) await m.createTable(exploreCache);
            if (from < 5) {
              await m.createTable(trackingCache);
              await m.createTable(episodeCache);
            }
          } catch (e, stack) {
            await SentryService().captureException(
              e,
              stack,
              {'from': from, 'to': to},
              'drift_migration_upgrade',
            );
            rethrow;
          }
        },
      );

  /// v1 → v2: `PendingMutations` replaces `offline_duel_queue` (unsent duels are carried
  /// over as `duels` mutations) and `local_rankings` gains `favorite_character`.
  Future<void> _migrateV1ToV2(Migrator m) async {
    await m.createTable(pendingMutations);
    await m.addColumn(localRankings, localRankings.favoriteCharacter);
    final legacy = await customSelect(
      "SELECT id, winner_title_id, loser_title_id, media_type FROM offline_duel_queue "
      "WHERE sync_status = 'PENDING' ORDER BY created_at, rowid",
    ).get();
    for (final row in legacy) {
      await pendingMutationDao.enqueue(MutationKind.duels, {
        'duels': [
          {
            'client_mutation_id': const Uuid().v4(),
            'winner_title_id': row.read<int>('winner_title_id'),
            'loser_title_id': row.read<int>('loser_title_id'),
            'media_type': row.read<String>('media_type'),
          },
        ],
      });
    }
    await customStatement('DROP TABLE IF EXISTS offline_duel_queue');
  }

  /// Wipes all local SQLite tables (rankings, watchlist, mutations, titles) on account deletion.
  Future<void> wipeLocalData() async {
    await transaction(() async {
      await delete(localRankings).go();
      await delete(watchlistCache).go();
      await delete(pendingMutations).go();
      await delete(cachedTitles).go();
      await delete(gamificationCache).go();
      await delete(trackingCache).go();
      await delete(episodeCache).go();
    });
  }

  static AppDatabase inMemory() {
    return AppDatabase(NativeDatabase.memory());
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'telly.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

