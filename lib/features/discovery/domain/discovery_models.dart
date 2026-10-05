/// Domain models for SCR-07 Explore & Discover Hub (FE-612).
/// Conforms to `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §SCR-07
/// and `docs/features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md` §5.
class NetworkBattleground {
  final String network;
  final int titleCount;
  final double avgScore;
  final List<NetworkTopTitle> topTitles;

  const NetworkBattleground({
    required this.network,
    required this.titleCount,
    required this.avgScore,
    this.topTitles = const [],
  });

  factory NetworkBattleground.fromJson(Map<String, dynamic> json) {
    return NetworkBattleground(
      network: json['network']?.toString() ?? '',
      titleCount: (json['title_count'] as num?)?.toInt() ?? 0,
      avgScore: (json['avg_score'] as num?)?.toDouble() ?? 0.0,
      topTitles: (json['top_titles'] as List<dynamic>?)
              ?.map((t) =>
                  NetworkTopTitle.fromJson(Map<String, dynamic>.from(t as Map)))
              .toList() ??
          const [],
    );
  }
}

class NetworkTopTitle {
  final int id;
  final String title;
  final String? posterPath;
  final double score;

  const NetworkTopTitle({
    required this.id,
    required this.title,
    this.posterPath,
    required this.score,
  });

  factory NetworkTopTitle.fromJson(Map<String, dynamic> json) {
    return NetworkTopTitle(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      posterPath: json['poster_path']?.toString(),
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class FriendBingingItem {
  final int titleId;
  final String mediaType;
  final String title;
  final String? posterPath;
  final String? network;
  final double? communityScore;
  final int activeFriendCount;
  final double? avgFriendScore;
  final List<FriendAvatarInfo> friendAvatars;

  const FriendBingingItem({
    required this.titleId,
    required this.mediaType,
    required this.title,
    this.posterPath,
    this.network,
    this.communityScore,
    required this.activeFriendCount,
    this.avgFriendScore,
    this.friendAvatars = const [],
  });

  factory FriendBingingItem.fromJson(Map<String, dynamic> json) {
    return FriendBingingItem(
      titleId: (json['title_id'] as num?)?.toInt() ?? 0,
      mediaType: json['media_type']?.toString() ?? 'tv',
      title: json['title']?.toString() ?? '',
      posterPath: json['poster_path']?.toString(),
      network: json['original_network']?.toString(),
      communityScore:
          (json['global_community_score'] as num?)?.toDouble(),
      activeFriendCount:
          (json['active_friend_count'] as num?)?.toInt() ?? 0,
      avgFriendScore:
          (json['avg_friend_score'] as num?)?.toDouble(),
      friendAvatars: (json['friend_avatars'] as List<dynamic>?)
              ?.map((a) =>
                  FriendAvatarInfo.fromJson(Map<String, dynamic>.from(a as Map)))
              .toList() ??
          const [],
    );
  }
}

class FriendAvatarInfo {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? status;

  const FriendAvatarInfo({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.status,
  });

  factory FriendAvatarInfo.fromJson(Map<String, dynamic> json) {
    return FriendAvatarInfo(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      displayName: json['display_name']?.toString() ??
          json['username']?.toString() ??
          '',
      avatarUrl: json['avatar_url']?.toString(),
      status: json['status']?.toString(),
    );
  }
}

class CuratedCanonItem {
  final String id;
  final String emoji;
  final String title;
  final String subtitle;
  final List<String> sampleTitles;
  final String mediaType;

  const CuratedCanonItem({
    required this.id,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.sampleTitles = const [],
    this.mediaType = 'tv',
  });
}

class UserSearchResult {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  const UserSearchResult({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      displayName: json['display_name']?.toString() ??
          json['username']?.toString() ??
          '',
      avatarUrl: json['avatar_url']?.toString(),
    );
  }
}


/// Why a title is recommended (FE-EXPLORE-03), mirroring `reason_kind` from
/// `get_recommended_titles`.
enum RecommendationReason { becauseYouLoved, trending, topRated }

/// A title from `get_recommended_titles` / `get_trending_titles` (FE-EXPLORE-03).
class RecommendedTitle {
  final int titleId;
  final String mediaType;
  final String title;
  final String? posterPath;
  final String? network;
  final double? communityScore;
  final int? releaseYear;
  final RecommendationReason reason;

  /// The loved title this pick resembles, when [reason] is [RecommendationReason.becauseYouLoved].
  final String? reasonTitle;

  /// Subscription / free platforms it streams on (FE-FEED-02); empty when unknown.
  final List<String> providers;

  const RecommendedTitle({
    required this.titleId,
    required this.mediaType,
    required this.title,
    this.posterPath,
    this.network,
    this.communityScore,
    this.releaseYear,
    this.reason = RecommendationReason.topRated,
    this.reasonTitle,
    this.providers = const [],
  });

  factory RecommendedTitle.fromJson(Map<String, dynamic> json) {
    final reasonTitle = json['reason_title']?.toString();
    return RecommendedTitle(
      titleId: (json['title_id'] as num?)?.toInt() ?? 0,
      mediaType: json['media_type']?.toString() ?? 'tv',
      title: json['title']?.toString() ?? '',
      posterPath: json['poster_path']?.toString(),
      network: json['original_network']?.toString(),
      communityScore: (json['global_community_score'] as num?)?.toDouble(),
      releaseYear: (json['release_year'] as num?)?.toInt(),
      reason: switch (json['reason_kind']?.toString()) {
        'because_you_loved' when reasonTitle != null => RecommendationReason.becauseYouLoved,
        'trending' => RecommendationReason.trending,
        _ => (json['recent_rankings'] as num? ?? 0) > 0
            ? RecommendationReason.trending
            : RecommendationReason.topRated,
      },
      reasonTitle: reasonTitle,
      providers: [for (final p in (json['providers'] as List? ?? const [])) p.toString()],
    );
  }

  /// One-line explanation shown under the poster.
  String get reasonLabel => switch (reason) {
        RecommendationReason.becauseYouLoved => 'Because you loved $reasonTitle',
        RecommendationReason.trending => 'Trending on Telly',
        RecommendationReason.topRated => 'Top rated on Telly',
      };
}
