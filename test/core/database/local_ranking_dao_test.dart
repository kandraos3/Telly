import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';

void main() {
  late AppDatabase db;
  late LocalRankingDao rankingDao;
  late LocalTitleDao titleDao;

  setUp(() {
    // In-memory SQLite for high-speed, isolated unit tests
    db = AppDatabase(NativeDatabase.memory());
    rankingDao = db.localRankingDao;
    titleDao = db.localTitleDao;
  });

  tearDown(() async {
    await db.close();
  });

  group('LocalRankingDao & Dual-Canon Partition Tests', () {
    test('Dual-Canon Segregation: Movie and TV rankings are strictly partitioned', () async {
      // 1. Insert a TV series ranking (Succession, rank #1)
      await rankingDao.upsertRanking(
        LocalRankingsCompanion.insert(
          showId: 76331,
          mediaType: 'tv',
          title: 'Succession',
          rankPosition: 1,
          calculatedScore: 9.85,
          bracket: const Value('top_10'),
          syncStatus: const Value('SYNCED'),
        ),
      );

      // 2. Insert a Movie ranking (The Dark Knight, rank #1)
      await rankingDao.upsertRanking(
        LocalRankingsCompanion.insert(
          showId: 155,
          mediaType: 'movie',
          title: 'The Dark Knight',
          rankPosition: 1,
          calculatedScore: 9.90,
          bracket: const Value('top_10'),
          syncStatus: const Value('SYNCED'),
        ),
      );

      // 3. Query TV Canon: must only contain Succession
      final tvRankings = await rankingDao.getRankingsByCanon('tv');
      expect(tvRankings.length, equals(1));
      expect(tvRankings.first.title, equals('Succession'));
      expect(tvRankings.first.mediaType, equals('tv'));

      // 4. Query Movie Canon: must only contain The Dark Knight
      final movieRankings = await rankingDao.getRankingsByCanon('movie');
      expect(movieRankings.length, equals(1));
      expect(movieRankings.first.title, equals('The Dark Knight'));
      expect(movieRankings.first.mediaType, equals('movie'));
    });

    test('Reactive Stream Watcher emits when canon ranking is added or updated', () async {
      final expectation = expectLater(
        rankingDao.watchRankingsByCanon('tv'),
        emitsInOrder([
          hasLength(1),
          hasLength(2),
        ]),
      );

      // Add #1
      await rankingDao.upsertRanking(
        LocalRankingsCompanion.insert(
          showId: 1,
          mediaType: 'tv',
          title: 'Severance',
          rankPosition: 1,
          calculatedScore: 9.95,
        ),
      );

      // Add #2
      await rankingDao.upsertRanking(
        LocalRankingsCompanion.insert(
          showId: 2,
          mediaType: 'tv',
          title: 'The Bear',
          rankPosition: 2,
          calculatedScore: 9.75,
        ),
      );

      await expectation;
    });

    test('Batch rank update rebalances canon slots correctly', () async {
      await rankingDao.upsertRanking(
        LocalRankingsCompanion.insert(
          showId: 10,
          mediaType: 'tv',
          title: 'Show A',
          rankPosition: 1,
          calculatedScore: 9.5,
        ),
      );

      await rankingDao.upsertRanking(
        LocalRankingsCompanion.insert(
          showId: 20,
          mediaType: 'tv',
          title: 'Show B',
          rankPosition: 2,
          calculatedScore: 9.0,
        ),
      );

      // Rebalance: swap ranks
      await rankingDao.updateBatchRanks([
        LocalRankingsCompanion.insert(
          showId: 10,
          mediaType: 'tv',
          title: 'Show A',
          rankPosition: 2,
          calculatedScore: 9.0,
        ),
        LocalRankingsCompanion.insert(
          showId: 20,
          mediaType: 'tv',
          title: 'Show B',
          rankPosition: 1,
          calculatedScore: 9.5,
        ),
      ]);

      final rankings = await rankingDao.getRankingsByCanon('tv');
      expect(rankings.first.showId, equals(20));
      expect(rankings.first.rankPosition, equals(1));
      expect(rankings.last.showId, equals(10));
      expect(rankings.last.rankPosition, equals(2));
    });

    test('Delete ranking removes specific entry while preserving others', () async {
      await rankingDao.upsertRanking(
        LocalRankingsCompanion.insert(
          showId: 101,
          mediaType: 'tv',
          title: 'To Keep',
          rankPosition: 1,
          calculatedScore: 9.0,
        ),
      );
      await rankingDao.upsertRanking(
        LocalRankingsCompanion.insert(
          showId: 102,
          mediaType: 'tv',
          title: 'To Delete',
          rankPosition: 2,
          calculatedScore: 8.0,
        ),
      );

      final deleted = await rankingDao.deleteRanking(102, 'tv');
      expect(deleted, equals(1));

      final remaining = await rankingDao.getRankingsByCanon('tv');
      expect(remaining.length, equals(1));
      expect(remaining.first.showId, equals(101));
    });
  });

  group('LocalTitleDao Cache & Search Tests', () {
    test('Title caching and substring search', () async {
      await titleDao.upsertBatchTitles([
        CachedTitlesCompanion.insert(
          id: 100,
          title: 'Breaking Bad',
          mediaType: 'tv',
          overview: const Value('A high school chemistry teacher...'),
        ),
        CachedTitlesCompanion.insert(
          id: 101,
          title: 'Better Call Saul',
          mediaType: 'tv',
          overview: const Value('The trials and tribulations...'),
        ),
        CachedTitlesCompanion.insert(
          id: 200,
          title: 'Bad Boys',
          mediaType: 'movie',
          overview: const Value('Miami detectives...'),
        ),
      ]);

      // Search TV titles for "Bad"
      final tvResults = await titleDao.searchTitles('Bad', mediaType: 'tv');
      expect(tvResults.length, equals(1));
      expect(tvResults.first.title, equals('Breaking Bad'));

      // Search all titles for "Bad"
      final allResults = await titleDao.searchTitles('Bad');
      expect(allResults.length, equals(2));
    });
  });
}
