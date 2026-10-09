import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/auth/presentation/screens/handle_reservation_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/cowatch/presentation/screens/two_to_watch_screen.dart';
import '../../features/feed/domain/social_models.dart';
import '../../features/feed/presentation/screens/activity_feed_screen.dart';
import '../../features/feed/presentation/screens/comment_thread_screen.dart';
import '../../features/logging/domain/log_request.dart';
import '../../features/logging/domain/title_search_result.dart';
import '../../features/logging/presentation/screens/log_flow_screens.dart';
import '../../features/logging/presentation/screens/logging_studio_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_tournament_screen.dart';
import '../../features/onboarding/presentation/screens/seed_grid_screen.dart';
import '../../features/onboarding/presentation/screens/streaming_setup_screen.dart';
import '../../features/profile/presentation/screens/dual_canon_profile_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_studio_screen.dart';
import '../../features/profile/presentation/screens/friend_profile_screen.dart';
import '../../features/profile/presentation/screens/search_users_screen.dart';
import '../../features/profile/presentation/screens/settings_hub_screen.dart';
import '../../features/profile/presentation/screens/tv_graveyard_screen.dart';
import '../../features/achievements/presentation/screens/achievements_screen.dart';
import '../../features/challenges/presentation/screens/challenge_screen.dart';
import '../../features/challenges/presentation/screens/challenges_screen.dart';
import '../../features/levels/presentation/screens/friends_this_week_screen.dart';
import '../../features/levels/presentation/screens/header_art_screen.dart';
import '../../features/levels/presentation/screens/rewards_screen.dart';
import '../../features/levels/presentation/screens/your_level_screen.dart';
import '../../features/queue/presentation/screens/custom_list_detail_screen.dart';
import '../../features/queue/presentation/screens/queue_lists_screen.dart';
import '../../features/queue/presentation/screens/smart_queue_screen.dart';
import '../../features/sharing/presentation/screens/telly_wrapped_studio_screen.dart';
import '../../features/squads/presentation/screens/squad_hub_screen.dart';
import '../../features/squads/presentation/screens/squads_list_screen.dart';
import '../../features/discovery/presentation/screens/explore_discover_screen.dart';
import '../../features/discovery/presentation/screens/explore_row_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/more/presentation/screens/more_hub_screen.dart';
import '../../features/tracking/domain/tracking_hub.dart';
import '../../features/tracking/presentation/screens/watching_hub_screen.dart';
import '../../features/title_detail/presentation/screens/show_detail_screen.dart';
import 'app_shell.dart';
import 'auth_redirect.dart';
import 'pending_screen.dart';
import 'routes.dart';
import 'splash_screen.dart';

/// Arguments for friend-scoped routes until FE-608 loads profiles by handle.
class FriendRouteArgs {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  const FriendRouteArgs({required this.userId, required this.displayName, this.avatarUrl});
}

