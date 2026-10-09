import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/tracking/domain/season_progress.dart';
import 'package:telly_app/features/tracking/domain/tracking_item.dart';
import 'package:telly_app/features/tracking/domain/tracking_models.dart';
import 'package:telly_app/features/tracking/presentation/widgets/tracking_labels.dart';

// SCR-08 §T.5: what a season row says about your progress.
void main() {
  final now = DateTime(2026, 10, 9, 12);
  final seasons = [
    SeasonInfo(number: 1, episodeCount: 10, airDate: DateTime(2022)),
    SeasonInfo(number: 2, episodeCount: 8, airDate: DateTime(2023)),
    SeasonInfo(number: 3, episodeCount: 6, airDate: DateTime(2027, 3, 1)),
  ];

  TrackingItem item({EpisodeRef? place, String status = 'Returning Series'}) => TrackingItem(
        titleId: 1,
        mediaType: 'tv',
        title: 'Show',
        state: TrackingState.watching,
        startedAt: now,
        lastProgressAt: now,
        seasons: seasons,
        titleStatus: status,
        place: place,
      );

  SeasonProgress of(TrackingItem i, int season, {List<EpisodeInfo> episodes = const []}) =>
      SeasonProgress.of(i, seasons[season - 1], now, episodes: episodes);

  group('watchedIn', () {
    test('counts the whole season before the place, up to the place in it, and nothing after', () {
      const place = EpisodeRef(2, 3);
      expect(SeasonProgress.watchedIn(place, seasons[0]), 10);
      expect(SeasonProgress.watchedIn(place, seasons[1]), 3);
      expect(SeasonProgress.watchedIn(place, seasons[2]), 0);
      expect(SeasonProgress.watchedIn(null, seasons[0]), 0);
    });

    test('a place past the season end is clamped', () {
      expect(SeasonProgress.watchedIn(const EpisodeRef(1, 99), seasons[0]), 10);
    });
  });

  group('trailing text', () {
    test('watched, "5 of 10" and Not started', () {
      final i = item(place: const EpisodeRef(2, 3));
      expect(TrackingLabels.season(of(i, 1), now), 'watched');
      expect(TrackingLabels.season(of(i, 2), now), '3 of 8');
      expect(TrackingLabels.season(of(item(place: const EpisodeRef(1, 1)), 2), now), 'Not started');
    });

    test('an announced season shows its date, a dateless one says Not started', () {
      expect(TrackingLabels.season(of(item(place: const EpisodeRef(2, 8)), 3), now), 'Airing · Mar 1, 2027');
      final undated = SeasonProgress.of(
        item(),
        const SeasonInfo(number: 4, episodeCount: 4),
        now,
      );
      expect(TrackingLabels.season(undated, now), 'Not started');
    });

    test('the airing season names its next episode when the cache knows it', () {
      final episodes = List.generate(
        8,
        (i) => EpisodeInfo(season: 2, episode: i + 1, airDate: DateTime(2026, 9, 19).add(Duration(days: 7 * i))),
      );
      final caughtUp = item(place: const EpisodeRef(2, 3));
      final p = of(caughtUp, 2, episodes: episodes);
      expect(p.aired, 3, reason: 'E4 airs Oct 10');
      expect(TrackingLabels.season(p, now), 'Airing · next Sat, Oct 10');
    });
  });

  test('fraction and the watched flag follow the counts', () {
    final p = of(item(place: const EpisodeRef(1, 5)), 1);
    expect(p.fraction, 0.5);
    expect(p.isWatched, isFalse);
    expect(of(item(place: const EpisodeRef(1, 10)), 1).isWatched, isTrue);
    expect(of(item(), 1).fraction, 0);
  });
}
