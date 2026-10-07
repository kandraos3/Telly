import 'package:flutter/material.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/poster_image.dart';
import '../../domain/streaming_models.dart';

/// SCR-13 compact queue row (epic #47): a 40 × 58 poster, the title, a meta line with the
/// friends' average, and one ▶ <provider> action. Tapping the row opens the title.
class QueueRow extends StatelessWidget {
  final WatchlistItem item;
  final String providerName;
  final VoidCallback onTap;
  final VoidCallback onWatch;

  const QueueRow({
    super.key,
    required this.item,
    required this.providerName,
    required this.onTap,
    required this.onWatch,
  });

  @override
  Widget build(BuildContext context) {
    final length = item.mediaType == 'movie'
        ? '${item.runtimeMinutes ?? 120} min'
        : '${item.seasonCount ?? 1} ${(item.seasonCount ?? 1) == 1 ? 'season' : 'seasons'}';
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: TellyColors.strokeSubtleOf(context))),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 40,
                height: 58,
                child: PosterImage(
                  posterPath: item.posterPath,
                  fallback: Container(
                    color: TellyColors.cardOf(context),
                    alignment: Alignment.center,
                    child: Icon(
                      item.mediaType == 'movie' ? Icons.movie_outlined : Icons.tv_outlined,
                      color: TellyColors.textTertiaryOf(context),
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(context))
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      text: length,
                      children: [
                        if (item.friendsAvgScore > 0)
                          TextSpan(
                            text: ' · ★ ${item.friendsAvgScore.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: TellyColors.warmAmberOf(context),
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
                  ),
                  if (item.isLeavingSoon) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: TellyColors.neonCoralOf(context).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'LEAVING SOON',
                        style: TellyTypography.caption(color: TellyColors.neonCoralOf(context))
                            .copyWith(fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'Watch ${item.title} on $providerName',
              excludeSemantics: true,
              child: GestureDetector(
                key: ValueKey('queue_row_watch_${item.showId}'),
                behavior: HitTestBehavior.opaque,
                onTap: onWatch,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Center(
                    widthFactor: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                      decoration: BoxDecoration(
                        color: TellyColors.cardOf(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: TellyColors.borderGlassOf(context)),
                      ),
                      child: Text(
                        '▶ $providerName',
                        style: TellyTypography.labelMedium(color: TellyColors.textPrimaryOf(context))
                            .copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
