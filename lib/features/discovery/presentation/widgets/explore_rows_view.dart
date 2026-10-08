import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/poster_image.dart';
import '../../../queue/data/watchlist_repository.dart';
import '../../../queue/domain/streaming_models.dart';
import '../../domain/explore_candidates.dart';
import '../../domain/explore_ranker.dart';
import '../controllers/explore_rows_controller.dart';

/// SCR-07's browse content for one canon (#180): the hero (or the new-user prompt), then the
/// rows in features/07 §7.2 order, then [footer] (network battlegrounds on the Series canon).
/// Sizes and tokens: `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §SCR-07.
class ExploreRowsView extends ConsumerWidget {
  const ExploreRowsView({super.key, required this.mediaType, this.footer});

  final String mediaType;
  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(exploreRowsProvider(mediaType));
    final state = async.valueOrNull;
    if (state == null) {
      if (async.hasError) {
        return _ErrorState(onRetry: () => ref.invalidate(exploreRowsProvider(mediaType)));
      }
      return const _Skeleton();
    }
    final rows = state.rows;
    return Column(
      key: Key('explore_rows_$mediaType'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.isOffline) ...[
          _OfflineBanner(savedAt: state.savedAt, now: ref.watch(exploreNowProvider)()),
          const SizedBox(height: 12),
        ],
        if (rows.isNewUser)
          _NewUserPrompt(mediaType: mediaType, rankingCount: rows.rankingCount)
        else if (rows.hero != null)
          _Hero(hero: rows.hero!, mediaType: mediaType),
        for (final row in rows.rows) ...[
          const SizedBox(height: 20),
          _ExploreRowSection(row: row, mediaType: mediaType, today: ref.watch(exploreNowProvider)()),
        ],
        if (footer != null) ...[const SizedBox(height: 20), footer!],
      ],
    );
  }
}

const _gutter = EdgeInsets.symmetric(horizontal: 16);

String _canonNoun(String mediaType, {bool plural = true}) =>
    mediaType == 'movie' ? (plural ? 'movies' : 'movie') : 'series';

/// "a and b" / "a, b and c".
String _andList(List<String> items) => switch (items.length) {
      0 => '',
      1 => items.first,
      _ => '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}',
    };

// ---------------------------------------------------------------------------------- rows

class _ExploreRowSection extends StatelessWidget {
  const _ExploreRowSection({required this.row, required this.mediaType, required this.today});

