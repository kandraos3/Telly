import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/queue/data/watchlist_repository.dart';
import '../../features/ranking/data/canon_hydration.dart';
import '../sync/sync_engine.dart';
import '../widgets/telly_floating_nav_bar.dart';
import '../widgets/telly_log_fab.dart';
import 'routes.dart';

/// Scaffold for the tab branches with the floating nav bar and the floating Log button overlaid (FE-602, #44).
///
/// The shell stays mounted under every signed-in screen, so it also keeps the canon
/// hydration (FE-604) and the sync engine (FE-605) alive, and flushes on app resume.
class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  /// Nav bar items, one per branch. The five-tab shell (Home, Explore, Canon, Social, More) lands in #116.
  static const navItems = [
    TellyNavItem(Icons.home_rounded, 'Feed'),
    TellyNavItem(Icons.explore_outlined, 'Explore'),
    TellyNavItem(Icons.collections_bookmark_outlined, 'Queue'),
    TellyNavItem(Icons.movie_filter_outlined, 'Canon'),
  ];

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(syncEngineProvider.notifier).flush(force: true),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(canonHydrationProvider, (_, __) {});
    ref.listen(watchlistHydrationProvider, (_, __) {});
    ref.listen(syncEngineProvider, (_, __) {});
    final shell = widget.navigationShell;
    return Stack(
      children: [
        Scaffold(
          extendBody: true,
          body: shell,
          bottomNavigationBar: TellyFloatingNavBar(
            currentIndex: shell.currentIndex,
            items: AppShell.navItems,
            onTabSelected: (index) => shell.goBranch(
              index,
              // Re-tapping the active tab pops it to its root.
              initialLocation: index == shell.currentIndex,
            ),
          ),
        ),
        Positioned(
          right: TellyLogFab.rightInset,
          bottom: TellyLogFab.bottomOffsetOf(context),
          child: TellyLogFab(onTap: () => context.push(Routes.log)),
        ),
      ],
    );
  }
}
