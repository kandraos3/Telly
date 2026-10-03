import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/ranking/domain/franchise_rollup_service.dart';

void main() {
  group('FE-208: FranchiseRollupService Tests', () {
    test('rollup combines 4 Attack on Titan seasons into 1 parent entry with mean score', () {
      final seasons = [
        const CanonEntry(
          id: 1,
          title: 'Attack on Titan Season 1',
          mediaType: 'tv',
          rankPosition: 5,
          calculatedScore: 9.12,
          isAnime: true,
          franchiseId: 'attack-on-titan',
          franchiseName: 'Attack on Titan',
          seasonNumber: 1,
        ),
        const CanonEntry(
          id: 2,
          title: 'Attack on Titan Season 2',
          mediaType: 'tv',
          rankPosition: 7,
          calculatedScore: 8.90,
          isAnime: true,
          franchiseId: 'attack-on-titan',
          franchiseName: 'Attack on Titan',
          seasonNumber: 2,
        ),
        const CanonEntry(
          id: 3,
          title: 'Attack on Titan Season 3 Part 2',
          mediaType: 'tv',
          rankPosition: 2,
          calculatedScore: 9.85,
          isAnime: true,
          franchiseId: 'attack-on-titan',
          franchiseName: 'Attack on Titan',
          seasonNumber: 3,
        ),
        const CanonEntry(
          id: 4,
          title: 'Attack on Titan: The Final Season',
          mediaType: 'tv',
          rankPosition: 12,
          calculatedScore: 8.65,
          isAnime: true,
          franchiseId: 'attack-on-titan',
          franchiseName: 'Attack on Titan',
          seasonNumber: 4,
        ),
      ];

      const standaloneShow = CanonEntry(
        id: 100,
        title: 'Succession',
        mediaType: 'tv',
        rankPosition: 1,
        calculatedScore: 9.95,
      );

      final mixedList = [standaloneShow, ...seasons];

      final rolledUp = FranchiseRollupService.rollupFranchises(mixedList);

      // We expect 2 entries: Succession and Attack on Titan
      expect(rolledUp.length, equals(2));

      final aot = rolledUp.firstWhere((e) => e.franchiseId == 'attack-on-titan');
      expect(aot.isRolledUp, isTrue);
      expect(aot.title, equals('Attack on Titan'));
      expect(aot.subEntries.length, equals(4));

      // Expected composite score: (9.12 + 8.90 + 9.85 + 8.65) / 4 = 36.52 / 4 = 9.13
      expect(aot.calculatedScore, equals(9.13));

      // Verify ranks are continuous: 1, 2
      expect(rolledUp[0].rankPosition, equals(1)); // Succession (9.95)
      expect(rolledUp[1].rankPosition, equals(2)); // Attack on Titan (9.13)
    });

    test('unbundleFranchises restores child seasons and re-indexes ranks 1..N', () {
      const parentAot = CanonEntry(
        id: 1,
        title: 'Attack on Titan',
        mediaType: 'tv',
        rankPosition: 2,
        calculatedScore: 9.13,
        isRolledUp: true,
        franchiseId: 'attack-on-titan',
        subEntries: [
          CanonEntry(
            id: 1,
            title: 'Attack on Titan Season 1',
            mediaType: 'tv',
            rankPosition: 0,
            calculatedScore: 9.12,
            seasonNumber: 1,
          ),
          CanonEntry(
            id: 2,
            title: 'Attack on Titan Season 3 Part 2',
            mediaType: 'tv',
            rankPosition: 0,
            calculatedScore: 9.85,
            seasonNumber: 3,
          ),
        ],
      );

      const standaloneShow = CanonEntry(
        id: 100,
        title: 'Severance',
        mediaType: 'tv',
        rankPosition: 1,
        calculatedScore: 9.70,
      );

      final unbundled = FranchiseRollupService.unbundleFranchises([standaloneShow, parentAot]);

      expect(unbundled.length, equals(3));
      // Scores: AoT S3 P2 (9.85), Severance (9.70), AoT S1 (9.12)
      expect(unbundled[0].title, equals('Attack on Titan Season 3 Part 2'));
      expect(unbundled[0].rankPosition, equals(1));

      expect(unbundled[1].title, equals('Severance'));
      expect(unbundled[1].rankPosition, equals(2));

      expect(unbundled[2].title, equals('Attack on Titan Season 1'));
      expect(unbundled[2].rankPosition, equals(3));
    });

    test('rollup with empty list returns empty list', () {
      expect(FranchiseRollupService.rollupFranchises([]), isEmpty);
      expect(FranchiseRollupService.unbundleFranchises([]), isEmpty);
    });
  });
}