  final ExploreRow row;
  final String mediaType;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final items = row.visible;
    return Column(
      key: Key('explore_row_${row.kind.name}${row.seed == null ? '' : '_${row.seed!.titleId}'}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RowHeader(title: _title(context), subtitle: _subtitle()),
        const SizedBox(height: 10),
        switch (row.kind) {
          ExploreRowKind.trending => _Carousel(
              height: 136,
              children: [for (final (i, s) in items.indexed) _Top10Card(rank: i + 1, pick: s)],
            ),
          ExploreRowKind.friends => _Carousel(
              height: 104,
              children: [for (final s in items) _FriendCard(pick: s)],
            ),
          ExploreRowKind.becauseYouRanked => _Carousel(
              height: 196,
              children: [_SeedTile(seed: row.seed!, mediaType: mediaType), for (final s in items) _PosterCard(pick: s, meta: _matchMeta(s))],
            ),
          ExploreRowKind.leavingSoon => _Carousel(
              height: 196,
              children: [for (final s in items) _PosterCard(pick: s, meta: _service(s), badge: _daysLeft(s))],
            ),
          ExploreRowKind.topPicks => _Carousel(
              height: 196,
              children: [for (final s in items) _PosterCard(pick: s, meta: _matchMeta(s))],
            ),
          ExploreRowKind.topRated => _Carousel(
              height: 196,
              children: [for (final s in items) _PosterCard(pick: s, meta: _communityMeta(s))],
            ),
          ExploreRowKind.somethingDifferent => _Carousel(
              height: 196,
              children: [for (final s in items) _PosterCard(pick: s, meta: _genreMeta(s))],
            ),
        },
      ],
    );
  }

  InlineSpan _title(BuildContext context) => switch (row.kind) {
        ExploreRowKind.trending => const TextSpan(text: 'Trending now'),
        ExploreRowKind.topPicks => const TextSpan(text: 'Top picks for you'),
        ExploreRowKind.topRated => const TextSpan(text: 'Top rated on Telly'),
        ExploreRowKind.becauseYouRanked => TextSpan(children: [
            const TextSpan(text: 'Because you ranked '),
            TextSpan(
              text: row.seed!.title,
              style: TellyTypography.displayXL(color: TellyColors.textPrimaryOf(context))
                  .copyWith(fontSize: 16.5, fontStyle: FontStyle.italic, fontWeight: FontWeight.w700, letterSpacing: 0),
            ),
          ]),
        ExploreRowKind.friends => const TextSpan(text: 'Your friends are watching'),
        ExploreRowKind.leavingSoon => const TextSpan(text: 'Leaving your services soon'),
        ExploreRowKind.somethingDifferent => const TextSpan(text: 'Something different'),
      };

  String? _subtitle() => switch (row.kind) {
        ExploreRowKind.trending => 'Top 10 ${_canonNoun(mediaType)} this week',
        ExploreRowKind.somethingDifferent when row.usualGenres.isNotEmpty =>
          'Outside your usual ${_andList(row.usualGenres.map((g) => g.toLowerCase()).toList())}',
        _ => null,
      };

  _Meta _matchMeta(ScoredCandidate s) =>
      _Meta(match: s.matchPct, text: s.candidate.releaseYear == null ? null : '${s.candidate.releaseYear}');

  _Meta _communityMeta(ScoredCandidate s) {
    final c = s.candidate;
    return _Meta(text: c.communityScore != null ? '${c.communityScore!.toStringAsFixed(2)} community' : c.releaseYear?.toString());
  }

  _Meta _genreMeta(ScoredCandidate s) {
    final c = s.candidate;
    return _Meta(text: [
      if (c.genres.isNotEmpty) c.genres.first,
      if (c.communityScore != null) '${c.communityScore!.toStringAsFixed(1)} on Telly',
    ].join(' · '));
  }

  _Meta _service(ScoredCandidate s) =>
      _Meta(text: s.candidate.providers.isEmpty ? null : StreamingPlatform.labelFor(s.candidate.providers.first));

  String? _daysLeft(ScoredCandidate s) {
    final u = s.candidate.leavingUntil;
    if (u == null) return null;
    final days = DateTime.utc(u.year, u.month, u.day).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    if (days <= 0) return 'LAST DAY';
    return days == 1 ? '1 DAY' : '$days DAYS';
  }
}

class _RowHeader extends StatelessWidget {
  const _RowHeader({required this.title, this.subtitle});

