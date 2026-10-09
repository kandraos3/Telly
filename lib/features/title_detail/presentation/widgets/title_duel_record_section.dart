import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../data/title_detail_repository.dart';
import '../../domain/title_detail_models.dart';

/// SCR-08 "Tournament & Duel Record" and "Canon Tier Distribution" from live community data
/// (`get_title_duel_stats`), with an honest empty state instead of placeholders (FE-DETAIL-02).
class TitleDuelRecordSection extends ConsumerWidget {
  static const emptyMessage = 'Not enough duel data yet. Duel this title to establish its record!';

  final int titleId;
  final String mediaType;

  const TitleDuelRecordSection({super.key, required this.titleId, required this.mediaType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(titleDuelStatsProvider((titleId, mediaType)));
    return switch (stats) {
      AsyncData(:final value) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DuelRecordCard(stats: value),
            if (value.tiers.total > 0) ...[
              const SizedBox(height: 28),
              _TierDistributionCard(tiers: value.tiers),
            ],
          ],
        ),
      // Offline or failed: the record is optional context, so show the empty state.
      AsyncError() => const _DuelRecordCard(stats: TitleDuelStats.empty),
      _ => SizedBox(
          height: 96,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: TellyColors.primaryAccentOf(context))),
        ),
    };
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String heading;
  final Widget child;

  const _SectionCard({super.key, required this.icon, required this.heading, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TellyColors.borderGlassOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: TellyColors.primaryAccentOf(context)),
              const SizedBox(width: 6),
              Text(
                heading,
                style: TellyTypography.labelSmall(color: TellyColors.textPrimaryOf(context))
                    .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DuelRecordCard extends StatelessWidget {
  final TitleDuelStats stats;

  const _DuelRecordCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final winRate = stats.winRatePct;
    final top = stats.topDefeated;
    return _SectionCard(
      key: const Key('title_duel_record'),
      icon: Icons.bolt_rounded,
      heading: 'TOURNAMENT & DUEL RECORD',
      child: winRate == null
          ? Text(
              TitleDuelRecordSection.emptyMessage,
              key: const Key('title_duel_record_empty'),
              style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _Stat(value: '$winRate%', label: 'Duel Win Rate', color: TellyColors.primaryAccentOf(context))),
                    Expanded(
                      child: _Stat(
                        value: '${stats.totalDuels}',
                        label: stats.totalDuels == 1 ? 'Duel Fought' : 'Duels Fought',
                        color: TellyColors.warmAmberOf(context),
                      ),
                    ),
                    Expanded(
                      child: _Stat(
                        value: '${stats.tiers.total}',
                        label: stats.tiers.total == 1 ? 'Ranker' : 'Rankers',
                        color: TellyColors.electricVioletOf(context),
                      ),
                    ),
                  ],
                ),
                if (top != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: TellyColors.cardOf(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: TellyColors.borderGlassOf(context)),
                    ),
                    child: Row(
                      children: [
                        const Text('⚡', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Most often beats ${top.title} '
                            '(${top.count} head-to-head ${top.count == 1 ? 'win' : 'wins'}).',
                            style: TellyTypography.caption(color: TellyColors.textPrimaryOf(context)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _Stat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TellyTypography.monoDigits(color: color).copyWith(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: TellyTypography.caption(color: TellyColors.textPrimaryOf(context))),
      ],
    );
  }
}

class _TierDistributionCard extends StatelessWidget {
  final TierDistribution tiers;

  const _TierDistributionCard({required this.tiers});

  @override
  Widget build(BuildContext context) {
    final pct = tiers.percentages!;
    final bands = [
      ('👑', 'God', TellyColors.primaryAccentOf(context)),
      ('🎖️', 'Prestige', TellyColors.electricVioletOf(context)),
      ('✨', 'Great', TellyColors.warmAmberOf(context)),
      ('💤', 'Other', TellyColors.strokeStrongOf(context)),
    ];
    return _SectionCard(
      key: const Key('title_tier_distribution'),
      icon: Icons.bar_chart_rounded,
      heading: 'RANKING TIER DISTRIBUTION',
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  for (var i = 0; i < bands.length; i++)
                    if (pct[i] > 0) Expanded(flex: pct[i], child: ColoredBox(color: bands[i].$3)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < bands.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 8, height: 8, decoration: BoxDecoration(color: bands[i].$3, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(
                      '${bands[i].$1} ${pct[i]}% ${bands[i].$2}',
                      style: TellyTypography.caption(color: TellyColors.textPrimaryOf(context))
                          .copyWith(fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
