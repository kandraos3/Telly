import 'dart:math' as math;

/// State representing confidence in a title's ranking position.
/// Conforms to `docs/features/08_ANIME_INTEGRATION_AND_HYBRID_CANON.md` §5
/// and `docs/features/02_PAIRWISE_RANKING_ENGINE_AND_LOGGING.md` §7.1.
enum RankingConfidenceStatus {
  /// Uncertainty sigma >= 0.50. Displays dashed neon border and [ ⚡ Calibrate ] pill.
  provisional,

  /// Uncertainty sigma < 0.50. Displays solid border with [ 🔒 Locked ] status.
  locked,
}

/// Bayesian ranking uncertainty and confidence tracker based on TrueSkill principles.
///
/// Each title holds an uncertainty parameter $\sigma \in [0.15, 1.50]$.
/// As the title participates in pairwise duels against neighbors, uncertainty decays:
/// $$\sigma_{t+1} = \max(0.15, \sigma_t \times 0.75)$$
///
/// When $\sigma < 0.50$, the ranking transitions to [RankingConfidenceStatus.locked].
class TrueSkillConfidence {
  /// Default initial uncertainty for newly inserted titles
  static const double initialSigma = 1.20;

  /// Uncertainty floor (minimum possible variance)
  static const double minSigma = 0.15;

  /// Decay rate multiplier per completed duel
  static const double decayMultiplier = 0.75;

  /// Threshold below which a title becomes Locked
  static const double lockedThreshold = 0.50;

  /// Uncertainty parameter sigma
  final double sigma;

  /// Total number of completed pairwise duels involving this title
  final int duelsCompleted;

  const TrueSkillConfidence({
    required this.sigma,
    this.duelsCompleted = 0,
  });

  /// Factory constructor for a newly inserted title
  factory TrueSkillConfidence.initial() {
    return const TrueSkillConfidence(
      sigma: initialSigma,
      duelsCompleted: 0,
    );
  }

  /// Factory constructor for the very first show logged into an empty canon ($N=0$).
  /// Automatically assigned $\sigma = 0.50$ per spec §7.3.
  factory TrueSkillConfidence.firstTitle() {
    return const TrueSkillConfidence(
      sigma: lockedThreshold,
      duelsCompleted: 0,
    );
  }

  /// Current confidence status based on whether $\sigma < 0.50$.
  RankingConfidenceStatus get status =>
      sigma < lockedThreshold ? RankingConfidenceStatus.locked : RankingConfidenceStatus.provisional;

  /// Whether the title's ranking is locked with high confidence.
  bool get isLocked => status == RankingConfidenceStatus.locked;

  /// Whether the title is provisional and requires calibration duels.
  bool get isProvisional => status == RankingConfidenceStatus.provisional;

  /// Returns a new [TrueSkillConfidence] decayed by one completed duel:
  /// $$\sigma_{\text{new}} = \max(0.15, \sigma_{\text{old}} \times 0.75)$$
  TrueSkillConfidence recordDuel() {
    final nextSigma = math.max(minSigma, sigma * decayMultiplier);
    return TrueSkillConfidence(
      sigma: double.parse(nextSigma.toStringAsFixed(4)),
      duelsCompleted: duelsCompleted + 1,
    );
  }

  /// Resets uncertainty back to initial state (e.g. "Start Fresh on This Show").
  TrueSkillConfidence reset() {
    return TrueSkillConfidence.initial();
  }

  /// Formatted confidence percentage between 0% (sigma=1.20) and 100% (sigma=0.15).
  int get confidencePercentage {
    final normalized = (initialSigma - sigma) / (initialSigma - minSigma);
    return (normalized.clamp(0.0, 1.0) * 100).round();
  }

  /// Formatted score margin of error (e.g. ±0.4) for UI display.
  String get displayMarginOfError {
    final margin = sigma * 0.35;
    return '±${margin.toStringAsFixed(1)}';
  }

  @override
  String toString() =>
      'TrueSkillConfidence(sigma: $sigma, status: ${status.name}, duels: $duelsCompleted)';
}
