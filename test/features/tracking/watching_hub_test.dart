import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/features/profile/data/graveyard_repository.dart';
import 'package:telly_app/features/profile/domain/dropped_show.dart';
import 'package:telly_app/features/profile/presentation/widgets/log_dropped_show_sheet.dart';
import 'package:telly_app/features/tracking/data/tracking_repository.dart';
import 'package:telly_app/features/tracking/domain/tracking_hub.dart';
import 'package:telly_app/features/tracking/domain/tracking_item.dart';
import 'package:telly_app/features/tracking/domain/tracking_models.dart';
import 'package:telly_app/features/tracking/presentation/providers/tracking_providers.dart';
import 'package:telly_app/features/tracking/presentation/screens/watching_hub_screen.dart';

import '../../fakes/fake_graveyard_repository.dart';
import '../../fakes/fake_tracking_repository.dart';
import '../../helpers/router_harness.dart';
import '../../helpers/tracking_harness.dart';

/// #231: `SCR-29` Watching (features/11 §2.3, §8, §9.5).
void main() {
  final now = DateTime(2026, 10, 9, 12);
  DateTime ago(int days) => now.subtract(Duration(days: days));

  var nextId = 1;
  TrackingItem series(
    String title, {
    TrackingState state = TrackingState.watching,
    int idle = 1,
    int? left = 3,
    EpisodeRef? next = const EpisodeRef(2, 6),
    EpisodeRef? place = const EpisodeRef(2, 5),
    bool ranked = false,
    DateTime? newSince,
    DateTime? finishedAt,
    int? rank,
  }) =>
      TrackingItem(
        titleId: nextId++,
        mediaType: 'tv',
        title: title,
        state: state,
        startedAt: ago(100),
        lastProgressAt: ago(idle),
        place: place,
        newEpisodesSince: newSince,
        finishedAt: finishedAt,
        isRanked: ranked,
        rankPosition: rank,
        airedTotal: left == null ? null : 19,
        watched: left == null ? null : 19 - left,
        nextEpisode: next == null ? null : NextEpisode(ref: next, name: 'Attila'),
      );

  TrackingItem movie(String title, {TrackingState state = TrackingState.watching, int idle = 1, bool ranked = false, DateTime? finishedAt}) =>
      TrackingItem(
        titleId: nextId++,
        mediaType: 'movie',
        title: title,
        state: state,
        startedAt: ago(idle),
        lastProgressAt: ago(idle),
        isRanked: ranked,
        finishedAt: finishedAt,
        runtimeMinutes: 166,
      );

  late FakeTrackingRepository fake;
  late FakeGraveyardRepository graveyard;
  setUp(() {
    fake = FakeTrackingRepository();
    graveyard = FakeGraveyardRepository();
  });

  Future<void> pump(
    WidgetTester tester, {
    WatchingFilter filter = WatchingFilter.all,
    ThemeData? theme,
    TrackingRepository? repo,
    List<Override> extra = const [],
    double width = 393,
  }) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(routerHarness(
      WatchingHubScreen(initialFilter: filter),
      theme: theme ?? TellyTheme.dark,
      overrides: [
        posterNetworkImagesProvider.overrideWithValue(false),
        trackingRepositoryProvider.overrideWithValue(repo ?? fake),
        trackingNowProvider.overrideWithValue(() => now),
        graveyardRepositoryProvider.overrideWithValue(graveyard),
        ...extra,
      ],
    ));
    await tester.pumpAndSettle();
  }

  Finder chip(String key) => find.byKey(Key('watching_filter_$key'));
  Finder inRow(TrackingItem item, Finder what) =>
      find.descendant(of: find.byKey(ValueKey('hub_${item.mediaType}_${item.titleId}')), matching: what);

  group('groups and rows', () {
    testWidgets('every group has a count header, in order, and rows say what is next', (tester) async {
      final fresh = series('Severance', newSince: ago(1), next: const EpisodeRef(3, 1), place: const EpisodeRef(2, 10));
      final shogun = series('Shogun', left: 2, next: const EpisodeRef(1, 9), place: const EpisodeRef(1, 8));
      final dune = movie('Dune: Part Two');
      final bear = series('The Bear', state: TrackingState.caughtUp, idle: 5, next: null, left: null);
      final caught = series('Andor', state: TrackingState.caughtUp, ranked: true, rank: 6, next: null, left: null);
      final stale = series('Lost', idle: 45);
      fake.items = [stale, caught, bear, dune, shogun, fresh];
      await pump(tester);

      final headers = ['NEW EPISODES · 1', 'IN PROGRESS · 2', 'FINISHED, NOT RANKED · 1', 'CAUGHT UP · 1', 'PAUSED · 1'];
      var lastY = -1.0;
      for (final h in headers) {
        final y = tester.getTopLeft(find.text(h)).dy;
        expect(y, greaterThan(lastY), reason: h);
        lastY = y;
      }

      expect(inRow(fresh, find.text('Season 3 is out')), findsOneWidget);
      expect(inRow(fresh, find.text('✓ S3E1')), findsOneWidget, reason: 'next episode starts another season');
      expect(inRow(shogun, find.text("S1 · E9 'Attila' · 2 left")), findsOneWidget);
      expect(inRow(shogun, find.text('✓ E9')), findsOneWidget);
      expect(inRow(shogun, find.byKey(const Key('hub_progress_bar'))), findsOneWidget);
      expect(inRow(dune, find.text('Movie · Started yesterday · 2 h 46')), findsOneWidget, reason: 'All prefixes movies');
      expect(inRow(dune, find.text('✓ Finished')), findsOneWidget);
      expect(inRow(dune, find.byKey(const Key('hub_progress_bar'))), findsNothing, reason: 'no bar for a film');
      expect(inRow(bear, find.text('Up to date · Oct 4')), findsOneWidget);
      expect(inRow(bear, find.text('Rank →')), findsOneWidget);
      expect(inRow(caught, find.text('Caught up')), findsOneWidget);
      expect(inRow(caught, find.text('Ranked #6 · no new season announced')), findsOneWidget);
      expect(inRow(stale, find.byKey(const Key('hub_progress_bar'))), findsOneWidget, reason: 'Paused keeps the bar');
    });

    testWidgets('tapping a row opens the title', (tester) async {
      final show = series('Shogun');
      fake.items = [show];
      await pump(tester);
      await tester.tap(find.text('Shogun'));
      await tester.pumpAndSettle();
      expect(find.text('route:${Routes.title('tv', show.titleId)}'), findsOneWidget);
    });
  });

  group('chips', () {
    testWidgets('show counts that never mix, and switch what is listed', (tester) async {
      fake.items = [series('A'), series('B'), movie('M')];
      await pump(tester);
      expect(find.text('All 3'), findsOneWidget);
      expect(find.text('Series 2'), findsOneWidget);
      expect(find.text('Movies 1'), findsOneWidget);

      await tester.tap(chip('movie'));
      await tester.pumpAndSettle();
      expect(find.text('M'), findsOneWidget);
      expect(find.text('A'), findsNothing);
      expect(find.text('Started yesterday · 2 h 46'), findsOneWidget, reason: 'no "Movie ·" prefix on the Movies chip');

      await tester.tap(chip('tv'));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
      expect(find.text('M'), findsNothing);
    });

    testWidgets('?filter= opens on a chip; Finished lists the history by finish date', (tester) async {
      fake.items = [
        series('Old', state: TrackingState.finished, finishedAt: ago(20), next: null, left: null),
        movie('New', state: TrackingState.finished, finishedAt: ago(2)),
        series('Open'),
      ];
      await pump(tester, filter: WatchingFilter.finished);
      expect(tester.widget<ChoiceChip>(chip('finished')).selected, isTrue);
      expect(find.text('Open'), findsNothing);
      expect(tester.getTopLeft(find.text('New')).dy, lessThan(tester.getTopLeft(find.text('Old')).dy));
      expect(find.text('Finished Oct 7'), findsOneWidget);
      expect(find.byKey(const Key('hub_rank_button')), findsNWidgets(2), reason: 'both are unranked');
    });
  });

  group('This week strip', () {
    testWidgets('shows episodes and time for All and Series', (tester) async {
      fake.items = [series('A')];
      fake.weekStats = const TrackingStats(episodes: 9, minutes: 470);
      await pump(tester);
      expect(find.byKey(const Key('week_count')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('week_count'))).data, '9');
      expect(find.text('episodes'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('week_time'))).data, '7 h 50');
    });

    testWidgets('the Movies chip shows movies finished and their time', (tester) async {
      fake.items = [movie('M')];
      fake.weekStats = const TrackingStats(moviesFinished: 2, minutes: 312);
      await pump(tester, filter: WatchingFilter.movie);
      expect(tester.widget<Text>(find.byKey(const Key('week_count'))).data, '2');
      expect(find.text('movies'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('week_time'))).data, '5 h 12');
    });

    testWidgets('time is hidden when a runtime is unknown, and offline shows a dash', (tester) async {
      fake.items = [series('A')];
      fake.weekStats = const TrackingStats(episodes: 3);
      await pump(tester);
      expect(find.byKey(const Key('week_time')), findsNothing);
      expect(find.byKey(const Key('week_count')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      fake.weekStats = null; // offline: the server call throws
      await pump(tester);
      expect(find.byKey(const Key('week_offline')), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
    });
  });

  group('sort', () {
    testWidgets('Fewest left reorders within the group, and the sheet marks the choice', (tester) async {
      fake.items = [series('Newest', idle: 1, left: 8), series('Closest', idle: 3, left: 1)];
      await pump(tester);
      expect(tester.getTopLeft(find.text('Newest')).dy, lessThan(tester.getTopLeft(find.text('Closest')).dy));

      await tester.tap(find.byKey(const Key('watching_sort_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('watching_sort_sheet')), findsOneWidget);
      await tester.tap(find.byKey(const Key('sort_fewest_left')));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Closest')).dy, lessThan(tester.getTopLeft(find.text('Newest')).dy));
    });
  });

  group('states', () {
    testWidgets('loading shows the skeleton', (tester) async {
      final never = _NeverLoads();
      await pump(tester, repo: never);
      expect(find.byKey(const Key('watching_skeleton')), findsOneWidget);
      expect(find.byKey(const Key('watching_empty')), findsNothing);
    });

    testWidgets('nothing tracked: empty state with Open Queue and Explore', (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('watching_empty')), findsOneWidget);
      expect(find.text("Track what you're watching. Start a show from its page or your Queue."), findsOneWidget);
      await tester.tap(find.byKey(const Key('watching_open_queue')));
      await tester.pumpAndSettle();
      expect(find.text('route:${Routes.queue}'), findsOneWidget);
    });

    testWidgets('Explore leads to Explore', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('watching_explore')));
      await tester.pumpAndSettle();
      expect(find.text('route:${Routes.explore}'), findsOneWidget);
    });

    testWidgets('an empty filter says so, and Show all goes back', (tester) async {
      fake.items = [series('A')];
      await pump(tester);
      await tester.tap(chip('movie'));
      await tester.pumpAndSettle();
      expect(find.text('No movies in progress'), findsOneWidget);
      await tester.tap(find.byKey(const Key('watching_show_all')));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('the Graveyard footer appears only with dropped shows, and opens the Graveyard', (tester) async {
      fake.items = [series('A')];
      await pump(tester);
      expect(find.byKey(const Key('watching_graveyard_row')), findsNothing);
      await tester.pumpWidget(const SizedBox());

      graveyard.shows.addAll([
        for (var i = 1; i <= 14; i++)
          DroppedShow(
            id: 'd$i',
            userId: 'u1',
            titleId: 9000 + i,
            mediaType: 'tv',
            title: 'Dropped $i',
            releaseYear: 2020,
            droppedAtSeason: 1,
            reason: DropReasonTaxonomy.pacingSlowed,
            createdAt: DateTime(2026, 10, 3),
          ),
      ]);
      await pump(tester);
      expect(find.text('Graveyard: 14 dropped shows'), findsOneWidget);
      await tester.tap(find.byKey(const Key('watching_graveyard_row')));
      await tester.pumpAndSettle();
      expect(find.text('route:${Routes.graveyard}'), findsOneWidget);
    });
  });

  group('actions', () {
    late AppDatabase db;
    late TrackingRepository real;
    setUp(() {
      db = AppDatabase.inMemory();
      real = trackingRepositoryFor(db);
    });
    tearDown(() => db.close());

    final seasons = [
      SeasonInfo(number: 1, episodeCount: 3, airDate: DateTime(2000)),
      SeasonInfo(number: 2, episodeCount: 3, airDate: DateTime(2027, 3, 1)),
    ];

    Future<TrackingItem> startShow({EpisodeRef? place, int id = 77}) => real.start(TrackingStartRequest(
          titleId: id,
          mediaType: 'tv',
          title: 'Real Show',
          titleStatus: 'Returning Series',
          seasons: seasons,
          place: place,
        ));

    testWidgets('✓ E moves the place, shows Undo, and Undo puts it back', (tester) async {
      final item = await startShow(place: const EpisodeRef(1, 1));
      await pump(tester, repo: real);
      expect(inRow(item, find.text('✓ E2')), findsOneWidget);

      await tester.tap(inRow(item, find.byKey(const Key('watched_episode_button'))));
      await settle(tester);
      expect(inRow(item, find.text('✓ E3')), findsOneWidget);
      expect(find.text('S1 · E2 watched'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(inRow(item, find.text('✓ E2')), findsOneWidget);
      await unmountTree(tester);
    });

    testWidgets('the last episode opens the finish sheet', (tester) async {
      final item = await startShow(place: const EpisodeRef(1, 2));
      await pump(tester, repo: real);
      await tester.tap(inRow(item, find.byKey(const Key('watched_episode_button'))));
      await settle(tester);
      expect(find.byKey(const Key('finish_sheet')), findsOneWidget);
      expect(find.text("You're up to date on Real Show"), findsOneWidget);
      await unmountTree(tester);
    });

    testWidgets('long-press ✓ offers Un-log for the last watched episode', (tester) async {
      final item = await startShow(place: const EpisodeRef(1, 2));
      await pump(tester, repo: real);
      await tester.longPress(inRow(item, find.byKey(const Key('watched_episode_button'))));
      await settle(tester);
      await tester.tap(find.byKey(const Key('unlog_last_action')));
      await settle(tester);
      expect(inRow(item, find.text('✓ E2')), findsOneWidget, reason: 'the place went back one episode');
      await unmountTree(tester);
    });

    testWidgets('a movie ✓ Finished opens the finish sheet', (tester) async {
      final film = await real.start(const TrackingStartRequest(titleId: 88, mediaType: 'movie', title: 'Real Film', runtimeMinutes: 100));
      await pump(tester, repo: real);
      await tester.tap(inRow(film, find.byKey(const Key('movie_finished_button'))));
      await settle(tester);
      expect(find.byKey(const Key('finish_sheet')), findsOneWidget);
      expect(find.text('You finished Real Film'), findsOneWidget);
      await unmountTree(tester);
    });

    testWidgets('swipe left on a series opens the drop sheet; on a movie it confirms Stop tracking', (tester) async {
      final show = await startShow(place: const EpisodeRef(1, 1));
      final film = await real.start(const TrackingStartRequest(titleId: 88, mediaType: 'movie', title: 'Real Film'));
      // Wider than a phone: the drop sheet's rows overflow the test font at 393 dp.
      await pump(tester, repo: real, width: 800);

      await tester.drag(find.byKey(ValueKey('hub_tv_${show.titleId}')), const Offset(-400, 0));
      await settle(tester);
      expect(find.byType(LogDroppedShowSheet), findsOneWidget);
      await tester.tapAt(const Offset(10, 10)); // dismiss the sheet: nothing is dropped
      await settle(tester);
      expect(find.text('Real Show'), findsOneWidget);

      await tester.drag(find.byKey(ValueKey('hub_movie_${film.titleId}')), const Offset(-400, 0));
      await settle(tester);
      expect(find.byKey(const Key('stop_tracking_dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('stop_tracking_confirm')));
      await settle(tester);
      expect(find.text('Real Film'), findsNothing);
      expect(find.text('Real Show'), findsOneWidget);
      await unmountTree(tester);
    });

    testWidgets('Cancel on the confirm keeps the movie', (tester) async {
      final film = await real.start(const TrackingStartRequest(titleId: 88, mediaType: 'movie', title: 'Real Film'));
      await pump(tester, repo: real);
      await tester.drag(find.byKey(ValueKey('hub_movie_${film.titleId}')), const Offset(-400, 0));
      await settle(tester);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.text('Real Film'), findsOneWidget);
      await unmountTree(tester);
    });
  });
}

/// A cache that has not answered yet.
class _NeverLoads extends FakeTrackingRepository {
  @override
  Stream<List<TrackingItem>> watchAll() => StreamController<List<TrackingItem>>().stream;
}
