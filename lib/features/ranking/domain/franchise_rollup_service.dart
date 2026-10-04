/// Anime Franchise Rollup Aggregator & Unbundle Service.
/// Conforms to:
/// - `docs/features/08_ANIME_INTEGRATION_AND_HYBRID_CANON.md` §2, §4
/// - Tickets: FE-208, ALGO-602 (primary series representative, decision D6)
library;

/// Represents a ranked title or anime season in the user's Canon.
class CanonEntry {
  final int id;
  final String title;
  final String mediaType; // 'movie' or 'tv'
  final int rankPosition;
  final double calculatedScore;
  final String? posterPath;
  final bool isAnime;
  final String? franchiseId;
  final String? franchiseName;
  /// Null for a franchise's primary series entry; set for individual seasons/cours.
  final int? seasonNumber;
  final String? seasonTitle;
  final String? mvpCharacter;
  final String? shortReview;
  /// Season-by-season grades shown in the rolled-up entry's dropdown (ALGO-602).
  final List<CanonEntry> seasonBreakdown;
  final bool isRolledUp;

  const CanonEntry({
    required this.id,
    required this.title,
    required this.mediaType,
    required this.rankPosition,
    required this.calculatedScore,
    this.posterPath,
    this.isAnime = false,
    this.franchiseId,
    this.franchiseName,
    this.seasonNumber,
    this.seasonTitle,
    this.mvpCharacter,
    this.shortReview,
    this.seasonBreakdown = const [],
    this.isRolledUp = false,
  });

  CanonEntry copyWith({
    int? id,
    String? title,
    String? mediaType,
    int? rankPosition,
    double? calculatedScore,
    String? posterPath,
    bool? isAnime,
    String? franchiseId,
    String? franchiseName,
    int? seasonNumber,
    String? seasonTitle,
    String? mvpCharacter,
    String? shortReview,
    List<CanonEntry>? seasonBreakdown,
    bool? isRolledUp,
  }) {
    return CanonEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      mediaType: mediaType ?? this.mediaType,
      rankPosition: rankPosition ?? this.rankPosition,
      calculatedScore: calculatedScore ?? this.calculatedScore,
      posterPath: posterPath ?? this.posterPath,
      isAnime: isAnime ?? this.isAnime,
      franchiseId: franchiseId ?? this.franchiseId,
      franchiseName: franchiseName ?? this.franchiseName,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      seasonTitle: seasonTitle ?? this.seasonTitle,
      mvpCharacter: mvpCharacter ?? this.mvpCharacter,
      shortReview: shortReview ?? this.shortReview,
      seasonBreakdown: seasonBreakdown ?? this.seasonBreakdown,
      isRolledUp: isRolledUp ?? this.isRolledUp,
    );
  }
}

/// Collapses fragmented anime seasons/cours into one franchise entry for display.
///
/// features/08 §4: the franchise entry takes the **rank and score of the user's primary
/// series ranking** (the franchise entry without a `seasonNumber`). Scores are never
/// averaged. Without a primary ranking it takes the highest-ranked season. Ranks are the
/// real canon positions, so a rolled-up list can skip numbers held by folded seasons.
/// The unbundled view is the raw canon itself and needs no transformation.
class FranchiseRollupService {
  static List<CanonEntry> rollupFranchises(List<CanonEntry> rawEntries) {
    final groups = <String, List<CanonEntry>>{};
    final result = <CanonEntry>[];

    for (final entry in rawEntries) {
      final franchise = entry.franchiseId;
      if (franchise == null || franchise.isEmpty) {
        result.add(entry);
      } else {
        groups.putIfAbsent(franchise, () => []).add(entry);
      }
    }

    for (final MapEntry(key: franchiseId, value: members) in groups.entries) {
      if (members.length == 1) {
        result.add(members.single);
        continue;
      }
      final primaries = members.where((e) => e.seasonNumber == null).toList()
        ..sort((a, b) => a.rankPosition.compareTo(b.rankPosition));
      final seasons = members.where((e) => e.seasonNumber != null).toList()
        ..sort((a, b) => a.seasonNumber!.compareTo(b.seasonNumber!));
      final representative = primaries.isNotEmpty
          ? primaries.first
          : (List.of(seasons)..sort((a, b) => a.rankPosition.compareTo(b.rankPosition))).first;

      result.add(representative.copyWith(
        title: representative.franchiseName ?? representative.title,
        franchiseId: franchiseId,
        seasonBreakdown: seasons,
        isRolledUp: true,
      ));
    }

    result.sort((a, b) => a.rankPosition.compareTo(b.rankPosition));
    return result;
  }
}
