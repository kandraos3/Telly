/// Watch tracking value types (#168). Behaviour: `docs/features/11_WATCH_TRACKING_AND_EPISODE_PROGRESS.md`.
library;

/// `user_tracking.state` (`tracking_state_enum`, features/11 §2.2). Movies never use [caughtUp].
enum TrackingState {
  watching('WATCHING'),
  caughtUp('CAUGHT_UP'),
  finished('FINISHED');

  const TrackingState(this.dbValue);

  final String dbValue;

  static TrackingState fromDb(String value) =>
      values.firstWhere((s) => s.dbValue == value, orElse: () => TrackingState.watching);
}

/// One episode of a series, `S2 · E6`. Season 0 (TMDB specials) never appears (features/11 §2.1).
class EpisodeRef implements Comparable<EpisodeRef> {
  const EpisodeRef(this.season, this.episode) : assert(season >= 1 && episode >= 1);

  final int season;
  final int episode;

  /// "S2 · E6".
  String get label => 'S$season · E$episode';

  @override
  int compareTo(EpisodeRef other) =>
      season != other.season ? season.compareTo(other.season) : episode.compareTo(other.episode);

  bool operator <(EpisodeRef other) => compareTo(other) < 0;
  bool operator >(EpisodeRef other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) => other is EpisodeRef && other.season == season && other.episode == episode;

  @override
  int get hashCode => Object.hash(season, episode);

  @override
  String toString() => label;
}

/// A season from `tv_seasons` (season 0 is dropped before it gets here).
class SeasonInfo {
  const SeasonInfo({required this.number, required this.episodeCount, this.airDate});

  final int number;
  final int episodeCount;
  final DateTime? airDate;
}

/// An episode from the `tv_episodes` cache. Only [airDate] matters to the progress model.
class EpisodeInfo {
  const EpisodeInfo({
    required this.season,
    required this.episode,
    this.airDate,
    this.name,
    this.overview,
    this.stillPath,
    this.runtimeMinutes,
  });

  final int season;
  final int episode;
  final DateTime? airDate;
  final String? name;
  final String? overview;
  final String? stillPath;
  final int? runtimeMinutes;

  EpisodeRef get ref => EpisodeRef(season, episode);
}

/// Everything the progress model knows about a series' episodes (features/11 §3).
class ShowSchedule {
  ShowSchedule({required List<SeasonInfo> seasons, Map<int, List<EpisodeInfo>> episodes = const {}, this.status})
      : seasons = (seasons.where((s) => s.number >= 1).toList()..sort((a, b) => a.number.compareTo(b.number))),
        episodes = {
          for (final e in episodes.entries)
            if (e.key >= 1) e.key: e.value,
        };

  /// Seasons ≥ 1, in order.
  final List<SeasonInfo> seasons;

  /// Cached `tv_episodes` rows by season number. A season missing here uses the season fallback (§3.2).
  final Map<int, List<EpisodeInfo>> episodes;

  /// TMDB `status`, e.g. `Returning Series`, `Ended`.
  final String? status;

  static const _ended = {'Ended', 'Canceled'};
  static const _running = {'Returning Series', 'In Production'};

  bool get hasEnded => _ended.contains(status);
  bool get isRunning => _running.contains(status);

  SeasonInfo? season(int number) {
    for (final s in seasons) {
      if (s.number == number) return s;
    }
    return null;
  }

  int episodeCount(int season) => this.season(season)?.episodeCount ?? 0;

  /// The cached episode, or null when it isn't cached.
  EpisodeInfo? episode(EpisodeRef ref) {
    for (final e in episodes[ref.season] ?? const <EpisodeInfo>[]) {
      if (e.episode == ref.episode) return e;
    }
    return null;
  }
}

/// The two kinds of episode event a move of the place records (features/11 §3.6).
enum TrackingEventKind {
  watched('WATCHED'),
  unwatched('UNWATCHED'),
  rewatched('REWATCHED'),
  finished('FINISHED');

  const TrackingEventKind(this.dbValue);

  final String dbValue;
}

class TrackingEvent {
  const TrackingEvent(this.kind, [this.episode]);

  final TrackingEventKind kind;
  final EpisodeRef? episode;

  @override
  bool operator ==(Object other) => other is TrackingEvent && other.kind == kind && other.episode == episode;

  @override
  int get hashCode => Object.hash(kind, episode);

  @override
  String toString() => '${kind.dbValue}${episode == null ? '' : ' $episode'}';
}
