import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/haptics_service.dart';
import '../theme/telly_colors.dart';
import '../theme/telly_typography.dart';
import 'telly_floating_nav_bar.dart';

/// Floating Log button — `docs/design_system/02_COMPONENT_LIBRARY_AND_PATTERNS.md` §2.3 (decision 0003).
///
/// Lime extended pill (52 tall, 20 horizontal padding) with a Void `+ Log` in both themes, and a lime halo in
/// dark mode only. Opens the Log flow with a medium haptic.
class TellyLogFab extends StatelessWidget {
  static const double height = 52;
  static const double horizontalPadding = 20;
  static const double rightInset = 20;

  /// Gap between the button's bottom edge and the nav bar's top edge.
  static const double gapAboveNavBar = 16;
  static const double haloBlur = 20;
  static const double haloAlpha = 0.35;

  /// Distance from the screen bottom to the button's bottom edge: the nav bar's bottom inset (safe area,
  /// at least 16), its height, then the gap. Use with the shell's own (un-extended) [MediaQuery].
  static double bottomOffsetOf(BuildContext context) =>
      math.max(MediaQuery.paddingOf(context).bottom, 16) + TellyFloatingNavBar.height + gapAboveNavBar;

  final VoidCallback onTap;

  const TellyLogFab({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      container: true,
      button: true,
      label: 'Log a title',
      child: Container(
        key: const Key('log_fab'),
        height: height,
        decoration: BoxDecoration(
          color: TellyColors.phosphorLime,
          borderRadius: BorderRadius.circular(999),
          boxShadow: dark
              ? [BoxShadow(color: TellyColors.phosphorLime.withValues(alpha: haloAlpha), blurRadius: haloBlur)]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () {
              HapticsService.mediumImpact();
              onTap();
            },
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, size: 20, color: TellyColors.backgroundPrimary),
                    const SizedBox(width: 8),
                    Text(
                      'Log',
                      style: TellyTypography.bodyLarge(color: TellyColors.backgroundPrimary)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
