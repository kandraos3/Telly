import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/core/services/streaming_deep_link_factory.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/core/widgets/telly_neon_badge.dart';
import 'package:telly_app/core/widgets/telly_canon_switcher.dart';
import 'package:telly_app/core/widgets/telly_empty_state.dart';
import 'package:telly_app/core/widgets/telly_filter_button.dart';
import 'package:telly_app/core/widgets/telly_frosted_sheet.dart';
import 'package:telly_app/core/widgets/telly_screen_header.dart';
import 'package:telly_app/features/queue/data/streaming_availability_repository.dart';
import 'package:telly_app/features/queue/data/streaming_availability_service.dart';
import 'package:telly_app/features/queue/data/watchlist_repository.dart';
import 'package:telly_app/features/queue/domain/streaming_models.dart';

/// Provider for user's universal watchlist items (FE-609).
/// Backed by Drift [WatchlistCache] + Supabase `user_watchlist` and [StreamingAvailabilityRepository].
final userWatchlistProvider =
    AsyncNotifierProvider<WatchlistNotifier, List<WatchlistItem>>(WatchlistNotifier.new);

class WatchlistNotifier extends AsyncNotifier<List<WatchlistItem>> {
  @override
  Future<List<WatchlistItem>> build() async {
    final repo = ref.watch(watchlistRepositoryProvider);
    final streamingRepo = ref.watch(streamingAvailabilityRepositoryProvider);

    final sub = repo.watchWatchlist().listen((entries) async {
      state = AsyncData(await _enrich(entries, streamingRepo));
    });
    ref.onDispose(sub.cancel);

    final initial = await repo.getWatchlist();
    return _enrich(initial, streamingRepo);
  }

  Future<List<WatchlistItem>> _enrich(
    List<WatchlistEntry> entries,
    StreamingAvailabilityRepository streamingRepo,
  ) async {
    final results = await Future.wait(
      entries.map((entry) async {
        final avail = await streamingRepo.getAvailability(
          titleId: entry.titleId,
          mediaType: entry.mediaType,
        );
        final isLeavingSoon = avail.any((a) => a.isLeavingSoon);
        return WatchlistItem(
          showId: entry.titleId,
          title: entry.title,
          posterPath: entry.posterPath,
          mediaType: entry.mediaType,
          runtimeMinutes: entry.mediaType == 'movie' ? 120 : null,
          seasonCount: entry.mediaType == 'tv' ? 1 : null,
          episodeCount: entry.mediaType == 'tv' ? 10 : null,
          friendsAvgScore: 0.0,
          friendsCount: 0,
          savedFromHandle: null,
          addedAt: entry.savedAt,
          availability: avail,
          isLeavingSoon: isLeavingSoon,
        );
      }),
    );
    return results;
  }

  Future<void> removeItem(int showId, [String? mediaType]) async {
    final currentMediaType = mediaType ??
        state.valueOrNull?.firstWhere(
          (i) => i.showId == showId,
          orElse: () => WatchlistItem(showId: showId, title: '', mediaType: 'tv', addedAt: DateTime.now()),
        ).mediaType ??
        'tv';
    await ref.read(watchlistRepositoryProvider).remove(
          titleId: showId,
          mediaType: currentMediaType,
        );
  }

  Future<void> addItem({
    required int titleId,
    required String mediaType,
    required String title,
    String? posterPath,
    String? recommendedBy,
  }) async {
    await ref.read(watchlistRepositoryProvider).add(
          titleId: titleId,
          mediaType: mediaType,
          title: title,
          posterPath: posterPath,
          recommendedBy: recommendedBy,
        );
  }
}

/// Filter state for displaying only titles on user subscriptions.
class QueueFilterSubscribedNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
  void set(bool val) => state = val;
}

final queueFilterSubscribedProvider =
    NotifierProvider<QueueFilterSubscribedNotifier, bool>(QueueFilterSubscribedNotifier.new);

/// Sort mode for the universal queue ('friends_score' or 'leaving_soon').
class QueueSortByNotifier extends Notifier<String> {
  @override
  String build() => 'friends_score';
  void set(String val) => state = val;
}

