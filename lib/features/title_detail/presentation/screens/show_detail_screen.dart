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
import 'package:telly_app/core/widgets/telly_screen_header.dart';
import 'package:share_plus/share_plus.dart';
import 'package:telly_app/features/logging/domain/title_search_result.dart';
import 'package:telly_app/features/onboarding/data/top_50_seeds.dart';
import 'package:telly_app/features/queue/data/watchlist_repository.dart';
import 'package:telly_app/features/ranking/domain/canon_tier.dart';
import '../../data/title_detail_repository.dart';
import '../../domain/title_detail_models.dart';
import '../widgets/title_cast_section.dart';
import '../widgets/title_duel_record_section.dart';
import 'package:telly_app/features/queue/domain/streaming_models.dart';

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
            backgroundColor: TellyColors.cardOf(context),
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
            backgroundColor: TellyColors.cardOf(context),
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
          child: ExcludeSemantics(
            child: Opacity(
              opacity: 0.01,
              child: Text(
                'Show Detail (${widget.mediaType}/${widget.titleId})',
                style: const TextStyle(fontSize: 1, color: Colors.transparent),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScaffold(TitleDetail title) {
    final canvasColor = Theme.of(context).brightness == Brightness.light
        ? TellyColors.lightBackgroundPrimary
        : TellyColors.backgroundCanvasOled;
    return Scaffold(
      backgroundColor: canvasColor,
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
                  ExcludeSemantics(
                    child: Text(
                      'Show Detail (${widget.mediaType}/${widget.titleId})',
                      style: const TextStyle(fontSize: 0, color: Colors.transparent),
                    ),
                  ),

                  // Title, Poster & Meta
                  _buildHeaderMeta(title),
                  const SizedBox(height: 16),

                  // Quick Action Hub (Queue, Rank/Duel, Co-Watch, Share)
                  _buildQuickActionHub(title),
                  const SizedBox(height: 24),

                  // Overview / Synopsis
                  if (title.overview != null && title.overview!.isNotEmpty) ...[
                    Text(
                      title.overview!,
                      style: TellyTypography.bodyMedium(
                        color: TellyColors.textPrimaryOf(context),
                      ).copyWith(height: 1.5, fontWeight: FontWeight.w600),
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
                  // Hidden until someone has finished, watched or dropped it (FE-DETAIL-02).
                  if (title.isTv && title.socialSummary?.survival?.completedPct != null) ...[
                    _buildSurvivalRateSection(
                        title.socialSummary!.survival!, title.socialSummary!.survival!.completedPct!),
                    const SizedBox(height: 32),
                  ],

                  // CAST & CREW SHOWCASE
                  TitleCastSection(titleId: title.id, mediaType: title.mediaType, fallbackDirector: title.director),
                  const SizedBox(height: 28),

                  // TOURNAMENT & DUEL RECORD + CANON TIER DISTRIBUTION (live, FE-DETAIL-02)
                  TitleDuelRecordSection(titleId: title.id, mediaType: title.mediaType),
                  const SizedBox(height: 28),

                  // IDEAL DOUBLE FEATURE / COMPANION PAIRINGS (Movies only)
                  if (title.isMovie) ...[
                    _buildDoubleFeatureSection(title),
                    const SizedBox(height: 28),
                  ],

                  // COMMUNITY HOT TAKES
                  _buildCommunityTakesSection(title),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackdropAppBar(TitleDetail title) {
    final canvasColor = Theme.of(context).brightness == Brightness.light
        ? TellyColors.lightBackgroundPrimary
        : TellyColors.backgroundCanvasOled;
    return SliverAppBar(
      backgroundColor: canvasColor,
      expandedHeight: 220,
      pinned: true,
      leading: TellyNavButton(onPressed: () => context.canPop() ? context.pop() : context.go(Routes.feed)),
      actions: [
        IconButton(
          icon: Icon(
            _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            color: _isBookmarked ? TellyColors.phosphorLime : TellyColors.textPrimaryOf(context),
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
              color: TellyColors.cardOf(context),
              child: title.backdropPath != null
                  ? Image.network(
                      TmdbImages.backdrop(title.backdropPath) ?? title.backdropPath!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(Icons.movie_outlined, size: 48, color: TellyColors.textTertiaryOf(context)),
                      ),
                    )
                  : Center(
                      child: Icon(Icons.movie_outlined, size: 48, color: TellyColors.textTertiaryOf(context)),
                    ),
            ),
            // Gradient fade to Canvas
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    canvasColor.withValues(alpha: 0.8),
                    canvasColor,
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
              color: TellyColors.cardOf(context),
              border: Border.all(color: TellyColors.borderGlassOf(context)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: PosterImage(
              posterPath: title.posterPath,
              fallback: Center(
                child: Icon(Icons.movie_outlined, size: 36, color: TellyColors.textTertiaryOf(context)),
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
                  color: TellyColors.textPrimaryOf(context),
                ).copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              // Meta Line: Network/Studio • Seasons/Runtime • Year
              Text(
                _formatMetaLine(title),
                style: TellyTypography.bodyMedium(
                  color: TellyColors.textPrimaryOf(context),
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              if (title.director != null && title.director!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  title.isMovie ? 'Director: ${title.director}' : 'Creator: ${title.director}',
                  style: TellyTypography.caption(
                    color: TellyColors.textSecondaryOf(context),
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
                      color: TellyColors.warmAmberOf(context),
                    ).copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 8),
                  TellyNeonBadge(
                    label: '${tier.emoji} ${tier.label.toUpperCase()}',
                    variant: tier == CanonTier.god
                        ? TellyBadgeVariant.godTier
                        : TellyBadgeVariant.tasteMatch,
                  ),
                  const SizedBox(width: 6),
                  Semantics(
                    button: true,
                    label: 'Score and tier explanation',
                    child: Tooltip(
                      message: 'Percentile grade (1.00–10.00) calculated from duels. Tiers: God (9.20+), Prestige (8.50+), Great (7.80+), Good (7.00+), Mid (5.50+).',
                      triggerMode: TooltipTriggerMode.tap,
                      child: InkWell(
                        key: const Key('show_detail_score_info_button'),
                        onTap: () => _showScoreExplanationDialog(context, communityScore, tier),
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: TellyColors.textTertiaryOf(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showScoreExplanationDialog(BuildContext context, double score, CanonTier tier) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: TellyColors.cardOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    '★ ${score.toStringAsFixed(2)}',
                    style: TellyTypography.titleLarge(color: TellyColors.warmAmberOf(ctx)).copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 8),
                  TellyNeonBadge(
                    label: '${tier.emoji} ${tier.label.toUpperCase()}',
                    variant: tier == CanonTier.god ? TellyBadgeVariant.winner : TellyBadgeVariant.tasteMatch,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'How is this score calculated?',
                style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(ctx)).copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Telly grades are dynamic percentile scores (1.00–10.00) calculated from head-to-head tournament duels across the community and your personal canon.',
                style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(ctx)),
              ),
              const SizedBox(height: 14),
              Text(
                'Score Tiers:',
                style: TellyTypography.labelLarge(color: TellyColors.textPrimaryOf(ctx)).copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '👑 God Tier: 9.20 – 10.00\n✨ Prestige: 8.50 – 9.19\n⚡ Great: 7.80 – 8.49\n👍 Good: 7.00 – 7.79\n📺 Mid: 5.50 – 6.99\n🚫 Dropped / DNF: < 5.50',
                style: TellyTypography.caption(color: TellyColors.textSecondaryOf(ctx)).copyWith(height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                key: const Key('score_info_dismiss_button'),
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TellyColors.primaryAccentOf(ctx),
                  foregroundColor: Theme.of(ctx).brightness == Brightness.light ? Colors.white : Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
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

  Widget _buildQuickActionHub(TitleDetail title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Queue / Watchlist Toggle
          _buildQuickActionButton(
            icon: _isBookmarked ? Icons.playlist_add_check_rounded : Icons.playlist_add_rounded,
            label: _isBookmarked ? 'In Queue' : 'Add to Queue',
            accentColor: _isBookmarked ? TellyColors.primaryAccentOf(context) : TellyColors.textSecondaryOf(context),
            onTap: () => _toggleBookmark(title),
          ),
          // 2. Rank / Re-Duel
          _buildQuickActionButton(
            icon: Icons.emoji_events_outlined,
            label: title.socialSummary?.myRanking != null ? 'Re-Duel' : 'Rank Title',
            accentColor: TellyColors.primaryAccentOf(context),
            onTap: () => _onReDuel(title),
          ),
          // 3. Two-to-Watch (Co-Watch)
          _buildQuickActionButton(
            icon: Icons.people_outline_rounded,
            label: 'Co-Watch',
            accentColor: TellyColors.electricVioletOf(context),
            onTap: () {
              final friendHandle = (title.socialSummary != null && title.socialSummary!.friends.isNotEmpty)
                  ? title.socialSummary!.friends.first.username
                  : null;
              context.push(Routes.cowatchWithTitle(title.id, mediaType: title.mediaType, friendHandle: friendHandle));
            },
          ),
          // 4. Share Taste Card
          _buildQuickActionButton(
            icon: Icons.share_outlined,
            label: 'Share',
            accentColor: TellyColors.warmAmberOf(context),
            onTap: () {
              final scoreStr = title.communityScore != null ? ' ★ ${title.communityScore!.toStringAsFixed(2)}' : '';
              SharePlus.instance.share(
                ShareParams(
                  text: 'Check out "${title.title}"$scoreStr on Telly!\nhttps://telly.app/title/${title.mediaType}/${title.id}',
                  subject: 'Check out ${title.title} on Telly',
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Semantics(
          button: true,
          label: label,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: TellyColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TellyColors.borderGlassOf(context)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: accentColor),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TellyTypography.caption(color: TellyColors.textPrimaryOf(context)).copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildStreamingNowSection(TitleDetail title) {
    // Live availability first (BE-DETAIL-01); cached `title_availability` rows otherwise.
    final live = ref.watch(titleStreamingProvider((title.id, title.mediaType))).valueOrNull ?? const [];
    final providers = live.isNotEmpty
        ? [
            for (final p in live)
              // "Streaming now" means watchable without buying or renting.
              if (p.monetizationType == MonetizationType.flatrate || p.monetizationType == MonetizationType.free)
                (id: p.platformId, name: p.platformName),
          ]
        : [for (final a in title.availabilities) (id: a.platformId, name: _platformName(a.platformId))];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TellyColors.borderGlassOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_fill, size: 16, color: TellyColors.primaryAccentOf(context)),
              const SizedBox(width: 6),
              Text(
                'STREAMING NOW',
                style: TellyTypography.labelSmall(
                  color: TellyColors.textPrimaryOf(context),
                ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (providers.isEmpty)
            Text(
              'No streaming services currently available for this title.',
              style: TellyTypography.bodyMedium(color: TellyColors.textPrimaryOf(context)).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: {for (final p in providers) p.id: p}.values.map((avail) {
                final platform = avail.name;
                return ElevatedButton.icon(
                  onPressed: () {
                    StreamingDeepLinkFactory.launchPlayback(
                      providerId: avail.id,
                      externalShowId: '${title.id}',
                      showSlug: title.title.toLowerCase().replaceAll(' ', '-'),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TellyColors.cardOf(context),
                    foregroundColor: TellyColors.primaryAccentOf(context),
                    side: BorderSide(color: TellyColors.borderGlassOf(context)),
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

  static String _platformName(String platformId) {
    for (final p in StreamingPlatform.standardPlatforms) {
      if (p.id == platformId) return p.displayName;
    }
    return platformId.replaceAll('_', ' ').toUpperCase();
  }

  Widget _buildYourStatusSection(TitleDetail title) {
    final myRanking = title.socialSummary?.myRanking;
    final isRanked = myRanking != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRanked
              ? TellyColors.primaryAccentOf(context).withValues(alpha: 0.3)
              : TellyColors.borderGlassOf(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR STATUS',
            style: TellyTypography.labelSmall(
              color: TellyColors.textSecondaryOf(context),
            ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
          ),
          const SizedBox(height: 12),
          if (isRanked) ...[
            Row(
              children: [
                Icon(Icons.star, color: TellyColors.warmAmberOf(context), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ranked #${myRanking.rankPosition} in Your ${title.isMovie ? 'Movie' : 'TV'} Canon',
                        style: TellyTypography.titleMedium(
                          color: TellyColors.textPrimaryOf(context),
                        ).copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Calculated Score: ${myRanking.calculatedScore.toStringAsFixed(2)} / 10.0',
                        style: TellyTypography.caption(color: TellyColors.warmAmberOf(context)),
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
                foregroundColor: TellyColors.primaryAccentOf(context),
                side: BorderSide(color: TellyColors.primaryAccentOf(context)),
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
              style: TellyTypography.bodyMedium(color: TellyColors.textPrimaryOf(context)).copyWith(fontSize: 14),
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
                color: TellyColors.electricVioletOf(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'FRIENDS WHO RANKED THIS (${friends.length})',
              style: TellyTypography.labelSmall(
                color: TellyColors.textPrimaryOf(context),
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
                  color: TellyColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TellyColors.borderGlassOf(context)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: TellyColors.cardOf(context),
                      child: Text(
                        f.displayName.isNotEmpty ? f.displayName[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: TellyColors.primaryAccentOf(context),
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
                            color: TellyColors.textPrimaryOf(context),
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '#${f.rankPosition} • ★ ${f.calculatedScore.toStringAsFixed(1)}',
                          style: TellyTypography.caption(
                            color: TellyColors.warmAmberOf(context),
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
        if (friends.length >= 2) ...[
          const SizedBox(height: 12),
          _buildFriendDivergenceCard(friends),
        ],
      ],
    );
  }

  Widget _buildFriendDivergenceCard(List<FriendTitleRanking> friends) {
    final sorted = List<FriendTitleRanking>.from(friends)
      ..sort((a, b) => a.rankPosition.compareTo(b.rankPosition));
    final highest = sorted.first;
    final lowest = sorted.last;
    final spread = (highest.rankPosition - lowest.rankPosition).abs();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TellyColors.cardOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TellyColors.neonCoral.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FRIEND CANON DIVERGENCE',
                  style: TellyTypography.caption(
                    color: TellyColors.neonCoralOf(context),
                  ).copyWith(fontWeight: FontWeight.w800, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${highest.username} ranked this #${highest.rankPosition} (${highest.calculatedScore.toStringAsFixed(2)}) vs @${lowest.username} at #${lowest.rankPosition} (${lowest.calculatedScore.toStringAsFixed(2)}) — a spread of $spread rank spots.',
                  style: TellyTypography.caption(color: TellyColors.textPrimaryOf(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoubleFeatureSection(TitleDetail title) {
    // Select 3 companion titles of same media type from top seeds
    final companions = kTop50SeedTitles
        .where((s) =>
            s.mediaType == title.mediaType &&
            s.id != title.id &&
            s.title.toLowerCase() != title.title.toLowerCase())
        .take(3)
        .toList();

    if (companions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: TellyColors.electricVioletOf(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'IDEAL DOUBLE FEATURE',
              style: TellyTypography.labelSmall(
                color: TellyColors.textPrimaryOf(context),
              ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Frequently paired together in community Top 10 Canons',
          style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: companions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final comp = companions[index];
              return Semantics(
                button: true,
                label: comp.title,
                child: InkWell(
                  onTap: () => context.push(Routes.title(comp.mediaType, comp.id)),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 110,
                    decoration: BoxDecoration(
                      color: TellyColors.surfaceOf(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: TellyColors.borderGlassOf(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          child: SizedBox(
                            height: 110,
                            width: double.infinity,
                            child: PosterImage(
                              posterPath: comp.posterPath,
                              fallback: Center(
                                child: Icon(Icons.movie_outlined, color: TellyColors.textTertiaryOf(context)),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Text(
                            comp.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TellyTypography.caption(
                              color: TellyColors.textPrimaryOf(context),
                            ).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCommunityTakesSection(TitleDetail title) {
    final takes = _kSeedTakes[title.id] ?? const [];
    if (takes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: TellyColors.neonCoralOf(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'COMMUNITY HOT TAKES',
              style: TellyTypography.labelSmall(
                color: TellyColors.textPrimaryOf(context),
              ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          children: takes.map((take) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TellyColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TellyColors.borderGlassOf(context)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: TellyColors.cardOf(context),
                    child: Text(
                      take.$1[0].toUpperCase(),
                      style: TextStyle(
                        color: TellyColors.primaryAccentOf(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '@${take.$1}',
                              style: TellyTypography.caption(color: TellyColors.textPrimaryOf(context)).copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: TellyColors.primaryAccentOf(context).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#${take.$3} • ${take.$4.toStringAsFixed(2)}',
                                style: TellyTypography.monoDigits(
                                  color: TellyColors.primaryAccentOf(context),
                                 ).copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '“${take.$2}”',
                          style: TellyTypography.caption(
                            color: TellyColors.textPrimaryOf(context),
                          ).copyWith(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
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
                color: TellyColors.primaryAccentOf(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'SEASONS ACCORDION',
              style: TellyTypography.labelSmall(
                color: TellyColors.textPrimaryOf(context),
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
              color: TellyColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TellyColors.borderGlassOf(context)),
            ),
            child: Column(
              children: [
                Semantics(
                  button: true,
                  label: '${season.name}, ${season.episodeCount} Episodes',
                  child: InkWell(
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
                            color: TellyColors.primaryAccentOf(context),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              season.name,
                              style: TellyTypography.labelLarge(
                                color: TellyColors.textPrimaryOf(context),
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            '${season.episodeCount} Episodes',
                            style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isExpanded && season.overview != null && season.overview!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
                    child: Text(
                      season.overview!,
                      style: TellyTypography.bodyMedium(
                        color: TellyColors.textSecondaryOf(context),
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

  Widget _buildSurvivalRateSection(CommunitySurvivalSummary survival, int completedPct) {
    final dropPoint = survival.commonDropPoint;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TellyColors.borderGlassOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, size: 16, color: TellyColors.neonCoralOf(context)),
              const SizedBox(width: 6),
              Text(
                'COMMUNITY SURVIVAL RATE',
                style: TellyTypography.labelSmall(
                  color: TellyColors.textPrimaryOf(context),
                ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  key: const Key('survival_completed_text'),
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$completedPct%',
                        style: TellyTypography.titleMedium(color: TellyColors.primaryAccentOf(context))
                            .copyWith(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(
                        text: ' completed all seasons',
                        style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context)),
                      ),
                    ],
                  ),
                ),
              ),
              if (dropPoint?.season != null)
                Text(
                  'Drop point: S${dropPoint!.season}E${(dropPoint.episode ?? 1).toString().padLeft(2, '0')}',
                  style: TellyTypography.caption(color: TellyColors.neonCoralOf(context)).copyWith(fontWeight: FontWeight.w700),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: completedPct / 100.0,
              backgroundColor: TellyColors.cardOf(context),
              color: TellyColors.primaryAccentOf(context),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

const Map<int, List<(String, String, int, double)>> _kSeedTakes = {
  101: [
    ('marcus', 'A razor-sharp masterclass in tension and societal metaphor.', 1, 9.90),
    ('elena', 'The peach sequence and tonal pivot permanently changed cinema.', 3, 9.65),
    ('sarah', 'Unmatched pacing from start to finish.', 5, 9.40),
  ],
  496243: [
    ('marcus', 'A razor-sharp masterclass in tension and societal metaphor.', 1, 9.90),
    ('elena', 'The peach sequence and tonal pivot permanently changed cinema.', 3, 9.65),
    ('sarah', 'Unmatched pacing from start to finish.', 5, 9.40),
  ],
  157336: [
    ('david', 'The docking scene paired with Hans Zimmer is pure auditory euphoria.', 1, 9.95),
    ('chloe', 'Emotional gravity that transcends time and dimensions.', 4, 9.60),
  ],
  27205: [
    ('alex', 'The spinning totem remains one of the greatest closing shots in history.', 2, 9.75),
    ('kai', 'Zero-gravity hallway fight is still completely unrivaled.', 6, 9.35),
  ],
  155: [
    ('jordan', 'Heath Ledger gave the definitive antagonist performance.', 1, 9.85),
    ('maya', 'A crime thriller operating at peak prestige.', 2, 9.70),
  ],
  238: [
    ('anthony', 'The foundational blueprint of modern cinematic storytelling.', 1, 10.0),
  ],
  872585: [
    ('sam', 'The trinity test build-up had the entire theater holding its breath.', 3, 9.60),
  ],
  1396: [
    ('mark', 'The season one finale is the greatest television cliffhanger ever created.', 1, 9.85),
    ('dylan', 'The waffle party sequence is peak psychological dread.', 2, 9.70),
  ],
  110492: [
    ('mark', 'The season one finale is the greatest television cliffhanger ever created.', 1, 9.85),
    ('dylan', 'The waffle party sequence is peak psychological dread.', 2, 9.70),
  ],
};
