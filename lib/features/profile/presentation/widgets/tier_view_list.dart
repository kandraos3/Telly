import 'package:flutter/material.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../ranking/domain/franchise_rollup_service.dart';

/// Mode 2: Tier View grouping personal canon into recognized cultural tiers.
/// Conforms to `docs/features/06_PROFILE_THE_CANON_AND_STATS.md` §3.2.
class TierViewList extends StatelessWidget {
  final List<CanonEntry> entries;
  final ValueChanged<CanonEntry>? onTapEntry;

  const TierViewList({
    super.key,
    required this.entries,
    this.onTapEntry,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'No titles ranked in this Canon yet.',
            style: TellyTypography.bodyMedium(color: TellyColors.textTertiary),
          ),
        ),
      );
    }

    final godTier = entries.where((e) => e.calculatedScore >= 9.20).toList();
    final prestigeTier = entries.where((e) => e.calculatedScore >= 8.50 && e.calculatedScore < 9.20).toList();
    final greatTier = entries.where((e) => e.calculatedScore >= 7.80 && e.calculatedScore < 8.50).toList();
    final goodTier = entries.where((e) => e.calculatedScore >= 7.00 && e.calculatedScore < 7.80).toList();
    final midTier = entries.where((e) => e.calculatedScore >= 5.50 && e.calculatedScore < 7.00).toList();
    final droppedTier = entries.where((e) => e.calculatedScore < 5.50).toList();

    return Column(
      children: [
        if (godTier.isNotEmpty)
          _buildTierGroup('👑 GOD TIER (9.20 – 10.00)', godTier, TellyColors.warmAmber),
        if (prestigeTier.isNotEmpty)
          _buildTierGroup('✨ PRESTIGE TIER (8.50 – 9.19)', prestigeTier, TellyColors.electricViolet),
        if (greatTier.isNotEmpty)
          _buildTierGroup('🔥 GREAT TIER (7.80 – 8.49)', greatTier, TellyColors.phosphorLime),
        if (goodTier.isNotEmpty)
          _buildTierGroup('⚡ GOOD TIER (7.00 – 7.79)', goodTier, TellyColors.electricCyan),
        if (midTier.isNotEmpty)
          _buildTierGroup('MID / FILLER (5.50 – 6.99)', midTier, TellyColors.textSecondary),
        if (droppedTier.isNotEmpty)
          _buildTierGroup('💀 DROPPED / DNF (< 5.50)', droppedTier, TellyColors.neonCoral),
      ],
    );
  }

  Widget _buildTierGroup(String header, List<CanonEntry> items, Color accentColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: TellyColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tier Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  header,
                  style: TellyTypography.labelSmall(color: accentColor).copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  '${items.length} titles',
                  style: TellyTypography.caption(color: TellyColors.textTertiary),
                ),
              ],
            ),
          ),

          // Titles in this Tier
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(
              color: TellyColors.borderGlass,
              height: 1,
              indent: 16,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return Material(
                color: Colors.transparent,
                child: ListTile(
                  dense: true,
                  onTap: () => onTapEntry?.call(item),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: Text(
                    '#${item.rankPosition}',
                    style: TellyTypography.scoreChip(color: TellyColors.textSecondary),
                  ),
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TellyTypography.titleMedium(color: TellyColors.textPrimary).copyWith(
                      fontSize: 14,
                    ),
                  ),
                  trailing: Text(
                    item.calculatedScore.toStringAsFixed(2),
                    style: TellyTypography.scoreMono(color: accentColor),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
