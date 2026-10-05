import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/cowatch/data/co_watch_repository.dart';
import 'package:telly_app/features/cowatch/domain/two_to_watch_engine.dart';
import 'package:telly_app/features/cowatch/presentation/screens/two_to_watch_screen.dart';
import 'package:telly_app/features/profile/data/profile_repository.dart';
import 'package:telly_app/features/queue/domain/streaming_models.dart';
import 'package:telly_app/features/title_detail/data/title_detail_repository.dart';
import 'package:telly_app/features/title_detail/domain/title_detail_models.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_co_watch_repository.dart';
import '../../fakes/fake_profile_repository.dart';
import '../../helpers/router_harness.dart';

const maya = CoWatchPartner(userId: 'u-maya', username: 'maya', displayName: 'Maya Lin');
const jordan = CoWatchPartner(userId: 'u-jordan', username: 'jordan', displayName: 'Jordan');

const parasite = CoWatchCandidate(
  showId: 496243,
  title: 'Parasite',
  mediaType: 'movie',
  runtimeMinutes: 132,
  posterPath: '/parasite.jpg',
  network: 'CJ Entertainment',
  availableProviders: ['max'],
  vibeTags: ['Thriller', 'Drama'],
  inWatchlistA: true,
  inWatchlistB: true,
  communityScore: 9.7,
);
const interstellar = CoWatchCandidate(
  showId: 157336,
  title: 'Interstellar',
  mediaType: 'movie',
  runtimeMinutes: 169,
  posterPath: '/interstellar.jpg',
  network: 'Paramount',
  availableProviders: ['netflix'],
  vibeTags: ['Science Fiction'],
  communityScore: 9.6,
);
const severance = CoWatchCandidate(
  showId: 95396,
  title: 'Severance',
  mediaType: 'tv',
  posterPath: '/severance.jpg',
  network: 'Apple TV+',
  availableProviders: ['apple_tv_plus'],
  vibeTags: ['Drama', 'Mystery'],
  inWatchlistA: true,
  communityScore: 9.4,
);

