import 'tracking_models.dart';

/// The watch tracking progress model: pure functions, mirrored in SQL by `_tracking_state` (#225).
/// Formulas: `docs/features/11_WATCH_TRACKING_AND_EPISODE_PROGRESS.md` §3. Shared vectors:
/// `test/fixtures/tracking_progress_vectors.json`.
abstract final class TrackingProgress {
  /// At most this many episode events per write (§3.6).
  static const maxEventsPerWrite = 50;

  /// §3.2: whether [ref] has aired on [today] (a date in the user's timezone).
  static bool aired(ShowSchedule show, EpisodeRef ref, DateTime today) {
    final season = show.season(ref.season);
    if (season == null || ref.episode > season.episodeCount) return false;
    final cached = show.episodes[ref.season];
    if (cached != null && cached.isNotEmpty) {
      final airDate = show.episode(ref)?.airDate;
      return airDate != null && !_day(airDate).isAfter(_day(today));
    }
    // Season fallback: the season has started, and it isn't the latest season of a running show.
    final seasonAir = season.airDate;
    if (seasonAir == null || _day(seasonAir).isAfter(_day(today))) return false;
    return !(show.isRunning && ref.season == show.seasons.last.number);
  }

  /// The episode after [place] if it exists, whether or not it has aired (§3.1 `candidate`).
  static EpisodeRef? candidateAfter(ShowSchedule show, EpisodeRef? place) {
    if (show.seasons.isEmpty) return null;
    if (place == null) {
      final first = show.seasons.first;
      return first.episodeCount >= 1 ? EpisodeRef(first.number, 1) : null;
    }
    if (place.episode < show.episodeCount(place.season)) return EpisodeRef(place.season, place.episode + 1);
    for (final s in show.seasons) {
      if (s.number > place.season && s.episodeCount >= 1) return EpisodeRef(s.number, 1);
    }
    return null;
  }

  /// §3.1: the next episode to watch, or null when nothing aired follows [place].
  static EpisodeRef? next(ShowSchedule show, EpisodeRef? place, DateTime today) {
    final candidate = candidateAfter(show, place);
    return candidate != null && aired(show, candidate, today) ? candidate : null;
  }

  /// §3.3 for a series.
  static TrackingState seriesState(ShowSchedule show, EpisodeRef? place, DateTime today) {
    if (next(show, place, today) != null) return TrackingState.watching;
    return show.hasEnded ? TrackingState.finished : TrackingState.caughtUp;
  }

  /// §3.3 for a movie: never caught up.
  static TrackingState movieState({required DateTime? finishedAt}) =>
      finishedAt == null ? TrackingState.watching : TrackingState.finished;

  /// §3.4 `watched`: every episode before and including [place].
  static int watchedCount(ShowSchedule show, EpisodeRef? place) => place == null ? 0 : _ordinal(show, place);

  /// §3.4 `aired_total`.
  static int airedTotal(ShowSchedule show, DateTime today) {
    var total = 0;
    for (final s in show.seasons) {
      for (var e = 1; e <= s.episodeCount; e++) {
        if (aired(show, EpisodeRef(s.number, e), today)) total++;
      }
    }
    return total;
  }

  /// §3.4: 0–1. Full when nothing has aired and the series is caught up or finished.
  static double progress(ShowSchedule show, EpisodeRef? place, DateTime today) {
    final total = airedTotal(show, today);
    if (total == 0) return seriesState(show, place, today) == TrackingState.watching ? 0 : 1;
    return (watchedCount(show, place) / total).clamp(0.0, 1.0);
  }

  /// The last aired episode, where `finish_tracking` puts a series' place (§6.2).
  static EpisodeRef? lastAired(ShowSchedule show, DateTime today) {
    for (final s in show.seasons.reversed) {
      for (var e = s.episodeCount; e >= 1; e--) {
        final ref = EpisodeRef(s.number, e);
        if (aired(show, ref, today)) return ref;
      }
    }
    return null;
  }

  /// §3.5: a place past the known episodes moves back to the last known episode of its season,
  /// or of the last season. Null stays null.
  static EpisodeRef? clamp(ShowSchedule show, EpisodeRef? place) {
    if (place == null || show.seasons.isEmpty) return place;
    final season = show.season(place.season);
    if (season != null) {
      if (season.episodeCount < 1) return place;
      return place.episode > season.episodeCount ? EpisodeRef(place.season, season.episodeCount) : place;
    }
    final last = show.seasons.lastWhere((s) => s.episodeCount >= 1, orElse: () => show.seasons.last);
    if (place.season > last.number && last.episodeCount >= 1) return EpisodeRef(last.number, last.episodeCount);
    return place;
  }

  /// §3.6: the events a move from [from] to [to] records. Forward: one `WATCHED` per episode passed
  /// (the [maxEventsPerWrite] nearest [to]). Backward: one `UNWATCHED` per episode un-watched.
  /// Starting partway records nothing, so callers don't call this for `start_tracking`.
  static List<TrackingEvent> eventsForMove(ShowSchedule show, EpisodeRef? from, EpisodeRef? to) {
    final a = from == null ? 0 : _ordinal(show, from);
    final b = to == null ? 0 : _ordinal(show, to);
    if (a == b) return const [];
    final forward = b > a;
    final lo = forward ? a + 1 : b + 1;
    final hi = forward ? b : a;
    final kind = forward ? TrackingEventKind.watched : TrackingEventKind.unwatched;
    final start = forward ? (hi - maxEventsPerWrite + 1).clamp(lo, hi) : lo;
    final end = forward ? hi : (lo + maxEventsPerWrite - 1).clamp(lo, hi);
    return [for (var i = start; i <= end; i++) TrackingEvent(kind, _atOrdinal(show, i))];
  }

  /// 1-based position of [ref] across seasons ≥ 1 (S1 E1 = 1). Episodes past a season's count
  /// count as that season's last.
  static int _ordinal(ShowSchedule show, EpisodeRef ref) {
    var n = 0;
    for (final s in show.seasons) {
      if (s.number < ref.season) {
        n += s.episodeCount;
      } else if (s.number == ref.season) {
        n += ref.episode.clamp(0, s.episodeCount);
      }
    }
    return n;
  }

  static EpisodeRef _atOrdinal(ShowSchedule show, int ordinal) {
    var left = ordinal;
    for (final s in show.seasons) {
      if (left <= s.episodeCount) return EpisodeRef(s.number, left);
      left -= s.episodeCount;
    }
    throw RangeError.value(ordinal, 'ordinal');
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}
