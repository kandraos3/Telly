import 'package:flutter/foundation.dart';

/// Upset severity level reflecting divergence from community consensus.
enum UpsetSeverity {
  none,
  spicy,
  chaosPick,
}

/// Evaluation result from analyzing a binary pairwise duel outcome.
@immutable
class UpsetEvaluation {
  final bool isUpset;
  final double delta;
  final double winnerWinRate;
  final double loserWinRate;
  final UpsetSeverity severity;
  final double agreementPercentage;

  const UpsetEvaluation({
    required this.isUpset,
    required this.delta,
    required this.winnerWinRate,
    required this.loserWinRate,
    required this.severity,
    required this.agreementPercentage,
  });

  @override
  String toString() =>
      'UpsetEvaluation(isUpset: $isUpset, delta: ${delta.toStringAsFixed(3)}, severity: $severity, agreement: ${agreementPercentage.toStringAsFixed(1)}%)';
}

/// Algorithmic detector for spicy upsets and controversial takes (BE-302, QA-302).
///
/// An upset is triggered if the loser's community win rate exceeds the winner's
/// win rate by at least 0.25 (i.e. Delta >= 0.2500).
class UpsetDetector {
  /// Threshold for triggering an upset alert (25% divergence).
  static const double upsetThreshold = 0.25;

  /// Threshold for extreme "Chaos Pick / Taste Crime" alerts (35% divergence).
  static const double chaosThreshold = 0.35;

  /// Epsilon tolerance for floating point comparisons.
  static const double epsilon = 1e-6;

  /// Detects whether a duel between [winnerWinRate] and [loserWinRate] is an upset.
  ///
  /// Win rates are normalized between 0.0 and 1.0.
  static UpsetEvaluation evaluateDuel({
    required double winnerWinRate,
    required double loserWinRate,
  }) {
    final clampedWinner = winnerWinRate.clamp(0.0, 1.0);
    final clampedLoser = loserWinRate.clamp(0.0, 1.0);

    // Delta is how much more popular/favored the loser was compared to the winner
    final delta = clampedLoser - clampedWinner;

    // Check threshold with epsilon tolerance
    final isUpset = (delta + epsilon) >= upsetThreshold;

    final UpsetSeverity severity;
    if (!isUpset) {
      severity = UpsetSeverity.none;
    } else if ((delta + epsilon) >= chaosThreshold) {
      severity = UpsetSeverity.chaosPick;
    } else {
      severity = UpsetSeverity.spicy;
    }

    // Community agreement percentage with this pick (approx. winner rate or 1 - delta)
    final agreement = (clampedWinner / (clampedWinner + clampedLoser > 0 ? (clampedWinner + clampedLoser) : 1.0) * 100.0)
        .clamp(1.0, 99.0);

    return UpsetEvaluation(
      isUpset: isUpset,
      delta: double.parse(delta.toStringAsFixed(4)),
      winnerWinRate: clampedWinner,
      loserWinRate: clampedLoser,
      severity: severity,
      agreementPercentage: double.parse(agreement.toStringAsFixed(1)),
    );
  }

  /// Calculates win-rate from wins and total matches.
  static double calculateWinRate({required int wins, required int totalMatches}) {
    if (totalMatches <= 0) return 0.50; // Neutral prior
    return (wins / totalMatches).clamp(0.0, 1.0);
  }
}