/// Bridges Riverpod auth state to GoRouter's `refreshListenable` directly.
class _RouterRefresh implements Listenable {
  final _listeners = <VoidCallback>[];
  void notify() {
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);
  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
}

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// The app router (FE-602, #44): auth/onboarding redirects, redirects from old paths, and a
/// StatefulShellRoute with five tabs (route map: screen spec §0.0). Every spec'd screen is reachable.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen<AuthState>(authControllerProvider, (_, __) => refresh.notify());

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    // Old (pre-#44) paths move first; the new location then passes through the auth policy.
    redirect: (context, state) =>
        Routes.legacyRedirect(state.uri) ?? authRedirect(ref.read(authControllerProvider), state.matchedLocation),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.auth, builder: (_, __) => const AuthScreen()),
      GoRoute(path: Routes.resetPassword, builder: (_, __) => const ResetPasswordScreen()),

      // Onboarding
      GoRoute(path: Routes.handle, builder: (_, __) => const HandleReservationScreen()),
      GoRoute(path: Routes.streamingSetup, builder: (_, __) => const StreamingSetupScreen()),
      GoRoute(path: Routes.seedGrid, builder: (_, __) => const SeedGridScreen()),
      GoRoute(path: Routes.tournament, builder: (_, __) => const OnboardingTournamentScreen()),

      // The five tabs (decision 0003): Home, Explore, Canon, Social, More
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.explore,
              builder: (_, state) => ExploreDiscoverScreen(searchRequest: state.uri.queryParameters['search']),
              routes: [
                GoRoute(
                  path: 'row/:rowId',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, state) => ExploreRowScreen(
                    rowId: state.pathParameters['rowId'] ?? '',
                    mediaType: state.uri.queryParameters['canon'],
                  ),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.canon,
              builder: (context, __) => DualCanonProfileScreen(
                onTapEntry: (entry) => context.push(Routes.title(entry.mediaType, entry.id)),
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.social,
              builder: (_, __) => const ActivityFeedScreen(),
              routes: [
                GoRoute(
                  path: 'activity/:id',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, state) => state.extra is ActivityLog
                      ? CommentThreadScreen(activity: state.extra! as ActivityLog)
                      : const PendingScreen(title: 'Discussion', ticket: 'FE-607'),
                ),
                GoRoute(
                  path: 'search',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, __) => const SearchUsersScreen(),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.more,
              builder: (_, __) => const MoreHubScreen(),
              routes: [
                GoRoute(
                  path: 'queue',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, __) => const SmartQueueScreen(),
                  routes: [
                    GoRoute(
                      path: 'lists',
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (_, __) => const QueueListsScreen(),
                    ),
                    GoRoute(
                      path: 'list/:id',
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (_, state) => CustomListDetailScreen(
                        listId: state.pathParameters['id'] ?? '',
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'settings',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, __) => const SettingsHubScreen(),
                ),
                GoRoute(
                  path: 'edit',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, __) => const EditProfileStudioScreen(),
                ),
                GoRoute(
                  path: 'achievements',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, __) => const AchievementsScreen(),
                ),
                GoRoute(
                  path: 'challenges',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, __) => const ChallengesScreen(),
                  routes: [
                    GoRoute(
                      path: ':slug',
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (_, state) => ChallengeScreen(slug: state.pathParameters['slug']!),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'level',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, __) => const YourLevelScreen(),
                  routes: [
                    GoRoute(
                      path: 'rewards',
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (_, __) => const RewardsScreen(),
                      routes: [
                        GoRoute(
                          path: 'header-art',
                          parentNavigatorKey: rootNavigatorKey,
                          builder: (_, __) => const HeaderArtScreen(),
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'week',
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (_, __) => const FriendsThisWeekScreen(),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'watching',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, state) => WatchingHubScreen(
                    initialFilter: WatchingFilter.fromQuery(state.uri.queryParameters['filter']),
                  ),
                ),
                GoRoute(
                  path: 'graveyard',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, __) => const TvGraveyardScreen(),
                ),
                GoRoute(
                  path: 'wrapped',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, __) => const TellyWrappedStudioScreen(),
                ),
              ],
            ),
          ]),
        ],
      ),

      // Logging flow (full-screen; SCR-09 → SCR-10 → SCR-11 sheet → SCR-12)
      GoRoute(
        path: Routes.log,
        builder: (_, state) {
          final extra = state.extra;
          return LoggingStudioScreen(
            initialTitle: extra is LogRequest
                ? extra.title
                : extra is TitleSearchResult
                    ? extra
                    : null,
            initialStatus: extra is LogRequest ? extra.status : null,
          );
        },
        routes: [
          GoRoute(path: 'duel', builder: (_, __) => const LogDuelScreen()),
          GoRoute(path: 'reveal', builder: (_, __) => const LogRevealScreen()),
        ],
      ),

      // Pushed detail screens
      GoRoute(
        path: '/title/:mediaType/:id',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (_, state) {
          final mediaType = state.pathParameters['mediaType'];
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          return (mediaType == 'movie' || mediaType == 'tv') && id != null ? null : Routes.home;
        },
        builder: (_, state) => ShowDetailScreen(
          titleId: int.parse(state.pathParameters['id']!),
          mediaType: state.pathParameters['mediaType']!,
        ),
      ),
      GoRoute(
        path: Routes.cowatch,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) {
          final titleId = int.tryParse(state.uri.queryParameters['titleId'] ?? '');
          final mediaType = state.uri.queryParameters['mediaType'];
          final friend = state.uri.queryParameters['friend'];
          final extra = state.extra;
          final friendArgs = extra is FriendRouteArgs ? extra : null;
          // Without a friend SCR-16 opens on its "Who's watching?" picker (FE-COWATCH-01).
          return TwoToWatchScreen(
            friendId: friendArgs?.userId,
            friendHandle: friend,
            friendDisplayName: friendArgs?.displayName,
            preselectedTitleId: titleId,
            preselectedMediaType: mediaType == 'movie' || mediaType == 'tv' ? mediaType : null,
          );
        },
      ),
      GoRoute(
        path: '/u/:handle',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => FriendProfileScreen(handle: state.pathParameters['handle']!),
        routes: [
          GoRoute(
            path: 'two-to-watch',
            builder: (_, state) {
              final args = state.extra;
              final handle = state.pathParameters['handle']!;
              final titleId = int.tryParse(state.uri.queryParameters['titleId'] ?? '');
              // Without route args the handle is resolved to a user by the controller.
              return TwoToWatchScreen(
                friendId: args is FriendRouteArgs ? args.userId : null,
                friendHandle: handle,
                friendDisplayName: args is FriendRouteArgs ? args.displayName : null,
                preselectedTitleId: titleId,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: Routes.squads,
        builder: (_, __) => const SquadsListScreen(),
        routes: [
          GoRoute(path: ':id', builder: (_, state) => SquadHubScreen(squadId: state.pathParameters['id']!)),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
