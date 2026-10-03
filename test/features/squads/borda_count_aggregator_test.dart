import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/squads/domain/squad_canon_aggregator.dart';

void main() {
  group('QA-301: SquadCanonAggregator (Borda Count) Invariants', () {
    test('3 users with overlapping canons generate accurate Borda points and ranking', () {
      // 3 members: Alex (N=3), Jordan (N=3), Maya (N=3)
      // Title 1: Succession
      // Title 2: Severance
      // Title 3: The Bear
      //
      // Alex ranks:
      // #1 Succession (points: 3 - 1 + 1 = 3)
      // #2 Severance (points: 3 - 2 + 1 = 2)
      // #3 The Bear (points: 3 - 3 + 1 = 1)
      //
      // Jordan ranks:
      // #1 Succession (points: 3 - 1 + 1 = 3)
      // #2 The Bear (points: 3 - 2 + 1 = 2)
      // #3 Severance (points: 3 - 3 + 1 = 1)
      //
      // Maya ranks:
      // #1 Severance (points: 3 - 1 + 1 = 3)
      // #2 Succession (points: 3 - 2 + 1 = 2)
      // #3 The Bear (points: 3 - 3 + 1 = 1)
      //
      // Expected total points:
      // Succession: 3 + 3 + 2 = 8 pts -> Consensus #1
      // Severance:  2 + 1 + 3 = 6 pts -> Consensus #2
      // The Bear:   1 + 2 + 1 = 4 pts -> Consensus #3

      final entries = [
        // Alex
        const MemberRankEntry(
          userId: 'u_alex',
          displayName: 'Alex',
          titleId: 1,
          title: 'Succession',
          releaseYear: 2018,
          rankPosition: 1,
        ),
        const MemberRankEntry(
          userId: 'u_alex',
          displayName: 'Alex',
          titleId: 2,
          title: 'Severance',
          releaseYear: 2022,
          rankPosition: 2,
        ),
        const MemberRankEntry(
          userId: 'u_alex',
          displayName: 'Alex',
          titleId: 3,
          title: 'The Bear',
          releaseYear: 2022,
          rankPosition: 3,
        ),
        // Jordan
        const MemberRankEntry(
          userId: 'u_jordan',
          displayName: 'Jordan',
          titleId: 1,
          title: 'Succession',
          releaseYear: 2018,
          rankPosition: 1,
        ),
        const MemberRankEntry(
          userId: 'u_jordan',
          displayName: 'Jordan',
          titleId: 3,
          title: 'The Bear',
          releaseYear: 2022,
          rankPosition: 2,
        ),
        const MemberRankEntry(
          userId: 'u_jordan',
          displayName: 'Jordan',
          titleId: 2,
          title: 'Severance',
          releaseYear: 2022,
          rankPosition: 3,
        ),
        // Maya
        const MemberRankEntry(
          userId: 'u_maya',
          displayName: 'Maya',
          titleId: 2,
          title: 'Severance',
          releaseYear: 2022,
          rankPosition: 1,
        ),
        const MemberRankEntry(
          userId: 'u_maya',
          displayName: 'Maya',
          titleId: 1,
          title: 'Succession',
          releaseYear: 2018,
          rankPosition: 2,
        ),
        const MemberRankEntry(
          userId: 'u_maya',
          displayName: 'Maya',
          titleId: 3,
          title: 'The Bear',
          releaseYear: 2022,
          rankPosition: 3,
        ),
      ];

      final consensus = SquadCanonAggregator.calculateConsensusCanon(
        entries: entries,
        mediaType: 'tv',
      );

      expect(consensus.length, equals(3));

      // Check #1 Succession
      expect(consensus[0].consensusRank, equals(1));
      expect(consensus[0].title, equals('Succession'));
      expect(consensus[0].totalBordaPoints, equals(8));
      expect(consensus[0].membersRankedCount, equals(3));
      expect(consensus[0].championRank, equals(1));
      expect(consensus[0].lowestRank, equals(2));

      // Check #2 Severance
      expect(consensus[1].consensusRank, equals(2));
      expect(consensus[1].title, equals('Severance'));
      expect(consensus[1].totalBordaPoints, equals(6));
      expect(consensus[1].championDisplayName, equals('Maya'));
      expect(consensus[1].lowestDisplayName, equals('Jordan'));

      // Check #3 The Bear
      expect(consensus[2].consensusRank, equals(3));
      expect(consensus[2].title, equals('The Bear'));
      expect(consensus[2].totalBordaPoints, equals(4));
    });

    test('handles incomplete overlaps (titles ranked by only subset of members)', () {
      final entries = [
        // User 1 ranked 2 shows
        const MemberRankEntry(
          userId: 'u1',
          displayName: 'User 1',
          titleId: 10,
          title: 'Dark',
          releaseYear: 2017,
          rankPosition: 1,
        ),
        const MemberRankEntry(
          userId: 'u1',
          displayName: 'User 1',
          titleId: 20,
          title: 'Lost',
          releaseYear: 2004,
          rankPosition: 2,
        ),
        // User 2 ranked only Dark
        const MemberRankEntry(
          userId: 'u2',
          displayName: 'User 2',
          titleId: 10,
          title: 'Dark',
          releaseYear: 2017,
          rankPosition: 1,
        ),
      ];

      final consensus = SquadCanonAggregator.calculateConsensusCanon(
        entries: entries,
        mediaType: 'tv',
      );

      expect(consensus.length, equals(2));
      // Dark: u1 gives (2 - 1 + 1) = 2 pts. u2 gives (1 - 1 + 1) = 1 pt. Total = 3 pts
      expect(consensus[0].title, equals('Dark'));
      expect(consensus[0].totalBordaPoints, equals(3));
      expect(consensus[0].membersRankedCount, equals(2));

      // Lost: u1 gives (2 - 2 + 1) = 1 pt. Total = 1 pt
      expect(consensus[1].title, equals('Lost'));
      expect(consensus[1].totalBordaPoints, equals(1));
      expect(consensus[1].membersRankedCount, equals(1));
    });

    test('filters by designated media type strictly', () {
      final entries = [
        const MemberRankEntry(
          userId: 'u1',
          displayName: 'User 1',
          titleId: 100,
          title: 'Interstellar',
          releaseYear: 2014,
          mediaType: 'movie',
          rankPosition: 1,
        ),
        const MemberRankEntry(
          userId: 'u1',
          displayName: 'User 1',
          titleId: 200,
          title: 'Succession',
          releaseYear: 2018,
          mediaType: 'tv',
          rankPosition: 1,
        ),
      ];

      final movies = SquadCanonAggregator.calculateConsensusCanon(
        entries: entries,
        mediaType: 'movie',
      );
      expect(movies.length, equals(1));
      expect(movies.first.title, equals('Interstellar'));

      final series = SquadCanonAggregator.calculateConsensusCanon(
        entries: entries,
        mediaType: 'tv',
      );
      expect(series.length, equals(1));
      expect(series.first.title, equals('Succession'));
    });

    test('detects hot debate when rank divergence is large', () {
      final entries = [
        const MemberRankEntry(
          userId: 'u1',
          displayName: 'Alex',
          titleId: 50,
          title: 'Lost',
          releaseYear: 2004,
          rankPosition: 1,
        ),
        const MemberRankEntry(
          userId: 'u2',
          displayName: 'Sam',
          titleId: 50,
          title: 'Lost',
          releaseYear: 2004,
          rankPosition: 20,
        ),
      ];

      final consensus = SquadCanonAggregator.calculateConsensusCanon(
        entries: entries,
        mediaType: 'tv',
      );

      expect(consensus.first.isHotDebate, isTrue);
      expect(consensus.first.rankVariance, greaterThan(10.0));
    });
  });
}
