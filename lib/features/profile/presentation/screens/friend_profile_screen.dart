import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_primary_button.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../cowatch/domain/spearman_taste_match_calculator.dart';
import '../../../feed/domain/social_models.dart';
import '../controllers/friend_profile_controller.dart';
import '../widgets/taste_breakdown_section.dart';
import '../widgets/taste_match_dial.dart';

/// SCR-15: Friend Profile & Taste Comparison View.
/// Conforms to `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §15
/// and `docs/features/05_TASTE_MATCH_AND_CO_WATCH_DECIDER.md` §2.
/// FE-608: loaded by handle through [friendProfileProvider]; per-canon matches come from
/// `calculate_taste_match_rpc`, comparisons from both users' canons.
class FriendProfileScreen extends ConsumerWidget {
  final String handle;

  const FriendProfileScreen({super.key, required this.handle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(friendProfileProvider(handle));
    final data = async.valueOrNull;
    final currentUserId = ref.watch(authRepositoryProvider).currentUserId;
    final currentUser = ref.watch(authControllerProvider).user;
    final isSelf = (currentUser != null &&
            ((data != null && data.profile.id == currentUser.id) ||
             (currentUser.username != null && currentUser.username!.toLowerCase() == handle.toLowerCase()))) ||
        (currentUserId != null && data != null && data.profile.id == currentUserId);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(Icons.arrow_back, color: TellyColors.textPrimaryOf(context)),
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.feed),
        ),
        title: Text('@$handle', style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context))),
        actions: [
          if (data != null)
            _FollowButton(handle: handle, status: data.followStatus, isSelf: isSelf),
        ],
      ),
      body: async.when(
        loading: () => Center(child: CircularProgressIndicator(color: TellyColors.primaryAccentOf(context))),
        error: (e, _) => _Message(
          key: const Key('friend_profile_error'),
          text: e is ProfileNotFound ? "We couldn't find @$handle." : "Couldn't load @$handle. Pull to retry.",
          onRetry: e is ProfileNotFound ? null : () => ref.invalidate(friendProfileProvider(handle)),
        ),
        data: (data) => _Body(handle: handle, data: data, isSelf: isSelf),
      ),
    );
  }
}

class _FollowButton extends ConsumerWidget {
  final String handle;
  final FollowStatus? status;
  final bool isSelf;
  const _FollowButton({required this.handle, required this.status, this.isSelf = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isSelf) {
      return Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Center(
          child: OutlinedButton(
            key: const Key('edit_profile_button'),
            onPressed: () => context.push(Routes.editProfile),
            style: OutlinedButton.styleFrom(
              foregroundColor: TellyColors.primaryAccentOf(context),
              side: BorderSide(color: TellyColors.primaryAccentOf(context)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
            ),
            child: const Text('Edit Profile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
      );
    }

    final following = status == FollowStatus.accepted;
    final label = switch (status) {
      FollowStatus.accepted => 'Following',
      FollowStatus.pending => 'Requested',
      _ => '+ Follow',
    };
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Center(
        child: OutlinedButton(
          key: const Key('follow_button'),
          onPressed: () async {
            try {
              await ref.read(friendProfileProvider(handle).notifier).toggleFollow();
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Couldn't update follow. Try again.")),
                );
              }
            }
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: following ? TellyColors.textPrimaryOf(context) : TellyColors.primaryAccentOf(context),
            side: BorderSide(color: following ? TellyColors.strokeStrongOf(context) : TellyColors.primaryAccentOf(context)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            minimumSize: Size.zero,
          ),
          child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final String handle;
  final FriendProfileData data;
  final bool isSelf;
  const _Body({required this.handle, required this.data, this.isSelf = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = data.profile;
    final blended = data.blendedMatch;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: TellyColors.cardOf(context),
                foregroundImage: profile.avatarUrl == null ? null : NetworkImage(profile.avatarUrl!),
                child: Text(
                  profile.displayName.isNotEmpty ? profile.displayName[0] : '?',
                  style: TextStyle(fontSize: 22, color: TellyColors.textPrimaryOf(context), fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.displayName, style: TellyTypography.headlineSmall(color: TellyColors.textPrimaryOf(context))),
                    if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(profile.bio!, style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context))),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (!profile.canView)
            _Message(
              key: const Key('friend_profile_private'),
              text: data.followStatus == FollowStatus.pending
                  ? 'Follow request sent. Their canon appears once @$handle accepts.'
                  : '@$handle shares their canon with friends only. Follow to request access.',
            )
          else ...[
            TasteMatchDial(
              matchPercentage: blended ?? (isSelf ? 100 : 50),
              mutualTitleCount: data.mutualCount,
              affinityTier: TasteAffinityTier.fromPercentage(blended ?? (isSelf ? 100 : 50)),
            ),
            const SizedBox(height: 24),
            if (!isSelf) ...[
              TellyPrimaryButton(
                label: '🍿 Two-to-Watch with @$handle',
                onPressed: () => context.push(
                  Routes.twoToWatch(handle),
                  extra: FriendRouteArgs(userId: profile.id, displayName: profile.displayName, avatarUrl: profile.avatarUrl),
                ),
              ),
              const SizedBox(height: 20),
            ],
            DualTasteMatchBreakdown(
              movieMatchPercentage: data.movieMatch?.percentage,
              seriesMatchPercentage: data.seriesMatch?.percentage,
              movieMutualCount: data.movieMatch?.mutualCount,
              seriesMutualCount: data.seriesMatch?.mutualCount,
            ),
            const SizedBox(height: 24),
            TasteComparisonsSection(
              friendHandle: '@$handle',
              agreements: data.agreements,
              clashes: data.clashes,
              unwatchedGems: data.gems,
              onAddGemToQueue: (gem) async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ref.read(friendProfileProvider(handle).notifier).queueGem(gem);
                  messenger.showSnackBar(SnackBar(content: Text('Added "${gem.title}" to your Queue')));
                } catch (_) {
                  messenger.showSnackBar(const SnackBar(content: Text("Couldn't add it to your Queue.")));
                }
              },
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final VoidCallback? onRetry;
  const _Message({super.key, required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: TellyTypography.bodyMedium(color: TellyColors.textPrimaryOf(context)).copyWith(fontWeight: FontWeight.w600),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
