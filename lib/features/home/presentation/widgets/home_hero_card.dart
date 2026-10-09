import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/poster_image.dart';
import '../../../tracking/domain/tracking_group.dart';
import '../../../tracking/domain/tracking_item.dart';
import '../../../tracking/domain/tracking_models.dart';
import '../../../tracking/presentation/providers/tracking_providers.dart';
import '../../../tracking/presentation/widgets/tracking_actions.dart';
import '../../../tracking/presentation/widgets/tracking_labels.dart';
import '../../domain/home_hero.dart';
import '../providers/home_providers.dart';

/// Text colours on the hero's dark scrim. They are fixed in both themes, like the Queue's Up next card.
const _eyebrowLime = Color(0xFFD2FF52);
const _eyebrowAmber = Color(0xFFFFA733);
const _onScrim = Color(0xFFFFFFFF);
const _onScrim2 = Color(0xFFC8CAD8);
const _scrim = Color(0xFF08090C);

/// The *Tonight* hero and the chips under it (`SCR-21` §21.2): what to watch next, and one tap to log it.
class HomeHeroSection extends ConsumerWidget {
  const HomeHeroSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeStateProvider);
    if (state.heroLoading) return const _HeroSkeleton();
    final hero = state.hero;
    return Column(
      key: const Key('home_hero_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeHeroCard(hero: hero),
        if (hero.mode == HomeHeroMode.watching) _HeroChips(hero: hero),
      ],
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('home_hero_loading'),
      height: HomeHeroCard.minHeight,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: TellyColors.cardOf(context), borderRadius: BorderRadius.circular(18)),
    );
  }
}

/// One card, four modes ([HomeHeroMode]).
class HomeHeroCard extends ConsumerWidget {
  const HomeHeroCard({super.key, required this.hero});

  static const minHeight = 236.0;

