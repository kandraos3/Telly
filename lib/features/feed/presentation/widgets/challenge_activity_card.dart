import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/haptics_service.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../achievements/domain/medal.dart';
import '../../../achievements/presentation/widgets/medal_badge.dart';
import '../../../challenges/data/challenges_repository.dart';
import '../../../challenges/domain/challenge.dart';
import '../../../challenges/presentation/controllers/challenges_controller.dart';
import '../../../challenges/presentation/widgets/challenge_widgets.dart';
import '../../../levels/presentation/widgets/reward_cosmetics.dart';
import '../../domain/social_models.dart';
import 'feed_card_actions.dart';

/// The challenge behind a feed card, to offer Join while it's live and I'm not in it. Null
/// when it can't be seen (ended, a squad I'm not in) or fails to load.
final feedChallengeProvider = FutureProvider.autoDispose.family<Challenge?, String>((ref, slug) async {
  try {
    return await ref.watch(challengesRepositoryProvider).bySlug(slug);
  } catch (_) {
    return null;
  }
});

/// `CHALLENGE_COMPLETED` post in Social (`SCR-05`, features/10 §10, mockup C3; #144): who
/// finished what, the medal, "Best of the 8", reactions, and Join while it's live.
class ChallengeActivityCard extends ConsumerWidget {
  final ActivityLog activity;
  final VoidCallback? onCardTap;
  final VoidCallback? onCommentTap;
  final ValueChanged<FeedReaction>? onReactionToggle;

  const ChallengeActivityCard({
    super.key,
    required this.activity,
    this.onCardTap,
    this.onCommentTap,
    this.onReactionToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = activity.challenge;
    final name = activity.userDisplayName.isNotEmpty ? activity.userDisplayName : '@${activity.username}';
    final live = fc == null ? null : ref.watch(feedChallengeProvider(fc.slug)).valueOrNull;
    final now = ref.watch(challengeClockProvider)();
    final canJoin = live != null && !live.joined && !live.hasEnded(now);

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
                        backgroundImage:
                            (activity.userAvatarUrl?.isNotEmpty ?? false) ? NetworkImage(activity.userAvatarUrl!) : null,
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
                            '$name finished ${fc?.name ?? 'a challenge'}',
                            key: const Key('challenge_card_headline'),
                            style: TellyTypography.labelLarge(color: TellyColors.textPrimaryOf(context))
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            [activity.relativeTime, if (fc != null) '${fc.count} of ${fc.count}'].join(' · '),
                            style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)).copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (fc != null) ...[
                  const SizedBox(height: 14),
                  Center(
                    child: MedalBadge(
                      tier: MedalTier.gold,
                      glyph: fc.medalGlyph,
                      unlocked: true,
                      semanticLabel: 'Gold medal, ${fc.name}',
                    ),
                  ),
                  if (fc.bestLine case final best?) ...[
                    const SizedBox(height: 10),
                    Text(best,
                        key: const Key('challenge_card_best'),
                        style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context))),
                  ],
                ],
                const SizedBox(height: 14),
                Divider(color: TellyColors.borderGlassOf(context), height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FeedActionBar(
                        activity: activity,
                        onReactionToggle: onReactionToggle,
                        onCommentTap: onCommentTap,
                      ),
                    ),
                    if (canJoin) ...[
                      const SizedBox(width: 8),
                      LimePill(
                        key: const Key('challenge_card_join'),
                        label: 'Join ${live.name}',
                        onTap: () async {
                          HapticsService.lightImpact();
                          final messenger = ScaffoldMessenger.maybeOf(context);
                          try {
                            await ref.read(challengesControllerProvider.notifier).join(live);
                            ref.invalidate(feedChallengeProvider(fc!.slug));
                            messenger?.showSnackBar(SnackBar(content: Text('Joined ${live.name}')));
                          } catch (_) {
                            messenger?.showSnackBar(const SnackBar(content: Text("Couldn't join. Try again.")));
                          }
                        },
                      ),
                    ],
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