  final InlineSpan title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _gutter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text.rich(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TellyTypography.labelLarge(color: TellyColors.textPrimaryOf(context))
                  .copyWith(fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -0.16),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)).copyWith(fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _Carousel extends StatelessWidget {
  const _Carousel({required this.height, required this.children});

  final double height;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: _gutter,
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}

class _Meta {
  const _Meta({this.match, this.text});

  final int? match;
  final String? text;

  String get spoken => [if (match != null) '$match% match', if (text != null && text!.isNotEmpty) text!].join(', ');
}

void _openTitle(BuildContext context, ExploreCandidate c) => context.push(Routes.title(c.mediaType, c.titleId));

/// 104 × 154 poster with a title and one meta line; [badge] is a coral countdown.
class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.pick, required this.meta, this.badge});

  final ScoredCandidate pick;
  final _Meta meta;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final c = pick.candidate;
    final tertiary = TellyColors.textTertiaryOf(context);
    return Semantics(
      button: true,
      label: [c.title, if (badge != null) badge!.toLowerCase(), meta.spoken].where((s) => s.isNotEmpty).join(', '),
      excludeSemantics: true,
      child: InkWell(
        key: Key('explore_card_${c.titleId}'),
        onTap: () => _openTitle(context, c),
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 104,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  _Poster(path: c.posterPath, width: 104, height: 154),
                  if (badge != null) Positioned(left: 6, top: 6, child: _CountdownBadge(label: badge!)),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                c.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TellyTypography.labelMedium(color: TellyColors.textPrimaryOf(context))
                    .copyWith(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              Text.rich(
                TextSpan(children: [
                  if (meta.match != null)
                    TextSpan(
                      text: '${meta.match}% match',
                      style: TextStyle(color: TellyColors.electricVioletOf(context), fontWeight: FontWeight.w800),
                    ),
                  if (meta.match != null && meta.text != null) const TextSpan(text: ' · '),
                  if (meta.text != null) TextSpan(text: meta.text),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TellyTypography.caption(color: tertiary).copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.path, required this.width, required this.height, this.radius = 10});

  final String? path;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: width,
        height: height,
        color: TellyColors.surfaceOf(context),
        child: PosterImage(
          posterPath: path,
          fallback: Center(child: Icon(Icons.movie_outlined, size: 22, color: TellyColors.textTertiaryOf(context))),
        ),
      ),
    );
  }
}

/// "3 DAYS" on Neon Coral. White on dark-theme coral is ~3.2:1, so dark uses canvas text.
class _CountdownBadge extends StatelessWidget {
  const _CountdownBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(color: TellyColors.neonCoralOf(context), borderRadius: BorderRadius.circular(5)),
      child: Text(
        label,
        style: TellyTypography.labelSmall(color: dark ? TellyColors.backgroundPrimary : Colors.white)
            .copyWith(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.57, height: 1),
      ),
    );
  }
}

/// Trending: the rank as an outlined 92 dp numeral overlapping a 92 × 136 poster by 14 dp.
class _Top10Card extends StatelessWidget {
  const _Top10Card({required this.rank, required this.pick});

  final int rank;
  final ScoredCandidate pick;

  @override
  Widget build(BuildContext context) {
    final c = pick.candidate;
    return Semantics(
      button: true,
      label: 'Number $rank trending, ${c.title}',
      excludeSemantics: true,
      child: InkWell(
        key: Key('explore_trending_${c.titleId}'),
        onTap: () => _openTitle(context, c),
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: rank >= 10 ? 160 : 136,
          height: 136,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Positioned(
                left: 0,
                bottom: -6,
                child: Text(
                  '$rank',
                  style: TellyTypography.labelLarge().copyWith(
                    fontSize: 92,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -5.5,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 2
                      ..color = TellyColors.textTertiaryOf(context),
                  ),
                ),
              ),
              _Poster(path: c.posterPath, width: 92, height: 136),
            ],
          ),
        ),
      ),
    );
  }
}

/// The first tile of a Because-you-ranked row: the seed itself, dashed.
class _SeedTile extends StatelessWidget {
  const _SeedTile({required this.seed, required this.mediaType});

  final ExploreSeed seed;
  final String mediaType;

