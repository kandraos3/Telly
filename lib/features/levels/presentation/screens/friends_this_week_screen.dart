import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_avatar.dart';
import '../../../../core/widgets/telly_empty_state.dart';
import '../../../../core/widgets/telly_screen_header.dart';
import '../../../../core/widgets/telly_segmented_control.dart';
import '../../domain/level_models.dart';
import '../controllers/levels_controller.dart';

/// Friends this week (`/more/level/week`, features/10 §9.7, mockup B3; #146): a weekly XP
/// table with the people I follow or one of my squads. Never all-time (decision 0005). The
/// selected segment is ephemeral UI state.
class FriendsThisWeekScreen extends ConsumerStatefulWidget {
  const FriendsThisWeekScreen({super.key});

  @override
  ConsumerState<FriendsThisWeekScreen> createState() => _FriendsThisWeekScreenState();
}

class _FriendsThisWeekScreenState extends ConsumerState<FriendsThisWeekScreen> {
  /// Null = Friends; else a squad id.
  String? _squadId;

  @override
  Widget build(BuildContext context) {
    final squads = ref.watch(weeklyTableSquadsProvider).valueOrNull ?? const [];
    final table = ref.watch(weeklyTableProvider(_squadId));
    return Scaffold(
      appBar: TellySubpageAppBar(
        title: 'This week',
        onNav: () => context.canPop() ? context.pop() : context.go(Routes.level),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (squads.isNotEmpty)
              TellySegmentedControl<String?>(
                key: const Key('week_segments'),
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                segments: [
                  const TellySegment(value: null, label: 'Friends', key: Key('week_segment_friends')),
                  for (final s in squads) TellySegment(value: s.id, label: s.name, key: Key('week_segment_${s.id}')),
                ],
                selected: _squadId,
                onChanged: (v) => setState(() => _squadId = v),
              ),
            Expanded(
              child: table.when(
                data: (rows) => _Table(rows: rows, squad: _squadId != null),
                loading: () => Center(child: CircularProgressIndicator(color: TellyColors.primaryAccentOf(context))),
                error: (_, __) => Center(
                  child: TellyEmptyState(
                    key: const Key('week_error'),
                    icon: Icons.leaderboard_outlined,
                    title: "Couldn't load this week",
                    message: 'Check your connection and try again.',
                    actionLabel: 'Retry',
                    onAction: () => ref.invalidate(weeklyTableProvider(_squadId)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Table extends StatelessWidget {
  final List<WeeklyRow> rows;
  final bool squad;
  const _Table({required this.rows, required this.squad});

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('week_table'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: TellyColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TellyColors.strokeOf(context)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(height: 1, thickness: 1, color: TellyColors.strokeOf(context)),
                _Row(row: rows[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          squad
              ? 'Weekly XP in this squad. Resets Monday, so nobody is out of reach for good.'
              : 'Weekly XP among people you follow. Resets Monday, so nobody is out of reach for good.',
          // The screen's intro: 13 px secondary w600, like Rewards' (11 px antialiases below AA contrast).
          style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context))
              .copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final WeeklyRow row;
  const _Row({required this.row});

  @override
  Widget build(BuildContext context) {
    final r = row;
    final detail = ['Level ${r.level}', if (r.streakWeeks > 0) '▲ ${r.streakWeeks} weeks'].join(' · ');
    return Container(
      key: Key('week_row_${r.userId}'),
      color: r.isMe ? TellyColors.primaryAccentOf(context).withValues(alpha: 0.07) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text('${r.rank}',
                style: TellyTypography.bodyMedium(color: TellyColors.textTertiaryOf(context))
                    .copyWith(fontWeight: FontWeight.w800)),
          ),
          TellyAvatar(name: r.name, imageUrl: r.avatarUrl, radius: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name,
                    style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(context))
                        .copyWith(fontWeight: FontWeight.w700)),
                Text(detail, style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context))),
              ],
            ),
          ),
          Text(groupDigits(r.weekXp),
              key: Key('week_xp_${r.userId}'),
              style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(context))
                  .copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
