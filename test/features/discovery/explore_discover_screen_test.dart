import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:telly_app/features/discovery/domain/discovery_models.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/features/discovery/data/discovery_repository.dart';
import 'package:telly_app/features/discovery/presentation/screens/explore_discover_screen.dart';
import 'package:telly_app/features/logging/data/title_repository.dart';

import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_title_repository.dart';
import '../../helpers/router_harness.dart';

void main() {
  Widget createTestWidget({
    DiscoveryRepository? discoveryRepo,
    TitleRepository? titleRepo,
    AuthRepository? authRepo,
    String? searchRequest,
  }) {
    return ProviderScope(
      overrides: [
        posterNetworkImagesProvider.overrideWithValue(false),
        authRepositoryProvider.overrideWithValue(
          authRepo ?? FakeAuthRepository(signedInUserId: 'u-user'),
        ),
        discoveryRepositoryProvider.overrideWithValue(
          discoveryRepo ?? FakeDiscoveryRepository(),
        ),
        titleRepositoryProvider.overrideWithValue(
          titleRepo ?? FakeTitleRepository(),
        ),
      ],
      child: MaterialApp(
        theme: TellyTheme.dark,
        home: Scaffold(
          body: ExploreDiscoverScreen(searchRequest: searchRequest),
        ),
      ),
    );
  }

  group('FE-612: ExploreDiscoverScreen Component Tests (SCR-07)', () {
    testWidgets('renders search bar, network battlegrounds, binging carousel, and curated canons', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Header & Search Bar
      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('Search shows, actors, showrunners, friends...'), findsOneWidget);

      // Network Battlegrounds Section
      expect(find.text('NETWORK BATTLEGROUNDS'), findsOneWidget);
      expect(find.text('👑 HBO'), findsOneWidget);
      expect(find.text('🍏 Apple TV+'), findsOneWidget);
      expect(find.text('See Full Network Rankings'), findsOneWidget);

      // Friends Are Currently Binging Carousel
      expect(find.text('FRIENDS ARE CURRENTLY BINGING'), findsOneWidget);
      expect(find.text('Shogun'), findsOneWidget);
      expect(find.text('Slow Horses'), findsOneWidget);
      expect(find.text('8 watching'), findsOneWidget);

      // Curated Canons Section
      expect(find.text('CURATED CANONS'), findsOneWidget);
      expect(find.text('The "Stuck the Landing" Canon'), findsOneWidget);
      expect(find.text('Peak 1-Season Miniseries'), findsOneWidget);
    });

    testWidgets('tapping See Full Network Rankings opens bottom sheet with leaderboard', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap See Full Network Rankings
      final button = find.text('See Full Network Rankings');
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();

      // Modal Bottom Sheet appears
      expect(find.text('👑 NETWORK BATTLEGROUNDS'), findsOneWidget);
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
    });

    testWidgets('tapping curated canon opens detail sheet with sample titles', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Scroll down to make Curated Canons fully visible if needed
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Tap The "Stuck the Landing" Canon card
      await tester.tap(find.text('The "Stuck the Landing" Canon'));
      await tester.pumpAndSettle();

      // Modal Bottom Sheet displays DraggableScrollableSheet, description and sample titles
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      expect(find.text('The "Stuck the Landing" Canon'), findsWidgets);
      expect(find.text('FEATURED TITLES'), findsOneWidget);
      expect(find.text('Shows with universally revered, transcendent final episodes.'), findsWidgets);
      expect(find.text('Breaking Bad'), findsOneWidget);
      expect(find.text('Succession'), findsOneWidget);
      expect(find.text('Six Feet Under'), findsOneWidget);

      // Tapping a featured title dismisses sheet and populates search
      await tester.tap(find.byKey(const Key('curated_title_Breaking_Bad')));
      await tester.pumpAndSettle();

      expect(find.byType(DraggableScrollableSheet), findsNothing);
      expect(find.text('Breaking Bad'), findsWidgets);
    });

    testWidgets('search query renders titles and people results with working filter chips', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter search text "bear"
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'bear');
      await tester.pumpAndSettle();

      // Filter chips should be visible
      expect(find.text('All'), findsOneWidget);
      expect(find.text('🎬 Titles'), findsOneWidget);
      expect(find.text('👥 People'), findsOneWidget);

      // Section for Titles shows count and "The Bear"
      expect(find.text('TITLES (1)'), findsOneWidget);
      expect(find.text('The Bear'), findsOneWidget);

      // Now search for "maya"
      await tester.enterText(searchField, 'maya');
      await tester.pumpAndSettle();

      expect(find.text('TITLES (0)'), findsOneWidget);
      expect(find.text('PEOPLE (1)'), findsOneWidget);
      expect(find.text('Maya Lin'), findsOneWidget);
      expect(find.text('@maya'), findsOneWidget);

      // Filter chips interaction: Tap "🎬 Titles"
      await tester.tap(find.text('🎬 Titles'));
      await tester.pumpAndSettle();

      // People section should be hidden
      expect(find.text('Maya Lin'), findsNothing);

      // Tap "👥 People"
      await tester.tap(find.text('👥 People'));
      await tester.pumpAndSettle();

      // People section shown
      expect(find.text('Maya Lin'), findsOneWidget);

      // Clear search query
      await tester.tap(find.byKey(const Key('explore_search_field_clear_btn')));
      await tester.pumpAndSettle();

      // Returns to default Discover hub view
      expect(find.text('NETWORK BATTLEGROUNDS'), findsOneWidget);
      expect(find.text('FRIENDS ARE CURRENTLY BINGING'), findsOneWidget);
    });

    testWidgets('renders empty states when repository returns empty collections', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final emptyRepo = FakeDiscoveryRepository(
        battlegrounds: [],
        friendsBinging: [],
        users: [],
      );

      await tester.pumpWidget(createTestWidget(discoveryRepo: emptyRepo));
      await tester.pumpAndSettle();

      // Explore hub loads, empty battlegrounds and friends binging shrink away, curated canons remain
      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('NETWORK BATTLEGROUNDS'), findsNothing);
      expect(find.text('FRIENDS ARE CURRENTLY BINGING'), findsNothing);
      expect(find.text('CURATED CANONS'), findsOneWidget);
    });

    testWidgets('header has no actions; each Feed search request focuses the search field (FE-HEADER-01)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool focused() => tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      expect(find.byTooltip('Search'), findsNothing, reason: 'the redundant header search button is gone');
      expect(focused(), isFalse);

      await tester.pumpWidget(createTestWidget(searchRequest: '1'));
      await tester.pumpAndSettle();
      expect(focused(), isTrue);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(focused(), isFalse);

      // The same request again does nothing; a new one focuses again.
      await tester.pumpWidget(createTestWidget(searchRequest: '1'));
      await tester.pumpAndSettle();
      expect(focused(), isFalse);
      await tester.pumpWidget(createTestWidget(searchRequest: '2'));
      await tester.pumpAndSettle();
      expect(focused(), isTrue);
    });

    testWidgets('tapping own user search result navigates to own canon', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAuth = FakeAuthRepository(
        signedInUserId: 'u-maya',
        profile: UserProfile(id: 'u-maya', username: 'maya', displayName: 'Maya Lin', createdAt: DateTime(2026)),
      );
      await tester.pumpWidget(routerHarness(
        const ExploreDiscoverScreen(),
        overrides: [
          posterNetworkImagesProvider.overrideWithValue(false),
          authRepositoryProvider.overrideWithValue(fakeAuth),
          discoveryRepositoryProvider.overrideWithValue(FakeDiscoveryRepository()),
          titleRepositoryProvider.overrideWithValue(FakeTitleRepository()),
        ],
      ));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'maya');
      await tester.pumpAndSettle();

      final userTile = find.byKey(const Key('user_result_tile_maya'));
      expect(userTile, findsOneWidget);
      await tester.tap(userTile);
      await tester.pumpAndSettle();

      expect(find.text('route:/canon'), findsOneWidget);
    });
  });

  group('FE-EXPLORE-03: Recommended for You & search zero-state', () {
    Widget routed() => routerHarness(
          const ExploreDiscoverScreen(),
          overrides: [
            posterNetworkImagesProvider.overrideWithValue(false),
            authRepositoryProvider.overrideWithValue(FakeAuthRepository(signedInUserId: 'u-user')),
            discoveryRepositoryProvider.overrideWithValue(FakeDiscoveryRepository()),
            titleRepositoryProvider.overrideWithValue(FakeTitleRepository()),
          ],
        );

    void tallView(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    testWidgets('carousel shows picks with their reason and opens the title', (tester) async {
      tallView(tester);
      await tester.pumpWidget(routed());
      await tester.pumpAndSettle();

      expect(find.text('RECOMMENDED FOR YOU'), findsOneWidget);
      expect(find.text('Better Call Saul'), findsOneWidget);
      expect(find.text('Because you loved Breaking Bad'), findsOneWidget);
      expect(find.text('Trending on Telly'), findsOneWidget);

      await tester.tap(find.byKey(const Key('recommended_title_60059')));
      await tester.pumpAndSettle();
      expect(find.text('route:/title/tv/60059'), findsOneWidget);
    });

    testWidgets('carousel is hidden when there is nothing to recommend', (tester) async {
      tallView(tester);
      await tester.pumpWidget(createTestWidget(discoveryRepo: FakeDiscoveryRepository(recommended: [])));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explore_recommended_section')), findsNothing);
      expect(find.text('CURATED CANONS'), findsOneWidget);
    });

    testWidgets('focusing the empty search field shows trending titles immediately', (tester) async {
      tallView(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explore_search_zero_state')), findsNothing);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explore_search_zero_state')), findsOneWidget);
      expect(find.text('TRENDING NOW'), findsOneWidget);
      expect(find.text('Shogun'), findsOneWidget);
      expect(find.text('Dune: Part Two'), findsOneWidget);
      expect(find.text('RECENT SEARCHES'), findsNothing);
      // The browse sections step aside while the zero-state is up.
      expect(find.text('CURATED CANONS'), findsNothing);
    });

    testWidgets('opening a result records it as a recent search', (tester) async {
      tallView(tester);
      await tester.pumpWidget(routed());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'maya');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('user_result_tile_maya')));
      await tester.pumpAndSettle();
      expect(find.text('route:/u/maya'), findsOneWidget);

      final container = ProviderScope.containerOf(tester.element(find.text('route:/u/maya')));
      expect(container.read(recentSearchesProvider), ['maya']);
    });

    testWidgets('recent-search chips re-run the query and can be cleared', (tester) async {
      tallView(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.byType(ExploreDiscoverScreen)));
      container.read(recentSearchesProvider.notifier)
        ..add('bear')
        ..add('maya');

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.text('RECENT SEARCHES'), findsOneWidget);

      await tester.tap(find.text('bear'));
      await tester.pumpAndSettle();
      expect(find.textContaining('TITLES ('), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'bear');

      await tester.tap(find.byKey(const Key('explore_search_field_clear_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('explore_clear_recent_btn')));
      await tester.pumpAndSettle();
      expect(find.text('RECENT SEARCHES'), findsNothing);
    });
  });

  group('FE-EXPLORE-03: RecentSearchesController', () {
    test('keeps newest first, de-duplicates case-insensitively and caps the list', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final recent = container.read(recentSearchesProvider.notifier);

      recent
        ..add('  ')
        ..add('Bear')
        ..add('maya')
        ..add('bear');
      expect(container.read(recentSearchesProvider), ['bear', 'maya']);

      for (var i = 0; i < 10; i++) {
        recent.add('q$i');
      }
      expect(container.read(recentSearchesProvider), hasLength(RecentSearchesController.maxEntries));
      expect(container.read(recentSearchesProvider).first, 'q9');
    });
  });

  group('FE-EXPLORE-03: RecommendedTitle parsing', () {
    test('maps reason kinds to their labels', () {
      final loved = RecommendedTitle.fromJson({
        'title_id': 27205,
        'media_type': 'movie',
        'title': 'Inception',
        'global_community_score': 9.55,
        'release_year': 2010,
        'reason_kind': 'because_you_loved',
        'reason_title': 'The Dark Knight',
      });
      expect(loved.reason, RecommendationReason.becauseYouLoved);
      expect(loved.reasonLabel, 'Because you loved The Dark Knight');
      expect(loved.releaseYear, 2010);

      expect(RecommendedTitle.fromJson({'title_id': 1, 'reason_kind': 'top_rated'}).reasonLabel,
          'Top rated on Telly');
      // get_trending_titles rows carry recent_rankings instead of reason_kind.
      expect(RecommendedTitle.fromJson({'title_id': 550, 'recent_rankings': 3}).reason,
          RecommendationReason.trending);
      // A "because you loved" row without its title degrades instead of printing "null".
      expect(RecommendedTitle.fromJson({'title_id': 2, 'reason_kind': 'because_you_loved'}).reason,
          RecommendationReason.topRated);
    });
  });

  group('FE-EXPLORE-03: SupabaseDiscoveryRepository', () {
    test('calls the recommendation RPCs with media type and limit', () async {
      final requests = <http.Request>[];
      final repo = SupabaseDiscoveryRepository(SupabaseClient(
        'http://supabase.test',
        'anon-key',
        httpClient: MockClient((req) async {
          requests.add(req);
          return http.Response(
            jsonEncode([
              {'title_id': 60059, 'media_type': 'tv', 'title': 'Better Call Saul', 'reason_kind': 'trending'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: req,
          );
        }),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ));

      final recs = await repo.fetchRecommendedTitles(mediaType: 'tv', limit: 5);
      final trending = await repo.fetchTrendingTitles();

      expect(recs.single.title, 'Better Call Saul');
      expect(trending, hasLength(1));
      expect(requests[0].url.path, '/rest/v1/rpc/get_recommended_titles');
      expect(jsonDecode(requests[0].body), {'p_media_type': 'tv', 'p_limit': 5});
      expect(requests[1].url.path, '/rest/v1/rpc/get_trending_titles');
      expect(jsonDecode(requests[1].body), {'p_media_type': null, 'p_limit': 10});
    });
  });
}

