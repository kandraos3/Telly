import 'package:flutter/material.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_logo.dart';
import '../../domain/reveal_story.dart';

/// 9:16 rank-reveal story (FE-SHARE-01), laid out at 360×640 logical px and captured at 3x
/// (1080×1920) per `docs/adjacent_systems/04_VIRAL_SHARING_AND_EXPORT_STUDIO.md` §2–§3.
/// Typographic only, so it renders offscreen without waiting on network posters.
class RevealStoryCard extends StatelessWidget {
  static const logicalSize = Size(360, 640);

  final RevealStory story;

  const RevealStoryCard({super.key, required this.story});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: logicalSize.width,
      height: logicalSize.height,
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.45),
          radius: 0.9,
          colors: [Color(0xFF1A2210), TellyColors.backgroundPrimary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: TellyWordmark(fontSize: 28)),
          const Spacer(),
          Text(
            'JUST RANKED IN MY ${story.canonLabel.toUpperCase()}',
            textAlign: TextAlign.center,
            style: TellyTypography.labelMedium(color: TellyColors.textTertiary).copyWith(letterSpacing: 1.6),
          ),
          const SizedBox(height: 10),
          Text(
            story.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TellyTypography.displayXL().copyWith(fontSize: 30, height: 1.15),
          ),
          const SizedBox(height: 18),
          Text(
            '#${story.rank}',
            textAlign: TextAlign.center,
            style: TellyTypography.scoreHero().copyWith(fontSize: 88, height: 1),
          ),
          Text(
            'of ${story.total}  ·  ${story.score.toStringAsFixed(2)}  ·  ${story.tierLabel}',
            textAlign: TextAlign.center,
            style: TellyTypography.bodyMedium(color: TellyColors.warmAmber).copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          for (final e in story.leaderboard)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: e.isNew ? TellyColors.phosphorLime.withValues(alpha: 0.14) : TellyColors.backgroundSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: e.isNew ? TellyColors.phosphorLime : TellyColors.borderGlass),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      '#${e.rank}',
                      style: TellyTypography.scoreMono(
                              color: e.isNew ? TellyColors.phosphorLime : TellyColors.textTertiary)
                          .copyWith(fontSize: 14),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TellyTypography.bodyMedium(
                              color: e.isNew ? TellyColors.textPrimary : TellyColors.textSecondary)
                          .copyWith(fontWeight: e.isNew ? FontWeight.w800 : FontWeight.w500),
                    ),
                  ),
                  Text(
                    e.score.toStringAsFixed(2),
                    style:
                        TellyTypography.scoreMono(color: e.isNew ? TellyColors.phosphorLime : TellyColors.textSecondary)
                            .copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
          const Spacer(),
          Text(
            'Rank your own canon on Telly',
            textAlign: TextAlign.center,
            style: TellyTypography.caption(color: TellyColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
