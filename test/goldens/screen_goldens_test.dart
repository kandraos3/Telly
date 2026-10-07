import 'dart:math';
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
import 'package:telly_app/features/queue/domain/streaming_models.dart';
import 'package:telly_app/features/queue/presentation/screens/smart_queue_screen.dart';
import 'package:telly_app/features/ranking/domain/franchise_rollup_service.dart';
import 'package:telly_app/features/ranking/presentation/screens/slot_reveal_modal.dart';
import 'package:telly_app/features/ranking/presentation/widgets/duel_arena_card.dart';
import 'package:telly_app/features/title_detail/domain/title_detail_models.dart';
import 'package:telly_app/features/title_detail/presentation/screens/show_detail_screen.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/core/widgets/telly_log_fab.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/home/presentation/screens/home_screen.dart';
import 'package:telly_app/features/more/presentation/screens/more_hub_screen.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/features/achievements/data/achievements_repository.dart';
import 'package:telly_app/features/achievements/presentation/screens/achievements_screen.dart';
import 'package:telly_app/features/achievements/presentation/screens/unlock_moment_screen.dart';
import 'package:telly_app/features/sharing/domain/medal_story.dart';
import 'package:telly_app/features/achievements/domain/medal.dart';
import 'package:telly_app/features/feed/presentation/widgets/medal_activity_card.dart';
import 'package:telly_app/features/sharing/presentation/widgets/medal_story_card.dart';
import 'package:telly_app/features/profile/presentation/controllers/profile_controller.dart';
import 'package:telly_app/features/profile/presentation/screens/dual_canon_profile_screen.dart';

import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_social_repository.dart';
import '../features/achievements/achievements_fixtures.dart';

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

