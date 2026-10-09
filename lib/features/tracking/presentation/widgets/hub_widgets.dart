import 'package:flutter/material.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/poster_image.dart';
import '../../domain/tracking_group.dart';
import '../../domain/tracking_hub.dart';
import '../../domain/tracking_item.dart';
import '../../domain/tracking_models.dart';
import '../../data/tracking_repository.dart';
import 'tracking_labels.dart';

const _onLime = Color(0xFF08090C);

/// *All 8*, *Series 6*, *Movies 2*, *Finished* (SCR-29).
class WatchingFilterChips extends StatelessWidget {
  const WatchingFilterChips({super.key, required this.hub, required this.selected, required this.onSelected});

  final TrackingHub hub;
  final WatchingFilter selected;
  final ValueChanged<WatchingFilter> onSelected;

  static String label(WatchingFilter f, TrackingHub hub) => switch (f) {
        WatchingFilter.all => 'All ${hub.count(f)}',
        WatchingFilter.tv => 'Series ${hub.count(f)}',
        WatchingFilter.movie => 'Movies ${hub.count(f)}',
        WatchingFilter.finished => 'Finished',
      };

  @override
  Widget build(BuildContext context) {
    final lime = TellyColors.primaryAccentOf(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final f in WatchingFilter.values) ...[
            if (f != WatchingFilter.all) const SizedBox(width: 8),
            ChoiceChip(
              key: Key('watching_filter_${f.query}'),
              label: Text(label(f, hub)),
              selected: f == selected,
              onSelected: (_) => onSelected(f),
              backgroundColor: TellyColors.surfaceOf(context),
              selectedColor: lime.withValues(alpha: 0.2),
              side: BorderSide(color: f == selected ? lime : TellyColors.borderGlassOf(context)),
              labelStyle: TextStyle(
                // Primary text on the lime tint: lime on its own 20% tint is 3.8:1 in dark (AA needs 4.5).
                color: f == selected ? TellyColors.textPrimaryOf(context) : TellyColors.textSecondaryOf(context),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// THIS WEEK: two tabular figures, the count and the time (SCR-29, features/11 §8). A null
/// [stats] is the offline "—"; a null time (a runtime wasn't cached) hides the second figure.
class ThisWeekStrip extends StatelessWidget {
  const ThisWeekStrip({super.key, required this.filter, required this.stats, required this.loading});

  final WatchingFilter filter;
  final TrackingStats? stats;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final movies = filter == WatchingFilter.movie;
    final count = movies ? stats?.moviesFinished : stats?.episodes;
    final unit = movies ? (count == 1 ? 'movie' : 'movies') : (count == 1 ? 'episode' : 'episodes');
    final minutes = stats?.minutes;
    final figure = TellyTypography.headlineSmall(color: TellyColors.textPrimaryOf(context))
        .copyWith(fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()]);
    final tertiary = TellyTypography.caption(color: TellyColors.textTertiaryOf(context));
    return Container(
      key: const Key('watching_week_strip'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TellyColors.borderGlassOf(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('THIS WEEK', style: tertiary.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0)),
          const SizedBox(width: 12),
          if (loading)
            Text('…', style: figure)
          else if (stats == null || count == null)
            Text('—', key: const Key('week_offline'), style: figure)
          else ...[
            Text('$count', key: const Key('week_count'), style: figure),
            const SizedBox(width: 4),
            Text(unit, style: tertiary),
          ],
          const Spacer(),
          if (!loading && minutes != null)
            Text(TrackingLabels.runtime(minutes), key: const Key('week_time'), style: figure),
        ],
      ),
    );
  }
}

/// One tracked title on the hub (SCR-29): poster, title, meta or amber pill, bar, trailing action.
class WatchingRow extends StatelessWidget {
  const WatchingRow({
    super.key,
    required this.item,
    required this.group,
    required this.now,
    required this.onTap,
    required this.onWatched,
    required this.onRank,
    this.onUnlogLast,
    this.moviePrefix = false,
    this.compact = false,
  });

  final TrackingItem item;

  /// Null in the *Finished* history.
  final TrackingGroup? group;
  final DateTime now;
  final VoidCallback onTap;

  /// ✓ E6, or ✓ Finished for a movie.
  final VoidCallback onWatched;
  final VoidCallback onRank;
  final VoidCallback? onUnlogLast;
  final bool moviePrefix;

  /// Home's version: a 40 × 58 poster and a shorter meta line (SCR-21).
  final bool compact;

  bool get _hasBar => !item.isMovie && (group == TrackingGroup.newEpisodes || group == TrackingGroup.inProgress || group == TrackingGroup.paused);

  @override
  Widget build(BuildContext context) {
    final meta = TrackingLabels.hubMeta(item, group, now, moviePrefix: moviePrefix, compact: compact);
    final amber = TellyColors.warmAmberOf(context);
    return Semantics(
      container: true,
      label: '${item.title}. ${group == TrackingGroup.newEpisodes ? TrackingLabels.newBadge(item) : meta}',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: compact ? 40 : 36,
                  height: compact ? 58 : 52,
                  child: PosterImage(posterPath: item.posterPath, fallback: ColoredBox(color: TellyColors.cardOf(context))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(context)).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    if (group == TrackingGroup.newEpisodes)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: amber.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(6)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            child: Text(
                              TrackingLabels.newBadge(item),
                              key: const Key('hub_new_badge'),
                              style: TellyTypography.caption(color: amber).copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
                      ),
                    if (_hasBar) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          key: const Key('hub_progress_bar'),
                          value: item.progress,
                          minHeight: 6,
                          backgroundColor: TellyColors.strokeSubtleOf(context),
                          color: TellyColors.primaryAccentOf(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _trailing(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trailing(BuildContext context) {
    final watching = item.state == TrackingState.watching || group == TrackingGroup.newEpisodes;
    if (item.isMovie && watching) {
      return _LimeButton(key: const Key('movie_finished_button'), label: '✓ Finished', onTap: onWatched);
    }
    if (!item.isMovie && watching && item.nextEpisode != null) {
      return _LimeButton(
        key: const Key('watched_episode_button'),
        label: TrackingLabels.watchedShort(item.nextEpisode!.ref, item.place),
        onTap: onWatched,
        onLongPress: item.place == null ? null : onUnlogLast,
      );
    }
    if (group == TrackingGroup.caughtUp) {
      return Container(
        key: const Key('hub_caught_up_pill'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: TellyColors.primaryAccentOf(context)),
        ),
        child: Text(
          'Caught up',
          style: TellyTypography.caption(color: TellyColors.primaryAccentOf(context)).copyWith(fontWeight: FontWeight.w700),
        ),
      );
    }
    if (!item.isRanked) return _LimeButton(key: const Key('hub_rank_button'), label: 'Rank →', onTap: onRank);
    return const SizedBox.shrink();
  }
}

class _LimeButton extends StatelessWidget {
  const _LimeButton({super.key, required this.label, required this.onTap, this.onLongPress});

  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: TellyColors.phosphorLime,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                widthFactor: 1,
                child: Text(label, style: const TextStyle(color: _onLime, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The strip and five rows shown while the cache answers (component library §7.1). Static, so it
/// never keeps a test from settling.
class WatchingSkeleton extends StatelessWidget {
  const WatchingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final fill = TellyColors.cardOf(context);
    Widget bar(double w, double h) => Container(width: w, height: h, decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(6)));
    return Column(
      key: const Key('watching_skeleton'),
      children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: bar(double.infinity, 52)),
        for (var i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                bar(36, 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [bar(140, 14), const SizedBox(height: 6), bar(200, 10)],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