final queueSortByProvider =
    NotifierProvider<QueueSortByNotifier, String>(QueueSortByNotifier.new);

/// SCR-13: Smart Queue, the watchlist split into Movies and TV Shows (FE-408, FE-609).
/// One control row (the compact switcher and the Filter chip); Sort and On My Services
/// live in the Filter sheet, and custom lists on the Lists screen (epic #47, decision 0004).
/// Conforms to `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §13.
class SmartQueueScreen extends ConsumerStatefulWidget {
  final List<WatchlistItem>? testItems;

  const SmartQueueScreen({super.key, this.testItems});

  @override
  ConsumerState<SmartQueueScreen> createState() => _SmartQueueScreenState();
}

class _SmartQueueScreenState extends ConsumerState<SmartQueueScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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
    final watchlistAsync = ref.watch(userWatchlistProvider);
    final List<WatchlistItem> allItems = widget.testItems ?? watchlistAsync.valueOrNull ?? const [];
    final userSubscriptions = ref.watch(userSubscriptionsProvider);
    final onlyOnMySubscriptions = ref.watch(queueFilterSubscribedProvider);
    final sortBy = ref.watch(queueSortByProvider);

    // Apply subscriptions filter if toggle is ON
    final List<WatchlistItem> filteredItems = onlyOnMySubscriptions
        ? allItems.where((item) => item.isAvailableOn(userSubscriptions)).toList()
        : allItems;

    final sortedItems = List<WatchlistItem>.from(filteredItems);
    if (sortBy == 'leaving_soon') {
      sortedItems.sort((a, b) => (b.isLeavingSoon ? 1 : 0).compareTo(a.isLeavingSoon ? 1 : 0));
    } else {
      sortedItems.sort((a, b) => b.friendsAvgScore.compareTo(a.friendsAvgScore));
    }

    final movieItems = sortedItems.where((item) => item.mediaType == 'movie').toList();
    final seriesItems = sortedItems.where((item) => item.mediaType == 'tv').toList();

    return Scaffold(
      // Pushed from the More hub (#44): subpage app bar with the Lists action (§0.2, #47).
      appBar: TellySubpageAppBar(
        title: 'Queue',
        onNav: () => context.canPop() ? context.pop() : context.go(Routes.more),
        actions: [
          TellyHeaderAction(
            key: const Key('queue_lists_button'),
            icon: Icons.collections_bookmark_outlined,
            tooltip: 'Lists',
            onPressed: () => context.push(Routes.queueLists),
          ),
        ],
      ),
      body: Column(
        children: [
          // The one control row: Movies / TV Shows and Filter (SCR-13).
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(child: _buildCanonTabs(movieCount: movieItems.length, seriesCount: seriesItems.length)),
                const SizedBox(width: 8),
                TellyFilterButton(
                  key: const Key('queue_filter_button'),
                  // Sort order never counts as a filter.
                  activeCount: onlyOnMySubscriptions ? 1 : 0,
                  onPressed: () => _showFilterSheet(context),
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: watchlistAsync.isLoading && widget.testItems == null && allItems.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: TellyColors.phosphorLime),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildQueueList(movieItems, userSubscriptions, onlyOnMySubscriptions),
                      _buildQueueList(seriesItems, userSubscriptions, onlyOnMySubscriptions),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// SCR-13 Filter sheet: SORT BY (closes the sheet) and SHOW (keeps it open).
  void _showFilterSheet(BuildContext context) {
    TellyFrostedSheet.show<void>(
      context: context,
      builder: (sheetCtx) => Consumer(
        builder: (ctx, ref, _) {
          final sortBy = ref.watch(queueSortByProvider);
          Widget label(String text) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  text,
                  style: TellyTypography.labelSmall(color: TellyColors.textTertiaryOf(ctx))
                      .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
                ),
              );
          Widget option(String value, String text, IconData icon) {
            final isSelected = sortBy == value;
            return ListTile(
              key: Key('queue_sort_option_$value'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon, color: TellyColors.textSecondaryOf(ctx)),
              title: Text(text, style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(ctx))),
              trailing: isSelected ? Icon(Icons.check_rounded, color: TellyColors.primaryAccentOf(ctx)) : null,
              selected: isSelected,
              onTap: () {
                ref.read(queueSortByProvider.notifier).set(value);
                Navigator.of(sheetCtx).pop();
              },
            );
          }

          return Column(
            key: const Key('queue_filter_sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label('SORT BY'),
              option('friends_score', 'Friends\' score', Icons.people_alt_outlined),
              option('leaving_soon', 'Leaving soon', Icons.timer_outlined),
              const SizedBox(height: 12),
              label('SHOW'),
              SwitchListTile(
                key: const Key('queue_services_toggle'),
                contentPadding: EdgeInsets.zero,
                title: Text('Only on my services', style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(ctx))),
                subtitle: Text(
                  'Hide titles you can\'t stream',
                  style: TellyTypography.caption(color: TellyColors.textTertiaryOf(ctx)),
                ),
                activeThumbColor: TellyColors.primaryAccentOf(ctx),
                value: ref.watch(queueFilterSubscribedProvider),
                onChanged: (val) => ref.read(queueFilterSubscribedProvider.notifier).set(val),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Movies / TV Shows: the shared canon switcher (FE-UI-01), kept in step with the
  /// swipeable [TabBarView] through [_tabController].
  Widget _buildCanonTabs({required int movieCount, required int seriesCount}) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) => TellyCanonSwitcher(
        margin: EdgeInsets.zero,
        selected: _tabController.index == 0 ? 'movie' : 'tv',
        movieCount: movieCount,
        seriesCount: seriesCount,
        movieKey: const Key('queue_movies_tab'),
        seriesKey: const Key('queue_series_tab'),
        onSelect: (mediaType) => _tabController.animateTo(mediaType == 'movie' ? 0 : 1),
      ),
    );
  }

  Widget _buildQueueList(List<WatchlistItem> items, Set<String> userSubscriptions, bool onlyOnMySubscriptions) {
    if (items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: TellyEmptyState(
            icon: Icons.bookmark_outline,
            title: 'Your queue is clear!',
            message: onlyOnMySubscriptions
                ? 'No titles found on your active subscriptions.'
                : 'Add shows from friend profiles and the feed.',
            actionLabel: onlyOnMySubscriptions ? null : 'Explore titles',
            actionIcon: Icons.explore_outlined,
            onAction: () => context.go(Routes.explore),
          ),
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
        ref.read(userWatchlistProvider.notifier).removeItem(item.showId, item.mediaType);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "${item.title}" from queue'),
            backgroundColor: TellyColors.cardOf(context),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: TellyColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isLeavingSoon ? TellyColors.neonCoral.withValues(alpha: 0.4) : TellyColors.borderGlassOf(context),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push(Routes.title(item.mediaType, item.showId)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Media Type Icon / Poster Box
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 52,
                      height: 72,
                      decoration: BoxDecoration(
                        color: TellyColors.cardOf(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: TellyColors.borderGlassOf(context)),
                      ),
                      child: PosterImage(
                        posterPath: item.posterPath,
                        fallback: Center(
                          child: Icon(
                            item.mediaType == 'movie' ? Icons.movie_outlined : Icons.tv_outlined,
                            color: TellyColors.textTertiaryOf(context),
                            size: 28,
                          ),
                        ),
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
                                  color: TellyColors.textPrimaryOf(context),
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
            ),
            const SizedBox(height: 12),

            // Actions Row: 1-Tap Watch and Mark Seen
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Shrinks (ellipsized) so long provider names fit a 393 pt phone (FE-QUEUE-01).
                Flexible(
                  child: TellyNeonBadge(
                    label: providerName.toUpperCase(),
                    variant: TellyBadgeVariant.winner,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        ref.read(userWatchlistProvider.notifier).removeItem(item.showId, item.mediaType);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Marked "${item.title}" as Seen!'),
                            backgroundColor: TellyColors.cardOf(context),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: TellyColors.textSecondaryOf(context),
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
