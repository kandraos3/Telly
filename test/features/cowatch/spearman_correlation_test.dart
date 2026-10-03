import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/cowatch/domain/spearman_taste_match_calculator.dart';

void main() {
  group('QA-401: Spearman Rank Correlation & Bayesian Shrinkage Tests', () {
    test('Boundary: less than 2 mutual titles returns neutral 50% prior', () {
      final emptyResult = SpearmanTasteMatchCalculator.calculate(
        pairedRanks: [],
      );
      expect(emptyResult.matchPercentage, 50);
      expect(emptyResult.rawRho, 0.0);
      expect(emptyResult.mutualTitleCount, 0);
      expect(emptyResult.affinityTier, TasteAffinityTier.casualAcquaintances);

      final singleItemResult = SpearmanTasteMatchCalculator.calculate(
        pairedRanks: [(1, 1)],
      );
      expect(singleItemResult.matchPercentage, 50);
      expect(singleItemResult.mutualTitleCount, 1);
    });

    test('Identical rankings produce raw rho = 1.0', () {
      // 5 identical items
      final result = SpearmanTasteMatchCalculator.calculate(
        pairedRanks: [
          (1, 1),
          (2, 2),
          (3, 3),
          (4, 4),
          (5, 5),
        ],
      );

      expect(result.rawRho, 1.0);
      // k=5, k0=5 => weight = 5 / 10 = 0.5
      // adjustedRho = 0.5 * 1.0 = 0.5
      // match = round((1.5 / 2.0) * 100) = 75%
      expect(result.adjustedRho, 0.5);
      expect(result.matchPercentage, 75);
      expect(result.affinityTier, TasteAffinityTier.kindredSpirits);
    });

    test('Completely inverted rankings produce raw rho = -1.0', () {
      // 5 completely reversed items: User A: [1,2,3,4,5], User B: [5,4,3,2,1]
      final result = SpearmanTasteMatchCalculator.calculate(
        pairedRanks: [
          (1, 5),
          (2, 4),
          (3, 3),
          (4, 2),
          (5, 1),
        ],
      );

      expect(result.rawRho, -1.0);
      // adjustedRho = 0.5 * -1.0 = -0.5
      // match = round((0.5 / 2.0) * 100) = 25%
      expect(result.adjustedRho, -0.5);
      expect(result.matchPercentage, 25);
      expect(result.affinityTier, TasteAffinityTier.oppositeEnds);
    });

    test('Shrinkage invariant: 2 overlapping titles with identical order yields <= 65% match', () {
      // Spec requirement QA-401: 2 overlapping titles with identical order yields <= 65% match due to prior k0 = 5
      final result = SpearmanTasteMatchCalculator.calculate(
        pairedRanks: [
          (1, 1),
          (2, 2),
        ],
      );

      expect(result.rawRho, 1.0);
      // W = 2 / (2 + 5) = 2 / 7 = 0.2857
      // adjRho = 2 / 7
      // match % = ((2/7 + 1) / 2) * 100 = 64% <= 65%
      expect(result.matchPercentage, lessThanOrEqualTo(65));
      expect(result.matchPercentage, 64);
    });

    test('Large sample size (k=45) approaches full raw confidence', () {
      // 45 items with identical ranks
      final pairs = List.generate(45, (i) => (i + 1, i + 1));
      final result = SpearmanTasteMatchCalculator.calculate(pairedRanks: pairs);

      expect(result.rawRho, 1.0);
      // W = 45 / (45 + 5) = 45 / 50 = 0.90
      // adjRho = 0.90
      // match % = round((1.90 / 2.0) * 100) = 95%
      expect(result.matchPercentage, 95);
      expect(result.affinityTier, TasteAffinityTier.tasteTwins);
    });

    test('calculateBlendedMatch computes sample-weighted average between media', () {
      // 30 movies with 90% match, 10 series with 70% match
      // Total = 40 items. Weighted = (90*30 + 70*10) / 40 = (2700 + 700) / 40 = 3400 / 40 = 85%
      final blended = SpearmanTasteMatchCalculator.calculateBlendedMatch(
        movieMatchPct: 90,
        movieCount: 30,
        seriesMatchPct: 70,
        seriesCount: 10,
      );

      expect(blended, 85);
    });

    test('Separates top agreements and spiciest clashes accurately', () {
      final comparisons = [
        const RankedTitleComparison(
          showId: 1,
          title: 'Succession',
          rankA: 1,
          rankB: 2,
          scoreA: 10.0,
          scoreB: 9.8,
        ),
        const RankedTitleComparison(
          showId: 2,
          title: 'Game of Thrones',
          rankA: 4,
          rankB: 44,
          scoreA: 9.2,
          scoreB: 6.0,
        ),
        const RankedTitleComparison(
          showId: 3,
          title: 'Severance',
          rankA: 3,
          rankB: 3,
          scoreA: 9.5,
          scoreB: 9.5,
        ),
      ];

      final pairedRanks = comparisons.map((c) => (c.rankA, c.rankB)).toList();
      final result = SpearmanTasteMatchCalculator.calculate(
        pairedRanks: pairedRanks,
        detailedComparisons: comparisons,
      );

      // Top agreement should be Severance (delta = 0), followed by Succession (delta = 1)
      expect(result.topAgreements.first.title, 'Severance');
      expect(result.topAgreements.first.rankDelta, 0);

      // Spiciest clash should be Game of Thrones (delta = 40)
      expect(result.spiciestClashes.first.title, 'Game of Thrones');
      expect(result.spiciestClashes.first.rankDelta, 40);
    });
  });
}

