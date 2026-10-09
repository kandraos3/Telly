import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/discovery_models.dart';
import '../../domain/explore_ranker.dart';
import 'explore_rows_controller.dart';

/// [pick] as the `RecommendedTitle` the feed and search cards show: "Because you loved X"
/// when it came from one of my seeds, else "Trending on Telly" or "Top rated on Telly".
RecommendedTitle recommendedFrom(ScoredCandidate pick, ExploreRows rows) {
  final c = pick.candidate;
  final seed = rows.strongestSeed(pick);
  final trending = c.trendingRank != null || c.tellyRecentRankings > 0;
  return RecommendedTitle(
    titleId: c.titleId,
    mediaType: c.mediaType,
    title: c.title,
    posterPath: c.posterPath,
    network: c.originalNetwork,
    communityScore: c.communityScore,
    releaseYear: c.releaseYear,
    reason: seed != null
        ? RecommendationReason.becauseYouLoved
        : trending
            ? RecommendationReason.trending
            : RecommendationReason.topRated,
    reasonTitle: seed?.title,
    providers: c.providers,
  );
}

/// Alternates items from [a] and [b], skipping repeats, up to [limit].
List<RecommendedTitle> _interleave(List<RecommendedTitle> a, List<RecommendedTitle> b, int limit) {
  final out = <RecommendedTitle>[];
  final seen = <String>{};
  for (var i = 0; out.length < limit && (i < a.length || i < b.length); i++) {
    for (final t in [if (i < a.length) a[i], if (i < b.length) b[i]]) {
      if (out.length < limit && seen.add('${t.mediaType}:${t.titleId}')) out.add(t);
    }
  }
  return out;
}

Future<ExploreRows?> _rows(Ref ref, String mediaType) async {
  try {
    return (await ref.watch(exploreRowsProvider(mediaType).future)).rows;
  } catch (_) {
    return null; // a canon that can't load just contributes nothing
  }
}

/// My best picks across both canons (the hero, then Top picks), alternating movie and series:
/// the Home feed's recommendation cards (#182) take them from here.
final explorePicksProvider = FutureProvider<List<RecommendedTitle>>((ref) async {
  List<RecommendedTitle> picks(ExploreRows? rows) => rows == null
      ? const []
      : [
          if (rows.hero != null) recommendedFrom(rows.hero!.pick, rows),
          for (final s in rows.row(ExploreRowKind.topPicks)?.visible ?? const <ScoredCandidate>[])
            recommendedFrom(s, rows),
        ];
  final movies = await _rows(ref, 'movie');
  final series = await _rows(ref, 'tv');
  return _interleave(picks(movies), picks(series), 12);
});

/// Trending across both canons for Explore's search zero state, alternating movie and series.
final exploreTrendingProvider = FutureProvider<List<RecommendedTitle>>((ref) async {
  List<RecommendedTitle> trending(ExploreRows? rows) => rows == null
      ? const []
      : [for (final s in rows.row(ExploreRowKind.trending)?.items ?? const <ScoredCandidate>[]) recommendedFrom(s, rows)];
  final movies = await _rows(ref, 'movie');
  final series = await _rows(ref, 'tv');
  return _interleave(trending(movies), trending(series), 8);
});
