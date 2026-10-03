import 'dart:math' as math;

/// Represents an affinity tier based on taste match percentage.
/// Defined in `docs/features/05_TASTE_MATCH_AND_CO_WATCH_DECIDER.md` §2.3.
enum TasteAffinityTier {
  tasteTwins(
    label: 'Taste Twins',
    description: 'Eerily identical canons. Follow their recommendations blindly.',
    minPercentage: 90,
  ),
  kindredSpirits(
    label: 'Kindred Spirits',
    description: 'High overlap in core prestige genres; occasional divergence.',
    minPercentage: 75,
  ),
  casualAcquaintances(
    label: 'Casual Acquaintances',
    description: 'Enjoy mainstream hits together, divergent niche tastes.',
    minPercentage: 50,
  ),
  oppositeEnds(
    label: 'Opposite Ends of the Couch',
    description: 'One loves reality TV, the other watches slow-burn foreign cinema.',
    minPercentage: 0,
  );

  final String label;
  final String description;
  final int minPercentage;

  const TasteAffinityTier({
    required this.label,
    required this.description,
    required this.minPercentage,
  });

  static TasteAffinityTier fromPercentage(int pct) {
    if (pct >= 90) return tasteTwins;
    if (pct >= 75) return kindredSpirits;
    if (pct >= 50) return casualAcquaintances;
    return oppositeEnds;
  }
}

/// A mutual title ranked by both users for comparison analysis.
class RankedTitleComparison {
  final int showId;
  final String title;
  final String? posterPath;
  final int rankA;
  final int rankB;
  final double scoreA;
  final double scoreB;
  final String? reviewA;
  final String? reviewB;
  final String mediaType; // 'movie' or 'tv'

  const RankedTitleComparison({
    required this.showId,
    required this.title,
    this.posterPath,
    required this.rankA,
    required this.rankB,
    required this.scoreA,
    required this.scoreB,
    this.reviewA,
    this.reviewB,
    this.mediaType = 'tv',
  });

  /// Absolute rank difference between both users: |RankA - RankB|
  int get rankDelta => (rankA - rankB).abs();

  /// Average rank position between both users.
  double get averageRank => (rankA + rankB) / 2.0;
}

/// An unwatched gem recommendation: highly ranked by friend, not seen by user.
class UnwatchedGem {
  final int showId;
  final String title;
  final String? posterPath;
  final int friendRank;
  final double friendScore;
  final String mediaType;
  final String network;
  final List<String> streamingPlatforms;

  const UnwatchedGem({
    required this.showId,
    required this.title,
    this.posterPath,
    required this.friendRank,
    required this.friendScore,
    required this.mediaType,
    required this.network,
    this.streamingPlatforms = const [],
  });
}

/// The detailed taste match analysis between two users.
class TasteMatchResult {
  final int matchPercentage;
  final double rawRho;
  final double adjustedRho;
  final int mutualTitleCount;
  final TasteAffinityTier affinityTier;
  final int? movieMatchPercentage;
  final int? seriesMatchPercentage;
  final List<RankedTitleComparison> topAgreements;
  final List<RankedTitleComparison> spiciestClashes;
  final List<UnwatchedGem> unwatchedGems;

  const TasteMatchResult({
    required this.matchPercentage,
    required this.rawRho,
    required this.adjustedRho,
    required this.mutualTitleCount,
    required this.affinityTier,
    this.movieMatchPercentage,
    this.seriesMatchPercentage,
    this.topAgreements = const [],
    this.spiciestClashes = const [],
    this.unwatchedGems = const [],
  });
}

/// Pure Dart implementation of the Spearman Rank Correlation with Bayesian Shrinkage.
/// Conforms to `docs/features/05_TASTE_MATCH_AND_CO_WATCH_DECIDER.md` §2.
class SpearmanTasteMatchCalculator {
  /// The baseline shrinkage prior sample size: k0 = 5.
  static const double defaultPriorK0 = 5.0;

  /// Calculate taste match percentage from paired ranks.
  ///
  /// Each entry in [pairedRanks] is a pair of `(rankA, rankB)`.
  /// Rank values are 1-indexed integers (1 = #1 all-time favorite).
  static TasteMatchResult calculate({
    required List<(int, int)> pairedRanks,
    List<RankedTitleComparison> detailedComparisons = const [],
    List<UnwatchedGem> unwatchedGems = const [],
    int? movieMatchPercentage,
    int? seriesMatchPercentage,
    double k0 = defaultPriorK0,
  }) {
    final k = pairedRanks.length;

    // Boundary case: less than 2 mutual titles returns neutral 50% prior
    if (k < 2) {
      return TasteMatchResult(
        matchPercentage: 50,
        rawRho: 0.0,
        adjustedRho: 0.0,
        mutualTitleCount: k,
        affinityTier: TasteAffinityTier.casualAcquaintances,
        movieMatchPercentage: movieMatchPercentage,
        seriesMatchPercentage: seriesMatchPercentage,
        topAgreements: detailedComparisons,
        spiciestClashes: detailedComparisons,
        unwatchedGems: unwatchedGems,
      );
    }

    // Compute sum of squared rank differences: sum(d_i^2)
    double sumDSq = 0.0;
    for (final pair in pairedRanks) {
      final diff = pair.$1 - pair.$2;
      sumDSq += diff * diff;
    }

    // Spearman formula: rho = 1.0 - (6 * sumDSq) / (k * (k^2 - 1))
    final denominator = k.toDouble() * (math.pow(k.toDouble(), 2) - 1.0);
    var rawRho = 1.0 - ((6.0 * sumDSq) / denominator);

    // Safeguard floating point rounding errors to [-1.0, 1.0]
    rawRho = rawRho.clamp(-1.0, 1.0);

    // Bayesian Confidence Shrinkage Factor: W(k) = k / (k + k0)
    final weight = k.toDouble() / (k.toDouble() + k0);
    // Prior rho is 0.0 (neutral uncorrelated assumption)
    final adjustedRho = weight * rawRho;

    // Normalization to [0, 100] percentage:
    // Match % = round(((adjustedRho + 1.0) / 2.0) * 100)
    final percentage = (((adjustedRho + 1.0) / 2.0) * 100.0).round().clamp(0, 100);

    // Sort comparisons: agreements have lowest rankDelta, clashes have highest rankDelta
    final sortedByDelta = List<RankedTitleComparison>.from(detailedComparisons);
    sortedByDelta.sort((a, b) => a.rankDelta.compareTo(b.rankDelta));

    final agreements = sortedByDelta.take(5).toList();
    final clashes = sortedByDelta.reversed.take(5).toList();

    return TasteMatchResult(
      matchPercentage: percentage,
      rawRho: rawRho,
      adjustedRho: adjustedRho,
      mutualTitleCount: k,
      affinityTier: TasteAffinityTier.fromPercentage(percentage),
      movieMatchPercentage: movieMatchPercentage,
      seriesMatchPercentage: seriesMatchPercentage,
      topAgreements: agreements,
      spiciestClashes: clashes,
      unwatchedGems: unwatchedGems,
    );
  }

  /// Calculates blended overall match from movie and series sub-matches.
  /// Weighted by sample size of mutual titles in each medium.
  static int calculateBlendedMatch({
    required int movieMatchPct,
    required int movieCount,
    required int seriesMatchPct,
    required int seriesCount,
  }) {
    final total = movieCount + seriesCount;
    if (total == 0) return 50;
    final weighted = (movieMatchPct * movieCount + seriesMatchPct * seriesCount) / total;
    return weighted.round().clamp(0, 100);
  }
}
