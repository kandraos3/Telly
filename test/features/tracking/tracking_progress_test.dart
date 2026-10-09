import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/tracking/domain/tracking_models.dart';
import 'package:telly_app/features/tracking/domain/tracking_progress.dart';

/// #224: the progress model against the shared fixture that pgTAP mirrors (#225).
/// features/11 §3.
void main() {
  final fixture =
      jsonDecode(File('test/fixtures/tracking_progress_vectors.json').readAsStringSync()) as Map<String, dynamic>;
  final today = DateTime.parse(fixture['today'] as String);
  final shows = {
    for (final e in (fixture['shows'] as Map<String, dynamic>).entries) e.key: _show(e.value as Map<String, dynamic>),
  };

  group('TrackingProgress: shared vectors', () {
    for (final raw in fixture['vectors'] as List) {
      final v = raw as Map<String, dynamic>;
      test(v['name'] as String, () {
        final show = shows[v['show'] as String]!;
        final rawPlace = _ref(v['place'] as Map<String, dynamic>?);
        // The clamp runs on every write, so the model sees a clamped place (§3.5).
        final place = TrackingProgress.clamp(show, rawPlace);
        if (v.containsKey('clamped_place')) {
          expect(place, _ref(v['clamped_place'] as Map<String, dynamic>?), reason: 'clamped place');
        } else {
          expect(place, rawPlace, reason: 'place should not be clamped');
        }

        expect(TrackingProgress.next(show, place, today), _ref(v['next'] as Map<String, dynamic>?), reason: 'next');
        expect(TrackingProgress.seriesState(show, place, today).dbValue, v['state'], reason: 'state');
        expect(TrackingProgress.watchedCount(show, place), v['watched'], reason: 'watched');
        expect(TrackingProgress.airedTotal(show, today), v['aired_total'], reason: 'aired_total');
        expect(TrackingProgress.progress(show, place, today),
            closeTo((v['progress'] as num).toDouble(), 0.000001),
            reason: 'progress');
      });
    }

    for (final raw in fixture['movie_vectors'] as List) {
      final v = raw as Map<String, dynamic>;
      test('movie: ${v['name']}', () {
        final finishedAt = v['finished_at'] == null ? null : DateTime.parse(v['finished_at'] as String);
        expect(TrackingProgress.movieState(finishedAt: finishedAt).dbValue, v['state']);
      });
    }

    for (final raw in fixture['event_vectors'] as List) {
      final v = raw as Map<String, dynamic>;
      test('events: ${v['name']}', () {
        final show = shows[v['show'] as String]!;
        final events = TrackingProgress.eventsForMove(
          show,
          _ref(v['from'] as Map<String, dynamic>?),
          _ref(v['to'] as Map<String, dynamic>?),
        );
        final expected = [
          for (final e in v['events'] as List)
            TrackingEvent(
              TrackingEventKind.values.firstWhere((k) => k.dbValue == (e as Map)['kind']),
              EpisodeRef((e as Map)['season'] as int, e['episode'] as int),
            ),
        ];
        expect(events, expected);
      });
    }
  });

  group('TrackingProgress: aired', () {
    final show = shows['running_weekly']!;

    test('an episode airing today counts as aired', () {
      expect(TrackingProgress.aired(show, const EpisodeRef(2, 4), today), isTrue);
    });

    test('tomorrow has not aired', () {
      expect(TrackingProgress.aired(show, const EpisodeRef(2, 5), today), isFalse);
    });

    test('an episode beyond the season count never airs', () {
      expect(TrackingProgress.aired(show, const EpisodeRef(2, 11), today), isFalse);
    });

    test('an uncached episode of a cached season is not aired', () {
      // S2 E6-E9 have no rows; they must not fall back to the season's air date.
      expect(TrackingProgress.aired(show, const EpisodeRef(2, 6), today), isFalse);
    });

    test('season 0 is ignored everywhere', () {
      final withSpecials = ShowSchedule(
        seasons: const [SeasonInfo(number: 0, episodeCount: 5), SeasonInfo(number: 1, episodeCount: 3)],
        episodes: {
          0: const [EpisodeInfo(season: 0, episode: 1)],
          1: [EpisodeInfo(season: 1, episode: 1, airDate: DateTime(2026, 1, 1))],
        },
        status: 'Ended',
      );
      expect(withSpecials.seasons.map((s) => s.number), [1]);
      expect(withSpecials.episodes.keys, [1]);
      expect(TrackingProgress.candidateAfter(withSpecials, null), const EpisodeRef(1, 1));
    });
  });

  group('TrackingProgress: progress edges', () {
    test('a show that has not started airing is caught up with a full bar (§3.3, §3.4)', () {
      final show = ShowSchedule(
        seasons: const [SeasonInfo(number: 1, episodeCount: 6)],
        episodes: {
          1: [EpisodeInfo(season: 1, episode: 1, airDate: DateTime(2027, 1, 1))],
        },
        status: 'Returning Series',
      );
      expect(TrackingProgress.airedTotal(show, today), 0);
      expect(TrackingProgress.next(show, null, today), isNull);
      expect(TrackingProgress.seriesState(show, null, today), TrackingState.caughtUp);
      // §3.4: with nothing aired, the bar is full rather than dividing by zero.
      expect(TrackingProgress.progress(show, null, today), 1);
    });

    test('a series with no seasons at all is caught up with a full bar', () {
      final show = ShowSchedule(seasons: const [], status: 'Ended');
      expect(TrackingProgress.candidateAfter(show, null), isNull);
      expect(TrackingProgress.seriesState(show, null, today), TrackingState.finished);
      expect(TrackingProgress.progress(show, null, today), 1);
    });

    test('lastAired finds the final aired episode of a running show', () {
      expect(TrackingProgress.lastAired(shows['running_weekly']!, today), const EpisodeRef(2, 4));
    });

    test('lastAired is null when nothing has aired', () {
      final show = ShowSchedule(
        seasons: const [SeasonInfo(number: 1, episodeCount: 2)],
        episodes: {
          1: [EpisodeInfo(season: 1, episode: 1, airDate: DateTime(2030, 1, 1))],
        },
        status: 'Returning Series',
      );
      expect(TrackingProgress.lastAired(show, today), isNull);
    });
  });

  group('TrackingProgress: events', () {
    test('forward then back nets no change', () {
      final show = shows['ended_two_seasons']!;
      const from = EpisodeRef(2, 5);
      const to = EpisodeRef(2, 6);
      final forward = TrackingProgress.eventsForMove(show, from, to);
      final back = TrackingProgress.eventsForMove(show, to, from);
      expect(forward.single.kind, TrackingEventKind.watched);
      expect(back.single.kind, TrackingEventKind.unwatched);
      expect(back.single.episode, forward.single.episode);
    });

    test('a long jump is capped at 50 events, keeping those nearest the new place', () {
      final show = ShowSchedule(
        seasons: const [SeasonInfo(number: 1, episodeCount: 1100)],
        episodes: const {},
        status: 'Returning Series',
      );
      // No cache and not the latest season of a running show would make nothing aired; use an
      // ended show so the season fallback airs everything.
      final ended = ShowSchedule(
        seasons: show.seasons,
        episodes: const {},
        status: 'Ended',
      );
      final events = TrackingProgress.eventsForMove(ended, null, const EpisodeRef(1, 1000));
      expect(events.length, TrackingProgress.maxEventsPerWrite);
      expect(events.first.episode, const EpisodeRef(1, 951));
      expect(events.last.episode, const EpisodeRef(1, 1000));
    });

    test('a long un-log is capped too, keeping those nearest the new place', () {
      final ended = ShowSchedule(
        seasons: const [SeasonInfo(number: 1, episodeCount: 1100)],
        status: 'Ended',
      );
      final events = TrackingProgress.eventsForMove(ended, const EpisodeRef(1, 1000), null);
      expect(events.length, TrackingProgress.maxEventsPerWrite);
      expect(events.first.episode, const EpisodeRef(1, 1));
      expect(events.last.episode, const EpisodeRef(1, 50));
      expect(events.every((e) => e.kind == TrackingEventKind.unwatched), isTrue);
    });
  });

  group('EpisodeRef', () {
    test('orders by season then episode', () {
      expect(const EpisodeRef(1, 9) < const EpisodeRef(2, 1), isTrue);
      expect(const EpisodeRef(2, 6) > const EpisodeRef(2, 5), isTrue);
      expect(const EpisodeRef(2, 6), const EpisodeRef(2, 6));
    });

    test('labels as S2 · E6', () {
      expect(const EpisodeRef(2, 6).label, 'S2 · E6');
    });
  });
}

