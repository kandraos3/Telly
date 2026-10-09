import 'dart:convert';

import 'tracking_group.dart';
import 'tracking_models.dart';

/// The next episode to watch, with what the Next episode card shows (features/11 §5.2).
class NextEpisode {
  const NextEpisode({
    required this.ref,
    this.name,
    this.stillPath,
    this.airDate,
    this.runtimeMinutes,
  });

  final EpisodeRef ref;
  final String? name;
  final String? stillPath;
  final DateTime? airDate;
  final int? runtimeMinutes;

  factory NextEpisode.fromJson(Map<String, dynamic> json) => NextEpisode(
        ref: EpisodeRef(json['season'] as int, json['episode'] as int),
        name: json['name'] as String?,
        stillPath: json['still_path'] as String?,
        airDate: DateTime.tryParse(json['air_date'] as String? ?? ''),
        runtimeMinutes: json['runtime_minutes'] as int?,
      );

  Map<String, Object?> toJson() => {
        'season': ref.season,
        'episode': ref.episode,
        'name': name,
        'still_path': stillPath,
        'air_date': airDate?.toIso8601String().substring(0, 10),
        'runtime_minutes': runtimeMinutes,
      };
}

/// One tracked title as the app shows it: the `user_tracking` row plus the display fields of
/// `get_my_tracking` (features/11 §6.3). Movies carry no place, seasons or counts.
class TrackingItem {
  const TrackingItem({
    required this.titleId,
    required this.mediaType,
    required this.title,
    required this.state,
    required this.startedAt,
    required this.lastProgressAt,
    this.posterPath,
    this.backdropPath,
    this.titleStatus,
    this.runtimeMinutes,
    this.place,
    this.isRewatch = false,
    this.newEpisodesSince,
    this.finishedAt,
    this.seasons = const [],
    this.watched,
    this.airedTotal,
    this.nextEpisode,
    this.lastAired,
    this.isRanked = false,
    this.rankPosition,
    this.score,
    this.pending = false,
  });

  final int titleId;
  final String mediaType;
  final String title;
  final String? posterPath;
  final String? backdropPath;

  /// TMDB `status` of the title ("Ended", "Returning Series", …).
  final String? titleStatus;
  final int? runtimeMinutes;

  /// The last episode watched; null for a movie and for a series not yet started.
  final EpisodeRef? place;
  final TrackingState state;
  final bool isRewatch;
  final DateTime? newEpisodesSince;
  final DateTime startedAt;
  final DateTime lastProgressAt;
  final DateTime? finishedAt;

  /// Seasons ≥ 1 (series only).
  final List<SeasonInfo> seasons;
  final int? watched;
  final int? airedTotal;
  final NextEpisode? nextEpisode;
  final EpisodeRef? lastAired;
  final bool isRanked;
  final int? rankPosition;
  final double? score;

  /// Local changes not yet confirmed by the server.
  final bool pending;

  bool get isMovie => mediaType == 'movie';

  /// §3.4: 0–1. Movies have no bar.
  double get progress {
    final total = airedTotal;
    if (isMovie || total == null) return 0;
    if (total == 0) return state == TrackingState.watching ? 0 : 1;
    return ((watched ?? 0) / total).clamp(0.0, 1.0);
  }

  /// Episodes left to watch among those aired (§3.4).
  int? get episodesLeft => isMovie || airedTotal == null ? null : (airedTotal! - (watched ?? 0)).clamp(0, airedTotal!);

  TrackingGroupInput get groupInput => TrackingGroupInput(
        mediaType: mediaType,
        state: state,
        lastProgressAt: lastProgressAt,
        newEpisodesSince: newEpisodesSince,
        finishedAt: finishedAt,
        isRanked: isRanked,
      );

  /// §2.3, or null when the title is a finished, ranked one that has left the groups.
  TrackingGroup? group(DateTime now) => TrackingGrouping.groupFor(groupInput, now);

  /// The progress model's view of this series, from the seasons the server sent and any cached
  /// [episodes] (by season). Used for optimistic moves; the server's answer replaces it.
  ShowSchedule schedule({Map<int, List<EpisodeInfo>> episodes = const {}}) =>
      ShowSchedule(seasons: seasons, episodes: episodes, status: titleStatus);

