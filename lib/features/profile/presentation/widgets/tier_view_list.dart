import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../tracking/presentation/providers/tracking_providers.dart';
import '../../../tracking/presentation/widgets/canon_tracking.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../ranking/domain/canon_tier.dart';
import '../../../ranking/domain/franchise_rollup_service.dart';
import '../../../ranking/presentation/widgets/canon_tier_style.dart';

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

    final grouped = <CanonTier, List<CanonEntry>>{};
    for (final entry in entries) {
      grouped.putIfAbsent(CanonTier.fromScore(entry.calculatedScore), () => []).add(entry);
    }

    return Column(
      children: [
        for (final tier in CanonTier.values)
          if (grouped[tier] != null) _buildTierGroup(context, tier.headerLabel, grouped[tier]!, tier.accent),
      ],
    );
  }

  Widget _buildTierGroup(BuildContext context, String header, List<CanonEntry> items, Color accentColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: TellyColors.cardOf(context),
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
                  style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
                ),
              ],
            ),
          ),

          // Titles in this Tier
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(
              color: TellyColors.borderGlassOf(context),
              height: 1,
              indent: 16,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return Material(
                color: Colors.transparent,
                child: Consumer(builder: (context, ref, _) {
                  final watching = CanonProgressTagFor.taggable(ref.watch(titleTrackingProvider((item.id, item.mediaType))));
                  return ListTile(
                  dense: true,
                  subtitle: watching == null
                      ? null
                      : Align(alignment: Alignment.centerLeft, child: CanonProgressTag(item: watching)),
                  onTap: () => onTapEntry?.call(item),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: Text(
                    '#${item.rankPosition}',
                    style: TellyTypography.scoreChip(color: TellyColors.textSecondaryOf(context)),
                  ),
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context)).copyWith(
                      fontSize: 14,
                    ),
                  ),
                  trailing: Text(
                    item.calculatedScore.toStringAsFixed(2),
                    style: TellyTypography.scoreMono(color: accentColor),
                  ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}
