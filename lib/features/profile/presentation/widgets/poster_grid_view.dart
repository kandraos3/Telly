import 'package:flutter/material.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/poster_image.dart';
import '../../../ranking/domain/franchise_rollup_service.dart';

/// Mode 3: 3x3 Poster Grid showing the user's top 9 titles without text clutter.
/// Conforms to `docs/features/06_PROFILE_THE_CANON_AND_STATS.md` §3.3.
class PosterGridView extends StatelessWidget {
  final List<CanonEntry> entries;
  final ValueChanged<CanonEntry>? onTapEntry;

  const PosterGridView({
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2 / 3, // Standard movie poster ratio
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final item = entries[index];
          final rank = item.rankPosition;
          return GestureDetector(
            key: Key('grid_poster_${item.id}'),
            onTap: () => onTapEntry?.call(item),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: TellyColors.backgroundCard,
                    child: PosterImage(
                      posterPath: item.posterPath,
                      fallback: _posterFallback(item),
                    ),
                  ),
                  // Rank badge
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
                        key: Key('grid_rank_badge_${item.id}'),
                        style: TellyTypography.caption(
                          color: rank == 1 ? Colors.black : TellyColors.textPrimary,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  // Score chip
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: TellyColors.backgroundPrimary.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: TellyColors.borderGlass),
                      ),
                      child: Text(
                        item.calculatedScore.toStringAsFixed(2),
                        style: TellyTypography.caption(color: TellyColors.phosphorLime)
                            .copyWith(fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _posterFallback(CanonEntry item) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            item.mediaType == 'movie' ? Icons.movie_outlined : Icons.tv_outlined,
            color: TellyColors.textTertiary,
            size: 24,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TellyTypography.caption(color: TellyColors.textSecondary).copyWith(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
