import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_empty_state.dart';
import '../../../../core/widgets/telly_frosted_sheet.dart';
import '../../../../core/widgets/telly_screen_header.dart';
import '../../../../core/widgets/telly_section_header.dart';
import '../../../profile/presentation/controllers/graveyard_controller.dart';
import '../../domain/tracking_hub.dart';
import '../../domain/tracking_item.dart';
import '../providers/tracking_providers.dart';
import '../widgets/hub_widgets.dart';
import '../widgets/tracking_actions.dart';

/// `SCR-29` Watching: everything you are tracking (epic #168; features/11 §2.3, §8, §9.5).
/// Pushed at `/more/watching`, opened from More, Home's *See all* and Canon's strip.
class WatchingHubScreen extends ConsumerStatefulWidget {
  const WatchingHubScreen({super.key, this.initialFilter = WatchingFilter.all});

  final WatchingFilter initialFilter;

  @override
  ConsumerState<WatchingHubScreen> createState() => _WatchingHubScreenState();
}

class _WatchingHubScreenState extends ConsumerState<WatchingHubScreen> {
  // Which chip and sort are showing is ephemeral screen state; the tracked titles are not.
  late WatchingFilter _filter = widget.initialFilter;
  WatchingSort _sort = WatchingSort.recent;

  Future<void> _openSort() async {
    final picked = await TellyFrostedSheet.show<WatchingSort>(
      context: context,
      builder: (ctx) => Column(
        key: const Key('watching_sort_sheet'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (value, label, key) in [
            (WatchingSort.recent, 'Recent', 'sort_recent'),
            (WatchingSort.fewestLeft, 'Fewest left', 'sort_fewest_left'),
          ])
            ListTile(
              key: Key(key),
              title: Text(label),
              trailing: _sort == value ? Icon(Icons.check_rounded, color: TellyColors.primaryAccentOf(ctx)) : null,
              onTap: () => Navigator.of(ctx).pop(value),
            ),
        ],
      ),
    );
    if (picked != null && mounted) setState(() => _sort = picked);
  }

  Future<void> _refresh() async {
    await ref.read(trackingProvider.notifier).refresh();
    ref.invalidate(trackingWeekStatsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(trackingProvider);
    final now = ref.watch(trackingNowProvider)();
    final items = async.valueOrNull;
    final hub = items == null ? null : TrackingHub(items, now);
    final dropped = ref.watch(graveyardControllerProvider.select((s) => s.valueOrNull?.length ?? 0));

    return Scaffold(
      appBar: TellySubpageAppBar(
        title: 'Watching',
        onNav: () => context.canPop() ? context.pop() : context.go(Routes.more),
        actions: [
          TellyHeaderAction(
            key: const Key('watching_sort_button'),
            icon: Icons.swap_vert_rounded,
            tooltip: 'Sort',
            onPressed: _openSort,
          ),
        ],
      ),
      body: SafeArea(
        child: hub == null
            ? (async.hasError
                ? _Error(onRetry: () => ref.invalidate(trackingProvider))
                : const SingleChildScrollView(physics: NeverScrollableScrollPhysics(), child: WatchingSkeleton()))
            : hub.isEmpty
                ? _Empty(dropped: dropped)
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 24),
                      children: _content(hub, now, dropped),
                    ),
                  ),
      ),
    );
  }

  List<Widget> _content(TrackingHub hub, DateTime now, int dropped) {
    final isMovies = _filter == WatchingFilter.movie;
    final stats = ref.watch(trackingWeekStatsProvider(isMovies ? 'movie' : 'tv'));
    final groups = hub.groups(_filter, _sort);
    final history = _filter == WatchingFilter.finished ? hub.finishedHistory() : const <TrackingItem>[];
    final noRows = _filter == WatchingFilter.finished ? history.isEmpty : groups.isEmpty;
    return [
      const SizedBox(height: 4),
      WatchingFilterChips(hub: hub, selected: _filter, onSelected: (f) => setState(() => _filter = f)),
      ThisWeekStrip(filter: _filter, stats: stats.valueOrNull, loading: stats.isLoading),
      if (noRows)
        _EmptyFilter(filter: _filter, onShowAll: () => setState(() => _filter = WatchingFilter.all))
      else if (_filter == WatchingFilter.finished)
        for (final item in history) _row(item, null, now, hub)
      else
        for (final g in groups) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: TellySectionHeader(label: '${g.group.header} · ${g.items.length}'),
          ),
          for (final item in g.items) _row(item, g.group, now, hub),
        ],
      if (dropped > 0)
        InkWell(
          key: const Key('watching_graveyard_row'),
          onTap: () => context.push(Routes.graveyard),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Graveyard: $dropped dropped show${dropped == 1 ? '' : 's'}',
                    style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context)),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: TellyColors.textTertiaryOf(context)),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _row(TrackingItem item, group, DateTime now, TrackingHub hub) {
    final row = WatchingRow(
      item: item,
      group: group ?? hub.groupOf(item),
      now: now,
      moviePrefix: _filter == WatchingFilter.all,
      onTap: () => context.push(Routes.title(item.mediaType, item.titleId)),
      onWatched: () => item.isMovie ? TrackingActions.finishMovie(context, ref, item) : TrackingActions.markNext(context, ref, item),
      onUnlogLast: () => TrackingActions.offerUnlogLast(context, ref, item),
      onRank: () => TrackingActions.rank(context, item),
    );
    final coral = TellyColors.neonCoralOf(context);
    return Dismissible(
      key: ValueKey('hub_${item.mediaType}_${item.titleId}'),
      direction: DismissDirection.endToStart,
      // Never dismisses: the action runs, and the list follows the cache.
      confirmDismiss: (_) async {
        if (item.isMovie) {
          await TrackingActions.confirmStop(context, ref, item);
        } else {
          await TrackingActions.drop(context, ref, item, goToGraveyard: false);
        }
        return false;
      },
      background: Container(
        color: coral.withValues(alpha: 0.18),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Text(
          item.isMovie ? 'Stop tracking' : 'Drop it',
          style: TellyTypography.labelLarge(color: coral).copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      child: row,
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.dropped});

  final int dropped;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TellyEmptyState(
              key: const Key('watching_empty'),
              icon: Icons.play_circle_outline_rounded,
              title: 'Nothing here yet',
              message: "Track what you're watching. Start a show from its page or your Queue.",
              actionLabel: 'Open Queue',
              actionKey: const Key('watching_open_queue'),
              onAction: () => context.push(Routes.queue),
            ),
            TextButton(
              key: const Key('watching_explore'),
              onPressed: () => context.go(Routes.explore),
              child: const Text('Explore'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFilter extends StatelessWidget {
  const _EmptyFilter({required this.filter, required this.onShowAll});

  final WatchingFilter filter;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final message = switch (filter) {
      WatchingFilter.movie => 'No movies in progress',
      WatchingFilter.tv => 'No series in progress',
      WatchingFilter.finished => 'Nothing finished yet',
      WatchingFilter.all => 'Nothing to show',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 32),
      child: Column(
        key: const Key('watching_empty_filter'),
        children: [
          Text(message, style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context))),
          const SizedBox(height: 8),
          TextButton(key: const Key('watching_show_all'), onPressed: onShowAll, child: const Text('Show all')),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        key: const Key('watching_error'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Couldn't load what you're watching.", style: TellyTypography.bodyMedium(color: TellyColors.textPrimaryOf(context))),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
