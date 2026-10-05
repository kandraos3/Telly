import 'package:flutter/material.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/features/discovery/domain/discovery_models.dart';
import 'package:telly_app/features/queue/domain/streaming_models.dart';

/// Algorithmic pick between SCR-05 posts (FE-FEED-02): why it's recommended, where it
/// streams, and one-tap Add to Queue / Rate & Rank.
class FeedRecommendationCard extends StatelessWidget {
  const FeedRecommendationCard({
    super.key,
    required this.title,
    required this.queued,
    required this.onOpen,
    required this.onQueue,
    required this.onRank,
  });

  final RecommendedTitle title;
  final bool queued;
  final VoidCallback onOpen;
  final VoidCallback onQueue;
  final VoidCallback onRank;

  /// "Because you loved Succession" / "Trending on Telly".
  String get headline => title.reasonLabel;

  /// "Industry (HBO) is streaming on Max" — only facts we have.
  String get detail {
    final name = title.network != null && title.network!.isNotEmpty && title.mediaType == 'tv'
        ? '${title.title} (${title.network})'
        : title.title;
    if (title.providers.isEmpty) return name;
    final services = title.providers.take(2).map(StreamingPlatform.labelFor).join(' & ');
    return '$name is streaming on $services';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TellyColors.electricViolet.withValues(alpha: 0.45)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 14, color: TellyColors.electricViolet),
                    const SizedBox(width: 6),
                    Text(
                      'PICKED FOR YOU',
                      style: TellyTypography.labelSmall(color: TellyColors.electricViolet)
                          .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.1),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 60,
                        height: 90,
                        color: TellyColors.cardOf(context),
                        child: PosterImage(
                          posterPath: title.posterPath,
                          fallback: Icon(
                            title.mediaType == 'movie' ? Icons.movie_rounded : Icons.tv_rounded,
                            color: TellyColors.textTertiaryOf(context),
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
                            headline,
                            style: TellyTypography.labelLarge(color: TellyColors.textPrimaryOf(context))
                                .copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(detail, style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context))),
                          if (title.communityScore != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              '★ ${title.communityScore!.toStringAsFixed(1)} on Telly',
                              style: TellyTypography.caption(color: TellyColors.warmAmber)
                                  .copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: Key('feed_rec_queue_${title.titleId}'),
                        onPressed: queued ? null : onQueue,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: TellyColors.phosphorLime,
                          disabledForegroundColor: TellyColors.phosphorLime,
                          side: BorderSide(color: TellyColors.phosphorLime.withValues(alpha: 0.5)),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: Icon(queued ? Icons.bookmark_rounded : Icons.bookmark_add_outlined, size: 18),
                        label: Text(queued ? 'In Queue' : 'Add to Queue'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: Key('feed_rec_rank_${title.titleId}'),
                        onPressed: onRank,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: TellyColors.textPrimaryOf(context),
                          side: BorderSide(color: TellyColors.strokeSubtleOf(context)),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.leaderboard_outlined, size: 18),
                        label: const Text('Rate / Rank'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
