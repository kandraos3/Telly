/// Domain models and enums for SCR-11 Editorial Tagging Sheet.
/// Conforms to:
/// - `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §11 (SCR-11)
/// - `docs/features/02_PAIRWISE_RANKING_ENGINE_AND_LOGGING.md` §3, §5
/// - `docs/features/09_MOVIE_INTEGRATION_AND_DUAL_CANON.md` §3
/// - `docs/features/08_ANIME_INTEGRATION_AND_HYBRID_CANON.md` §6.2
library;

/// Contextual viewing venue for Movie Canon logging.
enum ViewingVenue {
  home(
    dbValue: 'HOME',
    displayName: 'Home Streaming',
    shortLabel: 'Home / Streaming',
    emoji: '🛋️',
  ),
  theatrical(
    dbValue: 'THEATER',
    displayName: 'Theatrical',
    shortLabel: 'Theatrical',
    emoji: '🍿',
  ),
  imax(
    dbValue: 'IMAX',
    displayName: 'IMAX 70mm / Dolby',
    shortLabel: 'IMAX / Dolby',
    emoji: '📽️',
  ),
  festivalFlight(
    dbValue: 'OTHER',
    displayName: 'Festival / In-Flight',
    shortLabel: 'Festival / Flight',
    emoji: '✈️',
  );

  final String dbValue;
  final String displayName;
  final String shortLabel;
  final String emoji;

  const ViewingVenue({
    required this.dbValue,
    required this.displayName,
    required this.shortLabel,
    required this.emoji,
  });

  static ViewingVenue? fromDbValue(String? value) {
    if (value == null) return null;
    for (final venue in ViewingVenue.values) {
      if (venue.dbValue == value) return venue;
    }
    return null;
  }
}

/// Watching velocity / pace for Series Canon logging.
enum BingeVelocity {
  weekendBinge(
    dbValue: 'WEEKEND_BINGE',
    displayName: 'Weekend Binge',
    emoji: '⚡',
  ),
  weeklyAiring(
    dbValue: 'WEEKLY_AIRING',
    displayName: 'Weekly Airing',
    emoji: '📅',
  ),
  slowBurn(
    dbValue: 'SLOW_BURN',
    displayName: 'Slow Burn',
    emoji: '☕',
  );

  final String dbValue;
  final String displayName;
  final String emoji;

  const BingeVelocity({
    required this.dbValue,
    required this.displayName,
    required this.emoji,
  });

  static BingeVelocity? fromDbValue(String? value) {
    if (value == null) return null;
    for (final v in BingeVelocity.values) {
      if (v.dbValue == value) return v;
    }
    return null;
  }
}

/// Anime audio presentation mode.
enum AnimeAudioMode {
  sub(
    dbValue: 'SUB',
    displayName: 'Japanese (Sub)',
    emoji: '🇯🇵',
  ),
  dub(
    dbValue: 'DUB',
    displayName: 'English Dub',
    emoji: '🎙️',
  );

  final String dbValue;
  final String displayName;
  final String emoji;

  const AnimeAudioMode({
    required this.dbValue,
    required this.displayName,
    required this.emoji,
  });

  static AnimeAudioMode? fromDbValue(String? value) {
    if (value == null) return null;
    for (final a in AnimeAudioMode.values) {
      if (a.dbValue == value) return a;
    }
    return null;
  }
}

/// Immutable data container holding user-selected tags, notes, and metadata from SCR-11.
class EditorialTaggingData {
  /// Viewing venue for movies (e.g. Theaters, IMAX, Home).
  final ViewingVenue? viewingVenue;

  /// True if this was a rewatch; false if first-time watch.
  final bool isRewatch;

  /// Total count of times watched (1 for first time, >= 2 for rewatch).
  final int rewatchCount;

  /// Binge velocity for series (Weekend Binge, Weekly Airing, Slow Burn).
  final BingeVelocity? bingeVelocity;

  /// Audio mode for anime (Japanese Sub or English Dub).
  final AnimeAudioMode? audioMode;

  /// Selected vibe tags (maximum 3, managed with FIFO queue).
  final List<String> vibeTags;

  /// Auto-tagged director from TMDB crew credits.
  final String? director;

  /// Selected MVP standout character / cast performance.
  final String? mvpCharacter;

  /// 280-character maximum micro-review / hot take.
  final String review;

  const EditorialTaggingData({
    this.viewingVenue,
    this.isRewatch = false,
    this.rewatchCount = 1,
    this.bingeVelocity,
    this.audioMode,
    this.vibeTags = const [],
    this.director,
    this.mvpCharacter,
    this.review = '',
  });

  EditorialTaggingData copyWith({
    ViewingVenue? viewingVenue,
    bool? isRewatch,
    int? rewatchCount,
    BingeVelocity? bingeVelocity,
    AnimeAudioMode? audioMode,
    List<String>? vibeTags,
    String? director,
    String? mvpCharacter,
    String? review,
  }) {
    return EditorialTaggingData(
      viewingVenue: viewingVenue ?? this.viewingVenue,
      isRewatch: isRewatch ?? this.isRewatch,
      rewatchCount: rewatchCount ?? this.rewatchCount,
      bingeVelocity: bingeVelocity ?? this.bingeVelocity,
      audioMode: audioMode ?? this.audioMode,
      vibeTags: vibeTags ?? this.vibeTags,
      director: director ?? this.director,
      mvpCharacter: mvpCharacter ?? this.mvpCharacter,
      review: review ?? this.review,
    );
  }

  /// Preset vibe tags for movies.
  static const List<String> defaultMovieVibes = [
    'Cinematography Peak',
    'Mind-Bending',
    'Great Score',
    'Emotional Wreck',
    'Pacing Perfection',
    'Original Screenplay',
    'Style Over Substance',
    'Masterpiece Acting',
  ];

  /// Preset vibe tags for TV series.
  static const List<String> defaultSeriesVibes = [
    'Masterpiece Dialogue',
    'Emotional Wreck',
    'Peak Comedy',
    'Mind-Bending',
    'Sluggish Pacing',
    'Comfort TV',
    'Flawless Finale',
    'Cozy',
    'Dark & Gritty',
  ];
}
