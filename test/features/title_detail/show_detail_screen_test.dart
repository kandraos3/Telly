import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/features/queue/data/watchlist_repository.dart';
import 'package:telly_app/features/title_detail/domain/title_detail_models.dart';
import 'package:telly_app/features/title_detail/presentation/screens/show_detail_screen.dart';

class InMemoryWatchlistRepository implements WatchlistRepository {
  final Set<String> _items = {};

  @override
  Future<bool> isInWatchlist(int titleId, String mediaType) async {
    return _items.contains('$mediaType:$titleId');
  }

  @override
  Future<void> add({
    required int titleId,
    required String mediaType,
    required String title,
    String? posterPath,
    String? recommendedBy,
  }) async {
    _items.add('$mediaType:$titleId');
  }

  @override
  Future<void> remove({
    required int titleId,
    required String mediaType,
  }) async {
    _items.remove('$mediaType:$titleId');
  }

  @override
  Future<void> hydrate() async {}

  @override
  Future<List<WatchlistEntry>> getWatchlist({String? mediaType}) async => [];

  @override
  Stream<List<WatchlistEntry>> watchWatchlist({String? mediaType}) =>
      Stream.value([]);
}

void main() {
  final testTvShow = TitleDetail(
    id: 1396,
    mediaType: 'tv',
    title: 'Severance',
    overview: 'Mark leads a team of office workers whose memories have been surgically divided.',
    posterPath: '/severance_poster.jpg',
    backdropPath: '/severance_backdrop.jpg',
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
        FriendTitleRanking(
          userId: 'u3',
          username: 'maya',
          displayName: 'Maya',
          rankPosition: 3,
          calculatedScore: 9.50,
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
        commonDropPoint: CommonDropPoint(season: 1, episode: 4, count: 3),
      ),
    ),
  );

  final testMovie = TitleDetail(
    id: 101,
    mediaType: 'movie',
    title: 'Parasite',
    overview: 'Greed and class discrimination threaten the newly formed symbiotic relationship.',
    posterPath: '/parasite_poster.jpg',
    network: 'Neon',
    runtimeMinutes: 132,
    releaseDate: DateTime(2019, 5, 30),
    communityScore: 9.70,
    director: 'Bong Joon-ho',
    availabilities: const [
      TitleAvailabilityDetail(platformId: 'max'),
    ],
    seasons: const [], // Movies do not have seasons!
    socialSummary: null, // Unranked
  );

  Widget createTestWidget({
    required TitleDetail title,
    WatchlistRepository? watchlistRepo,
  }) {
    return ProviderScope(
      overrides: [
        posterNetworkImagesProvider.overrideWithValue(false),
        if (watchlistRepo != null)
          watchlistRepositoryProvider.overrideWithValue(watchlistRepo),
      ],
      child: MaterialApp(
        theme: TellyTheme.dark,
        home: ShowDetailScreen(
          titleId: title.id,
          mediaType: title.mediaType,
          initialTitle: title,
        ),
      ),
    );
  }

  group('FE-611: ShowDetailScreen Component Tests (SCR-08)', () {
    testWidgets('renders TV show with ranked status, seasons accordion and survival rate', (tester) async {
      await tester.pumpWidget(createTestWidget(title: testTvShow));
      await tester.pumpAndSettle();

      // Title & Meta
      expect(find.text('Severance'), findsOneWidget);
      expect(find.text('Apple TV+ • 2 Seasons • 2022'), findsOneWidget);
      expect(find.text('Creator: Dan Erickson'), findsOneWidget);
      expect(find.text('★ 9.34'), findsOneWidget);
      expect(find.text('👑 GOD TIER'), findsOneWidget);

      // Streaming Now
      expect(find.text('STREAMING NOW'), findsOneWidget);
      expect(find.text('Watch on APPLE_TV_PLUS'), findsOneWidget);

      // Your Status (Ranked State)
      expect(find.text('YOUR STATUS'), findsOneWidget);
      expect(find.text('Ranked #2 in Your TV Canon'), findsOneWidget);
      expect(find.text('Calculated Score: 9.72 / 10.0'), findsOneWidget);
      expect(find.text('Re-Duel / Change Rank'), findsOneWidget);

      // Friends Who Ranked
      expect(find.text('FRIENDS WHO RANKED THIS (2)'), findsOneWidget);
      expect(find.text('Jordan'), findsOneWidget);
      expect(find.text('Maya'), findsOneWidget);

      // Seasons Accordion
      expect(find.text('SEASONS ACCORDION'), findsOneWidget);
      expect(find.text('Season 1'), findsOneWidget);
      expect(find.text('Season 2'), findsOneWidget);
      expect(find.text('9 Episodes'), findsOneWidget);
      expect(find.text('10 Episodes'), findsOneWidget);

      // Community Survival Rate
      expect(find.text('COMMUNITY SURVIVAL RATE'), findsOneWidget);
      expect(find.text('82% Completed'), findsOneWidget);
      expect(find.text('Drop point: S1E04'), findsOneWidget);
    });

    testWidgets('renders Movie with unranked status and no seasons accordion', (tester) async {
      await tester.pumpWidget(createTestWidget(title: testMovie));
      await tester.pumpAndSettle();

      // Title & Meta
      expect(find.text('Parasite'), findsOneWidget);
      expect(find.text('Neon • 132 min • 2019'), findsOneWidget);
      expect(find.text('Director: Bong Joon-ho'), findsOneWidget);

      // Unranked Status
      expect(find.text('You have not ranked this movie yet.'), findsOneWidget);
      expect(find.text('+ Log & Add to Canon'), findsOneWidget);

      // Dual-Canon Invariant: Movies must NEVER have seasons accordion
      expect(find.text('SEASONS ACCORDION'), findsNothing);
      expect(find.text('COMMUNITY SURVIVAL RATE'), findsNothing);
    });

    testWidgets('toggles bookmark / watchlist status on tap', (tester) async {
      final fakeWatchlist = InMemoryWatchlistRepository();

      await tester.pumpWidget(
        createTestWidget(
          title: testMovie,
          watchlistRepo: fakeWatchlist,
        ),
      );
      await tester.pumpAndSettle();

      // Initially not bookmarked
      expect(await fakeWatchlist.isInWatchlist(101, 'movie'), isFalse);
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);

      // Tap Bookmark button
      await tester.tap(find.byIcon(Icons.bookmark_border));
      await tester.pumpAndSettle();

      // Added to watchlist
      expect(await fakeWatchlist.isInWatchlist(101, 'movie'), isTrue);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(find.text('Added "Parasite" to your Watchlist'), findsOneWidget);

      // Tap again to remove
      await tester.tap(find.byIcon(Icons.bookmark));
      await tester.pumpAndSettle();

      // Removed from watchlist
      expect(await fakeWatchlist.isInWatchlist(101, 'movie'), isFalse);
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
      expect(find.text('Removed "Parasite" from your Watchlist'), findsOneWidget);
    });

    testWidgets('toggling season in accordion expands and collapses details', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget(title: testTvShow));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Season 1 overview is expanded by default
      expect(find.text('Mark Scout leads a team at Lumon Industries.'), findsOneWidget);
      // Season 2 overview is collapsed
      expect(find.text('The fallout of the macrodata revolution.'), findsNothing);

      // Tap Season 2 to expand it
      await tester.tap(find.text('Season 2'));
      await tester.pumpAndSettle();

      // Season 2 overview is now visible
      expect(find.text('The fallout of the macrodata revolution.'), findsOneWidget);

      // Tap Season 1 to collapse it
      await tester.tap(find.text('Season 1'));
      await tester.pumpAndSettle();

      // Season 1 overview collapsed
      expect(find.text('Mark Scout leads a team at Lumon Industries.'), findsNothing);
    });
  });
}
