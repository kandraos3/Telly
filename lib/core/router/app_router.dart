import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/auth/presentation/screens/handle_reservation_screen.dart';
import '../../features/cowatch/presentation/screens/two_to_watch_screen.dart';
import '../../features/feed/domain/social_models.dart';
import '../../features/feed/presentation/screens/activity_feed_screen.dart';
import '../../features/feed/presentation/screens/comment_thread_screen.dart';
import '../../features/logging/domain/title_search_result.dart';
import '../../features/logging/presentation/screens/log_flow_screens.dart';
import '../../features/logging/presentation/screens/logging_studio_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_tournament_screen.dart';
import '../../features/onboarding/presentation/screens/seed_grid_screen.dart';
import '../../features/onboarding/presentation/screens/streaming_setup_screen.dart';
import '../../features/profile/presentation/screens/dual_canon_profile_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_studio_screen.dart';
import '../../features/profile/presentation/screens/friend_profile_screen.dart';
import '../../features/profile/presentation/screens/settings_hub_screen.dart';
import '../../features/profile/presentation/screens/tv_graveyard_screen.dart';
import '../../features/queue/presentation/screens/smart_queue_screen.dart';
import '../../features/sharing/presentation/screens/telly_wrapped_studio_screen.dart';
import '../../features/squads/presentation/screens/squad_hub_screen.dart';
import '../../features/squads/presentation/screens/squads_list_screen.dart';
import '../../features/discovery/presentation/screens/explore_discover_screen.dart';
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

/// The app router (FE-602): auth/onboarding redirects + StatefulShellRoute with four tabs
/// and a center Log action (component spec §2.1). Every spec'd screen is reachable.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen<AuthState>(authControllerProvider, (_, __) => refresh.notify());

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(ref.read(authControllerProvider), state.matchedLocation),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.auth, builder: (_, __) => const AuthScreen()),

      // Onboarding
      GoRoute(path: Routes.handle, builder: (_, __) => const HandleReservationScreen()),
      GoRoute(path: Routes.streamingSetup, builder: (_, __) => const StreamingSetupScreen()),
      GoRoute(path: Routes.seedGrid, builder: (_, __) => const SeedGridScreen()),
      GoRoute(path: Routes.tournament, builder: (_, __) => const OnboardingTournamentScreen()),

      // The four tabs
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.feed,
              builder: (_, __) => const ActivityFeedScreen(),
              routes: [
                GoRoute(
                  path: 'activity/:id',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, state) => state.extra is ActivityLog
                      ? CommentThreadScreen(activity: state.extra! as ActivityLog)
                      : const PendingScreen(title: 'Discussion', ticket: 'FE-607'),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.explore,
              builder: (_, __) => const ExploreDiscoverScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.queue, builder: (_, __) => const SmartQueueScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.canon,
              builder: (context, __) => DualCanonProfileScreen(
                onSettingsTap: () => context.push(Routes.settings),
                onSquadsTap: () => context.push(Routes.squads),
                onTapEntry: (entry) => context.push(Routes.title(entry.mediaType, entry.id)),
              ),
              routes: [
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
        builder: (_, state) => LoggingStudioScreen(
          initialTitle: state.extra is TitleSearchResult ? state.extra! as TitleSearchResult : null,
        ),
        routes: [
          GoRoute(path: 'duel', builder: (_, __) => const LogDuelScreen()),
          GoRoute(path: 'reveal', builder: (_, __) => const LogRevealScreen()),
        ],
      ),

      // Pushed detail screens
      GoRoute(
        path: '/title/:mediaType/:id',
        redirect: (_, state) {
          final mediaType = state.pathParameters['mediaType'];
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          return (mediaType == 'movie' || mediaType == 'tv') && id != null ? null : Routes.feed;
        },
        builder: (_, state) => ShowDetailScreen(
          titleId: int.parse(state.pathParameters['id']!),
          mediaType: state.pathParameters['mediaType']!,
        ),
      ),
      GoRoute(
        path: '/u/:handle',
        redirect: (_, state) {
          final handle = state.pathParameters['handle'];
          final currentUser = ref.read(authControllerProvider).user;
          if (handle != null && currentUser != null && currentUser.username?.toLowerCase() == handle.toLowerCase()) {
            return Routes.canon;
          }
          return null;
        },
        builder: (_, state) => FriendProfileScreen(handle: state.pathParameters['handle']!),
        routes: [
          GoRoute(
            path: 'two-to-watch',
            builder: (_, state) {
              final args = state.extra;
              final handle = state.pathParameters['handle']!;
              return args is FriendRouteArgs
                  ? TwoToWatchScreen(friendId: args.userId, friendHandle: handle, friendDisplayName: args.displayName)
                  : const PendingScreen(title: 'Two-to-Watch', ticket: 'FE-610');
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
