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
import 'package:telly_app/core/widgets/telly_screen_header.dart';
import 'package:telly_app/core/widgets/telly_section_header.dart';
import 'package:telly_app/core/widgets/telly_segmented_control.dart';
import 'package:telly_app/features/queue/data/streaming_availability_repository.dart';
import 'package:telly_app/features/queue/data/streaming_availability_service.dart';
import 'package:telly_app/features/queue/data/watchlist_repository.dart';
import 'package:telly_app/features/queue/domain/streaming_models.dart';
import 'package:telly_app/features/queue/domain/custom_list_models.dart';
import 'package:telly_app/features/queue/data/custom_list_repository.dart';
import 'package:telly_app/features/queue/presentation/screens/custom_list_detail_screen.dart';

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

enum QueueHubMode { watchlist, myLists, sharedLists }

/// SCR-13: Smart Queue Screen with Dual Watchlists, Custom Lists & Shared Friends' Lists.
/// Conforms to `FE-408`, `FE-609`, `FE-LISTS-01` and `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §13.
class SmartQueueScreen extends ConsumerStatefulWidget {
  final List<WatchlistItem>? testItems;
  final QueueHubMode initialMode;
  final List<CustomList>? testCustomLists;
  final List<CustomList>? testSharedLists;

  const SmartQueueScreen({
    super.key,
    this.testItems,
    this.initialMode = QueueHubMode.watchlist,
    this.testCustomLists,
    this.testSharedLists,
  });

  @override
  ConsumerState<SmartQueueScreen> createState() => _SmartQueueScreenState();
}

