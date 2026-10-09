import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/core/widgets/telly_log_fab.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/challenges/domain/challenge.dart';
import 'package:telly_app/features/challenges/presentation/controllers/challenges_controller.dart';
import 'package:telly_app/features/home/presentation/providers/home_providers.dart';
import 'package:telly_app/features/home/presentation/screens/home_screen.dart';
import 'package:telly_app/features/levels/domain/level_models.dart';
import 'package:telly_app/features/levels/presentation/controllers/levels_controller.dart';
import 'package:telly_app/features/queue/domain/streaming_models.dart';
import 'package:telly_app/features/queue/presentation/screens/smart_queue_screen.dart';
import 'package:telly_app/features/profile/presentation/controllers/profile_controller.dart';
import 'package:telly_app/features/ranking/domain/franchise_rollup_service.dart';
import 'package:telly_app/features/tracking/data/tracking_repository.dart';
import 'package:telly_app/features/tracking/domain/tracking_item.dart';
import 'package:telly_app/features/tracking/domain/tracking_models.dart';
import 'package:telly_app/features/tracking/presentation/providers/tracking_providers.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_social_repository.dart';
import '../../fakes/fake_tracking_repository.dart';
import '../levels/levels_fixtures.dart';
import 'home_fixtures.dart' show SeededChallenges, SeededLevel, SeededQueue, challenge, friendActivity, queued;

/// Fixed canon state for screen tests.
class _SeededCanon extends ProfileCanonNotifier {
  _SeededCanon(this.seed);
  final ProfileCanonState seed;

  @override
  ProfileCanonState build() => seed;
}

/// A social repository whose feed never loads (loading state) or always fails (offline).
class _StuckSocialRepository extends FakeSocialRepository {
  _StuckSocialRepository({this.fail = false});
  final bool fail;

  @override
  Future<FeedPage> getFeedPage({required FeedFilter filter, ActivityLog? after, int limit = 20}) =>
      fail ? Future.error(Exception('offline')) : Completer<FeedPage>().future;
}

CanonEntry _entry(int id, String title, String mediaType, int rank, double score) => CanonEntry(
      id: id,
      title: title,
      mediaType: mediaType,
      rankPosition: rank,
      calculatedScore: score,
    );

final _movies = [
  _entry(1, 'Past Lives', 'movie', 1, 9.80),
  _entry(2, 'Arrival', 'movie', 2, 9.10),
  _entry(3, 'Heat', 'movie', 3, 8.40),
  _entry(4, 'Tenet', 'movie', 4, 7.10),
];
final _series = [
  _entry(11, 'Severance', 'tv', 1, 9.90),
  _entry(12, 'The Bear', 'tv', 2, 9.00),
];

final _now = DateTime(2026, 10, 9, 12);
var _trackedId = 1000;

TrackingItem _tracked(
  String title, {
  int idle = 1,
  TrackingState state = TrackingState.watching,
  DateTime? newSince,
  bool ranked = false,
  EpisodeRef next = const EpisodeRef(2, 6),
}) =>
    TrackingItem(
      titleId: _trackedId++,
      mediaType: 'tv',
      title: title,
      state: state,
      startedAt: _now.subtract(const Duration(days: 90)),
      lastProgressAt: _now.subtract(Duration(days: idle)),
      place: const EpisodeRef(2, 5),
      newEpisodesSince: newSince,
      isRanked: ranked,
      airedTotal: 19,
      watched: 14,
      nextEpisode: state == TrackingState.watching ? NextEpisode(ref: next, name: 'Attila') : null,
    );

