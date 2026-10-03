import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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
  TextColumn get syncStatus => text().withDefault(const Constant('SYNCED'))(); // 'SYNCED', 'PENDING'
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {showId, mediaType};
}

class OfflineDuelQueue extends Table {
  TextColumn get id => text()(); // UUID
  IntColumn get winnerTitleId => integer()();
  IntColumn get loserTitleId => integer()();
  TextColumn get mediaType => text()(); // 'movie' or 'tv'
  IntColumn get roundNumber => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))(); // 'PENDING', 'SYNCED'

  @override
  Set<Column> get primaryKey => {id};
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
  tables: [CachedTitles, LocalRankings, OfflineDuelQueue, WatchlistCache],
  daos: [LocalRankingDao, LocalTitleDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

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

