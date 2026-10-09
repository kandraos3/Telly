import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/features/logging/domain/title_search_result.dart';
import 'package:telly_app/features/queue/data/watchlist_repository.dart';
import 'package:telly_app/features/title_detail/data/title_detail_repository.dart';
import 'package:telly_app/features/title_detail/domain/title_detail_models.dart';
import 'package:telly_app/features/title_detail/presentation/screens/show_detail_screen.dart';
import 'package:telly_app/features/tracking/data/tracking_repository.dart';
import 'package:telly_app/features/tracking/domain/tracking_models.dart';
import 'package:telly_app/features/tracking/presentation/providers/tracking_providers.dart';

import '../../fakes/fake_watchlist_repository.dart';
import '../../helpers/router_harness.dart';
import '../../helpers/tracking_harness.dart';

/// #230: seasons as progress, the episode sheet, the spoiler guard, Watching now and the
/// drop-off line (SCR-08 §T.5–§T.7; features/11 §4.3, §4.4, §5.3–§5.5).
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  final fullSeasons = [
    SeasonInfo(number: 1, episodeCount: 2, airDate: DateTime(2000)),
    SeasonInfo(number: 2, episodeCount: 3, airDate: DateTime(2001)),
    SeasonInfo(number: 3, episodeCount: 2, airDate: DateTime(2027, 3, 1)),
  ];

  const survival = CommunitySurvivalSummary(
    completed: 60,
    watching: 20,
    dropped: 20,
    completedPct: 60,
    commonDropPoint: CommonDropPoint(season: 1, episode: 1, count: 18),
  );

  TitleDetail show({TitleSocialSummary? social = const TitleSocialSummary(survival: survival)}) => TitleDetail(
        id: 500,
        mediaType: 'tv',
        title: 'Test Show',
        status: 'Returning Series',
        communityScore: 8.1,
        availabilities: const [TitleAvailabilityDetail(platformId: 'max')],
        seasons: const [
          TitleSeasonDetail(seasonNumber: 1, name: 'Season 1', episodeCount: 2, airDate: '2000-01-01'),
          TitleSeasonDetail(seasonNumber: 2, name: 'Season 2', episodeCount: 3, airDate: '2001-01-01'),
          TitleSeasonDetail(seasonNumber: 3, name: 'Season 3', episodeCount: 2, airDate: '2027-03-01'),
        ],
        socialSummary: social,
      );

  Future<void> track({EpisodeRef? place, DateTime? newEpisodesSince}) async {
    await trackingRepositoryFor(db).start(TrackingStartRequest(
      titleId: 500,
      mediaType: 'tv',
      title: 'Test Show',
      titleStatus: 'Returning Series',
      seasons: fullSeasons,
      place: place,
    ));
    if (newEpisodesSince != null) {
      await db.trackingCacheDao.upsert(
        (await db.trackingCacheDao.getOne(500, 'tv'))!.toCompanion(true).copyWith(newEpisodesSince: Value(newEpisodesSince)),
      );
    }
  }

  Future<void> pumpPage(WidgetTester tester, TitleDetail title, {TrackingWatchers? watchers, bool watchersFail = false}) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(routerHarness(
      ShowDetailScreen(titleId: title.id, mediaType: title.mediaType, initialTitle: title),
      theme: TellyTheme.dark,
      overrides: [
        posterNetworkImagesProvider.overrideWithValue(false),
        ...trackingOverrides(db),
        titleDetailRepositoryProvider.overrideWithValue(FakeTitleDetailRepository([title])),
        titleCreditsProvider.overrideWith((ref, _) async => TitleCredits.empty),
        titleStreamingProvider.overrideWith((ref, _) async => const []),
        watchlistRepositoryProvider.overrideWithValue(FakeWatchlistRepository()),
        if (watchers != null) titleWatchersProvider.overrideWith((ref, _) async => watchers),
        if (watchersFail) titleWatchersProvider.overrideWith((ref, _) async => const TrackingWatchers()),
      ],
    ));
    await settle(tester);
  }

  Finder eyebrow(String text) =>
      find.byWidgetPredicate((w) => w is Text && w.key == const Key('tracking_eyebrow') && w.data == text);

  Future<void> tapEpisode(WidgetTester tester, int season, int episode) async {
    final row = find.byKey(Key('episode_row_${season}_$episode'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await settle(tester);
  }

  Future<void> openSeason(WidgetTester tester, String name) async {
    await tester.tap(find.text(name));
    await settle(tester);
  }

  Text stateText(WidgetTester tester, int season) => tester.widget<Text>(find.byKey(Key('season_state_$season')));

  group('seasons as progress', () {
    testWidgets('untracked, the section looks as before apart from the new header', (tester) async {
      await pumpPage(tester, show());
      expect(find.text('SEASONS'), findsOneWidget);
      expect(stateText(tester, 1).data, '2 Episodes');
      expect(find.byKey(const Key('season_ring_1')), findsNothing);
      expect(find.byKey(const Key('episode_row_1_1')), findsNothing, reason: 'no episode rows untracked');
      await unmountTree(tester);
    });

    testWidgets('rings and the trailing text follow the place', (tester) async {
      await track(place: const EpisodeRef(1, 2));
      await pumpPage(tester, show());
      expect(find.byKey(const Key('season_ring_1')), findsOneWidget);
      expect(stateText(tester, 1).data, 'watched');
      expect(stateText(tester, 2).data, 'Not started');
      expect(stateText(tester, 3).data, 'Airing · Mar 1, 2027');
      await unmountTree(tester);
    });

    testWidgets('ticks up to the place, You\'re here on the next episode, blur after it', (tester) async {
      await track(place: const EpisodeRef(1, 1));
      await pumpPage(tester, show());
      // Season 1 is expanded by default.
      expect(find.byKey(const Key('episode_row_1_1')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('episode_row_1_1')), matching: find.byIcon(Icons.check_rounded)), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('episode_row_1_2')), matching: find.text("You're here")), findsOneWidget);

      await openSeason(tester, 'Season 2');
      expect(find.byKey(const Key('spoiler_caption')), findsOneWidget, reason: 'only the first hidden row says why');
      expect(find.descendant(of: find.byKey(const Key('episode_row_2_1')), matching: find.byType(ImageFiltered)), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('episode_row_2_3')), matching: find.byType(ImageFiltered)), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('episode_row_1_2')), matching: find.byType(ImageFiltered)), findsNothing,
          reason: 'the next episode is not hidden');
      await unmountTree(tester);
    });

    testWidgets('tapping a hidden row reveals only that row and does not open the sheet', (tester) async {
      await track(place: const EpisodeRef(1, 1));
      await pumpPage(tester, show());
      await openSeason(tester, 'Season 2');

      await tapEpisode(tester, 2, 1);
      expect(find.byKey(const Key('episode_sheet')), findsNothing);
      expect(find.descendant(of: find.byKey(const Key('episode_row_2_1')), matching: find.byType(ImageFiltered)), findsNothing);
      expect(find.descendant(of: find.byKey(const Key('episode_row_2_2')), matching: find.byType(ImageFiltered)), findsOneWidget);

      await tapEpisode(tester, 2, 1);
      expect(find.byKey(const Key('episode_sheet')), findsOneWidget, reason: 'a revealed row opens its sheet');
      await unmountTree(tester);
    });

    testWidgets('untracked titles hide nothing', (tester) async {
      await pumpPage(tester, show());
      expect(find.byType(ImageFiltered), findsNothing);
      await unmountTree(tester);
    });
  });

  group('episode sheet', () {
    testWidgets('Mark as not watched on the last watched episode moves back one, without a confirm', (tester) async {
      await track(place: const EpisodeRef(1, 2));
      await pumpPage(tester, show());
      await tapEpisode(tester, 1, 2);
      expect(find.byKey(const Key('episode_unlog_button')), findsOneWidget);
      expect(find.byKey(const Key('episode_rewatched_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('episode_unlog_button')));
      await settle(tester);
      expect(find.byKey(const Key('move_back_dialog')), findsNothing);
      expect(eyebrow('● WATCHING · S1 · E2 NEXT'), findsOneWidget);
      expect(find.text('S1 · E2 marked not watched'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(eyebrow('● WATCHING · S2 · E1 NEXT'), findsOneWidget, reason: 'back where it was');
      await unmountTree(tester);
    });

    testWidgets('moving back more than one episode confirms first, and Cancel changes nothing', (tester) async {
      await track(place: const EpisodeRef(2, 2));
      await pumpPage(tester, show());
      await tapEpisode(tester, 1, 1);
      await tester.tap(find.byKey(const Key('episode_unlog_button')));
      await settle(tester);
      expect(find.text('S1 · E1 to S2 · E2 will count as not watched.'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(eyebrow('● WATCHING · S2 · E3 NEXT'), findsOneWidget);

      await tapEpisode(tester, 1, 1);
      await tester.tap(find.byKey(const Key('episode_unlog_button')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('move_back_confirm')));
      await settle(tester);
      expect(eyebrow('● WATCHING · S1 · E1 NEXT'), findsOneWidget, reason: 'back before the first episode');
      await unmountTree(tester);
    });

    testWidgets('Rewatched it logs the rewatch and keeps the place', (tester) async {
      await track(place: const EpisodeRef(1, 2));
      await pumpPage(tester, show());
      await tapEpisode(tester, 1, 1);
      await tester.tap(find.byKey(const Key('episode_rewatched_button')));
      await settle(tester);
      expect(find.text('Rewatch logged'), findsOneWidget);
      expect(find.text('✓ Watched S2 · E1'), findsOneWidget, reason: 'the place did not move');
      await unmountTree(tester);
    });

    testWidgets('Watched up to here jumps, shows the count, and Undo restores the place', (tester) async {
      await track(place: const EpisodeRef(1, 1));
      await pumpPage(tester, show());
      await openSeason(tester, 'Season 2');
      await tapEpisode(tester, 2, 1); // reveal
      await tapEpisode(tester, 2, 1); // open
      expect(find.byKey(const Key('episode_jump_count')), findsOneWidget);
      expect(find.text('Marks 2 episodes watched.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('episode_jump_button')));
      await settle(tester);
      expect(eyebrow('● WATCHING · S2 · E2 NEXT'), findsOneWidget);
      expect(find.text('S2 · E1 watched'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(eyebrow('● WATCHING · S1 · E2 NEXT'), findsOneWidget);
      await unmountTree(tester);
    });

    testWidgets('jumping to the very next episode shows no count', (tester) async {
      await track(place: const EpisodeRef(1, 1));
      await pumpPage(tester, show());
      await tapEpisode(tester, 1, 2);
      expect(find.byKey(const Key('episode_jump_button')), findsOneWidget);
      expect(find.byKey(const Key('episode_jump_count')), findsNothing);
      await unmountTree(tester);
    });

    testWidgets('an episode that has not aired cannot be marked watched', (tester) async {
      await track(place: const EpisodeRef(2, 3));
      await pumpPage(tester, show());
      await openSeason(tester, 'Season 3');
      await tapEpisode(tester, 3, 1);
      expect(find.byKey(const Key('episode_sheet')), findsOneWidget);
      expect(find.byKey(const Key('episode_jump_button')), findsNothing);
      expect(find.text("It hasn't aired yet."), findsOneWidget);
      await unmountTree(tester);
    });

    testWidgets('long-press on ✓ Watched offers Un-log for the last watched episode', (tester) async {
      await track(place: const EpisodeRef(1, 2));
      await pumpPage(tester, show());
      await tester.longPress(find.byKey(const Key('watched_episode_button')));
      await settle(tester);
      expect(find.text('Un-log S1 · E2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('unlog_last_action')));
      await settle(tester);
      expect(eyebrow('● WATCHING · S1 · E2 NEXT'), findsOneWidget);
      await unmountTree(tester);
    });

    testWidgets('there is no long-press before the first episode', (tester) async {
      await track();
      await pumpPage(tester, show());
      await tester.longPress(find.byKey(const Key('watched_episode_button')));
      await settle(tester);
      expect(find.byKey(const Key('unlog_last_action')), findsNothing);
      await unmountTree(tester);
    });
  });

  group('new season', () {
    testWidgets('a ranked title is told a re-duel is coming', (tester) async {
      await track(place: const EpisodeRef(1, 2), newEpisodesSince: DateTime(2026, 10, 8));
      await pumpPage(
        tester,
        show(social: const TitleSocialSummary(myRanking: MyTitleRanking(rankPosition: 2, calculatedScore: 9.7))),
      );
      expect(find.byKey(const Key('reduel_note')), findsOneWidget);
      expect(find.text("When you catch up we'll offer a re-duel"), findsOneWidget);
      await unmountTree(tester);
    });

    testWidgets('an unranked title gets no re-duel note', (tester) async {
      await track(place: const EpisodeRef(1, 2), newEpisodesSince: DateTime(2026, 10, 8));
      await pumpPage(tester, show());
      expect(find.byKey(const Key('reduel_note')), findsNothing);
      await unmountTree(tester);
    });
  });

  group('Watching now', () {
    const maya = TrackingWatcher(userId: 'u2', username: 'maya', displayName: 'Maya');
    const jordan = TrackingWatcher(userId: 'u3', username: 'jordan', displayName: 'Jordan');

    testWidgets('names up to three friends, opens a list, and each opens their profile', (tester) async {
      await pumpPage(tester, show(), watchers: const TrackingWatchers(watchers: [maya, jordan], total: 2));
      expect(find.text('Watching now: Maya, Jordan'), findsOneWidget);

      await tester.tap(find.byKey(const Key('watching_now_row')));
      await settle(tester);
      expect(find.byKey(const Key('watchers_sheet')), findsOneWidget);
      await tester.tap(find.byKey(const Key('watcher_maya')));
      await settle(tester);
      expect(find.text('route:${Routes.profile('maya')}'), findsOneWidget);
      await unmountTree(tester);
    });

    testWidgets('more than three become "and N others"', (tester) async {
      const many = TrackingWatchers(
        watchers: [maya, jordan, TrackingWatcher(userId: 'u4', username: 'sam', displayName: 'Sam')],
        total: 6,
      );
      await pumpPage(tester, show(), watchers: many);
      expect(find.text('Watching now: Maya, Jordan, Sam and 3 others'), findsOneWidget);
      await unmountTree(tester);
    });

    testWidgets('nobody watching, or offline, hides the row', (tester) async {
      await pumpPage(tester, show(), watchers: const TrackingWatchers());
      expect(find.byKey(const Key('watching_now_row')), findsNothing);
      await unmountTree(tester);

      await pumpPage(tester, show(), watchersFail: true);
      expect(find.byKey(const Key('watching_now_row')), findsNothing);
      await unmountTree(tester);
    });

    test('the summary never shows an episode', () {
      // The model has no place field at all (features/11 §7.1).
      expect(const TrackingWatcher(userId: 'u').toString(), isNot(contains('episode')));
    });
  });

  group('drop-off line', () {
    testWidgets('appears once the place is past the top drop point', (tester) async {
      await track(place: const EpisodeRef(1, 2));
      await pumpPage(tester, show());
      expect(find.text("You're past S1 · E1, where 18% of viewers drop it."), findsOneWidget);
      await unmountTree(tester);
    });

    testWidgets('does not appear before it, or untracked', (tester) async {
      await track();
      await pumpPage(tester, show());
      expect(find.byKey(const Key('drop_off_line')), findsNothing);
      await unmountTree(tester);
    });

    testWidgets('does not appear untracked', (tester) async {
      await pumpPage(tester, show());
      expect(find.byKey(const Key('drop_off_line')), findsNothing);
      await unmountTree(tester);
    });
  });

  test('the episode route is declared but not registered (reserved for #216)', () {
    expect(Routes.episode('tv', 1396, 2, 6), '/title/tv/1396/episode/2/6');
  });
}
