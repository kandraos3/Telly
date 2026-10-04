/// "How much did you watch?" — features/02 §2 Step 1, `SCR-09` section 1 (FE-603).
enum WatchStatus {
  // Movies
  firstTime,
  rewatch,

  // Series
  finished,
  upToDate,
  season,
  dropped;

  String get label => switch (this) {
        WatchStatus.firstTime => 'First-Time Watch',
        WatchStatus.rewatch => 'Rewatch',
        WatchStatus.finished => 'Finished Whole Series',
        WatchStatus.upToDate => 'Up to Date (Waiting for Next Season)',
        WatchStatus.season => 'Watched Specific Season',
        WatchStatus.dropped => 'Dropped / Stopped Watching',
      };

  /// Options shown for a title; movies and series never share statuses.
  static List<WatchStatus> optionsFor(String mediaType) =>
      mediaType == 'movie' ? const [firstTime, rewatch] : const [finished, upToDate, season, dropped];

  static WatchStatus defaultFor(String mediaType) => mediaType == 'movie' ? firstTime : finished;
}

extension WatchStatusServer on WatchStatus {
  /// `user_rankings.status` (`watch_status_enum`): partial watches are still WATCHING.
  String get serverStatus => switch (this) {
        WatchStatus.upToDate || WatchStatus.season => 'WATCHING',
        WatchStatus.dropped => 'DROPPED',
        _ => 'COMPLETED',
      };

  bool get isRewatch => this == WatchStatus.rewatch;
}