void main() {
  late FakeCoWatchRepository coWatch;
  late FakeProfileRepository profiles;
  late FakeTitleDetailRepository titles;

  setUp(() {
    coWatch = FakeCoWatchRepository(
      partners: const [maya, jordan],
      pools: {
        'movie': [parasite, interstellar],
        'tv': [severance],
      },
    );
    profiles = FakeProfileRepository();
    profiles.matches[('u-maya', 'movie')] = const CanonMatch(92, 14);
    profiles.matches[('u-maya', 'tv')] = const CanonMatch(84, 9);
    titles = FakeTitleDetailRepository();
  });

  Future<void> pump(WidgetTester tester, TwoToWatchScreen screen) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(routerHarness(screen, overrides: [
      posterNetworkImagesProvider.overrideWithValue(false),
      coWatchRepositoryProvider.overrideWithValue(coWatch),
      profileRepositoryProvider.overrideWithValue(profiles),
      titleDetailRepositoryProvider.overrideWithValue(titles),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(signedInUserId: 'u-me')),
    ]));
    await tester.pumpAndSettle();
  }

  const withMaya = TwoToWatchScreen(friendId: 'u-maya', friendHandle: 'maya', friendDisplayName: 'Maya Lin');

  group('FE-COWATCH-01: SCR-16 streamlined three-step flow', () {
    testWidgets('lays out Who → Mood → Picks with the real match and real picks', (tester) async {
      await pump(tester, withMaya);

      expect(find.text("WHO'S WATCHING?"), findsOneWidget);
      expect(find.text('WHAT ARE YOU IN THE MOOD FOR?'), findsOneWidget);
      expect(find.text("TONIGHT'S TOP PICKS"), findsOneWidget);
      expect(find.text('Maya Lin'), findsOneWidget);
      expect(find.text('92% MATCH'), findsOneWidget);

      // Real candidates from get_co_watch_candidates, best first, with their real posters.
      expect(find.byKey(const Key('cowatch_pick_496243')), findsOneWidget);
      expect(find.byKey(const Key('cowatch_pick_157336')), findsOneWidget);
      final posters = tester.widgetList<PosterImage>(find.byType(PosterImage)).map((p) => p.posterPath);
      expect(posters, containsAll(['/parasite.jpg', '/interstellar.jpg']));
      expect(find.text('Parasite'), findsOneWidget);
      expect(find.textContaining('★ 9.7'), findsOneWidget);
      expect(coWatch.candidateCalls, [('u-maya', 'movie')]);
    });

    testWidgets('tapping a pick opens the real title detail route', (tester) async {
      await pump(tester, withMaya);
      await tester.tap(find.byKey(const Key('cowatch_pick_496243')));
      await tester.pumpAndSettle();
      expect(find.text('route:/title/movie/496243'), findsOneWidget);
    });

    testWidgets('switching to TV Series loads the series pool and its match', (tester) async {
      await pump(tester, withMaya);
      await tester.tap(find.byKey(const Key('cowatch_format_tv')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cowatch_pick_95396')), findsOneWidget);
      expect(find.text('Parasite'), findsNothing);
      expect(find.text('84% MATCH'), findsOneWidget);
      expect(coWatch.candidateCalls, [('u-maya', 'movie'), ('u-maya', 'tv')]);
    });

    testWidgets('without a friend it asks who is watching, then loads picks for them', (tester) async {
      await pump(tester, const TwoToWatchScreen());

      expect(find.text("Pick who you're watching with first."), findsOneWidget);
      expect(coWatch.candidateCalls, isEmpty);

      await tester.tap(find.byKey(const Key('cowatch_partner_maya')));
      await tester.pumpAndSettle();

      expect(find.text('Maya Lin'), findsOneWidget);
      expect(find.byKey(const Key('cowatch_pick_496243')), findsOneWidget);
      expect(coWatch.candidateCalls, [('u-maya', 'movie')]);
    });

    testWidgets('a handle-only link resolves the friend instead of using the handle as an id', (tester) async {
      profiles.profiles['maya'] = const PublicProfile(id: 'u-maya', username: 'maya', displayName: 'Maya Lin');
      await pump(tester, const TwoToWatchScreen(friendHandle: 'maya'));

      expect(find.text('Maya Lin'), findsOneWidget);
      expect(coWatch.candidateCalls, [('u-maya', 'movie')]);
    });

    testWidgets('the friend can be swapped for someone else I follow', (tester) async {
      await pump(tester, withMaya);
      await tester.tap(find.byKey(const Key('cowatch_change_partner')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cowatch_pick_jordan')));
      await tester.pumpAndSettle();

      expect(find.text('Jordan'), findsWidgets);
      expect(find.text('92% MATCH'), findsNothing, reason: "Maya's match must not carry over");
      expect(coWatch.candidateCalls.last, ('u-jordan', 'movie'));
    });

    testWidgets('with no follows it explains how to start', (tester) async {
      coWatch.partners = const [];
      await pump(tester, const TwoToWatchScreen());
      expect(find.text('Follow friends to decide what to watch together.'), findsOneWidget);
    });

    testWidgets('a known overlap filters picks to shared services; an unknown one does not', (tester) async {
      coWatch.streaming = const SharedStreaming(shared: {'max'}, mineSet: true, partnerSet: true);
      await pump(tester, withMaya);

      expect(find.byKey(const Key('cowatch_provider_max')), findsOneWidget);
      expect(find.text(StreamingPlatform.labelFor('max')), findsOneWidget);
      expect(find.byKey(const Key('cowatch_pick_496243')), findsOneWidget);
      expect(find.byKey(const Key('cowatch_pick_157336')), findsNothing, reason: 'Netflix only');
      expect(find.text('Watch on Max'), findsOneWidget);
    });

    testWidgets('an empty pool says so instead of showing mock titles', (tester) async {
      coWatch.pools
        ..['movie'] = const []
        ..['tv'] = const [];
      await pump(tester, withMaya);

      expect(find.text('Nothing on either of your queues yet. Queue a few titles and come back.'), findsOneWidget);
      expect(find.byKey(const Key('cowatch_quick_swipe_btn')), findsNothing);
    });

    testWidgets('a failed load shows an error, not fallback titles', (tester) async {
      coWatch.failCandidates = true;
      await pump(tester, withMaya);
      expect(find.text("Couldn't load picks. Check your connection and try again."), findsOneWidget);
    });

    testWidgets('a title opened from its detail page is pinned with its real name', (tester) async {
      titles.addTitle(const TitleDetail(
        id: 95396,
        mediaType: 'tv',
        title: 'Severance',
        posterPath: '/severance.jpg',
        genres: ['Drama'],
        communityScore: 9.4,
        availabilities: [TitleAvailabilityDetail(platformId: 'apple_tv_plus')],
      ));
      coWatch.pools['tv'] = const [];
      await pump(
        tester,
        const TwoToWatchScreen(friendId: 'u-maya', friendHandle: 'maya', preselectedTitleId: 95396, preselectedMediaType: 'tv'),
      );

      expect(find.byKey(const Key('cowatch_preselected_badge')), findsOneWidget);
      expect(find.textContaining('Deciding on'), findsOneWidget);
      expect(find.textContaining('Pre-Selected Title'), findsNothing);
      // Opened on the series canon, with the real title pinned as the first pick.
      expect(find.byKey(const Key('cowatch_pick_95396')), findsOneWidget);
      expect(coWatch.candidateCalls, [('u-maya', 'tv')]);
    });

    testWidgets('Quick Swipe opens with the top picks', (tester) async {
      await pump(tester, withMaya);
      await tester.tap(find.byKey(const Key('cowatch_quick_swipe_btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('QUICK SWIPE DUEL'), findsOneWidget);
      expect(find.byKey(const Key('quick_swipe_poster_496243')), findsOneWidget);
      Navigator.of(tester.element(find.text('QUICK SWIPE DUEL'))).pop();
      await tester.pumpAndSettle();
    });
  });
}
