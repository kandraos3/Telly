import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/tracking_repository.dart';
import '../../domain/tracking_item.dart';
import '../../domain/tracking_models.dart';

/// The caller's tracked titles (features/11 §9.3). State is the Drift cache, so every change is
/// visible at once and offline; actions write the cache first and queue the server call.
class TrackingController extends AsyncNotifier<List<TrackingItem>> {
  TrackingRepository get _repo => ref.read(trackingRepositoryProvider);

  @override
  Future<List<TrackingItem>> build() async {
    final repo = ref.watch(trackingRepositoryProvider);
    final sub = repo.watchAll().listen((items) => state = AsyncData(items));
    ref.onDispose(sub.cancel);
    // Best effort: offline, the cache is the truth until the next sync.
    unawaited(refresh());
    return repo.watchAll().first;
  }

  /// Pulls the server's copy into the cache. Never throws: offline is normal.
  Future<void> refresh() async {
    try {
      await _repo.hydrate();
    } catch (_) {}
  }

  Future<TrackingItem> start(TrackingStartRequest request) => _repo.start(request);

  /// ✓ Watched: moves the place to the next episode. Returns the item as it was, for [undo].
  Future<TrackingItem?> markNext(TrackingItem item) async {
    final next = item.nextEpisode?.ref;
    if (next == null || item.isMovie) return null;
    await _repo.setPlace(item, next);
    return item;
  }

  /// Puts the place back to what [before] had. Sends the previous absolute place, so the
  /// WATCHED and UNWATCHED events net to zero on the server (features/11 §4.2).
  Future<void> undo(TrackingItem before) async {
    final current = await _repo.getOne(before.titleId, before.mediaType);
    if (current == null) return;
    await _repo.setPlace(current, before.place);
  }

  Future<TrackingItem> setPlace(TrackingItem item, EpisodeRef? place) => _repo.setPlace(item, place);

  /// "Mark as not watched" on [episode]: the place goes to the episode before it (§4.3).
  Future<TrackingItem> unlog(TrackingItem item, EpisodeRef episode) async {
    final schedule = await _repo.scheduleFor(item);
    EpisodeRef? before;
    if (episode.episode > 1) {
      before = EpisodeRef(episode.season, episode.episode - 1);
    } else {
      for (final s in schedule.seasons.reversed) {
        if (s.number < episode.season && s.episodeCount >= 1) {
          before = EpisodeRef(s.number, s.episodeCount);
          break;
        }
      }
    }
    return _repo.setPlace(item, before);
  }

  Future<void> logRewatch(TrackingItem item, EpisodeRef episode) => _repo.logRewatch(item, episode);

  Future<TrackingItem> finish(TrackingItem item) => _repo.finish(item);

  Future<void> stop(TrackingItem item) => _repo.stop(item);

  Future<TrackingItem> revive(TrackingStartRequest request) => _repo.revive(request);
}

final trackingProvider = AsyncNotifierProvider<TrackingController, List<TrackingItem>>(TrackingController.new);

/// One tracked title, or null when it isn't tracked. Key: `(titleId, mediaType)`.
final titleTrackingProvider = Provider.family<TrackingItem?, (int, String)>((ref, key) {
  final items = ref.watch(trackingProvider).valueOrNull ?? const <TrackingItem>[];
  for (final item in items) {
    if (item.titleId == key.$1 && item.mediaType == key.$2) return item;
  }
  return null;
});

/// One season's episodes for the title page's Seasons list: the cache first, `tmdb-season` when
/// missing or stale, the cache again when offline. Key: `(titleId, season)`.
final seasonEpisodesProvider = FutureProvider.family<List<EpisodeInfo>, (int, int)>((ref, key) {
  return ref.watch(trackingRepositoryProvider).loadSeason(key.$1, key.$2);
});

/// Friends watching a title now (features/11 §5.4). Offline or failing reads as nobody, so the
/// row simply hides (SCR-08 §T.10). Key: `(titleId, mediaType)`.
final titleWatchersProvider = FutureProvider.family<TrackingWatchers, (int, String)>((ref, key) async {
  try {
    return await ref.watch(trackingRepositoryProvider).watchers(key.$1, key.$2);
  } catch (_) {
    return const TrackingWatchers();
  }
});
