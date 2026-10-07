import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/services/haptics_service.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_empty_state.dart';
import '../../../../core/widgets/telly_screen_header.dart';
import '../../../../core/widgets/telly_section_header.dart';
import '../../domain/medal.dart';
import '../controllers/achievements_controller.dart';
import '../widgets/medal_badge.dart';
import '../widgets/medal_sheet.dart';

/// `SCR-23` Achievements (`/more/achievements`, features/10 §9.3, mockup A1; #137).
///
/// Summary (unlocked count and the weekly streak chip), the pinned row, then Milestones,
/// Taste and Streak, with locked medals showing their progress. Collections join in slice 2
/// (#141); the app bar's Share comes with the medals share card (#138).
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(achievementsControllerProvider);
    final snapshot = async.valueOrNull;
    return Scaffold(
      appBar: TellySubpageAppBar(
        title: 'Achievements',
        onNav: () => context.canPop() ? context.pop() : context.go(Routes.more),
      ),
      body: SafeArea(
        child: snapshot != null
            ? RefreshIndicator(
                color: TellyColors.primaryAccentOf(context),
                onRefresh: () => ref.refresh(achievementsControllerProvider.future),
                child: _Body(snapshot: snapshot),
              )
            : async.hasError
                ? Center(
                    child: TellyEmptyState(
                      key: const Key('achievements_error'),
                      icon: Icons.emoji_events_outlined,
                      title: "Couldn't load your medals",
                      message: 'Check your connection and try again.',
                      actionLabel: 'Retry',
                      actionIcon: Icons.refresh_rounded,
                      onAction: () => ref.invalidate(achievementsControllerProvider),
                    ),
                  )
                : const _Skeleton(),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final AchievementsSnapshot snapshot;
  const _Body({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final sections = [
      ('Milestones', snapshot.section(MedalKind.milestone)),
      ('Taste', snapshot.section(MedalKind.taste)),
      ('Streak', snapshot.section(MedalKind.streak)),
      ('Special', snapshot.section(MedalKind.special)),
    ];
    return ListView(
      key: const Key('achievements_list'),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        if (snapshot.offline) const _OfflineBanner(),
        _SummaryCard(snapshot: snapshot),
        const SizedBox(height: 22),
        _PinnedRow(snapshot: snapshot),
        for (final (label, medals) in sections)
          if (medals.isNotEmpty) ...[
            const SizedBox(height: 22),
            TellySectionHeader(label: label),
            const SizedBox(height: 10),
            _MedalList(key: Key('achievements_section_${label.toLowerCase()}'), medals: medals),
          ],
      ],
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('achievements_offline_banner'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TellyColors.borderGlassOf(context)),
      ),
      child: Text(
        '⚡ Offline Mode • Showing your last saved medals',
        style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context)),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Card({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TellyColors.strokeOf(context)),
      ),
      child: child,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final AchievementsSnapshot snapshot;
  const _SummaryCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final muted = TellyTypography.bodyMedium(color: TellyColors.textTertiaryOf(context));
    final total = snapshot.visible.length;
    final unlocked = snapshot.unlockedCount;
    final streak = snapshot.streak;
    return _Card(
      key: const Key('achievements_summary'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Semantics(
              label: 'Unlocked $unlocked of $total medals',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unlocked', style: muted),
                  const SizedBox(height: 2),
                  Text.rich(TextSpan(children: [
                    TextSpan(
                      text: '$unlocked ',
                      style: TellyTypography.titleLarge(color: TellyColors.textPrimaryOf(context))
                          .copyWith(fontSize: 30, fontWeight: FontWeight.w800, height: 1.1),
                    ),
                    TextSpan(text: 'of $total', style: muted.copyWith(fontSize: 15)),
                  ])),
                ],
              ),
            ),
          ),
          Semantics(
            label: 'Weekly streak, ${streak.currentWeeks} ${streak.currentWeeks == 1 ? 'week' : 'weeks'}',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Weekly streak', style: muted),
                const SizedBox(height: 6),
                _LimeChip(key: const Key('achievements_streak_chip'), label: streak.chipLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The lime "▲ N weeks" chip (features/10 §3). Opens `SCR-27` once Your level ships (#146).
class _LimeChip extends StatelessWidget {
  final String label;
  const _LimeChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final accent = TellyColors.primaryAccentOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Text(label,
          style: TellyTypography.labelMedium(color: accent).copyWith(fontWeight: FontWeight.w800)),
    );
  }
}

/// Pinned medals; the three most recent unlocks ("Recent") when nothing is pinned; a hint
/// when there are no unlocks yet (§4.4, §9.3).
class _PinnedRow extends StatelessWidget {
  final AchievementsSnapshot snapshot;
  const _PinnedRow({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final pinned = snapshot.pinned;
    final shown = pinned.isNotEmpty ? pinned : snapshot.recent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TellySectionHeader(
          label: 'Pinned to profile',
          trailing: pinned.isEmpty && shown.isNotEmpty
              ? Text('Recent', style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)))
              : null,
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          Padding(
            key: const Key('achievements_pinned_hint'),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Rank titles to earn your first medal',
              textAlign: TextAlign.center,
              style: TellyTypography.bodyMedium(color: TellyColors.textTertiaryOf(context)),
            ),
          )
        else
          Padding(
            key: const Key('achievements_pinned_row'),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final m in shown)
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: m.semanticLabel,
                      excludeSemantics: true,
                      child: InkWell(
                        key: Key('achievements_pinned_${m.id}'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => MedalSheet.show(context, m),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            children: [
                              MedalBadge.of(m),
                              const SizedBox(height: 6),
                              Text(
                                m.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MedalList extends StatelessWidget {
  final List<Medal> medals;
  const _MedalList({super.key, required this.medals});

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < medals.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: TellyColors.strokeOf(context)),
            _MedalRow(medal: medals[i]),
          ],
        ],
      ),
    );
  }
}

class _MedalRow extends StatelessWidget {
  final Medal medal;
  const _MedalRow({required this.medal});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${medal.semanticLabel}. ${medal.description}',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: Key('achievements_row_${medal.id}'),
          onTap: () {
            HapticsService.selectionClick();
            MedalSheet.show(context, medal);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                MedalBadge.of(medal, size: MedalSize.small),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medal.name,
                        style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(context))
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        medal.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TellyTypography.bodyMedium(color: TellyColors.textTertiaryOf(context)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (medal.isUnlocked)
                  Icon(Icons.check_circle_rounded, size: 20, color: TellyColors.primaryAccentOf(context))
                else
                  Text(
                    medal.progressLabel,
                    key: Key('achievements_progress_${medal.id}'),
                    style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context))
                        .copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Loading placeholder (component library §7.1): the summary card, the pinned row and a list.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double height) => Container(
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: TellyColors.surfaceOf(context), borderRadius: BorderRadius.circular(16)),
        );
    return ListView(
      key: const Key('achievements_skeleton'),
      physics: const NeverScrollableScrollPhysics(),
      children: [block(84), block(100), block(220)],
    );
  }
}
