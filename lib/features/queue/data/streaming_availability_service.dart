import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telly_app/features/queue/domain/streaming_models.dart';

/// Provider for user's active streaming subscriptions.
/// By default includes Netflix and Max.
final userSubscriptionsProvider = StateProvider<Set<String>>((ref) {
  return {'netflix', 'max', 'apple_tv_plus'};
});

/// Service providing streaming availability queries and catalog metadata.
/// Conforms to `docs/technical_architecture/03_EXTERNAL_APIS_AND_DATA_PIPELINES.md` §2.
class StreamingAvailabilityService {
  final Map<int, List<ShowStreamingAvailability>> _mockAvailability = {
    101: [
      const ShowStreamingAvailability(
        platformId: 'max',
        platformName: 'Max',
        monetizationType: MonetizationType.flatrate,
        deepLinkUrl: 'max://play/101',
        webUrl: 'https://play.max.com/show/101',
      ),
    ],
    102: [
      const ShowStreamingAvailability(
        platformId: 'apple_tv_plus',
        platformName: 'Apple TV+',
        monetizationType: MonetizationType.flatrate,
        deepLinkUrl: 'videos://tv.apple.com/us/show/severance/102',
        webUrl: 'https://tv.apple.com/us/show/severance/102',
      ),
    ],
    103: [
      const ShowStreamingAvailability(
        platformId: 'hulu',
        platformName: 'Hulu',
        monetizationType: MonetizationType.flatrate,
        deepLinkUrl: 'hulu://series/103',
        webUrl: 'https://www.hulu.com/series/103',
      ),
    ],
    104: [
      const ShowStreamingAvailability(
        platformId: 'netflix',
        platformName: 'Netflix',
        monetizationType: MonetizationType.flatrate,
        deepLinkUrl: 'nflx://www.netflix.com/title/104',
        webUrl: 'https://www.netflix.com/title/104',
      ),
    ],
    105: [
      const ShowStreamingAvailability(
        platformId: 'netflix',
        platformName: 'Netflix',
        monetizationType: MonetizationType.flatrate,
        deepLinkUrl: 'nflx://www.netflix.com/title/105',
        webUrl: 'https://www.netflix.com/title/105',
      ),
      const ShowStreamingAvailability(
        platformId: 'prime_video',
        platformName: 'Prime Video',
        monetizationType: MonetizationType.rent,
        webUrl: 'https://www.amazon.com/gp/video/detail/105',
      ),
    ],
  };

  /// Returns availability records for a given [showId].
  Future<List<ShowStreamingAvailability>> getAvailabilityForTitle(
      int showId) async {
    return _mockAvailability[showId] ??
        [
          const ShowStreamingAvailability(
            platformId: 'netflix',
            platformName: 'Netflix',
            monetizationType: MonetizationType.flatrate,
            deepLinkUrl: 'nflx://www.netflix.com/title/0',
            webUrl: 'https://www.netflix.com',
          )
        ];
  }
}

final streamingAvailabilityServiceProvider =
    Provider<StreamingAvailabilityService>((ref) {
  return StreamingAvailabilityService();
});
