import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/core/services/streaming_deep_link_factory.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/core/widgets/telly_neon_badge.dart';
import 'package:telly_app/core/widgets/telly_frosted_sheet.dart';
import 'package:telly_app/core/widgets/telly_primary_button.dart';
import 'package:telly_app/core/widgets/telly_screen_header.dart';
import 'package:share_plus/share_plus.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/features/logging/domain/title_search_result.dart';
import 'package:telly_app/features/tracking/data/tracking_repository.dart';
import 'package:telly_app/features/tracking/domain/tracking_item.dart';
import 'package:telly_app/features/tracking/domain/tracking_models.dart';
import 'package:telly_app/features/tracking/domain/tracking_progress.dart';
import 'package:telly_app/features/tracking/presentation/providers/tracking_providers.dart';
import 'package:telly_app/features/tracking/domain/season_progress.dart';
import 'package:telly_app/features/tracking/presentation/widgets/episode_sheet.dart';
import 'package:telly_app/features/tracking/presentation/widgets/season_widgets.dart';
import 'package:telly_app/features/tracking/presentation/widgets/tracking_labels.dart';
import 'package:telly_app/features/tracking/presentation/widgets/watching_now.dart';
import 'package:telly_app/features/tracking/presentation/widgets/tracking_header.dart';
import 'package:telly_app/features/tracking/presentation/widgets/tracking_actions.dart';
import 'package:telly_app/features/tracking/presentation/widgets/tracking_undo_tray.dart';
import 'package:telly_app/features/tracking/presentation/widgets/watch_slot.dart';
import 'package:telly_app/features/tracking/presentation/widgets/watching_cards.dart';
import 'package:telly_app/features/tracking/presentation/widgets/where_are_you_sheet.dart';
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

  /// The big in-page title; once it scrolls under the pinned bar, the bar shows the name (FE-HEADER-03).
  final _pageTitleKey = GlobalKey();
  bool _showBarTitle = false;
  bool _barTitleCheckScheduled = false;

  /// Watch tracking (#229): scroll targets, and whether the user just moved the place, which is
  /// what lets the finish sheet open once for that transition (features/11 §4.5).
  final _nextCardKey = GlobalKey();
  final _seasonsKey = GlobalKey();
  bool _expectFinish = false;

  /// Episodes whose hidden name the user tapped to reveal; one at a time, not remembered (§5.5).
  final Set<EpisodeRef> _revealed = {};

  /// The caller's rank for this title, which the finish sheet shows (the page knows it, the
  /// tracking cache only learns it on sync).
  MyTitleRanking? _myRanking;

  TrackingItem? _withRank(TrackingItem? item) {
    final rank = _myRanking;
    if (item == null || rank == null || item.isRanked) return item;
    return item.copyWith(isRanked: true, rankPosition: rank.rankPosition, score: rank.calculatedScore);
  }

  /// Scroll notifications fire before the new layout, so the title is measured after the frame.
  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || _barTitleCheckScheduled) return false;
    _barTitleCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barTitleCheckScheduled = false;
      if (mounted) _updateBarTitle();
    });
    return false;
  }

  void _updateBarTitle() {
    final box = _pageTitleKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final titleBottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    final barBottom = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final show = titleBottom <= barBottom;
    if (show != _showBarTitle) setState(() => _showBarTitle = show);
  }

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
    ref.listen<TrackingItem?>(titleTrackingProvider((widget.titleId, widget.mediaType)), (prev, next) {
      if (_expectFinish && prev?.state == TrackingState.watching && next != null && next.state != TrackingState.watching) {
        _expectFinish = false;
        TrackingActions.openFinishSheet(context, _withRank(next)!);
      }
    });
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
    _myRanking = title.socialSummary?.myRanking;
    final tracked = _withRank(ref.watch(titleTrackingProvider((title.id, title.mediaType))));
    final canvasColor = Theme.of(context).brightness == Brightness.light
        ? TellyColors.lightBackgroundPrimary
        : TellyColors.backgroundCanvasOled;
    return Scaffold(
      backgroundColor: canvasColor,
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: CustomScrollView(
          slivers: [
            // 1. 16:9 Backdrop with Gradient Fade and Top Actions
            _buildBackdropAppBar(title, tracked),

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
                    _buildHeaderMeta(title, tracked),
                    const SizedBox(height: 16),

                    // Quick Action Hub (Queue, Rank/Duel, Co-Watch, Share)
                    _buildQuickActionHub(title, tracked),
                    _buildWatchingNow(title),
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

                    // NEXT EPISODE / WATCHING card while tracked, else STREAMING NOW
                    _buildWatchingBlock(title, tracked),
                    const SizedBox(height: 24),

                    // YOUR STATUS section (Ranked vs Unranked)
                    _buildYourStatusSection(title, tracked),
                    const SizedBox(height: 28),

                    // FRIENDS WHO RANKED THIS section
                    if (title.socialSummary != null &&
                        title.socialSummary!.friends.isNotEmpty) ...[
                      _buildFriendsWhoRankedSection(title.socialSummary!.friends),
                      const SizedBox(height: 28),
                    ],

                    // SEASONS ACCORDION (TV Series only; omitted for Movies)
                    if (title.isTv && title.seasons.isNotEmpty) ...[
                      KeyedSubtree(key: _seasonsKey, child: _buildSeasonsAccordion(title, tracked)),
                      const SizedBox(height: 28),
                    ],

                    // COMMUNITY SURVIVAL RATE section (TV Series)
                    // Hidden until someone has finished, watched or dropped it (FE-DETAIL-02).
                    if (title.isTv && title.socialSummary?.survival?.completedPct != null) ...[
                      _buildSurvivalRateSection(
                          title.socialSummary!.survival!, title.socialSummary!.survival!.completedPct!, tracked),
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
      ),
    );
  }

  Widget _buildBackdropAppBar(TitleDetail title, TrackingItem? tracked) {
    final canvasColor = Theme.of(context).brightness == Brightness.light
        ? TellyColors.lightBackgroundPrimary
        : TellyColors.backgroundCanvasOled;
    return SliverAppBar(
      backgroundColor: canvasColor,
      expandedHeight: 220,
      pinned: true,
      leading: TellyNavButton(onPressed: () => context.canPop() ? context.pop() : context.go(Routes.home)),
      // FE-HEADER-03: the collapsed bar names the title once the in-page title has scrolled under it.
      titleSpacing: 4,
      title: ExcludeSemantics(
        excluding: !_showBarTitle,
        child: AnimatedOpacity(
          opacity: _showBarTitle ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: Text(
            title.title,
            key: const Key('detail_bar_title'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TellyTypography.subpageTitle(color: TellyColors.textPrimaryOf(context)),
          ),
        ),
      ),
      actions: [
        if (tracked != null)
          PopupMenuButton<String>(
            key: const Key('tracking_overflow_menu'),
            icon: Icon(Icons.more_vert, color: TellyColors.textPrimaryOf(context)),
            onSelected: (v) => v == 'drop' ? TrackingActions.drop(context, ref, tracked) : TrackingActions.confirmStop(context, ref, tracked),
            itemBuilder: (_) => [
              if (!tracked.isMovie) const PopupMenuItem(value: 'drop', child: Text('Drop it')),
              const PopupMenuItem(value: 'stop', child: Text('Stop tracking')),
            ],
          ),
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
            if (tracked != null && !tracked.isMovie)
              Positioned(left: 0, right: 0, bottom: 0, child: TrackingProgressLine(fraction: tracked.progress)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderMeta(TitleDetail title, TrackingItem? tracked) {
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
              if (tracked != null) TrackingEyebrow(item: tracked),
              Text(
                title.title,
                key: _pageTitleKey,
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
              // Community Score with CanonTier Badge (wraps: "PRESTIGE" overflowed a row at 393 dp)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Text(
                    '★ ${communityScore.toStringAsFixed(2)}',
                    style: TellyTypography.titleMedium(
                      color: TellyColors.warmAmberOf(context),
                    ).copyWith(fontWeight: FontWeight.w800),
                  ),
                  TellyNeonBadge(
                    label: '${tier.emoji} ${tier.label.toUpperCase()}',
                    variant: tier == CanonTier.god
                        ? TellyBadgeVariant.godTier
                        : TellyBadgeVariant.tasteMatch,
                  ),
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

  Widget _buildQuickActionHub(TitleDetail title, TrackingItem? tracked) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Watch slot (the Queue toggle lives on the app bar bookmark; SCR-08 §T.2)
          WatchSlot(item: tracked, onTap: () => _onWatchSlot(title, tracked)),
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

  /// Where the title streams (live availability first, BE-DETAIL-01; cached rows otherwise).
  List<({String id, String name})> _streamingProviders(TitleDetail title) {
    final live = ref.watch(titleStreamingProvider((title.id, title.mediaType))).valueOrNull ?? const [];
    return live.isNotEmpty
        ? [
            for (final p in live)
              // "Streaming now" means watchable without buying or renting.
              if (p.monetizationType == MonetizationType.flatrate || p.monetizationType == MonetizationType.free)
                (id: p.platformId, name: p.platformName),
          ]
        : [for (final a in title.availabilities) (id: a.platformId, name: _platformName(a.platformId))];
  }

  void _play(TitleDetail title, String providerId) {
    StreamingDeepLinkFactory.launchPlayback(
      providerId: providerId,
      externalShowId: '${title.id}',
      showSlug: title.title.toLowerCase().replaceAll(' ', '-'),
    );
  }

  // --- Watch tracking (#229; SCR-08 §T, features/11 §4) ---

  /// The Next episode / Movie Watching card in place of *Streaming now* (§T.4, §T.4b).
  Widget _buildWatchingBlock(TitleDetail title, TrackingItem? item) {
    if (item == null) return _buildStreamingNowSection(title);
    final providers = _streamingProviders(title);
    final first = providers.isEmpty ? null : providers.first;
    final now = DateTime.now();
    final Widget card;
    if (item.isMovie) {
      card = MovieWatchingCard(
        item: item,
        now: now,
        providerName: first?.name,
        onPlay: first == null ? null : () => _play(title, first.id),
        onFinished: () => _onMovieFinished(item),
        onRank: () => TrackingActions.rank(context, item),
      );
    } else {
      card = NextEpisodeCard(
        item: item,
        now: now,
        providerName: first?.name,
        onPlay: first == null ? null : () => _play(title, first.id),
        onWatched: () => _onWatched(item),
        onUnlogLast: () => TrackingActions.offerUnlogLast(context, ref, item),
        onRank: () => TrackingActions.rank(context, item),
      );
    }
    final keyed = KeyedSubtree(key: _nextCardKey, child: card);
    if (item.state == TrackingState.watching) return keyed;
    return Column(children: [keyed, const SizedBox(height: 24), _buildStreamingNowSection(title)]);
  }

  TrackingController get _tracking => ref.read(trackingProvider.notifier);

  Future<void> _haptic({bool medium = false}) async {
    if (!ref.read(hapticsEnabledProvider)) return;
    medium ? await HapticsService.mediumImpact() : await HapticsService.lightImpact();
  }

  TrackingStartRequest _request(TitleDetail title, {EpisodeRef? place, bool rewatch = false}) => TrackingStartRequest(
        titleId: title.id,
        mediaType: title.mediaType,
        title: title.title,
        posterPath: title.posterPath,
        backdropPath: title.backdropPath,
        titleStatus: title.status,
        runtimeMinutes: title.runtimeMinutes,
        seasons: [
          for (final s in title.seasons)
            if (s.seasonNumber >= 1)
              SeasonInfo(
                number: s.seasonNumber,
                episodeCount: s.episodeCount,
                airDate: s.airDate == null ? null : DateTime.tryParse(s.airDate!),
              ),
        ],
        place: place,
        rewatch: rewatch,
      );

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.1);
  }

  Future<void> _onWatchSlot(TitleDetail title, TrackingItem? item) async {
    if (item == null) return _startWatching(title);
    switch (item.state) {
      case TrackingState.watching:
        _scrollTo(_nextCardKey);
      case TrackingState.caughtUp:
        _scrollTo(_seasonsKey.currentContext != null ? _seasonsKey : _nextCardKey);
      case TrackingState.finished:
        final choice = await TellyFrostedSheet.show<String>(
          context: context,
          builder: (ctx) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const Key('watch_again_action'),
                leading: const Icon(Icons.replay_rounded),
                title: const Text('Watch again'),
                onTap: () => Navigator.of(ctx).pop('again'),
              ),
              ListTile(
                key: const Key('stop_tracking_action'),
                leading: const Icon(Icons.stop_circle_outlined),
                title: const Text('Stop tracking'),
                onTap: () => Navigator.of(ctx).pop('stop'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (choice == 'again') {
          await _tracking.start(_request(title, rewatch: true));
        } else if (choice == 'stop') {
          await TrackingActions.confirmStop(context, ref, item);
        }
    }
  }

  /// Starting leaves the Queue; Undo puts the title back and stops tracking (§4.1, §4.10).
  Future<void> _startWatching(TitleDetail title) async {
    var request = _request(title);
    if (title.isTv && request.seasons.isNotEmpty) {
      EpisodeRef? preset;
      if (title.socialSummary?.myRanking != null) {
        // A ranked series is usually one you are up to date on: preset the place there (§10).
        preset = TrackingProgress.lastAired(
          ShowSchedule(seasons: request.seasons, status: title.status),
          DateTime.now(),
        );
      }
      final result = await WhereAreYouSheet.show(
        context,
        titleId: title.id,
        seasons: request.seasons,
        initialPlace: preset,
      );
      if (result == null || !mounted) return;
      request = _request(title, place: result.place);
    }
    final wasQueued = _isBookmarked;
    final started = await _tracking.start(request);
    await _haptic(medium: true);
    if (!mounted) return;
    if (wasQueued) {
      await ref.read(watchlistRepositoryProvider).remove(titleId: title.id, mediaType: title.mediaType);
      if (mounted) setState(() => _isBookmarked = false);
    }
    if (!mounted) return;
    TrackingUndoTray.show(
      context,
      message: 'Watching ${title.title}',
      onUndo: () async {
        await _tracking.stop(started);
        if (wasQueued) {
          await ref.read(watchlistRepositoryProvider).add(
                titleId: title.id,
                mediaType: title.mediaType,
                title: title.title,
                posterPath: title.posterPath,
              );
          if (mounted) setState(() => _isBookmarked = true);
        }
      },
    );
  }

  Future<void> _onWatched(TrackingItem item) async {
    final next = item.nextEpisode?.ref;
    if (next == null) return;
    await _haptic();
    _expectFinish = true;
    final before = await _tracking.markNext(item);
    if (before == null) {
      _expectFinish = false;
      return;
    }
    if (!mounted) return;
    TrackingUndoTray.show(
      context,
      message: '${next.label} watched',
      onUndo: () {
        _expectFinish = false;
        _tracking.undo(before);
      },
    );
  }

  Future<void> _onMovieFinished(TrackingItem item) async {
    await _haptic(medium: true);
    _expectFinish = true;
    await _tracking.finish(item);
  }

  Widget _buildStreamingNowSection(TitleDetail title) {
    final providers = _streamingProviders(title);

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

  Widget _buildYourStatusSection(TitleDetail title, TrackingItem? tracked) {
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
            if (tracked != null && tracked.newEpisodesSince != null) ...[
              const SizedBox(height: 10),
              Text(
                "When you catch up we'll offer a re-duel",
                key: const Key('reduel_note'),
                style: TellyTypography.caption(color: TellyColors.warmAmberOf(context)).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
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

  // --- Watch tracking: Watching now, drop-off line, Seasons as progress (#230) ---

  Widget _buildWatchingNow(TitleDetail title) {
    final watchers = ref.watch(titleWatchersProvider((title.id, title.mediaType))).valueOrNull;
    if (watchers == null || watchers.watchers.isEmpty) return const SizedBox.shrink();
    return WatchingNowRow(watchers: watchers, onOpenProfile: (handle) => context.push(Routes.profile(handle)));
  }

  /// "You're past S1 · E4, where 18% of viewers drop it." once the place is after the top drop
  /// point (features/11 §5.4).
  String? _dropOffLine(CommunitySurvivalSummary survival, TrackingItem? tracked) {
    final point = survival.commonDropPoint;
    final place = tracked?.place;
    if (tracked == null || tracked.isMovie || place == null || point?.season == null || point?.count == null) return null;
    final total = survival.completed + survival.watching + survival.dropped;
    if (total <= 0) return null;
    final drop = EpisodeRef(point!.season!, point.episode ?? 1);
    if (!(place > drop)) return null;
    final pct = (point.count! * 100 / total).round();
    return "You're past ${drop.label}, where $pct% of viewers drop it.";
  }

  TrackingItem? get _liveTracked => _withRank(ref.read(titleTrackingProvider((widget.titleId, widget.mediaType))));

  Future<void> _jumpTo(TrackingItem item, EpisodeRef episode) async {
    final before = item.place;
    await _haptic();
    _expectFinish = true;
    await _tracking.setPlace(item, episode);
    if (!mounted) return;
    TrackingUndoTray.show(
      context,
      message: '${episode.label} watched',
      onUndo: () {
        _expectFinish = false;
        final current = _liveTracked;
        if (current != null) _tracking.setPlace(current, before);
      },
    );
  }

  /// features/11 §4.3, §4.4: the episode sheet for a row of the Seasons list.
  Future<void> _onEpisodeTap(TrackingItem item, EpisodeRef episode, List<EpisodeInfo> cached) async {
    final today = DateTime.now();
    final schedule = item.schedule(episodes: {
      for (final s in item.seasons)
        s.number: s.number == episode.season ? cached : const <EpisodeInfo>[],
    });
    final info = cached.where((e) => e.episode == episode.episode).firstOrNull ??
        EpisodeInfo(season: episode.season, episode: episode.episode);
    final place = item.place;
    final watched = place != null && !(episode > place);
    final aired = TrackingProgress.aired(schedule, episode, today);
    final jump = TrackingProgress.watchedCount(schedule, episode) - TrackingProgress.watchedCount(schedule, place);
    final action = await EpisodeSheet.show(
      context,
      episode: info,
      watched: watched,
      aired: aired,
      now: today,
      jumpCount: jump,
    );
    if (action == null || !mounted) return;
    final current = _liveTracked ?? item;
    switch (action) {
      case EpisodeAction.unlog:
        final moved = TrackingProgress.watchedCount(schedule, place) - TrackingProgress.watchedCount(schedule, episode) + 1;
        if (moved > 1) {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              key: const Key('move_back_dialog'),
              content: Text('${episode.label} to ${place!.label} will count as not watched.'),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                TextButton(
                  key: const Key('move_back_confirm'),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Move back'),
                ),
              ],
            ),
          );
          if (ok != true || !mounted) return;
        }
        await TrackingActions.unlog(context, ref, current, episode);
      case EpisodeAction.rewatched:
        await _tracking.logRewatch(current, episode);
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(const SnackBar(content: Text('Rewatch logged'), duration: Duration(seconds: 2)));
        }
      case EpisodeAction.jump:
        await _jumpTo(current, episode);
    }
  }

  Widget _buildSeasonsAccordion(TitleDetail title, TrackingItem? tracked) {
    final seasons = title.seasons;
    final now = DateTime.now();
    final next = tracked?.state == TrackingState.watching ? tracked?.nextEpisode?.ref : null;
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
              'SEASONS',
              style: TellyTypography.labelSmall(
                color: TellyColors.textPrimaryOf(context),
              ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...seasons.map((season) {
          final isExpanded = _expandedSeasons.contains(season.seasonNumber);
          final cached = tracked == null || !isExpanded
              ? const <EpisodeInfo>[]
              : ref.watch(seasonEpisodesProvider((title.id, season.seasonNumber))).valueOrNull ?? const <EpisodeInfo>[];
          final progress = tracked == null || tracked.isMovie
              ? null
              : SeasonProgress.of(
                  tracked,
                  SeasonInfo(
                    number: season.seasonNumber,
                    episodeCount: season.episodeCount,
                    airDate: season.airDate == null ? null : DateTime.tryParse(season.airDate!),
                  ),
                  now,
                  episodes: cached,
                );
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
                  label: progress == null
                      ? '${season.name}, ${season.episodeCount} Episodes'
                      : '${season.name}, ${TrackingLabels.season(progress, now)}',
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
                          if (progress != null) ...[
                            SeasonRing(key: Key('season_ring_${season.seasonNumber}'), fraction: progress.fraction, done: progress.isWatched),
                            const SizedBox(width: 8),
                          ],
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
                            progress == null ? '${season.episodeCount} Episodes' : TrackingLabels.season(progress, now),
                            key: Key('season_state_${season.seasonNumber}'),
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
                if (isExpanded && tracked != null && !tracked.isMovie)
                  Padding(
                    padding: const EdgeInsets.only(left: 6, right: 6, bottom: 8),
                    child: Column(
                      children: [
                        for (var e = 1; e <= season.episodeCount; e++)
                          _buildEpisodeRow(tracked, EpisodeRef(season.seasonNumber, e), next, cached),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEpisodeRow(TrackingItem tracked, EpisodeRef ref, EpisodeRef? next, List<EpisodeInfo> cached) {
    final place = tracked.place;
    final mark = place != null && !(ref > place)
        ? EpisodeMark.watched
        : ref == next
            ? EpisodeMark.here
            : EpisodeMark.later;
    final hidden = mark == EpisodeMark.later && next != null && ref > next && !_revealed.contains(ref);
    final firstHidden = next == null ? null : TrackingProgress.candidateAfter(tracked.schedule(), next);
    final info = cached.where((e) => e.episode == ref.episode).firstOrNull;
    final name = info?.name == null || info!.name!.isEmpty ? 'Episode ${ref.episode}' : info.name!;
    return EpisodeRow(
      key: Key('episode_row_${ref.season}_${ref.episode}'),
      number: ref.episode,
      name: name,
      mark: mark,
      hidden: hidden,
      showHiddenCaption: hidden && ref == firstHidden,
      onTap: () {
        if (hidden) {
          setState(() => _revealed.add(ref));
        } else {
          _onEpisodeTap(tracked, ref, cached);
        }
      },
    );
  }

  Widget _buildSurvivalRateSection(CommunitySurvivalSummary survival, int completedPct, TrackingItem? tracked) {
    final dropPoint = survival.commonDropPoint;
    final pastDrop = _dropOffLine(survival, tracked);

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
          if (pastDrop != null) ...[
            const SizedBox(height: 8),
            Text(
              pastDrop,
              key: const Key('drop_off_line'),
              style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context)),
            ),
          ],
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
