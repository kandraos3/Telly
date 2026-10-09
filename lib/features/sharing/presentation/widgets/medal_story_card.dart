import 'package:flutter/material.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_logo.dart';
import '../../../achievements/presentation/widgets/medal_badge.dart';
import '../../domain/medal_story.dart';

/// 9:16 medals story (Template E, #138), laid out at 360×640 logical px and captured at 3x
/// (1080×1920) like [RevealStoryCard]: the same canvas, wordmark and footer, with a Warm
/// Amber glow instead of lime. Typographic and vector only, so it renders offscreen.
class MedalStoryCard extends StatelessWidget {
  static const logicalSize = Size(360, 640);

  final MedalStory story;

  const MedalStoryCard({super.key, required this.story});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: logicalSize.width,
      height: logicalSize.height,
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.9,
          colors: [Color(0xFF2A1C08), TellyColors.backgroundPrimary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: TellyWordmark(fontSize: 28)),
          const Spacer(),
          Text(
            story.heading.toUpperCase(),
            textAlign: TextAlign.center,
            style: TellyTypography.labelMedium(color: TellyColors.warmAmber).copyWith(letterSpacing: 1.6),
          ),
          const SizedBox(height: 22),
          if (story.isSingle) ..._single() else _set(),
          const SizedBox(height: 22),
          Text(
            story.line,
            textAlign: TextAlign.center,
            style: TellyTypography.bodyLarge(color: TellyColors.textSecondary).copyWith(height: 1.35),
          ),
          if (story.rarity != null) ...[
            const SizedBox(height: 10),
            Text(
              story.rarity!,
              textAlign: TextAlign.center,
              style: TellyTypography.bodyMedium(color: TellyColors.warmAmber).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
          const Spacer(),
          Text(
            'Build your own rankings on Telly',
            textAlign: TextAlign.center,
            style: TellyTypography.caption(color: TellyColors.textSecondary),
          ),
        ],
      ),
    );
  }

  List<Widget> _single() {
    final m = story.medals.single;
    return [
      Center(child: MedalBadge(tier: m.tier, glyph: m.glyph, unlocked: true, size: MedalSize.large)),
      const SizedBox(height: 20),
      Text(
        m.name,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TellyTypography.displayXL().copyWith(fontSize: 32, height: 1.15),
      ),
    ];
  }

  Widget _set() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final m in story.medals)
          SizedBox(
            width: 96,
            child: Column(
              children: [
                MedalBadge(tier: m.tier, glyph: m.glyph, unlocked: true, size: MedalSize.regular),
                const SizedBox(height: 10),
                Text(
                  m.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TellyTypography.bodyMedium(color: TellyColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
