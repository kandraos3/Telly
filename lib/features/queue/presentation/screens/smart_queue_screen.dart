import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telly_app/core/services/streaming_deep_link_factory.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/core/widgets/telly_neon_badge.dart';
import 'package:telly_app/features/queue/data/streaming_availability_service.dart';
import 'package:telly_app/features/queue/domain/streaming_models.dart';

/// Provider for user's universal watchlist items.
final userWatchlistProvider = StateNotifierProvider<WatchlistNotifier, List<WatchlistItem>>((ref) {
  return WatchlistNotifier();
});

class WatchlistNotifier extends StateNotifier<List<WatchlistItem>> {
  WatchlistNotifier()
      : super([
          WatchlistItem(
            showId: 101,
            title: 'Slow Horses',
            mediaType: 'tv',
            seasonCount: 4,
            episodeCount: 24,
            friendsAvgScore: 8.94,
            friendsCount: 6,
            savedFromHandle: '@maya',
            addedAt: DateTime.now().subtract(const Duration(days: 2)),
            availability: const [
              ShowStreamingAvailability(
                platformId: 'apple_tv_plus',
                platformName: 'Apple TV+',
                monetizationType: MonetizationType.flatrate,
                webUrl: 'https://tv.apple.com/us/show/slow-horses/101',
                deepLinkUrl: 'videos://tv.apple.com/us/show/slow-horses/101',
              ),
            ],
          ),
          WatchlistItem(
            showId: 102,
            title: 'Station Eleven',
            mediaType: 'tv',
            seasonCount: 1,
            episodeCount: 10,
            friendsAvgScore: 8.81,
            friendsCount: 4,
            savedFromHandle: '@alex',
            addedAt: DateTime.now().subtract(const Duration(days: 5)),
            availability: const [
              ShowStreamingAvailability(
                platformId: 'max',
                platformName: 'Max',
                monetizationType: MonetizationType.flatrate,
                webUrl: 'https://play.max.com/show/102',
                deepLinkUrl: 'max://play/102',
              ),
            ],
          ),
          WatchlistItem(
            showId: 103,
            title: 'Fargo',
            mediaType: 'tv',
            seasonCount: 5,
            episodeCount: 51,
            friendsAvgScore: 8.75,
            friendsCount: 5,
            savedFromHandle: '@jordan',
            isLeavingSoon: true,
            addedAt: DateTime.now().subtract(const Duration(days: 8)),
            availability: const [
              ShowStreamingAvailability(
                platformId: 'hulu',
                platformName: 'Hulu',
                monetizationType: MonetizationType.flatrate,
                webUrl: 'https://www.hulu.com/series/103',
                deepLinkUrl: 'hulu://series/103',
                isLeavingSoon: true,
              ),
            ],
          ),
          WatchlistItem(
            showId: 201,
            title: 'Parasite',
            mediaType: 'movie',
            runtimeMinutes: 132,
            friendsAvgScore: 9.72,
            friendsCount: 12,
            savedFromHandle: '@maya',
            addedAt: DateTime.now().subtract(const Duration(days: 1)),
            availability: const [
              ShowStreamingAvailability(
                platformId: 'max',
                platformName: 'Max',
                monetizationType: MonetizationType.flatrate,
                webUrl: 'https://play.max.com/show/201',
                deepLinkUrl: 'max://play/201',
              ),
            ],
          ),
          WatchlistItem(
            showId: 202,
            title: 'Past Lives',
            mediaType: 'movie',
            runtimeMinutes: 106,
            friendsAvgScore: 9.15,
            friendsCount: 8,
            savedFromHandle: '@chris',
            addedAt: DateTime.now().subtract(const Duration(days: 3)),
            availability: const [
              ShowStreamingAvailability(
                platformId: 'netflix',
                platformName: 'Netflix',
                monetizationType: MonetizationType.flatrate,
                webUrl: 'https://www.netflix.com/title/202',
                deepLinkUrl: 'nflx://www.netflix.com/title/202',
              ),
            ],
          ),
        ]);

  void removeItem(int showId) {
    state = state.where((item) => item.showId != showId).toList();
  }
}

/// SCR-13: Smart Queue Screen with Dual Watchlists & Streaming Filters.
/// Conforms to `FE-408` and `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §13.
class SmartQueueScreen extends ConsumerStatefulWidget {
  final List<WatchlistItem>? testItems;

  const SmartQueueScreen({
    super.key,
    this.testItems,
  });

  @override
  ConsumerState<SmartQueueScreen> createState() => _SmartQueueScreenState();
}

