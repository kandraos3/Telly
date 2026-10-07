import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/core/widgets/telly_screen_header.dart';
import 'package:telly_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:telly_app/features/onboarding/data/top_50_seeds.dart';
import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/feed/presentation/controllers/feed_controllers.dart';
import 'package:telly_app/features/feed/presentation/widgets/moderation_sheet.dart';
import 'package:telly_app/features/feed/presentation/widgets/spoiler_mask.dart';
import 'package:telly_app/features/achievements/presentation/widgets/medal_badge.dart';

/// SCR-06: Post Detail & Spoiler-Safe Comment Thread (FE-305).
///
/// Features frosted Gaussian blur on comments containing spoilers,
/// tap-to-reveal interaction, and spoiler tagging on the composer.
/// FE-607: comments and the composer live in [CommentsController] /
/// [CommentComposerController]; long-press a comment to report or block its author.
class CommentThreadScreen extends ConsumerStatefulWidget {
  final ActivityLog activity;

  const CommentThreadScreen({super.key, required this.activity});

  @override
  ConsumerState<CommentThreadScreen> createState() => _CommentThreadScreenState();
}

class _CommentThreadScreenState extends ConsumerState<CommentThreadScreen> {
  final TextEditingController _commentController = TextEditingController();

  String get _activityId => widget.activity.id;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitComment() async {
    final posted = await ref.read(commentComposerProvider(_activityId).notifier).submit(_commentController.text);
    if (posted) {
      _commentController.clear();
      HapticsService.mediumImpact();
    } else if (mounted) {
      final error = ref.read(commentComposerProvider(_activityId)).error;
      if (error != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  void _openModeration(RankingComment comment) {
    if (comment.userId == ref.read(authControllerProvider).user?.id) return; // not for my own comments
    showModerationSheet(
      context: context,
      ref: ref,
      target: ReportTarget.comment,
      targetId: comment.id,
      authorId: comment.userId,
      authorHandle: comment.username,
      onReported: () => ref.read(commentsControllerProvider(_activityId).notifier).hideComment(comment.id),
      onBlocked: () {
        ref.read(commentsControllerProvider(_activityId).notifier).hideUser(comment.userId);
        for (final filter in FeedFilter.values) {
          if (ref.exists(feedControllerProvider(filter))) {
            ref.read(feedControllerProvider(filter).notifier).hideUser(comment.userId);
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsControllerProvider(_activityId));

    return Scaffold(
      backgroundColor: TellyColors.canvasOf(context),
      appBar: TellySubpageAppBar(
        nav: TellyNavKind.close,
        title: 'Comments',
        onNav: () => Navigator.of(context).pop(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Original Activity Summary Card
            _buildPostSummaryCard(),

            Divider(color: TellyColors.borderGlassOf(context), height: 1),

            // 2. Comments Thread List
            Expanded(
              child: commentsAsync.when(
                data: (comments) {
                  if (comments.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 40,
                            color: TellyColors.textTertiaryOf(context),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No comments yet. Be the first to share your take!',
                            style: TellyTypography.bodyMedium(
                              color: TellyColors.textPrimaryOf(context),
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: comments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      return _buildCommentRow(comment);
                    },
                  );
                },
                loading: () => Center(
                  child: CircularProgressIndicator(color: TellyColors.primaryAccentOf(context)),
                ),
                error: (e, _) => Center(
                  child: Text("Couldn't load comments.", style: TellyTypography.bodyMedium()),
                ),
              ),
            ),

            // 3. Bottom Comment Composer with Spoiler Toggle
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildPostSummaryCard() {
    final activity = widget.activity;
    return InkWell(
      onTap: () => context.push(Routes.title(activity.mediaType, activity.titleId)),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: TellyColors.surfaceOf(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: TellyColors.cardOf(context),
              backgroundImage: (activity.userAvatarUrl != null && activity.userAvatarUrl!.isNotEmpty)
                  ? NetworkImage(activity.userAvatarUrl!)
                  : null,
              child: (activity.userAvatarUrl == null || activity.userAvatarUrl!.isEmpty)
                  ? Text(
                      activity.userDisplayName.isNotEmpty ? activity.userDisplayName[0] : '?',
                      style: TellyTypography.caption(
                        color:
                            activity.isUpset ? TellyColors.neonCoralOf(context) : TellyColors.primaryAccentOf(context),
                      ).copyWith(fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${activity.userDisplayName} @${activity.username}',
                    style: TellyTypography.labelMedium(
                      color: TellyColors.textPrimaryOf(context),
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    activity.medal != null
                        ? 'Unlocked ${activity.medal!.name}'
                        : activity.isUpset
                            ? 'Ranked ${activity.titleName} over ${activity.upsetOverTitleName ?? 'Titan'}'
                            : 'Ranked ${activity.titleName} at #${activity.rankPosition ?? 1}',
                    style: TellyTypography.caption(
                      color: activity.isUpset ? TellyColors.neonCoralOf(context) : TellyColors.primaryAccentOf(context),
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (activity.microReview != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '“${activity.microReview}”',
                      style: TellyTypography.caption(
                        color: TellyColors.textPrimaryOf(context),
                      ).copyWith(fontStyle: FontStyle.italic),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (activity.medal case final medal?)
              MedalBadge(tier: medal.tier, glyph: medal.glyph, unlocked: true, size: MedalSize.small)
            else
              Container(
                width: 44,
                height: 66,
                decoration: BoxDecoration(
                  color: TellyColors.cardOf(context),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: TellyColors.borderGlassOf(context)),
                ),
                clipBehavior: Clip.antiAlias,
                child: PosterImage(
                  posterPath: activity.titlePosterUrl ??
                      TmdbImages.poster(findSeedPoster(activity.titleId, activity.mediaType, activity.titleName)),
                  fallback: Center(
                    child: Icon(
                      activity.mediaType == 'movie' ? Icons.movie_rounded : Icons.tv_rounded,
                      color: TellyColors.textTertiaryOf(context),
                      size: 20,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentRow(RankingComment comment) {
    final text = Text(
      comment.commentText,
      style: TellyTypography.bodyMedium(color: TellyColors.textPrimaryOf(context)),
    );

    return GestureDetector(
      key: Key('comment_row_${comment.id}'),
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _openModeration(comment),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: TellyColors.cardOf(context),
            backgroundImage: (comment.userAvatarUrl != null && comment.userAvatarUrl!.isNotEmpty)
                ? NetworkImage(comment.userAvatarUrl!)
                : null,
            child: (comment.userAvatarUrl == null || comment.userAvatarUrl!.isEmpty)
                ? Text(
                    comment.userDisplayName.isNotEmpty ? comment.userDisplayName[0] : '?',
                    style: TellyTypography.caption(
                      color: TellyColors.textPrimaryOf(context),
                    ).copyWith(fontWeight: FontWeight.bold),
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
                    Text(
                      comment.userDisplayName,
                      style: TellyTypography.labelMedium(
                        color: TellyColors.textPrimaryOf(context),
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '@${comment.username} • ${comment.relativeTime}',
                      style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
                    ),
                    if (comment.containsSpoilers) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: TellyColors.neonCoralOf(context).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: TellyColors.neonCoralOf(context).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'SPOILER',
                          style: TellyTypography.caption(
                            color: TellyColors.neonCoralOf(context),
                          ).copyWith(fontSize: 9, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),

                // Comment text with tap-to-reveal spoiler mask (SCR-06)
                if (comment.containsSpoilers) SpoilerMask(id: comment.id, child: text) else text,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    final composer = ref.watch(commentComposerProvider(_activityId));
    final containsSpoilers = composer.containsSpoilers;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        border: Border(top: BorderSide(color: TellyColors.borderGlassOf(context))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Spoiler Toggle Chip
              InkWell(
                borderRadius: BorderRadius.circular(8),
                key: const Key('composer_spoiler_toggle'),
                onTap: () {
                  HapticsService.selectionClick();
                  ref.read(commentComposerProvider(_activityId).notifier).toggleSpoiler();
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: containsSpoilers
                          ? TellyColors.neonCoralOf(context).withValues(alpha: 0.2)
                          : TellyColors.cardOf(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: containsSpoilers ? TellyColors.neonCoralOf(context) : TellyColors.borderGlassOf(context),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color:
                              containsSpoilers ? TellyColors.neonCoralOf(context) : TellyColors.textPrimaryOf(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Contains Spoilers',
                          style: TellyTypography.caption(
                            color: containsSpoilers
                                ? TellyColors.neonCoralOf(context)
                                : TellyColors.textPrimaryOf(context),
                          ).copyWith(fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),

          // Text Field & Send Action
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('comment_input'),
                  controller: _commentController,
                  style: TellyTypography.bodyMedium(color: TellyColors.textPrimaryOf(context)),
                  decoration: InputDecoration(
                    hintText: 'Add your take... (spoilers supported)',
                    hintStyle: TellyTypography.bodyMedium(color: TellyColors.textTertiaryOf(context)),
                    filled: true,
                    fillColor: TellyColors.cardOf(context),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: TellyColors.borderGlassOf(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: TellyColors.borderGlassOf(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: TellyColors.primaryAccentOf(context)),
                    ),
                  ),
                  onSubmitted: (_) => _handleSubmitComment(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const Key('comment_send'),
                tooltip: 'Send comment',
                onPressed: composer.submitting ? null : _handleSubmitComment,
                icon: composer.submitting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: TellyColors.primaryAccentOf(context),
                        ),
                      )
                    : Icon(Icons.send_rounded, color: TellyColors.primaryAccentOf(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
