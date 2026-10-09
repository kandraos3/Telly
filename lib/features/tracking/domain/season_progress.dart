import 'tracking_item.dart';
import 'tracking_models.dart';
import 'tracking_progress.dart';

/// One season of a tracked series as the Seasons section shows it (SCR-08 §T.5, features/11 §5.3).
class SeasonProgress {
  const SeasonProgress({required this.number, required this.watched, required this.aired, required this.total, this.nextAirDate, this.seasonAirDate});

  final int number;

  /// Episodes of this season at or before the place.
  final int watched;

  /// Episodes of this season that have aired.
  final int aired;
  final int total;

  /// The air date of the first episode still to air, when the episode cache knows it.
  final DateTime? nextAirDate;
  final DateTime? seasonAirDate;

  bool get isWatched => total > 0 && watched >= total;
  double get fraction => total == 0 ? 0 : (watched / total).clamp(0.0, 1.0);

  /// Episodes of this season at or before the place, from the place alone.
  static int watchedIn(EpisodeRef? place, SeasonInfo season) {
    if (place == null) return 0;
    if (season.number < place.season) return season.episodeCount;
    if (season.number == place.season) return place.episode.clamp(0, season.episodeCount);
    return 0;
  }

  /// [episodes] are this season's cached rows (empty when not cached: the season fallback applies).
  static SeasonProgress of(TrackingItem item, SeasonInfo season, DateTime today, {List<EpisodeInfo> episodes = const []}) {
    final schedule = item.schedule(episodes: episodes.isEmpty ? const {} : {season.number: episodes});
    var aired = 0;
    DateTime? nextAir;
    for (var e = 1; e <= season.episodeCount; e++) {
      final ref = EpisodeRef(season.number, e);
      if (TrackingProgress.aired(schedule, ref, today)) {
        aired++;
      } else {
        nextAir ??= schedule.episode(ref)?.airDate;
      }
    }
    return SeasonProgress(
      number: season.number,
      watched: watchedIn(item.place, season),
      aired: aired,
      total: season.episodeCount,
      nextAirDate: nextAir,
      seasonAirDate: season.airDate,
    );
  }
}
