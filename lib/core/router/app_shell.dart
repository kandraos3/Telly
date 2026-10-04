import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/queue/data/watchlist_repository.dart';
import '../../features/ranking/data/canon_hydration.dart';
import '../sync/sync_engine.dart';
import '../theme/telly_colors.dart';
import '../widgets/telly_floating_nav_bar.dart';
import 'routes.dart';

/// Scaffold for the four tab branches with the floating nav bar overlaid (FE-602).
///
/// The shell stays mounted under every signed-in screen, so it also keeps the canon
/// hydration (FE-604) and the sync engine (FE-605) alive, and flushes on app resume.
class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

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
    return Scaffold(
      backgroundColor: TellyColors.backgroundPrimary,
      extendBody: true,
      body: shell,
      bottomNavigationBar: TellyFloatingNavBar(
        currentIndex: shell.currentIndex,
        onTabSelected: (index) => shell.goBranch(
          index,
          // Re-tapping the active tab pops it to its root.
          initialLocation: index == shell.currentIndex,
        ),
        onLogTap: () => context.push(Routes.log),
      ),
    );
  }
}
