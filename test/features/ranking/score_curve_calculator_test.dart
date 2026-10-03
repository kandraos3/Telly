import 'dart:convert';
import 'dart:io';
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

    test('features/02 §3.3 table: exact gamma = 0.82 values for N = 100', () {
      const expected = {1: 10.00, 5: 9.70, 15: 8.94, 35: 7.37, 60: 5.28, 90: 2.37};
      expected.forEach((rank, score) {
        expect(ScoreCurveCalculator.calculateRoundedScore(rank, 100), score, reason: 'rank #$rank');
      });
      expect(ScoreCurveCalculator.defaultExponent, 0.82);
    });

    test('N < 10 prior matches the spec formula exactly', () {
      // N = 3, r = 2: alpha = 0.3, raw = 1 + 9 * 0.5^0.82, prior = 9.5
      final raw = 1 + 9 * math.pow(0.5, 0.82);
      expect(ScoreCurveCalculator.calculateScore(2, 3), closeTo(0.3 * raw + 0.7 * 9.5, 1e-12));
    });

    test('matches the shared Dart/SQL fixture test/fixtures/score_curve_vectors.json', () {
      final fixture = jsonDecode(File('test/fixtures/score_curve_vectors.json').readAsStringSync()) as Map<String, dynamic>;
      final vectors = (fixture['vectors'] as List).cast<Map<String, dynamic>>();
      expect(vectors, hasLength(180));
      for (final v in vectors) {
        expect(
          ScoreCurveCalculator.calculateRoundedScore(v['rank'] as int, v['n'] as int),
          (v['score'] as num).toDouble(),
          reason: 'N=${v['n']} rank=${v['rank']}',
        );
      }
    });

    test('CanonTier uses style guide §2.2 thresholds with inclusive lower bounds', () {
      expect(CanonTier.fromScore(10.00), CanonTier.god);
      expect(CanonTier.fromScore(9.20), CanonTier.god);
      expect(CanonTier.fromScore(9.19), CanonTier.prestige);
      expect(CanonTier.fromScore(8.50), CanonTier.prestige);
      expect(CanonTier.fromScore(8.49), CanonTier.great);
      expect(CanonTier.fromScore(7.80), CanonTier.great);
      expect(CanonTier.fromScore(7.79), CanonTier.good);
      expect(CanonTier.fromScore(7.00), CanonTier.good);
      expect(CanonTier.fromScore(6.99), CanonTier.mid);
      expect(CanonTier.fromScore(5.50), CanonTier.mid);
      expect(CanonTier.fromScore(5.49), CanonTier.dropped);
      expect(CanonTier.fromScore(1.00), CanonTier.dropped);
      // Floating-point noise around a boundary resolves at display precision.
      expect(CanonTier.fromScore(9.199999999), CanonTier.god);

      expect(CanonTier.prestige.rangeLabel, '8.50 – 9.19');
      expect(CanonTier.dropped.rangeLabel, '< 5.50');
      expect(ScoreCurveCalculator.getTier(1, 100), CanonTier.god);
      expect(ScoreCurveCalculator.getTier(100, 100), CanonTier.dropped);
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
