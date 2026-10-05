import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/features/profile/data/profile_repository.dart';
import 'package:telly_app/features/profile/presentation/controllers/profile_controller.dart';
import 'package:telly_app/features/profile/presentation/screens/dual_canon_profile_screen.dart';
import 'package:telly_app/features/profile/presentation/widgets/poster_grid_view.dart';
import 'package:telly_app/features/profile/presentation/widgets/ranked_canon_list.dart';
import 'package:telly_app/features/profile/presentation/widgets/tier_view_list.dart';
import 'package:telly_app/features/profile/presentation/widgets/top_showcase_row.dart';
import 'package:telly_app/features/ranking/domain/canon_type.dart';
import 'package:telly_app/features/ranking/domain/franchise_rollup_service.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_profile_repository.dart';

/// Fixed canon for screen tests: these fixtures carry franchise metadata Drift does not store.
class SeededProfileCanon extends ProfileCanonNotifier {
  SeededProfileCanon(this.movies, this.series);
  final List<CanonEntry> movies;
  final List<CanonEntry> series;

  @override
  ProfileCanonState build() => ProfileCanonState(movies: movies, series: series);
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
  }) {
    return ProviderScope(
      overrides: [
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
      ],
      child: const MaterialApp(
        home: DualCanonProfileScreen(),
      ),
    );
  }

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

      final row = tester.widget<TopShowcaseRow>(find.byType(TopShowcaseRow));
      expect(row.topEntries.map((e) => e.title), ['Dune: Part Two', 'Interstellar', 'Parasite']);
    });
  });
  group('FE-206: SCR-14 Dual-Canon Profile Header & Segmented Pill Switcher Tests', () {
    testWidgets('renders profile avatar, handle, bio, and cultural stats', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile_handle_text')), findsOneWidget);
      expect(find.text('@jordan'), findsOneWidget);
      expect(find.byKey(const Key('profile_display_name_text')), findsOneWidget);
      expect(find.text('Jordan Miller'), findsOneWidget);
      expect(find.byKey(const Key('profile_bio_text')), findsOneWidget);
      expect(find.byKey(const Key('profile_stats_summary_text')), findsOneWidget);
      expect(find.text('3 Movies  •  5 Series'), findsOneWidget, reason: 'real counts, no invented hours');
    });

    testWidgets('defaults to Movie Canon and displays movie titles', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();

      expect(find.text('🎬 Movies (3)'), findsOneWidget);
      expect(find.text('📺 TV Shows (5)'), findsOneWidget);
      expect(find.text('Includes anime'), findsOneWidget);

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

  group('FE-207: Three Canon View Modes Tests', () {
    testWidgets('mode 1 renders RankedCanonList by default', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen(
        initialViewMode: CanonViewMode.rankedList,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(RankedCanonList), findsOneWidget);
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

      final tierBtn = find.byKey(const Key('view_mode_tier_button'));
      await tester.tap(tierBtn);
      await tester.pumpAndSettle();

      expect(find.byType(TierViewList), findsOneWidget);
      expect(find.byType(RankedCanonList), findsNothing);
      expect(find.text('👑 GOD TIER (9.20 – 10.00)'), findsOneWidget);
    });

    testWidgets('mode 3 switcher switches to PosterGridView', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen(
        initialViewMode: CanonViewMode.rankedList,
      ));
      await tester.pumpAndSettle();

      final gridBtn = find.byKey(const Key('view_mode_grid_button'));
      await tester.tap(gridBtn);
      await tester.pumpAndSettle();

      expect(find.byType(PosterGridView), findsOneWidget);
      expect(find.byType(RankedCanonList), findsNothing);
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

      // Tap View Options button to open sheet
      final optionsBtn = find.byKey(const Key('canon_options_button'));
      expect(optionsBtn, findsOneWidget);
      await tester.tap(optionsBtn);
      await tester.pumpAndSettle();

      // Tap Franchise Rollup toggle inside options sheet
      final rollupToggle = find.byKey(const Key('franchise_rollup_toggle'));
      expect(rollupToggle, findsOneWidget);
      await tester.tap(rollupToggle);
      await tester.pumpAndSettle();

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

      final rowFinder = find.byKey(const ValueKey('ranked_row_2'));
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
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Parasite ranked row should be removed from view
      expect(find.byKey(const ValueKey('ranked_row_2')), findsNothing);
    });
  });

  group('FE-209: Reorderable Drag-and-Drop Manual Re-Indexing Tests', () {
    testWidgets('drag handles are rendered for each ranked row', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen(
        initialViewMode: CanonViewMode.rankedList,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('drag_handle_1')), findsOneWidget);
      expect(find.byKey(const Key('drag_handle_2')), findsOneWidget);
      expect(find.byKey(const Key('drag_handle_3')), findsOneWidget);
    });

    testWidgets('moving an entry re-ranks and re-scores the list immediately', (tester) async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          profileCanonProvider.overrideWith(() => SeededProfileCanon(sampleMovies, sampleSeries)),
        ],
      );
      addTearDown(container.dispose);

      // Move Dune (id 3, rank 3) to #1
      await container.read(profileCanonProvider.notifier).moveTitle(canon: CanonType.movie, titleId: 3, newRank: 1);

      final movies = container.read(profileCanonProvider).movies;
      expect(movies[0].title, equals('Dune: Part Two'));
      expect(movies[0].rankPosition, equals(1));
      expect(movies[0].calculatedScore, equals(10.00));
      expect(movies[1].title, equals('Interstellar'));
      expect(movies[1].rankPosition, equals(2));
      expect(movies[2].title, equals('Parasite'));
      expect(movies[2].rankPosition, equals(3));
    });
  });
}
