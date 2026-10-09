import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/features/profile/data/graveyard_repository.dart';
import 'package:telly_app/features/profile/domain/dropped_show.dart';
import 'package:telly_app/features/profile/presentation/controllers/graveyard_controller.dart';
import 'package:telly_app/features/profile/presentation/controllers/profile_controller.dart';
import 'package:telly_app/features/profile/presentation/screens/dual_canon_profile_screen.dart';
import 'package:telly_app/features/profile/presentation/screens/tv_graveyard_screen.dart';
import 'package:telly_app/features/ranking/domain/canon_type.dart';
import 'package:telly_app/features/ranking/domain/franchise_rollup_service.dart';
import 'package:telly_app/features/title_detail/data/title_detail_repository.dart';
import 'package:telly_app/features/title_detail/domain/title_detail_models.dart';
import 'package:telly_app/features/tracking/data/tracking_repository.dart';
import 'package:telly_app/features/tracking/domain/tracking_item.dart';
import 'package:telly_app/features/tracking/domain/tracking_models.dart';
import 'package:telly_app/features/tracking/presentation/providers/tracking_providers.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_graveyard_repository.dart';
import '../../fakes/fake_tracking_repository.dart';
import '../../helpers/router_harness.dart';
import '../../helpers/tracking_harness.dart';

class _SeededCanon extends ProfileCanonNotifier {
  _SeededCanon(this.movies, this.series);
  final List<CanonEntry> movies;
  final List<CanonEntry> series;

  @override
  ProfileCanonState build() => ProfileCanonState(movies: movies, series: series);
}

