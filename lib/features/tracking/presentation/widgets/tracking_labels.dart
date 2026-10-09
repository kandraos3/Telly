import '../../domain/season_progress.dart';
import '../../domain/tracking_item.dart';
import '../../domain/tracking_models.dart';

/// Text the tracking widgets share (SCR-08 §T, features/11 §4.2).
abstract final class TrackingLabels {
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// "Oct 6", or "Oct 6, 2025" outside [now]'s year.
  static String date(DateTime d, DateTime now) =>
      '${_months[d.month - 1]} ${d.day}${d.year == now.year ? '' : ', ${d.year}'}';

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// "Fri, Oct 17".
  static String weekdayDate(DateTime d) => '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';

  /// The trailing text of a season row (SCR-08 §T.5): "watched", "5 of 10", "Not started" or
  /// "Airing · next Fri, Oct 17".
  static String season(SeasonProgress p, DateTime now) {
    if (p.isWatched) return 'watched';
    if (p.aired == 0) {
      final air = p.seasonAirDate;
      return air != null && air.isAfter(now) ? 'Airing · ${date(air, now)}' : 'Not started';
    }
    if (p.aired < p.total && p.watched >= p.aired && p.nextAirDate != null) {
      return 'Airing · next ${weekdayDate(p.nextAirDate!)}';
    }
    return p.watched > 0 ? '${p.watched} of ${p.total}' : 'Not started';
  }

  /// "today", "yesterday", "3 days ago", else the date.
  static String relativeDay(DateTime d, DateTime now) {
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    if (days < 7) return '$days days ago';
    return date(d, now);
  }

  /// §T.1 eyebrow without the leading dot, e.g. "Watching · S2 · E6 next".
  static String eyebrow(TrackingItem item) {
    if (item.isMovie) return item.state == TrackingState.finished ? 'Finished' : 'Watching';
    switch (item.state) {
      case TrackingState.finished:
        return 'Finished';
      case TrackingState.caughtUp:
        return 'Up to date';
      case TrackingState.watching:
        final next = item.nextEpisode?.ref;
        if (item.newEpisodesSince != null) {
          final place = item.place;
          return next != null && place != null && next.season > place.season ? 'New season' : 'New episode';
        }
        return next == null ? 'Watching' : 'Watching · ${next.label} next';
    }
  }

  /// Amber eyebrow: a new season or episode dropped (§T.1, §T.6).
  static bool eyebrowIsAmber(TrackingItem item) =>
      !item.isMovie && item.state == TrackingState.watching && item.newEpisodesSince != null;

  /// "✓ Watched E6", or "✓ Watched S3 · E1" when the next episode starts another season.
  static String watched(EpisodeRef next, EpisodeRef? place) =>
      place != null && next.season != place.season ? '✓ Watched ${next.label}' : '✓ Watched E${next.episode}';

  /// The short form for rows: "✓ E6" or "✓ S3E1".
  static String watchedShort(EpisodeRef next, EpisodeRef? place) =>
      place != null && next.season != place.season ? '✓ S${next.season}E${next.episode}' : '✓ E${next.episode}';

  /// "2 h 46" or "46 min".
  static String runtime(int minutes) =>
      minutes >= 60 ? '${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')}' : '$minutes min';
}
