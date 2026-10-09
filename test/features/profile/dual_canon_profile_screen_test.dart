import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/features/profile/presentation/widgets/canon_stats_panel.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/widgets/telly_canon_switcher.dart';
import 'package:telly_app/features/profile/data/profile_repository.dart';
import 'package:telly_app/features/profile/data/profile_share_service.dart';
import 'package:telly_app/features/profile/domain/canon_stats.dart';
import 'package:telly_app/features/profile/presentation/controllers/profile_controller.dart';
import 'package:telly_app/features/profile/presentation/screens/dual_canon_profile_screen.dart';
import 'package:telly_app/features/profile/presentation/widgets/canon_podium.dart';
import 'package:telly_app/features/profile/presentation/widgets/poster_grid_view.dart';
import 'package:telly_app/features/profile/presentation/widgets/ranked_canon_list.dart';
import 'package:telly_app/features/profile/presentation/widgets/tier_view_list.dart';
import 'package:telly_app/features/profile/presentation/widgets/top_showcase_row.dart';
import 'package:telly_app/features/ranking/domain/canon_type.dart';
import 'package:telly_app/features/ranking/domain/franchise_rollup_service.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_profile_repository.dart';
import '../../helpers/router_harness.dart';

/// Fixed canon for screen tests: these fixtures carry franchise metadata Drift does not store.
class SeededProfileCanon extends ProfileCanonNotifier {
  SeededProfileCanon(this.movies, this.series);
  final List<CanonEntry> movies;
  final List<CanonEntry> series;

  @override
  ProfileCanonState build() => ProfileCanonState(movies: movies, series: series);
}

