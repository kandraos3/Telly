import '../../achievements/domain/medal.dart';
import '../../challenges/domain/challenge.dart';
import '../../feed/domain/social_models.dart';
import '../../queue/domain/streaming_models.dart';
import '../../tracking/domain/tracking_group.dart';
import '../../tracking/domain/tracking_item.dart';
import '../../tracking/domain/tracking_models.dart';
import 'friends_line.dart';
import 'home_hero.dart';

/// The kinds of card in *Your moves* (SCR-21 §21.3).
enum HomeMoveKind {
  rankFinished,
  newEpisodes,
  streakAtRisk,
  challenge,
  friendCompare,
  queuePick,
  startTracking,
  findFriends,
}

/// The tint of a move's icon tile and kicker.
enum HomeMoveAccent { lime, amber, coral, violet }

/// Where you stand on a title, for `friendCompare`.
class HomeMyRank {
  const HomeMyRank({this.rank, this.score});

  final int? rank;
  final double? score;
}

/// One card in *Your moves*: what it says and what its button does.
class HomeMove {
  const HomeMove({
    required this.kind,
    required this.priority,
    required this.recency,
    required this.kicker,
    required this.title,
    required this.meta,
    required this.buttonLabel,
    required this.accent,
    this.titleId,
    this.mediaType,
    this.challengeSlug,
  });

  final HomeMoveKind kind;
  final int priority;

  /// Breaks ties between equal priorities: newest first.
  final DateTime recency;
  final String kicker;
  final String title;
  final String meta;
  final String buttonLabel;
  final HomeMoveAccent accent;

  /// The title the button opens (and the one-move-per-title key); null for moves about no title.
  final int? titleId;
  final String? mediaType;

  /// The challenge a `challenge` move opens.
  final String? challengeSlug;
}

/// Picks and orders the cards in *Your moves* (SCR-21 §21.3). Pure Dart: `now` is passed in, so weekday and
/// date rules are testable, and it is read as local time.
abstract final class HomeMovesRanker {
  static const maxMoves = 4;
  static const maxPerKind = 2;

  /// A finished title stays on offer to rank this long.
  static const rankWindow = Duration(days: 14);

  /// A friend's ranking is worth comparing for this long.
  static const compareWindow = Duration(days: 3);

  /// A challenge counts as close to done from this share of its target.
  static const challengeNearDone = 0.75;

  /// A challenge counts as ending soon within this many days.
  static const challengeSoonDays = 3;

  static final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  static List<HomeMove> rank({
    required DateTime now,
    required HomeHero hero,
    required List<TrackingItem> tracking,
    required WatchlistItem? queuePick,
    required WeeklyStreak? streak,
    required List<Challenge> challenges,
    required List<ActivityLog> friendActivity,
    required String? me,
    required Map<(String, int), HomeMyRank> myRankings,
    required bool followsAnyone,
  }) {
    final all = <HomeMove>[
      ..._tracked(now, hero, tracking),
      ..._streak(now, streak),
      ..._challenges(now, challenges),
      ..._friendCompare(now, friendActivity, me, myRankings),
      ..._queue(hero, queuePick),
      if (tracking.isEmpty) _startTracking(),
      if (!followsAnyone) _findFriends(),
    ];
    all.sort((a, b) {
      final byPriority = b.priority.compareTo(a.priority);
      if (byPriority != 0) return byPriority;
      final byRecency = b.recency.compareTo(a.recency);
      if (byRecency != 0) return byRecency;
      final byId = (a.titleId ?? 0).compareTo(b.titleId ?? 0);
      return byId != 0 ? byId : a.kind.index.compareTo(b.kind.index);
    });

    final out = <HomeMove>[];
    final perKind = <HomeMoveKind, int>{};
    final titles = <(String, int)>{};
    for (final move in all) {
      if (out.length == maxMoves) break;
      if ((perKind[move.kind] ?? 0) >= maxPerKind) continue;
      final key = move.titleId == null ? null : (move.mediaType ?? '', move.titleId!);
      if (key != null && titles.contains(key)) continue;
      out.add(move);
      perKind[move.kind] = (perKind[move.kind] ?? 0) + 1;
      if (key != null) titles.add(key);
    }
    return out;
  }

