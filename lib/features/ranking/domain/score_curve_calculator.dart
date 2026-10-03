import 'dart:math' as math;

/// Canon tier classification based on dynamic percentile score.
/// Conforms to `docs/features/02_PAIRWISE_RANKING_ENGINE_AND_LOGGING.md` §3.3.
enum CanonTier {
  /// Score 9.00 - 10.00
  godTier('God Tier', 9.00),

  /// Score 8.00 - 8.99
  prestigeTier('Prestige Tier', 8.00),

  /// Score 7.00 - 7.99
  greatTier('Great Tier', 7.00),

  /// Score 5.00 - 6.99
  goodMidTier('Good / Mid', 5.00),

  /// Score 1.00 - 4.99
  disappointment('Disappointment', 1.00);

  final String label;
  final double minScore;

  const CanonTier(this.label, this.minScore);

  static CanonTier fromScore(double score) {
    if (score >= 9.00) return CanonTier.godTier;
    if (score >= 8.00) return CanonTier.prestigeTier;
    if (score >= 7.00) return CanonTier.greatTier;
    if (score >= 5.00) return CanonTier.goodMidTier;
    return CanonTier.disappointment;
  }
}

/// Dynamic Percentile Score Curve Calculator for the Telly Personal Canon.
///
/// Implements:
/// - Deterministic prestige percentile curve mapping rank $r \in [1, N]$ to $[1.00, 10.00]$
/// - Power curve exponent $p = 1.15$ weighting top-echelon titles
/// - Empirical Bayesian smoothing prior for profiles with $N < 10$ ranked titles
///
/// Conforms to:
/// - `docs/features/02_PAIRWISE_RANKING_ENGINE_AND_LOGGING.md` §3.3
/// - `docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md` §2.1
class ScoreCurveCalculator {
  /// Default power curve exponent per spec ($p = 1.15$)
  static const double defaultExponent = 1.15;

  /// Minimum threshold for pure raw percentile curve without Bayesian smoothing
  static const int bayesianConvergenceCount = 10;

  /// Calculates the dynamic percentile score for rank [rank] in a canon of size [totalCount].
  ///
  /// Parameters:
  /// - [rank]: 1-indexed rank position ($1 \le rank \le totalCount$).
  /// - [totalCount]: Total number of ranked items in this canon.
  /// - [exponent]: Power curve exponent (defaults to 1.15).
  /// - [applyBayesianPrior]: If true, applies Bayesian prior blending when $totalCount < 10$.
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

    // Edge case: exactly 1 item in canon
    if (totalCount == 1) {
      return 10.00;
    }

    // Raw percentile: 1.0 for rank 1, 0.0 for rank totalCount
    final rawPercentile = (totalCount - rank) / (totalCount - 1);
    final rawScore = 1.00 + 9.00 * math.pow(rawPercentile, exponent);

    // If Bayesian smoothing is disabled or user has reached convergence (>= 10 titles)
    if (!applyBayesianPrior || totalCount >= bayesianConvergenceCount) {
      return rawScore;
    }

    // Bayesian prior blending for early profiles (N < 10):
    // Prevents a user's 3rd or 4th show from receiving a punishing 1.00 score.
    final alpha = totalCount / bayesianConvergenceCount.toDouble();
    // Prior score assumes early logs represent a user's favorite titles (gentle step from 10.0 down)
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

  /// Returns the corresponding [CanonTier] for a given rank and canon size.
  static CanonTier getTier(
    int rank,
    int totalCount, {
    double exponent = defaultExponent,
    bool applyBayesianPrior = true,
  }) {
    final score = calculateScore(
      rank,
      totalCount,
      exponent: exponent,
      applyBayesianPrior: applyBayesianPrior,
    );
    return CanonTier.fromScore(score);
  }
}
