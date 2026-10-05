import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/core/widgets/telly_neon_badge.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:telly_app/features/discovery/data/discovery_repository.dart';
import 'package:telly_app/features/discovery/domain/discovery_models.dart';
import 'package:telly_app/features/logging/data/title_repository.dart';
import 'package:telly_app/features/logging/domain/title_search_result.dart';

/// SCR-07: Explore & Discover Hub (FE-612).
/// Conforms to `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §SCR-07
/// and `docs/features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md` §5.
class ExploreDiscoverScreen extends ConsumerStatefulWidget {
  const ExploreDiscoverScreen({super.key});

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

  List<TitleSearchResult> _titleResults = [];
  List<UserSearchResult> _userResults = [];

  @override
  void dispose() {
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
      backgroundColor: TellyColors.backgroundCanvasOled,
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
                        color: TellyColors.backgroundSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: TellyColors.borderGlass),
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
                                      : TellyColors.textTertiary,
                                ).copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  net.network,
                                  style: TellyTypography.titleMedium(
                                    color: TellyColors.textPrimary,
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

  void _showCuratedCanonDetail(CuratedCanonItem canon) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TellyColors.backgroundCanvasOled,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(canon.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      canon.title,
                      style: TellyTypography.titleLarge(
                        color: TellyColors.textPrimary,
                      ).copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                canon.subtitle,
                style: TellyTypography.bodyMedium(color: TellyColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Text(
                'FEATURED TITLES',
                style: TellyTypography.labelSmall(
                  color: TellyColors.textTertiary,
                ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
              ),
              const SizedBox(height: 12),
              ...canon.sampleTitles.map((title) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: TellyColors.backgroundSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: TellyColors.borderGlass),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: TellyColors.warmAmber),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: TellyTypography.labelLarge(
                            color: TellyColors.textPrimary,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final battlegroundsAsync = ref.watch(networkBattlegroundsProvider('tv'));
    final friendsBingingAsync = ref.watch(friendsBingingProvider);
    final curatedCanons = ref.watch(discoveryRepositoryProvider).getCuratedCanons();

    return Scaffold(
      backgroundColor: TellyColors.backgroundCanvasOled,
      appBar: AppBar(
        backgroundColor: TellyColors.backgroundCanvasOled,
        elevation: 0,
        title: Text(
          '🧭 EXPLORE',
          style: TellyTypography.titleMedium(color: TellyColors.textPrimary)
              .copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            key: const Key('explore_appbar_search_btn'),
            icon: const Icon(Icons.search, color: TellyColors.textSecondary),
            tooltip: 'Search',
            onPressed: () {
              _searchFocusNode.requestFocus();
            },
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              key: const Key('explore_appbar_clear_btn'),
              icon: const Icon(Icons.close, color: TellyColors.textSecondary),
              tooltip: 'Clear search',
              onPressed: _clearSearch,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Search Bar
            _buildSearchBar(),
            const SizedBox(height: 20),

            // If user is searching, render Search Results
            if (_searchQuery.isNotEmpty)
              _buildSearchResults()
            else ...[
              // 2. Network Battlegrounds Strip
              battlegroundsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(color: TellyColors.phosphorLime),
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (battlegrounds) => _buildNetworkBattlegroundsStrip(battlegrounds),
              ),
              const SizedBox(height: 28),

              // 3. Friends Are Currently Binging Carousel
              friendsBingingAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(color: TellyColors.phosphorLime),
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (binging) => _buildFriendsBingingSection(binging),
              ),
              const SizedBox(height: 28),

              // 4. Curated Canons
              _buildCuratedCanonsSection(curatedCanons),
              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: TellyColors.backgroundSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TellyColors.borderGlass),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: TellyColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search shows, actors, showrunners, friends...',
          hintStyle: TextStyle(
            color: TellyColors.textTertiary.withValues(alpha: 0.8),
            fontSize: 13,
          ),
          prefixIcon: const Icon(Icons.search, color: TellyColors.textTertiary, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  key: const Key('explore_search_field_clear_btn'),
                  icon: const Icon(Icons.close, color: TellyColors.textTertiary, size: 18),
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
      backgroundColor: TellyColors.backgroundSurface,
      selectedColor: TellyColors.phosphorLime.withValues(alpha: 0.2),
      side: BorderSide(
        color: isSelected ? TellyColors.phosphorLime : TellyColors.borderGlass,
      ),
      labelStyle: TextStyle(
        color: isSelected ? TellyColors.phosphorLime : TellyColors.textSecondary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }

  Widget _buildTitleResultTile(TitleSearchResult title) {
    return InkWell(
      onTap: () => context.push(Routes.title(title.mediaType, title.id)),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: TellyColors.backgroundSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TellyColors.borderGlass),
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
                  fallback: const Center(
                    child: Icon(Icons.movie_outlined, size: 20, color: TellyColors.textTertiary),
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
                    style: TellyTypography.titleMedium(color: TellyColors.textPrimary)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${title.mediaType.toUpperCase()}${title.releaseYear.isNotEmpty ? ' • ${title.releaseYear}' : ''}',
                    style: TellyTypography.caption(color: TellyColors.textTertiary),
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

  Widget _buildUserResultTile(UserSearchResult user) {
    final currentUserId = ref.watch(authRepositoryProvider).currentUserId;
    final currentUsername = ref.watch(authControllerProvider).user?.username;
    final isMe = (currentUsername != null &&
            currentUsername.toLowerCase() == user.username.toLowerCase()) ||
        (currentUserId != null && currentUserId == user.id);

    return InkWell(
      key: Key('user_result_tile_${user.username}'),
      onTap: () {
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
                    style: TellyTypography.titleMedium(color: TellyColors.textPrimary)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '@${user.username}',
                    style: TellyTypography.caption(color: TellyColors.textTertiary),
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

  Widget _buildNetworkBattlegroundsStrip(List<NetworkBattleground> battlegrounds) {
    if (battlegrounds.isEmpty) return const SizedBox.shrink();

    final topThree = battlegrounds.take(3).toList();
    final emojis = ['👑', '🍏', '🔴'];

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
                style: TellyTypography.labelSmall(color: TellyColors.textPrimary)
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
                      style: TellyTypography.labelMedium(color: TellyColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '★ ${b.avgScore.toStringAsFixed(2)}',
                      style: TellyTypography.caption(color: TellyColors.warmAmber)
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
                    style: TellyTypography.labelMedium(color: TellyColors.phosphorLime)
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, size: 14, color: TellyColors.phosphorLime),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsBingingSection(List<FriendBingingItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

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
              'FRIENDS ARE CURRENTLY BINGING',
              style: TellyTypography.labelSmall(color: TellyColors.textPrimary)
                  .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final item = items[index];
              return InkWell(
                onTap: () => context.push(Routes.title(item.mediaType, item.titleId)),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TellyColors.backgroundSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: TellyColors.borderGlass),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 50,
                              height: 75,
                              child: PosterImage(
                                posterPath: item.posterPath,
                                fallback: const Center(
                                  child: Icon(Icons.movie_outlined, size: 24, color: TellyColors.textTertiary),
                                ),
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
                                  style: TellyTypography.titleMedium(color: TellyColors.textPrimary)
                                      .copyWith(fontWeight: FontWeight.w800),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (item.network != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    item.network!,
                                    style: TellyTypography.caption(color: TellyColors.textTertiary),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.people, size: 14, color: TellyColors.electricViolet),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${item.activeFriendCount} watching',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TellyTypography.caption(color: TellyColors.textSecondary)
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (item.avgFriendScore != null)
                            TellyNeonBadge(
                              label: '★ ${item.avgFriendScore!.toStringAsFixed(1)}',
                              variant: TellyBadgeVariant.winner,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCuratedCanonsSection(List<CuratedCanonItem> canons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: TellyColors.warmAmber,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'CURATED CANONS',
              style: TellyTypography.labelSmall(color: TellyColors.textPrimary)
                  .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...canons.map((canon) => InkWell(
              onTap: () => _showCuratedCanonDetail(canon),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: TellyColors.backgroundSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: TellyColors.borderGlass),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: TellyColors.backgroundCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(canon.emoji, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            canon.title,
                            style: TellyTypography.titleMedium(color: TellyColors.textPrimary)
                                .copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            canon.subtitle,
                            style: TellyTypography.caption(color: TellyColors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: TellyColors.textTertiary),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}
