@Tags(['a11y'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/core/router/splash_screen.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/features/auth/presentation/screens/auth_screen.dart';
import 'package:telly_app/features/auth/presentation/screens/handle_reservation_screen.dart';
import 'package:telly_app/features/cowatch/presentation/screens/two_to_watch_screen.dart';
import 'package:telly_app/features/discovery/data/discovery_repository.dart';
import 'package:telly_app/features/discovery/presentation/screens/explore_discover_screen.dart';
import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/feed/presentation/screens/activity_feed_screen.dart';
import 'package:telly_app/features/feed/presentation/screens/comment_thread_screen.dart';
import 'package:telly_app/features/logging/data/title_repository.dart';
import 'package:telly_app/features/logging/presentation/screens/log_flow_screens.dart';
import 'package:telly_app/features/logging/presentation/screens/logging_studio_screen.dart';
import 'package:telly_app/features/onboarding/data/onboarding_repository.dart';
import 'package:telly_app/features/onboarding/presentation/controllers/onboarding_controllers.dart';
import 'package:telly_app/features/onboarding/presentation/screens/onboarding_tournament_screen.dart';
import 'package:telly_app/features/onboarding/presentation/screens/seed_grid_screen.dart';
import 'package:telly_app/features/onboarding/presentation/screens/streaming_setup_screen.dart';
import 'package:telly_app/features/profile/data/graveyard_repository.dart';
import 'package:telly_app/features/profile/data/profile_repository.dart';
import 'package:telly_app/features/profile/presentation/controllers/profile_controller.dart';
import 'package:telly_app/features/profile/presentation/screens/dual_canon_profile_screen.dart';
import 'package:telly_app/features/profile/presentation/screens/edit_profile_studio_screen.dart';
import 'package:telly_app/features/profile/presentation/screens/friend_profile_screen.dart';
import 'package:telly_app/features/profile/presentation/screens/settings_hub_screen.dart';
import 'package:telly_app/features/profile/presentation/screens/tv_graveyard_screen.dart';
import 'package:telly_app/features/queue/data/watchlist_repository.dart';
import 'package:telly_app/features/queue/presentation/screens/smart_queue_screen.dart';
import 'package:telly_app/features/ranking/domain/franchise_rollup_service.dart';
import 'package:telly_app/features/sharing/data/story_share_service.dart';
import 'package:telly_app/features/sharing/presentation/screens/telly_wrapped_studio_screen.dart';
import 'package:telly_app/features/squads/data/squad_repository.dart';
import 'package:telly_app/features/squads/domain/squad_models.dart';
import 'package:telly_app/features/squads/presentation/screens/squad_hub_screen.dart';
import 'package:telly_app/features/squads/presentation/screens/squads_list_screen.dart';
import 'package:telly_app/features/title_detail/domain/title_detail_models.dart';
import 'package:telly_app/features/title_detail/presentation/screens/show_detail_screen.dart';

import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_graveyard_repository.dart';
import '../fakes/fake_onboarding_repository.dart';
import '../fakes/fake_profile_repository.dart';
import '../fakes/fake_social_repository.dart';
import '../fakes/fake_title_repository.dart';
import '../fakes/fake_watchlist_repository.dart';

class _FakeSquadRepository implements SquadRepository {
  final Map<String, Squad> squads = {
    'sq-1': Squad(
      id: 'sq-1',
      name: 'Prestige TV Club',
      createdBy: 'u-1',
      members: [
        SquadMember(
          userId: 'u-1',
          username: 'alex',
          displayName: 'Alex',
          role: SquadRole.owner,
          joinedAt: DateTime(2026, 1, 1),
        ),
      ],
      createdAt: DateTime(2026, 1, 1),
    ),
  };

  @override
  Future<List<Squad>> mySquads() async => squads.values.toList();

  @override
  Future<Squad> fetchSquad(String squadId) async => squads[squadId]!;

  @override
  Future<List<SquadConsensusItem>> consensus(Squad squad, String mediaType) async => [];

  @override
  Future<List<SharedWatchlistItem>> sharedWatchlist(String squadId) async => [];

  @override
  Future<Squad> create({required String name, String? description}) async {
    final s = Squad(
      id: 'sq-new',
      name: name,
      createdBy: 'u-1',
      members: [
        SquadMember(
          userId: 'u-1',
          username: 'alex',
          displayName: 'Alex',
          role: SquadRole.owner,
          joinedAt: DateTime(2026, 1, 1),
        ),
      ],
      createdAt: DateTime.now(),
    );
    return squads[s.id] = s;
  }

  @override
  Future<void> addMember({required String squadId, required String userId}) async {}
}

class _SeededProfileCanon extends ProfileCanonNotifier {
  _SeededProfileCanon(this.movies, this.series);
  final List<CanonEntry> movies;
  final List<CanonEntry> series;

  @override
  ProfileCanonState build() => ProfileCanonState(movies: movies, series: series);
}

class _FakeSeedSelectionController extends SeedSelectionController {
  _FakeSeedSelectionController(this._initialState);
  final SeedSelectionState _initialState;

  @override
  SeedSelectionState build() => _initialState;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late AppDatabase db;
  late FakeAuthRepository authRepo;
  late FakeSocialRepository socialRepo;
  late FakeOnboardingRepository onboardingRepo;
  late FakeTitleRepository titleRepo;
  late FakeGraveyardRepository graveyardRepo;
  late FakeProfileRepository profileRepo;
  late FakeWatchlistRepository watchlistRepo;
  late _FakeSquadRepository squadRepo;

  setUp(() {
    db = AppDatabase.inMemory();
    authRepo = FakeAuthRepository(
      signedInUserId: 'u-test',
      profile: UserProfile(
        id: 'u-test',
        username: 'testuser',
        displayName: 'Test User',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    socialRepo = FakeSocialRepository(
      feed: [
        fakeActivity('act-1', upset: true, minutesAgo: 1),
        fakeActivity('act-2', userId: 'u-maya', username: 'maya', titleId: 2, title: 'The Morning Show', minutesAgo: 2),
      ],
    );
    onboardingRepo = FakeOnboardingRepository();
    titleRepo = FakeTitleRepository();
    graveyardRepo = FakeGraveyardRepository();
    profileRepo = FakeProfileRepository();
    watchlistRepo = FakeWatchlistRepository();
    squadRepo = _FakeSquadRepository();
  });

  tearDown(() => db.close());

  Future<void> runA11yAudit(
    WidgetTester tester,
    Widget screen, {
    List<Override> overrides = const [],
    Size size = const Size(1080, 2400),
    double pixelRatio = 2.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = pixelRatio;
    addTearDown(tester.view.reset);

    final defaultOverrides = <Override>[
      databaseProvider.overrideWithValue(db),
      authRepositoryProvider.overrideWithValue(authRepo),
      socialRepositoryProvider.overrideWithValue(socialRepo),
      onboardingRepositoryProvider.overrideWithValue(onboardingRepo),
      titleRepositoryProvider.overrideWithValue(titleRepo),
      graveyardRepositoryProvider.overrideWithValue(graveyardRepo),
      profileRepositoryProvider.overrideWithValue(profileRepo),
      profileCanonProvider.overrideWith(() => _SeededProfileCanon(const [], const [])),
      watchlistRepositoryProvider.overrideWithValue(watchlistRepo),
      squadRepositoryProvider.overrideWithValue(squadRepo),
      posterNetworkImagesProvider.overrideWithValue(false),
      hapticsEnabledProvider.overrideWith((ref) => false),
      storyShareServiceProvider.overrideWithValue(FakeStoryShareService()),
      discoveryRepositoryProvider.overrideWithValue(FakeDiscoveryRepository()),
      ...overrides,
    ];

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            backgroundColor: const Color(0xFF08090C),
            body: screen,
          ),
        ),
        GoRoute(path: Routes.log, builder: (_, __) => const SizedBox()),
        GoRoute(path: Routes.canon, builder: (_, __) => const SizedBox()),
        GoRoute(path: Routes.feed, builder: (_, __) => const SizedBox()),
        GoRoute(path: Routes.reveal, builder: (_, __) => const SizedBox()),
        GoRoute(path: Routes.squads, builder: (_, __) => const SizedBox()),
        GoRoute(path: Routes.seedGrid, builder: (_, __) => const SizedBox()),
        GoRoute(path: '/profile/:handle', builder: (_, __) => const SizedBox()),
      ],
    );

    final SemanticsHandle handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: defaultOverrides,
          child: MaterialApp.router(
            theme: TellyTheme.darkTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all 4 mandatory guideline checks (QA-604 / TA-06 §5.2)
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    } finally {
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('Automated Accessibility Guideline Checks Across All 20+ Routed Screens (QA-604)', () {
    testWidgets('01. SplashScreen meets guidelines', (tester) async {
      await runA11yAudit(tester, const SplashScreen());
    });

    testWidgets('02. SCR-01 AuthScreen meets guidelines', (tester) async {
      await runA11yAudit(tester, const AuthScreen());
    });

    testWidgets('03. HandleReservationScreen meets guidelines', (tester) async {
      await runA11yAudit(tester, const HandleReservationScreen());
    });

    testWidgets('04. SCR-02 StreamingSetupScreen meets guidelines', (tester) async {
      await runA11yAudit(tester, const StreamingSetupScreen());
    });

    testWidgets('05. SCR-03 SeedGridScreen meets guidelines', (tester) async {
      await runA11yAudit(tester, const SeedGridScreen());
    });

    testWidgets('06. SCR-04 OnboardingTournamentScreen meets guidelines', (tester) async {
      await runA11yAudit(
        tester,
        const OnboardingTournamentScreen(),
        overrides: [
          seedSelectionProvider.overrideWith(
            () => _FakeSeedSelectionController(
              const SeedSelectionState(selected: {'tv:76331', 'tv:110492'}),
            ),
          ),
        ],
      );
    });

    testWidgets('07. SCR-05 ActivityFeedScreen meets guidelines', (tester) async {
      await runA11yAudit(tester, const ActivityFeedScreen());
    });

    testWidgets('08. SCR-06 CommentThreadScreen meets guidelines', (tester) async {
      final act = fakeActivity('act-comment-1', minutesAgo: 5);
      await runA11yAudit(tester, CommentThreadScreen(activity: act));
    });

    testWidgets('09. SCR-07 ExploreDiscoverScreen meets guidelines', (tester) async {
      await runA11yAudit(tester, const ExploreDiscoverScreen());
    });

    testWidgets('10. SCR-08 ShowDetailScreen meets guidelines', (tester) async {
      final testTitle = TitleDetail(
        id: 1396,
        mediaType: 'tv',
        title: 'Severance',
        overview: 'Mark leads a team of office workers whose memories have been surgically divided.',
        communityScore: 9.34,
        numberOfSeasons: 2,
        numberOfEpisodes: 19,
        releaseDate: DateTime(2022, 2, 18),
        seasons: const [
          TitleSeasonDetail(
            seasonNumber: 1,
            name: 'Season 1',
            episodeCount: 9,
            airDate: '2022-02-18',
          ),
        ],
      );
      await runA11yAudit(
        tester,
        ShowDetailScreen(titleId: 1396, mediaType: 'tv', initialTitle: testTitle),
      );
    });

    testWidgets('11. SCR-09 LoggingStudioScreen meets guidelines', (tester) async {
      await runA11yAudit(tester, const LoggingStudioScreen());
    });

    testWidgets('12. SCR-10 LogDuelScreen meets guidelines', (tester) async {
      await runA11yAudit(tester, const LogDuelScreen());
    });

    testWidgets('13. SCR-12 LogRevealScreen meets guidelines', (tester) async {
      await runA11yAudit(tester, const LogRevealScreen());
    });

    testWidgets('14. SCR-13 SmartQueueScreen meets guidelines', (tester) async {
      await runA11yAudit(tester, const SmartQueueScreen());
    });

    testWidgets('15. SCR-14 DualCanonProfileScreen meets guidelines', (tester) async {
      final movies = [
        const CanonEntry(id: 1, title: 'Interstellar', mediaType: 'movie', rankPosition: 1, calculatedScore: 9.5),
      ];
      final series = [
        const CanonEntry(id: 2, title: 'Severance', mediaType: 'tv', rankPosition: 1, calculatedScore: 9.7),
      ];
      await runA11yAudit(
        tester,
        const DualCanonProfileScreen(),
        overrides: [
          profileCanonProvider.overrideWith(() => _SeededProfileCanon(movies, series)),
        ],
      );
    });

    testWidgets('16. SCR-15 FriendProfileScreen meets guidelines', (tester) async {
      await runA11yAudit(tester, const FriendProfileScreen(handle: 'jordan'));
    });

    testWidgets('17. SCR-16 TwoToWatchScreen meets guidelines', (tester) async {
      await runA11yAudit(
        tester,
        const TwoToWatchScreen(friendId: 'u-jordan', friendHandle: 'jordan', friendDisplayName: 'Jordan M.'),
      );
    });

    testWidgets('18. SCR-17a SquadsListScreen meets guidelines', (tester) async {
      await runA11yAudit(tester, const SquadsListScreen());
    });

    testWidgets('19. SCR-17b SquadHubScreen meets guidelines', (tester) async {
      await runA11yAudit(tester, const SquadHubScreen(squadId: 'sq-1'));
    });

    testWidgets('20. SCR-18 TvGraveyardScreen meets guidelines', (tester) async {
      await runA11yAudit(tester, const TvGraveyardScreen());
    });

    testWidgets('21. SCR-19 TellyWrappedStudioScreen meets guidelines', (tester) async {
      await runA11yAudit(tester, const TellyWrappedStudioScreen());
    });

    testWidgets('22. SCR-20 SettingsHubScreen meets guidelines', (tester) async {
      await runA11yAudit(tester, const SettingsHubScreen());
    });

    testWidgets('23. EditProfileStudioScreen meets guidelines', (tester) async {
      await runA11yAudit(tester, const EditProfileStudioScreen());
    });
  });
}
