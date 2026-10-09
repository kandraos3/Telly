import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_section_header.dart';
import '../../domain/tracking_hub.dart';
import '../providers/tracking_providers.dart';
import 'hub_widgets.dart';
import 'tracking_actions.dart';

/// Home's *Currently watching* card (SCR-21, epic #168): at most three rows, a count line, and
/// *See all* to the hub. Hidden when there is nothing to show.
class HomeCurrentlyWatching extends ConsumerWidget {
  const HomeCurrentlyWatching({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(trackingProvider).valueOrNull;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    final now = ref.watch(trackingNowProvider)();
    final hub = TrackingHub(items, now);
    final rows = hub.homeRows();
    if (rows.isEmpty) return const SizedBox.shrink();
    final countLine = hub.homeCountLine();
    void openHub() => context.push(Routes.watching);

    return Column(
      key: const Key('home_currently_watching'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: const Key('home_watching_header'),
          onTap: openHub,
          child: TellySectionHeader(
            label: 'CURRENTLY WATCHING',
            trailing: TextButton(
              key: const Key('home_watching_see_all'),
              onPressed: openHub,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(
                'See all ${hub.count(WatchingFilter.all)} ›',
                style: TellyTypography.labelLarge(color: TellyColors.primaryAccentOf(context)).copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: TellyColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TellyColors.strokeOf(context)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final item in rows)
                WatchingRow(
                  key: Key('home_watching_row_${item.mediaType}_${item.titleId}'),
                  item: item,
                  group: hub.groupOf(item),
                  now: now,
                  compact: true,
                  onTap: () => context.push(Routes.title(item.mediaType, item.titleId)),
                  onWatched: () =>
                      item.isMovie ? TrackingActions.finishMovie(context, ref, item) : TrackingActions.markNext(context, ref, item),
                  onUnlogLast: () => TrackingActions.offerUnlogLast(context, ref, item),
                  onRank: () => TrackingActions.rank(context, item),
                ),
            ],
          ),
        ),
        if (countLine != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              countLine,
              key: const Key('home_watching_count'),
              style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}