  final HomeHero hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(trackingNowProvider)();
    final copy = _HeroCopy.of(hero, now);
    final item = hero.item;
    return Container(
      key: const Key('home_hero'),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(color: _scrim, borderRadius: BorderRadius.circular(18)),
      child: Stack(
        children: [
          Positioned.fill(
            child: PosterImage(
              posterPath: TmdbImages.backdrop(copy.backdrop) ?? copy.poster,
              fallback: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2A2F45), _scrim]),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.2, 1.0],
                  colors: [_scrim.withValues(alpha: 0), _scrim.withValues(alpha: 0.92)],
                ),
              ),
            ),
          ),
          if (copy.onOpen(context) != null)
            Positioned.fill(
              child: Semantics(
                button: true,
                label: 'Open ${copy.openLabel}',
                child: GestureDetector(
                  key: const Key('home_hero_art'),
                  behavior: HitTestBehavior.opaque,
                  onTap: copy.onOpen(context),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: minHeight - 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    container: true,
                    label: copy.semantics,
                    // Text lets taps through to the art behind it, which opens the title.
                    child: ExcludeSemantics(
                      child: IgnorePointer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              copy.eyebrow,
                              key: const Key('home_hero_eyebrow'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TellyTypography.caption(color: copy.amber ? _eyebrowAmber : _eyebrowLime)
                                  .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.2),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              copy.title,
                              key: const Key('home_hero_title'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TellyTypography.displayXL(color: _onScrim).copyWith(fontSize: 23, height: 1.15),
                            ),
                            if (copy.meta.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                copy.meta,
                                key: const Key('home_hero_meta'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TellyTypography.caption(color: _onScrim2),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buttons(context, ref, now),
                  if (item != null && !item.isMovie) ...[
                    const SizedBox(height: 12),
                    IgnorePointer(child: _ProgressLine(fraction: item.progress)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buttons(BuildContext context, WidgetRef ref, DateTime now) {
    final item = hero.item;
    switch (hero.mode) {
      case HomeHeroMode.watching:
        final next = item!.nextEpisode?.ref;
        final canLog = item.isMovie || next != null;
        final label = item.isMovie ? '✓ Finished' : (next == null ? '' : TrackingLabels.watched(next, item.place));
        return Row(
          children: [
            if (canLog)
              Expanded(
                flex: 3,
                child: _HeroButton(
                  buttonKey: const Key('home_hero_primary'),
                  label: label,
                  primary: true,
                  onPressed: () async {
                    if (item.isMovie) {
                      await TrackingActions.finishMovie(context, ref, item);
                    } else {
                      await TrackingActions.markNext(context, ref, item);
                    }
                    if (context.mounted) ref.read(homeStateProvider.notifier).refresh();
                  },
                  onLongPress: item.isMovie || item.place == null
                      ? null
                      : () => TrackingActions.offerUnlogLast(context, ref, item),
                ),
              ),
            if (canLog) const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _HeroButton(
                buttonKey: const Key('home_hero_details'),
                label: 'Details',
                onPressed: () => context.push(Routes.title(item.mediaType, item.titleId)),
              ),
            ),
          ],
        );
      case HomeHeroMode.queue:
        final pick = hero.queuePick!;
        final notifier = ref.read(homeStateProvider.notifier);
        return Row(
          children: [
            Expanded(
              flex: 3,
              child: _HeroButton(
                buttonKey: const Key('home_hero_primary'),
                label: '▶ Start watching',
                primary: true,
                onPressed: () async {
                  await TrackingActions.startFromQueue(context, ref, pick);
                  if (context.mounted) notifier.refresh();
                },
              ),
            ),
            if (ref.watch(homeStateProvider.select((s) => s.queueSize)) > 1) ...[
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _HeroButton(
                  buttonKey: const Key('home_hero_another'),
                  label: '↻ Another',
                  onPressed: notifier.shuffleQueuePick,
                ),
              ),
            ],
          ],
        );
      case HomeHeroMode.newUser:
        return _HeroButton(
          buttonKey: const Key('home_hero_primary'),
          label: '+ Log a title',
          primary: true,
          onPressed: () => context.push(Routes.log),
        );
      case HomeHeroMode.explore:
        return _HeroButton(
          buttonKey: const Key('home_hero_primary'),
          label: 'Open Explore',
          primary: true,
          onPressed: () => context.go(Routes.explore),
        );
    }
  }
}

/// What the hero says in each mode.
class _HeroCopy {
  const _HeroCopy({
    required this.eyebrow,
    required this.title,
    this.meta = '',
    this.amber = false,
    this.backdrop,
    this.poster,
    this.open,
  });

  final String eyebrow;
  final String title;
  final String meta;
  final bool amber;
  final String? backdrop;
  final String? poster;

  /// The title the card opens, as (media type, id, name); null when the card opens nothing.
  final (String, int, String)? open;

  String get openLabel => open?.$3 ?? '';

  VoidCallback? onOpen(BuildContext context) {
    final target = open;
    return target == null ? null : () => context.push(Routes.title(target.$1, target.$2));
  }

  String get semantics => [eyebrow, title, meta].where((s) => s.isNotEmpty).join(', ');

  static _HeroCopy of(HomeHero hero, DateTime now) {
    switch (hero.mode) {
      case HomeHeroMode.watching:
        return _watching(hero.item!, now);
      case HomeHeroMode.queue:
        final pick = hero.queuePick!;
        final canon = pick.mediaType == 'movie' ? 'Movie' : 'Series';
        final size = pick.mediaType == 'movie'
            ? (pick.runtimeMinutes == null ? null : TrackingLabels.runtime(pick.runtimeMinutes!))
            : (pick.seasonCount == null ? null : '${pick.seasonCount} ${pick.seasonCount == 1 ? 'season' : 'seasons'}');
        return _HeroCopy(
          eyebrow: 'UP NEXT FROM YOUR QUEUE',
          title: pick.title,
          meta: [
            canon,
            if (size != null) size,
            if (pick.availability.isNotEmpty) 'on ${pick.availability.first.platformName}'
          ].join(' · '),
          poster: pick.posterPath,
          open: (pick.mediaType, pick.showId, pick.title),
        );
      case HomeHeroMode.newUser:
        return const _HeroCopy(
          eyebrow: 'WELCOME TO TELLY',
          title: 'Start your canon',
          meta: 'Log one movie or show you love. Telly ranks everything after it head to head.',
        );
      case HomeHeroMode.explore:
        return const _HeroCopy(
          eyebrow: 'NOTHING ON TONIGHT',
          title: 'Find your next watch',
          meta: 'Explore has picks from your canon',
        );
    }
  }

  static _HeroCopy _watching(TrackingItem item, DateTime now) {
    final open = (item.mediaType, item.titleId, item.title);
    if (item.isMovie) {
      return _HeroCopy(
        eyebrow: 'WATCHING · MOVIE',
        title: item.title,
        meta: 'Started ${TrackingLabels.relativeDay(item.startedAt, now)}',
        backdrop: item.backdropPath,
        poster: item.posterPath,
        open: open,
      );
    }
    final next = item.nextEpisode;
    final fresh = item.group(now) == TrackingGroup.newEpisodes;
    final name = next?.name;
    final left = next == null ? null : _leftInSeason(item, next.ref);
    final runtime = next?.runtimeMinutes ?? item.runtimeMinutes;
    return _HeroCopy(
      eyebrow: fresh
          ? '${item.title.toUpperCase()} · ${TrackingLabels.newBadge(item).toUpperCase()}'
          : 'UP NEXT · ${item.title.toUpperCase()}',
      title: next == null ? item.title : (name == null ? next.ref.label : '${next.ref.label} "$name"'),
      meta: [
        if (runtime != null) TrackingLabels.runtime(runtime),
        if (left != null && left > 0) '$left left this season',
      ].join(' · '),
      amber: fresh,
      backdrop: item.backdropPath,
      poster: item.posterPath,
      open: open,
    );
  }

  /// Episodes after [next] in its season, or null when the season's size isn't known.
  static int? _leftInSeason(TrackingItem item, EpisodeRef next) {
    for (final s in item.seasons) {
      if (s.number == next.season) return s.episodeCount - next.episode;
    }
    return null;
  }
}

/// The hero's two buttons: lime primary, glass secondary (white at 12% with a white-at-20% border).
class _HeroButton extends StatelessWidget {
  const _HeroButton(
      {required this.buttonKey, required this.label, required this.onPressed, this.primary = false, this.onLongPress});

  final Key buttonKey;
  final String label;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: ElevatedButton(
        key: buttonKey,
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary ? _eyebrowLime : Colors.white.withValues(alpha: 0.12),
          foregroundColor: primary ? _scrim : _onScrim,
          minimumSize: const Size(0, 48),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: primary ? BorderSide.none : BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TellyTypography.labelMedium(color: primary ? _scrim : _onScrim).copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

/// A 3 dp line: the share of released episodes before your place (features/11 §3.4).
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        key: const Key('home_hero_progress'),
        height: 3,
        child: Stack(
          children: [
            ColoredBox(color: Colors.white.withValues(alpha: 0.18), child: const SizedBox.expand()),
            FractionallySizedBox(
                widthFactor: fraction.clamp(0.0, 1.0),
                child: const ColoredBox(color: _eyebrowLime, child: SizedBox.expand())),
          ],
        ),
      ),
    );
  }
}

/// The other titles you're watching, then *All N ›* (`SCR-21` §21.2). Each opens its title.
class _HeroChips extends ConsumerWidget {
  const _HeroChips({required this.hero});

  final HomeHero hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(trackingNowProvider)();
    if (hero.chips.isEmpty && hero.totalTracked <= 1) return const SizedBox.shrink();
    return SingleChildScrollView(
      key: const Key('home_hero_chips'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          for (final item in hero.chips) ...[
            _Chip(
              key: Key('home_chip_${item.mediaType}_${item.titleId}'),
              item: item,
              fresh: item.group(now) == TrackingGroup.newEpisodes,
              onTap: () => context.push(Routes.title(item.mediaType, item.titleId)),
            ),
            const SizedBox(width: 6),
          ],
          _Chip.all(
            key: const Key('home_chip_all'),
            count: hero.totalTracked,
            onTap: () => context.push(Routes.watching),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required TrackingItem this.item, required this.fresh, required this.onTap}) : count = null;

  const _Chip.all({super.key, required int this.count, required this.onTap})
      : item = null,
        fresh = false;

  final TrackingItem? item;
  final int? count;
  final bool fresh;
  final VoidCallback onTap;

  /// "Slow Horses · E2", an amber "Shōgun · S2 new", or "Dune · Movie".
  static String labelOf(TrackingItem item, {required bool fresh}) {
    if (item.isMovie) return '${item.title} · Movie';
    final next = item.nextEpisode?.ref;
    if (next == null) return item.title;
    if (fresh) return '${item.title} · ${next.episode == 1 ? 'S${next.season}' : 'E${next.episode}'} new';
    return '${item.title} · E${next.episode}';
  }

  @override
  Widget build(BuildContext context) {
    final it = item;
    final amber = TellyColors.warmAmberOf(context);
    final color = fresh ? amber : TellyColors.textSecondaryOf(context);
    final label = it == null ? 'All $count ›' : labelOf(it, fresh: fresh);
    return Semantics(
      button: true,
      label: it == null ? 'All $count tracked titles' : label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: fresh ? amber : TellyColors.strokeOf(context)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (it != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          width: 14,
                          height: 20,
                          child: PosterImage(
                              posterPath: it.posterPath, fallback: ColoredBox(color: TellyColors.cardOf(context))),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TellyTypography.caption(color: color).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
