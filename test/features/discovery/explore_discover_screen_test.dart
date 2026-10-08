import 'dart:convert';

import 'package:drift/native.dart';
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
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/features/discovery/presentation/controllers/explore_picks.dart';
import 'package:telly_app/features/discovery/presentation/controllers/explore_rows_controller.dart';
import 'package:telly_app/features/queue/data/watchlist_repository.dart';
import 'package:telly_app/features/discovery/presentation/screens/explore_discover_screen.dart';
import 'package:telly_app/features/logging/data/title_repository.dart';

import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_title_repository.dart';
import '../../fakes/fake_watchlist_repository.dart';
import '../../helpers/router_harness.dart';

// Explore's ranked picks and trending (#182); the ranking itself is tested in explore_ranker_test.
const _picks = [
  RecommendedTitle(
    titleId: 60059,
    mediaType: 'tv',
    title: 'Better Call Saul',
    reason: RecommendationReason.becauseYouLoved,
    reasonTitle: 'Breaking Bad',
  ),
  RecommendedTitle(titleId: 27205, mediaType: 'movie', title: 'Inception', reason: RecommendationReason.trending),
];
const _trending = [
  RecommendedTitle(titleId: 126308, mediaType: 'tv', title: 'Shogun', reason: RecommendationReason.trending),
  RecommendedTitle(titleId: 693134, mediaType: 'movie', title: 'Dune: Part Two', reason: RecommendationReason.trending),
];

List<Override> _pickOverrides({List<RecommendedTitle> picks = _picks}) => [
      explorePicksProvider.overrideWith((ref) async => picks),
      exploreTrendingProvider.overrideWith((ref) async => _trending),
    ];

void main() {
  // Explore's rows read a Drift cache and rank against a fixed day (#180).
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());
  List<Override> env() => [
        databaseProvider.overrideWithValue(db),
        exploreNowProvider.overrideWithValue(() => DateTime(2026, 10, 8, 12)),
        watchlistRepositoryProvider.overrideWithValue(FakeWatchlistRepository()),
      ];

  Widget createTestWidget({
    DiscoveryRepository? discoveryRepo,
    TitleRepository? titleRepo,
    AuthRepository? authRepo,
    String? searchRequest,
    List<RecommendedTitle> picks = _picks,
  }) {
    return ProviderScope(
      overrides: [
        ...env(),
        ..._pickOverrides(picks: picks),
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

      // Returns to the rows
      expect(find.byKey(const Key('explore_rows_movie')), findsOneWidget);
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
          ...env(),
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

  group('FE-EXPLORE-03: search zero-state', () {
    Widget routed() => routerHarness(
          const ExploreDiscoverScreen(),
          overrides: [
            ...env(),
            ..._pickOverrides(),
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
      // The rows step aside while the zero-state is up.
      expect(find.byKey(const Key('explore_rows_movie')), findsNothing);
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

  group('#46: SupabaseDiscoveryRepository', () {
    test('fetches explore candidates and asks title-related for missing seeds', () async {
      final requests = <http.Request>[];
      final repo = SupabaseDiscoveryRepository(SupabaseClient(
        'http://supabase.test',
        'anon-key',
        httpClient: MockClient((req) async {
          requests.add(req);
          return http.Response(jsonEncode({'media_type': 'tv', 'candidates': []}), 200,
              headers: {'content-type': 'application/json'}, request: req);
        }),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ));

      final payload = await repo.fetchExploreCandidates('tv');
      await repo.refreshRelated([1396, 60059], 'tv');

      expect(payload['media_type'], 'tv');
      expect(requests[0].url.path, '/rest/v1/rpc/get_explore_candidates');
      expect(jsonDecode(requests[0].body), {'p_media_type': 'tv'});
      expect(requests[1].url.path, '/functions/v1/title-related');
      expect(jsonDecode(requests[1].body), {'seed_ids': [1396, 60059], 'media_type': 'tv'});
    });
  });
}
