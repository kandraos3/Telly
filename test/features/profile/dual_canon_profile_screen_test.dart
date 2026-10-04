import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/features/profile/presentation/controllers/profile_controller.dart';
import 'package:telly_app/features/profile/presentation/screens/dual_canon_profile_screen.dart';
import 'package:telly_app/features/profile/presentation/widgets/poster_grid_view.dart';
import 'package:telly_app/features/profile/presentation/widgets/ranked_canon_list.dart';
import 'package:telly_app/features/profile/presentation/widgets/tier_view_list.dart';
import 'package:telly_app/features/ranking/domain/canon_type.dart';
import 'package:telly_app/features/ranking/domain/franchise_rollup_service.dart';

void main() {
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
  }) {
    return ProviderScope(
      overrides: [
        hapticsEnabledProvider.overrideWith((ref) => false),
        selectedCanonProvider.overrideWith((ref) => initialCanon),
        canonViewModeProvider.overrideWith((ref) => initialViewMode),
        franchiseRollupProvider.overrideWith((ref) => initialRollup),
        profileCanonProvider.overrideWith((ref) => ProfileCanonNotifier(
              initialMovies: movies ?? sampleMovies,
              initialSeries: series ?? sampleSeries,
            )),
      ],
      child: const MaterialApp(
        home: DualCanonProfileScreen(),
      ),
    );
  }

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
    });

    testWidgets('defaults to Movie Canon and displays movie titles', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();

      expect(find.text('🎬 Movie Canon (3)'), findsOneWidget);
      expect(find.text('📺 Series & Anime (5)'), findsOneWidget);

      expect(find.text('Interstellar'), findsWidgets);
      expect(find.text('Parasite'), findsWidgets);
      expect(find.text('Dune: Part Two'), findsWidgets);

      // Verify series items are omitted from Movie Canon
      expect(find.text('Succession'), findsNothing);
      expect(find.text('The Bear'), findsNothing);
    });

    testWidgets('tapping Series & Anime tab updates list to series titles only', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();

      // Tap Series Canon tab
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

      // Tap Franchise Rollup toggle
      final rollupToggle = find.byKey(const Key('franchise_rollup_toggle'));
      expect(rollupToggle, findsOneWidget);
      await tester.tap(rollupToggle);
      await tester.pumpAndSettle();

      // After rollup: seasons folded into one 'Attack on Titan' entry (ALGO-602)
      expect(find.text('Attack on Titan'), findsOneWidget);
      expect(find.text('Includes: S1, S2'), findsOneWidget);
      expect(find.text('Attack on Titan Season 1'), findsNothing);
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

    testWidgets('reordering entries updates ranks and recalculates scores', (tester) async {
      final container = ProviderContainer(
        overrides: [
          profileCanonProvider.overrideWith((ref) => ProfileCanonNotifier(
                initialMovies: sampleMovies,
                initialSeries: sampleSeries,
              )),
        ],
      );

      final notifier = container.read(profileCanonProvider.notifier);

      // Reorder Dune (index 2, rank 3) to top (index 0, rank 1)
      await notifier.reorder(
        canon: CanonType.movie,
        oldIndex: 2,
        newIndex: 0,
      );

      final state = container.read(profileCanonProvider);
      final movies = state.movies;

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
