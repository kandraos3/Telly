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
/// Height 64, 16 horizontal margin, radius 32, `#11131A` @ 75% with a 24 blur, 1px `#242938` stroke.
/// Center action: Phosphor Lime hexagon raised 6px with a 12px halo. Active tab: white icon + phosphor dot.
class TellyFloatingNavBar extends StatelessWidget {
  static const double height = 64;
  static const double horizontalMargin = 16;
  static const double radius = 32;
  static const double blurSigma = 24;
  static const double centerLift = 6;
  static const double haloBlur = 12;

  static const leftItems = [TellyNavItem(Icons.home_rounded, 'Feed'), TellyNavItem(Icons.explore_outlined, 'Explore')];
  static const rightItems = [
    TellyNavItem(Icons.collections_bookmark_outlined, 'Queue'),
    TellyNavItem(Icons.movie_filter_outlined, 'Canon'),
  ];

  /// Index into the four tab branches (Feed, Explore, Queue, Canon).
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onLogTap;

  const TellyFloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onLogTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 16), // suspended above the home indicator
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: horizontalMargin),
        child: SizedBox(
          height: height + centerLift,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              ClipRRect(
                key: const Key('nav_bar_surface'),
                borderRadius: BorderRadius.circular(radius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: TellyColors.surfaceOf(context).withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(radius),
                      border: Border.all(color: TellyColors.strokeOf(context)),
                    ),
                    child: Row(
                      children: [
                        for (var i = 0; i < leftItems.length; i++) _tab(context, leftItems[i], i),
                        const Expanded(child: SizedBox()),
                        for (var i = 0; i < rightItems.length; i++) _tab(context, rightItems[i], i + leftItems.length),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: (height - 52) / 2 + centerLift,
                child: _LogButton(onTap: onLogTap),
              ),
            ],
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

class _LogButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Log a show',
      child: GestureDetector(
        key: const Key('nav_log_button'),
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: TellyColors.phosphorLime.withValues(alpha: 0.45),
                blurRadius: TellyFloatingNavBar.haloBlur,
              ),
            ],
            shape: BoxShape.circle,
          ),
          child: ClipPath(
            clipper: _HexagonClipper(),
            child: const ColoredBox(
              color: TellyColors.phosphorLime,
              child: Center(child: Icon(Icons.add, color: TellyColors.backgroundPrimary, size: 28)),
            ),
          ),
        ),
      ),
    );
  }
}

class _HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    return Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.25)
      ..lineTo(w, h * 0.75)
      ..lineTo(w * 0.5, h)
      ..lineTo(0, h * 0.75)
      ..lineTo(0, h * 0.25)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
