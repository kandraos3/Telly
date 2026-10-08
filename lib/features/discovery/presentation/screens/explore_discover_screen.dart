import 'package:flutter/material.dart';
import 'package:telly_app/core/widgets/telly_log_fab.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/core/widgets/telly_screen_header.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:telly_app/features/discovery/data/discovery_repository.dart';
import 'package:telly_app/features/discovery/domain/discovery_models.dart';
import 'package:telly_app/features/discovery/presentation/controllers/explore_picks.dart';
import 'package:telly_app/features/discovery/presentation/controllers/explore_rows_controller.dart';
import 'package:telly_app/features/discovery/presentation/widgets/explore_rows_view.dart';
import 'package:telly_app/core/widgets/telly_canon_switcher.dart';
import 'package:telly_app/features/logging/data/title_repository.dart';
import 'package:telly_app/features/logging/domain/title_search_result.dart';

/// SCR-07: Explore & Discover Hub (FE-612; rows #180).
/// Conforms to `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §SCR-07
/// and `docs/features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md` §5 and §7.
class ExploreDiscoverScreen extends ConsumerStatefulWidget {
  /// Set by [Routes.exploreSearch] (the Feed header's search button): each new value
  /// focuses the search field (FE-HEADER-01).
  final String? searchRequest;

  const ExploreDiscoverScreen({super.key, this.searchRequest});

  @override
  ConsumerState<ExploreDiscoverScreen> createState() => _ExploreDiscoverScreenState();
}

enum SearchFilterTab { all, titles, people }

