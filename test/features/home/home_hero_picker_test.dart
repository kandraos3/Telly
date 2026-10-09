import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/home/domain/home_hero.dart';
import 'package:telly_app/features/queue/domain/streaming_models.dart';
import 'package:telly_app/features/tracking/domain/tracking_item.dart';
import 'package:telly_app/features/tracking/domain/tracking_models.dart';

import 'home_fixtures.dart';

// SCR-21 §21.2: which card leads Home.
void main() {
  HomeHero pick({
    List<TrackingItem> tracking = const [],
    List<WatchlistItem> queue = const [],
    int? key,
    bool ranked = false,
  }) =>
      HomeHeroPicker.pick(
        tracking: tracking,
        queue: queue,
        queuePickKey: key,
        hasRankings: ranked,
        now: homeNow,
      );

  group('watching', () {
    test('leads with the newest progress across both canons', () {
      final hero = pick(tracking: [
        tracked('Old', idle: 5),
        tracked('Film', mediaType: 'movie', idle: 1),
        tracked('Fresh', idle: 0),
      ]);
      expect(hero.mode, HomeHeroMode.watching);
      expect(hero.item!.title, 'Fresh');
      expect(hero.chips.map((c) => c.title), ['Film', 'Old']);
    });

    test('a tie goes to New episodes', () {
      final hero = pick(tracking: [
        tracked('Plain', id: 1),
        tracked('Returned', id: 2, newSince: daysAgo(0)),
      ]);
      expect(hero.item!.title, 'Returned');
    });

    test('keeps at most 3 chips and counts every tracked title in All', () {
      final hero = pick(tracking: [
        for (var i = 0; i < 6; i++) tracked('S$i', id: i, idle: i),
        tracked('Caught', id: 99, state: TrackingState.caughtUp, ranked: true),
      ]);
      expect(hero.chips, hasLength(3));
      expect(hero.totalTracked, 7);
    });

    test('paused, caught-up and finished titles do not lead', () {
      final hero = pick(tracking: [
        tracked('Paused', idle: 40),
        tracked('Done', state: TrackingState.finished, finishedAt: daysAgo(1)),
      ], queue: [
        queued('Dune')
      ]);
      expect(hero.mode, HomeHeroMode.queue);
    });
  });

  group('queue', () {
    test('uses the named pick, mixing canons', () {
      final film = queued('Dune', id: 7);
      final show = queued('Fleabag', id: 7, mediaType: 'tv');
      final hero = pick(queue: [film, show], key: HomeQueueKey.of(show));
      expect(hero.mode, HomeHeroMode.queue);
      expect(hero.queuePick!.title, 'Fleabag');
      expect(hero.chips, isEmpty);
    });

    test('movie and series ids never collide in the key', () {
      expect(HomeQueueKey.of(queued('A', id: 7)), isNot(HomeQueueKey.of(queued('B', id: 7, mediaType: 'tv'))));
    });

    test('an unknown key falls back to the first title', () {
      final hero = pick(queue: [queued('Dune', id: 1), queued('Past Lives', id: 2)], key: 12345);
      expect(hero.queuePick!.title, 'Dune');
    });
  });

  group('new user and explore', () {
    test('no rankings, nothing tracked, empty queue is a new user', () {
      expect(pick().mode, HomeHeroMode.newUser);
    });

    test('with rankings the same state falls through to Explore', () {
      expect(pick(ranked: true).mode, HomeHeroMode.explore);
    });

    test('a tracked-but-paused title keeps a new user out of the welcome', () {
      expect(pick(tracking: [tracked('Paused', idle: 40)]).mode, HomeHeroMode.explore);
    });
  });
}