/// #232: Canon's Watching strip, row tags and stats tile; the Graveyard's Revive.
void main() {
  final now = DateTime(2026, 10, 9, 12);

  CanonEntry entry(int id, String title, String media, int rank) =>
      CanonEntry(id: id, title: title, mediaType: media, rankPosition: rank, calculatedScore: 10 - rank * 0.3);

  final series = [
    entry(10, 'Succession', 'tv', 1),
    entry(11, 'The Bear', 'tv', 2),
    entry(12, 'Severance', 'tv', 3),
    entry(13, 'Andor', 'tv', 4),
    entry(14, 'Fargo', 'tv', 5),
  ];
  final movies = [entry(1, 'Interstellar', 'movie', 1), entry(2, 'Parasite', 'movie', 2)];

  TrackingItem tvItem(
    int titleId,
    String title, {
    TrackingState state = TrackingState.watching,
    DateTime? newSince,
    bool ranked = true,
    EpisodeRef next = const EpisodeRef(2, 6),
    int idle = 1,
  }) {
    return TrackingItem(
      titleId: titleId,
      mediaType: 'tv',
      title: title,
      state: state,
      startedAt: now.subtract(const Duration(days: 90)),
      lastProgressAt: now.subtract(Duration(days: idle)),
      place: const EpisodeRef(2, 5),
      newEpisodesSince: newSince,
      isRanked: ranked,
      nextEpisode: state == TrackingState.watching ? NextEpisode(ref: next) : null,
      airedTotal: 19,
      watched: 14,
    );
  }

  TrackingItem filmItem(int titleId, {bool rewatch = false}) => TrackingItem(
        titleId: titleId,
        mediaType: 'movie',
        title: 'Interstellar',
        state: TrackingState.watching,
        startedAt: now.subtract(const Duration(days: 1)),
        lastProgressAt: now.subtract(const Duration(days: 1)),
        isRewatch: rewatch,
        isRanked: true,
      );

  group('Canon', () {
    late AppDatabase db;
    late FakeTrackingRepository fake;
    setUp(() {
      db = AppDatabase.inMemory();
      fake = FakeTrackingRepository();
    });
    tearDown(() => db.close());

    Future<void> pump(
      WidgetTester tester, {
      CanonType canon = CanonType.series,
      CanonViewMode view = CanonViewMode.rankedList,
    }) async {
      tester.view.physicalSize = const Size(412, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(routerHarness(
        const DualCanonProfileScreen(),
        theme: TellyTheme.dark,
        overrides: [
          hapticsEnabledProvider.overrideWith((ref) => false),
          selectedCanonProvider.overrideWith(() => Selection(canon)),
          canonViewModeProvider.overrideWith(() => Selection(view)),
          franchiseRollupProvider.overrideWith(() => Selection(false)),
          databaseProvider.overrideWithValue(db),
          posterNetworkImagesProvider.overrideWithValue(false),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository(
            signedInUserId: 'u1',
            profile: UserProfile(id: 'u1', username: 'jordan', displayName: 'Jordan', onboardingCompleted: true, createdAt: DateTime(2026)),
          )),
          profileCanonProvider.overrideWith(() => _SeededCanon(movies, series)),
          trackingRepositoryProvider.overrideWithValue(fake),
          trackingNowProvider.overrideWithValue(() => now),
        ],
      ));
      await tester.pumpAndSettle();
    }

    group('Watching strip', () {
      testWidgets('is hidden when the canon has nothing tracked', (tester) async {
        await pump(tester);
        expect(find.byKey(const Key('canon_watching_strip')), findsNothing);
      });

      testWidgets('counts only the selected canon: series never mix with movies', (tester) async {
        fake.items = [tvItem(12, 'Severance'), tvItem(13, 'Andor', idle: 5), filmItem(1)];
        await pump(tester);
        expect(find.text('Watching 2 series'), findsOneWidget);
        expect(find.byKey(const Key('canon_watching_waiting')), findsNothing);
      });

      testWidgets('the Movies canon counts movies only', (tester) async {
        fake.items = [tvItem(12, 'Severance'), filmItem(1)];
        await pump(tester, canon: CanonType.movie);
        expect(find.text('Watching 1 movie'), findsOneWidget);
      });

      testWidgets('a second line counts finished titles waiting to be ranked', (tester) async {
        fake.items = [
          tvItem(12, 'Severance'),
          tvItem(13, 'Andor', state: TrackingState.caughtUp, ranked: false),
          tvItem(14, 'Fargo', state: TrackingState.finished, ranked: false),
        ];
        await pump(tester);
        expect(find.text('2 finished, waiting to be ranked'), findsOneWidget);
      });

      testWidgets('opens the hub on the selected canon', (tester) async {
        fake.items = [tvItem(12, 'Severance')];
        await pump(tester);
        await tester.tap(find.byKey(const Key('canon_watching_strip')));
        await tester.pumpAndSettle();
        expect(find.text('route:${Routes.watchingFiltered('tv')}'), findsOneWidget);
      });

      testWidgets('movie strip opens the Movies filter', (tester) async {
        fake.items = [filmItem(1)];
        await pump(tester, canon: CanonType.movie);
        await tester.tap(find.byKey(const Key('canon_watching_strip')));
        await tester.pumpAndSettle();
        expect(find.text('route:${Routes.watchingFiltered('movie')}'), findsOneWidget);
      });

      testWidgets('shows in every view, including 3x3', (tester) async {
        fake.items = [tvItem(12, 'Severance')];
        for (final view in CanonViewMode.values) {
          await pump(tester, view: view);
          expect(find.byKey(const Key('canon_watching_strip')), findsOneWidget, reason: view.name);
          await tester.pumpWidget(const SizedBox());
        }
      });
    });

    group('row progress tag', () {
      testWidgets('podium and Ranked rows show "▶ S2 · E6" for a title being watched', (tester) async {
        fake.items = [tvItem(12, 'Severance'), tvItem(14, 'Fargo')]; // #3 on the podium, #5 in the rows
        await pump(tester);
        expect(find.text('▶ S2 · E6'), findsNWidgets(2));
      });

      testWidgets('a title with new episodes is amber "▶ New"', (tester) async {
        fake.items = [tvItem(13, 'Andor', newSince: now)];
        await pump(tester);
        expect(find.text('▶ New'), findsOneWidget);
      });

      testWidgets('Tiers rows have it too', (tester) async {
        fake.items = [tvItem(12, 'Severance')];
        await pump(tester, view: CanonViewMode.tierView);
        expect(find.text('▶ S2 · E6'), findsOneWidget);
      });

      testWidgets('3x3 never shows it', (tester) async {
        fake.items = [tvItem(12, 'Severance')];
        await pump(tester, view: CanonViewMode.grid3x3);
        expect(find.byKey(const Key('canon_progress_tag')), findsNothing);
      });

      testWidgets('a finished or caught-up title has no tag', (tester) async {
        fake.items = [tvItem(12, 'Severance', state: TrackingState.caughtUp)];
        await pump(tester);
        expect(find.byKey(const Key('canon_progress_tag')), findsNothing);
      });

      testWidgets('a movie reads Rewatching or Watching, and a series row never gets a movie tag', (tester) async {
        fake.items = [filmItem(1, rewatch: true), filmItem(2)];
        await pump(tester, canon: CanonType.movie);
        expect(find.text('▶ Rewatching'), findsOneWidget);
        expect(find.text('▶ Watching'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());

        // Same ids on the TV side are different titles: tv:1 is not movie:1.
        fake.items = [filmItem(1)];
        await pump(tester, canon: CanonType.series);
        expect(find.byKey(const Key('canon_progress_tag')), findsNothing);
      });
    });

    group('Stats sheet tracking tile', () {
      Future<void> openStats(WidgetTester tester) async {
        await tester.tap(find.byKey(const Key('canon_stats_button')));
        await tester.pumpAndSettle();
      }

      testWidgets('shows Episodes in <year> for series', (tester) async {
        fake.weekStats = const TrackingStats(episodes: 42);
        await pump(tester);
        await openStats(tester);
        final tile = find.byKey(const Key('canon_stat_tracking'));
        expect(find.descendant(of: tile, matching: find.text('EPISODES IN 2026')), findsOneWidget);
        expect(find.descendant(of: tile, matching: find.text('42')), findsOneWidget);
      });

      testWidgets('shows Movies finished in <year> for movies', (tester) async {
        fake.weekStats = const TrackingStats(moviesFinished: 7);
        await pump(tester, canon: CanonType.movie);
        await openStats(tester);
        final tile = find.byKey(const Key('canon_stat_tracking'));
        expect(find.descendant(of: tile, matching: find.text('MOVIES FINISHED IN 2026')), findsOneWidget);
        expect(find.descendant(of: tile, matching: find.text('7')), findsOneWidget);
      });

      testWidgets('zero is a number, and offline is a dash', (tester) async {
        fake.weekStats = const TrackingStats(episodes: 0);
        await pump(tester);
        await openStats(tester);
        expect(find.descendant(of: find.byKey(const Key('canon_stat_tracking')), matching: find.text('0')), findsOneWidget);
        await tester.pumpWidget(const SizedBox());

        fake.weekStats = null;
        await pump(tester);
        await openStats(tester);
        expect(find.descendant(of: find.byKey(const Key('canon_stat_tracking')), matching: find.text('—')), findsOneWidget);
      });
    });
  });

  group('Graveyard Revive', () {
    late AppDatabase db;
    late FakeGraveyardRepository graveyard;
    setUp(() {
      db = AppDatabase.inMemory();
      graveyard = FakeGraveyardRepository();
    });
    tearDown(() => db.close());

    DroppedShow dropped({int season = 3, int? episode = 4}) => DroppedShow(
          id: 'drop-1',
          userId: 'u1',
          titleId: 63247,
          title: 'Westworld',
          releaseYear: 2016,
          droppedAtSeason: season,
          droppedAtEpisode: episode,
          reason: DropReasonTaxonomy.jumpedShark,
          createdAt: DateTime(2026, 9, 1),
        );

    const westworld = TitleDetail(
      id: 63247,
      mediaType: 'tv',
      title: 'Westworld',
      status: 'Ended',
      seasons: [
        TitleSeasonDetail(seasonNumber: 1, name: 'Season 1', episodeCount: 10, airDate: '2016-10-02'),
        TitleSeasonDetail(seasonNumber: 2, name: 'Season 2', episodeCount: 10, airDate: '2018-04-22'),
        TitleSeasonDetail(seasonNumber: 3, name: 'Season 3', episodeCount: 8, airDate: '2020-03-15'),
      ],
    );

    Future<void> pump(WidgetTester tester, {bool offline = false}) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(routerHarness(const TvGraveyardScreen(), overrides: [
        graveyardRepositoryProvider.overrideWithValue(graveyard),
        ...trackingOverrides(db),
        hapticsEnabledProvider.overrideWith((ref) => false),
        titleDetailRepositoryProvider.overrideWithValue(offline ? FakeTitleDetailRepository() : FakeTitleDetailRepository([westworld])),
      ]));
      await settle(tester);
    }

    testWidgets('starts tracking at the drop point, removes the entry and opens the title', (tester) async {
      graveyard.shows.add(dropped());
      await pump(tester);
      await tester.tap(find.byKey(const Key('graveyard_revive_drop-1')));
      await settle(tester);

      final item = await trackingRepositoryFor(db).getOne(63247, 'tv');
      expect(item, isNotNull);
      expect(item!.place, const EpisodeRef(3, 4));
      expect(item.state, TrackingState.watching);
      expect(find.text('route:${Routes.title('tv', 63247)}'), findsOneWidget);
      await unmountTree(tester);
    });

    testWidgets('the entry leaves the list', (tester) async {
      graveyard.shows.add(dropped());
      await pump(tester);
      expect(find.text('WESTWORLD'), findsOneWidget);
      final container = ProviderScope.containerOf(tester.element(find.byType(TvGraveyardScreen)));
      await tester.tap(find.byKey(const Key('graveyard_revive_drop-1')));
      await settle(tester);
      expect(container.read(graveyardControllerProvider).valueOrNull, isEmpty);
      await unmountTree(tester);
    });

    testWidgets('a drop with a season but no episode resumes at the season before its end', (tester) async {
      graveyard.shows.add(dropped(season: 3, episode: null));
      await pump(tester);
      await tester.tap(find.byKey(const Key('graveyard_revive_drop-1')));
      await settle(tester);
      expect((await trackingRepositoryFor(db).getOne(63247, 'tv'))!.place, const EpisodeRef(2, 10));
      await unmountTree(tester);
    });

    testWidgets('a season 1 drop with no episode starts from the beginning', (tester) async {
      graveyard.shows.add(dropped(season: 1, episode: null));
      await pump(tester);
      await tester.tap(find.byKey(const Key('graveyard_revive_drop-1')));
      await settle(tester);
      expect((await trackingRepositoryFor(db).getOne(63247, 'tv'))!.place, isNull);
      await unmountTree(tester);
    });

    testWidgets('offline, the seasons are unknown: it says so and changes nothing', (tester) async {
      graveyard.shows.add(dropped());
      await pump(tester, offline: true);
      await tester.tap(find.byKey(const Key('graveyard_revive_drop-1')));
      await settle(tester);
      expect(find.textContaining("Couldn't revive it right now"), findsOneWidget);
      expect(await trackingRepositoryFor(db).getOne(63247, 'tv'), isNull);
      expect(find.text('WESTWORLD'), findsOneWidget);
      await unmountTree(tester);
    });
  });
}