class _ExploreDiscoverScreenState extends ConsumerState<ExploreDiscoverScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  SearchFilterTab _activeTab = SearchFilterTab.all;
  bool _isSearching = false;
  bool _searchFocused = false;

  /// The canon the rows show (`'movie'` or `'tv'`): the slim switcher under the search bar.
  String _mediaType = 'movie';

  List<TitleSearchResult> _titleResults = [];
  List<UserSearchResult> _userResults = [];

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onSearchFocusChanged);
    if (widget.searchRequest != null) _focusSearchAfterFrame();
  }

  @override
  void didUpdateWidget(ExploreDiscoverScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchRequest != null && widget.searchRequest != oldWidget.searchRequest) _focusSearchAfterFrame();
  }

  void _focusSearchAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _onSearchFocusChanged() {
    if (_searchFocused != _searchFocusNode.hasFocus) {
      setState(() => _searchFocused = _searchFocusNode.hasFocus);
    }
  }

  /// Runs [query] as if typed, e.g. from a recent-search chip.
  void _runSearch(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.collapsed(offset: query.length);
    _onSearchChanged(query);
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
    _searchFocusNode.unfocus();
  }

  Future<void> _onSearchChanged(String query) async {
    final trimmed = query.trim();
    setState(() {
      _searchQuery = trimmed;
    });

    if (trimmed.isEmpty) {
      setState(() {
        _isSearching = false;
        _titleResults = [];
        _userResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final titleSearch = ref.read(titleRepositoryProvider).search(trimmed);
      final userSearch = ref.read(discoveryRepositoryProvider).searchUsers(trimmed);

      final results = await Future.wait([titleSearch, userSearch]);
      if (mounted && _searchQuery == trimmed) {
        setState(() {
          _titleResults = (results[0] as TitleSearchOutcome).results;
          _userResults = results[1] as List<UserSearchResult>;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _showFullNetworkRankings(List<NetworkBattleground> battlegrounds) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TellyColors.cardOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: TellyColors.borderGlass,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '👑 NETWORK BATTLEGROUNDS',
                    style: TellyTypography.titleLarge(
                      color: TellyColors.phosphorLime,
                    ).copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Which network produces the highest average quality?\nRanked by community pairwise battles.',
                    style: TellyTypography.bodyMedium(color: TellyColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  ...battlegrounds.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final net = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                              Text(
                                '#$index',
                                style: TellyTypography.titleMedium(
                                  color: index == 1
                                      ? TellyColors.warmAmber
                                      : TellyColors.textTertiaryOf(context),
                                ).copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  net.network,
                                  style: TellyTypography.titleMedium(
                                    color: TellyColors.textPrimaryOf(context),
                                  ).copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: TellyColors.phosphorLime
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '★ ${net.avgScore.toStringAsFixed(2)}',
                                  style: TellyTypography.caption(
                                    color: TellyColors.phosphorLime,
                                  ).copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${net.titleCount} Titles in Canon',
                            style: TellyTypography.caption(
                              color: TellyColors.textTertiary,
                            ),
                          ),
                          if (net.topTitles.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Top 3: ${net.topTitles.map((t) => t.title).join(', ')}',
                              style: TellyTypography.caption(
                                color: TellyColors.warmAmber,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final browsing = _searchQuery.isEmpty && !_searchFocused;
    final battlegroundsAsync = ref.watch(networkBattlegroundsProvider('tv'));
    int? count(String mediaType) => ref.watch(exploreRowsProvider(mediaType)).valueOrNull?.rows.rankingCount;

    return Scaffold(
      body: TellyFloatingHeaderScrollView(
        header: const TellyScreenHeader(title: 'Explore'),
        body: RefreshIndicator(
          onRefresh: () => ref.read(exploreRowsProvider(_mediaType).notifier).refresh(),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                sliver: SliverToBoxAdapter(child: _buildSearchBar()),
              ),
              if (!browsing)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8 + TellyLogFab.clearance),
                  sliver: SliverToBoxAdapter(
                    child: _searchQuery.isNotEmpty ? _buildSearchResults() : _buildSearchZeroState(),
                  ),
                )
              else ...[
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SwitcherHeader(
                    background: TellyColors.canvasOf(context),
                    child: TellyCanonSwitcher(
                      selected: _mediaType,
                      onSelect: (m) => setState(() => _mediaType = m),
                      movieCount: count('movie'),
                      seriesCount: count('tv'),
                      movieKey: const Key('explore_canon_movie'),
                      seriesKey: const Key('explore_canon_tv'),
                    ),
                  ),
                ),
                SliverPadding(
                  // End space lets the last row scroll above the floating Log button (#44).
                  padding: const EdgeInsets.only(top: 12, bottom: 8 + TellyLogFab.clearance),
                  sliver: SliverToBoxAdapter(
                    child: ExploreRowsView(
                      mediaType: _mediaType,
                      // Network battlegrounds stay as the last Series row (decision 0007).
                      footer: _mediaType == 'tv'
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: battlegroundsAsync.maybeWhen(
                                data: _buildNetworkBattlegroundsStrip,
                                orElse: () => const SizedBox.shrink(),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TellyColors.borderGlassOf(context)),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        onSubmitted: (q) => ref.read(recentSearchesProvider.notifier).add(q),
        textInputAction: TextInputAction.search,
        style: TextStyle(color: TellyColors.textPrimaryOf(context), fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search titles, people, friends',
          hintStyle: TextStyle(
            color: TellyColors.textTertiaryOf(context).withValues(alpha: 0.8),
            fontSize: 13,
          ),
          prefixIcon: Icon(Icons.search, color: TellyColors.textTertiaryOf(context), size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  key: const Key('explore_search_field_clear_btn'),
                  icon: Icon(Icons.close, color: TellyColors.textTertiaryOf(context), size: 18),
                  onPressed: _clearSearch,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter tabs: All, Titles, People
        Row(
          children: [
            _buildFilterChip('All', SearchFilterTab.all),
            const SizedBox(width: 8),
            _buildFilterChip('🎬 Titles', SearchFilterTab.titles),
            const SizedBox(width: 8),
            _buildFilterChip('👥 People', SearchFilterTab.people),
          ],
        ),
        const SizedBox(height: 16),

        if (_isSearching)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: TellyColors.phosphorLime),
            ),
          )
        else ...[
          // Titles Results
          if (_activeTab != SearchFilterTab.people) ...[
            Text(
              'TITLES (${_titleResults.length})',
              style: TellyTypography.labelSmall(color: TellyColors.textTertiary)
                  .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
            ),
            const SizedBox(height: 10),
            if (_titleResults.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text('No titles found',
                    style: TellyTypography.bodyMedium(color: TellyColors.textTertiary)),
              )
            else
              ..._titleResults.map((title) => _buildTitleResultTile(title)),
            const SizedBox(height: 16),
          ],

          // People Results
          if (_activeTab != SearchFilterTab.titles) ...[
            Text(
              'PEOPLE (${_userResults.length})',
              style: TellyTypography.labelSmall(color: TellyColors.textTertiary)
                  .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
            ),
            const SizedBox(height: 10),
            if (_userResults.isEmpty)
              Text('No users found',
                  style: TellyTypography.bodyMedium(color: TellyColors.textTertiary))
            else
              ..._userResults.map((user) => _buildUserResultTile(user)),
          ],
        ],
      ],
    );
  }

  Widget _buildFilterChip(String label, SearchFilterTab tab) {
    final isSelected = _activeTab == tab;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _activeTab = tab),
      backgroundColor: TellyColors.surfaceOf(context),
      selectedColor: TellyColors.phosphorLime.withValues(alpha: 0.2),
      side: BorderSide(
        color: isSelected ? TellyColors.phosphorLime : TellyColors.borderGlassOf(context),
      ),
      labelStyle: TextStyle(
        color: isSelected ? TellyColors.phosphorLime : TellyColors.textSecondaryOf(context),
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }

  Widget _buildTitleResultTile(TitleSearchResult title) {
    return InkWell(
      onTap: () {
        ref.read(recentSearchesProvider.notifier).add(_searchQuery);
        context.push(Routes.title(title.mediaType, title.id));
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: TellyColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TellyColors.borderGlassOf(context)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 64,
                child: PosterImage(
                  posterPath: title.posterPath,
                  fallback: Center(
                    child: Icon(Icons.movie_outlined, size: 20, color: TellyColors.textTertiaryOf(context)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.title,
                    style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context))
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${title.mediaType.toUpperCase()}${title.releaseYear.isNotEmpty ? ' • ${title.releaseYear}' : ''}',
                    style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: TellyColors.textTertiaryOf(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildUserResultTile(UserSearchResult user) {
    final currentUserId = ref.watch(authRepositoryProvider).currentUserId;
    final currentUsername = ref.watch(authControllerProvider).user?.username;
    final isMe = (currentUsername != null &&
            currentUsername.toLowerCase() == user.username.toLowerCase()) ||
        (currentUserId != null && currentUserId == user.id);

    return InkWell(
      key: Key('user_result_tile_${user.username}'),
      onTap: () {
        ref.read(recentSearchesProvider.notifier).add(_searchQuery);
        if (isMe) {
          context.go(Routes.canon);
        } else {
          context.push(Routes.profile(user.username));
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
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
                user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: TellyColors.phosphorLime,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context))
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '@${user.username}',
                    style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: TellyColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String label, Color accent, {Widget? trailing}) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TellyTypography.labelSmall(color: TellyColors.textPrimaryOf(context))
                .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  /// Shown while the search field is focused but empty: recent searches + trending.
  Widget _buildSearchZeroState() {
    final recent = ref.watch(recentSearchesProvider);
    final trending = ref.watch(exploreTrendingProvider).valueOrNull ?? const [];

    return Column(
      key: const Key('explore_search_zero_state'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recent.isNotEmpty) ...[
          _sectionHeader(
            'RECENT SEARCHES',
            TellyColors.electricViolet,
            trailing: TextButton(
              key: const Key('explore_clear_recent_btn'),
              onPressed: () => ref.read(recentSearchesProvider.notifier).clear(),
              child: Text(
                'Clear',
                style: TellyTypography.labelMedium(color: TellyColors.textTertiary),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in recent)
                InputChip(
                  key: Key('recent_search_$q'),
                  label: Text(q),
                  onPressed: () => _runSearch(q),
                  onDeleted: () => ref.read(recentSearchesProvider.notifier).remove(q),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  backgroundColor: TellyColors.surfaceOf(context),
                  side: BorderSide(color: TellyColors.borderGlassOf(context)),
                  labelStyle: TellyTypography.labelMedium(color: TellyColors.textSecondaryOf(context)),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        _sectionHeader('TRENDING NOW', TellyColors.neonCoral),
        const SizedBox(height: 12),
        if (trending.isEmpty)
          Text(
            'Start typing to search titles and people.',
            style: TellyTypography.bodyMedium(color: TellyColors.textTertiaryOf(context)),
          )
        else
          for (final (i, t) in trending.indexed)
            InkWell(
              key: Key('trending_title_${t.titleId}'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push(Routes.title(t.mediaType, t.titleId)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${i + 1}',
                        style: TellyTypography.titleMedium(color: TellyColors.textTertiaryOf(context))
                            .copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 36,
                        height: 54,
                        child: PosterImage(
                          posterPath: t.posterPath,
                          fallback: Center(
                            child: Icon(Icons.movie_outlined, size: 16, color: TellyColors.textTertiaryOf(context)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context))
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              t.mediaType == 'movie' ? 'Movie' : 'TV Show',
                              if (t.releaseYear != null) '${t.releaseYear}',
                              if (t.network != null && t.mediaType == 'tv') t.network!,
                            ].join(' • '),
                            style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.trending_up, size: 18, color: TellyColors.neonCoral),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildNetworkBattlegroundsStrip(List<NetworkBattleground> battlegrounds) {
    if (battlegrounds.isEmpty) return const SizedBox.shrink();

    final topThree = battlegrounds.take(3).toList();
    final emojis = ['👑', '🍏', '🔴'];

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
                'NETWORK BATTLEGROUNDS',
                style: TellyTypography.labelSmall(color: TellyColors.textPrimaryOf(context))
                    .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Strip showing top 3 networks
          Row(
            children: topThree.asMap().entries.map((entry) {
              final idx = entry.key;
              final b = entry.value;
              final emoji = idx < emojis.length ? emojis[idx] : '⭐';
              return Expanded(
                child: Column(
                  children: [
                    Text(
                      '$emoji ${b.network}',
                      style: TellyTypography.labelMedium(color: TellyColors.textPrimaryOf(context))
                          .copyWith(fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '★ ${b.avgScore.toStringAsFixed(2)}',
                      style: TellyTypography.caption(color: TellyColors.warmAmberOf(context))
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _showFullNetworkRankings(battlegrounds),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'See Full Network Rankings',
                    style: TellyTypography.labelMedium(color: TellyColors.primaryAccentOf(context))
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 14, color: TellyColors.primaryAccentOf(context)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}

/// Pins the canon switcher under the status bar while the rows scroll (SCR-07).
class _SwitcherHeader extends SliverPersistentHeaderDelegate {
  _SwitcherHeader({required this.background, required this.child});

  final Color background;
  final Widget child;

  static const _height = 60.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(color: background, child: Align(alignment: Alignment.center, child: child));

  @override
  bool shouldRebuild(_SwitcherHeader old) => old.child != child || old.background != background;
}
