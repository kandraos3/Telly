/// Display tiers for dynamic canon scores — the single tier definition in the app.
///
/// Thresholds are canonical in `docs/design_system/01_DESIGN_PHILOSOPHY_AND_STYLE_GUIDE.md` §2.2
/// (Sprint 6 decision D2). Every lower bound is inclusive.
enum CanonTier {
  god(label: 'God Tier', emoji: '👑', minScore: 9.20),
  prestige(label: 'Prestige Tier', emoji: '✨', minScore: 8.50),
  great(label: 'Great Tier', emoji: '👍', minScore: 7.80),
  good(label: 'Good / Fun', emoji: '🍿', minScore: 7.00),
  mid(label: 'Mid / Filler', emoji: '🤷', minScore: 5.50),
  lower(label: 'Lower Tier', emoji: '📉', minScore: 1.00),
  dropped(label: 'Dropped / DNF', emoji: '💀', minScore: 0.00);

  final String label;
  final String emoji;
  final double minScore;

  const CanonTier({required this.label, required this.emoji, required this.minScore});

  /// Upper bound shown in headers, e.g. `9.19` for Prestige; `10.00` for God.
  double get maxScore {
    final i = index;
    return i == 0 ? 10.00 : CanonTier.values[i - 1].minScore - 0.01;
  }

  /// Human-readable range, e.g. `8.50 – 9.19` or `< 5.50`.
  String get rangeLabel {
    if (this == CanonTier.dropped) return 'DNF';
    if (this == CanonTier.lower) return '< ${CanonTier.mid.minScore.toStringAsFixed(2)}';
    return '${minScore.toStringAsFixed(2)} – ${maxScore.toStringAsFixed(2)}';
  }

  /// Classifies a score. Scores are compared at 2-decimal display precision so a
  /// stored `9.20` is always God Tier regardless of floating-point noise.
  /// Completed canon entries are never assigned [CanonTier.dropped] unless [isAbandoned] is true.
  static CanonTier fromScore(double score, {bool isAbandoned = false}) {
    if (isAbandoned) return CanonTier.dropped;
    final s = (score * 100).round() / 100;
    for (final tier in CanonTier.values) {
      if (tier == CanonTier.dropped) continue;
      if (s >= tier.minScore) return tier;
    }
    return CanonTier.lower;
  }
}