  TrackingItem copyWith({
    EpisodeRef? place,
    bool clearPlace = false,
    TrackingState? state,
    bool? isRewatch,
    DateTime? newEpisodesSince,
    bool clearNewEpisodes = false,
    DateTime? startedAt,
    DateTime? lastProgressAt,
    DateTime? finishedAt,
    bool clearFinishedAt = false,
    int? watched,
    NextEpisode? nextEpisode,
    bool clearNextEpisode = false,
    bool? pending,
  }) =>
      TrackingItem(
        titleId: titleId,
        mediaType: mediaType,
        title: title,
        posterPath: posterPath,
        backdropPath: backdropPath,
        titleStatus: titleStatus,
        runtimeMinutes: runtimeMinutes,
        place: clearPlace ? null : (place ?? this.place),
        state: state ?? this.state,
        isRewatch: isRewatch ?? this.isRewatch,
        newEpisodesSince: clearNewEpisodes ? null : (newEpisodesSince ?? this.newEpisodesSince),
        startedAt: startedAt ?? this.startedAt,
        lastProgressAt: lastProgressAt ?? this.lastProgressAt,
        finishedAt: clearFinishedAt ? null : (finishedAt ?? this.finishedAt),
        seasons: seasons,
        watched: watched ?? this.watched,
        airedTotal: airedTotal,
        nextEpisode: clearNextEpisode ? null : (nextEpisode ?? this.nextEpisode),
        lastAired: lastAired,
        isRanked: isRanked,
        rankPosition: rankPosition,
        score: score,
        pending: pending ?? this.pending,
      );

  /// One element of `get_my_tracking().items`.
  factory TrackingItem.fromServerJson(Map<String, dynamic> json) {
    DateTime? date(Object? v) => v is String ? DateTime.tryParse(v) : null;
    final seasons = json['seasons'] as List?;
    final next = json['next_episode'] as Map<String, dynamic>?;
    final last = json['last_aired'] as Map<String, dynamic>?;
    final lastSeason = json['last_season'] as int?;
    final lastEpisode = json['last_episode'] as int?;
    return TrackingItem(
      titleId: json['title_id'] as int,
      mediaType: json['media_type'] as String,
      title: json['title'] as String? ?? 'Untitled',
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      titleStatus: json['title_status'] as String?,
      runtimeMinutes: json['runtime_minutes'] as int?,
      place: lastSeason == null || lastEpisode == null ? null : EpisodeRef(lastSeason, lastEpisode),
      state: TrackingState.fromDb(json['state'] as String? ?? 'WATCHING'),
      isRewatch: json['is_rewatch'] as bool? ?? false,
      newEpisodesSince: date(json['new_episodes_since']),
      startedAt: date(json['started_at']) ?? DateTime.now(),
      lastProgressAt: date(json['last_progress_at']) ?? DateTime.now(),
      finishedAt: date(json['finished_at']),
      seasons: [
        for (final s in seasons ?? const [])
          SeasonInfo(
            number: (s as Map)['number'] as int,
            episodeCount: s['episode_count'] as int,
            airDate: date(s['air_date']),
          ),
      ],
      watched: json['watched'] as int?,
      airedTotal: json['aired_total'] as int?,
      nextEpisode: next == null ? null : NextEpisode.fromJson(next),
      lastAired: last == null ? null : EpisodeRef(last['season'] as int, last['episode'] as int),
      isRanked: json['ranked'] as bool? ?? false,
      rankPosition: json['rank_position'] as int?,
      score: (json['calculated_score'] as num?)?.toDouble(),
    );
  }

  /// JSON text for the cache columns that hold documents.
  String? get seasonsJson => seasons.isEmpty
      ? null
      : jsonEncode([
          for (final s in seasons)
            {
              'number': s.number,
              'episode_count': s.episodeCount,
              'air_date': s.airDate?.toIso8601String().substring(0, 10),
            },
        ]);

  String? get nextEpisodeJson => nextEpisode == null ? null : jsonEncode(nextEpisode!.toJson());

  String? get lastAiredJson =>
      lastAired == null ? null : jsonEncode({'season': lastAired!.season, 'episode': lastAired!.episode});
}
