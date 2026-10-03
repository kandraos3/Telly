import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/ranking/domain/score_curve_calculator.dart';

void main() {
  group('ALGO-202 / QA-202: ScoreCurveCalculator Invariants', () {
    test('Boundary Invariants: Rank 1 is always 10.00 across all N', () {
      for (final n in [1, 2, 3, 5, 10, 25, 50, 100, 500]) {
        final score = ScoreCurveCalculator.calculateScore(1, n);
        expect(score, closeTo(10.00, 0.0001),
            reason: 'Rank 1 with N=$n failed to return 10.00');

        final rounded = ScoreCurveCalculator.calculateRoundedScore(1, n);
        expect(rounded, equals(10.00));
      }
    });

    test('Boundary Invariants: Converged canons (N >= 10) have Score(N) = 1.00', () {
      for (final n in [10, 20, 50, 100, 500, 1000]) {
        final score = ScoreCurveCalculator.calculateScore(n, n);
        expect(score, closeTo(1.00, 0.0001),
            reason: 'Rank $n with N=$n failed to return 1.00');

        final rounded = ScoreCurveCalculator.calculateRoundedScore(n, n);
        expect(rounded, equals(1.00));
      }
    });

    test('Raw curve without Bayesian smoothing has Score(N) = 1.00 for any N > 1', () {
      for (final n in [2, 3, 4, 5, 8, 9]) {
        final rawScore = ScoreCurveCalculator.calculateScore(
          n,
          n,
          applyBayesianPrior: false,
        );
        expect(rawScore, closeTo(1.00, 0.0001));
      }
    });

    test('Bayesian smoothing softens bottom scores for early profiles (N < 10)', () {
      // For N = 3, raw score of 3rd show would be 1.00.
      final rawScore3 = ScoreCurveCalculator.calculateScore(3, 3, applyBayesianPrior: false);
      expect(rawScore3, closeTo(1.00, 0.0001));

      // With Bayesian smoothing, 3rd show gets a respectable score > 6.0
      final smoothedScore3 = ScoreCurveCalculator.calculateScore(3, 3, applyBayesianPrior: true);
      expect(smoothedScore3, greaterThan(6.0));
      expect(smoothedScore3, lessThan(10.0));

      // And 1st show is still 10.00
      final smoothedScore1 = ScoreCurveCalculator.calculateScore(1, 3, applyBayesianPrior: true);
      expect(smoothedScore1, closeTo(10.00, 0.0001));
    });

    test('Monotonic Strictly Decreasing: Score(i) > Score(i + 1) for all lists', () {
      for (final n in [2, 3, 5, 9, 10, 25, 100]) {
        for (int r = 1; r < n; r++) {
          final scoreA = ScoreCurveCalculator.calculateScore(r, n);
          final scoreB = ScoreCurveCalculator.calculateScore(r + 1, n);
          expect(scoreA, greaterThan(scoreB),
              reason: 'Score($r, $n) [$scoreA] was not strictly greater than Score(${r + 1}, $n) [$scoreB]');
        }
      }
    });

    test('CanonTier classification maps accurately to score tiers', () {
      expect(CanonTier.fromScore(10.00), equals(CanonTier.godTier));
      expect(CanonTier.fromScore(9.24), equals(CanonTier.godTier));
      expect(CanonTier.fromScore(8.50), equals(CanonTier.prestigeTier));
      expect(CanonTier.fromScore(7.41), equals(CanonTier.greatTier));
      expect(CanonTier.fromScore(5.30), equals(CanonTier.goodMidTier));
      expect(CanonTier.fromScore(2.38), equals(CanonTier.disappointment));
      expect(CanonTier.fromScore(1.00), equals(CanonTier.disappointment));

      // Check helper on calculator
      expect(ScoreCurveCalculator.getTier(1, 100), equals(CanonTier.godTier));
      expect(ScoreCurveCalculator.getTier(100, 100), equals(CanonTier.disappointment));
    });

    test('Property-based testing: 10,000 generated datasets obey invariants', () {
      final random = math.Random(42);

      for (int i = 0; i < 10000; i++) {
        // Random N between 2 and 500
        final n = 2 + random.nextInt(499);
        // Random rank r between 1 and n - 1
        final r = 1 + random.nextInt(n - 1);

        final scoreR = ScoreCurveCalculator.calculateScore(r, n);
        final scoreNext = ScoreCurveCalculator.calculateScore(r + 1, n);

        // Invariant 1: Range bounds
        expect(scoreR, greaterThanOrEqualTo(1.00));
        expect(scoreR, lessThanOrEqualTo(10.00));
        expect(scoreNext, greaterThanOrEqualTo(1.00));
        expect(scoreNext, lessThanOrEqualTo(10.00));

        // Invariant 2: Strictly monotonic decreasing
        expect(scoreR, greaterThan(scoreNext));
      }
    });

    test('Throws ArgumentError / RangeError on invalid parameters', () {
      expect(() => ScoreCurveCalculator.calculateScore(1, 0), throwsArgumentError);
      expect(() => ScoreCurveCalculator.calculateScore(1, -5), throwsArgumentError);
      expect(() => ScoreCurveCalculator.calculateScore(0, 10), throwsRangeError);
      expect(() => ScoreCurveCalculator.calculateScore(11, 10), throwsRangeError);
    });
  });
}
