import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/tracking/domain/tracking_group.dart';
import 'package:telly_app/features/tracking/domain/tracking_models.dart';

/// #224: hub and Home grouping (features/11 §2.3, §2.5).
void main() {
  final fixture =
      jsonDecode(File('test/fixtures/tracking_progress_vectors.json').readAsStringSync()) as Map<String, dynamic>;
  final now = DateTime.parse('${fixture['today']}T20:00:00Z');

  group('TrackingGrouping: shared vectors', () {
    for (final raw in fixture['group_vectors'] as List) {
      final v = raw as Map<String, dynamic>;
      test(v['name'] as String, () {
        final row = TrackingGroupInput(
          mediaType: v['media_type'] as String,
          state: TrackingState.fromDb(v['state'] as String),
          lastProgressAt: now.subtract(Duration(days: v['days_since_progress'] as int)),
          newEpisodesSince: (v['new_episodes'] as bool? ?? false) ? now.subtract(const Duration(hours: 2)) : null,
          finishedAt: v.containsKey('days_since_finished')
              ? now.subtract(Duration(days: v['days_since_finished'] as int))
              : null,
          isRanked: v['is_ranked'] as bool,
        );
        final expected = v['group'] == null
            ? null
            : TrackingGroup.values.firstWhere((g) => g.name == v['group']);
        expect(TrackingGrouping.groupFor(row, now), expected);
      });
    }
  });

  group('TrackingGrouping: windows', () {
    TrackingGroupInput row({
      String mediaType = 'tv',
      TrackingState state = TrackingState.watching,
      int idleDays = 0,
      bool ranked = false,
      int? finishedDaysAgo,
    }) =>
        TrackingGroupInput(
          mediaType: mediaType,
          state: state,
          lastProgressAt: now.subtract(Duration(days: idleDays)),
          finishedAt: finishedDaysAgo == null ? null : now.subtract(Duration(days: finishedDaysAgo)),
          isRanked: ranked,
        );

    test('the pause window is 30 days for series and 7 for movies', () {
      expect(TrackingGrouping.pauseDays(isMovie: false), 30);
      expect(TrackingGrouping.pauseDays(isMovie: true), 7);
    });

    test('a series pauses the day it reaches 30, not before', () {
      expect(TrackingGrouping.groupFor(row(idleDays: 29), now), TrackingGroup.inProgress);
      expect(TrackingGrouping.groupFor(row(idleDays: 30), now), TrackingGroup.paused);
    });

    test('a movie pauses the day it reaches 7, not before', () {
      expect(TrackingGrouping.groupFor(row(mediaType: 'movie', idleDays: 6), now), TrackingGroup.inProgress);
      expect(TrackingGrouping.groupFor(row(mediaType: 'movie', idleDays: 7), now), TrackingGroup.paused);
    });

    test('a finished, ranked series leaves the hub once the grace window ends', () {
      expect(
        TrackingGrouping.groupFor(row(state: TrackingState.finished, ranked: true, finishedDaysAgo: 13), now),
        TrackingGroup.caughtUp,
      );
      expect(
        TrackingGrouping.groupFor(row(state: TrackingState.finished, ranked: true, finishedDaysAgo: 14), now),
        isNull,
      );
    });

    test('a finished, ranked series with no finishedAt stays under Caught up', () {
      expect(
        TrackingGrouping.groupFor(row(state: TrackingState.finished, ranked: true), now),
        TrackingGroup.caughtUp,
      );
    });

    test('an unranked finished title always waits to be ranked', () {
      for (final mediaType in ['tv', 'movie']) {
        expect(
          TrackingGrouping.groupFor(
              row(mediaType: mediaType, state: TrackingState.finished, finishedDaysAgo: 400), now),
          TrackingGroup.finishedNotRanked,
          reason: mediaType,
        );
      }
    });

    test('a clock that runs backwards never pauses a title', () {
      expect(TrackingGrouping.groupFor(row(idleDays: -5), now), TrackingGroup.inProgress);
    });

    test('headers match SCR-29', () {
      expect(TrackingGroup.newEpisodes.header, 'NEW EPISODES');
      expect(TrackingGroup.finishedNotRanked.header, 'FINISHED, NOT RANKED');
    });
  });
}