  static Iterable<HomeMove> _tracked(DateTime now, HomeHero hero, List<TrackingItem> tracking) sync* {
    final heroItem = hero.item;
    for (final item in tracking) {
      final group = item.group(now);
      final canon = item.isMovie ? 'Movie' : 'Series';

      if (group == TrackingGroup.finishedNotRanked) {
        final at = item.finishedAt ?? item.lastProgressAt;
        if (now.difference(at) > rankWindow) continue;
        yield HomeMove(
          kind: HomeMoveKind.rankFinished,
          priority: 90,
          recency: at,
          kicker: 'RANK IT',
          title:
              item.state == TrackingState.caughtUp ? "You're caught up on ${item.title}" : 'You finished ${item.title}',
          meta: '$canon · ${_when(at, now)}',
          buttonLabel: 'Log and duel',
          accent: HomeMoveAccent.lime,
          titleId: item.titleId,
          mediaType: item.mediaType,
        );
      } else if (group == TrackingGroup.newEpisodes) {
        if (heroItem != null && heroItem.titleId == item.titleId && heroItem.mediaType == item.mediaType) continue;
        final next = item.nextEpisode?.ref;
        final String title, meta;
        if (next == null) {
          title = '${item.title} has new episodes';
          meta = 'Pick up where you left off';
        } else if (next.episode == 1) {
          title = '${item.title}: Season ${next.season} is out';
          meta = next.season > 1 ? "You're caught up on S${next.season - 1}" : 'Ready when you are';
        } else {
          title = '${item.title}: E${next.episode} is out';
          meta = 'Next up: ${next.label}';
        }
        yield HomeMove(
          kind: HomeMoveKind.newEpisodes,
          priority: 80,
          recency: item.newEpisodesSince ?? item.lastProgressAt,
          kicker: 'NEW EPISODES',
          title: title,
          meta: meta,
          buttonLabel: 'Resume',
          accent: HomeMoveAccent.amber,
          titleId: item.titleId,
          mediaType: item.mediaType,
        );
      }
    }
  }

  /// §21.3: from Thursday, when you have a streak and this week hasn't counted yet.
  static Iterable<HomeMove> _streak(DateTime now, WeeklyStreak? streak) sync* {
    if (streak == null || streak.currentWeeks < 1 || streak.weeks.isEmpty) return;
    if (streak.weeks.last.status != StreakWeekStatus.current) return;
    if (now.weekday < DateTime.thursday) return;
    final weekend = now.weekday >= DateTime.saturday;
    yield HomeMove(
      kind: HomeMoveKind.streakAtRisk,
      priority: weekend ? 100 : 70,
      recency: _epoch,
      kicker: 'KEEP YOUR STREAK',
      title: 'Rank 1 title by Sunday',
      meta: 'Your ${streak.currentWeeks}-week streak needs one ranking this week',
      buttonLabel: '+ Log',
      accent: weekend ? HomeMoveAccent.coral : HomeMoveAccent.amber,
    );
  }

  static Iterable<HomeMove> _challenges(DateTime now, List<Challenge> challenges) sync* {
    for (final c in challenges) {
      if (!c.joined || c.isCompleted || c.hasEnded(now) || c.target <= 0) continue;
      final daysLeft = c.daysLeft(now);
      final soon = daysLeft != null && daysLeft <= challengeSoonDays;
      final near = c.myProgress >= c.target * challengeNearDone;
      if (!soon && !near) continue;
      final end = c.endsAt;
      final String meta;
      if (end == null) {
        meta = 'No deadline';
      } else {
        final days = _calendarDays(now, end.toLocal());
        meta = days <= 0 ? 'Ends today' : (days == 1 ? 'Ends tomorrow' : '$days days left');
      }
      yield HomeMove(
        kind: HomeMoveKind.challenge,
        priority: soon ? 85 : 75,
        recency: end ?? c.startsAt,
        kicker: 'CHALLENGE',
        title: '${c.name}: ${c.myProgress} of ${c.target}',
        meta: meta,
        buttonLabel: 'Open',
        accent: HomeMoveAccent.amber,
        challengeSlug: c.slug,
      );
    }
  }

