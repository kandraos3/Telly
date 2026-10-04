import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/queue/data/streaming_availability_repository.dart';
import 'package:telly_app/features/queue/data/watchlist_repository.dart';
import 'package:telly_app/features/queue/domain/streaming_models.dart';
import 'package:telly_app/features/queue/presentation/screens/smart_queue_screen.dart';

import '../../fakes/fake_watchlist_repository.dart';

class FakeStreamingAvailabilityRepository implements StreamingAvailabilityRepository {
  @override
  Future<List<ShowStreamingAvailability>> getAvailability({
    required int titleId,
    required String mediaType,
    String? country,
  }) async {
    if (titleId == 101) {
      return const [
        ShowStreamingAvailability(
          platformId: 'apple_tv_plus',
          platformName: 'Apple TV+',
          monetizationType: MonetizationType.flatrate,
          webUrl: 'https://apple.com',
          deepLinkUrl: 'videos://apple.com',
          isLeavingSoon: true,
        ),
      ];
    }
    return const [];
  }
}

void main() {
  group('FE-609: WatchlistNotifier & Queue Providers tests', () {
    test('enriches entries with streaming availability', () async {
      final fakeRepo = FakeWatchlistRepository();
      await fakeRepo.add(
        titleId: 101,
        mediaType: 'tv',
        title: 'Slow Horses',
      );

      final container = ProviderContainer(
        overrides: [
          watchlistRepositoryProvider.overrideWithValue(fakeRepo),
          streamingAvailabilityRepositoryProvider.overrideWithValue(FakeStreamingAvailabilityRepository()),
        ],
      );
      addTearDown(container.dispose);

      final items = await container.read(userWatchlistProvider.future);
      expect(items, hasLength(1));
      expect(items.first.title, 'Slow Horses');
      expect(items.first.isLeavingSoon, isTrue);
      expect(items.first.availability, hasLength(1));
      expect(items.first.availability.first.platformId, 'apple_tv_plus');
    });

    test('addItem and removeItem update repository', () async {
      final fakeRepo = FakeWatchlistRepository();
      final container = ProviderContainer(
        overrides: [
          watchlistRepositoryProvider.overrideWithValue(fakeRepo),
          streamingAvailabilityRepositoryProvider.overrideWithValue(FakeStreamingAvailabilityRepository()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(userWatchlistProvider.notifier).addItem(
            titleId: 201,
            mediaType: 'movie',
            title: 'Parasite',
          );
      expect(await fakeRepo.isInWatchlist(201, 'movie'), isTrue);

      await container.read(userWatchlistProvider.notifier).removeItem(201, 'movie');
      expect(await fakeRepo.isInWatchlist(201, 'movie'), isFalse);
    });

    test('queueFilterSubscribedProvider toggles correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(queueFilterSubscribedProvider), isFalse);
      container.read(queueFilterSubscribedProvider.notifier).toggle();
      expect(container.read(queueFilterSubscribedProvider), isTrue);
      container.read(queueFilterSubscribedProvider.notifier).set(false);
      expect(container.read(queueFilterSubscribedProvider), isFalse);
    });

    test('queueSortByProvider changes sort modes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(queueSortByProvider), 'friends_score');
      container.read(queueSortByProvider.notifier).set('leaving_soon');
      expect(container.read(queueSortByProvider), 'leaving_soon');
    });
  });
}