  @override
  Widget build(BuildContext context) {
    final score = seed.score.toStringAsFixed(2);
    return Semantics(
      button: true,
      label: 'You ranked ${seed.title} number ${seed.rank}, $score',
      excludeSemantics: true,
      child: InkWell(
        key: Key('explore_seed_${seed.titleId}'),
        onTap: () => context.push(Routes.title(mediaType, seed.titleId)),
        borderRadius: BorderRadius.circular(10),
        child: Align(
          alignment: Alignment.topCenter,
          child: CustomPaint(
            painter: _DashedRRect(color: TellyColors.strokeSubtleOf(context), radius: 10),
            child: Container(
              width: 104,
              height: 154,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: TellyColors.surfaceOf(context), borderRadius: BorderRadius.circular(10)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('YOU RANKED',
                      style: TellyTypography.labelSmall(color: TellyColors.textTertiaryOf(context))
                          .copyWith(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.63)),
                  const SizedBox(height: 4),
                  Text(seed.title,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TellyTypography.labelMedium(color: TellyColors.textPrimaryOf(context))
                          .copyWith(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('#${seed.rank} · $score',
                      style: TellyTypography.labelMedium(color: TellyColors.warmAmberOf(context))
                          .copyWith(fontWeight: FontWeight.w800, fontFeatures: const [ui.FontFeature.tabularFigures()])),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRRect extends CustomPainter {
  _DashedRRect({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, (d + 5).clamp(0, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRect old) => old.color != color || old.radius != radius;
}

/// 214 dp card: poster, names, up to 3 avatars and the friends' average.
class _FriendCard extends StatelessWidget {
  const _FriendCard({required this.pick});

  final ScoredCandidate pick;

  @override
  Widget build(BuildContext context) {
    final c = pick.candidate;
    final names = c.friends.map((f) => f.displayName.isEmpty ? 'A friend' : f.displayName).toList();
    final who = names.length <= 3 ? _andList(names) : '${names.first} and ${names.length - 1} others';
    final scores = [for (final f in c.friends) if (f.score != null) f.score!];
    final avg = scores.isEmpty ? null : scores.reduce((a, b) => a + b) / scores.length;
    final surface = TellyColors.surfaceOf(context);
    return Semantics(
      button: true,
      label: [c.title, who, if (avg != null) "${avg.toStringAsFixed(1)} friends' average"].join(', '),
      excludeSemantics: true,
      child: InkWell(
        key: Key('explore_friend_${c.titleId}'),
        onTap: () => _openTitle(context, c),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 214,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TellyColors.borderGlassOf(context)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Poster(path: c.posterPath, width: 56, height: 84, radius: 8),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TellyTypography.labelMedium(color: TellyColors.textPrimaryOf(context))
                            .copyWith(fontSize: 13.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(who,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)).copyWith(fontSize: 11)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 22,
                      child: Stack(
                        children: [
                          for (final (i, f) in c.friends.take(3).indexed)
                            Positioned(
                              left: i * 15.0,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: surface, width: 2)),
                                child: CircleAvatar(
                                  backgroundColor: TellyColors.cardOf(context),
                                  child: Text(
                                    f.displayName.isEmpty ? '?' : f.displayName[0].toUpperCase(),
                                    style: TellyTypography.labelSmall(color: TellyColors.textSecondaryOf(context))
                                        .copyWith(fontSize: 9, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (avg != null) ...[
                      const SizedBox(height: 6),
                      Text("★ ${avg.toStringAsFixed(1)} friends' avg",
                          style: TellyTypography.caption(color: TellyColors.warmAmberOf(context))
                              .copyWith(fontSize: 12, fontWeight: FontWeight.w800)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------- hero

class _Hero extends ConsumerStatefulWidget {
  const _Hero({required this.hero, required this.mediaType});

  final ExploreHero hero;
  final String mediaType;

  @override
  ConsumerState<_Hero> createState() => _HeroState();
}

class _HeroState extends ConsumerState<_Hero> {
  /// Titles queued from this hero in this session (the button turns into "✓ In queue").
  final Set<int> _queued = {};

  ExploreCandidate get _c => widget.hero.pick.candidate;

  String _reason() {
    final h = widget.hero;
    final like = h.likeSeeds.isNotEmpty
        ? 'Like ${_andList([for (final s in h.likeSeeds) '${s.title} (${s.score.toStringAsFixed(2)})'])}'
        : h.sharedGenres.isNotEmpty
            ? 'Fits your love of ${_andList(h.sharedGenres.map((g) => g.toLowerCase()).toList())}'
            : null;
    final who = widget.mediaType == 'movie' ? _c.director : _c.originalNetwork;
    final facts = [
      [if (who != null) who, if (_c.releaseYear != null) '${_c.releaseYear}'].join(', '),
      if (h.provider != null) 'on ${StreamingPlatform.labelFor(h.provider!)}',
    ].where((s) => s.isNotEmpty).join(' · ');
    return [if (like != null) like, if (facts.isNotEmpty) facts].join('. ');
  }

  Future<void> _queue() async {
    setState(() => _queued.add(_c.titleId));
    try {
      await ref.read(watchlistRepositoryProvider).add(
            titleId: _c.titleId,
            mediaType: _c.mediaType,
            title: _c.title,
            posterPath: _c.posterPath,
          );
    } catch (_) {
      if (mounted) setState(() => _queued.remove(_c.titleId));
    }
  }

  Future<void> _notForMe() async {
    final id = _c.titleId;
    final title = _c.title;
    final notifier = ref.read(exploreRowsProvider(widget.mediaType).notifier);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await notifier.dismiss(id);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't hide that pick. Try again.")));
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        key: const Key('explore_dismissed_snackbar'),
        content: Text('Hidden from your picks: $title'),
        action: SnackBarAction(label: 'Undo', onPressed: () => notifier.undoDismiss(id)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final queued = _queued.contains(c.titleId);
    final canvas = TellyColors.canvasOf(context);
    final match = widget.hero.pick.matchPct;
    return Padding(
      padding: _gutter,
      child: ClipRRect(
        key: const Key('explore_hero'),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 252,
          decoration: BoxDecoration(
            color: TellyColors.surfaceOf(context),
            border: Border.all(color: TellyColors.borderGlassOf(context)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExcludeSemantics(
                child: PosterImage(posterPath: c.backdropPath ?? c.posterPath, fallback: const SizedBox.shrink()),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.25, 0.78],
                    colors: [canvas.withValues(alpha: 0), canvas.withValues(alpha: 0.94)],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('TOP PICK FOR YOU · $match% MATCH',
                        style: TellyTypography.labelSmall(color: TellyColors.electricVioletOf(context))
                            .copyWith(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.05)),
                    const SizedBox(height: 6),
                    Semantics(
                      header: true,
                      child: Text(c.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TellyTypography.displayXL(color: TellyColors.textPrimaryOf(context))
                              .copyWith(fontSize: 26, fontWeight: FontWeight.w700, height: 1.05)),
                    ),
                    const SizedBox(height: 6),
                    Text(_reason(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context)).copyWith(fontSize: 12.5)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _HeroButton(
                          key: const Key('explore_hero_queue'),
                          label: queued ? '✓ In queue' : '+ Queue',
                          primary: !queued,
                          onPressed: queued ? null : _queue,
                        ),
                        const SizedBox(width: 8),
                        _HeroButton(
                          key: const Key('explore_hero_details'),
                          label: 'Details',
                          onPressed: () => _openTitle(context, c),
                        ),
                        const SizedBox(width: 8),
                        _HeroButton(key: const Key('explore_hero_dismiss'), label: 'Not for me', onPressed: _notForMe),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({super.key, required this.label, required this.onPressed, this.primary = false});

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      backgroundColor: primary ? TellyColors.phosphorLime : TellyColors.cardOf(context),
      foregroundColor: primary ? TellyColors.backgroundPrimary : TellyColors.textPrimaryOf(context),
      disabledForegroundColor: TellyColors.textPrimaryOf(context),
      disabledBackgroundColor: TellyColors.cardOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: primary ? BorderSide.none : BorderSide(color: TellyColors.borderGlassOf(context)),
      ),
      textStyle: TellyTypography.labelMedium().copyWith(fontSize: 12.5, fontWeight: FontWeight.w800),
    );
    return TextButton(onPressed: onPressed, style: style, child: Text(label));
  }
}

// ---------------------------------------------------------------------------------- states

class _NewUserPrompt extends StatelessWidget {
  const _NewUserPrompt({required this.mediaType, required this.rankingCount});

  final String mediaType;
  final int rankingCount;

  @override
  Widget build(BuildContext context) {
    final noun = _canonNoun(mediaType);
    return Padding(
      padding: _gutter,
      child: Container(
        key: const Key('explore_new_user_prompt'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: TellyColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: TellyColors.borderGlassOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PICKS FOR YOU',
                style: TellyTypography.labelSmall(color: TellyColors.electricVioletOf(context))
                    .copyWith(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.05)),
            const SizedBox(height: 8),
            Semantics(
              header: true,
              child: Text('Rank 3 $noun to unlock your picks',
                  style: TellyTypography.displayXL(color: TellyColors.textPrimaryOf(context))
                      .copyWith(fontSize: 22, fontWeight: FontWeight.w700, height: 1.1)),
            ),
            const SizedBox(height: 8),
            Text('Your top picks and "Because you ranked" rows appear once Telly knows your taste.',
                style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context)).copyWith(fontSize: 12.5)),
            const SizedBox(height: 10),
            Semantics(
              label: '$rankingCount of 3 ranked',
              excludeSemantics: true,
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    Container(
                      width: 28,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i < rankingCount ? TellyColors.phosphorLime : TellyColors.strokeSubtleOf(context),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _HeroButton(
              key: const Key('explore_new_user_log'),
              label: '+ Log a ${_canonNoun(mediaType, plural: false)}',
              primary: true,
              onPressed: () => context.push(Routes.log),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.savedAt, required this.now});

  final DateTime savedAt;
  final DateTime now;

  String get _ago {
    final d = now.difference(savedAt);
    if (d.inMinutes < 60) return '${d.inMinutes < 1 ? 1 : d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return d.inDays == 1 ? '1 day ago' : '${d.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _gutter,
      child: Container(
        key: const Key('explore_offline_banner'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: TellyColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TellyColors.borderGlassOf(context)),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off, size: 16, color: TellyColors.textSecondaryOf(context)),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: 'Offline. ', style: TextStyle(color: TellyColors.textPrimaryOf(context), fontWeight: FontWeight.w700)),
                  TextSpan(text: 'Showing picks from $_ago.'),
                ]),
                style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context)).copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('explore_error'),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        children: [
          Text("Couldn't load Explore. Check your connection and pull to try again.",
              textAlign: TextAlign.center,
              style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context))),
          const SizedBox(height: 12),
          _HeroButton(key: const Key('explore_retry'), label: 'Try again', primary: true, onPressed: onRetry),
        ],
      ),
    );
  }
}

/// Loading with no cache: a skeleton hero and two rows. The shimmer stops under reduced motion.
class _Skeleton extends StatefulWidget {
  const _Skeleton();

  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _shimmer.stop();
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = TellyColors.surfaceOf(context);
    final b = TellyColors.cardOf(context);
    Widget box(double w, double h, double r) => AnimatedBuilder(
          animation: _shimmer,
          builder: (context, _) => Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(r),
              gradient: LinearGradient(
                begin: Alignment(-1 - 2 * (1 - _shimmer.value), 0),
                end: Alignment(1 + 2 * _shimmer.value, 0),
                colors: [a, b, a],
              ),
            ),
          ),
        );
    Widget row() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: _gutter, child: box(150, 14, 4)),
            const SizedBox(height: 10),
            SizedBox(
              height: 154,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: _gutter,
                children: [for (var i = 0; i < 4; i++) Padding(padding: const EdgeInsets.only(right: 10), child: box(104, 154, 10))],
              ),
            ),
          ],
        );
    return Semantics(
      key: const Key('explore_skeleton'),
      label: 'Loading Explore',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(padding: _gutter, child: box(double.infinity, 252, 18)),
            const SizedBox(height: 20),
            row(),
            const SizedBox(height: 20),
            row(),
          ],
        ),
      ),
    );
  }
}
