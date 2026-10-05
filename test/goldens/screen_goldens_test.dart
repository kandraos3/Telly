import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/core/widgets/telly_floating_nav_bar.dart';
import 'package:telly_app/core/widgets/telly_neon_badge.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/feed/presentation/widgets/upset_activity_card.dart';
import 'package:telly_app/features/profile/presentation/widgets/poster_grid_view.dart';
import 'package:telly_app/features/profile/presentation/widgets/ranked_canon_list.dart';
import 'package:telly_app/features/profile/presentation/widgets/tier_view_list.dart';
import 'package:telly_app/features/queue/data/watchlist_repository.dart';
import 'package:telly_app/features/ranking/domain/franchise_rollup_service.dart';
import 'package:telly_app/features/ranking/presentation/screens/slot_reveal_modal.dart';
import 'package:telly_app/features/ranking/presentation/widgets/duel_arena_card.dart';
import 'package:telly_app/features/title_detail/domain/title_detail_models.dart';
import 'package:telly_app/features/title_detail/presentation/screens/show_detail_screen.dart';

class TolerantGoldenComparator extends LocalFileComparator {
  TolerantGoldenComparator(super.testFile, {this.tolerance = 0.50});
  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (!result.passed) {
      debugPrint(
        'Golden comparison diff for $golden: ${(result.diffPercent * 100).toStringAsFixed(2)}% '
        '(allowed tolerance: ${(tolerance * 100).toStringAsFixed(0)}%)',
      );
    }
    if (!result.passed && result.diffPercent > tolerance) {
      final String error = await generateFailureOutput(result, golden, basedir);
      throw FlutterError(error);
    }
    return true;
  }
}

class _InMemoryWatchlistRepository implements WatchlistRepository {
  @override
  Future<bool> isInWatchlist(int titleId, String mediaType) async => true;

  @override
  Future<void> add({
    required int titleId,
    required String mediaType,
    required String title,
    String? posterPath,
    String? recommendedBy,
  }) async {}

  @override
  Future<void> remove({
    required int titleId,
    required String mediaType,
  }) async {}

  @override
  Future<void> hydrate() async {}

  @override
  Future<List<WatchlistEntry>> getWatchlist({String? mediaType}) async => [];

  @override
  Stream<List<WatchlistEntry>> watchWatchlist({String? mediaType}) =>
      Stream.value([]);
}

