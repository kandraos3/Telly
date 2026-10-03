import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:telly_app/features/squads/domain/squad_models.dart';

/// Raw user rank observation for a specific title in their personal canon.
@immutable
class MemberRankEntry {
  final String userId;
  final String displayName;
  final int titleId;
  final String title;
  final String? posterUrl;
  final int releaseYear;
  final String mediaType;
  final int rankPosition; // 1-indexed (1 is top favorite)

  const MemberRankEntry({
    required this.userId,
    required this.displayName,
    required this.titleId,
    required this.title,
    this.posterUrl,
    required this.releaseYear,
    this.mediaType = 'tv',
    required this.rankPosition,
  });
}

/// Algorithmic consensus engine implementing Borda Count rank aggregation (BE-304, QA-301).
class SquadCanonAggregator {
  /// Aggregates individual member rankings into a consensus leaderboard using Borda Count.
  ///
  /// For member i who has ranked N_i items, title s at rank r_{i,s} earns:
  /// Points = N_i - r_{i,s} + 1
  static List<SquadConsensusItem> calculateConsensusCanon({
    required List<MemberRankEntry> entries,
    required String mediaType,
  }) {
    // 1. Filter entries for designated media type ('movie' or 'tv')
    final filtered = entries.where((e) => e.mediaType == mediaType).toList();
    if (filtered.isEmpty) return [];

    // 2. Compute N_i (total count of ranked items per user)
    final memberCanonSizes = <String, int>{};
    for (final entry in filtered) {
      memberCanonSizes[entry.userId] = (memberCanonSizes[entry.userId] ?? 0) + 1;
    }

    // 3. Group by titleId
    final titleGroups = <int, List<MemberRankEntry>>{};
    for (final entry in filtered) {
      titleGroups.putIfAbsent(entry.titleId, () => []).add(entry);
    }

    final rawResults = <_RawConsensus>[];

    for (final titleId in titleGroups.keys) {
      final titleEntries = titleGroups[titleId]!;
      final first = titleEntries.first;

      int totalBordaPoints = 0;
      MemberRankEntry? champion;
      MemberRankEntry? lowest;
      final ranks = <int>[];

      for (final e in titleEntries) {
        final nI = memberCanonSizes[e.userId] ?? titleEntries.length;
        // Borda Points formula: N_i - r_{i,s} + 1
        final points = nI - e.rankPosition + 1;
        totalBordaPoints += points;
        ranks.add(e.rankPosition);

        if (champion == null || e.rankPosition < champion.rankPosition) {
          champion = e;
        }
        if (lowest == null || e.rankPosition > lowest.rankPosition) {
          lowest = e;
        }
      }

      // Compute rank variance
      final meanRank = ranks.reduce((a, b) => a + b) / ranks.length;
      double variance = 0.0;
      if (ranks.length > 1) {
        final sumSquaredDiff = ranks.fold<double>(
          0.0,
          (sum, r) => sum + math.pow(r - meanRank, 2),
        );
        variance = sumSquaredDiff / (ranks.length - 1); // Sample variance
      }

      rawResults.add(
        _RawConsensus(
          titleId: titleId,
          title: first.title,
          posterUrl: first.posterUrl,
          releaseYear: first.releaseYear,
          mediaType: first.mediaType,
          totalBordaPoints: totalBordaPoints,
          championUserId: champion!.userId,
          championDisplayName: champion.displayName,
          championRank: champion.rankPosition,
          lowestUserId: lowest!.userId,
          lowestDisplayName: lowest.displayName,
          lowestRank: lowest.rankPosition,
          membersRankedCount: titleEntries.length,
          rankVariance: double.parse(variance.toStringAsFixed(2)),
          meanRank: meanRank,
        ),
      );
    }

    // 4. Sort descending by:
    // a) Total Borda points (highest first)
    // b) Member count (more consensus first)
    // c) Mean rank (lower numerical rank is better)
    // d) Title name alphabetical
    rawResults.sort((a, b) {
      final pointCmp = b.totalBordaPoints.compareTo(a.totalBordaPoints);
      if (pointCmp != 0) return pointCmp;

      final countCmp = b.membersRankedCount.compareTo(a.membersRankedCount);
      if (countCmp != 0) return countCmp;

      final rankCmp = a.meanRank.compareTo(b.meanRank);
      if (rankCmp != 0) return rankCmp;

      return a.title.compareTo(b.title);
    });

    // 5. Assign 1-indexed consensus ranks
    return List.generate(rawResults.length, (index) {
      final r = rawResults[index];
      return SquadConsensusItem(
        consensusRank: index + 1,
        titleId: r.titleId,
        title: r.title,
        posterUrl: r.posterUrl,
        releaseYear: r.releaseYear,
        mediaType: r.mediaType,
        totalBordaPoints: r.totalBordaPoints,
        championUserId: r.championUserId,
        championDisplayName: r.championDisplayName,
        championRank: r.championRank,
        lowestUserId: r.lowestUserId,
        lowestDisplayName: r.lowestDisplayName,
        lowestRank: r.lowestRank,
        membersRankedCount: r.membersRankedCount,
        rankVariance: r.rankVariance,
      );
    });
  }
}

class _RawConsensus {
  final int titleId;
  final String title;
  final String? posterUrl;
  final int releaseYear;
  final String mediaType;
  final int totalBordaPoints;
  final String championUserId;
  final String championDisplayName;
  final int championRank;
  final String lowestUserId;
  final String lowestDisplayName;
  final int lowestRank;
  final int membersRankedCount;
  final double rankVariance;
  final double meanRank;

  const _RawConsensus({
    required this.titleId,
    required this.title,
    this.posterUrl,
    required this.releaseYear,
    required this.mediaType,
    required this.totalBordaPoints,
    required this.championUserId,
    required this.championDisplayName,
    required this.championRank,
    required this.lowestUserId,
    required this.lowestDisplayName,
    required this.lowestRank,
    required this.membersRankedCount,
    required this.rankVariance,
    required this.meanRank,
  });
}
