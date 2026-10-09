import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../domain/tracking_group.dart';
import '../../domain/tracking_item.dart';
import '../../domain/tracking_models.dart';
import '../providers/tracking_providers.dart';

/// "▶ S2 · E6", "▶ New", "▶ Rewatching" or "▶ Watching" on a Canon row (SCR-14, epic #168).
/// Shown for a ranked title that is being watched; not in the 3x3 view.
class CanonProgressTag extends StatelessWidget {
  const CanonProgressTag({super.key, required this.item});

  final TrackingItem item;

  /// The pill's text.
  static String label(TrackingItem item) {
    if (item.isMovie) return item.isRewatch ? '▶ Rewatching' : '▶ Watching';
    if (item.newEpisodesSince != null) return '▶ New';
    final next = item.nextEpisode?.ref;
    return next == null ? '▶ Watching' : '▶ ${next.label}';
  }

  @override
  Widget build(BuildContext context) {
    final amber = !item.isMovie && item.newEpisodesSince != null;
    final color = amber ? TellyColors.warmAmberOf(context) : TellyColors.primaryAccentOf(context);
    return Container(
      key: const Key('canon_progress_tag'),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(label(item), style: TellyTypography.labelSmall(color: color).copyWith(fontWeight: FontWeight.w800)),
    );
  }
}

/// The tag for one Canon row, or nothing when the title isn't being watched.
class CanonProgressTagFor extends ConsumerWidget {
  const CanonProgressTagFor({super.key, required this.titleId, required this.mediaType, this.padding = const EdgeInsets.only(top: 4)});

  final int titleId;
  final String mediaType;
  final EdgeInsetsGeometry padding;

  /// The item to tag: only a title in `WATCHING` gets one.
  static TrackingItem? taggable(TrackingItem? item) => item != null && item.state == TrackingState.watching ? item : null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = taggable(ref.watch(titleTrackingProvider((titleId, mediaType))));
    if (item == null) return const SizedBox.shrink();
    return Padding(padding: padding, child: Align(alignment: Alignment.centerLeft, child: CanonProgressTag(item: item)));
  }
}

/// The Watching strip under the Canon switcher (SCR-14, features/11 §2.3): how many titles of the
/// selected canon are being watched, and how many finished ones wait to be ranked. Opens the hub
/// on that canon. Hidden when the canon has neither.
class CanonWatchingStrip extends ConsumerWidget {
  const CanonWatchingStrip({super.key, required this.mediaType});

  /// `'movie'` or `'tv'`: the selected canon.
  final String mediaType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(trackingProvider).valueOrNull;
    if (items == null) return const SizedBox.shrink();
    final now = ref.watch(trackingNowProvider)();
    var watching = 0;
    var waiting = 0;
    for (final item in items) {
      if (item.mediaType != mediaType) continue;
      switch (item.group(now)) {
        case TrackingGroup.newEpisodes || TrackingGroup.inProgress || TrackingGroup.paused:
          watching++;
        case TrackingGroup.finishedNotRanked:
          waiting++;
        case TrackingGroup.caughtUp || null:
          break;
      }
    }
    if (watching == 0 && waiting == 0) return const SizedBox.shrink();
    final noun = mediaType == 'movie' ? (watching == 1 ? 'movie' : 'movies') : 'series';
    final lime = TellyColors.primaryAccentOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Semantics(
        button: true,
        container: true,
        label: 'Watching $watching $noun${waiting > 0 ? ', $waiting finished, waiting to be ranked' : ''}',
        excludeSemantics: true,
        child: Material(
          key: const Key('canon_watching_strip'),
          color: TellyColors.surfaceOf(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Color.alphaBlend(lime.withValues(alpha: 0.45), TellyColors.strokeSubtleOf(context))),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(Routes.watchingFiltered(mediaType)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.play_arrow_rounded, color: lime, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Watching $watching $noun',
                            style: TellyTypography.labelLarge(color: TellyColors.textPrimaryOf(context)).copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (waiting > 0)
                            Text(
                              '$waiting finished, waiting to be ranked',
                              key: const Key('canon_watching_waiting'),
                              style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
                            ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: TellyColors.textTertiaryOf(context)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
