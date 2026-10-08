import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../achievements/data/achievements_repository.dart';
import '../../../achievements/domain/medal.dart';
import '../../../achievements/presentation/widgets/medal_badge.dart';
import '../../../levels/presentation/widgets/reward_cosmetics.dart';
import '../../domain/social_models.dart';
import 'feed_card_actions.dart';

/// `MEDAL_UNLOCKED` post in Social (`SCR-05`, features/10 §10, mockup C3; #139): the person,
/// the medal, its rarity and reactions. No title, so no poster and no Queue button.
class MedalActivityCard extends ConsumerWidget {
  final ActivityLog activity;
  final VoidCallback? onCardTap;
  final VoidCallback? onCommentTap;
  final ValueChanged<FeedReaction>? onReactionToggle;

  const MedalActivityCard({
    super.key,
    required this.activity,
    this.onCardTap,
    this.onCommentTap,
    this.onReactionToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medal = activity.medal;
    final rarity = medal == null ? null : ref.watch(medalRarityProvider).valueOrNull?[medal.id];
    final rarityLine = rarity?.line ?? Medal.rarityLineOf(null, isNew: true);
    final name = activity.userDisplayName.isNotEmpty ? activity.userDisplayName : '@${activity.username}';
    final medalName = medal?.name ?? 'a medal';

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
          onTap: onCardTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    RewardFrame(
                      userId: activity.userId,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: TellyColors.cardOf(context),
                        backgroundImage: (activity.userAvatarUrl?.isNotEmpty ?? false)
                            ? NetworkImage(activity.userAvatarUrl!)
                            : null,
                        child: (activity.userAvatarUrl?.isNotEmpty ?? false)
                            ? null
                            : Text(
                                name.replaceFirst('@', '').isNotEmpty ? name.replaceFirst('@', '')[0].toUpperCase() : '?',
                                style: TellyTypography.labelLarge(color: TellyColors.primaryAccentOf(context)),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$name unlocked $medalName',
                            key: const Key('medal_card_headline'),
                            style: TellyTypography.labelLarge(color: TellyColors.textPrimaryOf(context))
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            [activity.relativeTime, if (medal != null) '${medal.tier.label} medal'].join(' · '),
                            style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context))
                                .copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (medal != null) ...[
                  const SizedBox(height: 14),
                  Center(
                    child: MedalBadge(
                      tier: medal.tier,
                      glyph: medal.glyph,
                      unlocked: true,
                      semanticLabel: '${medal.tier.label} medal, ${medal.name}',
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    rarityLine,
                    key: const Key('medal_card_rarity'),
                    style: TellyTypography.caption(color: TellyColors.warmAmberOf(context))
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 14),
                Divider(color: TellyColors.borderGlassOf(context), height: 1),
                const SizedBox(height: 10),
                FeedActionBar(activity: activity, onReactionToggle: onReactionToggle, onCommentTap: onCommentTap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
