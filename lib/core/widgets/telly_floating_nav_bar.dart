import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/telly_colors.dart';
import '../theme/telly_typography.dart';

class TellyNavItem {
  final IconData icon;
  final String label;
  const TellyNavItem(this.icon, this.label);
}

/// Floating frosted pill navigation bar — `docs/design_system/02_COMPONENT_LIBRARY_AND_PATTERNS.md` §2.1.
///
/// Height 64, 16 horizontal margin, radius 32, 24 blur, 1px stroke. Surface `#11131A` @ 75% (dark) or
/// `#FFFFFF` @ 90% (light). Five equal destinations, no centre action (the Log button is [TellyLogFab], §2.3).
/// Active tab: primary text colour + phosphor dot; inactive tabs: tertiary text.
class TellyFloatingNavBar extends StatelessWidget {
  static const double height = 64;
  static const double horizontalMargin = 16;
  static const double radius = 32;
  static const double blurSigma = 24;
  static const double darkSurfaceAlpha = 0.75;
  static const double lightSurfaceAlpha = 0.9;

  /// The five shell destinations (decision 0003): Home, Explore, Canon, Social, More.
  static const defaultItems = [
    TellyNavItem(Icons.home_rounded, 'Home'),
    TellyNavItem(Icons.explore_outlined, 'Explore'),
    TellyNavItem(Icons.movie_filter_outlined, 'Canon'),
    TellyNavItem(Icons.people_outline_rounded, 'Social'),
    TellyNavItem(Icons.grid_view_rounded, 'More'),
  ];

  /// Index into [items], which mirror the shell's branches.
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final List<TellyNavItem> items;

  const TellyFloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    this.items = defaultItems,
  });

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 16), // suspended above the home indicator
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: horizontalMargin),
        child: ClipRRect(
          key: const Key('nav_bar_surface'),
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: TellyColors.surfaceOf(context).withValues(alpha: light ? lightSurfaceAlpha : darkSurfaceAlpha),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: TellyColors.strokeOf(context)),
              ),
              child: Row(
                children: [for (var i = 0; i < items.length; i++) _tab(context, items[i], i)],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, TellyNavItem item, int index) {
    final active = index == currentIndex;
    final activeColor = TellyColors.textPrimaryOf(context);
    final inactiveColor = TellyColors.textTertiaryOf(context);
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: item.label,
        child: InkResponse(
          key: Key('nav_tab_${item.label.toLowerCase()}'),
          onTap: () => onTabSelected(index),
          child: SizedBox(
            height: height,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, size: 22, color: active ? activeColor : inactiveColor),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  style: TellyTypography.caption(color: active ? activeColor : inactiveColor),
                ),
                const SizedBox(height: 3),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: active ? 1 : 0,
                  child: Container(
                    key: active ? const Key('nav_active_dot') : null,
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: TellyColors.primaryAccentOf(context),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
