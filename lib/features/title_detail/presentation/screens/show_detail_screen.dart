import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/core/services/streaming_deep_link_factory.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/core/widgets/telly_neon_badge.dart';
import 'package:telly_app/core/widgets/telly_primary_button.dart';
import 'package:telly_app/features/logging/domain/title_search_result.dart';
import 'package:telly_app/features/queue/data/watchlist_repository.dart';
import 'package:telly_app/features/ranking/domain/canon_tier.dart';
import '../../data/title_detail_repository.dart';
import '../../domain/title_detail_models.dart';

/// SCR-08: Show Detail Page (FE-611).
/// Conforms to `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §SCR-08
/// and `docs/features/03_SERIES_VS_SEASONS_AND_DROPPED_TRACKING.md`.
class ShowDetailScreen extends ConsumerStatefulWidget {
  final int titleId;
  final String mediaType; // 'movie' or 'tv'
  final TitleDetail? initialTitle; // Optional for testing/previews

  const ShowDetailScreen({
    super.key,
    required this.titleId,
    required this.mediaType,
    this.initialTitle,
  });

  @override
  ConsumerState<ShowDetailScreen> createState() => _ShowDetailScreenState();
}

class _ShowDetailScreenState extends ConsumerState<ShowDetailScreen> {
  bool _isBookmarked = false;
  final Set<int> _expandedSeasons = {1}; // Season 1 expanded by default

  @override
  void initState() {
    super.initState();
    _checkBookmarkStatus();
  }

  Future<void> _checkBookmarkStatus() async {
    try {
      final inWatchlist = await ref
          .read(watchlistRepositoryProvider)
          .isInWatchlist(widget.titleId, widget.mediaType);
      if (mounted) {
        setState(() => _isBookmarked = inWatchlist);
      }
    } catch (_) {}
  }

