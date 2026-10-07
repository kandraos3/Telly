import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/services/haptics_service.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_empty_state.dart';
import '../../../../core/widgets/telly_frosted_sheet.dart';
import '../../../../core/widgets/telly_screen_header.dart';
import '../../domain/level_models.dart';
import '../controllers/levels_controller.dart';
import '../widgets/level_widgets.dart';

/// `SCR-27` Your level (`/more/level`, features/10 §9.7, mockup B1; #146): the level ring and
/// bar, the weekly streak with its 7-week strip, this week's quests, and links to Rewards and
/// Friends this week. "?" explains how XP is earned.
class YourLevelScreen extends ConsumerWidget {
  const YourLevelScreen({super.key});

  static Future<void> showRules(BuildContext context) =>
      TellyFrostedSheet.show<void>(context: context, builder: (_) => const XpRulesTable());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(yourLevelControllerProvider);
    final data = async.valueOrNull;
    return Scaffold(
      appBar: TellySubpageAppBar(
        title: 'Your level',
        onNav: () => context.canPop() ? context.pop() : context.go(Routes.more),
        actions: [
          TellyHeaderAction(
            key: const Key('level_rules'),
            icon: Icons.help_outline_rounded,
            tooltip: 'How XP works',
            onPressed: () => showRules(context),
          ),
        ],
      ),
      body: SafeArea(
        child: data != null
            ? RefreshIndicator(
                color: TellyColors.primaryAccentOf(context),
                onRefresh: () => ref.refresh(yourLevelControllerProvider.future),
                child: _Body(data: data),
              )
            : async.hasError
                ? Center(
                    child: TellyEmptyState(
                      key: const Key('level_error'),
                      icon: Icons.bolt_rounded,
                      title: "Couldn't load your level",
                      message: 'Check your connection and try again.',
                      actionLabel: 'Retry',
                      actionIcon: Icons.refresh_rounded,
                      onAction: () => ref.invalidate(yourLevelControllerProvider),
                    ),
                  )
                : Center(child: CircularProgressIndicator(color: TellyColors.primaryAccentOf(context))),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final YourLevel data;
  const _Body({required this.data});

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('level_list'),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (data.offline) const _OfflineBanner(),
        _LevelCard(level: data.level),
        const SizedBox(height: 14),
        _StreakCard(data: data),
        const SizedBox(height: 14),
        _QuestsCard(quests: data.quests),
        const SizedBox(height: 14),
        _Links(),
      ],
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) => Padding(
        key: const Key('level_offline_banner'),
        padding: const EdgeInsets.only(bottom: 12),
        child: Text('⚡ Offline Mode • Showing your last saved level',
            style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context))),
      );
}

BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
      color: TellyColors.surfaceOf(context),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: TellyColors.strokeOf(context)),
    );

class _LevelCard extends StatelessWidget {
  final LevelInfo level;
  const _LevelCard({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('level_card'),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Row(
        children: [
          LevelRing(level: level.level, fraction: level.fraction),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(level.name,
                    style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context))
                        .copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(level.progressLabel,
                    key: const Key('level_progress_label'),
                    style: TellyTypography.bodyMedium(color: TellyColors.textTertiaryOf(context))),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: level.fraction,
                    minHeight: 6,
                    color: TellyColors.primaryAccentOf(context),
                    backgroundColor: TellyColors.strokeOf(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final YourLevel data;
  const _StreakCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final accent = TellyColors.primaryAccentOf(context);
    return Container(
      key: const Key('level_streak_card'),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Weekly streak',
                    style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(context))
                        .copyWith(fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.45)),
                ),
                child: Text(data.streak.chipLabel,
                    style: TellyTypography.labelMedium(color: accent).copyWith(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (data.streak.weeks.isNotEmpty) StreakStrip(weeks: data.streak.weeks),
          const SizedBox(height: 12),
          Text('One freeze a month keeps a quiet week from breaking it.',
              style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context))),
        ],
      ),
    );
  }
}

class _QuestsCard extends StatelessWidget {
  final List<Quest> quests;
  const _QuestsCard({required this.quests});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('level_quests'),
      decoration: _cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text("This week's quests",
                      style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(context))
                          .copyWith(fontWeight: FontWeight.w700)),
                ),
                Text('resets Mon', style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context))),
              ],
            ),
          ),
          if (quests.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Text('Quests appear here every Monday.',
                  style: TellyTypography.bodyMedium(color: TellyColors.textTertiaryOf(context))),
            ),
          for (final q in quests) _QuestRow(quest: q),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _QuestRow extends StatelessWidget {
  final Quest quest;
  const _QuestRow({required this.quest});

  @override
  Widget build(BuildContext context) {
    final accent = TellyColors.primaryAccentOf(context);
    final done = quest.isDone;
    return Semantics(
      label: '${quest.title}, ${done ? 'done' : '${quest.progress} of ${quest.target}'}, ${quest.xp} XP',
      excludeSemantics: true,
      child: Padding(
        key: Key('quest_${quest.key}'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? accent : null,
                border: Border.all(color: done ? accent : TellyColors.strokeStrongOf(context), width: 1.5),
              ),
              child: done ? const Icon(Icons.check_rounded, size: 16, color: TellyColors.backgroundPrimary) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(quest.title,
                      style: TellyTypography.bodyLarge(
                              color: done ? TellyColors.textSecondaryOf(context) : TellyColors.textPrimaryOf(context))
                          .copyWith(fontWeight: FontWeight.w600)),
                  Text(done ? 'Done' : '${quest.progress} of ${quest.target}',
                      style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: TellyColors.strokeStrongOf(context)),
              ),
              child: Text('+${quest.xp}',
                  style: TellyTypography.labelMedium(color: TellyColors.textSecondaryOf(context))
                      .copyWith(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Links extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget row(Key key, IconData icon, String label, String route) => Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: key,
            onTap: () {
              HapticsService.selectionClick();
              context.push(route);
            },
            child: SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: TellyColors.textSecondaryOf(context)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(label,
                          style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(context))
                              .copyWith(fontWeight: FontWeight.w600)),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 18, color: TellyColors.textTertiaryOf(context)),
                  ],
                ),
              ),
            ),
          ),
        );
    return Container(
      decoration: _cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          row(const Key('level_link_week'), Icons.leaderboard_outlined, 'Friends this week', Routes.levelWeek),
        ],
      ),
    );
  }
}
