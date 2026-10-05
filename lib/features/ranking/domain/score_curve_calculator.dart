import 'dart:math' as math;

import 'canon_tier.dart';

export 'canon_tier.dart';

/// Dynamic Percentile Score Curve Calculator for the Telly Personal Canon.
///
/// Implements the canonical curve from `docs/features/02_PAIRWISE_RANKING_ENGINE_AND_LOGGING.md` §3.3:
/// - $\text{raw}(r) = 1 + 9 \cdot \left(\frac{N - r}{N - 1}\right)^{0.82}$
/// - for $N < 10$: blended with the prior $\max(1, 10 - 0.5(r-1))$ using $\alpha = N / 10$
///
/// The server RPC `insert_user_ranking_atomic` must produce identical values; both
/// are checked against `test/fixtures/score_curve_vectors.json`.
class ScoreCurveCalculator {
  /// Power curve exponent $\gamma$ (features/02 §3.3, decision D3).
  static const double defaultExponent = 0.82;

  /// Canon size at which the Bayesian prior stops being blended in.
  static const int bayesianConvergenceCount = 10;

  /// Calculates the dynamic percentile score for rank [rank] in a canon of size [totalCount].
  ///
  /// - [rank]: 1-indexed rank position ($1 \le rank \le totalCount$).
  /// - [totalCount]: Total number of ranked items in this canon.
  /// - [applyBayesianPrior]: If true, applies the prior blending when $totalCount < 10$.
  ///
  /// Returns a high-precision [double] between 1.00 and 10.00.
  static double calculateScore(
    int rank,
    int totalCount, {
    double exponent = defaultExponent,
    bool applyBayesianPrior = true,
  }) {
    if (totalCount <= 0) {
      throw ArgumentError.value(totalCount, 'totalCount', 'Must be at least 1.');
    }
    if (rank < 1 || rank > totalCount) {
      throw RangeError.range(rank, 1, totalCount, 'rank', 'Rank must be between 1 and totalCount.');
    }

    if (totalCount == 1) {
      return 10.00;
    }

    final percentile = (totalCount - rank) / (totalCount - 1);
    final rawScore = 1.00 + 9.00 * math.pow(percentile, exponent);

    if (!applyBayesianPrior || totalCount >= bayesianConvergenceCount) {
      return rawScore;
    }

    final alpha = totalCount / bayesianConvergenceCount;
    final priorScore = math.max(1.00, 10.00 - (rank - 1) * 0.50);
    return (alpha * rawScore) + ((1.0 - alpha) * priorScore);
  }

  /// Calculates score rounded to two decimal places (e.g. 9.42).
  static double calculateRoundedScore(
    int rank,
    int totalCount, {
    double exponent = defaultExponent,
    bool applyBayesianPrior = true,
  }) {
    final raw = calculateScore(
      rank,
      totalCount,
      exponent: exponent,
      applyBayesianPrior: applyBayesianPrior,
    );
    return double.parse(raw.toStringAsFixed(2));
  }

  /// Returns the [CanonTier] for a given rank and canon size.
  /// Completed canon entries are never assigned [CanonTier.dropped] unless [isAbandoned] is true.
  static CanonTier getTier(
    int rank,
    int totalCount, {
    double exponent = defaultExponent,
    bool applyBayesianPrior = true,
    bool isAbandoned = false,
  }) {
    return CanonTier.fromScore(
      calculateRoundedScore(
        rank,
        totalCount,
        exponent: exponent,
        applyBayesianPrior: applyBayesianPrior,
      ),
      isAbandoned: isAbandoned,
    );
  }
}
