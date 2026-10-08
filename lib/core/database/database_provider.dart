import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database.dart';

/// Master Riverpod provider exposing the local Drift SQLite database singleton.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Provider exposing the [LocalRankingDao].
final localRankingDaoProvider = Provider<LocalRankingDao>((ref) {
  return ref.watch(databaseProvider).localRankingDao;
});

/// Provider exposing the [LocalTitleDao].
final localTitleDaoProvider = Provider<LocalTitleDao>((ref) {
  return ref.watch(databaseProvider).localTitleDao;
});


/// Provider exposing the [ExploreCacheDao] (features/07 §7.5).
final exploreCacheDaoProvider = Provider<ExploreCacheDao>((ref) {
  return ref.watch(databaseProvider).exploreCacheDao;
});
