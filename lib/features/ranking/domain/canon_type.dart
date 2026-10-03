/// The personal dual-canon partition types.
/// Conforms to `docs/features/09_MOVIE_INTEGRATION_AND_DUAL_CANON.md` §2
/// and Prime Directive Invariant 1 (Dual-Canon Segregation).
enum CanonType {
  /// Feature films, anime movies, and documentaries.
  movie(
    dbValue: 'movie',
    displayName: 'Movie Canon',
    shortLabel: 'Movies',
    emoji: '🎬',
  ),

  /// Serialized television, limited series, and anime series.
  series(
    dbValue: 'tv',
    displayName: 'Series & Anime Canon',
    shortLabel: 'Series & Anime',
    emoji: '📺',
  );

  final String dbValue;
  final String displayName;
  final String shortLabel;
  final String emoji;

  const CanonType({
    required this.dbValue,
    required this.displayName,
    required this.shortLabel,
    required this.emoji,
  });

  /// Resolves [CanonType] from TMDB / Supabase `media_type` string ('movie' or 'tv').
  static CanonType fromMediaType(String mediaType) {
    switch (mediaType.toLowerCase()) {
      case 'movie':
        return CanonType.movie;
      case 'tv':
      case 'series':
      case 'anime':
        return CanonType.series;
      default:
        throw ArgumentError.value(
          mediaType,
          'mediaType',
          'Invalid media_type. Must be "movie" or "tv".',
        );
    }
  }
}

/// Mixin for any item that belongs to a specific media type and canon.
mixin HasMediaType {
  String get mediaType;
  CanonType get canonType => CanonType.fromMediaType(mediaType);
}

/// Thrown when an illegal cross-canon pairwise duel or comparison is attempted.
class CrossCanonDuelException implements Exception {
  final String message;
  final CanonType candidateCanon;
  final CanonType opponentCanon;

  CrossCanonDuelException({
    required this.candidateCanon,
    required this.opponentCanon,
    String? message,
  }) : message = message ??
            'Cross-canon duels are prohibited: Candidate (${candidateCanon.displayName}) '
            'cannot duel against Opponent (${opponentCanon.displayName}).';

  @override
  String toString() => 'CrossCanonDuelException: $message';
}

/// Domain service enforcing strict Dual-Canon segregation rules.
class DualCanonService {
  /// Validates that a candidate item matches the canon type of all items in [existingCanon].
  /// Throws [CrossCanonDuelException] if any cross-canon pairing is detected.
  static void validateTournamentPairing<T extends HasMediaType>({
    required T candidate,
    required List<T> existingCanon,
  }) {
    final candidateCanon = candidate.canonType;
    for (final item in existingCanon) {
      if (item.canonType != candidateCanon) {
        throw CrossCanonDuelException(
          candidateCanon: candidateCanon,
          opponentCanon: item.canonType,
        );
      }
    }
  }

  /// Partitions a mixed collection into segregated Movie and Series lists.
  static ({List<T> movies, List<T> series}) partitionByCanon<T extends HasMediaType>(
    List<T> mixedTitles,
  ) {
    final movies = <T>[];
    final series = <T>[];

    for (final item in mixedTitles) {
      if (item.canonType == CanonType.movie) {
        movies.add(item);
      } else {
        series.add(item);
      }
    }

    return (movies: movies, series: series);
  }

  /// Interleaves a user's Movie and Series canons into a single Unified Master Canon
  /// sorted in descending order of dynamic percentile score.
  /// Conforms to `docs/features/09_MOVIE_INTEGRATION_AND_DUAL_CANON.md` §2.1.
  static List<T> buildUnifiedMasterCanon<T>({
    required List<T> movieCanon,
    required List<T> seriesCanon,
    required double Function(T item) getScore,
  }) {
    final blended = [...movieCanon, ...seriesCanon];
    blended.sort((a, b) => getScore(b).compareTo(getScore(a)));
    return blended;
  }
}