class _SmartQueueScreenState extends ConsumerState<SmartQueueScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _onlyOnMySubscriptions = false;
  String _sortBy = 'friends_score';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<WatchlistItem> allItems = widget.testItems ?? ref.watch(userWatchlistProvider);
    final userSubscriptions = ref.watch(userSubscriptionsProvider);

    // Apply subscriptions filter if toggle is ON
    final List<WatchlistItem> filteredItems = _onlyOnMySubscriptions
        ? allItems.where((item) => item.isAvailableOn(userSubscriptions)).toList()
        : allItems;

    final movieItems = filteredItems.where((item) => item.mediaType == 'movie').toList();
    final seriesItems = filteredItems.where((item) => item.mediaType == 'tv').toList();

    return Scaffold(
      backgroundColor: TellyColors.backgroundCanvasOled,
      appBar: AppBar(
        backgroundColor: TellyColors.backgroundCanvasOled,
        elevation: 0,
        title: Text(
          'UNIVERSAL QUEUE',
          style: TellyTypography.titleMedium(color: TellyColors.textPrimary).copyWith(letterSpacing: 1.2),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: TellyColors.backgroundSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TellyColors.borderGlass),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: TellyColors.phosphorLime,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: TellyColors.backgroundCanvasOled,
              unselectedLabelColor: TellyColors.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: '🎬 Movies (${movieItems.length})'),
                Tab(text: '📺 Series (${seriesItems.length})'),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Master Subscription Filter Toggle
                InkWell(
                  onTap: () {
                    setState(() {
                      _onlyOnMySubscriptions = !_onlyOnMySubscriptions;
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _onlyOnMySubscriptions
                          ? TellyColors.phosphorLime.withValues(alpha: 0.15)
                          : TellyColors.backgroundSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _onlyOnMySubscriptions ? TellyColors.phosphorLime : TellyColors.borderGlass,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _onlyOnMySubscriptions ? Icons.check_circle : Icons.radio_button_unchecked,
                          size: 14,
                          color: _onlyOnMySubscriptions ? TellyColors.phosphorLime : TellyColors.textTertiary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'On My Services',
                          style: TellyTypography.caption(
                            color: _onlyOnMySubscriptions ? TellyColors.phosphorLime : TellyColors.textSecondary,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),

                // Sort Dropdown
                DropdownButton<String>(
                  value: _sortBy,
                  dropdownColor: TellyColors.backgroundCard,
                  underline: const SizedBox.shrink(),
                  icon: const Icon(Icons.arrow_drop_down, color: TellyColors.textTertiary, size: 18),
                  style: TellyTypography.caption(color: TellyColors.textSecondary),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _sortBy = val;
                      });
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 'friends_score', child: Text('Friends\' Score')),
                    DropdownMenuItem(value: 'leaving_soon', child: Text('Leaving Soon')),
                  ],
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildQueueList(movieItems, userSubscriptions),
                _buildQueueList(seriesItems, userSubscriptions),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueList(List<WatchlistItem> items, Set<String> userSubscriptions) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bookmark_outline, size: 48, color: TellyColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              'Your queue is clear!',
              style: TellyTypography.titleMedium(color: TellyColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              _onlyOnMySubscriptions
                  ? 'No titles found on your active subscriptions.'
                  : 'Add shows from friend profiles and the feed.',
              style: TellyTypography.caption(color: TellyColors.textTertiary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildQueueCard(item, userSubscriptions);
      },
    );
  }

  Widget _buildQueueCard(WatchlistItem item, Set<String> userSubscriptions) {
    final primaryAvail = item.primarySubscribedAvailability(userSubscriptions);
    final providerName = primaryAvail != null ? primaryAvail.platformName : 'Online';
    final providerId = primaryAvail != null ? primaryAvail.platformId : 'netflix';

    return Dismissible(
      key: ValueKey('queue_item_${item.showId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: TellyColors.neonCoral,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) {
        ref.read(userWatchlistProvider.notifier).removeItem(item.showId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "${item.title}" from queue'),
            backgroundColor: TellyColors.backgroundCard,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: TellyColors.backgroundSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isLeavingSoon ? TellyColors.neonCoral.withValues(alpha: 0.4) : TellyColors.borderGlass,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Media Type Icon / Poster Box
                Container(
                  width: 52,
                  height: 72,
                  decoration: BoxDecoration(
                    color: TellyColors.backgroundCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: TellyColors.borderGlass),
                  ),
                  child: Center(
                    child: Icon(
                      item.mediaType == 'movie' ? Icons.movie_outlined : Icons.tv_outlined,
                      color: TellyColors.textTertiary,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Title & Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TellyTypography.titleMedium(
                                color: TellyColors.textPrimary,
                              ).copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (item.isLeavingSoon)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: TellyColors.neonCoral.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '⚠️ LEAVING SOON',
                                style: TellyTypography.caption(
                                  color: TellyColors.neonCoral,
                                ).copyWith(fontSize: 8, fontWeight: FontWeight.w800),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.mediaType == 'movie'
                            ? '${item.runtimeMinutes ?? 120} min'
                            : '${item.seasonCount ?? 1} Seasons • ${item.episodeCount ?? 10} Episodes',
                        style: TellyTypography.caption(color: TellyColors.textTertiary),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 13, color: TellyColors.warmAmber),
                          const SizedBox(width: 4),
                          Text(
                            '${item.friendsAvgScore.toStringAsFixed(2)} Friends Avg',
                            style: TellyTypography.caption(
                              color: TellyColors.warmAmber,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (item.savedFromHandle != null) ...[
                            Text(
                              ' • From ${item.savedFromHandle}',
                              style: TellyTypography.caption(color: TellyColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Actions Row: 1-Tap Watch and Mark Seen
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TellyNeonBadge(
                  label: providerName.toUpperCase(),
                  variant: TellyBadgeVariant.winner,
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        ref.read(userWatchlistProvider.notifier).removeItem(item.showId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Marked "${item.title}" as Seen!'),
                            backgroundColor: TellyColors.backgroundCard,
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: TellyColors.textSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('✓ Mark Seen', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        StreamingDeepLinkFactory.launchPlayback(
                          providerId: providerId,
                          externalShowId: '${item.showId}',
                          showSlug: item.title.toLowerCase().replaceAll(' ', '-'),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TellyColors.phosphorLime,
                        foregroundColor: TellyColors.backgroundCanvasOled,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.play_arrow, size: 14),
                      label: Text(
                        'Watch on $providerName',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
