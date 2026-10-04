/// Two-to-Watch recommendation engine and candidate scorer.
/// Conforms to `docs/features/05_TASTE_MATCH_AND_CO_WATCH_DECIDER.md` §3
/// and `docs/features/09_MOVIE_INTEGRATION_AND_DUAL_CANON.md` §5.
library two_to_watch_engine;

import '../../ranking/domain/canon_tier.dart';

enum CoWatchFormat {
  movieNight('Movie Night', 'movie'),
  series('Start a Series', 'tv');

  final String label;
  final String mediaType;
  const CoWatchFormat(this.label, this.mediaType);
}

enum RuntimeBudget {
  breezy('< 90m (Breezy)', 0, 90),
  standard('90–120m (Standard)', 91, 120),
  epic('120m+ (Epic)', 121, 999);

  final String label;
  final int minMinutes;
  final int maxMinutes;
  const RuntimeBudget(this.label, this.minMinutes, this.maxMinutes);

  bool matches(int? runtime) {
    if (runtime == null) return false;
    return runtime >= minMinutes && runtime <= maxMinutes;
  }
}

class CoWatchCandidate {
  final int showId;
  final String title;
  final String mediaType; // 'movie' or 'tv'
  final int? runtimeMinutes;
  final String? posterPath;
  final String network;
  final List<String> availableProviders;
  final List<String> vibeTags;
  final bool inWatchlistA;
  final bool inWatchlistB;
  final double? ratingA; // God Tier when CanonTier.fromScore(...) == CanonTier.god
  final double? ratingB;
  final double communityScore;
  final String overview;

  const CoWatchCandidate({
    required this.showId,
    required this.title,
    required this.mediaType,
    this.runtimeMinutes,
    this.posterPath,
    required this.network,
    this.availableProviders = const [],
    this.vibeTags = const [],
    this.inWatchlistA = false,
    this.inWatchlistB = false,
    this.ratingA,
    this.ratingB,
    this.communityScore = 8.0,
    this.overview = '',
  });

  bool get inBothWatchlists => inWatchlistA && inWatchlistB;

  factory CoWatchCandidate.fromJson(Map<String, dynamic> json) {
    return CoWatchCandidate(
      showId: (json['show_id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      mediaType: json['media_type'] as String? ?? 'movie',
      runtimeMinutes: (json['runtime_minutes'] as num?)?.toInt(),
      posterPath: json['poster_path'] as String?,
      network: json['network'] as String? ?? '',
      availableProviders: (json['available_providers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      vibeTags: (json['vibe_tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      inWatchlistA: json['in_watchlist_a'] as bool? ?? false,
      inWatchlistB: json['in_watchlist_b'] as bool? ?? false,
      ratingA: (json['rating_a'] as num?)?.toDouble(),
      ratingB: (json['rating_b'] as num?)?.toDouble(),
      communityScore: (json['community_score'] as num?)?.toDouble() ?? 8.0,
      overview: json['overview'] as String? ?? '',
    );
  }
}

class ScoredRecommendation {
  final CoWatchCandidate candidate;
  final double score;
  final String matchReason;
  final List<String> matchedProviders;

  const ScoredRecommendation({
    required this.candidate,
    required this.score,
    required this.matchReason,
    required this.matchedProviders,
  });
}

class TwoToWatchEngine {
  /// Computes intersection of streaming providers between user A and user B:
  /// Shared = Providers_A ∩ Providers_B
  static Set<String> computeSharedProviders({
    required Set<String> providersA,
    required Set<String> providersB,
  }) {
    return providersA.intersection(providersB);
  }

  /// Filters and ranks candidate titles based on shared providers, format, runtime, and vibe.
  static List<ScoredRecommendation> scoreCandidates({
    required List<CoWatchCandidate> candidates,
    required Set<String> activeSharedProviders,
    required CoWatchFormat format,
    RuntimeBudget? runtimeBudget,
    List<String> selectedVibes = const [],
    int tasteMatchPercentage = 88,
  }) {
    final scoredList = <ScoredRecommendation>[];

    for (final c in candidates) {
      // 1. Format filter
      if (c.mediaType != format.mediaType) {
        continue;
      }

      // 2. Runtime filter (if format is movie and budget is set)
      if (format == CoWatchFormat.movieNight && runtimeBudget != null) {
        if (!runtimeBudget.matches(c.runtimeMinutes)) {
          continue;
        }
      }

      // 3. Shared streaming intersection filter
      final matchedProviders = c.availableProviders.where((p) => activeSharedProviders.contains(p)).toList();
      if (activeSharedProviders.isNotEmpty && matchedProviders.isEmpty) {
        continue;
      }

      // 4. Scoring function:
      // Score = w1 * InBothWatchlists (+50) + w2 * TasteMatch * UserRating + w3 * PopularityFactor (+ GodTier + Vibe)
      double score = 0.0;
      final reasons = <String>[];

      // w1 * InBothWatchlists (+50 bonus points)
      if (c.inBothWatchlists) {
        score += 50.0;
        reasons.add('On both of your watchlists');
      }

      // God Tier recommendation (+35 points) via CanonTier.god
      final isGodTierA = c.ratingA != null && CanonTier.fromScore(c.ratingA!) == CanonTier.god && c.ratingB == null;
      final isGodTierB = c.ratingB != null && CanonTier.fromScore(c.ratingB!) == CanonTier.god && c.ratingA == null;
      if (isGodTierA) {
        score += 35.0;
        reasons.add('You rated it ★${c.ratingA!.toStringAsFixed(1)} (God Tier)');
      } else if (isGodTierB) {
        score += 35.0;
        reasons.add('Partner rated it ★${c.ratingB!.toStringAsFixed(1)} (God Tier)');
      }

      // Vibe tag match (+20 points)
      if (selectedVibes.isNotEmpty) {
        final matchesVibe = c.vibeTags.any((v) => selectedVibes.contains(v));
        if (matchesVibe) {
          score += 20.0;
          reasons.add('Matches selected vibe');
        }
      }

      // w2 * TasteMatch * UserRating (w2 = 2.5)
      const w2 = 2.5;
      final tasteMultiplier = tasteMatchPercentage / 100.0;
      final userRating = c.ratingA != null && c.ratingB != null
          ? (c.ratingA! + c.ratingB!) / 2.0
          : (c.ratingA ?? c.ratingB ?? c.communityScore);
      score += w2 * tasteMultiplier * userRating;

      // w3 * PopularityFactor (w3 = 10.0, PopularityFactor in [0, 1])
      const w3 = 10.0;
      final popularityFactor = (c.communityScore / 10.0).clamp(0.0, 1.0);
      score += w3 * popularityFactor;

      scoredList.add(
        ScoredRecommendation(
          candidate: c,
          score: double.parse(score.toStringAsFixed(1)),
          matchReason: reasons.isNotEmpty ? reasons.join(' • ') : 'Highly aligned with your shared taste',
          matchedProviders: matchedProviders.isNotEmpty ? matchedProviders : c.availableProviders,
        ),
      );
    }

    // Sort descending by score
    scoredList.sort((a, b) => b.score.compareTo(a.score));
    return scoredList;
  }
}
