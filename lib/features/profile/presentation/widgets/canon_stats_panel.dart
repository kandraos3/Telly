import 'package:flutter/material.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../domain/canon_stats.dart';

/// SCR-14 stats dashboard for the selected canon (FE-PROFILE-03, profile spec §2/§5):
/// hours watched, top genre with its share, top director (movies) or network (series),
/// and total titles. [stats] is null while loading or offline; tiles then show "—"
/// except the title count, which comes from the local canon.
class CanonStatsPanel extends StatelessWidget {
  final CanonStats? stats;
  final bool isMovie;
  final int localTitleCount;

  const CanonStatsPanel({
    super.key,
    required this.stats,
    required this.isMovie,
    required this.localTitleCount,
  });

  static String formatHours(CanonStats s) {
    final h = s.hours;
    final digits = h.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return '${s.hoursEstimated ? '≈' : ''}${digits}h';
  }

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final genre = s?.topGenre;
    final creator = s?.topCreator;
    final titleWord = isMovie ? 'film' : 'show';
    final tiles = [
      _StatTile(
        key: const Key('canon_stat_titles'),
        label: isMovie ? 'Movies Ranked' : 'Shows Ranked',
        value: '${s?.totalTitles ?? localTitleCount}',
      ),
      _StatTile(
        key: const Key('canon_stat_hours'),
        label: 'Hours Watched',
        value: s == null ? '—' : formatHours(s),
        detail: s != null && s.hoursEstimated ? 'from episode counts' : null,
      ),
      _StatTile(
        key: const Key('canon_stat_genre'),
        label: 'Top Genre',
        value: genre?.name ?? '—',
        detail: genre?.percent == null ? null : '${genre!.percent}% of your canon',
      ),
      _StatTile(
        key: const Key('canon_stat_creator'),
        label: isMovie ? 'Top Director' : 'Top Network',
        value: creator?.name ?? '—',
        detail: creator == null ? null : '${creator.count} ${creator.count == 1 ? titleWord : '${titleWord}s'}',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        key: const Key('canon_stats_panel'),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: TellyColors.backgroundSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TellyColors.borderGlass),
        ),
        child: Column(
          children: [
            Row(children: [Expanded(child: tiles[0]), Expanded(child: tiles[1])]),
            Row(children: [Expanded(child: tiles[2]), Expanded(child: tiles[3])]),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? detail;

  const _StatTile({super.key, required this.label, required this.value, this.detail});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label: $value${detail == null ? '' : ', $detail'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: TellyTypography.caption(color: TellyColors.textTertiary)
                    .copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8, fontSize: 10)),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TellyTypography.titleMedium(color: TellyColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
            ),
            if (detail != null)
              Text(detail!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TellyTypography.caption(color: TellyColors.phosphorLime)),
          ],
        ),
      ),
    );
  }
}