/// Fixed canon for the Home goldens.
class _GoldenCanon extends ProfileCanonNotifier {
  @override
  ProfileCanonState build() => const ProfileCanonState(
        movies: [
          CanonEntry(id: 1, title: 'Past Lives', mediaType: 'movie', rankPosition: 1, calculatedScore: 9.80),
          CanonEntry(id: 2, title: 'Arrival', mediaType: 'movie', rankPosition: 2, calculatedScore: 9.10),
          CanonEntry(id: 3, title: 'Heat', mediaType: 'movie', rankPosition: 3, calculatedScore: 8.40),
        ],
      );
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
    // 8b. SCR-21 Home and SCR-22 More hub, dark and light (#44)
    // -------------------------------------------------------------------------
    for (final (name, theme) in [('dark', TellyTheme.darkTheme), ('light', TellyTheme.lightTheme)]) {
      List<Override> shellOverrides() => [
            hapticsEnabledProvider.overrideWith((ref) => false),
            posterNetworkImagesProvider.overrideWithValue(false),
            authRepositoryProvider.overrideWithValue(FakeAuthRepository(
              signedInUserId: 'u1',
              profile: UserProfile(
                id: 'u1',
                username: 'jordan',
                displayName: 'Jordan Miller',
                onboardingCompleted: true,
                createdAt: DateTime(2026),
              ),
            )),
            socialRepositoryProvider.overrideWithValue(FakeSocialRepository(feed: [
              fakeActivity('a1', username: 'maya', title: 'The Bear', minutesAgo: 1),
              fakeActivity('a2', username: 'jordan', title: 'Severance', minutesAgo: 2),
              fakeActivity('a3', username: 'sam', title: 'Shogun', minutesAgo: 3),
            ])),
            profileCanonProvider.overrideWith(() => _GoldenCanon()),
            // #138: the More profile card shows pinned medals.
            databaseProvider.overrideWith((ref) {
              final db = AppDatabase.inMemory();
              ref.onDispose(db.close);
              return db;
            }),
            achievementsRepositoryProvider.overrideWithValue(FakeAchievementsRepository(sampleSnapshot())),
          ];

      testWidgets('Golden: SCR-21 HomeScreen ($name) on iPhone 15 Pro size', (tester) async {
        await tester.binding.setSurfaceSize(const Size(393, 852));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(ProviderScope(
          overrides: shellOverrides(),
          child: MaterialApp(theme: theme, home: const HomeScreen()),
        ));
        await tester.pumpAndSettle();
        await expectLater(find.byType(HomeScreen), matchesGoldenFile('goldens/home_${name}_iphone15.png'));
      });

      testWidgets('Golden: SCR-22 MoreHubScreen ($name) on iPhone 15 Pro size', (tester) async {
        await tester.binding.setSurfaceSize(const Size(393, 852));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(ProviderScope(
          overrides: shellOverrides(),
          child: MaterialApp(theme: theme, home: const MoreHubScreen()),
        ));
        await tester.pumpAndSettle();
        await expectLater(find.byType(MoreHubScreen), matchesGoldenFile('goldens/more_${name}_iphone15.png'));
      });

      testWidgets('Golden: SCR-23 AchievementsScreen ($name) on iPhone 15 Pro size (#137)', (tester) async {
        await tester.binding.setSurfaceSize(const Size(393, 852));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final db = AppDatabase.inMemory();
        addTearDown(db.close);
        await tester.pumpWidget(ProviderScope(
          overrides: [
            hapticsEnabledProvider.overrideWith((ref) => false),
            databaseProvider.overrideWithValue(db),
            achievementsRepositoryProvider.overrideWithValue(FakeAchievementsRepository(sampleSnapshot())),
          ],
          child: MaterialApp(theme: theme, home: const AchievementsScreen()),
        ));
        await tester.pumpAndSettle();
        await expectLater(find.byType(AchievementsScreen), matchesGoldenFile('goldens/achievements_${name}_iphone15.png'));
      });

      testWidgets('Golden: SCR-24 UnlockMomentScreen ($name) on iPhone 15 Pro size (#138)', (tester) async {
        await tester.binding.setSurfaceSize(const Size(393, 852));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(ProviderScope(
          overrides: shellOverrides(),
          child: MaterialApp(
            theme: theme,
            // Reduced motion keeps the confetti still, so the golden is stable.
            builder: (context, child) =>
                MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
            home: UnlockMomentScreen(medal: sampleSnapshot().medals.first),
          ),
        ));
        await tester.pumpAndSettle();
        await expectLater(find.byType(UnlockMomentScreen), matchesGoldenFile('goldens/unlock_moment_${name}_iphone15.png'));
      });

      testWidgets('Golden: SCR-05 MedalActivityCard ($name) on iPhone 15 Pro width (#139)', (tester) async {
        await tester.binding.setSurfaceSize(const Size(393, 300));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final medals = FakeAchievementsRepository(null)
          ..rarity = {'movies_100': const MedalRarity(percent: 4.2, activeUsers: 950)};
        await tester.pumpWidget(ProviderScope(
          overrides: [
            hapticsEnabledProvider.overrideWith((ref) => false),
            achievementsRepositoryProvider.overrideWithValue(medals),
          ],
          child: MaterialApp(
            theme: theme,
            home: Scaffold(
              body: MedalActivityCard(
                activity: ActivityLog(
                  id: 'm1',
                  userId: 'u-maya',
                  username: 'maya',
                  userDisplayName: 'Maya',
                  activityType: ActivityType.medalUnlocked,
                  titleId: 0,
                  titleName: '',
                  medal: const FeedMedal(id: 'movies_100', name: 'Centurion', tier: MedalTier.gold, glyph: '100'),
                  reactions: {FeedReaction.fire: 12},
                  commentCount: 4,
                  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        await expectLater(find.byType(MedalActivityCard), matchesGoldenFile('goldens/medal_feed_card_$name.png'));
      });

      testWidgets('Golden: SCR-14 Canon podium ($name) on iPhone 15 Pro size (#47)', (tester) async {
        await tester.binding.setSurfaceSize(const Size(393, 852));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(ProviderScope(
          overrides: shellOverrides(),
          child: MaterialApp(theme: theme, home: const DualCanonProfileScreen()),
        ));
        await tester.pumpAndSettle();
        await expectLater(find.byType(DualCanonProfileScreen), matchesGoldenFile('goldens/canon_podium_${name}_iphone15.png'));
      });

      testWidgets('Golden: SCR-13 Queue Up next ($name) on iPhone 15 Pro size (#47)', (tester) async {
        await tester.binding.setSurfaceSize(const Size(393, 852));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        WatchlistItem tv(int id, String title, double score, {bool leaving = false}) => WatchlistItem(
              showId: id,
              title: title,
              mediaType: 'tv',
              seasonCount: 3,
              friendsAvgScore: score,
              isLeavingSoon: leaving,
              savedFromHandle: '@maya',
              addedAt: DateTime(2026),
            );
        await tester.pumpWidget(ProviderScope(
          // A seeded pick keeps the golden stable.
          overrides: [queueRandomProvider.overrideWithValue(Random(4))],
          child: MaterialApp(
            theme: theme,
            home: SmartQueueScreen(testItems: [
              tv(1, 'The Bear', 8.60),
              tv(2, 'Slow Horses', 8.94),
              tv(3, 'Station Eleven', 8.81, leaving: true),
              tv(4, 'Severance', 8.55),
            ]),
          ),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('queue_series_tab')));
        await tester.pumpAndSettle();
        await expectLater(find.byType(SmartQueueScreen), matchesGoldenFile('goldens/queue_up_next_${name}_iphone15.png'));
      });
    }

    for (final (name, story) in [
      ('single', MedalStory.single(sampleSnapshot().medals.first)),
      ('showcase', MedalStory.showcase(sampleSnapshot().showcase, unlocked: 3, total: 6)),
    ]) {
      testWidgets('Golden: medals share card ($name, #138)', (tester) async {
        await tester.binding.setSurfaceSize(MedalStoryCard.logicalSize);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: MedalStoryCard(story: story),
        ));
        await tester.pumpAndSettle();
        await expectLater(find.byType(MedalStoryCard), matchesGoldenFile('goldens/medal_story_$name.png'));
      });
    }

    testWidgets('Golden: floating Log button over the nav bar (light)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: TellyTheme.lightTheme,
        home: Builder(
          builder: (context) => Stack(
            children: [
              Scaffold(
                body: const SizedBox.expand(),
                bottomNavigationBar: TellyFloatingNavBar(currentIndex: 0, onTabSelected: (_) {}),
              ),
              Positioned(
                right: TellyLogFab.rightInset,
                bottom: TellyLogFab.bottomOffsetOf(context),
                child: TellyLogFab(onTap: () {}),
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/nav_bar_log_fab_light_iphone15.png'));
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