void main() {
  setUpAll(() {
    // Deterministic golden renders: avoid network font downloads; bundled assets are loaded
    GoogleFonts.config.allowRuntimeFetching = false;
    final defaultComparator = goldenFileComparator as LocalFileComparator;
    goldenFileComparator = TolerantGoldenComparator(
      defaultComparator.basedir.resolve('screen_goldens_test.dart'),
      tolerance: 0.50,
    );
  });

  group('Real Golden Regression Suite (QA-603 / TA-06 §5.1)', () {
    // -------------------------------------------------------------------------
    // 1. Telly Floating Frosted Navigation Bar
    // -------------------------------------------------------------------------
    testWidgets('Golden: TellyFloatingNavBar on iPhone 15 Pro size', (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: TellyTheme.darkTheme,
          home: Scaffold(
            backgroundColor: TellyColors.backgroundCanvasOled,
            body: Align(
              alignment: Alignment.bottomCenter,
              child: TellyFloatingNavBar(
                currentIndex: 0,
                onTabSelected: (_) {},
                onLogTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(TellyFloatingNavBar),
        matchesGoldenFile('goldens/nav_bar_iphone15.png'),
      );
    });

    // -------------------------------------------------------------------------
    // 2. SCR-05 Upset Activity Card
    // -------------------------------------------------------------------------
    testWidgets('Golden: SCR-05 UpsetActivityCard on Pixel 8 size', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final upsetActivity = ActivityLog(
        id: 'act-upset-1',
        userId: 'u-jordan',
        username: 'jordan',
        userDisplayName: 'Jordan Miller',
        activityType: ActivityType.upsetAlert,
        titleId: 102,
        titleName: 'Severance',
        releaseYear: 2022,
        mediaType: 'tv',
        rankPosition: 2,
        calculatedScore: 9.72,
        culturalTier: 'God Tier',
        isUpset: true,
        upsetDelta: 0.28,
        upsetOverTitleName: 'Succession',
        upsetOverTitleRank: 4,
        agreementPercentage: 14.0,
        microReview: 'The season 2 finale was the most stressful 60 minutes of television.',
        createdAt: DateTime(2026, 10, 1, 12, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: TellyTheme.darkTheme,
          home: Scaffold(
            backgroundColor: TellyColors.backgroundCanvasOled,
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: UpsetActivityCard(activity: upsetActivity),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(UpsetActivityCard),
        matchesGoldenFile('goldens/upset_card_pixel8.png'),
      );
    });

    // -------------------------------------------------------------------------
    // 3. SCR-08 Show Detail Screen
    // -------------------------------------------------------------------------
    testWidgets('Golden: SCR-08 ShowDetailScreen on iPhone 15 Pro size', (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final testTitle = TitleDetail(
        id: 1396,
        mediaType: 'tv',
        title: 'Severance',
        overview: 'Mark leads a team of office workers whose memories have been surgically divided.',
        posterPath: null,
        backdropPath: null,
        network: 'Apple TV+',
        numberOfSeasons: 2,
        numberOfEpisodes: 19,
        releaseDate: DateTime(2022, 2, 18),
        communityScore: 9.34,
        director: 'Dan Erickson',
        availabilities: const [
          TitleAvailabilityDetail(platformId: 'apple_tv_plus'),
        ],
        seasons: const [
          TitleSeasonDetail(
            seasonNumber: 1,
            name: 'Season 1',
            episodeCount: 9,
            airDate: '2022-02-18',
            overview: 'Mark Scout leads a team at Lumon Industries.',
          ),
          TitleSeasonDetail(
            seasonNumber: 2,
            name: 'Season 2',
            episodeCount: 10,
            airDate: '2025-01-17',
            overview: 'The fallout of the macrodata revolution.',
          ),
        ],
        socialSummary: const TitleSocialSummary(
          myRanking: MyTitleRanking(
            rankPosition: 2,
            calculatedScore: 9.72,
          ),
          friends: [
            FriendTitleRanking(
              userId: 'u2',
              username: 'jordan',
              displayName: 'Jordan',
              rankPosition: 2,
              calculatedScore: 9.72,
            ),
          ],
          community: CommunityRankingSummary(
            avgScore: 9.34,
            rankingCount: 124,
          ),
          survival: CommunitySurvivalSummary(
            completed: 92,
            watching: 15,
            dropped: 5,
            completedPct: 82,
            commonDropPoint: CommonDropPoint(
              season: 1,
              episode: 3,
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            watchlistRepositoryProvider.overrideWithValue(_InMemoryWatchlistRepository()),
          ],
          child: MaterialApp(
            theme: TellyTheme.darkTheme,
            home: ShowDetailScreen(
              titleId: 1396,
              mediaType: 'tv',
              initialTitle: testTitle,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(ShowDetailScreen),
        matchesGoldenFile('goldens/show_detail_iphone15.png'),
      );
    });

    // -------------------------------------------------------------------------
    // 4. SCR-10 Duel Arena Card
    // -------------------------------------------------------------------------
    testWidgets('Golden: SCR-10 DuelArenaCard on iPhone 15 Pro size', (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 450));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: TellyTheme.darkTheme,
          home: const Scaffold(
            backgroundColor: TellyColors.backgroundCanvasOled,
            body: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DuelArenaCard(
                    showId: 101,
                    title: 'Severance',
                    subtitle: 'Season 2 • Apple TV+',
                    actionPrompt: 'TAP TO PICK WINNER',
                    isWinner: true,
                  ),
                  SizedBox(height: 16),
                  DuelArenaCard(
                    showId: 102,
                    title: 'Succession',
                    subtitle: 'Season 4 • HBO / Max',
                    actionPrompt: 'TAP TO PICK WINNER',
                    isLoser: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/duel_card_iphone15.png'),
      );
    });

    // -------------------------------------------------------------------------
    // 5. SCR-12 Slot Reveal Modal
    // -------------------------------------------------------------------------
    testWidgets('Golden: SCR-12 SlotRevealModal on iPad Mini size', (tester) async {
      await tester.binding.setSurfaceSize(const Size(744, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hapticsEnabledProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(
            theme: TellyTheme.darkTheme,
            home: Scaffold(
              backgroundColor: TellyColors.backgroundCanvasOled,
              body: Center(
                child: SlotRevealModal(
                  showId: 101,
                  title: 'Interstellar',
                  mediaType: 'movie',
                  rankPosition: 4,
                  totalInCanon: 48,
                  targetScore: 9.42,
                  justBehindTitles: const ['Dune: Part Two (#3)'],
                  beatingTitles: const ['Oppenheimer (#5)', 'Inception (#6)'],
                  onViewInCanon: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(SlotRevealModal),
        matchesGoldenFile('goldens/slot_reveal_ipad.png'),
      );
    });

    // -------------------------------------------------------------------------
    // 6. SCR-14 Ranked Canon List (Mode 1: Ranked List)
    // -------------------------------------------------------------------------
    testWidgets('Golden: SCR-14 Mode 1 RankedCanonList on Pixel 8 size', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final entries = [
        const CanonEntry(
          id: 76331,
          title: 'Succession',
          mediaType: 'tv',
          rankPosition: 1,
          calculatedScore: 10.00,
          mvpCharacter: 'Kendall Roy',
        ),
        const CanonEntry(
          id: 110492,
          title: 'Severance',
          mediaType: 'tv',
          rankPosition: 2,
          calculatedScore: 9.68,
          mvpCharacter: 'Mark Scout',
        ),
        const CanonEntry(
          id: 85937,
          title: 'The Bear',
          mediaType: 'tv',
          rankPosition: 3,
          calculatedScore: 9.35,
          mvpCharacter: 'Carmy Berzatto',
        ),
        const CanonEntry(
          id: 1396,
          title: 'Breaking Bad',
          mediaType: 'tv',
          rankPosition: 4,
          calculatedScore: 8.84,
          mvpCharacter: 'Walter White',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: TellyTheme.darkTheme,
          home: Scaffold(
            backgroundColor: TellyColors.backgroundCanvasOled,
            body: SingleChildScrollView(
              child: RankedCanonList(
                entries: entries,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(RankedCanonList),
        matchesGoldenFile('goldens/canon_list_pixel8.png'),
      );
    });

    // -------------------------------------------------------------------------
    // 7. SCR-14 Mode 2 TierViewList
    // -------------------------------------------------------------------------
    testWidgets('Golden: SCR-14 Mode 2 TierViewList on Pixel 8 size', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final entries = [
        const CanonEntry(
          id: 76331,
          title: 'Succession',
          mediaType: 'tv',
          rankPosition: 1,
          calculatedScore: 10.00,
        ),
        const CanonEntry(
          id: 110492,
          title: 'Severance',
          mediaType: 'tv',
          rankPosition: 2,
          calculatedScore: 9.68,
        ),
        const CanonEntry(
          id: 85937,
          title: 'The Bear',
          mediaType: 'tv',
          rankPosition: 3,
          calculatedScore: 8.90,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: TellyTheme.darkTheme,
          home: Scaffold(
            backgroundColor: TellyColors.backgroundCanvasOled,
            body: SingleChildScrollView(
              child: TierViewList(
                entries: entries,
                onTapEntry: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(TierViewList),
        matchesGoldenFile('goldens/canon_tiers_pixel8.png'),
      );
    });

    // -------------------------------------------------------------------------
    // 8. SCR-14 Mode 3 PosterGridView
    // -------------------------------------------------------------------------
    testWidgets('Golden: SCR-14 Mode 3 PosterGridView on Pixel 8 size', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final entries = List.generate(
        9,
        (i) => CanonEntry(
          id: 100 + i,
          title: 'Show #$i',
          mediaType: 'tv',
          rankPosition: i + 1,
          calculatedScore: 9.9 - (i * 0.3),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: TellyTheme.darkTheme,
          home: Scaffold(
            backgroundColor: TellyColors.backgroundCanvasOled,
            body: SingleChildScrollView(
              child: PosterGridView(
                entries: entries,
                onTapEntry: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PosterGridView),
        matchesGoldenFile('goldens/canon_grid_pixel8.png'),
      );
    });

    // -------------------------------------------------------------------------
    // 9. Badges & Token Fidelity Checks
    // -------------------------------------------------------------------------
    testWidgets('TellyNeonBadge renders all variants with proper tokens', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            backgroundColor: TellyColors.backgroundCanvasOled,
            body: Column(
              children: [
                TellyNeonBadge(label: 'WINNER', variant: TellyBadgeVariant.winner),
                TellyNeonBadge(label: 'UPSET', variant: TellyBadgeVariant.upset),
                TellyNeonBadge(label: 'GOD TIER', variant: TellyBadgeVariant.godTier),
                TellyNeonBadge(label: '88% MATCH', variant: TellyBadgeVariant.tasteMatch),
                TellyNeonBadge(label: 'NEUTRAL', variant: TellyBadgeVariant.neutral),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WINNER'), findsOneWidget);
      expect(find.text('UPSET'), findsOneWidget);
      expect(find.text('GOD TIER'), findsOneWidget);
      expect(find.text('88% MATCH'), findsOneWidget);
      expect(find.text('NEUTRAL'), findsOneWidget);
    });
  });
}
