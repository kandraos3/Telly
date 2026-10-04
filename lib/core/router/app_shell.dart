import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/telly_colors.dart';
import '../widgets/telly_floating_nav_bar.dart';
import 'routes.dart';

/// Scaffold for the four tab branches with the floating nav bar overlaid (FE-602).
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TellyColors.backgroundPrimary,
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: TellyFloatingNavBar(
        currentIndex: navigationShell.currentIndex,
        onTabSelected: (index) => navigationShell.goBranch(
          index,
          // Re-tapping the active tab pops it to its root.
          initialLocation: index == navigationShell.currentIndex,
        ),
        onLogTap: () => context.push(Routes.log),
      ),
    );
  }
}
