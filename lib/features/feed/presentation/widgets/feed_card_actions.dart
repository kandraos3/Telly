import 'package:flutter/material.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';

/// Compact "Want to Watch" bookmark for the top-right corner of a feed card (FE-FEED-01).
class FeedBookmarkButton extends StatelessWidget {
  const FeedBookmarkButton({super.key, required this.inQueue, required this.onPressed, this.accent});

  final bool inQueue;
  final VoidCallback onPressed;

  /// Saved-state colour; Phosphor Lime unless the card has its own accent.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? TellyColors.primaryAccentOf(context);
    return IconButton(
      key: const Key('feed_bookmark'),
      tooltip: inQueue ? 'In your Watchlist' : 'Want to Watch',
      onPressed: onPressed,
      icon: Icon(
        inQueue ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        color: inQueue ? color : TellyColors.textSecondaryOf(context),
        size: 22,
      ),
    );
  }
}

/// The snackbar shown after saving a title from a feed card.
SnackBar feedQueuedSnackBar({BuildContext? context, Color? accent}) => SnackBar(
      backgroundColor: context != null ? TellyColors.cardOf(context) : TellyColors.backgroundCard,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accent ?? (context != null ? TellyColors.borderGlassOf(context) : TellyColors.borderGlass)),
      ),
      content: Row(
        children: [
          Icon(Icons.bookmark_rounded, color: accent ?? (context != null ? TellyColors.primaryAccentOf(context) : TellyColors.phosphorLime), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Added to your Watchlist', style: TellyTypography.caption(color: context != null ? TellyColors.textPrimaryOf(context) : TellyColors.textPrimary)),
          ),
        ],
      ),
      duration: const Duration(seconds: 2),
    );

/// Reaction bar + comments for feed cards (FE-FEED-01): the five presets, any other
/// reactions the post already has (retired presets, custom emoji), and a `+` that
/// opens the emoji picker.
class FeedActionBar extends StatelessWidget {
  const FeedActionBar({
    super.key,
    required this.activity,
    this.onReactionToggle,
    this.onCommentTap,
  });

  final ActivityLog activity;
  final ValueChanged<FeedReaction>? onReactionToggle;
  final VoidCallback? onCommentTap;

  /// Presets first, then the post's other reactions by count.
  List<FeedReaction> get _shown {
    final extras = activity.reactions.keys.where((r) => !FeedReactionType.presets.contains(r.type)).toList()
      ..sort((a, b) => (activity.reactions[b] ?? 0).compareTo(activity.reactions[a] ?? 0));
    return [for (final t in FeedReactionType.presets) FeedReaction(t), ...extras];
  }

  void _toggle(FeedReaction r) {
    HapticsService.selectionClick();
    onReactionToggle?.call(r);
  }

  Future<void> _pick(BuildContext context) async {
    final mine = activity.userReactions.where((r) => r.isCustom).firstOrNull;
    final picked = await showFeedEmojiPicker(context, current: mine);
    if (picked == null) return;
    // Picking my current custom emoji again leaves it as is; un-react by tapping its pill.
    if (picked == mine) return;
    if (picked.isCustom || !activity.userReactions.contains(picked)) _toggle(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final r in _shown)
                  _ReactionPill(
                    reaction: r,
                    count: activity.reactions[r] ?? 0,
                    selected: activity.userReactions.contains(r),
                    onTap: () => _toggle(r),
                  ),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    key: const Key('feed_reaction_more'),
                    tooltip: 'More reactions',
                    onPressed: () => _pick(context),
                    icon: Icon(Icons.add_reaction_outlined, size: 20, color: TellyColors.textTertiaryOf(context)),
                  ),
                ),
              ],
            ),
          ),
        ),
        InkWell(
          key: const Key('feed_comments'),
          borderRadius: BorderRadius.circular(8),
          onTap: onCommentTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 16, color: TellyColors.textTertiaryOf(context)),
                  const SizedBox(width: 4),
                  Text(
                    '${activity.commentCount}',
                    style: TellyTypography.caption(color: TellyColors.textPrimaryOf(context))
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReactionPill extends StatelessWidget {
  const _ReactionPill({required this.reaction, required this.count, required this.selected, required this.onTap});

  final FeedReaction reaction;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = TellyColors.primaryAccentOf(context);
    return Tooltip(
      message: reaction.label,
      child: InkWell(
        key: Key('feed_reaction_${reaction.dbKey}'),
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 44),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.symmetric(horizontal: count > 0 ? 8 : 6, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? accent.withValues(alpha: 0.14) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? accent : Colors.transparent),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Text(reaction.glyph, style: TextStyle(fontSize: 16, color: TellyColors.textPrimaryOf(context))),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      '$count',
                      style: TellyTypography.caption(
                        color: selected ? accent : TellyColors.textPrimaryOf(context),
                      ).copyWith(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Curated emoji for the picker; one custom emoji per user per post.
const kFeedPickerEmoji = [
  '😂', '🥹', '😭', '😍', '🥰', '😱', '🤯', '😤', '🙄', '😴', //
  '🫠', '🤔', '🫡', '🥶', '🤢', '💀', '👀', '🙌', '🔥', '💯', //
  '✨', '⭐', '❤️', '💜', '🍿', '📺', '🎭', '🎞️', '🧠', '🗑️', //
  '👑', '🐐', '🚀', '💥', '🌊', '🌙', '☕', '🍷', '🎉', '🤝', //
];

/// Bottom sheet with the labelled presets and an emoji grid. Returns the chosen
/// reaction, or null when dismissed.
Future<FeedReaction?> showFeedEmojiPicker(BuildContext context, {FeedReaction? current}) {
  return showModalBottomSheet<FeedReaction>(
    context: context,
    isScrollControlled: true,
    backgroundColor: TellyColors.cardOf(context),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'REACT',
              style: TellyTypography.labelSmall(color: TellyColors.textTertiaryOf(context))
                  .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in FeedReactionType.presets)
                  ActionChip(
                    key: Key('feed_picker_${t.dbValue}'),
                    avatar: Text(t.emoji),
                    label: Text(t.label),
                    onPressed: () => Navigator.of(ctx).pop(FeedReaction(t)),
                    backgroundColor: TellyColors.surfaceOf(context),
                    side: BorderSide(color: TellyColors.borderGlassOf(context)),
                    labelStyle: TellyTypography.labelMedium(color: TellyColors.textSecondaryOf(context)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              current == null ? 'OR PICK ANY EMOJI' : 'SWAP YOUR EMOJI (${current.emoji})',
              style: TellyTypography.labelSmall(color: TellyColors.textTertiaryOf(context))
                  .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
            ),
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final e in kFeedPickerEmoji)
                  InkWell(
                    key: Key('feed_picker_emoji_$e'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(ctx).pop(FeedReaction.custom(e)),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: current?.emoji == e ? TellyColors.phosphorLime : Colors.transparent,
                          ),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
