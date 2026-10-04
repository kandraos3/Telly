/// Domain models for SCR-08 Show Detail Page (FE-611).
/// Conforms to `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §SCR-08
/// and `docs/features/03_SERIES_VS_SEASONS_AND_DROPPED_TRACKING.md`.
class TitleDetail {
  final int id;
  final String mediaType; // 'movie' or 'tv'
  final String title;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final DateTime? releaseDate;
  final int? runtimeMinutes;
  final String? network;
  final String? director;
  final int? numberOfSeasons;
  final int? numberOfEpisodes;
  final double? communityScore;
  final List<String> genres;
  final List<TitleSeasonDetail> seasons;
  final List<TitleAvailabilityDetail> availabilities;
  final TitleSocialSummary? socialSummary;

  const TitleDetail({
    required this.id,
    required this.mediaType,
    required this.title,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
    this.runtimeMinutes,
    this.network,
    this.director,
    this.numberOfSeasons,
    this.numberOfEpisodes,
    this.communityScore,
    this.genres = const [],
    this.seasons = const [],
    this.availabilities = const [],
    this.socialSummary,
  });

  bool get isMovie => mediaType == 'movie';
  bool get isTv => mediaType == 'tv';

  String get releaseYear =>
      releaseDate != null ? '${releaseDate!.year}' : '';

