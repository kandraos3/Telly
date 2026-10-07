import 'package:flutter/material.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/poster_image.dart';
import '../../../ranking/domain/franchise_rollup_service.dart';
import '../../../ranking/presentation/widgets/canon_tier_style.dart';

/// SCR-14 Ranked view podium (epic #47, decision 0004): ranks #1–#3 as poster cards in
/// one bottom-aligned row (1.25fr / 1fr / 1fr). With fewer than three titles only those
/// cards are drawn, in the same columns. The list continues from #4 below it.
class CanonPodium extends StatelessWidget {
  /// The canon's first entries in rank order; only the first three are shown.
  final List<CanonEntry> entries;
  final ValueChanged<CanonEntry>? onTapEntry;
  final ValueChanged<CanonEntry>? onLongPressEntry;

  const CanonPodium({super.key, required this.entries, this.onTapEntry, this.onLongPressEntry});

  static const _flex = [5, 4, 4];
  static const _posterHeights = [170.0, 132.0, 132.0];

  @override
  Widget build(BuildContext context) {
    final top = entries.take(3).toList();
    return Padding(
      key: const Key('canon_podium'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              flex: _flex[i],
              child: i < top.length
                  ? _PodiumCard(
                      entry: top[i],
                      place: i + 1,
                      posterHeight: _posterHeights[i],
                      onTap: onTapEntry,
                      onLongPress: onLongPressEntry,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final CanonEntry entry;
  final int place;
  final double posterHeight;
  final ValueChanged<CanonEntry>? onTap;
  final ValueChanged<CanonEntry>? onLongPress;

  const _PodiumCard({
    required this.entry,
    required this.place,
    required this.posterHeight,
    this.onTap,
    this.onLongPress,
  });

  /// The rank tag sits on a fixed lime fill, so its colours don't change with the theme.
  static const _tagFill = TellyColors.phosphorLime;
  static const _tagText = Color(0xFF08090C);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '#$place, ${entry.title}, ${entry.calculatedScore.toStringAsFixed(2)}',
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('podium_card_${entry.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null ? null : () => onTap!(entry),
        onLongPress: onLongPress == null ? null : () => onLongPress!(entry),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: TellyColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TellyColors.borderGlassOf(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: posterHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PosterImage(
                      posterPath: entry.posterPath,
                      fallback: Container(
                        color: TellyColors.cardOf(context),
                        alignment: Alignment.center,
                        child: Icon(
                          entry.mediaType == 'movie' ? Icons.movie_outlined : Icons.tv_outlined,
                          color: TellyColors.textTertiaryOf(context),
                          size: 28,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: _tagFill, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          '#$place',
                          style: TellyTypography.labelMedium(color: _tagText).copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TellyTypography.labelLarge(color: TellyColors.textPrimaryOf(context))
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    CanonTierScoreChip(score: entry.calculatedScore),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