  /// §21.3: a friend's recent ranking of a title you've ranked in the same canon. The map is keyed by
  /// (media type, title id), so a movie never compares with a series.
  static Iterable<HomeMove> _friendCompare(
    DateTime now,
    List<ActivityLog> feed,
    String? me,
    Map<(String, int), HomeMyRank> mine,
  ) sync* {
    final recent = [
      for (final a in feed)
        if (a.userId != me &&
            (a.activityType == ActivityType.rankingCreated || a.activityType == ActivityType.upsetAlert) &&
            now.difference(a.createdAt) <= compareWindow &&
            mine.containsKey((a.mediaType, a.titleId)))
          a,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final seen = <(String, int)>{};
    for (final a in recent) {
      if (!seen.add((a.mediaType, a.titleId))) continue;
      final my = mine[(a.mediaType, a.titleId)]!;
      final rank = a.rankPosition == null ? '' : ' #${a.rankPosition}';
      final parts = <String>[
        my.rank == null ? "You've ranked it" : 'You have it at #${my.rank}',
        if (a.calculatedScore != null && my.score != null)
          '${a.calculatedScore!.toStringAsFixed(2)} vs ${my.score!.toStringAsFixed(2)}',
      ];
      yield HomeMove(
        kind: HomeMoveKind.friendCompare,
        priority: 60,
        recency: a.createdAt,
        kicker: 'COMPARE',
        title: '${FriendsLine.nameOf(a)} ranked ${a.titleName}$rank',
        meta: parts.join(' · '),
        buttonLabel: 'See',
        accent: HomeMoveAccent.violet,
        titleId: a.titleId,
        mediaType: a.mediaType,
      );
    }
  }

  static Iterable<HomeMove> _queue(HomeHero hero, WatchlistItem? pick) sync* {
    if (pick == null || hero.mode == HomeHeroMode.queue) return;
    final canon = pick.mediaType == 'movie' ? 'Movie' : 'Series';
    yield HomeMove(
      kind: HomeMoveKind.queuePick,
      priority: 40,
      recency: pick.addedAt,
      kicker: 'UP NEXT IN YOUR QUEUE',
      title: pick.title,
      meta: pick.availability.isEmpty ? canon : '$canon · on ${pick.availability.first.platformName}',
      buttonLabel: 'Watch',
      accent: HomeMoveAccent.lime,
      titleId: pick.showId,
      mediaType: pick.mediaType,
    );
  }

  static HomeMove _startTracking() => HomeMove(
        kind: HomeMoveKind.startTracking,
        priority: 50,
        recency: _epoch,
        kicker: 'TRACK',
        title: 'Watching a show right now?',
        meta: 'Track it and log episodes from here',
        buttonLabel: 'Find it',
        accent: HomeMoveAccent.lime,
      );

  static HomeMove _findFriends() => HomeMove(
        kind: HomeMoveKind.findFriends,
        priority: 45,
        recency: _epoch,
        kicker: 'FRIENDS',
        title: 'Find friends in Social',
        meta: 'See what they rank',
        buttonLabel: 'Search',
        accent: HomeMoveAccent.violet,
      );

  /// "today", "yesterday" or "N days ago", by calendar day.
  static String _when(DateTime at, DateTime now) {
    final days = _calendarDays(at, now);
    if (days <= 0) return 'today';
    return days == 1 ? 'yesterday' : '$days days ago';
  }

  /// Whole calendar days from [from] to [to], in local time.
  static int _calendarDays(DateTime from, DateTime to) {
    final a = from.toLocal(), b = to.toLocal();
    return DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
  }
}
