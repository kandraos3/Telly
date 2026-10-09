import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/core/services/streaming_deep_link_factory.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/core/widgets/telly_canon_switcher.dart';
import 'package:telly_app/core/widgets/telly_empty_state.dart';
import 'package:telly_app/core/widgets/telly_filter_button.dart';
import 'package:telly_app/core/widgets/telly_frosted_sheet.dart';
import 'package:telly_app/core/widgets/telly_screen_header.dart';
import 'package:telly_app/core/widgets/telly_section_header.dart';
import 'package:telly_app/features/queue/data/streaming_availability_repository.dart';
import 'package:telly_app/features/queue/data/streaming_availability_service.dart';
import 'package:telly_app/features/queue/data/watchlist_repository.dart';
import 'package:telly_app/features/logging/domain/title_search_result.dart';
import 'package:telly_app/features/queue/domain/streaming_models.dart';
import 'package:telly_app/features/queue/domain/up_next_picker.dart';
import 'package:telly_app/features/queue/presentation/widgets/queue_row.dart';
import 'package:telly_app/features/queue/presentation/widgets/up_next_card.dart';
import 'package:telly_app/features/tracking/presentation/widgets/tracking_actions.dart';

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

/// Random source for the Up next pick; tests override it with a seeded [Random].
final queueRandomProvider = Provider<Random>((ref) => Random());

/// The Queue's Up next pick per canon (SCR-13, #134). Auto-disposed with the screen, so
/// each visit re-rolls. The state is a version number that [shuffle] bumps; the picks
/// themselves live in [UpNextPicker], which memoises them while they stay in the pool.
class QueueUpNextNotifier extends AutoDisposeNotifier<int> {
  late UpNextPicker _picker;

  @override
  int build() {
    _picker = UpNextPicker(ref.watch(queueRandomProvider));
    return 0;
  }

  int? pickFor(String mediaType, List<int> pool) => _picker.pickFor(mediaType, pool);

  void shuffle(String mediaType, List<int> pool) {
    _picker.shuffle(mediaType, pool);
    state++;
  }
}

