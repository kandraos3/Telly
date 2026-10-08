/// The `get_explore_candidates` payload (#46): one canon's ranking profile and the titles
/// Explore may recommend. Shape: `docs/features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md` §7.3.
/// Ranking happens in [ExploreRanker]; these classes only parse.
library;

double? _d(Object? v) => (v as num?)?.toDouble();
int? _i(Object? v) => (v as num?)?.toInt();
List<String> _strings(Object? v) => [for (final s in (v as List? ?? const [])) s.toString()];
List<Map<String, dynamic>> _maps(Object? v) =>
    [for (final m in (v as List? ?? const [])) Map<String, dynamic>.from(m as Map)];

class ExploreCandidates {
  final DateTime? generatedAt;
  final String mediaType;
  final ExploreProfile profile;
  final List<ExploreCandidate> candidates;

  const ExploreCandidates({
    this.generatedAt,
    required this.mediaType,
    required this.profile,
    this.candidates = const [],
  });

  factory ExploreCandidates.fromJson(Map<String, dynamic> json) {
    final mediaType = json['media_type']?.toString() ?? 'movie';
    return ExploreCandidates(
      generatedAt: DateTime.tryParse(json['generated_at']?.toString() ?? ''),
      mediaType: mediaType,
      profile: ExploreProfile.fromJson(Map<String, dynamic>.from(json['profile'] as Map? ?? const {})),
      candidates: [for (final c in _maps(json['candidates'])) ExploreCandidate.fromJson(c, mediaType)],
    );
  }
}

class ExploreProfile {
  /// My non-DROPPED rankings in the canon, for the genre profile.
  final List<ProfileRanking> rankings;

  /// My top 5 titles in the canon with score ≥ 7.80, best first.
  final List<ExploreSeed> seeds;

  /// `streaming_platforms.id`s I subscribe to.
  final List<String> services;

  /// Seeds with no fresh `title_related` rows; the app asks `title-related` to fetch them.
  final List<int> missingRelated;

  const ExploreProfile({
    this.rankings = const [],
    this.seeds = const [],
    this.services = const [],
    this.missingRelated = const [],
  });

  factory ExploreProfile.fromJson(Map<String, dynamic> json) => ExploreProfile(
        rankings: [for (final r in _maps(json['rankings'])) ProfileRanking.fromJson(r)],
        seeds: [for (final s in _maps(json['seeds'])) ExploreSeed.fromJson(s)],
        services: _strings(json['services']),
        missingRelated: [for (final id in (json['missing_related'] as List? ?? const [])) (id as num).toInt()],
      );
}

class ProfileRanking {
  final int titleId;
  final double score;
  final int? rank;
  final List<String> genres;

  const ProfileRanking({required this.titleId, required this.score, this.rank, this.genres = const []});

  factory ProfileRanking.fromJson(Map<String, dynamic> json) => ProfileRanking(
        titleId: _i(json['title_id']) ?? 0,
        score: _d(json['score']) ?? 0,
        rank: _i(json['rank']),
        genres: _strings(json['genres']),
      );
}

class ExploreSeed {
  final int titleId;
  final String title;
  final String? posterPath;
  final double score;
  final int rank;

  const ExploreSeed({
    required this.titleId,
    required this.title,
    this.posterPath,
    required this.score,
    required this.rank,
  });

  factory ExploreSeed.fromJson(Map<String, dynamic> json) => ExploreSeed(
        titleId: _i(json['title_id']) ?? 0,
        title: json['title']?.toString() ?? '',
        posterPath: json['poster_path']?.toString(),
        score: _d(json['score']) ?? 0,
        rank: _i(json['rank']) ?? 0,
      );
}

/// A `title_related` row linking a candidate to one of my seeds; [position] is TMDB's 1-based order.
class SeedLink {
  final int seedId;
  final int position;

  const SeedLink({required this.seedId, required this.position});

  factory SeedLink.fromJson(Map<String, dynamic> json) =>
      SeedLink(seedId: _i(json['seed_id']) ?? 0, position: _i(json['position']) ?? 20);
}

/// A followee who ranked ([score]) or only queued (`score == null`) the candidate.
class CandidateFriend {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final double? score;
  final int? matchPct;

  const CandidateFriend({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.score,
    this.matchPct,
  });

  factory CandidateFriend.fromJson(Map<String, dynamic> json) => CandidateFriend(
        userId: json['user_id']?.toString() ?? '',
        displayName: json['display_name']?.toString() ?? '',
        avatarUrl: json['avatar_url']?.toString(),
        score: _d(json['score']),
        matchPct: _i(json['match_pct']),
      );
}

class ExploreCandidate {
  final int titleId;
  final String mediaType;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final int? releaseYear;
  final List<String> genres;
  final String? director;
  final String? originalNetwork;
  final int? collectionId;
  final double? communityScore;
  final int communityCount;
  final double? tmdbVoteAverage;
  final int? tmdbVoteCount;
  final List<SeedLink> seedLinks;
  final int? trendingRank;
  final int tellyRecentRankings;
  final List<CandidateFriend> friends;
  final List<String> providers;
  final bool onMyServices;
  final DateTime? leavingUntil;
  final bool inQueue;

  const ExploreCandidate({
    required this.titleId,
    required this.mediaType,
    required this.title,
    this.posterPath,
    this.backdropPath,
    this.releaseYear,
    this.genres = const [],
    this.director,
    this.originalNetwork,
    this.collectionId,
    this.communityScore,
    this.communityCount = 0,
    this.tmdbVoteAverage,
    this.tmdbVoteCount,
    this.seedLinks = const [],
    this.trendingRank,
    this.tellyRecentRankings = 0,
    this.friends = const [],
    this.providers = const [],
    this.onMyServices = false,
    this.leavingUntil,
    this.inQueue = false,
  });

  /// [payloadMediaType] fills in `media_type` when a row omits it (the RPC returns one canon).
  factory ExploreCandidate.fromJson(Map<String, dynamic> json, String payloadMediaType) => ExploreCandidate(
        titleId: _i(json['title_id']) ?? 0,
        mediaType: json['media_type']?.toString() ?? payloadMediaType,
        title: json['title']?.toString() ?? '',
        posterPath: json['poster_path']?.toString(),
        backdropPath: json['backdrop_path']?.toString(),
        releaseYear: _i(json['release_year']),
        genres: _strings(json['genres']),
        director: json['director']?.toString(),
        originalNetwork: json['original_network']?.toString(),
        collectionId: _i(json['collection_id']),
        communityScore: _d(json['community_score']),
        communityCount: _i(json['community_count']) ?? 0,
        tmdbVoteAverage: _d(json['tmdb_vote_average']),
        tmdbVoteCount: _i(json['tmdb_vote_count']),
        seedLinks: [for (final l in _maps(json['seed_links'])) SeedLink.fromJson(l)],
        trendingRank: _i(json['trending_rank']),
        tellyRecentRankings: _i(json['telly_recent_rankings']) ?? 0,
        friends: [for (final f in _maps(json['friends'])) CandidateFriend.fromJson(f)],
        providers: _strings(json['providers']),
        onMyServices: json['on_my_services'] == true,
        leavingUntil: DateTime.tryParse(json['leaving_until']?.toString() ?? ''),
        inQueue: json['in_queue'] == true,
      );
}
