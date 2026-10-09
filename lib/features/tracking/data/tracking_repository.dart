import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/network/supabase_providers.dart';
import '../domain/tracking_item.dart';
import '../domain/tracking_models.dart';
import '../domain/tracking_progress.dart';

/// A friend who is watching a title now (features/11 §5.4). Never carries a place.
class TrackingWatcher {
  const TrackingWatcher({required this.userId, this.username, this.displayName, this.avatarUrl});

  final String userId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
}

class TrackingWatchers {
  const TrackingWatchers({this.watchers = const [], this.total = 0});

  final List<TrackingWatcher> watchers;
  final int total;
}

/// `get_tracking_stats` (features/11 §8). [minutes] is only set for a week, and only when every
/// counted runtime is known.
class TrackingStats {
  const TrackingStats({this.episodes, this.moviesFinished, this.minutes});

  final int? episodes;
  final int? moviesFinished;
  final int? minutes;
}

/// What the title page knows when someone starts tracking a title that has no cache row yet.
class TrackingStartRequest {
  const TrackingStartRequest({
    required this.titleId,
    required this.mediaType,
    required this.title,
    this.posterPath,
    this.backdropPath,
    this.titleStatus,
    this.runtimeMinutes,
    this.seasons = const [],
    this.place,
    this.rewatch = false,
  });

  final int titleId;
  final String mediaType;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final String? titleStatus;
  final int? runtimeMinutes;
  final List<SeasonInfo> seasons;

  /// The last episode already watched ("I'm partway through"); null starts from the beginning.
  final EpisodeRef? place;
  final bool rewatch;
}

/// Local-first watch tracking (features/11 §9.2). Writes update the Drift [TrackingCache] first,
/// then append a [PendingMutations] row that the sync engine replays to the §6.2 RPCs. Payloads
/// carry absolute places, so replays converge on the last write.
abstract interface class TrackingRepository {
  Stream<List<TrackingItem>> watchAll();
  Stream<TrackingItem?> watchOne(int titleId, String mediaType);
  Future<TrackingItem?> getOne(int titleId, String mediaType);

  /// Pulls `get_my_tracking` into the cache, keeping rows that still have pending mutations.
  Future<void> hydrate();

  /// The progress model's view of a series: its seasons plus every cached episode.
  Future<ShowSchedule> scheduleFor(TrackingItem item);

  /// A season's episodes from the cache, fetched through `tmdb-season` when missing or older
  /// than [maxAge]. Falls back to the cache when offline.
  Future<List<EpisodeInfo>> loadSeason(int titleId, int season, {Duration maxAge = const Duration(days: 7)});

  Future<TrackingWatchers> watchers(int titleId, String mediaType);
  Future<TrackingStats> stats(String mediaType, {int? year});

  Future<TrackingItem> start(TrackingStartRequest request);

  /// Moves a series' place (forward, back, or [place] null for the very beginning).
  Future<TrackingItem> setPlace(TrackingItem item, EpisodeRef? place);

  /// Logs a rewatch of one episode without moving the place.
  Future<void> logRewatch(TrackingItem item, EpisodeRef episode);

  /// A movie → finished; a series → its last aired episode.
  Future<TrackingItem> finish(TrackingItem item);
  Future<void> stop(TrackingItem item);

  /// Graveyard "Revive": tracks again from [request]'s place (the drop point).
  Future<TrackingItem> revive(TrackingStartRequest request);
}