/// Opens a header sheet (#47): Stats (`canon_stats_button`) or View (`canon_view_button`).
Future<void> openSheet(WidgetTester tester, String buttonKey) async {
  await tester.tap(find.byKey(Key(buttonKey)));
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  final sampleMovies = [
    const CanonEntry(
      id: 1,
      title: 'Interstellar',
      mediaType: 'movie',
      rankPosition: 1,
      calculatedScore: 10.00,
      mvpCharacter: 'Matthew McConaughey as Cooper',
    ),
    const CanonEntry(
      id: 2,
      title: 'Parasite',
      mediaType: 'movie',
      rankPosition: 2,
      calculatedScore: 9.72,
      mvpCharacter: 'Song Kang-ho as Kim Ki-taek',
    ),
    const CanonEntry(
      id: 3,
      title: 'Dune: Part Two',
      mediaType: 'movie',
      rankPosition: 3,
      calculatedScore: 9.45,
      mvpCharacter: 'Timothée Chalamet as Paul Atreides',
    ),
  ];

  final sampleSeries = [
    const CanonEntry(
      id: 10,
      title: 'Succession',
      mediaType: 'tv',
      rankPosition: 1,
      calculatedScore: 10.00,
      mvpCharacter: 'Jeremy Strong as Kendall Roy',
    ),
    const CanonEntry(
      id: 11,
      title: 'The Bear',
      mediaType: 'tv',
      rankPosition: 2,
      calculatedScore: 9.65,
      mvpCharacter: 'Jeremy Allen White as Carmy',
    ),
    const CanonEntry(
      id: 12,
      title: 'Severance',
      mediaType: 'tv',
      rankPosition: 3,
      calculatedScore: 9.30,
      mvpCharacter: 'Adam Scott as Mark Scout',
    ),
    // Franchise anime seasons for testing FE-208
    const CanonEntry(
      id: 20,
      title: 'Attack on Titan Season 1',
      mediaType: 'tv',
      rankPosition: 4,
      calculatedScore: 9.10,
      isAnime: true,
      franchiseId: 'aot',
      franchiseName: 'Attack on Titan',
      seasonNumber: 1,
    ),
    const CanonEntry(
      id: 21,
      title: 'Attack on Titan Season 2',
      mediaType: 'tv',
      rankPosition: 5,
      calculatedScore: 8.90,
      isAnime: true,
      franchiseId: 'aot',
      franchiseName: 'Attack on Titan',
      seasonNumber: 2,
    ),
  ];

  Widget buildTestableProfileScreen({
    List<CanonEntry>? movies,
    List<CanonEntry>? series,
    CanonType initialCanon = CanonType.movie,
    CanonViewMode initialViewMode = CanonViewMode.rankedList,
    bool initialRollup = false,
    FakeProfileRepository? profiles,
    ProfileShareService? share,
    bool routed = false,
  }) {
    final overrides = [
        hapticsEnabledProvider.overrideWith((ref) => false),
        selectedCanonProvider.overrideWith(() => Selection(initialCanon)),
        canonViewModeProvider.overrideWith(() => Selection(initialViewMode)),
        franchiseRollupProvider.overrideWith(() => Selection(initialRollup)),
        databaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(
          signedInUserId: 'u-jordan',
          profile: UserProfile(
            id: 'u-jordan',
            username: 'jordan',
            displayName: 'Jordan Miller',
            bio: 'Cinema purist. Severance truther.',
            onboardingCompleted: true,
            createdAt: DateTime(2026),
          ),
        )),
        profileCanonProvider.overrideWith(() => SeededProfileCanon(movies ?? sampleMovies, series ?? sampleSeries)),
        if (profiles != null) profileRepositoryProvider.overrideWithValue(profiles),
        if (share != null) profileShareServiceProvider.overrideWithValue(share),
      ];
    if (routed) return routerHarness(const DualCanonProfileScreen(), overrides: overrides);
    return ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        home: DualCanonProfileScreen(),
      ),
    );
  }

  group('FE-PROFILE-03: SCR-14 per-canon stats dashboard', () {
    FakeProfileRepository statsRepo() => FakeProfileRepository()
      ..stats['movie'] = const CanonStats(
        mediaType: 'movie',
        totalTitles: 3,
        totalMinutes: 470,
        topGenre: StatLeader(name: 'Science Fiction', count: 2, percent: 67),
        topCreator: StatLeader(name: 'Christopher Nolan', count: 2),
      )
      ..stats['tv'] = const CanonStats(
        mediaType: 'tv',
        totalTitles: 5,
        totalMinutes: 15000,
        hoursEstimated: true,
        topGenre: StatLeader(name: 'Drama', count: 4, percent: 80),
        topCreator: StatLeader(name: 'HBO', count: 3),
      );

    String tile(WidgetTester tester, String key) => tester
        .widgetList<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)))
        .map((t) => t.data)
        .join(' | ');

    testWidgets('shows hours, top genre and top director for the movie canon', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen(profiles: statsRepo()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('canon_stats_panel')), findsNothing, reason: 'stats live in the sheet (#47)');
      await openSheet(tester, 'canon_stats_button');

      expect(find.text('MOVIE STATS'), findsOneWidget);
      expect(tile(tester, 'canon_stat_titles'), contains('3'));
      expect(tile(tester, 'canon_stat_hours'), contains('8h'));
      expect(tile(tester, 'canon_stat_genre'), allOf(contains('Science Fiction'), contains('67% of your rankings')));
      expect(tile(tester, 'canon_stat_creator'), allOf(contains('Top Director'.toUpperCase()), contains('Christopher Nolan'), contains('2 films')));
    });

    testWidgets('switching to TV Shows recalculates the stats for the series canon', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen(profiles: statsRepo()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('series_canon_tab')));
      await tester.pumpAndSettle();
      await openSheet(tester, 'canon_stats_button');

      expect(find.text('TV STATS'), findsOneWidget);
      expect(tile(tester, 'canon_stat_hours'), allOf(contains('≈250h'), contains('from episode counts')));
      expect(tile(tester, 'canon_stat_genre'), contains('Drama'));
      expect(tile(tester, 'canon_stat_creator'), allOf(contains('Top Network'.toUpperCase()), contains('HBO'), contains('3 shows')));
    });

    testWidgets('detail lines use the theme accent, so they read on light (#47, #54)', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: TellyTheme.light,
        home: const Scaffold(
          body: CanonStatsPanel(
            stats: CanonStats(
              mediaType: 'movie',
              totalTitles: 3,
              totalMinutes: 470,
              topGenre: StatLeader(name: 'Science Fiction', count: 2, percent: 67),
            ),
            isMovie: true,
            localTitleCount: 3,
          ),
        ),
      ));
      expect(tester.widget<Text>(find.text('67% of your rankings')).style!.color, TellyColors.lightPhosphorLime);
    });

    testWidgets('offline falls back to the local title count and dashes', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen(profiles: statsRepo()..failReads = true));
      await tester.pumpAndSettle();
      await openSheet(tester, 'canon_stats_button');

      expect(tile(tester, 'canon_stat_titles'), contains('3'));
      expect(tile(tester, 'canon_stat_hours'), contains('—'));
    });
  });

  group('FE-PROFILE-02: SCR-14 top bar, avatar and share', () {
    testWidgets('header reads "Canon" with Stats, View and Share, in that order (FE-HEADER-01, #47)', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(find.byKey(const Key('screen_header_title'))).data, 'Rankings');
      expect(find.text('Profile'), findsNothing);
      double x(String key) => tester.getCenter(find.byKey(Key(key))).dx;
      expect(x('canon_stats_button'), lessThan(x('canon_view_button')));
      expect(x('canon_view_button'), lessThan(x('profile_share_button')));
      // Settings moved to the More hub and Squads to Social.
      expect(find.byKey(const Key('profile_squads_button')), findsNothing);
      expect(find.byKey(const Key('profile_settings_button')), findsNothing);
      expect(find.textContaining('📺'), findsNothing, reason: 'old TV emoji removed');
    });

    testWidgets('the page leads with the switcher: no profile card or in-page controls (#47)', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile_avatar_button')), findsNothing, reason: 'the profile card lives in More');
      expect(find.text('Jordan Miller'), findsNothing);
      expect(find.byType(TopShowcaseRow), findsNothing);
      expect(find.byKey(const Key('canon_options_button')), findsNothing);
      expect(find.byKey(const Key('view_mode_ranked_button')), findsNothing, reason: 'views moved into the View sheet');
      // The podium starts 12 dp under the switcher.
      final switcherBottom = tester.getBottomLeft(find.byType(TellyCanonSwitcher)).dy;
      expect(tester.getTopLeft(find.byType(CanonPodium)).dy - switcherBottom, closeTo(12, 0.5));
    });

    testWidgets('tapping Share opens the share sheet with the handle and top titles', (tester) async {
      final sent = <ShareParams>[];
      await tester.pumpWidget(buildTestableProfileScreen(
        share: ProfileShareService(share: (p) async => sent.add(p), shareUrl: 'https://example.test/telly'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('profile_share_button')));
      await tester.pump();

      expect(sent, hasLength(1));
      final text = sent.single.text!;
      expect(text, contains('Jordan Miller (@jordan)'));
      expect(text, contains('1. Interstellar'));
      expect(text, contains('Top TV shows'));
      expect(text, contains('https://example.test/telly'));
    });
  });

  group('FE-608: SCR-14 pinned Top 3 showcase', () {
    testWidgets('pinned titles of the shown canon lead the showcase, then top ranks fill in', (tester) async {
      final profiles = FakeProfileRepository()
        ..profiles['jordan'] = const PublicProfile(
          id: 'u-jordan',
          username: 'jordan',
          displayName: 'Jordan Miller',
          // (12, tv) belongs to the other canon and must not leak into the movie row.
          pinnedShowcase: [(titleId: 12, mediaType: 'tv'), (titleId: 3, mediaType: 'movie')],
        );
      await tester.pumpWidget(buildTestableProfileScreen(profiles: profiles));
      await tester.pumpAndSettle();
      await openSheet(tester, 'canon_stats_button');

      final row = tester.widget<TopShowcaseRow>(find.byType(TopShowcaseRow));
      expect(row.topEntries.map((e) => e.title), ['Dune: Part Two', 'Interstellar', 'Parasite']);
    });

    testWidgets('tapping a showcase title closes the sheet and opens the title', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen(routed: true));
      await tester.pumpAndSettle();
      await openSheet(tester, 'canon_stats_button');

      await tester.tap(find.descendant(of: find.byType(TopShowcaseRow), matching: find.text('Parasite')).first);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('canon_stats_sheet')), findsNothing);
      expect(find.text('route:${Routes.title('movie', 2)}'), findsOneWidget);
    });
  });
  group('FE-206: SCR-14 Dual-Canon Profile Header & Segmented Pill Switcher Tests', () {
    testWidgets('defaults to Movie Canon and displays movie titles', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();

      expect(find.text('Movies 3'), findsOneWidget);
      expect(find.text('TV Shows 5'), findsOneWidget);

      expect(find.text('Interstellar'), findsWidgets);
      expect(find.text('Parasite'), findsWidgets);
      expect(find.text('Dune: Part Two'), findsWidgets);

      // Verify series items are omitted from Movie Canon
      expect(find.text('Succession'), findsNothing);
      expect(find.text('The Bear'), findsNothing);
    });

    testWidgets('tapping TV Shows tab updates list to series titles only', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();

      // Tap TV Shows tab
      final seriesTab = find.byKey(const Key('series_canon_tab'));
      await tester.tap(seriesTab);
      await tester.pumpAndSettle();

      expect(find.text('Succession'), findsWidgets);
      expect(find.text('The Bear'), findsWidgets);
      expect(find.text('Severance'), findsWidgets);

      // Verify movie items are omitted from Series Canon
      expect(find.text('Interstellar'), findsNothing);
      expect(find.text('Parasite'), findsNothing);
    });

    testWidgets('FE-PROFILE-01: horizontal swipe switches between Movies and TV Shows', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();

      // Initially in Movies
      expect(find.text('Interstellar'), findsWidgets);
      expect(find.text('Succession'), findsNothing);

      // Swipe left (drag to negative offset with high velocity)
      await tester.fling(find.byType(SingleChildScrollView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      // Now in TV Shows
      expect(find.text('Succession'), findsWidgets);
      expect(find.text('Interstellar'), findsNothing);

      // Swipe right (drag to positive offset with high velocity)
      await tester.fling(find.byType(SingleChildScrollView), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();

      // Now back in Movies
      expect(find.text('Interstellar'), findsWidgets);
      expect(find.text('Succession'), findsNothing);
    });
  });

  group('#132: SCR-14 Ranked podium', () {
    CanonEntry movie(int rank) => CanonEntry(
          id: 100 + rank,
          title: 'Film $rank',
          mediaType: 'movie',
          rankPosition: rank,
          calculatedScore: 10.0 - rank * 0.2,
        );
    List<CanonEntry> movies(int n) => [for (var r = 1; r <= n; r++) movie(r)];

    testWidgets('0 titles: the empty state and no podium', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen(movies: const []));
      await tester.pumpAndSettle();
      expect(find.byType(CanonPodium), findsNothing);
      expect(find.textContaining('No ranked titles'), findsOneWidget);
    });

    for (final n in [1, 2, 3]) {
      testWidgets('$n title(s): only those cards, in their columns, and no rows', (tester) async {
        await tester.pumpWidget(buildTestableProfileScreen(movies: movies(n)));
        await tester.pumpAndSettle();
        for (var r = 1; r <= 3; r++) {
          expect(find.byKey(ValueKey('podium_card_${100 + r}')), r <= n ? findsOneWidget : findsNothing);
        }
        expect(find.byType(RankedCanonList), findsNothing);
      });
    }

    testWidgets('#1 is the widest and tallest card, the cards share a bottom edge', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen(movies: movies(3)));
      await tester.pumpAndSettle();
      Rect card(int r) => tester.getRect(find.byKey(ValueKey('podium_card_${100 + r}')));
      expect(card(1).width, greaterThan(card(2).width));
      expect(card(2).width, closeTo(card(3).width, 0.5));
      expect(card(1).height, greaterThan(card(2).height));
      expect(card(1).bottom, closeTo(card(2).bottom, 0.5));
      expect(card(1).left, lessThan(card(2).left));
      expect(card(2).left, lessThan(card(3).left));
    });

    testWidgets('10+ titles: rows start at #4 with no repeat of #1-#3', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen(movies: movies(12)));
      await tester.pumpAndSettle();
      final list = tester.widget<RankedCanonList>(find.byType(RankedCanonList));
      expect(list.entries.first.rankPosition, 4);
      expect(list.entries, hasLength(9));
      expect(find.byKey(const ValueKey('ranked_row_101')), findsNothing);
      expect(find.byKey(const ValueKey('ranked_row_104')), findsOneWidget);
    });

    testWidgets('tapping a podium card opens the title', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen(routed: true));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('podium_card_1')));
      await tester.pumpAndSettle();
      expect(find.text('route:${Routes.title('movie', 1)}'), findsOneWidget);
    });

    testWidgets('Tiers and 3x3 have no podium', (tester) async {
      for (final mode in [CanonViewMode.tierView, CanonViewMode.grid3x3]) {
        await tester.pumpWidget(buildTestableProfileScreen(movies: movies(5), initialViewMode: mode));
        await tester.pumpAndSettle();
        expect(find.byType(CanonPodium), findsNothing, reason: '$mode');
      }
    });

    testWidgets('each canon has its own podium: no film on the TV podium', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('series_canon_tab')));
      await tester.pumpAndSettle();

      final podium = find.byType(CanonPodium);
      expect(tester.widget<CanonPodium>(podium).entries.every((e) => e.mediaType == 'tv'), isTrue);
      expect(find.descendant(of: podium, matching: find.text('Interstellar')), findsNothing);
    });

    testWidgets('cards are labelled for screen readers with rank, title and score', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('#1, Interstellar, 10.00'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('FE-207: Three Canon View Modes Tests', () {
    testWidgets('mode 1 renders the podium by default (three titles: no rows below it)', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen(
        initialViewMode: CanonViewMode.rankedList,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(CanonPodium), findsOneWidget);
      expect(find.byType(RankedCanonList), findsNothing);
      expect(find.byType(TierViewList), findsNothing);
      expect(find.byType(PosterGridView), findsNothing);

      // Verify rank numbers and score pills
      expect(find.text('#1'), findsWidgets);
      expect(find.text('#2'), findsWidgets);
      expect(find.text('#3'), findsWidgets);
      expect(find.text('10.00'), findsWidgets);
    });

    testWidgets('mode 2 switcher switches to TierViewList', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen(
        initialViewMode: CanonViewMode.rankedList,
      ));
      await tester.pumpAndSettle();

      await openSheet(tester, 'canon_view_button');
      await tester.tap(find.byKey(const Key('view_mode_tier_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('canon_view_sheet')), findsNothing, reason: 'choosing a view closes the sheet');
      expect(find.byTooltip('View: Tiers'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('canon_view_button')), matching: find.byIcon(Icons.view_agenda_rounded)),
          findsOneWidget);

      expect(find.byType(TierViewList), findsOneWidget);
      expect(find.byType(RankedCanonList), findsNothing);
      expect(find.text('👑 GOD TIER (9.20 – 10.00)'), findsOneWidget);
    });

    testWidgets('mode 3 switcher switches to PosterGridView', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen(
        initialViewMode: CanonViewMode.rankedList,
      ));
      await tester.pumpAndSettle();

      await openSheet(tester, 'canon_view_button');
      await tester.tap(find.byKey(const Key('view_mode_grid_button')));
      await tester.pumpAndSettle();

      expect(find.byType(PosterGridView), findsOneWidget);
      expect(find.byType(RankedCanonList), findsNothing);
      expect(find.byTooltip('View: 3x3'), findsOneWidget);
    });

    testWidgets('the View sheet marks the current view and hides the rollup on Movies', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen(initialViewMode: CanonViewMode.rankedList));
      await tester.pumpAndSettle();
      await openSheet(tester, 'canon_view_button');

      expect(find.text('VIEW'), findsOneWidget);
      expect(tester.widget<ListTile>(find.byKey(const Key('view_mode_ranked_button'))).selected, isTrue);
      expect(tester.widget<ListTile>(find.byKey(const Key('view_mode_tier_button'))).selected, isFalse);
      expect(find.byKey(const Key('franchise_rollup_toggle')), findsNothing);
      expect(find.text('SERIES ONLY'), findsNothing);
    });
  });

  group('FE-208: Anime Franchise Rollup UI Integration Tests', () {
    testWidgets('toggling franchise rollup combines anime seasons into master entry', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen(
        initialCanon: CanonType.series,
        initialRollup: false,
      ));
      await tester.pumpAndSettle();

      // Before rollup: individual seasons visible
      expect(find.text('Attack on Titan Season 1'), findsOneWidget);
      expect(find.text('Attack on Titan Season 2'), findsOneWidget);

      // The rollup lives in the View sheet's Series-only section (#47).
      await openSheet(tester, 'canon_view_button');
      expect(find.text('SERIES ONLY'), findsOneWidget);
      final rollupToggle = find.byKey(const Key('franchise_rollup_toggle'));
      expect(rollupToggle, findsOneWidget);
      await tester.tap(rollupToggle);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('canon_view_sheet')), findsOneWidget, reason: 'toggling keeps the sheet open');

      // Dismiss bottom sheet
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // After rollup: seasons folded into one 'Attack on Titan' entry (ALGO-602)
      expect(find.text('Attack on Titan'), findsOneWidget);
      expect(find.text('Includes: S1, S2'), findsOneWidget);
      expect(find.text('Attack on Titan Season 1'), findsNothing);
    });
  });

  group('FE-CANON-01: Delete Title Action and Recalculation', () {
    testWidgets('deleting an entry re-ranks and re-scores remaining list immediately', (tester) async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          profileCanonProvider.overrideWith(() => SeededProfileCanon(sampleMovies, sampleSeries)),
        ],
      );
      addTearDown(container.dispose);

      // Initially 3 movies: Interstellar (#1), Parasite (#2), Dune: Part Two (#3)
      expect(container.read(profileCanonProvider).movies.length, equals(3));

      // Delete Interstellar (id 1)
      await container.read(profileCanonProvider.notifier).deleteTitle(canon: CanonType.movie, titleId: 1);

      final movies = container.read(profileCanonProvider).movies;
      expect(movies.length, equals(2));
      // Parasite is promoted to #1
      expect(movies[0].title, equals('Parasite'));
      expect(movies[0].rankPosition, equals(1));
      expect(movies[0].calculatedScore, equals(10.00));
      // Dune is now #2
      expect(movies[1].title, equals('Dune: Part Two'));
      expect(movies[1].rankPosition, equals(2));
    });

    testWidgets('long press entry opens options with remove action and confirmation dialog', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen(
        initialCanon: CanonType.movie,
      ));
      await tester.pumpAndSettle();

      final rowFinder = find.byKey(const ValueKey('podium_card_2'));
      expect(rowFinder, findsOneWidget);
      await tester.ensureVisible(rowFinder);
      await tester.pumpAndSettle();

      // Long press on Parasite row
      await tester.longPress(rowFinder);
      await tester.pumpAndSettle();

      // Verify actions sheet shown with Remove from List
      final removeAction = find.byKey(const Key('remove_title_action'));
      expect(removeAction, findsOneWidget);
      await tester.tap(removeAction);
      await tester.pumpAndSettle();

      // Verify confirmation dialog
      expect(find.text('Remove from List?'), findsOneWidget);
      final confirmBtn = find.byKey(const Key('confirm_delete_title_button'));
      expect(confirmBtn, findsOneWidget);
      await tester.ensureVisible(confirmBtn);
      await tester.pumpAndSettle();
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Parasite ranked row should be removed from view
      expect(find.byKey(const ValueKey('podium_card_2')), findsNothing);
    });
  });

  group('FE-ALGO-02: RankingEngine Arbitrary Drag-and-Drop Removed in Favor of Re-dueling', () {
    testWidgets('manual drag handles are removed from ranked rows', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen(
        initialViewMode: CanonViewMode.rankedList,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('drag_handle_1')), findsNothing);
      expect(find.byKey(const Key('drag_handle_2')), findsNothing);
      expect(find.byKey(const Key('drag_handle_3')), findsNothing);
    });

    testWidgets('long press entry offers Re-duel & Recalibrate Rank action', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen(
        initialCanon: CanonType.movie,
      ));
      await tester.pumpAndSettle();

      final rowFinder = find.byKey(const ValueKey('podium_card_1'));
      await tester.ensureVisible(rowFinder);
      await tester.pumpAndSettle();
      await tester.longPress(rowFinder);
      await tester.pumpAndSettle();

      expect(find.text('Re-duel & Recalibrate Rank'), findsOneWidget);
      expect(find.text('Play comparison duels to organically calibrate position'), findsOneWidget);
    });
  });

  group('FE-CANON-02: Full Poster Grid Display Without 9-Item Limit', () {
    testWidgets('renders all entries beyond 9 items with rank badge and score chip', (tester) async {
      final twelveMovies = List.generate(
        12,
        (i) => CanonEntry(
          id: 100 + i,
          title: 'Movie ${i + 1}',
          mediaType: 'movie',
          rankPosition: i + 1,
          calculatedScore: (10.0 - (i * 0.4)).clamp(1.0, 10.0),
        ),
      );

      await tester.pumpWidget(buildTestableProfileScreen(
        movies: twelveMovies,
        initialViewMode: CanonViewMode.grid3x3,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(PosterGridView), findsOneWidget);

      // Verify all 12 items exist in the grid
      for (int i = 0; i < 12; i++) {
        expect(find.byKey(Key('grid_poster_${100 + i}')), findsOneWidget);
        expect(find.byKey(Key('grid_rank_badge_${100 + i}')), findsOneWidget);
      }

      // Verify #1 rank badge has distinct styling/text in poster grid
      expect(
        find.descendant(of: find.byType(PosterGridView), matching: find.text('#1')),
        findsOneWidget,
      );
      expect(find.text('#12'), findsOneWidget);
      // Verify score chip format
      expect(find.text('10.00'), findsWidgets);
    });
  });
}