final queueUpNextProvider = NotifierProvider.autoDispose<QueueUpNextNotifier, int>(QueueUpNextNotifier.new);

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

  /// Titles swiped away this visit, hidden at once: a dismissed [Dismissible] must leave the
  /// tree before the watchlist's async removal lands. Ephemeral UI state; Undo un-hides.
  final Set<String> _swiped = {};

  static String _swipeKey(WatchlistItem item) => '${item.mediaType}_${item.showId}';

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
    final List<WatchlistItem> allItems = [
      for (final item in widget.testItems ?? watchlistAsync.valueOrNull ?? const <WatchlistItem>[])
        if (!_swiped.contains(_swipeKey(item))) item,
    ];
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
                ? const _QueueSkeleton()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildQueueList('movie', movieItems, allItems.where((i) => i.mediaType == 'movie').length,
                          userSubscriptions, onlyOnMySubscriptions),
                      _buildQueueList('tv', seriesItems, allItems.where((i) => i.mediaType == 'tv').length,
                          userSubscriptions, onlyOnMySubscriptions),
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

  /// One canon's page: the Up next card, then THEN rows (SCR-13, #134). [unfilteredCount]
  /// tells "nothing streams on your services" apart from an empty watchlist.
  Widget _buildQueueList(
    String mediaType,
    List<WatchlistItem> items,
    int unfilteredCount,
    Set<String> userSubscriptions,
    bool onlyOnMySubscriptions,
  ) {
    if (items.isEmpty) {
      if (onlyOnMySubscriptions && unfilteredCount > 0) {
        return Center(
          child: SingleChildScrollView(
            child: TellyEmptyState(
              icon: Icons.tv_off_outlined,
              title: 'Nothing here streams on your services',
              message: 'Show your whole queue, or add services in Settings.',
              actionLabel: 'Show all',
              actionKey: const Key('queue_show_all_button'),
              onAction: () => ref.read(queueFilterSubscribedProvider.notifier).set(false),
            ),
          ),
        );
      }
      return Center(
        child: SingleChildScrollView(
          child: TellyEmptyState(
            icon: Icons.bookmark_outline,
            title: 'Your queue is clear!',
            message: 'Add shows from friend profiles and the feed.',
            actionLabel: 'Explore titles',
            actionIcon: Icons.explore_outlined,
            onAction: () => context.go(Routes.explore),
          ),
        ),
      );
    }

    // The pick's version: ↻ bumps it, so the page rebuilds with the new pick.
    ref.watch(queueUpNextProvider);
    final upNext = ref.read(queueUpNextProvider.notifier);
    final pool = [for (final i in items) i.showId];
    final pickId = upNext.pickFor(mediaType, pool);
    final pick = items.firstWhere((i) => i.showId == pickId);
    final rest = [for (final i in items) if (i.showId != pickId) i];

    return ListView(
      key: PageStorageKey('queue_page_$mediaType'),
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      children: [
        _swipeable(
          pick,
          UpNextCard(
            key: const Key('queue_up_next_card'),
            item: pick,
            providerName: _providerName(pick, userSubscriptions),
            onTap: () => context.push(Routes.title(pick.mediaType, pick.showId)),
            onWatch: () => _watch(pick, userSubscriptions),
            onSeen: () => _markSeen(pick),
            onShuffle: pool.length < 2 ? null : () => upNext.shuffle(mediaType, pool),
          ),
        ),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 16),
          TellySectionHeader(
            label: 'THEN',
            trailing: Text(
              '${rest.length}',
              key: const Key('queue_then_count'),
              style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)).copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 4),
          for (final item in rest)
            _swipeable(
              item,
              QueueRow(
                key: ValueKey('queue_row_${item.showId}'),
                item: item,
                providerName: _providerName(item, userSubscriptions),
                onTap: () => context.push(Routes.title(item.mediaType, item.showId)),
                onWatch: () => _watch(item, userSubscriptions),
              ),
            ),
        ],
      ],
    );
  }

  static String _providerName(WatchlistItem item, Set<String> userSubscriptions) =>
      item.primarySubscribedAvailability(userSubscriptions)?.platformName ?? 'Online';

  void _watch(WatchlistItem item, Set<String> userSubscriptions) {
    StreamingDeepLinkFactory.launchPlayback(
      providerId: item.primarySubscribedAvailability(userSubscriptions)?.platformId ?? 'netflix',
      externalShowId: '${item.showId}',
      showSlug: item.title.toLowerCase().replaceAll(' ', '-'),
    );
  }

  /// Swipe right: mark seen (opens the Log flow); swipe left: remove, with Undo (SCR-13).
  Widget _swipeable(WatchlistItem item, Widget child) {
    Widget background(Color color, IconData icon, Alignment alignment, Color iconColor) => Container(
          alignment: alignment,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          color: color,
          child: Icon(icon, color: iconColor),
        );
    return Dismissible(
      key: ValueKey('queue_swipe_${item.mediaType}_${item.showId}'),
      background: background(TellyColors.phosphorLime, Icons.check_rounded, Alignment.centerLeft, const Color(0xFF08090C)),
      secondaryBackground: background(TellyColors.neonCoral, Icons.delete_outline, Alignment.centerRight, Colors.white),
      onDismissed: (direction) {
        setState(() => _swiped.add(_swipeKey(item)));
        direction == DismissDirection.startToEnd ? _markSeen(item) : _remove(item);
      },
      // Long-press opens the row actions (epic #168).
      child: GestureDetector(behavior: HitTestBehavior.translucent, onLongPress: () => _openActions(item), child: child),
    );
  }

  /// Long-press on a row or the Up next card: Start watching, Mark seen, Remove (SCR-13).
  Future<void> _openActions(WatchlistItem item) async {
    final choice = await TellyFrostedSheet.show<String>(
      context: context,
      builder: (ctx) => Column(
        key: const Key('queue_actions_sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(item.title, style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(ctx)).copyWith(fontWeight: FontWeight.w800)),
          ),
          for (final (key, icon, label, value) in [
            ('queue_action_start', Icons.play_circle_outline_rounded, 'Start watching', 'start'),
            ('queue_action_seen', Icons.check_rounded, 'Mark seen', 'seen'),
            ('queue_action_remove', Icons.delete_outline, 'Remove', 'remove'),
          ])
            ListTile(
              key: Key(key),
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon),
              title: Text(label),
              onTap: () => Navigator.of(ctx).pop(value),
            ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'start':
        await _startWatching(item);
      case 'seen':
        setState(() => _swiped.add(_swipeKey(item)));
        _markSeen(item);
      case 'remove':
        setState(() => _swiped.add(_swipeKey(item)));
        _remove(item);
    }
  }

  /// Start watching from the Queue (features/11 §4.1): the title page's flow, fed from the cached
  /// detail. A series we can't describe offline opens its page instead.
  Future<void> _startWatching(WatchlistItem item) async {
    await TrackingActions.startFromQueue(
      context,
      ref,
      item,
      // Leaving the Queue hides the row at once; Undo brings it back.
      onQueueChanged: (inQueue) {
        if (!mounted) return;
        setState(() => inQueue ? _swiped.remove(_swipeKey(item)) : _swiped.add(_swipeKey(item)));
      },
    );
  }

  /// Leaves the watchlist and opens the Log flow with the title selected (SCR-09).
  void _markSeen(WatchlistItem item) {
    ref.read(userWatchlistProvider.notifier).removeItem(item.showId, item.mediaType);
    context.push(
      Routes.log,
      extra: TitleSearchResult(id: item.showId, mediaType: item.mediaType, title: item.title, posterPath: item.posterPath),
    );
  }

  void _remove(WatchlistItem item) {
    final watchlist = ref.read(userWatchlistProvider.notifier);
    watchlist.removeItem(item.showId, item.mediaType);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Removed "${item.title}" from queue'),
        backgroundColor: TellyColors.cardOf(context),
        action: SnackBarAction(
          key: const Key('queue_undo_remove'),
          label: 'Undo',
          textColor: TellyColors.primaryAccentOf(context),
          onPressed: () {
            if (mounted) setState(() => _swiped.remove(_swipeKey(item)));
            watchlist.addItem(
              titleId: item.showId,
              mediaType: item.mediaType,
              title: item.title,
              posterPath: item.posterPath,
              recommendedBy: item.savedFromHandle,
            );
          },
        ),
      ),
    );
  }
}

/// Loading placeholder: a card-sized block and five row-sized blocks (component library §7.1).
class _QueueSkeleton extends StatelessWidget {
  const _QueueSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double height, {EdgeInsets margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6)}) =>
        Container(
          height: height,
          margin: margin,
          decoration: BoxDecoration(color: TellyColors.surfaceOf(context), borderRadius: BorderRadius.circular(14)),
        );
    return ListView(
      key: const Key('queue_skeleton'),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        block(240, margin: const EdgeInsets.fromLTRB(16, 4, 16, 16)),
        for (var i = 0; i < 5; i++) block(58),
      ],
    );
  }
}
