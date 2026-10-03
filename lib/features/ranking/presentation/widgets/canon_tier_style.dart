import 'package:flutter/material.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/widgets/telly_neon_badge.dart';
import '../../domain/canon_tier.dart';

/// Visual tokens for [CanonTier] per Style Guide §2.2 (Tier Badge Color Palette).
extension CanonTierStyle on CanonTier {
  Color get gradientStart => switch (this) {
        CanonTier.god => TellyColors.tierGodStart,
        CanonTier.prestige => TellyColors.tierPrestigeStart,
        CanonTier.great => TellyColors.tierGreatStart,
        CanonTier.good => TellyColors.tierGoodStart,
        CanonTier.mid => TellyColors.tierMidStart,
        CanonTier.dropped => TellyColors.tierDroppedStart,
      };

  Color get gradientEnd => switch (this) {
        CanonTier.god => TellyColors.tierGodEnd,
        CanonTier.prestige => TellyColors.tierPrestigeEnd,
        CanonTier.great => TellyColors.tierGreatEnd,
        CanonTier.good => TellyColors.tierGoodEnd,
        CanonTier.mid => TellyColors.tierMidEnd,
        CanonTier.dropped => TellyColors.tierDroppedEnd,
      };

  /// Single accent used for text, borders and badges.
  Color get accent => this == CanonTier.god ? TellyColors.warmAmber : gradientStart;

  LinearGradient get gradient => LinearGradient(colors: [gradientStart, gradientEnd]);

  /// e.g. `👑 GOD TIER`
  String get badgeLabel => '$emoji ${label.toUpperCase()}';

  /// e.g. `✨ PRESTIGE TIER (8.50 – 9.19)`
  String get headerLabel => '$badgeLabel ($rangeLabel)';
}

/// Neon pill showing a score's tier.
class CanonTierBadge extends StatelessWidget {
  final CanonTier tier;

  const CanonTierBadge({super.key, required this.tier});

  @override
  Widget build(BuildContext context) {
    return TellyNeonBadge(
      label: tier.badgeLabel,
      color: tier.accent,
      variant: tier == CanonTier.god ? TellyBadgeVariant.godTier : TellyBadgeVariant.neutral,
    );
  }
}
