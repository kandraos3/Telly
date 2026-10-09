import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/achievements/domain/medal.dart';
import 'package:telly_app/features/challenges/domain/challenge.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/home/domain/home_hero.dart';
import 'package:telly_app/features/home/domain/home_moves.dart';
import 'package:telly_app/features/queue/domain/streaming_models.dart';
import 'package:telly_app/features/tracking/domain/tracking_item.dart';
import 'package:telly_app/features/tracking/domain/tracking_models.dart';

import 'home_fixtures.dart';

// SCR-21 §21.3: which moves Home offers, and in what order.
void main() {
  const weekStreak = WeeklyStreak(
    currentWeeks: 6,
    bestWeeks: 6,
    weeks: [
      StreakWeek(label: '2026-W41', status: StreakWeekStatus.counted),
      StreakWeek(label: '2026-W42', status: StreakWeekStatus.current),
    ],
  );

  List<HomeMove> rank({
    DateTime? now,
    List<TrackingItem>? tracking,
    HomeHero? hero,
    WatchlistItem? queuePick,
    WeeklyStreak? streak,
    List<Challenge> challenges = const [],
    List<ActivityLog> feed = const [],
    Map<(String, int), HomeMyRank> mine = const {},
    bool follows = true,
  }) {
    final at = now ?? homeNow;
    // Something is always tracked unless a test says otherwise, so startTracking stays out of the way.
    final items = tracking ?? [tracked('Base', id: 9999)];
    return HomeMovesRanker.rank(
      now: at,
      hero: hero ?? HomeHeroPicker.pick(tracking: items, queue: const [], queuePickKey: null, hasRankings: true, now: at),
      tracking: items,
      queuePick: queuePick,
      streak: streak,
      challenges: challenges,
      friendActivity: feed,
      me: 'me',
      myRankings: mine,
      followsAnyone: follows,
    );
  }

  List<HomeMoveKind> kinds(List<HomeMove> m) => [for (final x in m) x.kind];

  group('rankFinished', () {
    final finished = tracked('The Bear', id: 5, state: TrackingState.finished, finishedAt: daysAgo(1));

    test('offers a finished, unranked title for 14 days', () {
      final move = rank(tracking: [finished]).single;
      expect(move.kind, HomeMoveKind.rankFinished);
      expect(move.title, 'You finished The Bear');
      expect(move.meta, 'Series · yesterday');
      expect(move.buttonLabel, 'Log and duel');
      expect((move.titleId, move.mediaType), (5, 'tv'));
    });

    test('the 14-day window is inclusive and a ranked title never shows', () {
      final edge = tracked('Edge', id: 6, state: TrackingState.finished, finishedAt: daysAgo(14));
      final past = tracked('Past', id: 7, state: TrackingState.finished, finishedAt: daysAgo(15));
      final ranked = tracked('Ranked', id: 8, state: TrackingState.finished, finishedAt: daysAgo(1), ranked: true);
      expect(rank(tracking: [edge, past, ranked]).map((m) => m.titleId), [6]);
    });

    test('a movie says so, and a caught-up series reads as caught up', () {
      final film = tracked('Perfect Days', id: 9, mediaType: 'movie', state: TrackingState.finished, finishedAt: homeNow);
      final caught = tracked('Slow Horses', id: 10, state: TrackingState.caughtUp);
      final moves = rank(tracking: [film, caught]);
      expect(moves.firstWhere((m) => m.titleId == 9).meta, 'Movie · today');
      expect(moves.firstWhere((m) => m.titleId == 10).title, "You're caught up on Slow Horses");
    });
  });

  group('newEpisodes', () {
    test('a returned season reads as a new season, and the hero title is left out', () {
      final lead = tracked('Lead', id: 1, idle: 0);
      final shogun = tracked('Shōgun', id: 2, newSince: daysAgo(2), idle: 3, next: const EpisodeRef(2, 1));
      final moves = rank(tracking: [lead, shogun]);
      expect(moves.single.title, 'Shōgun: Season 2 is out');
      expect(moves.single.meta, "You're caught up on S1");
      expect(moves.single.buttonLabel, 'Resume');
    });

    test('a mid-season episode reads as an episode', () {
      final lead = tracked('Lead', id: 1, idle: 0);
      final show = tracked('Show', id: 3, newSince: daysAgo(2), idle: 3, next: const EpisodeRef(2, 4));
      final move = rank(tracking: [lead, show]).single;
      expect(move.title, 'Show: E4 is out');
      expect(move.meta, 'Next up: S2 · E4');
    });

    test('the hero title does not repeat as a move', () {
      final only = tracked('Only', id: 1, newSince: daysAgo(0), idle: 0);
      expect(rank(tracking: [only]), isEmpty);
    });
  });

  group('streakAtRisk', () {
    HomeMove? streakMove(DateTime now, {WeeklyStreak? streak = weekStreak}) => rank(
          now: now,
          streak: streak,
          tracking: [tracked('X')],
        ).where((m) => m.kind == HomeMoveKind.streakAtRisk).firstOrNull;

    test('stays quiet through Wednesday and starts on Thursday', () {
      expect(streakMove(DateTime(2026, 10, 7, 23, 59)), isNull);
      final thu = streakMove(DateTime(2026, 10, 8))!;
      expect((thu.priority, thu.accent), (70, HomeMoveAccent.amber));
      expect(streakMove(DateTime(2026, 10, 9))!.priority, 70);
    });

    test('turns urgent on Saturday and Sunday, then clears on Monday', () {
      final sat = streakMove(DateTime(2026, 10, 10))!;
      expect((sat.priority, sat.accent), (100, HomeMoveAccent.coral));
      expect(streakMove(DateTime(2026, 10, 11, 23, 59))!.priority, 100);
      expect(streakMove(DateTime(2026, 10, 12)), isNull);
    });

    test('needs a streak and a week that has not counted', () {
      expect(streakMove(DateTime(2026, 10, 10), streak: null), isNull);
      expect(streakMove(DateTime(2026, 10, 10), streak: const WeeklyStreak()), isNull);
      const counted = WeeklyStreak(
        currentWeeks: 6,
        weeks: [StreakWeek(label: '2026-W42', status: StreakWeekStatus.counted)],
      );
      expect(streakMove(DateTime(2026, 10, 10), streak: counted), isNull);
    });

    test('says what it needs', () {
      final move = streakMove(DateTime(2026, 10, 10))!;
      expect(move.title, 'Rank 1 title by Sunday');
      expect(move.meta, 'Your 6-week streak needs one ranking this week');
      expect(move.buttonLabel, '+ Log');
    });
  });

  group('challenge', () {
    test('ending within 3 days outranks one that is nearly done', () {
      final soon = challenge(slug: 'soon', name: 'Soon', progress: 1, endsAt: homeNow.add(const Duration(days: 2)));
      final near = challenge(slug: 'near', name: 'Near', progress: 6, endsAt: homeNow.add(const Duration(days: 20)));
      final moves = rank(challenges: [near, soon]);
      expect(moves.map((m) => m.challengeSlug), ['soon', 'near']);
      expect(moves.map((m) => m.priority), [85, 75]);
    });

    test('shows progress and the days left', () {
      final c = challenge(progress: 6, endsAt: DateTime(2026, 10, 18, 12));
      final move = rank(challenges: [c]).single;
      expect(move.title, 'Heist Month: 6 of 8');
      expect(move.meta, '9 days left');
      expect(move.buttonLabel, 'Open');
    });

    test('says today and tomorrow', () {
      expect(rank(challenges: [challenge(endsAt: DateTime(2026, 10, 9, 20))]).single.meta, 'Ends today');
      expect(rank(challenges: [challenge(endsAt: DateTime(2026, 10, 10, 20))]).single.meta, 'Ends tomorrow');
    });

    test('75% is the line, and unjoined, finished or ended challenges never show', () {
      expect(rank(challenges: [challenge(progress: 6, target: 8)]), hasLength(1));
      expect(rank(challenges: [challenge(progress: 5, target: 8, endsAt: homeNow.add(const Duration(days: 20)))]), isEmpty);
      expect(rank(challenges: [challenge(progress: 7, joined: false)]), isEmpty);
      expect(rank(challenges: [challenge(progress: 8, completedAt: homeNow)]), isEmpty);
      expect(rank(challenges: [challenge(progress: 7, endsAt: homeNow.subtract(const Duration(days: 1)))]), isEmpty);
    });

    test('an open-ended challenge close to done has no deadline', () {
      expect(rank(challenges: [challenge(progress: 7)]).single.meta, 'No deadline');
    });
  });

  group('friendCompare', () {
    final mine = {('tv', 10): const HomeMyRank(rank: 5, score: 9.08)};

    test("compares a friend's recent ranking with yours", () {
      final move = rank(feed: [friendActivity('Maya')], mine: mine).single;
      expect(move.kind, HomeMoveKind.friendCompare);
      expect(move.title, 'Maya ranked Andor #2');
      expect(move.meta, 'You have it at #5 · 9.40 vs 9.08');
      expect(move.accent, HomeMoveAccent.violet);
    });

    test('stays within one canon: a movie with the same id is not a match', () {
      final film = friendActivity('Maya', mediaType: 'movie');
      expect(rank(feed: [film], mine: mine), isEmpty);
    });

    test('needs a ranking of yours, a friend (not you) and the last 3 days', () {
      expect(rank(feed: [friendActivity('Maya')]), isEmpty);
      expect(rank(feed: [friendActivity('Me', userId: 'me')], mine: mine), isEmpty);
      expect(rank(feed: [friendActivity('Maya', age: const Duration(days: 3, hours: 1))], mine: mine), isEmpty);
      expect(rank(feed: [friendActivity('Maya', age: const Duration(days: 3))], mine: mine), hasLength(1));
      expect(rank(feed: [friendActivity('Maya', type: ActivityType.queueAdded)], mine: mine), isEmpty);
    });

    test('one move per title, from the most recent friend', () {
      final moves = rank(
        feed: [
          friendActivity('Older', userId: 'u1', age: const Duration(hours: 30)),
          friendActivity('Newer', userId: 'u2', age: const Duration(hours: 1)),
        ],
        mine: mine,
      );
      expect(moves.single.title, startsWith('Newer'));
    });

    test('leaves out the score when either is missing', () {
      final move = rank(feed: [friendActivity('Maya', score: null)], mine: mine).single;
      expect(move.meta, 'You have it at #5');
    });
  });

  group('queuePick, startTracking and findFriends', () {
    test('the Queue pick shows unless the hero already is one', () {
      final pick = queued('Dune: Part Two', id: 3, provider: 'Max');
      final move = rank(queuePick: pick, tracking: [tracked('X')]).single;
      expect(move.kind, HomeMoveKind.queuePick);
      expect(move.meta, 'Movie · on Max');
      final queueHero = HomeHero(mode: HomeHeroMode.queue, queuePick: pick);
      expect(rank(queuePick: pick, hero: queueHero, tracking: [tracked('X')]), isEmpty);
    });

    test('startTracking only before anything was ever tracked', () {
      expect(kinds(rank(tracking: const [])), [HomeMoveKind.startTracking]);
      expect(rank(tracking: [tracked('X')]), isEmpty);
    });

    test('findFriends only when you follow nobody', () {
      expect(kinds(rank(follows: false, tracking: [tracked('X')])), [HomeMoveKind.findFriends]);
    });

    test('a new user gets track-a-show and find-friends, in that order', () {
      expect(kinds(rank(follows: false, tracking: const [])), [HomeMoveKind.startTracking, HomeMoveKind.findFriends]);
    });
  });

  group('ordering and caps', () {
    test('priority order follows the table', () {
      final moves = rank(
        now: DateTime(2026, 10, 10, 12),
        streak: weekStreak,
        tracking: [
          tracked('Lead', id: 1, idle: 0),
          tracked('Done', id: 2, state: TrackingState.finished, finishedAt: DateTime(2026, 10, 9)),
        ],
        challenges: [challenge(progress: 7)],
        queuePick: queued('Dune'),
      );
      expect(kinds(moves), [
        HomeMoveKind.streakAtRisk,
        HomeMoveKind.rankFinished,
        HomeMoveKind.challenge,
        HomeMoveKind.queuePick,
      ]);
    });

    test('at most 4 moves', () {
      final moves = rank(
        streak: weekStreak,
        now: DateTime(2026, 10, 10, 12),
        tracking: [
          tracked('Lead', id: 1, idle: 0),
          tracked('Done', id: 2, state: TrackingState.finished, finishedAt: DateTime(2026, 10, 9)),
        ],
        challenges: [challenge(progress: 7)],
        feed: [friendActivity('Maya', age: const Duration(hours: 40))],
        mine: {('tv', 10): const HomeMyRank(rank: 5)},
        queuePick: queued('Dune'),
        follows: false,
      );
      expect(moves, hasLength(4));
      expect(moves.last.kind, HomeMoveKind.friendCompare);
    });

    test('at most 2 of a kind, newest first', () {
      final done = [
        for (var i = 0; i < 4; i++)
          tracked('Done$i', id: 20 + i, state: TrackingState.finished, finishedAt: daysAgo(i + 1)),
      ];
      expect(rank(tracking: done).map((m) => m.titleId), [20, 21]);
    });

    test('one move per title: the higher priority wins', () {
      final done = tracked('Andor', id: 10, state: TrackingState.finished, finishedAt: daysAgo(1));
      final moves = rank(
        tracking: [done],
        feed: [friendActivity('Maya')],
        mine: {('tv', 10): const HomeMyRank(rank: 5)},
      );
      expect(moves.single.kind, HomeMoveKind.rankFinished);
    });

    test('ties break by recency, then title id, so the order is stable', () {
      final a = tracked('A', id: 31, state: TrackingState.finished, finishedAt: daysAgo(2));
      final b = tracked('B', id: 30, state: TrackingState.finished, finishedAt: daysAgo(2));
      final first = rank(tracking: [a, b]).map((m) => m.titleId).toList();
      expect(first, [30, 31]);
      expect(rank(tracking: [b, a]).map((m) => m.titleId), first);
    });
  });
}
