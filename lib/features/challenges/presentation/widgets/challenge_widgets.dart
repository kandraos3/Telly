import 'package:flutter/material.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../achievements/domain/medal.dart';
import '../../../achievements/presentation/widgets/medal_badge.dart';
import '../../domain/challenge.dart';

/// Challenge art: a fixed dark gradient per `art` key (content/README.md), the same in both
/// themes because text on it is always light (mockup C1).
abstract final class ChallengeArt {
  static const _gradients = {
    'horror': (Color(0xFF5B1A2A), Color(0xFF120609)),
    'noir': (Color(0xFF3A3A44), Color(0xFF0B0B0F)),
    'gold': (Color(0xFF7A5A12), Color(0xFF1A1306)),
    'cyan': (Color(0xFF0B4F5C), Color(0xFF061418)),
    'violet': (Color(0xFF3B2A7A), Color(0xFF0E0A1F)),
    'coral': (Color(0xFF6B1F2E), Color(0xFF170709)),
    'lime': (Color(0xFF3F5A12), Color(0xFF0D1405)),
  };

  static LinearGradient of(String art) {
    final (a, b) = _gradients[art] ?? _gradients['gold']!;
    return LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a, b], stops: const [0, 0.7]);
  }
}

/// A challenge's medal: gold with its glyph, locked until finished.
class ChallengeMedal extends StatelessWidget {
  final Challenge challenge;
  final MedalSize size;
  const ChallengeMedal({super.key, required this.challenge, this.size = MedalSize.small});

  @override
  Widget build(BuildContext context) => MedalBadge(
        tier: MedalTier.gold,
        glyph: challenge.medalGlyph,
        unlocked: challenge.isCompleted,
        size: size,
      );
}

/// Lime pill button used for Join and + Queue (mockups C1, C2).
class LimePill extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const LimePill({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = TellyColors.primaryAccentOf(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          child: Text(label, style: TellyTypography.labelMedium(color: accent).copyWith(fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

/// Neutral outline chip ("Squad").
class OutlineChip extends StatelessWidget {
  final String label;
  const OutlineChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: TellyColors.strokeStrongOf(context)),
        ),
        child: Text(label, style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context))),
      );
}

/// A thin progress bar in the primary accent (or amber once finished).
class ChallengeBar extends StatelessWidget {
  final double value;
  final bool done;
  final double height;
  const ChallengeBar({super.key, required this.value, this.done = false, this.height = 6});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: LinearProgressIndicator(
          value: value,
          minHeight: height,
          color: done ? TellyColors.warmAmberOf(context) : TellyColors.primaryAccentOf(context),
          backgroundColor: TellyColors.strokeOf(context),
        ),
      );
}
