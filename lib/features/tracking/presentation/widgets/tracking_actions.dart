import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/services/haptics_service.dart';
import '../../../../core/widgets/telly_frosted_sheet.dart';
import '../../../logging/domain/log_request.dart';
import '../../../logging/domain/title_search_result.dart';
import '../../../profile/domain/dropped_show.dart';
import '../../../queue/data/watchlist_repository.dart';
import '../../../queue/domain/streaming_models.dart';
import '../../../title_detail/data/title_detail_repository.dart';
import '../../../title_detail/domain/title_detail_models.dart';
import '../../../profile/presentation/controllers/graveyard_controller.dart';
import '../../../profile/presentation/widgets/log_dropped_show_sheet.dart';
import '../../data/tracking_repository.dart';
import '../../domain/tracking_item.dart';
import '../../domain/tracking_models.dart';
import '../providers/tracking_providers.dart';
import '../../domain/tracking_progress.dart';
import 'finish_sheet.dart';
import 'where_are_you_sheet.dart';
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

  /// What a title page knows when someone starts tracking it.
  static TrackingStartRequest requestFromDetail(TitleDetail title, {EpisodeRef? place, bool rewatch = false}) =>
      TrackingStartRequest(
        titleId: title.id,
        mediaType: title.mediaType,
        title: title.title,
        posterPath: title.posterPath,
        backdropPath: title.backdropPath,
        titleStatus: title.status,
        runtimeMinutes: title.runtimeMinutes,
        seasons: [
          for (final s in title.seasons)
            if (s.seasonNumber >= 1)
              SeasonInfo(
                number: s.seasonNumber,
                episodeCount: s.episodeCount,
                airDate: s.airDate == null ? null : DateTime.tryParse(s.airDate!),
              ),
        ],
        place: place,
        rewatch: rewatch,
      );

  /// Start watching [title] (features/11 §4.1): a series asks where you are first, a movie starts
  /// at once. The title leaves the Queue ([wasQueued]); Undo stops tracking and puts it back.
  /// [onQueueChanged] tells the caller when the Queue membership changed. [ranked] presets the
  /// sheet at the last aired episode (§10). Returns the new item, or null if the sheet was dismissed.
  static Future<TrackingItem?> startWatching(
    BuildContext context,
    WidgetRef ref,
    TitleDetail title, {
    required bool wasQueued,
    bool ranked = false,
    ValueChanged<bool>? onQueueChanged,
  }) async {
    var request = requestFromDetail(title);
    if (title.isTv && request.seasons.isNotEmpty) {
      final preset = ranked
          ? TrackingProgress.lastAired(ShowSchedule(seasons: request.seasons, status: title.status), DateTime.now())
          : null;
      final result = await WhereAreYouSheet.show(
        context,
        titleId: title.id,
        seasons: request.seasons,
        initialPlace: preset,
      );
      if (result == null || !context.mounted) return null;
      request = requestFromDetail(title, place: result.place);
    }
    final controller = ref.read(trackingProvider.notifier);
    final queue = ref.read(watchlistRepositoryProvider);
    final started = await controller.start(request);
    await _haptic(ref, medium: true);
    if (wasQueued) {
      await queue.remove(titleId: title.id, mediaType: title.mediaType);
      onQueueChanged?.call(false);
    }
    if (!context.mounted) return started;
    TrackingUndoTray.show(
      context,
      message: 'Watching ${title.title}',
      onUndo: () async {
        await controller.stop(started);
        if (wasQueued) {
          await queue.add(titleId: title.id, mediaType: title.mediaType, title: title.title, posterPath: title.posterPath);
          onQueueChanged?.call(true);
        }
      },
    );
    return started;
  }

  /// Start watching a Queue title (features/11 §4.1): the title page's flow, fed from the cached detail. A
  /// series we can't describe offline opens its page instead. The Queue (Home's hero, SCR-13) calls this.
  static Future<TrackingItem?> startFromQueue(
    BuildContext context,
    WidgetRef ref,
    WatchlistItem item, {
    ValueChanged<bool>? onQueueChanged,
  }) async {
    TitleDetail? detail;
    try {
      detail = await ref.read(titleDetailRepositoryProvider).fetchTitleDetail(id: item.showId, mediaType: item.mediaType);
    } catch (_) {}
    if (!context.mounted) return null;
    if (detail == null && item.mediaType == 'tv') {
      context.push(Routes.title(item.mediaType, item.showId));
      return null;
    }
    final title = detail ?? TitleDetail(id: item.showId, mediaType: item.mediaType, title: item.title, posterPath: item.posterPath);
    return startWatching(context, ref, title, wasQueued: true, onQueueChanged: onQueueChanged);
  }

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

  /// Graveyard **Revive** (features/11 §4.7): tracks the show again from its drop point, removes
  /// the Graveyard entry and opens the title page in the Watching state. A drop that recorded a
  /// season but no episode resumes at that season's start, so the place is the last episode of the
  /// season before (nothing for season 1). Needs the show's seasons, so it can't run offline.
  static Future<bool> revive(BuildContext context, WidgetRef ref, DroppedShow show) async {
    TitleDetail? detail;
    try {
      detail = await ref.read(titleDetailRepositoryProvider).fetchTitleDetail(id: show.titleId, mediaType: 'tv');
    } catch (_) {}
    if (!context.mounted) return false;
    if (detail == null || detail.seasons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't revive it right now. Try again when you're online.")),
      );
      return false;
    }
    final episode = show.droppedAtEpisode;
    EpisodeRef? place;
    if (episode != null) {
      place = EpisodeRef(show.droppedAtSeason, episode);
    } else {
      final before = [
        for (final s in detail.seasons)
          if (s.seasonNumber >= 1 && s.seasonNumber < show.droppedAtSeason && s.episodeCount >= 1) s,
      ]..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
      if (before.isNotEmpty) place = EpisodeRef(before.last.seasonNumber, before.last.episodeCount);
    }
    await ref.read(trackingProvider.notifier).revive(requestFromDetail(detail, place: place));
    ref.read(graveyardControllerProvider.notifier).forget(show);
    await _haptic(ref, medium: true);
    if (context.mounted) context.push(Routes.title('tv', show.titleId));
    return true;
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
