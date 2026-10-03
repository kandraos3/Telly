/// Sentiment brackets for initial tournament seed insertion and quick ranking buckets.
/// Conforms to `docs/features/02_PAIRWISE_DUEL_ENGINE_AND_TOURNAMENTS.md` §3
/// and `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §5.
enum SentimentBracket {
  /// Masterpiece / God Tier: Initial placement target Top 10% (Score 9.0 - 10.0)
  masterpiece,

  /// Loved It / Prestige Tier: Initial placement target Top 25% (Score 8.0 - 8.9)
  loved,

  /// Liked It / Solid Tier: Initial placement target 50th percentile (Score 6.5 - 7.9)
  liked,

  /// Meh / Mid Tier: Initial placement target Lower 20% (Score 4.5 - 6.4)
  meh,

  /// Regret / Bin Tier: Initial placement target Bottom 5% (Score 1.0 - 4.4)
  regret,
}

extension SentimentBracketExtension on SentimentBracket {
  String get displayName {
    switch (this) {
      case SentimentBracket.masterpiece:
        return 'Masterpiece (Top 10%)';
      case SentimentBracket.loved:
        return 'Loved It (Top 25%)';
      case SentimentBracket.liked:
        return 'Liked It';
      case SentimentBracket.meh:
        return 'Meh / Mixed';
      case SentimentBracket.regret:
        return 'Regret / Dropped';
    }
  }

  /// Maps a 10-point scale score to a sentiment bracket.
  static SentimentBracket fromScore(double score) {
    if (score >= 9.0) return SentimentBracket.masterpiece;
    if (score >= 8.0) return SentimentBracket.loved;
    if (score >= 6.5) return SentimentBracket.liked;
    if (score >= 4.5) return SentimentBracket.meh;
    return SentimentBracket.regret;
  }

  /// Maps Letterboxd 0.5 - 5.0 star rating to a sentiment bracket.
  static SentimentBracket fromStarRating(double stars) {
    if (stars >= 4.5) return SentimentBracket.masterpiece;
    if (stars >= 4.0) return SentimentBracket.loved;
    if (stars >= 3.0) return SentimentBracket.liked;
    if (stars >= 2.0) return SentimentBracket.meh;
    return SentimentBracket.regret;
  }
}
