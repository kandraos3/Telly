import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/features/logging/domain/title_search_result.dart';
import 'package:telly_app/features/queue/data/watchlist_repository.dart';
import 'package:telly_app/features/title_detail/data/title_detail_repository.dart';
import 'package:telly_app/features/title_detail/domain/title_detail_models.dart';
import 'package:telly_app/features/title_detail/presentation/screens/show_detail_screen.dart';
import 'package:telly_app/features/tracking/data/tracking_repository.dart';
import 'package:telly_app/features/tracking/domain/tracking_models.dart';

import '../../fakes/fake_watchlist_repository.dart';
import '../../helpers/router_harness.dart';
import '../../helpers/tracking_harness.dart';

/// #229: the title page's tracking loop (SCR-08 §T.1–§T.4b, §T.8; features/11 §4.1, §4.2, §4.5).
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());


  // The same seasons the page lists, as the repository stores them.
  final fullSeasons = [
    SeasonInfo(number: 1, episodeCount: 2, airDate: DateTime(2000)),
    SeasonInfo(number: 2, episodeCount: 3, airDate: DateTime(2001)),
    SeasonInfo(number: 3, episodeCount: 2, airDate: DateTime(2027, 3, 1)),
  ];
  // One aired episode, then an announced season: finishing S1 E1 catches you up.
  final shortSeasons = [
    SeasonInfo(number: 1, episodeCount: 1, airDate: DateTime(2000)),
    SeasonInfo(number: 2, episodeCount: 1, airDate: DateTime(2027, 3, 1)),
  ];

  const ranked = TitleSocialSummary(myRanking: MyTitleRanking(rankPosition: 2, calculatedScore: 9.72));

  // A running show: seasons 1 and 2 are out, season 3 is announced. S2 E3 is the last aired episode.
  TitleDetail show({TitleSocialSummary? social}) => TitleDetail(
        id: 500,
        mediaType: 'tv',
        title: 'Test Show',
        status: 'Returning Series',
        posterPath: '/p.jpg',
        communityScore: 8.1,
        availabilities: const [TitleAvailabilityDetail(platformId: 'max')],
        seasons: const [
          TitleSeasonDetail(seasonNumber: 1, name: 'Season 1', episodeCount: 2, airDate: '2000-01-01'),
          TitleSeasonDetail(seasonNumber: 2, name: 'Season 2', episodeCount: 3, airDate: '2001-01-01'),
          TitleSeasonDetail(seasonNumber: 3, name: 'Season 3', episodeCount: 2, airDate: '2027-03-01'),
        ],
        socialSummary: social,
      );

  const movie = TitleDetail(
    id: 600,
    mediaType: 'movie',
    title: 'Test Film',
    runtimeMinutes: 166,
    communityScore: 8.0,
    availabilities: [TitleAvailabilityDetail(platformId: 'max')],
  );

  Future<void> pumpPage(WidgetTester tester, TitleDetail title, {ThemeData? theme, WatchlistRepository? queue}) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(routerHarness(
      ShowDetailScreen(titleId: title.id, mediaType: title.mediaType, initialTitle: title),
      theme: theme ?? TellyTheme.dark,
      overrides: [
        posterNetworkImagesProvider.overrideWithValue(false),
        ...trackingOverrides(db),
        titleDetailRepositoryProvider.overrideWithValue(FakeTitleDetailRepository([title])),
        titleCreditsProvider.overrideWith((ref, _) async => TitleCredits.empty),
        titleStreamingProvider.overrideWith((ref, _) async => const []),
        watchlistRepositoryProvider.overrideWithValue(queue ?? FakeWatchlistRepository()),
      ],
    ));
    await settle(tester);
  }

  Future<void> startSeries(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('title_watch_action')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('start_tracking_button')));
    await settle(tester);
  }

  Finder eyebrow(String text) =>
      find.byWidgetPredicate((w) => w is Text && w.key == const Key('tracking_eyebrow') && w.data == text);

  group('series', () {
    testWidgets('untracked: Start watching opens the Where are you? sheet; from the beginning shows the card',
        (tester) async {
      await pumpPage(tester, show());
      expect(find.text('Start watching'), findsOneWidget);
      expect(find.byKey(const Key('tracking_eyebrow')), findsNothing);
      expect(find.byKey(const Key('tracking_progress_line')), findsNothing);
      expect(find.text('STREAMING NOW'), findsOneWidget);

      await tester.tap(find.byKey(const Key('title_watch_action')));
      await settle(tester);
      expect(find.byKey(const Key('where_are_you_sheet')), findsOneWidget);
      expect(find.text('Starting from the beginning'), findsOneWidget);
      expect(find.byKey(const Key('season_wheel')), findsNothing, reason: 'wheels only when partway');

      await tester.tap(find.byKey(const Key('start_tracking_button')));
      await settle(tester);

      expect(find.text('Watching'), findsOneWidget, reason: 'the slot');
      expect(eyebrow('● WATCHING · S1 · E1 NEXT'), findsOneWidget);
      expect(find.byKey(const Key('tracking_progress_line')), findsOneWidget);
      expect(find.byKey(const Key('next_episode_card')), findsOneWidget);
      expect(find.text('STREAMING NOW'), findsNothing, reason: 'the card replaces it while watching');
      expect(find.text('✓ Watched E1'), findsOneWidget);
      await unmountTree(tester);
    });

    testWidgets('partway: the wheels pick the last episode watched, with a caption', (tester) async {
      await pumpPage(tester, show());
      await tester.tap(find.byKey(const Key('title_watch_action')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('where_partway')));
      await settle(tester);
      expect(find.byKey(const Key('season_wheel')), findsOneWidget);
      expect(find.text('Season 1 · Episode 1'), findsOneWidget);

      await tester.drag(find.byKey(const Key('season_wheel')), const Offset(0, -36));
      await settle(tester);
      expect(find.text('Season 2 · Episode 1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('start_tracking_button')));
      await settle(tester);
      expect(eyebrow('● WATCHING · S2 · E2 NEXT'), findsOneWidget);
      await unmountTree(tester);
    });

    testWidgets('a ranked series presets partway at its last aired episode', (tester) async {
      await pumpPage(tester, show(social: ranked));
      await tester.tap(find.byKey(const Key('title_watch_action')));
      await settle(tester);
      expect(find.byKey(const Key('season_wheel')), findsOneWidget, reason: 'partway is preselected');
      expect(find.text('Season 2 · Episode 3'), findsOneWidget);
      await tester.tap(find.byKey(const Key('start_tracking_button')));
      await settle(tester);
      expect(find.text('Up to date'), findsOneWidget);
      await unmountTree(tester);
    });

    testWidgets('dismissing the sheet starts nothing', (tester) async {
      await pumpPage(tester, show());
      await tester.tap(find.byKey(const Key('title_watch_action')));
      await settle(tester);
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);
      expect(find.text('Start watching'), findsOneWidget);
      expect(find.byKey(const Key('next_episode_card')), findsNothing);
      await unmountTree(tester);
    });

    testWidgets('✓ Watched moves the place, shows the Undo tray, and Undo puts it back', (tester) async {
      await pumpPage(tester, show());
      await startSeries(tester);

      await tester.tap(find.byKey(const Key('watched_episode_button')));
      await settle(tester);
      expect(eyebrow('● WATCHING · S1 · E2 NEXT'), findsOneWidget);
      expect(find.text('S1 · E1 watched'), findsOneWidget);
      expect(find.text('✓ Watched E2'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(eyebrow('● WATCHING · S1 · E1 NEXT'), findsOneWidget);
      expect(find.byKey(const Key('finish_sheet')), findsNothing);
      await unmountTree(tester);
    });

    testWidgets('across a season boundary the button names the season', (tester) async {
      await pumpPage(tester, show());
      await tester.tap(find.byKey(const Key('title_watch_action')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('where_partway')));
      await settle(tester);
      await tester.drag(find.byKey(const Key('episode_wheel_1')), const Offset(0, -36));
      await settle(tester);
      expect(find.text('Season 1 · Episode 2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('start_tracking_button')));
      await settle(tester);
      expect(find.text('✓ Watched S2 · E1'), findsOneWidget);
      await unmountTree(tester);
    });

    testWidgets('starting already up to date opens no sheet by itself', (tester) async {
      await pumpPage(tester, show());
      await tester.tap(find.byKey(const Key('title_watch_action')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('where_partway')));
      await settle(tester);
      await tester.drag(find.byKey(const Key('season_wheel')), const Offset(0, -36));
      await settle(tester);
      await tester.drag(find.byKey(const Key('episode_wheel_2')), const Offset(0, -72));
      await settle(tester);
      expect(find.text('Season 2 · Episode 3'), findsOneWidget);
      await tester.tap(find.byKey(const Key('start_tracking_button')));
      await settle(tester);
      // Started already up to date: nothing is next, and no finish sheet opened by itself.
      expect(find.byKey(const Key('finish_sheet')), findsNothing);
      expect(find.text("You're caught up"), findsOneWidget);
      await unmountTree(tester);
    });

    testWidgets('catching up opens the finish sheet: unranked offers Log and duel, Later closes it', (tester) async {
      final repo = trackingRepositoryFor(db);
      await repo.start(TrackingStartRequest(
        titleId: 500,
        mediaType: 'tv',
        title: 'Test Show',
        titleStatus: 'Returning Series',
        seasons: fullSeasons,
        place: const EpisodeRef(2, 2),
      ));
      await pumpPage(tester, show());
      expect(find.text('✓ Watched E3'), findsOneWidget);

      await tester.tap(find.byKey(const Key('watched_episode_button')));
      await settle(tester);

      expect(find.byKey(const Key('finish_sheet')), findsOneWidget);
      expect(find.text("You're up to date on Test Show"), findsOneWidget);
      expect(find.byKey(const Key('finish_log_button')), findsOneWidget);
      expect(find.byKey(const Key('finish_reduel_button')), findsNothing);

      await tester.tap(find.byKey(const Key('finish_later_button')));
      await settle(tester);
      expect(find.byKey(const Key('finish_sheet')), findsNothing);
      expect(eyebrow('● UP TO DATE'), findsOneWidget);
      expect(find.text("You're caught up"), findsOneWidget);
      expect(find.text('Season 3 · Mar 1, 2027'), findsOneWidget);
      expect(find.byKey(const Key('caught_up_rank_button')), findsOneWidget);
      expect(find.text('STREAMING NOW'), findsOneWidget, reason: 'streaming returns below the caught-up card');
      await unmountTree(tester);
    });

    testWidgets('Log and duel opens /log', (tester) async {
      final repo = trackingRepositoryFor(db);
      await repo.start(TrackingStartRequest(
        titleId: 500,
        mediaType: 'tv',
        title: 'Test Show',
        titleStatus: 'Returning Series',
        seasons: shortSeasons,
      ));
      await pumpPage(tester, show());
      await tester.tap(find.byKey(const Key('watched_episode_button')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('finish_log_button')));
      await settle(tester);
      expect(find.text('route:/log'), findsOneWidget);
      await unmountTree(tester);
    });

    testWidgets('a ranked title gets Re-duel and Keep my rank', (tester) async {
      final repo = trackingRepositoryFor(db);
      await repo.start(TrackingStartRequest(
        titleId: 500,
        mediaType: 'tv',
        title: 'Test Show',
        titleStatus: 'Returning Series',
        seasons: shortSeasons,
      ));
      await pumpPage(tester, show(social: ranked));
      await tester.tap(find.byKey(const Key('watched_episode_button')));
      await settle(tester);
      expect(find.byKey(const Key('finish_rank_line')), findsOneWidget);
      expect(find.byKey(const Key('finish_reduel_button')), findsOneWidget);
      expect(find.byKey(const Key('finish_log_button')), findsNothing);
      await tester.tap(find.byKey(const Key('finish_keep_button')));
      await settle(tester);
      expect(find.byKey(const Key('finish_sheet')), findsNothing);
      await unmountTree(tester);
    });

    testWidgets('starting removes the title from the Queue, and Undo restores both', (tester) async {
      final queue = FakeWatchlistRepository();
      await queue.add(titleId: 500, mediaType: 'tv', title: 'Test Show');
      await pumpPage(tester, show(), queue: queue);
      await startSeries(tester);

      expect(await queue.isInWatchlist(500, 'tv'), isFalse);
      expect(find.text('Watching Test Show'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(await queue.isInWatchlist(500, 'tv'), isTrue);
      expect(find.text('Start watching'), findsOneWidget);
      await unmountTree(tester);
    });

    testWidgets('the overflow menu stops tracking after a confirm, and offers Drop it for a series', (tester) async {
      await pumpPage(tester, show());
      expect(find.byKey(const Key('tracking_overflow_menu')), findsNothing);
      await startSeries(tester);

      await tester.tap(find.byKey(const Key('tracking_overflow_menu')));
      await settle(tester);
      expect(find.text('Drop it'), findsOneWidget);
      await tester.tap(find.text('Stop tracking'));
      await settle(tester);
      expect(find.text('Your progress is removed. Your rank, if any, stays.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('stop_tracking_confirm')));
      await settle(tester);

      expect(find.text('Start watching'), findsOneWidget);
      expect(find.byKey(const Key('next_episode_card')), findsNothing);
      await unmountTree(tester);
    });

    testWidgets('a new season turns the eyebrow amber and labels the card', (tester) async {
      final repo = trackingRepositoryFor(db);
      await repo.start(TrackingStartRequest(
        titleId: 500,
        mediaType: 'tv',
        title: 'Test Show',
        titleStatus: 'Returning Series',
        seasons: fullSeasons,
        place: const EpisodeRef(1, 2),
      ));
      await db.trackingCacheDao.upsert(
        (await db.trackingCacheDao.getOne(500, 'tv'))!.toCompanion(true).copyWith(
              newEpisodesSince: Value(DateTime(2026, 10, 8)),
            ),
      );
      await pumpPage(tester, show());
      expect(eyebrow('● NEW SEASON'), findsOneWidget);
      expect(find.text('NEW'), findsOneWidget);
      expect(find.text('Season 2 is out'), findsOneWidget);
      final text = tester.widget<Text>(find.byKey(const Key('tracking_eyebrow')));
      expect(text.style!.color, TellyColors.warmAmber);
      await unmountTree(tester);
    });
  });

  group('themes', () {
    testWidgets('the eyebrow is lime on dark and the AA lime on light', (tester) async {
      final repo = trackingRepositoryFor(db);
      await repo.start(TrackingStartRequest(
        titleId: 500,
        mediaType: 'tv',
        title: 'Test Show',
        titleStatus: 'Returning Series',
        seasons: shortSeasons,
      ));
      await pumpPage(tester, show());
      expect(tester.widget<Text>(find.byKey(const Key('tracking_eyebrow'))).style!.color, TellyColors.phosphorLime);
      await unmountTree(tester);

      await pumpPage(tester, show(), theme: TellyTheme.light);
      expect(tester.widget<Text>(find.byKey(const Key('tracking_eyebrow'))).style!.color, TellyColors.lightPhosphorLime);
      await unmountTree(tester);
    });
  });

  group('movies', () {
    testWidgets('start at once with Undo; ✓ Finished opens the sheet preselecting First-time watch', (tester) async {
      await pumpPage(tester, movie);
      expect(find.text('Start watching'), findsOneWidget);

      await tester.tap(find.byKey(const Key('title_watch_action')));
      await settle(tester);
      expect(find.byKey(const Key('where_are_you_sheet')), findsNothing, reason: 'movies have no place');
      expect(find.byKey(const Key('movie_watching_card')), findsOneWidget);
      expect(find.text('Watching Test Film'), findsOneWidget);
      expect(eyebrow('● WATCHING'), findsOneWidget);
      expect(find.byKey(const Key('tracking_progress_line')), findsNothing, reason: 'no bar for a film');
      expect(find.textContaining('2 h 46'), findsOneWidget);
      expect(find.byKey(const Key('tracking_overflow_menu')), findsOneWidget);

      await tester.tap(find.byKey(const Key('movie_finished_button')));
      await settle(tester);
      expect(find.byKey(const Key('finish_sheet')), findsOneWidget);
      expect(find.text('You finished Test Film'), findsOneWidget);
      final first = find.byKey(const Key('finish_status_firstTime'));
      expect(find.descendant(of: first, matching: find.byIcon(Icons.radio_button_checked)), findsOneWidget);

      await tester.tap(find.byKey(const Key('finish_later_button')));
      await settle(tester);
      expect(find.text('You finished it · Oct 9'), findsOneWidget);
      expect(find.byKey(const Key('caught_up_rank_button')), findsOneWidget);
      expect(find.text('Finished'), findsWidgets);
      await unmountTree(tester);
    });

    testWidgets('Watch again resets the card, and the next finish preselects Rewatch', (tester) async {
      await pumpPage(tester, movie);
      await tester.tap(find.byKey(const Key('title_watch_action')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('movie_finished_button')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('finish_later_button')));
      await settle(tester);

      await tester.tap(find.byKey(const Key('title_watch_action')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('watch_again_action')));
      await settle(tester);
      expect(find.byKey(const Key('movie_finished_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('movie_finished_button')));
      await settle(tester);
      final rewatch = find.byKey(const Key('finish_status_rewatch'));
      expect(find.descendant(of: rewatch, matching: find.byIcon(Icons.radio_button_checked)), findsOneWidget);
      await unmountTree(tester);
    });

    testWidgets('a movie cannot be dropped', (tester) async {
      await pumpPage(tester, movie);
      await tester.tap(find.byKey(const Key('title_watch_action')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('tracking_overflow_menu')));
      await settle(tester);
      expect(find.text('Drop it'), findsNothing);
      expect(find.text('Stop tracking'), findsOneWidget);
      await unmountTree(tester);
    });
  });
}
