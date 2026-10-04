import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

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

// --- MASTER DATABASE ---

@DriftDatabase(
  tables: [CachedTitles, LocalRankings, PendingMutations, WatchlistCache],
  daos: [LocalRankingDao, LocalTitleDao, PendingMutationDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) await _migrateV1ToV2(m);
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