class _SmartQueueScreenState extends ConsumerState<SmartQueueScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late QueueHubMode _selectedMode;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreateListDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    bool isPrivate = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: TellyColors.surfaceOf(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: TellyColors.borderGlassOf(context)),
          ),
          title: Text(
            'Create Custom List',
            style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context))
                .copyWith(fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIST NAME',
                  style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context))
                      .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('create_list_title_field'),
                  controller: titleController,
                  style: TextStyle(color: TellyColors.textPrimaryOf(context)),
                  decoration: InputDecoration(
                    hintText: 'e.g. Criterion Must-Sees',
                    hintStyle: TextStyle(color: TellyColors.textTertiaryOf(context)),
                    filled: true,
                    fillColor: TellyColors.cardOf(context),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: TellyColors.borderGlassOf(context)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'DESCRIPTION (OPTIONAL)',
                  style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context))
                      .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('create_list_desc_field'),
                  controller: descController,
                  style: TextStyle(color: TellyColors.textPrimaryOf(context)),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'What makes this list special...',
                    hintStyle: TextStyle(color: TellyColors.textTertiaryOf(context)),
                    filled: true,
                    fillColor: TellyColors.cardOf(context),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: TellyColors.borderGlassOf(context)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TellyColors.cardOf(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: TellyColors.borderGlassOf(context)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPrivate ? Icons.lock_outline : Icons.public,
                        color: isPrivate ? TellyColors.neonCoral : TellyColors.phosphorLime,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPrivate ? 'Private List' : 'Public List',
                              style: TextStyle(
                                color: TellyColors.textPrimaryOf(context),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              isPrivate
                                  ? 'Only you can view and edit'
                                  : 'Visible on your profile & shareable',
                              style: TextStyle(
                                color: TellyColors.textTertiaryOf(context),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        key: const Key('create_list_private_switch'),
                        value: isPrivate,
                        activeThumbColor: TellyColors.neonCoral,
                        onChanged: (val) {
                          setModalState(() {
                            isPrivate = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: TellyColors.textSecondaryOf(context))),
            ),
            ElevatedButton(
              key: const Key('create_list_submit_button'),
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isNotEmpty) {
                  final messenger = ScaffoldMessenger.of(context);
                  final cardBg = TellyColors.cardOf(context);
                  final desc = descController.text.trim();
                  await ref.read(userCustomListsProvider.notifier).createList(
                        title: title,
                        description: desc.isNotEmpty ? desc : null,
                        isPrivate: isPrivate,
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Created list "$title"'),
                      backgroundColor: cardBg,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TellyColors.phosphorLime,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Create List', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
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
      body: TellyFloatingHeaderScrollView(
        header: TellyScreenHeader(
          title: 'Queue',
          actions: [
            if (_selectedMode == QueueHubMode.watchlist)
              TellyHeaderAction(
                key: const Key('queue_sort_button'),
                icon: Icons.swap_vert_rounded,
                tooltip: 'Sort',
                onPressed: () => _showSortSheet(context),
              ),
            if (_selectedMode == QueueHubMode.myLists)
              TellyHeaderAction(
                key: const Key('create_new_list_button'),
                icon: Icons.add_rounded,
                tooltip: 'New list',
                onPressed: () => _showCreateListDialog(context),
              ),
          ],
        ),
        body: Column(
          children: [
            // Hub mode switcher: the shared segmented control (FE-UI-01).
            TellySegmentedControl<QueueHubMode>(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              segments: const [
                TellySegment(value: QueueHubMode.watchlist, label: 'Watchlist'),
                TellySegment(value: QueueHubMode.myLists, label: 'My Lists'),
                TellySegment(value: QueueHubMode.sharedLists, label: 'Friends\' Lists'),
              ],
              selected: _selectedMode,
              onChanged: (mode) => setState(() => _selectedMode = mode),
            ),

            if (_selectedMode == QueueHubMode.watchlist) ...[
              // Movies / TV Shows, styled like the Canon selector (FE-HEADER-01).
              _buildCanonTabs(movieCount: movieItems.length, seriesCount: seriesItems.length),

              // Filter Bar (sorting lives in the header)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  // Master Subscription Filter Toggle
                  child: InkWell(
                    onTap: () {
                      ref.read(queueFilterSubscribedProvider.notifier).toggle();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: onlyOnMySubscriptions
                              ? TellyColors.primaryAccentOf(context).withValues(alpha: 0.15)
                              : TellyColors.surfaceOf(context),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: onlyOnMySubscriptions ? TellyColors.primaryAccentOf(context) : TellyColors.borderGlassOf(context),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              onlyOnMySubscriptions ? Icons.check_circle : Icons.radio_button_unchecked,
                              size: 14,
                              color: onlyOnMySubscriptions ? TellyColors.primaryAccentOf(context) : TellyColors.textTertiaryOf(context),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'On My Services',
                              style: TellyTypography.caption(
                                color: onlyOnMySubscriptions ? TellyColors.primaryAccentOf(context) : TellyColors.textSecondaryOf(context),
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
            ] else if (_selectedMode == QueueHubMode.myLists) ...[
              Expanded(
                child: _buildMyListsView(context),
              ),
            ] else ...[
              Expanded(
                child: _buildSharedListsView(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Watchlist sort options, opened from the header's sort action (FE-HEADER-01).
  void _showSortSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: TellyColors.cardOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Consumer(
        builder: (ctx, ref, _) {
          final sortBy = ref.watch(queueSortByProvider);
          Widget option(String value, String label, IconData icon) {
            final isSelected = sortBy == value;
            return ListTile(
              key: Key('queue_sort_option_$value'),
              leading: Icon(icon, color: TellyColors.textSecondaryOf(ctx)),
              title: Text(label, style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(ctx))),
              trailing: isSelected ? Icon(Icons.check_rounded, color: TellyColors.primaryAccentOf(ctx)) : null,
              selected: isSelected,
              onTap: () {
                ref.read(queueSortByProvider.notifier).set(value);
                Navigator.of(sheetCtx).pop();
              },
            );
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'SORT BY',
                      style: TellyTypography.labelSmall(color: TellyColors.textTertiaryOf(ctx))
                          .copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                    ),
                  ),
                  const SizedBox(height: 8),
                  option('friends_score', 'Friends\' Score', Icons.people_alt_outlined),
                  option('leaving_soon', 'Leaving Soon', Icons.timer_outlined),
                ],
              ),
            ),
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
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        selected: _tabController.index == 0 ? 'movie' : 'tv',
        movieCount: movieCount,
        seriesCount: seriesCount,
        movieKey: const Key('queue_movies_tab'),
        seriesKey: const Key('queue_series_tab'),
        onSelect: (mediaType) => _tabController.animateTo(mediaType == 'movie' ? 0 : 1),
      ),
    );
  }

  Widget _buildMyListsView(BuildContext context) {
    final userListsAsync = ref.watch(userCustomListsProvider);
    final lists = widget.testCustomLists ?? userListsAsync.valueOrNull ?? const [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
          // New lists are created from the header's + action (FE-HEADER-01).
          child: TellySectionHeader(label: 'MY CURATED LISTS (${lists.length})'),
        ),
        Expanded(
          child: lists.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    child: TellyEmptyState(
                      icon: Icons.playlist_add,
                      title: 'No custom lists yet',
                      message: 'Create your first list for marathons or recommendations.',
                      actionLabel: 'New list',
                      actionIcon: Icons.add_rounded,
                      onAction: () => _showCreateListDialog(context),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: lists.length,
                  itemBuilder: (context, index) {
                    final list = lists[index];
                    return _buildCustomListCard(context, list, isUserOwned: true);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSharedListsView(BuildContext context) {
    final sharedListsAsync = ref.watch(sharedCustomListsProvider);
    final lists = widget.testSharedLists ?? sharedListsAsync.valueOrNull ?? const [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
          child: TellySectionHeader(label: 'SHARED BY FRIENDS (${lists.length})'),
        ),
        Expanded(
          child: lists.isEmpty
              ? const Center(
                  child: SingleChildScrollView(
                    child: TellyEmptyState(
                      icon: Icons.group_outlined,
                      title: 'No shared lists found',
                      message: 'Friends\' public lists will show up here.',
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: lists.length,
                  itemBuilder: (context, index) {
                    final list = lists[index];
                    return _buildCustomListCard(context, list, isUserOwned: false);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCustomListCard(BuildContext context, CustomList list, {required bool isUserOwned}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TellyColors.borderGlassOf(context)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CustomListDetailScreen(
                  listId: list.id,
                  initialList: list,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            list.title,
                            style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context))
                                .copyWith(fontWeight: FontWeight.w800),
                          ),
                          if (list.description != null && list.description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              list.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TellyNeonBadge(
                      label: list.isPrivate ? 'PRIVATE' : 'PUBLIC',
                      variant: list.isPrivate ? TellyBadgeVariant.upset : TellyBadgeVariant.winner,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Curated by ${list.ownerHandle}',
                      style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: TellyColors.cardOf(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '🎬 ${list.movieCount} Movies • 📺 ${list.seriesCount} Series',
                        style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context))
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (!isUserOwned) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.bookmark_add_outlined, color: TellyColors.phosphorLime, size: 20),
                        tooltip: 'Save to My Lists',
                        onPressed: () {
                          ref.read(userCustomListsProvider.notifier).saveSharedList(list);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Saved "${list.title}" to your lists!'),
                              backgroundColor: TellyColors.cardOf(context),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
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
