import 'package:flutter/material.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/poster_image.dart';
import '../../data/ranking_repository.dart';

/// `SCR-12` ranking context: the new entry with its neighbours above and below, posters and
/// scores, the new row highlighted in Phosphor Lime (FE-SHARE-01).
class RevealLeaderboardSnippet extends StatelessWidget {
  final List<RevealLeaderboardEntry> entries;

  const RevealLeaderboardSnippet({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: TellyColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TellyColors.borderGlass),
      ),
      child: Column(
        children: [for (final e in entries) _Row(entry: e)],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final RevealLeaderboardEntry entry;

  const _Row({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isNew = entry.isNew;
    return Semantics(
      label: 'Rank ${entry.rank}, ${entry.title}, ${entry.score.toStringAsFixed(2)}${isNew ? ', just ranked' : ''}',
      excludeSemantics: true,
      child: Container(
        key: Key('reveal_leaderboard_row_${entry.rank}'),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isNew ? TellyColors.phosphorLime.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isNew ? TellyColors.phosphorLime : Colors.transparent, width: 1.2),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                '#${entry.rank}',
                style: TellyTypography.scoreMono(color: isNew ? TellyColors.phosphorLime : TellyColors.textTertiary)
                    .copyWith(fontSize: 14),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 28,
                height: 42,
                child: PosterImage(
                  posterPath: entry.posterPath,
                  fallback: const ColoredBox(color: TellyColors.backgroundSurface),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TellyTypography.bodyMedium(color: isNew ? TellyColors.textPrimary : TellyColors.textSecondary)
                    .copyWith(fontWeight: isNew ? FontWeight.w700 : FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              entry.score.toStringAsFixed(2),
              style: TellyTypography.scoreMono(color: isNew ? TellyColors.phosphorLime : TellyColors.textSecondary)
                  .copyWith(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
