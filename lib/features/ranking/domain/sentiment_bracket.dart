/// Sentiment brackets that narrow the binary-insertion search window before duels.
/// Conforms to `docs/features/02_PAIRWISE_RANKING_ENGINE_AND_LOGGING.md` §2 Step 2 and §3.1
/// (search-window bounds) and `SCR-09` in `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md`.
///
/// Brackets describe *canon position*, not a score: the final score always comes from the
/// percentile curve (`ScoreCurveCalculator`). `SCR-09` shows the first four cards; [regret]
/// (features/02 "Disappointed / Bottom 5%") is used by importers for the lowest ratings.
enum SentimentBracket {
  /// Masterpiece: search window = top 10% of the canon.
  masterpiece,

  /// Loved It: search window = 10%–35%.
  loved,

  /// Liked It: search window = 35%–75%.
  liked,

  /// Meh: search window = 75%–95%.
  meh,

  /// Disappointed / Regret: search window = bottom 5%.
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

  /// The four cards shown on `SCR-09` (FE-603); [SentimentBracket.regret] is importer-only.
  static const studioBrackets = [
    SentimentBracket.masterpiece,
    SentimentBracket.loved,
    SentimentBracket.liked,
    SentimentBracket.meh,
  ];

  /// `SCR-09` card headline, e.g. `👑 Masterpiece / Top 10%`.
  String get studioTitle => switch (this) {
        SentimentBracket.masterpiece => '👑 Masterpiece / Top 10%',
        SentimentBracket.loved => '✨ Loved It / Top 25%',
        SentimentBracket.liked => '👍 Liked It / Middle 40%',
        SentimentBracket.meh => '🤷 Meh / Bottom 25%',
        SentimentBracket.regret => '💔 Disappointed / Bottom 5%',
      };

  /// `SCR-09` card tagline.
  String get studioTagline => switch (this) {
        SentimentBracket.masterpiece => 'Life-changing, flawless television',
        SentimentBracket.loved => 'Outstanding, highly recommended',
        SentimentBracket.liked => 'Solid, enjoyable, some flaws',
        SentimentBracket.meh => 'Forgettable, background noise',
        SentimentBracket.regret => 'Wish I had that time back',
      };

  /// Maps an external 10-point rating (e.g. AniList) to a starting bracket.
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
