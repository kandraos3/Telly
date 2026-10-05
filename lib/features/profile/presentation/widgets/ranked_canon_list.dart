import 'package:flutter/material.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/poster_image.dart';
import '../../../ranking/domain/franchise_rollup_service.dart';

/// Mode 1: Ranked Canon List with mathematical tournament calibration.
/// Conforms to:
/// - `docs/features/06_PROFILE_THE_CANON_AND_STATS.md` §3.1
/// - Tickets: FE-207, FE-ALGO-02
class RankedCanonList extends StatelessWidget {
  final List<CanonEntry> entries;
  final ValueChanged<CanonEntry>? onTapEntry;
  final ValueChanged<CanonEntry>? onLongPressEntry;

  const RankedCanonList({
    super.key,
    required this.entries,
    this.onTapEntry,
    this.onLongPressEntry,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'No ranked titles in this Canon yet.\nTap "+" to start ranking!',
            textAlign: TextAlign.center,
            style: TellyTypography.bodyMedium(color: TellyColors.textTertiary),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final item = entries[index];
        final rank = item.rankPosition;
        final isTopThree = rank <= 3;

        return GestureDetector(
          key: ValueKey('ranked_row_${item.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: onTapEntry == null ? null : () => onTapEntry!(item),
          onLongPress: onLongPressEntry == null ? null : () => onLongPressEntry!(item),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: TellyColors.cardOf(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isTopThree ? TellyColors.phosphorLime.withValues(alpha: 0.25) : TellyColors.borderGlassOf(context),
              ),
            ),
            child: Row(
              children: [
                // 1. Rank Number
                SizedBox(
                  width: 38,
                  child: Text(
                    '#$rank',
                    key: Key('rank_text_${item.id}'),
                    style: TellyTypography.scoreChip(
                      color: isTopThree ? TellyColors.phosphorLime : TellyColors.textSecondaryOf(context),
                    ).copyWith(fontSize: 15),
                  ),
                ),

                // 2. Poster Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 36,
                    height: 52,
                    child: PosterImage(
                      posterPath: item.posterPath,
                      fallback: _posterFallback(context, item),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // 3. Title & Metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.title,
                              key: Key('title_text_${item.id}'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context)).copyWith(
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (item.isRolledUp) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: TellyColors.electricViolet.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: TellyColors.electricViolet.withValues(alpha: 0.6),
                                ),
                              ),
                              child: Text(
                                'Franchise',
                                style: TellyTypography.caption(color: TellyColors.electricViolet)
                                    .copyWith(fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      if (item.mvpCharacter != null && item.mvpCharacter!.isNotEmpty) ...[
                        Text(
                          '⭐ ${item.mvpCharacter!}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
                        ),
                      ] else if (item.isRolledUp) ...[
                        Text(
                          'Includes: ${item.seasonBreakdown.map((s) => s.seasonTitle ?? 'S${s.seasonNumber}').join(', ')}',
                          style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // 4. Dynamic Percentile Score Badge
                Container(
                  key: Key('score_pill_${item.id}'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        isTopThree ? TellyColors.phosphorLime.withValues(alpha: 0.15) : TellyColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isTopThree ? TellyColors.phosphorLime : TellyColors.strokeSubtleOf(context),
                    ),
                  ),
                  child: Text(
                    item.calculatedScore.toStringAsFixed(2),
                    style: TellyTypography.scoreMono(
                      color: isTopThree ? TellyColors.phosphorLime : TellyColors.textPrimaryOf(context),
                    ).copyWith(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _posterFallback(BuildContext context, CanonEntry item) {
    return Center(
      child: Icon(
        item.mediaType == 'movie' ? Icons.movie_outlined : Icons.tv_outlined,
        color: TellyColors.textTertiaryOf(context),
        size: 18,
      ),
    );
  }
}
