import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';

/// SCR-06: Post Detail & Spoiler-Safe Comment Thread (FE-305).
///
/// Features frosted Gaussian blur on comments containing spoilers,
/// tap-to-reveal interaction, and spoiler tagging on the composer.
class CommentThreadScreen extends ConsumerStatefulWidget {
  final ActivityLog activity;

  const CommentThreadScreen({super.key, required this.activity});

  @override
  ConsumerState<CommentThreadScreen> createState() => _CommentThreadScreenState();
}

class _CommentThreadScreenState extends ConsumerState<CommentThreadScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _containsSpoilers = false;
  bool _isSubmitting = false;

  // Track which spoiler comments are currently unmasked/revealed
  final Set<String> _revealedCommentIds = {};

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _toggleRevealSpoiler(String commentId) {
    HapticsService.lightImpact();
    setState(() {
      if (_revealedCommentIds.contains(commentId)) {
        _revealedCommentIds.remove(commentId);
      } else {
        _revealedCommentIds.add(commentId);
      }
    });
  }

  Future<void> _handleSubmitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repo = ref.read(socialRepositoryProvider);
      await repo.addComment(
        activityId: widget.activity.id,
        text: text,
        containsSpoilers: _containsSpoilers,
      );

      _commentController.clear();
      setState(() {
        _containsSpoilers = false;
        _isSubmitting = false;
      });

      ref.invalidate(commentsProvider(widget.activity.id));
      HapticsService.mediumImpact();
    } catch (_) {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsProvider(widget.activity.id));

    return Scaffold(
      backgroundColor: TellyColors.backgroundCanvasOled,
      appBar: AppBar(
        backgroundColor: TellyColors.backgroundCanvasOled,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: TellyColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'CONVERSATION',
          style: TellyTypography.labelLarge(
            color: TellyColors.textPrimary,
          ).copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Original Activity Summary Card
            _buildPostSummaryCard(),

            const Divider(color: TellyColors.borderGlass, height: 1),

            // 2. Comments Thread List
            Expanded(
              child: commentsAsync.when(
                data: (comments) {
                  if (comments.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 40,
                            color: TellyColors.textTertiary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No comments yet. Be the first to share your take!',
                            style: TellyTypography.bodyMedium(
                              color: TellyColors.textTertiary,
                            ),
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
                loading: () => const Center(
                  child: CircularProgressIndicator(color: TellyColors.phosphorLime),
                ),
                error: (e, _) => Center(
                  child: Text('Error loading comments: $e', style: TellyTypography.bodyMedium()),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: TellyColors.backgroundSurface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: TellyColors.backgroundCard,
            child: Text(
              activity.userDisplayName.isNotEmpty ? activity.userDisplayName[0] : '?',
              style: TellyTypography.caption(
                color: activity.isUpset ? TellyColors.neonCoral : TellyColors.phosphorLime,
              ).copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${activity.userDisplayName} @${activity.username}',
                  style: TellyTypography.labelMedium(
                    color: TellyColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  activity.isUpset
                      ? 'Ranked ${activity.titleName} over ${activity.upsetOverTitleName ?? 'Titan'}'
                      : 'Ranked ${activity.titleName} at #${activity.rankPosition ?? 1}',
                  style: TellyTypography.caption(
                    color: activity.isUpset ? TellyColors.neonCoral : TellyColors.phosphorLime,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                if (activity.microReview != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '“${activity.microReview}”',
                    style: TellyTypography.caption(
                      color: TellyColors.textSecondary,
                    ).copyWith(fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentRow(RankingComment comment) {
    final isMasked = comment.containsSpoilers && !_revealedCommentIds.contains(comment.id);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: TellyColors.backgroundCard,
          child: Text(
            comment.userDisplayName.isNotEmpty ? comment.userDisplayName[0] : '?',
            style: TellyTypography.caption(
              color: TellyColors.textPrimary,
            ).copyWith(fontWeight: FontWeight.bold),
          ),
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
                      color: TellyColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '@${comment.username} • ${comment.relativeTime}',
                    style: TellyTypography.caption(color: TellyColors.textTertiary),
                  ),
                  if (comment.containsSpoilers) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: TellyColors.neonCoral.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: TellyColors.neonCoral.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'SPOILER',
                        style: TellyTypography.caption(
                          color: TellyColors.neonCoral,
                        ).copyWith(fontSize: 9, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),

              // Comment text with tap-to-reveal spoiler mask
              if (isMasked)
                GestureDetector(
                  key: Key('spoiler_mask_${comment.id}'),
                  onTap: () => _toggleRevealSpoiler(comment.id),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        // Blurred text content underneath
                        ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            color: TellyColors.backgroundCard,
                            child: Text(
                              comment.commentText,
                              style: TellyTypography.bodyMedium(
                                color: TellyColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        // Glass frosted overlay banner
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.35),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.visibility_off_rounded,
                                      color: TellyColors.warmAmber, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    'TAP TO REVEAL SPOILER',
                                    style: TellyTypography.caption(
                                      color: TellyColors.warmAmber,
                                    ).copyWith(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: comment.containsSpoilers ? () => _toggleRevealSpoiler(comment.id) : null,
                  child: Container(
                    padding: comment.containsSpoilers ? const EdgeInsets.all(8) : EdgeInsets.zero,
                    decoration: comment.containsSpoilers
                        ? BoxDecoration(
                            color: TellyColors.backgroundCard,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: TellyColors.borderGlass),
                          )
                        : null,
                    child: Text(
                      comment.commentText,
                      style: TellyTypography.bodyMedium(color: TellyColors.textPrimary),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: TellyColors.backgroundSurface,
        border: Border(top: BorderSide(color: TellyColors.borderGlass)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Spoiler Toggle Chip
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  HapticsService.selectionClick();
                  setState(() {
                    _containsSpoilers = !_containsSpoilers;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _containsSpoilers
                        ? TellyColors.neonCoral.withValues(alpha: 0.2)
                        : TellyColors.backgroundCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _containsSpoilers
                          ? TellyColors.neonCoral
                          : TellyColors.borderGlass,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: _containsSpoilers
                            ? TellyColors.neonCoral
                            : TellyColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Contains Spoilers',
                        style: TellyTypography.caption(
                          color: _containsSpoilers
                              ? TellyColors.neonCoral
                              : TellyColors.textTertiary,
                        ).copyWith(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
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
                  controller: _commentController,
                  style: TellyTypography.bodyMedium(color: TellyColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Add your take... (spoilers supported)',
                    hintStyle: TellyTypography.bodyMedium(color: TellyColors.textTertiary),
                    filled: true,
                    fillColor: TellyColors.backgroundCard,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: TellyColors.borderGlass),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: TellyColors.borderGlass),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: TellyColors.phosphorLime),
                    ),
                  ),
                  onSubmitted: (_) => _handleSubmitComment(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _handleSubmitComment,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: TellyColors.phosphorLime,
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: TellyColors.phosphorLime),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
