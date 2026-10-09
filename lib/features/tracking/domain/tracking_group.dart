import 'tracking_models.dart';

/// Hub and Home groups, in the order they are checked and shown
/// (`docs/features/11_WATCH_TRACKING_AND_EPISODE_PROGRESS.md` §2.3).
enum TrackingGroup {
  newEpisodes('NEW EPISODES'),
  inProgress('IN PROGRESS'),
  finishedNotRanked('FINISHED, NOT RANKED'),
  caughtUp('CAUGHT UP'),
  paused('PAUSED');

  const TrackingGroup(this.header);

  /// The section header on `SCR-29`.
  final String header;
}

/// What grouping needs to know about one tracked title.
class TrackingGroupInput {
  const TrackingGroupInput({
    required this.mediaType,
    required this.state,
    required this.lastProgressAt,
    this.newEpisodesSince,
    this.finishedAt,
    this.isRanked = false,
  });

  final String mediaType; // 'movie' or 'tv'
  final TrackingState state;
  final DateTime lastProgressAt;
  final DateTime? newEpisodesSince;
  final DateTime? finishedAt;

  /// Whether the title is in the user's canon for its own media type.
  final bool isRanked;

  bool get isMovie => mediaType == 'movie';
}

abstract final class TrackingGrouping {
  /// §2.3: a series pauses after 30 days without progress, a movie after 7 (§2.5).
  static const seriesPauseDays = 30;
  static const moviePauseDays = 7;

  /// A finished, ranked series stays under *Caught up* this long, then leaves the hub (§2.3).
  static const finishedGraceDays = 14;

  static int pauseDays({required bool isMovie}) => isMovie ? moviePauseDays : seriesPauseDays;

  /// The group for one tracked title, or null when it no longer belongs in the hub's groups
  /// (a finished, ranked title past its grace; it stays in the *Finished* filter).
  static TrackingGroup? groupFor(TrackingGroupInput row, DateTime now) {
    // 1. New episodes. Movies never get them (§2.5), so a stale flag can't strand a movie here.
    if (!row.isMovie && row.newEpisodesSince != null) return TrackingGroup.newEpisodes;

    if (row.state == TrackingState.watching) {
      final idleDays = _days(row.lastProgressAt, now);
      // 2. In progress, 5. Paused.
      return idleDays >= pauseDays(isMovie: row.isMovie) ? TrackingGroup.paused : TrackingGroup.inProgress;
    }

    // 3. Finished, not ranked (both CAUGHT_UP and FINISHED).
    if (!row.isRanked) return TrackingGroup.finishedNotRanked;

    // 4. Caught up: series only. A ranked, finished movie leaves at once (§2.5).
    if (row.isMovie) return null;
    if (row.state == TrackingState.caughtUp) return TrackingGroup.caughtUp;
    final finishedAt = row.finishedAt;
    if (finishedAt == null) return TrackingGroup.caughtUp;
    return _days(finishedAt, now) < finishedGraceDays ? TrackingGroup.caughtUp : null;
  }

  /// Whole days between two instants, floored at 0.
  static int _days(DateTime from, DateTime to) {
    final d = to.difference(from).inDays;
    return d < 0 ? 0 : d;
  }
}
