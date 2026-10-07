import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/haptics_service.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_avatar.dart';
import '../../../../core/widgets/telly_frosted_sheet.dart';
import '../../../../core/widgets/telly_primary_button.dart';
import '../../../../core/widgets/telly_section_header.dart';
import '../../domain/medal.dart';
import '../controllers/achievements_controller.dart';
import 'medal_badge.dart';

/// The medal sheet (features/10 §9.3, mockup A2): the medal, how it's earned, progress, which
/// people you follow have it, its rarity, and Pin/Unpin for unlocked medals. Collections'
/// "Still to watch" comes in slice 2 (#141); the share card comes with #138.
class MedalSheet extends ConsumerStatefulWidget {
  final String medalId;

  const MedalSheet({super.key, required this.medalId});

  static Future<void> show(BuildContext context, Medal medal) {
    HapticsService.selectionClick();
    return TellyFrostedSheet.show<void>(context: context, builder: (_) => MedalSheet(medalId: medal.id));
  }

  @override
  ConsumerState<MedalSheet> createState() => _MedalSheetState();
}

class _MedalSheetState extends ConsumerState<MedalSheet> {
  bool _busy = false;
  bool _choosingSlot = false;

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(achievementsControllerProvider).valueOrNull;
    final medal = snapshot?.medals.where((m) => m.id == widget.medalId).firstOrNull;
    if (snapshot == null || medal == null) return const SizedBox.shrink();
    final kind = switch (medal.kind) {
      MedalKind.milestone => 'Milestone',
      MedalKind.taste => 'Taste',
      MedalKind.streak => 'Streak',
      MedalKind.collection => 'Collection',
      MedalKind.challenge => 'Challenge',
      MedalKind.special => 'Special',
    };

    return SingleChildScrollView(
      key: const Key('medal_sheet'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MedalBadge.of(medal, describe: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medal.name,
                      style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context))
                          .copyWith(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$kind · ${medal.tier.label}',
                      style: TellyTypography.bodyMedium(color: TellyColors.textTertiaryOf(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(medal.description, style: TellyTypography.bodyLarge(color: TellyColors.textSecondaryOf(context))),
          const SizedBox(height: 14),
          _Progress(medal: medal),
          const SizedBox(height: 18),
          const TellySectionHeader(label: 'Friends', padding: EdgeInsets.zero),
          const SizedBox(height: 10),
          _Friends(medal: medal),
          const SizedBox(height: 8),
          Text(
            medal.rarityLine,
            key: const Key('medal_sheet_rarity'),
            style: TellyTypography.bodyMedium(color: TellyColors.textTertiaryOf(context)),
          ),
          if (medal.isUnlocked) ...[
            const SizedBox(height: 20),
            if (_choosingSlot) _slotChooser(snapshot, medal) else _pinButton(snapshot, medal),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _pinButton(AchievementsSnapshot snapshot, Medal medal) {
    final pinned = medal.pinnedSlot != null;
    return TellyPrimaryButton(
      key: const Key('medal_sheet_pin'),
      label: pinned ? 'Unpin from profile' : 'Pin to profile',
      isLoading: _busy,
      backgroundColor: pinned ? TellyColors.cardOf(context) : TellyColors.phosphorLime,
      textColor: pinned ? TellyColors.textPrimaryOf(context) : const Color(0xFF08090C),
      onPressed: () {
        if (pinned) {
          _run(() => ref.read(achievementsControllerProvider.notifier).unpin(medal));
        } else if (snapshot.freePinSlot == null) {
          setState(() => _choosingSlot = true);
        } else {
          _run(() => ref.read(achievementsControllerProvider.notifier).pin(medal));
        }
      },
    );
  }

  /// All three slots are taken: pick the medal to replace.
  Widget _slotChooser(AchievementsSnapshot snapshot, Medal medal) {
    return Column(
      key: const Key('medal_sheet_slot_chooser'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Replace which pinned medal?',
            style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(context))
                .copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final p in snapshot.pinned)
              Semantics(
                button: true,
                label: 'Replace ${p.name}',
                excludeSemantics: true,
                child: InkWell(
                  key: Key('medal_sheet_replace_${p.pinnedSlot}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: _busy
                      ? null
                      : () => _run(() =>
                          ref.read(achievementsControllerProvider.notifier).pin(medal, slot: p.pinnedSlot)),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      children: [
                        MedalBadge.of(p, size: MedalSize.small),
                        const SizedBox(height: 4),
                        Text(p.name, style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context))),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        TextButton(
          onPressed: () => setState(() => _choosingSlot = false),
          child: Text('Cancel', style: TextStyle(color: TellyColors.textSecondaryOf(context))),
        ),
      ],
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      HapticsService.selectionClick();
      if (mounted) setState(() => _choosingSlot = false);
    } catch (e) {
      if (!mounted) return;
      final message = e is AchievementsOfflineException ? e.toString() : "Couldn't update your pins. Try again.";
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Progress extends StatelessWidget {
  final Medal medal;
  const _Progress({required this.medal});

  @override
  Widget build(BuildContext context) {
    final unlocked = medal.unlockedAt;
    final line = unlocked != null
        ? 'Unlocked ${_date(unlocked)}'
        : medal.threshold == null
            ? 'Locked'
            : medal.id == 'taste_twin'
                ? 'Best match ${medal.progress}% of ${medal.threshold}%'
                : '${medal.progress} of ${medal.threshold}';
    final accent = TellyColors.warmAmberOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(line,
                  key: const Key('medal_sheet_progress'),
                  style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context))),
            ),
            Text('${(medal.fraction * 100).round()}%',
                style: TellyTypography.bodyMedium(color: TellyColors.textPrimaryOf(context))
                    .copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: medal.fraction,
            minHeight: 6,
            color: accent,
            backgroundColor: TellyColors.strokeOf(context),
          ),
        ),
      ],
    );
  }

  static String _date(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _Friends extends StatelessWidget {
  final Medal medal;
  const _Friends({required this.medal});

  @override
  Widget build(BuildContext context) {
    final style = TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context));
    if (medal.friendsCount == 0) {
      return Text('No one you follow has it yet', key: const Key('medal_sheet_friends'), style: style);
    }
    final names = medal.friends.map((f) => f.shortName).take(3).toList();
    final others = medal.friendsCount - names.length;
    final who = switch ((names.length, others)) {
      (1, 0) => names[0],
      (_, 0) => '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}',
      _ => '${names.join(', ')} and $others more',
    };
    return Row(
      children: [
        TellyAvatarStack(
          people: [for (final f in medal.friends) (f.displayName.isEmpty ? (f.username ?? '') : f.displayName, f.avatarUrl)],
          total: medal.friendsCount,
          max: 3,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text('$who ${medal.friendsCount == 1 ? 'has' : 'have'} it',
              key: const Key('medal_sheet_friends'), style: style),
        ),
      ],
    );
  }
}
