/// Anime Franchise Rollup Aggregator & Unbundle Service.
/// Conforms to:
/// - `docs/features/08_ANIME_INTEGRATION_AND_HYBRID_CANON.md` §2, §4
/// - Ticket: FE-208
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
  final int? seasonNumber;
  final String? seasonTitle;
  final String? mvpCharacter;
  final String? shortReview;
  final List<CanonEntry> subEntries;
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
    this.subEntries = const [],
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
    List<CanonEntry>? subEntries,
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
      subEntries: subEntries ?? this.subEntries,
      isRolledUp: isRolledUp ?? this.isRolledUp,
    );
  }
}

/// Domain service allowing users to collapse fragmented anime seasons/cours
/// into a single franchise entity or unbundle them into standalone ranked entries.
class FranchiseRollupService {
  /// Aggregates multiple entries belonging to the same franchise into a single
  /// parent entry whose calculated score is the weighted/arithmetic mean of its seasons.
  ///
  /// Re-indexes final ranks sequentially 1..N based on new composite scores.
  static List<CanonEntry> rollupFranchises(List<CanonEntry> rawEntries) {
    if (rawEntries.isEmpty) return const [];

    final franchiseMap = <String, List<CanonEntry>>{};
    final standaloneEntries = <CanonEntry>[];

    // Partition by franchiseId
    for (final entry in rawEntries) {
      if (entry.franchiseId != null && entry.franchiseId!.isNotEmpty) {
        franchiseMap.putIfAbsent(entry.franchiseId!, () => []).add(entry);
      } else {
        standaloneEntries.add(entry);
      }
    }

    final rolledUpList = <CanonEntry>[...standaloneEntries];

    // Combine each franchise group
    for (final entry in franchiseMap.entries) {
      final seasons = entry.value;

      if (seasons.length == 1) {
        // Only 1 season ranked, no rollup necessary
        rolledUpList.add(seasons.first);
      } else {
        // Calculate composite score (mean of seasons, rounded to 2 decimal places)
        final totalScore = seasons.fold<double>(0.0, (sum, s) => sum + s.calculatedScore);
        final compositeScore = double.parse((totalScore / seasons.length).toStringAsFixed(2));

        final primarySeason = seasons.first;
        final franchiseName = primarySeason.franchiseName ?? primarySeason.title;

        // Sort sub-entries by season number or rank position
        final sortedSubEntries = List<CanonEntry>.from(seasons)
          ..sort((a, b) => (a.seasonNumber ?? 0).compareTo(b.seasonNumber ?? 0));

        final parent = CanonEntry(
          id: primarySeason.id,
          title: franchiseName,
          mediaType: primarySeason.mediaType,
          rankPosition: 0, // Will be re-indexed below
          calculatedScore: compositeScore,
          posterPath: primarySeason.posterPath,
          isAnime: primarySeason.isAnime,
          franchiseId: entry.key,
          franchiseName: franchiseName,
          subEntries: sortedSubEntries,
          isRolledUp: true,
        );

        rolledUpList.add(parent);
      }
    }

    // Sort by composite score descending
    rolledUpList.sort((a, b) => b.calculatedScore.compareTo(a.calculatedScore));

    // Re-index ranks 1..N
    return List.generate(rolledUpList.length, (index) {
      return rolledUpList[index].copyWith(rankPosition: index + 1);
    });
  }

  /// Unbundles rolled up parent entries back into their individual standalone seasons,
  /// re-ordering by original score and assigning consecutive ranks 1..N.
  static List<CanonEntry> unbundleFranchises(List<CanonEntry> entries) {
    if (entries.isEmpty) return const [];

    final unbundled = <CanonEntry>[];

    for (final entry in entries) {
      if (entry.isRolledUp && entry.subEntries.isNotEmpty) {
        unbundled.addAll(entry.subEntries);
      } else {
        unbundled.add(entry);
      }
    }

    // Sort descending by score
    unbundled.sort((a, b) => b.calculatedScore.compareTo(a.calculatedScore));

    // Re-index ranks 1..N
    return List.generate(unbundled.length, (index) {
      return unbundled[index].copyWith(rankPosition: index + 1);
    });
  }
}
