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

/// Standard activity feed card component (FE-302, FE-304).
///
/// Implements design tokens from design_system/02_COMPONENT_LIBRARY_AND_PATTERNS.md §3.2
/// and SCR-05 specs.
class FeedActivityCard extends StatefulWidget {
  final ActivityLog activity;
  final VoidCallback? onCardTap;
  final VoidCallback? onCommentTap;
  final ValueChanged<FeedReaction>? onReactionToggle;
  final ValueChanged<bool>? onQueueToggle;
  final VoidCallback? onTapTitle;

  const FeedActivityCard({
    super.key,
    required this.activity,
    this.onCardTap,
    this.onCommentTap,
    this.onReactionToggle,
    this.onQueueToggle,
    this.onTapTitle,
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
      ScaffoldMessenger.of(context).showSnackBar(feedQueuedSnackBar());
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TellyColors.borderGlassOf(context)),
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
                      backgroundColor: TellyColors.cardOf(context),
                      backgroundImage: (activity.userAvatarUrl != null && activity.userAvatarUrl!.isNotEmpty)
                          ? NetworkImage(activity.userAvatarUrl!)
                          : null,
                      child: (activity.userAvatarUrl == null || activity.userAvatarUrl!.isEmpty)
                          ? Text(
                              activity.userDisplayName.isNotEmpty
                                  ? activity.userDisplayName[0].toUpperCase()
                                  : '?',
                              style: TellyTypography.labelLarge(color: TellyColors.primaryAccentOf(context)),
                            )
                          : null,
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
                                    color: TellyColors.textPrimaryOf(context),
                                  ).copyWith(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '@${activity.username}',
                                style: TellyTypography.caption(
                                  color: TellyColors.textTertiaryOf(context),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            activity.relativeTime,
                            style: TellyTypography.caption(
                              color: TellyColors.textTertiaryOf(context),
                            ).copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    // Compact "Want to Watch" (FE-FEED-01).
                    FeedBookmarkButton(inQueue: _inQueue, onPressed: _handleQueueToggle),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Action description
                _buildActionHeadline(activity),
                // "Spooktober 2 of 8" for a ranking inside a joined challenge (#144).
                if (activity.challengeContext case final ctx?) ...[
                  const SizedBox(height: 4),
                  Row(
                    key: const Key('feed_card_challenge_context'),
                    children: [
                      Icon(Icons.flag_outlined, size: 14, color: TellyColors.electricCyanOf(context)),
                      const SizedBox(width: 4),
                      Text(
                        ctx.label,
                        style: TellyTypography.caption(color: TellyColors.electricCyanOf(context))
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),

                // 3. Media row: Poster + Details + Score
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticsService.lightImpact();
                    if (widget.onTapTitle != null) {
                      widget.onTapTitle!();
                    } else {
                      context.push(Routes.title(activity.mediaType, activity.titleId));
                    }
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Poster thumbnail
                      Container(
                        width: 60,
                        height: 90,
                        decoration: BoxDecoration(
                          color: TellyColors.cardOf(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: TellyColors.borderGlassOf(context)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: PosterImage(
                          posterPath: activity.titlePosterUrl ??
                              TmdbImages.poster(findSeedPoster(activity.titleId, activity.mediaType, activity.titleName)),
                          fallback: Center(
                            child: Icon(
                              activity.mediaType == 'movie'
                                  ? Icons.movie_rounded
                                  : Icons.tv_rounded,
                              color: TellyColors.textTertiaryOf(context),
                              size: 28,
                            ),
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
                                color: TellyColors.textPrimaryOf(context),
                              ).copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (activity.releaseYear != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                '${activity.releaseYear} • ${activity.mediaType == 'movie' ? 'Film' : 'Series'}',
                                style: TellyTypography.caption(
                                  color: TellyColors.textTertiaryOf(context),
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
                                      color: TellyColors.primaryAccentOf(context).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: TellyColors.primaryAccentOf(context).withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.star_rounded,
                                            color: TellyColors.primaryAccentOf(context), size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          activity.calculatedScore!.toStringAsFixed(2),
                                          style: TellyTypography.monoDigits(
                                            color: TellyColors.primaryAccentOf(context),
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
                                      color: TellyColors.warmAmberOf(context).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: TellyColors.warmAmberOf(context).withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: Text(
                                      activity.culturalTier!,
                                      style: TellyTypography.caption(
                                        color: TellyColors.warmAmberOf(context),
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
                ),

                // 4. MVP Character Chip
                if (activity.favoriteCharacter != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: TellyColors.cardOf(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: TellyColors.borderGlassOf(context)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.stars_rounded, color: TellyColors.warmAmberOf(context), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'MVP: ${activity.favoriteCharacter!}',
                          style: TellyTypography.caption(
                            color: TellyColors.textPrimaryOf(context),
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
                          color: TellyColors.electricCyanOf(context),
                        ).copyWith(fontWeight: FontWeight.w600),
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
                      color: TellyColors.textPrimaryOf(context),
                    ).copyWith(fontStyle: FontStyle.italic),
                  ),
                ],

                const SizedBox(height: 14),
                Divider(color: TellyColors.borderGlassOf(context), height: 1),
                const SizedBox(height: 10),

                // 7. Reactions + Comments (FE-FEED-01)
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

  Widget _buildActionHeadline(ActivityLog activity) {
    if (activity.activityType == ActivityType.showDropped) {
      return Text(
        'Dropped at S${activity.droppedSeason ?? 1}:E${activity.droppedEpisode ?? 1} • Reason: “${activity.dropReason ?? 'Lost interest'}”',
        style: TellyTypography.bodyMedium(
          color: TellyColors.neonCoralOf(context),
        ).copyWith(fontWeight: FontWeight.w600),
      );
    }

    final canonName = activity.mediaType == 'movie' ? 'Movie Canon' : 'Series Canon';
    final rankText = activity.rankPosition != null ? 'at #${activity.rankPosition}' : '';
    return Text(
      'Ranked ${activity.titleName} $rankText in $canonName',
      style: TellyTypography.bodyMedium(
        color: TellyColors.textPrimaryOf(context),
      ).copyWith(fontWeight: FontWeight.w600),
    );
  }
}