  factory TitleDetail.fromJson({
    required Map<String, dynamic> titleRow,
    List<Map<String, dynamic>> seasonRows = const [],
    List<Map<String, dynamic>> availabilityRows = const [],
    Map<String, dynamic>? socialSummaryJson,
  }) {
    final rawRelease = titleRow['release_date']?.toString();
    DateTime? releaseDate;
    if (rawRelease != null && rawRelease.isNotEmpty) {
      releaseDate = DateTime.tryParse(rawRelease);
    }

    return TitleDetail(
      id: (titleRow['id'] as num).toInt(),
      mediaType: titleRow['media_type']?.toString() ?? 'tv',
      title: titleRow['title']?.toString() ?? '',
      overview: titleRow['overview']?.toString(),
      posterPath: titleRow['poster_path']?.toString(),
      backdropPath: titleRow['backdrop_path']?.toString(),
      releaseDate: releaseDate,
      runtimeMinutes: (titleRow['runtime_minutes'] as num?)?.toInt(),
      network: titleRow['original_network']?.toString(),
      director: titleRow['director']?.toString(),
      numberOfSeasons: (titleRow['number_of_seasons'] as num?)?.toInt(),
      numberOfEpisodes: (titleRow['number_of_episodes'] as num?)?.toInt(),
      communityScore:
          (titleRow['global_community_score'] as num?)?.toDouble(),
      genres: (titleRow['genres'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      seasons: seasonRows.map(TitleSeasonDetail.fromJson).toList(),
      availabilities:
          availabilityRows.map(TitleAvailabilityDetail.fromJson).toList(),
      socialSummary: socialSummaryJson != null
          ? TitleSocialSummary.fromJson(socialSummaryJson)
          : null,
    );
  }
}

class TitleSeasonDetail {
  final int seasonNumber;
  final String name;
  final int episodeCount;
  final String? airDate;
  final String? overview;
  final double? avgScore;

  const TitleSeasonDetail({
    required this.seasonNumber,
    required this.name,
    this.episodeCount = 0,
    this.airDate,
    this.overview,
    this.avgScore,
  });

  factory TitleSeasonDetail.fromJson(Map<String, dynamic> json) {
    return TitleSeasonDetail(
      seasonNumber: (json['season_number'] as num?)?.toInt() ?? 1,
      name: json['name']?.toString() ??
          'Season ${(json['season_number'] ?? 1)}',
      episodeCount: (json['episode_count'] as num?)?.toInt() ?? 0,
      airDate: json['air_date']?.toString(),
      overview: json['overview']?.toString(),
      avgScore: (json['avg_score'] as num?)?.toDouble(),
    );
  }
}

class TitleAvailabilityDetail {
  final String platformId;
  final String? monetizationType;
  final String? deepLinkUrl;

  const TitleAvailabilityDetail({
    required this.platformId,
    this.monetizationType,
    this.deepLinkUrl,
  });

  factory TitleAvailabilityDetail.fromJson(Map<String, dynamic> json) {
    return TitleAvailabilityDetail(
      platformId: json['platform_id']?.toString() ?? '',
      monetizationType: json['monetization_type']?.toString(),
      deepLinkUrl: json['deep_link_url']?.toString(),
    );
  }
}

class TitleSocialSummary {
  final MyTitleRanking? myRanking;
  final List<FriendTitleRanking> friends;
  final CommunityRankingSummary? community;
  final CommunitySurvivalSummary? survival;

  const TitleSocialSummary({
    this.myRanking,
    this.friends = const [],
    this.community,
    this.survival,
  });

  factory TitleSocialSummary.fromJson(Map<String, dynamic> json) {
    return TitleSocialSummary(
      myRanking: json['my_ranking'] != null
          ? MyTitleRanking.fromJson(
              Map<String, dynamic>.from(json['my_ranking'] as Map))
          : null,
      friends: (json['friends'] as List<dynamic>?)
              ?.map((f) => FriendTitleRanking.fromJson(
                  Map<String, dynamic>.from(f as Map)))
              .toList() ??
          const [],
      community: json['community'] != null
          ? CommunityRankingSummary.fromJson(
              Map<String, dynamic>.from(json['community'] as Map))
          : null,
      survival: json['survival'] != null
          ? CommunitySurvivalSummary.fromJson(
              Map<String, dynamic>.from(json['survival'] as Map))
          : null,
    );
  }
}

class MyTitleRanking {
  final int rankPosition;
  final double calculatedScore;
  final double? ratingUncertainty;
  final int? canonSize;

  const MyTitleRanking({
    required this.rankPosition,
    required this.calculatedScore,
    this.ratingUncertainty,
    this.canonSize,
  });

  factory MyTitleRanking.fromJson(Map<String, dynamic> json) {
    return MyTitleRanking(
      rankPosition: (json['rank_position'] as num?)?.toInt() ?? 1,
      calculatedScore:
          (json['calculated_score'] as num?)?.toDouble() ?? 5.0,
      ratingUncertainty:
          (json['rating_uncertainty'] as num?)?.toDouble(),
      canonSize: (json['canon_size'] as num?)?.toInt(),
    );
  }
}

class FriendTitleRanking {
  final String userId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final int rankPosition;
  final double calculatedScore;

  const FriendTitleRanking({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.rankPosition,
    required this.calculatedScore,
  });

  factory FriendTitleRanking.fromJson(Map<String, dynamic> json) {
    return FriendTitleRanking(
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      displayName: json['display_name']?.toString() ??
          json['username']?.toString() ??
          '',
      avatarUrl: json['avatar_url']?.toString(),
      rankPosition: (json['rank_position'] as num?)?.toInt() ?? 1,
      calculatedScore:
          (json['calculated_score'] as num?)?.toDouble() ?? 5.0,
    );
  }
}

class CommunityRankingSummary {
  final double? avgScore;
  final int rankingCount;

  const CommunityRankingSummary({
    this.avgScore,
    required this.rankingCount,
  });

  factory CommunityRankingSummary.fromJson(Map<String, dynamic> json) {
    return CommunityRankingSummary(
      avgScore: (json['avg_score'] as num?)?.toDouble(),
      rankingCount: (json['ranking_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class CommunitySurvivalSummary {
  final int completed;
  final int watching;
  final int dropped;
  final int? completedPct;
  final CommonDropPoint? commonDropPoint;

  const CommunitySurvivalSummary({
    required this.completed,
    required this.watching,
    required this.dropped,
    this.completedPct,
    this.commonDropPoint,
  });

  factory CommunitySurvivalSummary.fromJson(Map<String, dynamic> json) {
    return CommunitySurvivalSummary(
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      watching: (json['watching'] as num?)?.toInt() ?? 0,
      dropped: (json['dropped'] as num?)?.toInt() ?? 0,
      completedPct: (json['completed_pct'] as num?)?.toInt(),
      commonDropPoint: json['common_drop_point'] != null
          ? CommonDropPoint.fromJson(
              Map<String, dynamic>.from(json['common_drop_point'] as Map))
          : null,
    );
  }
}

class CommonDropPoint {
  final int? season;
  final int? episode;
  final int? count;

  const CommonDropPoint({
    this.season,
    this.episode,
    this.count,
  });

  factory CommonDropPoint.fromJson(Map<String, dynamic> json) {
    return CommonDropPoint(
      season: (json['season'] as num?)?.toInt(),
      episode: (json['episode'] as num?)?.toInt(),
      count: (json['count'] as num?)?.toInt(),
    );
  }
}
