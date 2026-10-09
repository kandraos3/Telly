import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/tracking/domain/tracking_group.dart';
import 'package:telly_app/features/tracking/domain/tracking_hub.dart';
import 'package:telly_app/features/tracking/domain/tracking_item.dart';
import 'package:telly_app/features/tracking/domain/tracking_models.dart';
import 'package:telly_app/features/tracking/presentation/widgets/tracking_labels.dart';

// SCR-29 / features/11 §2.3, §9.5: what the hub groups, counts, sorts and says.
void main() {
  final now = DateTime(2026, 10, 9, 12);
  DateTime ago(int days) => now.subtract(Duration(days: days));

  TrackingItem series(
    String title, {
    TrackingState state = TrackingState.watching,
    int idle = 1,
    int? left,
    EpisodeRef? next = const EpisodeRef(1, 2),
    EpisodeRef? place = const EpisodeRef(1, 1),
    bool ranked = false,
    DateTime? newSince,
    DateTime? finishedAt,
    int? rank,
  }) =>
      TrackingItem(
        titleId: title.hashCode,
        mediaType: 'tv',
        title: title,
        state: state,
        startedAt: ago(100),
        lastProgressAt: ago(idle),
        place: place,
        newEpisodesSince: newSince,
        finishedAt: finishedAt,
        isRanked: ranked,
        rankPosition: rank,
        airedTotal: left == null ? null : 10,
        watched: left == null ? null : 10 - left,
        nextEpisode: next == null ? null : NextEpisode(ref: next, name: 'Attila'),
      );

  TrackingItem movie(String title, {TrackingState state = TrackingState.watching, int idle = 1, bool ranked = false, DateTime? finishedAt}) =>
      TrackingItem(
        titleId: title.hashCode,
        mediaType: 'movie',
        title: title,
        state: state,
        startedAt: ago(idle),
        lastProgressAt: ago(idle),
        isRanked: ranked,
        finishedAt: finishedAt,
        runtimeMinutes: 166,
      );

  group('counts', () {
    test('All, Series and Movies count grouped titles and never mix canons', () {
      final hub = TrackingHub([
        series('A'),
        series('B', newSince: ago(1)),
        movie('M'),
        series('Gone', state: TrackingState.finished, ranked: true, finishedAt: ago(30)),
      ], now);
      expect(hub.count(WatchingFilter.all), 3, reason: 'a finished, ranked show past 14 days has left the groups');
      expect(hub.count(WatchingFilter.tv), 2);
      expect(hub.count(WatchingFilter.movie), 1);
      expect(hub.count(WatchingFilter.finished), 1, reason: 'but it stays in the history');
    });

    test('isEmpty means nothing is tracked at all', () {
      expect(TrackingHub(const [], now).isEmpty, isTrue);
      expect(TrackingHub([series('A')], now).isEmpty, isFalse);
    });
  });

  group('groups', () {
    test('follow the §2.3 order and omit empty ones', () {
      final hub = TrackingHub([
        series('paused', idle: 40),
        series('caught', state: TrackingState.caughtUp, ranked: true, next: null),
        series('unranked', state: TrackingState.caughtUp, next: null),
        series('progress'),
        series('new', newSince: ago(1)),
      ], now);
      expect(
        hub.groups(WatchingFilter.all, WatchingSort.recent).map((g) => g.group).toList(),
        [TrackingGroup.newEpisodes, TrackingGroup.inProgress, TrackingGroup.finishedNotRanked, TrackingGroup.caughtUp, TrackingGroup.paused],
      );
      expect(hub.groups(WatchingFilter.all, WatchingSort.recent).every((g) => g.items.isNotEmpty), isTrue);
    });

    test('the Movies chip lists movies only, the Series chip series only', () {
      final hub = TrackingHub([series('S'), movie('M'), movie('Slow', idle: 9)], now);
      final movies = hub.groups(WatchingFilter.movie, WatchingSort.recent);
      expect(movies.map((g) => g.group), [TrackingGroup.inProgress, TrackingGroup.paused], reason: 'a movie pauses after 7 days');
      expect(movies.expand((g) => g.items).every((i) => i.isMovie), isTrue);
      expect(hub.groups(WatchingFilter.tv, WatchingSort.recent).expand((g) => g.items).every((i) => !i.isMovie), isTrue);
    });

    test('a ranked finished movie leaves the groups at once but stays in the history', () {
      final hub = TrackingHub([movie('Done', state: TrackingState.finished, ranked: true, finishedAt: ago(1))], now);
      expect(hub.groups(WatchingFilter.all, WatchingSort.recent), isEmpty);
      expect(hub.finishedHistory().single.title, 'Done');
    });

    test('Finished is a flat history, newest finish first', () {
      final hub = TrackingHub([
        series('old', state: TrackingState.finished, finishedAt: ago(20)),
        movie('new', state: TrackingState.finished, finishedAt: ago(2)),
        series('mid', state: TrackingState.finished, finishedAt: ago(9)),
        series('open'),
      ], now);
      expect(hub.groups(WatchingFilter.finished, WatchingSort.recent), isEmpty);
      expect(hub.finishedHistory().map((i) => i.title), ['new', 'mid', 'old']);
    });
  });

  group('sort', () {
    final items = [
      series('slow', idle: 2, left: 8),
      series('close', idle: 5, left: 1),
      series('unknown', idle: 1),
      series('mid', idle: 3, left: 4),
    ];

    test('Recent puts the latest progress first within a group', () {
      final g = TrackingHub(items, now).groups(WatchingFilter.all, WatchingSort.recent).single.items;
      expect(g.map((i) => i.title), ['unknown', 'slow', 'mid', 'close']);
    });

    test('Fewest left puts the nearest finish first, unknowns last', () {
      final g = TrackingHub(items, now).groups(WatchingFilter.all, WatchingSort.fewestLeft).single.items;
      expect(g.map((i) => i.title), ['close', 'mid', 'slow', 'unknown']);
    });
  });

  group('filter query', () {
    test('parses the four values and falls back to All', () {
      expect(WatchingFilter.fromQuery('tv'), WatchingFilter.tv);
      expect(WatchingFilter.fromQuery('movie'), WatchingFilter.movie);
      expect(WatchingFilter.fromQuery('finished'), WatchingFilter.finished);
      expect(WatchingFilter.fromQuery('nonsense'), WatchingFilter.all);
      expect(WatchingFilter.fromQuery(null), WatchingFilter.all);
    });
  });

  group('row text', () {
    test('in progress names the next episode, its title and what is left', () {
      expect(TrackingLabels.hubMeta(series('S', left: 5), TrackingGroup.inProgress, now), "S1 · E2 'Attila' · 5 left");
    });

    test('New episodes says it with a pill, not a meta line', () {
      final item = series('S', newSince: ago(1), next: const EpisodeRef(2, 1), place: const EpisodeRef(1, 9));
      expect(TrackingLabels.hubMeta(item, TrackingGroup.newEpisodes, now), '');
      expect(TrackingLabels.newBadge(item), 'Season 2 is out');
      expect(TrackingLabels.newBadge(series('S', newSince: ago(1), next: const EpisodeRef(2, 4), place: const EpisodeRef(2, 3))), 'E4 is out');
    });

    test('Finished, not ranked says when', () {
      expect(TrackingLabels.hubMeta(series('S', state: TrackingState.caughtUp, idle: 5, next: null), TrackingGroup.finishedNotRanked, now), 'Up to date · Oct 4');
      expect(
        TrackingLabels.hubMeta(series('S', state: TrackingState.finished, finishedAt: DateTime(2026, 10, 4), next: null), TrackingGroup.finishedNotRanked, now),
        'Finished · Oct 4',
      );
    });

    test('Caught up shows the rank and whether a season is announced', () {
      final done = series('S', state: TrackingState.caughtUp, ranked: true, rank: 6, next: null);
      expect(TrackingLabels.hubMeta(done, TrackingGroup.caughtUp, now), 'Ranked #6 · no new season announced');
    });

    test('movies read "Started yesterday · 2 h 46" and "Finished Oct 6", with a prefix under All', () {
      expect(TrackingLabels.hubMeta(movie('M'), TrackingGroup.inProgress, now), 'Started yesterday · 2 h 46');
      expect(TrackingLabels.hubMeta(movie('M'), TrackingGroup.inProgress, now, moviePrefix: true), 'Movie · Started yesterday · 2 h 46');
      expect(
        TrackingLabels.hubMeta(movie('M', state: TrackingState.finished, finishedAt: DateTime(2026, 10, 6)), null, now),
        'Finished Oct 6',
      );
    });
  });
}
