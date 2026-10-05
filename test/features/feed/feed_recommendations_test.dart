import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/features/discovery/data/discovery_repository.dart';
import 'package:telly_app/features/discovery/domain/discovery_models.dart';
import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/feed/presentation/controllers/feed_recommendations.dart';
import 'package:telly_app/features/feed/presentation/screens/activity_feed_screen.dart';
import 'package:telly_app/features/queue/data/watchlist_repository.dart';

import '../../fakes/fake_social_repository.dart';
import '../../fakes/fake_watchlist_repository.dart';
import '../../helpers/router_harness.dart';

const saul = RecommendedTitle(
  titleId: 60059,
  mediaType: 'tv',
  title: 'Better Call Saul',
  network: 'AMC',
  communityScore: 9.48,
  reason: RecommendationReason.becauseYouLoved,
  reasonTitle: 'Breaking Bad',
  providers: ['netflix'],
);
const inception = RecommendedTitle(
  titleId: 27205,
  mediaType: 'movie',
  title: 'Inception',
  releaseYear: 2010,
  reason: RecommendationReason.trending,
);

void main() {
  group('FE-FEED-02: interleaveRecommendations', () {
    final posts = [for (var i = 0; i < 14; i++) fakeActivity('a$i', minutesAgo: i)];

    String shape(List<FeedEntry> entries) => entries
        .map((e) => switch (e) {
              ActivityEntry() => 'p',
              RecommendationEntry(:final title) => 'R${title.titleId}',
            })
        .join(' ');

    test('slots one pick after every six posts, in order, without repeats', () {
      expect(shape(interleaveRecommendations(posts, const [saul, inception, saul])),
          'p p p p p p R60059 p p p p p p R27205 p p');
    });

    test('never ends the feed on a pick and copes with too few picks or posts', () {
      expect(shape(interleaveRecommendations(posts.take(6).toList(), const [saul])), 'p p p p p p');
      expect(shape(interleaveRecommendations(posts, const [saul])), 'p p p p p p R60059 p p p p p p p p');
      expect(interleaveRecommendations(posts, const []).whereType<RecommendationEntry>(), isEmpty);
    });
  });

  group('FE-FEED-02: recommendation cards on SCR-05', () {
    late FakeWatchlistRepository watchlist;

    Future<void> pump(WidgetTester tester, {List<RecommendedTitle> picks = const [saul, inception]}) async {
      watchlist = FakeWatchlistRepository();
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(routerHarness(const ActivityFeedScreen(), overrides: [
        socialRepositoryProvider.overrideWithValue(
          FakeSocialRepository(feed: [for (var i = 0; i < 8; i++) fakeActivity('a$i', minutesAgo: i)]),
        ),
        discoveryRepositoryProvider.overrideWithValue(FakeDiscoveryRepository(recommended: picks)),
        watchlistRepositoryProvider.overrideWithValue(watchlist),
        posterNetworkImagesProvider.overrideWithValue(false),
        hapticsEnabledProvider.overrideWith((ref) => false),
      ]));
      await tester.pumpAndSettle();
    }

    testWidgets('a pick appears after the sixth post with its reason and where it streams', (tester) async {
      await pump(tester);
      final card = find.byKey(const Key('feed_rec_tv_60059'));
      expect(card, findsOneWidget);
      expect(find.text('PICKED FOR YOU'), findsOneWidget);
      expect(find.text('Because you loved Breaking Bad'), findsOneWidget);
      expect(find.text('Better Call Saul (AMC) is streaming on Netflix'), findsOneWidget);
      expect(
        tester.getTopLeft(card).dy,
        greaterThan(tester.getTopLeft(find.byKey(const Key('feed_card_a5'))).dy),
      );
      expect(
        tester.getTopLeft(card).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('feed_card_a6'))).dy),
      );
    });

    testWidgets('Add to Queue saves the pick and marks it', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('feed_rec_queue_60059')));
      await tester.pumpAndSettle();

      expect(watchlist.items.single.titleId, 60059);
      expect(watchlist.items.single.title, 'Better Call Saul');
      expect(find.descendant(of: find.byKey(const Key('feed_rec_tv_60059')), matching: find.text('In Queue')),
          findsOneWidget);
    });

    testWidgets('Rate / Rank opens the logging studio for the pick', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('feed_rec_rank_60059')));
      await tester.pumpAndSettle();
      expect(find.text('route:/log'), findsOneWidget);
    });

    testWidgets('tapping the card opens the title', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Because you loved Breaking Bad'));
      await tester.pumpAndSettle();
      expect(find.text('route:/title/tv/60059'), findsOneWidget);
    });

    testWidgets('no picks, no cards', (tester) async {
      await pump(tester, picks: const []);
      expect(find.text('PICKED FOR YOU'), findsNothing);
      expect(find.byKey(const Key('feed_card_a7')), findsOneWidget);
    });
  });
}
