import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/services/haptics_service.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_empty_state.dart';
import '../../../../core/widgets/telly_screen_header.dart';
import '../../domain/level_models.dart';
import '../controllers/rewards_controller.dart';
import '../widgets/level_widgets.dart';

/// Rewards (`/more/level/rewards`, features/10 §5.2, §9.7, mockup B2; #147): the track by
/// level (unlocked rows outlined in the primary accent with Equip; locked rows with XP to go),
/// then how XP is earned. Every reward is cosmetic.
class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(rewardsControllerProvider);
    return Scaffold(
      appBar: TellySubpageAppBar(
        title: 'Rewards',
        onNav: () => context.canPop() ? context.pop() : context.go(Routes.level),
      ),
      body: SafeArea(
        child: async.when(
          data: (rewards) => ListView(
            key: const Key('rewards_list'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                'Every reward is cosmetic. Nothing you need to use Telly is locked behind points.',
                style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context)),
              ),
              const SizedBox(height: 14),
              for (final r in rewards) ...[_RewardRow(reward: r), const SizedBox(height: 10)],
              const SizedBox(height: 14),
              const XpRulesTable(),
            ],
          ),
          loading: () => Center(child: CircularProgressIndicator(color: TellyColors.primaryAccentOf(context))),
          error: (_, __) => Center(
            child: TellyEmptyState(
              key: const Key('rewards_error'),
              icon: Icons.card_giftcard_rounded,
              title: "Couldn't load rewards",
              message: 'Check your connection and try again.',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(rewardsControllerProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardRow extends ConsumerStatefulWidget {
  final Reward reward;
  const _RewardRow({required this.reward});

  @override
  ConsumerState<_RewardRow> createState() => _RewardRowState();
}

class _RewardRowState extends ConsumerState<_RewardRow> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.reward;
    final accent = TellyColors.primaryAccentOf(context);
    final sub = r.unlocked ? 'Level ${r.levelRequired}' : '${groupDigits(r.xpToGo)} XP to go';
    return Semantics(
      label: '${r.name}, ${r.unlocked ? (r.equipped ? 'equipped' : 'unlocked') : 'locked, $sub'}',
      child: Container(
        key: Key('reward_${r.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: TellyColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: r.unlocked ? accent : TellyColors.strokeOf(context), width: r.unlocked ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: r.unlocked ? accent : TellyColors.cardOf(context),
              ),
              child: r.unlocked
                  ? const Icon(Icons.check_rounded, size: 18, color: TellyColors.backgroundPrimary)
                  : Text('${r.levelRequired}',
                      style: TellyTypography.labelMedium(color: TellyColors.textSecondaryOf(context))
                          .copyWith(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name,
                      style: TellyTypography.bodyLarge(
                              color: r.unlocked ? TellyColors.textPrimaryOf(context) : TellyColors.textSecondaryOf(context))
                          .copyWith(fontWeight: FontWeight.w700)),
                  Text(sub, style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context))),
                ],
              ),
            ),
            if (r.unlocked && r.kind == RewardKind.appIcon)
              // Alternate app icons aren't built yet (#154): unlockable, not equippable.
              Padding(
                key: Key('reward_soon_${r.id}'),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('Coming soon',
                    style: TellyTypography.labelMedium(color: TellyColors.textTertiaryOf(context))
                        .copyWith(fontWeight: FontWeight.w800)),
              )
            else if (r.unlocked && r.kind == RewardKind.headerArt)
              TextButton(
                key: Key('reward_choose_${r.id}'),
                onPressed: () {
                  HapticsService.selectionClick();
                  context.push(Routes.levelHeaderArt);
                },
                child: Text(r.equipped ? 'Change' : 'Choose',
                    style: TellyTypography.labelMedium(color: accent).copyWith(fontWeight: FontWeight.w800)),
              )
            else if (r.unlocked)
              TextButton(
                key: Key('reward_equip_${r.id}'),
                onPressed: _busy ? null : () => _toggle(r),
                child: Text(r.equipped ? 'Equipped' : 'Equip',
                    style: TellyTypography.labelMedium(
                            color: r.equipped ? TellyColors.textSecondaryOf(context) : accent)
                        .copyWith(fontWeight: FontWeight.w800)),
              )
            else
              Icon(Icons.lock_outline_rounded, size: 18, color: TellyColors.textTertiaryOf(context)),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(Reward r) async {
    HapticsService.selectionClick();
    setState(() => _busy = true);
    final ctrl = ref.read(rewardsControllerProvider.notifier);
    try {
      r.equipped ? await ctrl.unequip(r) : await ctrl.equip(r);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text("Couldn't change that. Try again.")));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