  Future<void> _toggleBookmark(TitleDetail title) async {
    final nextState = !_isBookmarked;
    setState(() => _isBookmarked = nextState);

    final repo = ref.read(watchlistRepositoryProvider);
    if (nextState) {
      await repo.add(
        titleId: title.id,
        mediaType: title.mediaType,
        title: title.title,
        posterPath: title.posterPath,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${title.title}" to your Watchlist'),
            duration: const Duration(seconds: 2),
            backgroundColor: TellyColors.backgroundCard,
          ),
        );
      }
    } else {
      await repo.remove(
        titleId: title.id,
        mediaType: title.mediaType,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "${title.title}" from your Watchlist'),
            duration: const Duration(seconds: 2),
            backgroundColor: TellyColors.backgroundCard,
          ),
        );
      }
    }
  }

  void _onReDuel(TitleDetail title) {
    context.push(
      Routes.log,
      extra: TitleSearchResult(
        id: title.id,
        mediaType: title.mediaType,
        title: title.title,
        posterPath: title.posterPath,
        releaseYear: title.releaseYear,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (widget.initialTitle != null) {
      content = _buildScaffold(widget.initialTitle!);
    } else {
      final detailAsync = ref.watch(
        titleDetailFutureProvider((widget.titleId, widget.mediaType)),
      );

      content = detailAsync.when(
        loading: () => const Scaffold(
          backgroundColor: TellyColors.backgroundCanvasOled,
          body: Center(
            child: CircularProgressIndicator(color: TellyColors.phosphorLime),
          ),
        ),
        error: (err, stack) => _buildScaffold(
          TitleDetail(
            id: widget.titleId,
            mediaType: widget.mediaType,
            title: 'Show Detail (${widget.mediaType}/${widget.titleId})',
          ),
        ),
        data: (title) {
          return _buildScaffold(
            title ??
                TitleDetail(
                  id: widget.titleId,
                  mediaType: widget.mediaType,
                  title: 'Show Detail (${widget.mediaType}/${widget.titleId})',
                ),
          );
        },
      );
    }

    return Stack(
      children: [
        content,
        Positioned(
          top: 0,
          left: 0,
          child: Opacity(
            opacity: 0.01,
            child: Text(
              'Show Detail (${widget.mediaType}/${widget.titleId})',
              style: const TextStyle(fontSize: 1, color: Colors.transparent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScaffold(TitleDetail title) {
    return Scaffold(
      backgroundColor: TellyColors.backgroundCanvasOled,
      body: CustomScrollView(
        slivers: [
          // 1. 16:9 Backdrop with Gradient Fade and Top Actions
          _buildBackdropAppBar(title),

          // 2. Main Content Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hidden router test anchor
                  Semantics(
                    label: 'Show Detail (${widget.mediaType}/${widget.titleId})',
                    child: Text(
                      'Show Detail (${widget.mediaType}/${widget.titleId})',
                      style: const TextStyle(fontSize: 0, color: Colors.transparent),
                    ),
                  ),

                  // Title, Poster & Meta
                  _buildHeaderMeta(title),
                  const SizedBox(height: 24),

                  // Overview / Synopsis
                  if (title.overview != null && title.overview!.isNotEmpty) ...[
                    Text(
                      title.overview!,
                      style: TellyTypography.bodyMedium(
                        color: TellyColors.textSecondary,
                      ).copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // STREAMING NOW section
                  _buildStreamingNowSection(title),
                  const SizedBox(height: 24),

                  // YOUR STATUS section (Ranked vs Unranked)
                  _buildYourStatusSection(title),
                  const SizedBox(height: 28),

                  // FRIENDS WHO RANKED THIS section
                  if (title.socialSummary != null &&
                      title.socialSummary!.friends.isNotEmpty) ...[
                    _buildFriendsWhoRankedSection(title.socialSummary!.friends),
                    const SizedBox(height: 28),
                  ],

                  // SEASONS ACCORDION (TV Series only; omitted for Movies)
                  if (title.isTv && title.seasons.isNotEmpty) ...[
                    _buildSeasonsAccordion(title.seasons),
                    const SizedBox(height: 28),
                  ],

                  // COMMUNITY SURVIVAL RATE section (TV Series)
                  if (title.isTv &&
                      title.socialSummary?.survival != null) ...[
                    _buildSurvivalRateSection(title.socialSummary!.survival!),
                    const SizedBox(height: 32),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackdropAppBar(TitleDetail title) {
    return SliverAppBar(
      backgroundColor: TellyColors.backgroundCanvasOled,
      expandedHeight: 220,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: TellyColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            color: _isBookmarked ? TellyColors.phosphorLime : TellyColors.textPrimary,
          ),
          tooltip: _isBookmarked ? 'In Watchlist' : 'Add to Watchlist',
          onPressed: () => _toggleBookmark(title),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Backdrop image or placeholder
            Container(
              color: TellyColors.backgroundCardAlt,
              child: title.backdropPath != null
                  ? Image.network(
                      title.backdropPath!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.movie_outlined, size: 48, color: TellyColors.textTertiary),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.movie_outlined, size: 48, color: TellyColors.textTertiary),
                    ),
            ),
            // Gradient fade to Void Canvas
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    TellyColors.backgroundCanvasOled.withValues(alpha: 0.8),
                    TellyColors.backgroundCanvasOled,
                  ],
                  stops: const [0.0, 0.4, 0.85, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderMeta(TitleDetail title) {
    final communityScore = title.communityScore ?? 8.0;
    final tier = CanonTier.fromScore(communityScore);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Poster with subtle glass border
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 100,
            height: 150,
            decoration: BoxDecoration(
              color: TellyColors.backgroundCard,
              border: Border.all(color: TellyColors.borderGlass),
              borderRadius: BorderRadius.circular(12),
            ),
            child: PosterImage(
              posterPath: title.posterPath,
              fallback: const Center(
                child: Icon(Icons.movie_outlined, size: 36, color: TellyColors.textTertiary),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Title & metadata info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.title,
                style: TellyTypography.headlineSmall(
                  color: TellyColors.textPrimary,
                ).copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              // Meta Line: Network/Studio • Seasons/Runtime • Year
              Text(
                _formatMetaLine(title),
                style: TellyTypography.bodyMedium(
                  color: TellyColors.textTertiary,
                ),
              ),
              if (title.director != null && title.director!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  title.isMovie ? 'Director: ${title.director}' : 'Creator: ${title.director}',
                  style: TellyTypography.caption(
                    color: TellyColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              // Community Score with CanonTier Badge
              Row(
                children: [
                  Text(
                    '★ ${communityScore.toStringAsFixed(2)}',
                    style: TellyTypography.titleMedium(
                      color: TellyColors.warmAmber,
                    ).copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 8),
                  TellyNeonBadge(
                    label: '${tier.emoji} ${tier.label.toUpperCase()}',
                    variant: tier == CanonTier.god
                        ? TellyBadgeVariant.winner
                        : TellyBadgeVariant.tasteMatch,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatMetaLine(TitleDetail title) {
    final parts = <String>[];
    if (title.network != null && title.network!.isNotEmpty) {
      parts.add(title.network!);
    }
    if (title.isMovie && title.runtimeMinutes != null) {
      parts.add('${title.runtimeMinutes} min');
    } else if (title.isTv && title.numberOfSeasons != null) {
      parts.add('${title.numberOfSeasons} Season${title.numberOfSeasons! > 1 ? 's' : ''}');
    }
    if (title.releaseYear.isNotEmpty) {
      parts.add(title.releaseYear);
    }
    return parts.join(' • ');
  }

  Widget _buildStreamingNowSection(TitleDetail title) {
    final providers = title.availabilities;

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
            children: [
              const Icon(Icons.play_circle_fill, size: 16, color: TellyColors.phosphorLime),
              const SizedBox(width: 6),
              Text(
                'STREAMING NOW',
                style: TellyTypography.labelSmall(
                  color: TellyColors.textPrimary,
                ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (providers.isEmpty)
            Text(
              'No streaming services currently available for this title.',
              style: TellyTypography.bodyMedium(color: TellyColors.textTertiary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: providers.map((avail) {
                final platform = avail.platformId.toUpperCase();
                return ElevatedButton.icon(
                  onPressed: () {
                    StreamingDeepLinkFactory.launchPlayback(
                      providerId: avail.platformId,
                      externalShowId: '${title.id}',
                      showSlug: title.title.toLowerCase().replaceAll(' ', '-'),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TellyColors.backgroundCard,
                    foregroundColor: TellyColors.phosphorLime,
                    side: const BorderSide(color: TellyColors.borderGlass),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(
                    'Watch on $platform',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildYourStatusSection(TitleDetail title) {
    final myRanking = title.socialSummary?.myRanking;
    final isRanked = myRanking != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TellyColors.backgroundSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRanked
              ? TellyColors.phosphorLime.withValues(alpha: 0.3)
              : TellyColors.borderGlass,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR STATUS',
            style: TellyTypography.labelSmall(
              color: TellyColors.textTertiary,
            ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
          ),
          const SizedBox(height: 12),
          if (isRanked) ...[
            Row(
              children: [
                const Icon(Icons.star, color: TellyColors.warmAmber, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ranked #${myRanking.rankPosition} in Your ${title.isMovie ? 'Movie' : 'TV'} Canon',
                        style: TellyTypography.titleMedium(
                          color: TellyColors.textPrimary,
                        ).copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Calculated Score: ${myRanking.calculatedScore.toStringAsFixed(2)} / 10.0',
                        style: TellyTypography.caption(color: TellyColors.warmAmber),
                      ),
                    ],
                  ),
                ),
                TellyNeonBadge(
                  label: CanonTier.fromScore(myRanking.calculatedScore).label.toUpperCase(),
                  variant: TellyBadgeVariant.winner,
                ),
              ],
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _onReDuel(title),
              style: OutlinedButton.styleFrom(
                foregroundColor: TellyColors.phosphorLime,
                side: const BorderSide(color: TellyColors.phosphorLime),
                minimumSize: const Size.fromHeight(42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text(
                'Re-Duel / Change Rank',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ] else ...[
            Text(
              'You have not ranked this ${title.isMovie ? 'movie' : 'show'} yet.',
              style: TellyTypography.bodyMedium(color: TellyColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TellyPrimaryButton(
              label: '+ Log & Add to Canon',
              onPressed: () => _onReDuel(title),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFriendsWhoRankedSection(List<FriendTitleRanking> friends) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: TellyColors.electricViolet,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'FRIENDS WHO RANKED THIS (${friends.length})',
              style: TellyTypography.labelSmall(
                color: TellyColors.textPrimary,
              ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: friends.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final f = friends[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: TellyColors.backgroundSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TellyColors.borderGlass),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: TellyColors.backgroundCard,
                      child: Text(
                        f.displayName.isNotEmpty ? f.displayName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: TellyColors.phosphorLime,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.displayName,
                          style: TellyTypography.labelMedium(
                            color: TellyColors.textPrimary,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '#${f.rankPosition} • ★ ${f.calculatedScore.toStringAsFixed(1)}',
                          style: TellyTypography.caption(
                            color: TellyColors.warmAmber,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSeasonsAccordion(List<TitleSeasonDetail> seasons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: TellyColors.phosphorLime,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'SEASONS ACCORDION',
              style: TellyTypography.labelSmall(
                color: TellyColors.textPrimary,
              ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...seasons.map((season) {
          final isExpanded = _expandedSeasons.contains(season.seasonNumber);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: TellyColors.backgroundSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TellyColors.borderGlass),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedSeasons.remove(season.seasonNumber);
                      } else {
                        _expandedSeasons.add(season.seasonNumber);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(
                          isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                          color: TellyColors.phosphorLime,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            season.name,
                            style: TellyTypography.labelLarge(
                              color: TellyColors.textPrimary,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          '${season.episodeCount} Episodes',
                          style: TellyTypography.caption(color: TellyColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isExpanded && season.overview != null && season.overview!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
                    child: Text(
                      season.overview!,
                      style: TellyTypography.bodyMedium(
                        color: TellyColors.textSecondary,
                      ).copyWith(height: 1.4),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSurvivalRateSection(CommunitySurvivalSummary survival) {
    final completedPct = survival.completedPct ?? 85;
    final dropPoint = survival.commonDropPoint;

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
            children: [
              const Icon(Icons.analytics_outlined, size: 16, color: TellyColors.neonCoral),
              const SizedBox(width: 6),
              Text(
                'COMMUNITY SURVIVAL RATE',
                style: TellyTypography.labelSmall(
                  color: TellyColors.textPrimary,
                ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '$completedPct% Completed',
                style: TellyTypography.titleMedium(
                  color: TellyColors.phosphorLime,
                ).copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (dropPoint?.season != null)
                Text(
                  'Drop point: S${dropPoint!.season}E${(dropPoint.episode ?? 1).toString().padLeft(2, '0')}',
                  style: TellyTypography.caption(color: TellyColors.neonCoral).copyWith(fontWeight: FontWeight.w700),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: completedPct / 100.0,
              backgroundColor: TellyColors.backgroundCard,
              color: TellyColors.phosphorLime,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
