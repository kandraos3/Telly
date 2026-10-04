import 'package:flutter/material.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../ranking/domain/franchise_rollup_service.dart';

/// Top 3 Showcase cards for the user's highest ranked titles.
/// Conforms to `docs/features/06_PROFILE_THE_CANON_AND_STATS.md` §2.
class TopShowcaseRow extends StatelessWidget {
  final List<CanonEntry> topEntries;
  final ValueChanged<CanonEntry>? onTapEntry;

  const TopShowcaseRow({
    super.key,
    required this.topEntries,
    this.onTapEntry,
  });

  @override
  Widget build(BuildContext context) {
    if (topEntries.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayItems = topEntries.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '━ TOP 3 SHOWCASE ',
                style: TellyTypography.caption(color: TellyColors.textTertiary).copyWith(
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: TellyColors.borderGlass,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: List.generate(3, (index) {
              if (index < displayItems.length) {
                final item = displayItems[index];
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index < 2 ? 10 : 0,
                    ),
                    child: _buildShowcaseCard(item, index + 1),
                  ),
                );
              } else {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index < 2 ? 10 : 0,
                    ),
                    child: _buildEmptyCard(index + 1),
                  ),
                );
              }
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildShowcaseCard(CanonEntry item, int rank) {
    return GestureDetector(
      onTap: () => onTapEntry?.call(item),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: TellyColors.backgroundCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: rank == 1
                ? TellyColors.phosphorLime.withValues(alpha: 0.6)
                : TellyColors.borderGlass,
            width: rank == 1 ? 1.5 : 1.0,
          ),
          boxShadow: rank == 1
              ? [
                  BoxShadow(
                    color: TellyColors.phosphorLime.withValues(alpha: 0.15),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            // Poster thumbnail with rank overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 110,
                    width: double.infinity,
                    color: TellyColors.backgroundSurface,
                    child: item.posterPath != null && item.posterPath!.isNotEmpty
                        ? Image.network(
                            item.posterPath!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _posterFallback(item),
                          )
                        : _posterFallback(item),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: rank == 1
                          ? TellyColors.phosphorLime
                          : TellyColors.backgroundPrimary.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#$rank',
                      style: TellyTypography.caption(
                        color: rank == 1 ? Colors.black : TellyColors.textPrimary,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TellyTypography.caption(color: TellyColors.textPrimary).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.calculatedScore.toStringAsFixed(2),
              style: TellyTypography.scoreMono(
                color: rank == 1 ? TellyColors.phosphorLime : TellyColors.textSecondary,
              ).copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard(int rank) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: TellyColors.backgroundCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TellyColors.strokeSubtle),
      ),
      child: Center(
        child: Text(
          '#$rank',
          style: TellyTypography.titleMedium(color: TellyColors.textSecondary),
        ),
      ),
    );
  }

  Widget _posterFallback(CanonEntry item) {
    return Center(
      child: Icon(
        item.mediaType == 'movie' ? Icons.movie_outlined : Icons.tv_outlined,
        color: TellyColors.textTertiary,
        size: 28,
      ),
    );
  }
}
