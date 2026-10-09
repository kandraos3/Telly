import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/services/haptics_service.dart';
import '../../../../core/widgets/telly_frosted_sheet.dart';
import '../../../logging/domain/log_request.dart';
import '../../../logging/domain/title_search_result.dart';
import '../../../profile/domain/dropped_show.dart';
import '../../../profile/presentation/controllers/graveyard_controller.dart';
import '../../../profile/presentation/widgets/log_dropped_show_sheet.dart';
import '../../data/tracking_repository.dart';
import '../../domain/tracking_item.dart';
import '../../domain/tracking_models.dart';
import '../providers/tracking_providers.dart';
import 'finish_sheet.dart';
import 'tracking_undo_tray.dart';

/// The tracking actions that every surface offers the same way: the title page, the hub, Home and
/// Canon (features/11 §4). Each one writes through [trackingProvider] (local first), gives the
/// haptic and the Undo tray, and opens the finish sheet when a write ends the title.
abstract final class TrackingActions {
  static Future<void> _haptic(WidgetRef ref, {bool medium = false}) async {
    if (!ref.read(hapticsEnabledProvider)) return;
    medium ? await HapticsService.mediumImpact() : await HapticsService.lightImpact();
  }

  static TitleSearchResult _result(TrackingItem item) =>
      TitleSearchResult(id: item.titleId, mediaType: item.mediaType, title: item.title, posterPath: item.posterPath);

  /// ✓ E6: moves the place to the next episode, with Undo; opens the finish sheet when that
  /// leaves nothing to watch (§4.2, §4.5).
  static Future<void> markNext(BuildContext context, WidgetRef ref, TrackingItem item) async {
    final next = item.nextEpisode?.ref;
    if (next == null || item.isMovie) return;
    await _haptic(ref);
    final controller = ref.read(trackingProvider.notifier);
    final before = await controller.markNext(item);
    if (before == null || !context.mounted) return;
    TrackingUndoTray.show(
      context,
      message: '${next.label} watched',
      onUndo: () => controller.undo(before),
    );
    final updated = await ref.read(trackingRepositoryProvider).getOne(item.titleId, item.mediaType);
    if (updated != null && updated.state != TrackingState.watching && context.mounted) {
      await openFinishSheet(context, updated);
    }
  }

  /// ✓ Finished on a movie: finishes it and opens the finish sheet.
  static Future<void> finishMovie(BuildContext context, WidgetRef ref, TrackingItem item) async {
    await _haptic(ref, medium: true);
    final done = await ref.read(trackingProvider.notifier).finish(item);
    if (context.mounted) await openFinishSheet(context, done);
  }

  /// Long-press on ✓: *Un-log S2 · E5* for the last watched episode (§4.3).
  static Future<void> offerUnlogLast(BuildContext context, WidgetRef ref, TrackingItem item) async {
    final place = item.place;
    if (place == null) return;
    final choice = await TellyFrostedSheet.show<bool>(
      context: context,
      builder: (ctx) => ListTile(
        key: const Key('unlog_last_action'),
        leading: const Icon(Icons.undo_rounded),
        title: Text('Un-log ${place.label}'),
        onTap: () => Navigator.of(ctx).pop(true),
      ),
    );
    if (choice != true || !context.mounted) return;
    await unlog(context, ref, item, place);
  }

  /// Marks [episode] and everything after it as not watched; Undo restores the place.
  static Future<void> unlog(BuildContext context, WidgetRef ref, TrackingItem item, EpisodeRef episode) async {
    final before = item.place;
    await _haptic(ref);
    final controller = ref.read(trackingProvider.notifier);
    await controller.unlog(item, episode);
    if (!context.mounted) return;
    TrackingUndoTray.show(
      context,
      message: '${episode.label} marked not watched',
      onUndo: () async {
        final current = await ref.read(trackingRepositoryProvider).getOne(item.titleId, item.mediaType);
        if (current != null) await controller.setPlace(current, before);
      },
    );
  }

  /// The finish sheet, and where its buttons lead (§4.5).
  static Future<void> openFinishSheet(BuildContext context, TrackingItem item) async {
    final result = await FinishSheet.show(context, item);
    if (result == null || !context.mounted) return;
    switch (result.action) {
      case FinishAction.logAndDuel:
        context.push(Routes.log, extra: LogRequest(title: _result(item), status: result.status));
      case FinishAction.reDuel:
        context.push(Routes.log, extra: _result(item));
      case FinishAction.later || FinishAction.keepRank:
        break;
    }
  }

  /// **Rank →**: opens the Log flow with the title and the status that fits how it ended.
  static void rank(BuildContext context, TrackingItem item) {
    context.push(Routes.log, extra: LogRequest(title: _result(item), status: FinishSheet.defaultStatus(item)));
  }

  /// features/11 §4.6: the existing drop flow, prefilled from the place; saving stops tracking.
  /// Returns whether the show was dropped.
  static Future<bool> drop(BuildContext context, WidgetRef ref, TrackingItem item, {bool goToGraveyard = true}) async {
    final point = item.nextEpisode?.ref ?? item.place;
    final details = await LogDroppedShowSheet.show(
      context: context,
      titleId: item.titleId,
      title: item.title,
      releaseYear: 0,
      initial: DropDetails(season: point?.season ?? 1, episode: point?.episode),
    );
    if (details == null || !context.mounted) return false;
    try {
      await ref
          .read(graveyardControllerProvider.notifier)
          .drop(titleId: item.titleId, mediaType: item.mediaType, details: details);
      await ref.read(trackingProvider.notifier).stop(item);
      if (goToGraveyard && context.mounted) context.go(Routes.graveyard);
      return true;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't add it to your Graveyard. Try again.")),
        );
      }
      return false;
    }
  }

  /// *Stop tracking* after a confirm (§4.9). Returns whether it stopped.
  static Future<bool> confirmStop(BuildContext context, WidgetRef ref, TrackingItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('stop_tracking_dialog'),
        title: const Text('Stop tracking?'),
        content: const Text('Your progress is removed. Your rank, if any, stays.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            key: const Key('stop_tracking_confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Stop tracking'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return false;
    await ref.read(trackingProvider.notifier).stop(item);
    return true;
  }
}