class LocalFirstTrackingRepository implements TrackingRepository {
  LocalFirstTrackingRepository(this._db, this._client, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final SupabaseClient _client;
  final DateTime Function() _clock;

  TrackingCacheDao get _cache => _db.trackingCacheDao;

  DateTime get _today {
    final n = _clock();
    return DateTime(n.year, n.month, n.day);
  }

  // --- reads ---

  /// The caller's canon is in Drift too, so a title ranked on this device is ranked here at once,
  /// without waiting for the next `get_my_tracking` (features/11 §2.3). Either table changing
  /// re-emits.
  @override
  Stream<List<TrackingItem>> watchAll() {
    late final StreamController<List<TrackingItem>> controller;
    StreamSubscription<List<TrackingCacheData>>? rowsSub;
    StreamSubscription<List<LocalRanking>>? ranksSub;
    List<TrackingCacheData>? rows;
    Map<(int, String), LocalRanking>? ranks;
    void emit() {
      final r = rows, k = ranks;
      if (r != null && k != null && !controller.isClosed) {
        controller.add([for (final row in r) _fromRow(row, rank: k[(row.titleId, row.mediaType)])]);
      }
    }

    controller = StreamController<List<TrackingItem>>(
      onListen: () {
        rowsSub = _cache.watchAll().listen((v) {
          rows = v;
          emit();
        }, onError: controller.addError);
        ranksSub = _db.localRankingDao.watchAll().listen((v) {
          ranks = {for (final k in v) (k.showId, k.mediaType): k};
          emit();
        }, onError: controller.addError);
      },
      // Not awaited: Drift finishes a cancel on a later timer, and nothing here depends on it.
      onCancel: () {
        unawaited(rowsSub?.cancel());
        unawaited(ranksSub?.cancel());
      },
    );
    return controller.stream;
  }

  @override
  Stream<TrackingItem?> watchOne(int titleId, String mediaType) =>
      watchAll().map((all) {
        for (final i in all) {
          if (i.titleId == titleId && i.mediaType == mediaType) return i;
        }
        return null;
      });

  @override
  Future<TrackingItem?> getOne(int titleId, String mediaType) async {
    final row = await _cache.getOne(titleId, mediaType);
    if (row == null) return null;
    final rank = await (_db.select(_db.localRankings)
          ..where((t) => t.showId.equals(titleId) & t.mediaType.equals(mediaType)))
        .getSingleOrNull();
    return _fromRow(row, rank: rank);
  }

  @override
  Future<void> hydrate() async {
    final raw = await _client.rpc('get_my_tracking');
    final items = [
      for (final i in ((raw as Map<String, dynamic>)['items'] as List? ?? const []))
        TrackingItem.fromServerJson(i as Map<String, dynamic>),
    ];
    final keep = <(int, String)>{};
    for (final m in await _db.pendingMutationDao.getAllFifo()) {
      if (!_trackingKinds.contains(m.kind)) continue;
      final p = jsonDecode(m.payload) as Map<String, dynamic>;
      if (p['title_id'] is int && p['media_type'] is String) keep.add((p['title_id'] as int, p['media_type'] as String));
    }
    await _cache.replaceSynced([for (final i in items) _toCompanion(i, 'SYNCED')], keep);
  }

  @override
  Future<ShowSchedule> scheduleFor(TrackingItem item) async {
    final episodes = <int, List<EpisodeInfo>>{};
    for (final row in await _db.episodeCacheDao.readTitle(item.titleId)) {
      episodes[row.seasonNumber] = _decodeSeason(item.titleId, row.seasonNumber, row.json);
    }
    return item.schedule(episodes: episodes);
  }

  @override
  Future<List<EpisodeInfo>> loadSeason(int titleId, int season, {Duration maxAge = const Duration(days: 7)}) async {
    final cached = await _db.episodeCacheDao.read(titleId, season);
    final fresh = cached != null && _clock().difference(cached.fetchedAt) < maxAge;
    if (fresh) return _decodeSeason(titleId, season, cached.json);
    try {
      final response = await _client.functions.invoke(
        'tmdb-season',
        method: HttpMethod.get,
        queryParameters: {'id': '$titleId', 'season': '$season'},
      );
      final episodes = (response.data as Map<String, dynamic>)['episodes'] as List? ?? const [];
      final json = jsonEncode(episodes);
      await _db.episodeCacheDao.write(titleId, season, json, _clock());
      return _decodeSeason(titleId, season, json);
    } catch (_) {
      // Offline or TMDB trouble: stale episodes beat none, and "Episode 6" is the last fallback.
      return cached == null ? const [] : _decodeSeason(titleId, season, cached.json);
    }
  }

  @override
  Future<TrackingWatchers> watchers(int titleId, String mediaType) async {
    final rows = await _client.rpc('get_title_watchers', params: {'p_title_id': titleId, 'p_media_type': mediaType});
    final list = (rows as List? ?? const []).cast<Map<String, dynamic>>();
    return TrackingWatchers(
      watchers: [
        for (final r in list)
          TrackingWatcher(
            userId: r['watcher_id'] as String,
            username: r['username'] as String?,
            displayName: r['display_name'] as String?,
            avatarUrl: r['avatar_url'] as String?,
          ),
      ],
      total: list.isEmpty ? 0 : (list.first['total_watchers'] as num).toInt(),
    );
  }

  @override
  Future<TrackingStats> stats(String mediaType, {int? year}) async {
    final raw = await _client.rpc('get_tracking_stats', params: {
      'p_media_type': mediaType,
      if (year != null) 'p_year': year,
    }) as Map<String, dynamic>;
    return TrackingStats(
      episodes: (raw['episodes'] as num?)?.toInt(),
      moviesFinished: (raw['movies_finished'] as num?)?.toInt(),
      minutes: (raw['minutes'] as num?)?.toInt(),
    );
  }

  // --- writes ---

  @override
  Future<TrackingItem> start(TrackingStartRequest request) async {
    final now = _clock();
    final existing = await getOne(request.titleId, request.mediaType);
    // Starting a tracked title again changes nothing, except "Watch again" on a finished one.
    if (existing != null && !(request.rewatch && existing.state == TrackingState.finished)) return existing;

    final isMovie = request.mediaType == 'movie';
    final base = existing ??
        TrackingItem(
          titleId: request.titleId,
          mediaType: request.mediaType,
          title: request.title,
          posterPath: request.posterPath,
          backdropPath: request.backdropPath,
          titleStatus: request.titleStatus,
          runtimeMinutes: request.runtimeMinutes,
          state: TrackingState.watching,
          startedAt: now,
          lastProgressAt: now,
          seasons: request.seasons,
          isRewatch: request.rewatch,
        );
    final started = isMovie
        ? base.copyWith(
            state: TrackingState.watching,
            clearFinishedAt: true,
            isRewatch: request.rewatch,
            startedAt: now,
            lastProgressAt: now,
            pending: true)
        : _moved(base, request.place, now, await scheduleFor(base), startedAt: now, isRewatch: request.rewatch);
    await _db.transaction(() async {
      await _cache.upsert(_toCompanion(started, 'PENDING'));
      await _db.pendingMutationDao.enqueue(MutationKind.trackingStart, {
        'title_id': request.titleId,
        'media_type': request.mediaType,
        'last_season': started.place?.season,
        'last_episode': started.place?.episode,
        'rewatch': request.rewatch,
      });
      // Starting removes the title from the Queue (features/11 §4.10).
      await (_db.delete(_db.watchlistCache)
            ..where((t) => t.titleId.equals(request.titleId) & t.mediaType.equals(request.mediaType)))
          .go();
    });
    return started;
  }

  @override
  Future<TrackingItem> setPlace(TrackingItem item, EpisodeRef? place) async {
    final moved = _moved(item, place, _clock(), await scheduleFor(item));
    await _db.transaction(() async {
      await _cache.upsert(_toCompanion(moved, 'PENDING'));
      await _db.pendingMutationDao.enqueue(MutationKind.trackingPlace, {
        'title_id': item.titleId,
        'media_type': item.mediaType,
        'last_season': moved.place?.season,
        'last_episode': moved.place?.episode,
      });
    });
    return moved;
  }

  @override
  Future<void> logRewatch(TrackingItem item, EpisodeRef episode) => _db.transaction(() async {
        await _cache.upsert(_toCompanion(item.copyWith(lastProgressAt: _clock(), pending: true), 'PENDING'));
        await _db.pendingMutationDao.enqueue(MutationKind.trackingRewatch, {
          'title_id': item.titleId,
          'media_type': 'tv',
          'season': episode.season,
          'episode': episode.episode,
        });
      });

  @override
  Future<TrackingItem> finish(TrackingItem item) async {
    final now = _clock();
    final TrackingItem done;
    if (item.isMovie) {
      done = item.copyWith(state: TrackingState.finished, finishedAt: item.finishedAt ?? now, lastProgressAt: now, pending: true);
    } else {
      final schedule = await scheduleFor(item);
      final last = TrackingProgress.lastAired(schedule, _today) ?? item.lastAired;
      done = _moved(item, last ?? item.place, now, schedule);
    }
    await _db.transaction(() async {
      await _cache.upsert(_toCompanion(done, 'PENDING'));
      await _db.pendingMutationDao.enqueue(MutationKind.trackingFinish, {
        'title_id': item.titleId,
        'media_type': item.mediaType,
      });
    });
    return done;
  }

  @override
  Future<void> stop(TrackingItem item) => _db.transaction(() async {
        await _cache.remove(item.titleId, item.mediaType);
        await _db.pendingMutationDao.enqueue(MutationKind.trackingStop, {
          'title_id': item.titleId,
          'media_type': item.mediaType,
        });
      });

  @override
  Future<TrackingItem> revive(TrackingStartRequest request) async {
    final now = _clock();
    final base = TrackingItem(
      titleId: request.titleId,
      mediaType: 'tv',
      title: request.title,
      posterPath: request.posterPath,
      backdropPath: request.backdropPath,
      titleStatus: request.titleStatus,
      runtimeMinutes: request.runtimeMinutes,
      state: TrackingState.watching,
      startedAt: now,
      lastProgressAt: now,
      seasons: request.seasons,
    );
    final revived = _moved(base, request.place, now, await scheduleFor(base));
    await _db.transaction(() async {
      await _cache.upsert(_toCompanion(revived, 'PENDING'));
      await _db.pendingMutationDao.enqueue(MutationKind.trackingRevive, {
        'title_id': request.titleId,
        'media_type': 'tv',
      });
    });
    return revived;
  }

  // --- the optimistic model (mirrors `_tracking_move`, features/11 §3, §6.2) ---

  TrackingItem _moved(
    TrackingItem item,
    EpisodeRef? to,
    DateTime now,
    ShowSchedule schedule, {
    DateTime? startedAt,
    bool? isRewatch,
  }) {
    final today = _today;
    final place = TrackingProgress.clamp(schedule, to);
    final state = TrackingProgress.seriesState(schedule, place, today);
    final forward = TrackingProgress.watchedCount(schedule, place) > TrackingProgress.watchedCount(schedule, item.place);
    final next = TrackingProgress.next(schedule, place, today);
    final info = next == null ? null : schedule.episode(next);
    return TrackingItem(
      titleId: item.titleId,
      mediaType: item.mediaType,
      title: item.title,
      posterPath: item.posterPath,
      backdropPath: item.backdropPath,
      titleStatus: item.titleStatus,
      runtimeMinutes: item.runtimeMinutes,
      place: place,
      state: state,
      isRewatch: isRewatch ?? item.isRewatch,
      newEpisodesSince: forward ? null : item.newEpisodesSince,
      startedAt: startedAt ?? item.startedAt,
      lastProgressAt: now,
      finishedAt: state != TrackingState.finished
          ? null
          : (item.state == TrackingState.finished ? (item.finishedAt ?? now) : now),
      seasons: item.seasons,
      watched: TrackingProgress.watchedCount(schedule, place),
      airedTotal: item.airedTotal,
      nextEpisode: next == null
          ? null
          : NextEpisode(
              ref: next,
              name: info?.name,
              stillPath: info?.stillPath,
              airDate: info?.airDate,
              runtimeMinutes: info?.runtimeMinutes,
            ),
      lastAired: item.lastAired,
      isRanked: item.isRanked,
      rankPosition: item.rankPosition,
      score: item.score,
      pending: true,
    );
  }

  // --- mapping ---

  static const _trackingKinds = {
    MutationKind.trackingStart,
    MutationKind.trackingPlace,
    MutationKind.trackingRewatch,
    MutationKind.trackingFinish,
    MutationKind.trackingStop,
    MutationKind.trackingRevive,
  };

  List<EpisodeInfo> _decodeSeason(int titleId, int season, String json) => [
        for (final e in jsonDecode(json) as List)
          EpisodeInfo(
            season: season,
            episode: (e as Map)['episode_number'] as int,
            name: e['name'] as String?,
            overview: e['overview'] as String?,
            stillPath: e['still_path'] as String?,
            airDate: DateTime.tryParse(e['air_date'] as String? ?? ''),
            runtimeMinutes: e['runtime_minutes'] as int?,
          ),
      ];

  /// [rank] is the local canon's row for the title, which decides *ranked* over the server's flag.
  TrackingItem _fromRow(TrackingCacheData r, {LocalRanking? rank}) {
    final seasons = r.seasons == null ? const [] : jsonDecode(r.seasons!) as List;
    final next = r.nextEpisode == null ? null : jsonDecode(r.nextEpisode!) as Map<String, dynamic>;
    final last = r.lastAired == null ? null : jsonDecode(r.lastAired!) as Map<String, dynamic>;
    return TrackingItem(
      titleId: r.titleId,
      mediaType: r.mediaType,
      title: r.title,
      posterPath: r.posterPath,
      backdropPath: r.backdropPath,
      titleStatus: r.titleStatus,
      runtimeMinutes: r.runtimeMinutes,
      place: r.lastSeason == null || r.lastEpisode == null ? null : EpisodeRef(r.lastSeason!, r.lastEpisode!),
      state: TrackingState.fromDb(r.state),
      isRewatch: r.isRewatch,
      newEpisodesSince: r.newEpisodesSince,
      startedAt: r.startedAt,
      lastProgressAt: r.lastProgressAt,
      finishedAt: r.finishedAt,
      seasons: [
        for (final s in seasons)
          SeasonInfo(
            number: (s as Map)['number'] as int,
            episodeCount: s['episode_count'] as int,
            airDate: DateTime.tryParse(s['air_date'] as String? ?? ''),
          ),
      ],
      watched: r.watched,
      airedTotal: r.airedTotal,
      nextEpisode: next == null ? null : NextEpisode.fromJson(next),
      lastAired: last == null ? null : EpisodeRef(last['season'] as int, last['episode'] as int),
      isRanked: r.ranked || rank != null,
      rankPosition: rank?.rankPosition ?? r.rankPosition,
      score: rank?.calculatedScore ?? r.score,
      pending: r.syncStatus == 'PENDING',
    );
  }

  TrackingCacheCompanion _toCompanion(TrackingItem i, String syncStatus) => TrackingCacheCompanion.insert(
        titleId: i.titleId,
        mediaType: i.mediaType,
        title: i.title,
        posterPath: Value(i.posterPath),
        backdropPath: Value(i.backdropPath),
        titleStatus: Value(i.titleStatus),
        runtimeMinutes: Value(i.runtimeMinutes),
        lastSeason: Value(i.place?.season),
        lastEpisode: Value(i.place?.episode),
        state: Value(i.state.dbValue),
        isRewatch: Value(i.isRewatch),
        newEpisodesSince: Value(i.newEpisodesSince),
        startedAt: Value(i.startedAt),
        lastProgressAt: Value(i.lastProgressAt),
        finishedAt: Value(i.finishedAt),
        seasons: Value(i.seasonsJson),
        watched: Value(i.watched),
        airedTotal: Value(i.airedTotal),
        nextEpisode: Value(i.nextEpisodeJson),
        lastAired: Value(i.lastAiredJson),
        ranked: Value(i.isRanked),
        rankPosition: Value(i.rankPosition),
        score: Value(i.score),
        syncStatus: Value(syncStatus),
      );
}

final trackingRepositoryProvider = Provider<TrackingRepository>((ref) {
  return LocalFirstTrackingRepository(ref.watch(databaseProvider), ref.watch(supabaseClientProvider));
});
