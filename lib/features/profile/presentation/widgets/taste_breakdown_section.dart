import 'package:flutter/material.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/features/cowatch/domain/spearman_taste_match_calculator.dart';

/// Sub-card displaying segregated Movie Taste Match % and Series Taste Match % pills.
/// Conforms to `FE-402` and `docs/features/09_MOVIE_INTEGRATION_AND_DUAL_CANON.md` §5.
class DualTasteMatchBreakdown extends StatelessWidget {
  final int? movieMatchPercentage;
  final int? seriesMatchPercentage;
  final VoidCallback? onInfoTap;

  const DualTasteMatchBreakdown({
    super.key,
    this.movieMatchPercentage,
    this.seriesMatchPercentage,
    this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TellyColors.backgroundSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TellyColors.borderGlass),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CANON TASTE BREAKDOWN',
                style: TellyTypography.labelSmall(
                  color: TellyColors.textTertiary,
                ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.0),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 16, color: TellyColors.textTertiary),
                onPressed: onInfoTap ?? () => _showMathExplanationDialog(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCanonPill(
                  icon: '🎬',
                  label: 'Movie Match',
                  percentage: movieMatchPercentage,
                  color: TellyColors.warmAmber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCanonPill(
                  icon: '📺',
                  label: 'Series Match',
                  percentage: seriesMatchPercentage,
                  color: TellyColors.electricViolet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCanonPill({
    required String icon,
    required String label,
    required int? percentage,
    required Color color,
  }) {
    final hasScore = percentage != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: TellyColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TellyTypography.caption(
                    color: TellyColors.textSecondary,
                  ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasScore ? '$percentage%' : 'N/A',
            style: TellyTypography.titleLarge(
              color: hasScore ? color : TellyColors.textDisabled,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  void _showMathExplanationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TellyColors.backgroundCard,
        title: Text(
          'How Taste Match Works',
          style: TellyTypography.headlineSmall(color: TellyColors.textPrimary),
        ),
        content: Text(
          'Telly uses the Spearman Rank Correlation coefficient (ρ) combined with Bayesian confidence shrinkage (k₀ = 5).\n\n'
          'Movie and Series Canons are computed independently to prevent short-form features from skewing long-form TV alignments.',
          style: TellyTypography.bodyMedium(color: TellyColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Got It',
              style: TellyTypography.labelLarge(color: TellyColors.phosphorLime),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders Where You Agree, Spiciest Clashes, and Unwatched Gems.
/// Conforms to `FE-403` and `docs/features/05_TASTE_MATCH_AND_CO_WATCH_DECIDER.md` §2.
class TasteComparisonsSection extends StatelessWidget {
  final String friendHandle;
  final List<RankedTitleComparison> agreements;
  final List<RankedTitleComparison> clashes;
  final List<UnwatchedGem> unwatchedGems;
  final void Function(RankedTitleComparison title)? onTitleTap;
  final void Function(UnwatchedGem gem)? onAddGemToQueue;

  const TasteComparisonsSection({
    super.key,
    required this.friendHandle,
    required this.agreements,
    required this.clashes,
    required this.unwatchedGems,
    this.onTitleTap,
    this.onAddGemToQueue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Where You Agree
        _buildSectionHeader('🤝 WHERE YOU AGREE', TellyColors.phosphorLime),
        const SizedBox(height: 8),
        if (agreements.isEmpty)
          _buildEmptyText('No mutual agreements yet.')
        else
          ...agreements.map((item) => _buildAgreementTile(context, item)),

        const SizedBox(height: 20),

        // 2. Spiciest Clashes
        _buildSectionHeader('⚡ SPICIEST CLASHES', TellyColors.neonCoral),
        const SizedBox(height: 8),
        if (clashes.isEmpty)
          _buildEmptyText('No major ranking disagreements yet.')
        else
          ...clashes.map((item) => _buildClashTile(context, item)),

        const SizedBox(height: 20),

        // 3. Unwatched Gems
        _buildSectionHeader('💡 UNWATCHED GEMS $friendHandle LOVES', TellyColors.warmAmber),
        const SizedBox(height: 8),
        if (unwatchedGems.isEmpty)
          _buildEmptyText('No unwatched recommendations right now.')
        else
          ...unwatchedGems.map((gem) => _buildGemTile(context, gem)),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TellyTypography.labelSmall(
            color: TellyColors.textPrimary,
          ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
        ),
      ],
    );
  }

  Widget _buildEmptyText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TellyTypography.caption(color: TellyColors.textTertiary),
      ),
    );
  }

  Widget _buildAgreementTile(BuildContext context, RankedTitleComparison item) {
    return InkWell(
      onTap: () {
        if (onTitleTap != null) {
          onTitleTap!(item);
        } else {
          _showDetailSheet(context, item);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: TellyColors.backgroundSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TellyColors.borderGlass),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TellyTypography.headlineSmall(
                      color: TellyColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You: #${item.rankA} (★${item.scoreA.toStringAsFixed(1)}) • $friendHandle: #${item.rankB} (★${item.scoreB.toStringAsFixed(1)})',
                    style: TellyTypography.caption(
                      color: TellyColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: TellyColors.phosphorLime.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Δ ${item.rankDelta}',
                style: TellyTypography.caption(
                  color: TellyColors.phosphorLime,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClashTile(BuildContext context, RankedTitleComparison item) {
    return InkWell(
      onTap: () {
        if (onTitleTap != null) {
          onTitleTap!(item);
        } else {
          _showDetailSheet(context, item);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: TellyColors.backgroundSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TellyColors.neonCoral.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TellyTypography.headlineSmall(
                      color: TellyColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You: #${item.rankA} (★${item.scoreA.toStringAsFixed(1)}) • $friendHandle: #${item.rankB} (★${item.scoreB.toStringAsFixed(1)})',
                    style: TellyTypography.caption(
                      color: TellyColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: TellyColors.neonCoral.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Δ ${item.rankDelta}',
                style: TellyTypography.caption(
                  color: TellyColors.neonCoral,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGemTile(BuildContext context, UnwatchedGem gem) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: TellyColors.backgroundSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TellyColors.borderGlass),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gem.title,
                  style: TellyTypography.headlineSmall(
                    color: TellyColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '$friendHandle\'s #${gem.friendRank} ${gem.mediaType.toUpperCase()} • ${gem.network}',
                  style: TellyTypography.caption(
                    color: TellyColors.warmAmber,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => onAddGemToQueue?.call(gem),
            style: ElevatedButton.styleFrom(
              backgroundColor: TellyColors.backgroundCard,
              foregroundColor: TellyColors.phosphorLime,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: TellyColors.phosphorLime.withValues(alpha: 0.4)),
              ),
            ),
            icon: const Icon(Icons.add, size: 14),
            label: const Text('+ Queue', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showDetailSheet(BuildContext context, RankedTitleComparison item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TellyColors.backgroundCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: TellyTypography.headlineSmall(color: TellyColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: TellyColors.backgroundSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text('YOU', style: TextStyle(color: TellyColors.textTertiary, fontSize: 11)),
                        Text('#${item.rankA}', style: const TextStyle(color: TellyColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('★${item.scoreA.toStringAsFixed(1)}', style: const TextStyle(color: TellyColors.warmAmber, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: TellyColors.backgroundSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(friendHandle.toUpperCase(), style: const TextStyle(color: TellyColors.textTertiary, fontSize: 11)),
                        Text('#${item.rankB}', style: const TextStyle(color: TellyColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('★${item.scoreB.toStringAsFixed(1)}', style: const TextStyle(color: TellyColors.warmAmber, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (item.reviewB != null) ...[
              const SizedBox(height: 16),
              Text(
                '$friendHandle\'s note: "${item.reviewB}"',
                style: TellyTypography.bodyMedium(color: TellyColors.textSecondary).copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
