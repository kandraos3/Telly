import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/feed/presentation/widgets/feed_card_actions.dart';
import 'package:telly_app/features/onboarding/data/top_50_seeds.dart';

/// High-visibility Spicy Upset Alert feed card (FE-303).
///
/// Features Neon Coral branding, dual matchup layout (winner vs loser),
/// controversy consensus statistics, and pulse animation.
class UpsetActivityCard extends StatefulWidget {
  final ActivityLog activity;
  final VoidCallback? onCardTap;
  final VoidCallback? onCommentTap;
  final ValueChanged<FeedReaction>? onReactionToggle;
  final ValueChanged<bool>? onQueueToggle;
  final VoidCallback? onTapWinner;
  final VoidCallback? onTapLoser;

  const UpsetActivityCard({
    super.key,
    required this.activity,
    this.onCardTap,
    this.onCommentTap,
    this.onReactionToggle,
    this.onQueueToggle,
    this.onTapWinner,
    this.onTapLoser,
  });

  @override
  State<UpsetActivityCard> createState() => _UpsetActivityCardState();
}

class _UpsetActivityCardState extends State<UpsetActivityCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late bool _inQueue;

  @override
  void initState() {
    super.initState();
    _inQueue = widget.activity.inUserQueue;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _pulseScale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    int pulseCount = 0;
    _pulseController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        pulseCount++;
        if (pulseCount < 2) {
          _pulseController.forward();
        }
      }
    });

    _pulseController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleQueueToggle() {
    HapticsService.lightImpact();
    setState(() {
      _inQueue = !_inQueue;
    });
    widget.onQueueToggle?.call(_inQueue);

    if (_inQueue) {
      ScaffoldMessenger.of(context).showSnackBar(feedQueuedSnackBar(accent: TellyColors.neonCoral));
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: TellyColors.backgroundSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: TellyColors.neonCoral.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: TellyColors.neonCoral.withValues(alpha: 0.12),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onCardTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Prominent Upset Badge Header
                Row(
                  children: [
                    ScaleTransition(
                      scale: _pulseScale,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: TellyColors.neonCoral.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: TellyColors.neonCoral, width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('⚡', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 4),
                            Text(
                              'SPICY UPSET ALERT',
                              style: TellyTypography.caption(
                                color: TellyColors.neonCoral,
                              ).copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      activity.relativeTime,
                      style: TellyTypography.caption(
                        color: TellyColors.textTertiary,
                      ).copyWith(fontSize: 11),
                    ),
                    // Compact "Want to Watch" (FE-FEED-01).
                    FeedBookmarkButton(
                      inQueue: _inQueue,
                      onPressed: _handleQueueToggle,
                      accent: TellyColors.neonCoral,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Author and Headline
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: TellyColors.backgroundCard,
                      backgroundImage: (activity.userAvatarUrl != null && activity.userAvatarUrl!.isNotEmpty)
                          ? NetworkImage(activity.userAvatarUrl!)
                          : null,
                      child: (activity.userAvatarUrl == null || activity.userAvatarUrl!.isEmpty)
                          ? Text(
                              activity.userDisplayName.isNotEmpty
                                  ? activity.userDisplayName[0].toUpperCase()
                                  : '?',
                              style: TellyTypography.caption(
                                color: TellyColors.neonCoral,
                              ).copyWith(fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: RichText(
                        text: TextSpan(
                          style: TellyTypography.bodyMedium(color: TellyColors.textPrimary),
                          children: [
                            TextSpan(
                              text: activity.userDisplayName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const TextSpan(text: ' ranked '),
                            TextSpan(
                              text: activity.titleName.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: TellyColors.phosphorLime,
                              ),
                            ),
                            if (activity.rankPosition != null)
                              TextSpan(text: ' (#${activity.rankPosition})'),
                            const TextSpan(text: ' over '),
                            TextSpan(
                              text: (activity.upsetOverTitleName ?? 'Consensus Titan').toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: TellyColors.textSecondary,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: TellyColors.neonCoral,
                              ),
                            ),
                            if (activity.upsetOverTitleRank != null)
                              TextSpan(text: ' (#${activity.upsetOverTitleRank})'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 3. Head-to-Head Duel Matchup Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TellyColors.backgroundCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: TellyColors.borderGlass),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Winner Card
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticsService.lightImpact();
                          if (widget.onTapWinner != null) {
                            widget.onTapWinner!();
                          } else {
                            context.push(Routes.title(activity.mediaType, activity.titleId));
                          }
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 85,
                              decoration: BoxDecoration(
                                color: TellyColors.backgroundSurface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: TellyColors.phosphorLime, width: 2),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: PosterImage(
                                posterPath: activity.titlePosterUrl ??
                                    TmdbImages.poster(findSeedPoster(activity.titleId, activity.mediaType, activity.titleName)),
                                fallback: const Center(
                                  child: Icon(Icons.tv_rounded, color: TellyColors.phosphorLime, size: 28),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              activity.titleName,
                              style: TellyTypography.caption(
                                color: TellyColors.phosphorLime,
                              ).copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'WINNER • #${activity.rankPosition ?? 1}',
                              style: TellyTypography.caption(
                                color: TellyColors.textTertiary,
                              ).copyWith(fontSize: 10),
                            ),
                          ],
                        ),
                      ),

                      // Central VS Indicator
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: TellyColors.neonCoral.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: TellyColors.neonCoral),
                            ),
                            child: Text(
                              '⚡ OVER',
                              style: TellyTypography.caption(
                                color: TellyColors.neonCoral,
                              ).copyWith(fontWeight: FontWeight.w900, fontSize: 10),
                            ),
                          ),
                        ],
                      ),

                      // Loser Card (Struck through)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          final loserId = activity.upsetOverTitleId ??
                              (activity.upsetOverTitleName != null
                                  ? kTop50SeedTitles
                                      .where((s) => s.title.toLowerCase() == activity.upsetOverTitleName!.toLowerCase())
                                      .firstOrNull
                                      ?.id
                                  : null);
                          if (loserId != null && loserId > 0) {
                            HapticsService.lightImpact();
                            if (widget.onTapLoser != null) {
                              widget.onTapLoser!();
                            } else {
                              context.push(Routes.title(activity.mediaType, loserId));
                            }
                          }
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 85,
                              decoration: BoxDecoration(
                                color: TellyColors.backgroundSurface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: TellyColors.borderGlass),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  PosterImage(
                                    posterPath: activity.upsetOverTitlePoster ??
                                        TmdbImages.poster(findSeedPoster(0, activity.mediaType, activity.upsetOverTitleName)),
                                    fallback: Center(
                                      child: Icon(
                                        Icons.tv_rounded,
                                        color: TellyColors.textTertiary.withValues(alpha: 0.6),
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                  Container(color: Colors.black.withValues(alpha: 0.35)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              activity.upsetOverTitleName ?? 'Titan',
                              style: TellyTypography.caption(
                                color: TellyColors.textTertiary,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '#${activity.upsetOverTitleRank ?? 4}',
                              style: TellyTypography.caption(
                                color: TellyColors.textTertiary,
                              ).copyWith(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Divergence Consensus Stat
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: TellyColors.neonCoral.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: TellyColors.neonCoral.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline_rounded,
                          color: TellyColors.neonCoral, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          // features/04 §3.2: Δ is a percentile gap; 0.25 = 2.5 score points.
                          activity.agreementPercentage != null
                              ? 'Only ${activity.agreementPercentage!.toStringAsFixed(0)}% of Telly users agree with this pick'
                              : 'Community consensus favors ${activity.upsetOverTitleName ?? 'the other title'} '
                                  'by ${(activity.upsetDelta * 10).toStringAsFixed(1)} pts',
                          key: const Key('upset_consensus_text'),
                          textAlign: TextAlign.center,
                          style: TellyTypography.caption(
                            color: TellyColors.neonCoral,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                // 5. Micro-review quote
                if (activity.microReview != null && activity.microReview!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '“${activity.microReview!}”',
                    style: TellyTypography.bodyMedium(
                      color: TellyColors.textSecondary,
                    ).copyWith(fontStyle: FontStyle.italic),
                  ),
                ],

                const SizedBox(height: 14),
                const Divider(color: TellyColors.borderGlass, height: 1),
                const SizedBox(height: 10),

                // 6. Reactions + Comments (FE-FEED-01)
                FeedActionBar(
                  activity: activity,
                  onReactionToggle: widget.onReactionToggle,
                  onCommentTap: widget.onCommentTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