void main() {
  late ProviderContainer container;

  Future<void> pumpHome(
    WidgetTester tester, {
    ProfileCanonState? canon,
    SocialRepository? social,
    ThemeData? theme,
    List<TrackingItem> tracking = const [],
    List<WatchlistItem> queue = const [],
    YourLevel? level,
    ChallengesOverview overview = const ChallengesOverview(),
  }) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget stub(BuildContext _, GoRouterState state) => Scaffold(body: Text('route:${state.uri}'));
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/:a', builder: stub),
      GoRoute(path: '/:a/:b', builder: stub),
      GoRoute(path: '/:a/:b/:c', builder: stub),
    ]);
    container = ProviderContainer(overrides: [
      hapticsEnabledProvider.overrideWith((ref) => false),
      trackingRepositoryProvider.overrideWithValue(FakeTrackingRepository(tracking)),
      trackingNowProvider.overrideWithValue(() => _now),
      homeRandomProvider.overrideWithValue(Random(4)),
      userWatchlistProvider.overrideWith(() => SeededQueue(queue)),
      yourLevelControllerProvider.overrideWith(() => SeededLevel(level ?? sampleLevel(streak: 0))),
      challengesControllerProvider.overrideWith(() => SeededChallenges(overview)),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(
        signedInUserId: 'u-me',
        profile: UserProfile(
          id: 'u-me',
          username: 'me',
          displayName: 'Me',
          onboardingCompleted: true,
          createdAt: DateTime(2026),
        ),
      )),
      profileCanonProvider.overrideWith(
        () => _SeededCanon(canon ?? ProfileCanonState(movies: _movies, series: _series)),
      ),
      socialRepositoryProvider.overrideWithValue(
        social ??
            FakeSocialRepository(feed: [
              fakeActivity('a1', username: 'maya', title: 'The Bear', minutesAgo: 1),
              fakeActivity('a2', username: 'jordan', title: 'Severance', minutesAgo: 2),
              fakeActivity('a3', username: 'sam', title: 'Shogun', minutesAgo: 3),
              fakeActivity('a4', username: 'lee', title: 'Fargo', minutesAgo: 4),
            ]),
      ),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: theme ?? TellyTheme.dark, routerConfig: router),
    ));
    await tester.pump();
    await tester.pump();
  }

  group('#242: SCR-21 Home — Tonight hero', () {
    testWidgets('leads the page with the next episode and the one-tap button', (tester) async {
      await pumpHome(tester, tracking: [_tracked('Shogun')]);
      expect(tester.widget<Text>(find.byKey(const Key('home_hero_eyebrow'))).data, 'UP NEXT · SHOGUN');
      expect(tester.widget<Text>(find.byKey(const Key('home_hero_title'))).data, 'S2 · E6 "Attila"');
      expect(find.descendant(of: find.byKey(const Key('home_hero_primary')), matching: find.text('✓ Watched E6')), findsOneWidget);
      expect(find.byKey(const Key('home_hero_details')), findsOneWidget);
      expect(find.byKey(const Key('home_hero_progress')), findsOneWidget, reason: 'a series carries a progress line');
      expect(tester.getSize(find.byKey(const Key('home_hero'))).height, greaterThanOrEqualTo(236));
    });

    testWidgets('✓ Watched logs the episode with an Undo toast', (tester) async {
      await pumpHome(tester, tracking: [_tracked('Shogun')]);
      await tester.tap(find.byKey(const Key('home_hero_primary')));
      await tester.pump();
      await tester.pump();
      expect(find.text('S2 · E6 watched'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('the Undo toast floats above the Log button so Undo stays tappable', (tester) async {
      await pumpHome(tester, tracking: [_tracked('Shogun')]);
      await tester.tap(find.byKey(const Key('home_hero_primary')));
      await tester.pump();
      await tester.pump();
      final toast = tester.widget<SnackBar>(find.byKey(const Key('tracking_undo_tray')));
      expect((toast.margin! as EdgeInsets).bottom, 8 + TellyLogFab.clearance);
    });

    testWidgets('Details opens the title', (tester) async {
      final show = _tracked('Shogun');
      await pumpHome(tester, tracking: [show]);
      await tester.tap(find.byKey(const Key('home_hero_details')));
      await tester.pumpAndSettle();
      expect(find.text('route:${Routes.title('tv', show.titleId)}'), findsOneWidget);
    });

    testWidgets('a returned show says what is out, in amber, and names the show', (tester) async {
      await pumpHome(tester, tracking: [_tracked('Shogun', newSince: _now)]);
      final eyebrow = tester.widget<Text>(find.byKey(const Key('home_hero_eyebrow')));
      expect(eyebrow.data, 'SHOGUN · E6 IS OUT');
      expect(eyebrow.style!.color, const Color(0xFFFFA733));
    });

    testWidgets('a movie says so, finishes with one tap and has no progress line', (tester) async {
      final film = TrackingItem(
        titleId: 5000,
        mediaType: 'movie',
        title: 'Dune: Part Two',
        state: TrackingState.watching,
        startedAt: _now.subtract(const Duration(days: 1)),
        lastProgressAt: _now.subtract(const Duration(days: 1)),
      );
      await pumpHome(tester, tracking: [film]);
      expect(tester.widget<Text>(find.byKey(const Key('home_hero_eyebrow'))).data, 'WATCHING · MOVIE');
      expect(tester.widget<Text>(find.byKey(const Key('home_hero_meta'))).data, 'Started yesterday');
      expect(find.descendant(of: find.byKey(const Key('home_hero_primary')), matching: find.text('✓ Finished')), findsOneWidget);
      expect(find.byKey(const Key('home_hero_progress')), findsNothing);
    });

    testWidgets('chips list the other titles, then All N; a chip opens its title', (tester) async {
      final a = _tracked('Alpha', idle: 0);
      final b = _tracked('Beta', idle: 2);
      final c = _tracked('Gamma', idle: 3, newSince: _now);
      await pumpHome(tester, tracking: [a, b, c]);
      expect(find.byKey(const Key('home_hero_chips')), findsOneWidget);
      expect(find.text('Beta · E6'), findsOneWidget);
      expect(find.text('Gamma · E6 new'), findsOneWidget);
      expect(find.text('All 3 ›'), findsOneWidget);
      await tester.tap(find.text('Beta · E6'));
      await tester.pumpAndSettle();
      expect(find.text('route:${Routes.title('tv', b.titleId)}'), findsOneWidget);
    });

    testWidgets('All N opens the Watching hub', (tester) async {
      await pumpHome(tester, tracking: [_tracked('Alpha', idle: 0), _tracked('Beta', idle: 2)]);
      await tester.tap(find.byKey(const Key('home_chip_all')));
      await tester.pumpAndSettle();
      expect(find.text('route:${Routes.watching}'), findsOneWidget);
    });

    testWidgets('no chip row when it is the only title', (tester) async {
      await pumpHome(tester, tracking: [_tracked('Alpha')]);
      expect(find.byKey(const Key('home_hero_chips')), findsNothing);
    });

    testWidgets('with nothing tracked it falls back to the Queue pick; ↻ needs two titles', (tester) async {
      await pumpHome(tester, queue: [queued('Dune: Part Two', id: 3, provider: 'Max')]);
      expect(tester.widget<Text>(find.byKey(const Key('home_hero_eyebrow'))).data, 'UP NEXT FROM YOUR QUEUE');
      expect(tester.widget<Text>(find.byKey(const Key('home_hero_title'))).data, 'Dune: Part Two');
      expect(tester.widget<Text>(find.byKey(const Key('home_hero_meta'))).data, 'Movie · on Max');
      expect(find.byKey(const Key('home_hero_another')), findsNothing);
      expect(find.byKey(const Key('home_hero_chips')), findsNothing);
    });

    testWidgets('↻ Another picks a different Queue title', (tester) async {
      await pumpHome(tester, queue: [for (var i = 1; i <= 3; i++) queued('Film $i', id: i)]);
      final first = tester.widget<Text>(find.byKey(const Key('home_hero_title'))).data;
      await tester.tap(find.byKey(const Key('home_hero_another')));
      await tester.pump();
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const Key('home_hero_title'))).data, isNot(first));
    });

    testWidgets('a new user is asked to log a first title', (tester) async {
      await pumpHome(tester, canon: const ProfileCanonState());
      expect(tester.widget<Text>(find.byKey(const Key('home_hero_title'))).data, 'Start your canon');
      await tester.tap(find.byKey(const Key('home_hero_primary')));
      await tester.pumpAndSettle();
      expect(find.text('route:${Routes.log}'), findsOneWidget);
    });

    testWidgets('with rankings but nothing to watch it points to Explore', (tester) async {
      await pumpHome(tester);
      expect(tester.widget<Text>(find.byKey(const Key('home_hero_title'))).data, 'Find your next watch');
      await tester.tap(find.byKey(const Key('home_hero_primary')));
      await tester.pumpAndSettle();
      expect(find.text('route:${Routes.explore}'), findsOneWidget);
    });

    testWidgets('shows a skeleton until tracking and the Queue answer', (tester) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      container = ProviderContainer(overrides: [
        trackingRepositoryProvider.overrideWithValue(FakeTrackingRepository()),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(signedInUserId: 'u-me')),
        userWatchlistProvider.overrideWith(() => SeededQueue(const [])),
        yourLevelControllerProvider.overrideWith(() => SeededLevel(sampleLevel(streak: 0))),
        challengesControllerProvider.overrideWith(() => SeededChallenges(const ChallengesOverview())),
        profileCanonProvider.overrideWith(() => _SeededCanon(const ProfileCanonState())),
        socialRepositoryProvider.overrideWithValue(FakeSocialRepository()),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: TellyTheme.dark, home: const HomeScreen()),
      ));
      expect(find.byKey(const Key('home_hero_loading')), findsOneWidget);
      expect(find.byKey(const Key('home_moves_loading')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home_hero_loading')), findsNothing);
      expect(find.byKey(const Key('home_hero')), findsOneWidget);
    });

    testWidgets('renders with light tokens', (tester) async {
      await pumpHome(tester, tracking: [_tracked('Shogun')], theme: TellyTheme.light);
      expect(find.byKey(const Key('home_hero')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('home_hero_title'))).style!.color, const Color(0xFFFFFFFF),
          reason: 'the hero text sits on a dark scrim in both themes');
    });
  });

  group('#243: SCR-21 Home — header', () {
    testWidgets('shows the title, Search and no canon or feed sections', (tester) async {
      await pumpHome(tester);
      expect(find.text('Home'), findsOneWidget);
      expect(find.byKey(const Key('home_search_button')), findsOneWidget);
      expect(find.text('YOUR CANON'), findsNothing);
      expect(find.text('FROM YOUR FRIENDS'), findsNothing);
      expect(find.byKey(const Key('home_canon_movies')), findsNothing);
    });

    testWidgets('Search opens Explore with the search field focused', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('home_search_button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('route:${Routes.explore}'), findsOneWidget);
    });

    testWidgets('the streak chip shows the weeks and opens Your level; it is hidden at 0', (tester) async {
      await pumpHome(tester, level: sampleLevel(streak: 6));
      expect(find.text('▲ 6 weeks'), findsOneWidget);
      await tester.tap(find.byKey(const Key('home_streak_chip')));
      await tester.pumpAndSettle();
      expect(find.text('route:${Routes.level}'), findsOneWidget);
    });

    testWidgets('no streak chip without a streak', (tester) async {
      await pumpHome(tester, level: sampleLevel(streak: 0));
      expect(find.byKey(const Key('home_streak_chip')), findsNothing);
    });

    testWidgets('a single week reads singular', (tester) async {
      await pumpHome(tester, level: sampleLevel(streak: 1));
      expect(find.text('▲ 1 week'), findsOneWidget);
    });
  });

  group('#243: SCR-21 Home — Your moves', () {
    final finished = TrackingItem(
      titleId: 77,
      mediaType: 'tv',
      title: 'The Bear',
      state: TrackingState.finished,
      startedAt: _now.subtract(const Duration(days: 30)),
      lastProgressAt: _now.subtract(const Duration(days: 1)),
      finishedAt: _now.subtract(const Duration(days: 1)),
    );

    testWidgets('a finished title offers Log and duel, which opens Log', (tester) async {
      await pumpHome(tester, tracking: [_tracked('Shogun'), finished]);
      expect(find.text('YOUR MOVES'), findsOneWidget);
      expect(find.text('RANK IT'), findsOneWidget);
      expect(find.text('You finished The Bear'), findsOneWidget);
      expect(find.text('Series · yesterday'), findsOneWidget);
      await tester.tap(find.text('Log and duel'));
      await tester.pumpAndSettle();
      expect(find.text('route:${Routes.log}'), findsOneWidget);
    });

    testWidgets('tapping the card does what its button does', (tester) async {
      await pumpHome(tester, tracking: [_tracked('Shogun'), finished]);
      await tester.tap(find.text('You finished The Bear'));
      await tester.pumpAndSettle();
      expect(find.text('route:${Routes.log}'), findsOneWidget);
    });

    testWidgets('the hero is not repeated as a move, and a quiet Home has no moves section', (tester) async {
      await pumpHome(tester, tracking: [_tracked('Shogun')]);
      expect(find.byKey(const Key('home_moves')), findsNothing);
    });

    testWidgets('a challenge close to done opens its page', (tester) async {
      await pumpHome(
        tester,
        tracking: [_tracked('Shogun')],
        overview: ChallengesOverview(yours: [challenge(slug: 'heist-month', name: 'Heist Month', progress: 7)]),
      );
      expect(find.text('Heist Month: 7 of 8'), findsOneWidget);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('route:${Routes.challenge('heist-month')}'), findsOneWidget);
    });

    testWidgets('a new user is offered tracking and friends', (tester) async {
      await pumpHome(tester, canon: const ProfileCanonState(), social: FakeSocialRepository());
      expect(find.text('Watching a show right now?'), findsOneWidget);
      expect(find.text('Find friends in Social'), findsOneWidget);
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(find.text('route:${Routes.userSearch}'), findsOneWidget);
    });

    testWidgets('Find it opens Explore search', (tester) async {
      await pumpHome(tester, canon: const ProfileCanonState(), social: FakeSocialRepository());
      await tester.tap(find.text('Find it'));
      await tester.pumpAndSettle();
      expect(find.textContaining('route:${Routes.explore}'), findsOneWidget);
    });

    testWidgets('shows at most four moves', (tester) async {
      final done = [
        for (var i = 0; i < 4; i++)
          TrackingItem(
            titleId: 90 + i,
            mediaType: 'tv',
            title: 'Done $i',
            state: TrackingState.finished,
            startedAt: _now.subtract(const Duration(days: 30)),
            lastProgressAt: _now.subtract(Duration(days: i + 1)),
            finishedAt: _now.subtract(Duration(days: i + 1)),
          ),
      ];
      await pumpHome(
        tester,
        tracking: [_tracked('Shogun'), ...done],
        overview: ChallengesOverview(yours: [challenge(progress: 7)]),
        queue: [queued('Dune', id: 3)],
        social: FakeSocialRepository(),
      );
      final cards = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('home_move_'));
      expect(cards, findsNWidgets(4));
    });

    testWidgets('renders with light tokens', (tester) async {
      await pumpHome(tester, tracking: [_tracked('Shogun'), finished], theme: TellyTheme.light);
      expect(find.text('You finished The Bear'), findsOneWidget);
    });
  });

  group('#243: SCR-21 Home — Friends line', () {
    testWidgets('names the friends and counts today\'s rankings', (tester) async {
      await pumpHome(tester, social: FakeSocialRepository(feed: [
        friendActivity('Maya', userId: 'a', titleId: 1),
        friendActivity('Jordan', userId: 'b', titleId: 2),
        friendActivity('Sam', userId: 'c', titleId: 3),
        friendActivity('Lee', userId: 'd', titleId: 4),
      ]));
      expect(find.text('FRIENDS'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('home_friends_title'))).data, 'Maya, Jordan and 2 others');
      expect(tester.widget<Text>(find.byKey(const Key('home_friends_meta'))).data, 'ranked 4 titles today');
    });

    testWidgets('without rankings today it shows the newest item', (tester) async {
      await pumpHome(tester, social: FakeSocialRepository(feed: [
        friendActivity('Maya', type: ActivityType.watchStarted, title: 'Severance', rank: null, age: const Duration(hours: 2)),
      ]));
      expect(tester.widget<Text>(find.byKey(const Key('home_friends_title'))).data, 'Maya');
      expect(tester.widget<Text>(find.byKey(const Key('home_friends_meta'))).data, 'started watching Severance · 2h');
    });

    testWidgets('the card and Social › open the Social tab', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('home_friends_card')));
      await tester.pumpAndSettle();
      expect(find.text('route:${Routes.social}'), findsOneWidget);
    });

    testWidgets('Social › opens the Social tab', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('home_friends_see_all')));
      await tester.pumpAndSettle();
      expect(find.text('route:${Routes.social}'), findsOneWidget);
    });

    testWidgets('is hidden when only you posted', (tester) async {
      await pumpHome(tester, social: FakeSocialRepository(feed: [friendActivity('Me', userId: 'u-me')]));
      expect(find.byKey(const Key('home_friends_line')), findsNothing);
    });

    testWidgets('is hidden when the feed is empty', (tester) async {
      await pumpHome(tester, social: FakeSocialRepository());
      expect(find.byKey(const Key('home_friends_line')), findsNothing);
    });

    testWidgets('is hidden offline with nothing loaded', (tester) async {
      await pumpHome(tester, social: _StuckSocialRepository(fail: true));
      expect(find.byKey(const Key('home_friends_line')), findsNothing);
      expect(find.byKey(const Key('home_hero')), findsOneWidget, reason: 'the rest of Home still shows');
    });

    testWidgets('renders with light tokens', (tester) async {
      await pumpHome(tester, theme: TellyTheme.light, social: FakeSocialRepository(feed: [friendActivity('Maya')]));
      expect(find.byKey(const Key('home_friends_line')), findsOneWidget);
    });
  });
}