/// Expands the fixture's compact episode ranges (`from`..`to`, one air date plus an interval).
ShowSchedule _show(Map<String, dynamic> raw) {
  final episodes = <int, List<EpisodeInfo>>{};
  for (final e in raw['episodes'] as List) {
    final m = e as Map<String, dynamic>;
    final season = m['season'] as int;
    final first = m['first_air_date'] == null ? null : DateTime.parse(m['first_air_date'] as String);
    final interval = m['interval_days'] as int? ?? 7;
    for (var n = m['from'] as int; n <= (m['to'] as int); n++) {
      episodes.putIfAbsent(season, () => []).add(EpisodeInfo(
            season: season,
            episode: n,
            airDate: first?.add(Duration(days: interval * (n - (m['from'] as int)))),
          ));
    }
  }
  return ShowSchedule(
    seasons: [
      for (final s in raw['seasons'] as List)
        SeasonInfo(
          number: (s as Map<String, dynamic>)['number'] as int,
          episodeCount: s['episode_count'] as int,
          airDate: s['air_date'] == null ? null : DateTime.parse(s['air_date'] as String),
        ),
    ],
    episodes: episodes,
    status: raw['status'] as String?,
  );
}

EpisodeRef? _ref(Map<String, dynamic>? raw) =>
    raw == null ? null : EpisodeRef(raw['season'] as int, raw['episode'] as int);
