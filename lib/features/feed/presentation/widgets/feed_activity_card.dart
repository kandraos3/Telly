import 'package:flutter/material.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';

/// Standard activity feed card component (FE-302, FE-304).
///
/// Implements design tokens from design_system/02_COMPONENT_LIBRARY_AND_PATTERNS.md §3.2
/// and SCR-05 specs.
class FeedActivityCard extends StatefulWidget {
  final ActivityLog activity;
  final VoidCallback? onCardTap;
  final VoidCallback? onCommentTap;
  final ValueChanged<FeedReactionType>? onReactionToggle;
  final ValueChanged<bool>? onQueueToggle;

  const FeedActivityCard({
    super.key,
    required this.activity,
    this.onCardTap,
    this.onCommentTap,
    this.onReactionToggle,
    this.onQueueToggle,
  });

  @override
  State<FeedActivityCard> createState() => _FeedActivityCardState();
}

class _FeedActivityCardState extends State<FeedActivityCard> {
  late bool _inQueue;

  @override
  void initState() {
    super.initState();
    _inQueue = widget.activity.inUserQueue;
  }

  @override
  void didUpdateWidget(covariant FeedActivityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity.inUserQueue != widget.activity.inUserQueue) {
      _inQueue = widget.activity.inUserQueue;
    }
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
            side: const BorderSide(color: TellyColors.borderGlass),
          ),
          content: Row(
            children: [
              const Icon(Icons.bookmark_added_rounded, color: TellyColors.phosphorLime, size: 20),
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
        border: Border.all(color: TellyColors.borderGlass),
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
                // 1. Author row & Relative time
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: TellyColors.backgroundCard,
                      child: Text(
                        activity.userDisplayName.isNotEmpty
                            ? activity.userDisplayName[0].toUpperCase()
                            : '?',
                        style: TellyTypography.labelLarge(color: TellyColors.phosphorLime),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  activity.userDisplayName,
                                  style: TellyTypography.labelLarge(
                                    color: TellyColors.textPrimary,
                                  ).copyWith(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '@${activity.username}',
                                style: TellyTypography.caption(
                                  color: TellyColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            activity.relativeTime,
                            style: TellyTypography.caption(
                              color: TellyColors.textTertiary,
                            ).copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Action description
                _buildActionHeadline(activity),
                const SizedBox(height: 12),

                // 3. Media row: Poster + Details + Score
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Poster thumbnail
                    Container(
                      width: 60,
                      height: 90,
                      decoration: BoxDecoration(
                        color: TellyColors.backgroundCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: TellyColors.borderGlass),
                      ),
                      child: Center(
                        child: Icon(
                          activity.mediaType == 'movie'
                              ? Icons.movie_rounded
                              : Icons.tv_rounded,
                          color: TellyColors.textTertiary,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title info & badges
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity.titleName,
                            style: TellyTypography.headlineSmall(
                              color: TellyColors.textPrimary,
                            ).copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (activity.releaseYear != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${activity.releaseYear} • ${activity.mediaType == 'movie' ? 'Film' : 'Series'}',
                              style: TellyTypography.caption(
                                color: TellyColors.textTertiary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (activity.calculatedScore != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: TellyColors.phosphorLime.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: TellyColors.phosphorLime.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          color: TellyColors.phosphorLime, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        activity.calculatedScore!.toStringAsFixed(2),
                                        style: TellyTypography.monoDigits(
                                          color: TellyColors.phosphorLime,
                                        ).copyWith(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              if (activity.culturalTier != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: TellyColors.warmAmber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: TellyColors.warmAmber.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Text(
                                    activity.culturalTier!,
                                    style: TellyTypography.caption(
                                      color: TellyColors.warmAmber,
                                    ).copyWith(fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // 4. MVP Character Chip
                if (activity.favoriteCharacter != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: TellyColors.backgroundCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: TellyColors.borderGlass),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars_rounded, color: TellyColors.warmAmber, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'MVP: ${activity.favoriteCharacter!}',
                          style: TellyTypography.caption(
                            color: TellyColors.textSecondary,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],

                // 5. Vibe tags chips
                if (activity.vibeTags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: activity.vibeTags.map((tag) {
                      return Text(
                        '#$tag',
                        style: TellyTypography.caption(
                          color: TellyColors.electricCyan,
                        ).copyWith(fontWeight: FontWeight.w500),
                      );
                    }).toList(),
                  ),
                ],

                // 6. Micro-review text
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

                // 7. Action Bar: 1-Tap Queue Button + Reactions + Comments
                Row(
                  children: [
                    // 1-Tap Queue Button (FE-304)
                    _buildQueueButton(),
                    const Spacer(),

                    // Reactions Row
                    _buildReactionsRow(activity),
                    const SizedBox(width: 12),

                    // Comments Bubble
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: widget.onCommentTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
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
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionHeadline(ActivityLog activity) {
    if (activity.activityType == ActivityType.showDropped) {
      return Text(
        'Dropped at S${activity.droppedSeason ?? 1}:E${activity.droppedEpisode ?? 1} • Reason: “${activity.dropReason ?? 'Lost interest'}”',
        style: TellyTypography.bodyMedium(
          color: TellyColors.neonCoral,
        ).copyWith(fontWeight: FontWeight.w600),
      );
    }

    final canonName = activity.mediaType == 'movie' ? 'Movie Canon' : 'Series Canon';
    final rankText = activity.rankPosition != null ? 'at #${activity.rankPosition}' : '';
    return Text(
      'Ranked ${activity.titleName} $rankText in $canonName',
      style: TellyTypography.bodyMedium(
        color: TellyColors.textPrimary,
      ).copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _buildQueueButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _handleQueueToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _inQueue
              ? TellyColors.phosphorLime.withValues(alpha: 0.15)
              : TellyColors.backgroundCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _inQueue ? TellyColors.phosphorLime : TellyColors.borderGlass,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _inQueue ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
              size: 15,
              color: _inQueue ? TellyColors.phosphorLime : TellyColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              _inQueue ? 'In Queue' : '+ Want to Watch',
              style: TellyTypography.caption(
                color: _inQueue ? TellyColors.phosphorLime : TellyColors.textSecondary,
              ).copyWith(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ],
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? TellyColors.phosphorLime.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? TellyColors.phosphorLime : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(reaction.emoji, style: const TextStyle(fontSize: 14)),
                  if (count > 0) ...[
                    const SizedBox(width: 3),
                    Text(
                      '$count',
                      style: TellyTypography.caption(
                        color: isSelected ? TellyColors.phosphorLime : TellyColors.textSecondary,
                      ).copyWith(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
