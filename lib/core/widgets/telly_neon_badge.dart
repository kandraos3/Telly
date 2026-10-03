import 'package:flutter/material.dart';
import '../theme/telly_colors.dart';
import '../theme/telly_typography.dart';

enum TellyBadgeVariant {
  upset,
  winner,
  godTier,
  tasteMatch,
  neutral,
}

/// Pill container with glowing outline for upsets, winners, and tier indicators.
/// Conforms to `docs/design_system/02_COMPONENT_LIBRARY_AND_PATTERNS.md` §5.3.
class TellyNeonBadge extends StatelessWidget {
  final String label;
  final Widget? icon;
  final TellyBadgeVariant variant;
  final bool enableGlow;
  final EdgeInsetsGeometry padding;

  /// Overrides the variant color (e.g. canon tier accents).
  final Color? color;

  const TellyNeonBadge({
    super.key,
    required this.label,
    this.icon,
    this.variant = TellyBadgeVariant.winner,
    this.enableGlow = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    this.color,
  });

  factory TellyNeonBadge.upset({Key? key, String label = 'UPSET', Widget? icon}) =>
      TellyNeonBadge(
        key: key,
        label: label,
        icon: icon ?? const Icon(Icons.bolt, size: 13, color: TellyColors.neonCoral),
        variant: TellyBadgeVariant.upset,
      );

  factory TellyNeonBadge.winner({Key? key, String label = 'WINNER', Widget? icon}) =>
      TellyNeonBadge(
        key: key,
        label: label,
        icon: icon ?? const Icon(Icons.check, size: 13, color: TellyColors.phosphorLime),
        variant: TellyBadgeVariant.winner,
      );

  factory TellyNeonBadge.godTier({Key? key, String label = 'GOD TIER', Widget? icon}) =>
      TellyNeonBadge(
        key: key,
        label: label,
        icon: icon ?? const Text('👑', style: TextStyle(fontSize: 11)),
        variant: TellyBadgeVariant.godTier,
      );

  Color _badgeColor() {
    if (color != null) return color!;
    switch (variant) {
      case TellyBadgeVariant.upset:
        return TellyColors.neonCoral;
      case TellyBadgeVariant.winner:
        return TellyColors.phosphorLime;
      case TellyBadgeVariant.godTier:
        return TellyColors.warmAmber;
      case TellyBadgeVariant.tasteMatch:
        return TellyColors.electricViolet;
      case TellyBadgeVariant.neutral:
        return TellyColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _badgeColor();

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.8),
          width: 1.0,
        ),
        boxShadow: enableGlow
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 10.0,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: TellyTypography.caption(color: color).copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

