import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/poster_image.dart';
import '../../domain/tracking_item.dart';
import '../../domain/tracking_models.dart';
import 'tracking_labels.dart';

const _onLime = Color(0xFF08090C);

/// The container shared by the Next episode and Movie Watching cards (SCR-08 §T.4).
class _CardShell extends StatelessWidget {
  const _CardShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Color.alphaBlend(
            TellyColors.primaryAccentOf(context).withValues(alpha: 0.45),
            TellyColors.strokeSubtleOf(context),
          ),
        ),
      ),
      child: child,
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context))
            .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
      );
}

/// ▶ <provider> (secondary) and the lime primary action, equal widths, 48 dp tall.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.providerName,
    required this.onPlay,
    required this.primaryKey,
    required this.primaryLabel,
    required this.onPrimary,
    this.onPrimaryLongPress,
  });

  final String? providerName;
  final VoidCallback? onPlay;
  final Key primaryKey;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback? onPrimaryLongPress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (providerName != null) ...[
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                key: const Key('watching_play_button'),
                onPressed: onPlay,
                style: OutlinedButton.styleFrom(
                  foregroundColor: TellyColors.primaryAccentOf(context),
                  side: BorderSide(color: TellyColors.borderGlassOf(context)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  '▶ $providerName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              key: primaryKey,
              onPressed: onPrimary,
              onLongPress: onPrimaryLongPress,
              style: ElevatedButton.styleFrom(
                backgroundColor: TellyColors.phosphorLime,
                foregroundColor: _onLime,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                primaryLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 84 × 48 episode still with a runtime badge, or a numbered box when none is cached.
class _Still extends ConsumerWidget {
  const _Still({required this.episode});

  final NextEpisode episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = TmdbImages.backdrop(episode.stillPath, size: 'w300');
    final network = ref.watch(posterNetworkImagesProvider);
    final fallback = ColoredBox(
      color: TellyColors.cardOf(context),
      child: Center(
        child: Text(
          'E${episode.ref.episode}',
          style: TellyTypography.labelLarge(color: TellyColors.textTertiaryOf(context)),
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 84,
        height: 48,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url != null && network)
              Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback)
            else
              fallback,
            if (episode.runtimeMinutes != null)
              Positioned(
                right: 4,
                bottom: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    child: Text(
                      '${episode.runtimeMinutes}m',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// SCR-08 §T.4: the next episode and ✓ Watched E6, or "You're caught up".
class NextEpisodeCard extends StatelessWidget {
  const NextEpisodeCard({
    super.key,
    required this.item,
    required this.now,
    required this.onWatched,
    required this.onRank,
    this.onUnlogLast,
    this.providerName,
    this.onPlay,
  });

  final TrackingItem item;
  final DateTime now;
  final String? providerName;
  final VoidCallback? onPlay;
  final VoidCallback onWatched;
  final VoidCallback onRank;

  /// Long-press on ✓ Watched offers *Un-log <last episode>* (features/11 §4.3).
  final VoidCallback? onUnlogLast;

  @override
  Widget build(BuildContext context) {
    final next = item.nextEpisode;
    if (next == null || item.state != TrackingState.watching) return _caughtUp(context);
    final isNew = item.newEpisodesSince != null;
    final place = item.place;
    final newSeason = isNew && place != null && next.ref.season > place.season;
    final aired = next.airDate == null ? null : 'Aired ${TrackingLabels.date(next.airDate!, now)}';
    return _CardShell(
      key: const Key('next_episode_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isNew) ...[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: TellyColors.warmAmberOf(context),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    child: Text('NEW', style: TextStyle(color: _onLime, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    newSeason ? 'Season ${next.ref.season} is out' : 'E${next.ref.episode} is out',
                    style: TellyTypography.caption(color: TellyColors.warmAmberOf(context))
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ] else
                const Expanded(child: _Label('NEXT EPISODE')),
              if (item.airedTotal != null)
                Text(
                  '${item.watched ?? 0} of ${item.airedTotal}',
                  style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Still(episode: next),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      next.name == null ? next.ref.label : '${next.ref.label} · ${next.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TellyTypography.labelLarge(color: TellyColors.textPrimaryOf(context))
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (aired != null)
                      Text(aired, style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ActionRow(
            providerName: providerName,
            onPlay: onPlay,
            primaryKey: const Key('watched_episode_button'),
            primaryLabel: TrackingLabels.watched(next.ref, place),
            onPrimary: onWatched,
            onPrimaryLongPress: place == null ? null : onUnlogLast,
          ),
        ],
      ),
    );
  }

  Widget _caughtUp(BuildContext context) {
    final upcoming = [
      for (final s in item.seasons)
        if (s.airDate != null && s.airDate!.isAfter(now)) s,
    ];
    final finished = item.state == TrackingState.finished;
    final String detail;
    if (finished) {
      detail = 'You finished ${item.title}';
    } else if (upcoming.isNotEmpty) {
      final s = upcoming.first;
      detail = 'Season ${s.number} · ${TrackingLabels.date(s.airDate!, now)}';
    } else {
      detail = 'No new season announced';
    }
    return _CardShell(
      key: const Key('next_episode_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            finished ? "You're done" : "You're caught up",
            style: TellyTypography.labelLarge(color: TellyColors.textPrimaryOf(context)).copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(detail, style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context))),
          if (!item.isRanked) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('caught_up_rank_button'),
                onPressed: onRank,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TellyColors.phosphorLime,
                  foregroundColor: _onLime,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Rank ${item.title} →',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// SCR-08 §T.4b: a movie being watched, or the finished variant.
class MovieWatchingCard extends StatelessWidget {
  const MovieWatchingCard({
    super.key,
    required this.item,
    required this.now,
    required this.onFinished,
    required this.onRank,
    this.providerName,
    this.onPlay,
  });

  final TrackingItem item;
  final DateTime now;
  final String? providerName;
  final VoidCallback? onPlay;
  final VoidCallback onFinished;
  final VoidCallback onRank;

  @override
  Widget build(BuildContext context) {
    if (item.state == TrackingState.finished) return _finished(context);
    final meta = [
      if (item.runtimeMinutes != null) TrackingLabels.runtime(item.runtimeMinutes!),
      if (providerName != null) 'on $providerName',
    ].join(' · ');
    return _CardShell(
      key: const Key('movie_watching_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _Label('WATCHING')),
              Text(
                'Started ${TrackingLabels.relativeDay(item.startedAt, now)}',
                style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 34,
                  height: 50,
                  child: PosterImage(
                    posterPath: item.posterPath,
                    fallback: ColoredBox(color: TellyColors.cardOf(context)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TellyTypography.labelLarge(color: TellyColors.textPrimaryOf(context))
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (meta.isNotEmpty)
                      Text(meta, style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ActionRow(
            providerName: providerName,
            onPlay: onPlay,
            primaryKey: const Key('movie_finished_button'),
            primaryLabel: '✓ Finished',
            onPrimary: onFinished,
          ),
        ],
      ),
    );
  }

  Widget _finished(BuildContext context) {
    final when = item.finishedAt == null ? '' : ' · ${TrackingLabels.date(item.finishedAt!, now)}';
    return _CardShell(
      key: const Key('movie_watching_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You finished it$when',
            style: TellyTypography.labelLarge(color: TellyColors.textPrimaryOf(context)).copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (item.isRanked)
            Text(
              'Ranked #${item.rankPosition}${item.score == null ? '' : ' · ${item.score!.toStringAsFixed(2)}'}',
              key: const Key('movie_rank_chip'),
              style: TellyTypography.labelLarge(color: TellyColors.warmAmberOf(context)).copyWith(fontWeight: FontWeight.w800),
            )
          else
            SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('caught_up_rank_button'),
                onPressed: onRank,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TellyColors.phosphorLime,
                  foregroundColor: _onLime,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Rank ${item.title} →',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
