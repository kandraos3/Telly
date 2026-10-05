/// Domain models for streaming availability and universal watchlist queue.
/// Defined in `docs/features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md` §2 & §6.
library streaming_models;

enum MonetizationType {
  flatrate('Subscription'),
  free('Free'),
  rent('Rent'),
  buy('Buy');

  final String label;
  const MonetizationType(this.label);

  static MonetizationType fromString(String val) {
    switch (val.toLowerCase()) {
      case 'flatrate':
      case 'subscription':
        return flatrate;
      case 'free':
        return free;
      case 'rent':
        return rent;
      case 'buy':
        return buy;
      default:
        return flatrate;
    }
  }
}

class StreamingPlatform {
  final String id; // 'netflix', 'max', 'apple_tv_plus', 'hulu', 'prime_video', 'crunchyroll'
  final String displayName;
  final String logoUrl;
  final String? baseDeepLink;
  final bool isFreeTier;

  const StreamingPlatform({
    required this.id,
    required this.displayName,
    required this.logoUrl,
    this.baseDeepLink,
    this.isFreeTier = false,
  });

  static const List<StreamingPlatform> standardPlatforms = [
    StreamingPlatform(
      id: 'netflix',
      displayName: 'Netflix',
      logoUrl: 'assets/icons/providers/netflix.png',
    ),
    StreamingPlatform(
      id: 'max',
      displayName: 'Max',
      logoUrl: 'assets/icons/providers/max.png',
    ),
    StreamingPlatform(
      id: 'apple_tv_plus',
      displayName: 'Apple TV+',
      logoUrl: 'assets/icons/providers/apple_tv.png',
    ),
    StreamingPlatform(
      id: 'hulu',
      displayName: 'Hulu',
      logoUrl: 'assets/icons/providers/hulu.png',
    ),
    StreamingPlatform(
      id: 'prime_video',
      displayName: 'Prime Video',
      logoUrl: 'assets/icons/providers/prime_video.png',
    ),
    StreamingPlatform(
      id: 'crunchyroll',
      displayName: 'Crunchyroll',
      logoUrl: 'assets/icons/providers/crunchyroll.png',
    ),
  ];

  /// Display name for a platform id (`apple_tv_plus` → `Apple TV+`); unknown ids are
  /// title-cased (`paramount_plus` → `Paramount Plus`).
  static String labelFor(String id) {
    for (final p in standardPlatforms) {
      if (p.id == id) return p.displayName;
    }
    return id.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }
}

class ShowStreamingAvailability {
  final String platformId;
  final String platformName;
  final MonetizationType monetizationType;
  final String? deepLinkUrl;
  final String webUrl;
  final DateTime? availableUntil;
  final bool isLeavingSoon;

  const ShowStreamingAvailability({
    required this.platformId,
    required this.platformName,
    required this.monetizationType,
    this.deepLinkUrl,
    required this.webUrl,
    this.availableUntil,
    this.isLeavingSoon = false,
  });
}

class WatchlistItem {
  final int showId;
  final String title;
  final String? posterPath;
  final String mediaType; // 'movie' or 'tv'
  final int? runtimeMinutes;
  final int? seasonCount;
  final int? episodeCount;
  final double friendsAvgScore;
  final int friendsCount;
  final String? savedFromHandle;
  final List<ShowStreamingAvailability> availability;
  final DateTime addedAt;
  final bool isLeavingSoon;

  const WatchlistItem({
    required this.showId,
    required this.title,
    this.posterPath,
    required this.mediaType,
    this.runtimeMinutes,
    this.seasonCount,
    this.episodeCount,
    this.friendsAvgScore = 0.0,
    this.friendsCount = 0,
    this.savedFromHandle,
    this.availability = const [],
    required this.addedAt,
    this.isLeavingSoon = false,
  });

  /// True if title is available under any of the user's active subscriptions
  bool isAvailableOn(Set<String> userSubscriptions) {
    if (userSubscriptions.isEmpty) return false;
    return availability.any(
      (a) => a.monetizationType == MonetizationType.flatrate && userSubscriptions.contains(a.platformId),
    );
  }

  /// The first matching streaming platform among user subscriptions
  ShowStreamingAvailability? primarySubscribedAvailability(Set<String> userSubscriptions) {
    return availability.cast<ShowStreamingAvailability?>().firstWhere(
          (a) => a != null && a.monetizationType == MonetizationType.flatrate && userSubscriptions.contains(a.platformId),
          orElse: () => availability.isNotEmpty ? availability.first : null,
        );
  }
}
