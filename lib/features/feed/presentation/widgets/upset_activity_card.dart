import 'package:flutter/material.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';

/// High-visibility Spicy Upset Alert feed card (FE-303).
///
/// Features Neon Coral branding, dual matchup layout (winner vs loser),
/// controversy consensus statistics, and pulse animation.
class UpsetActivityCard extends StatefulWidget {
  final ActivityLog activity;
  final VoidCallback? onCardTap;
  final VoidCallback? onCommentTap;
  final ValueChanged<FeedReactionType>? onReactionToggle;
  final ValueChanged<bool>? onQueueToggle;

  const UpsetActivityCard({
    super.key,
    required this.activity,
    this.onCardTap,
    this.onCommentTap,
    this.onReactionToggle,
    this.onQueueToggle,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: TellyColors.backgroundCard,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: TellyColors.neonCoral),
          ),
          content: Row(
            children: [
              const Icon(Icons.bookmark_added_rounded, color: TellyColors.neonCoral, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Added to your Watchlist (available on Netflix)',
                  style: TellyTypography.caption(color: TellyColors.textPrimary),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
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
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Author and Headline
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: TellyColors.backgroundCard,
                      child: Text(
                        activity.userDisplayName.isNotEmpty
                            ? activity.userDisplayName[0].toUpperCase()
                            : '?',
                        style: TellyTypography.caption(
                          color: TellyColors.neonCoral,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
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
                      Column(
                        children: [
                          Container(
                            width: 60,
                            height: 85,
                            decoration: BoxDecoration(
                              color: TellyColors.backgroundSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: TellyColors.phosphorLime, width: 2),
                            ),
                            child: const Center(
                              child: Icon(Icons.tv_rounded, color: TellyColors.phosphorLime, size: 28),
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
                      Column(
                        children: [
                          Container(
                            width: 60,
                            height: 85,
                            decoration: BoxDecoration(
                              color: TellyColors.backgroundSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: TellyColors.borderGlass),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.tv_rounded,
                                color: TellyColors.textTertiary.withValues(alpha: 0.6),
                                size: 28,
                              ),
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

                // 6. Action Bar
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 8,
                    children: [
                      _buildQueueButton(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildReactionsRow(activity),
                          const SizedBox(width: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: widget.onCommentTap,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 16,
                                      color: TellyColors.textTertiary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${activity.commentCount}',
                                      style: TellyTypography.caption(
                                        color: TellyColors.textSecondary,
                                      ).copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQueueButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _handleQueueToggle,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _inQueue
                ? TellyColors.neonCoral.withValues(alpha: 0.15)
                : TellyColors.backgroundCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _inQueue ? TellyColors.neonCoral : TellyColors.borderGlass,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _inQueue ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                size: 15,
                color: _inQueue ? TellyColors.neonCoral : TellyColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                _inQueue ? 'In Queue' : '+ Want to Watch',
                style: TellyTypography.caption(
                  color: _inQueue ? TellyColors.neonCoral : TellyColors.textSecondary,
                ).copyWith(fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReactionsRow(ActivityLog activity) {
    final defaultReactions = [
      FeedReactionType.fire,
      FeedReactionType.mindBlown,
      FeedReactionType.trashTake,
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: defaultReactions.map((reaction) {
        final count = activity.reactions[reaction] ?? 0;
        final isSelected = activity.userReactions.contains(reaction);

        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              HapticsService.selectionClick();
              widget.onReactionToggle?.call(reaction);
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? TellyColors.neonCoral.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? TellyColors.neonCoral : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(reaction.emoji, style: const TextStyle(fontSize: 14, color: TellyColors.textPrimary)),
                    if (count > 0) ...[
                      const SizedBox(width: 3),
                      Text(
                        '$count',
                        style: TellyTypography.caption(
                          color: isSelected ? TellyColors.neonCoral : TellyColors.textSecondary,
                        ).copyWith(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
