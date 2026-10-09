import '../../feed/domain/social_models.dart';

/// One avatar on the Friends line.
class FriendFace {
  const FriendFace({required this.userId, required this.name, this.avatarUrl});

  final String userId;
  final String name;
  final String? avatarUrl;
}

/// The one-line friends summary on Home (SCR-21 §21.4).
class FriendsLineData {
  const FriendsLineData({required this.faces, required this.title, required this.meta});

  /// Up to [FriendsLine.maxFaces], most recent first.
  final List<FriendFace> faces;

  /// "Maya, Jordan and 4 others", "Maya and Jordan" or "Maya".
  final String title;

  /// "ranked 9 titles today", or the newest item's sentence when nobody ranked today.
  final String meta;
}

abstract final class FriendsLine {
  static const maxFaces = 3;

  /// A friend's display name, or `@username` when they have none.
  static String nameOf(ActivityLog a) => a.userDisplayName.isEmpty ? '@${a.username}' : a.userDisplayName;

  /// The sentence after a friend's name, e.g. `ranked Severance #2`.
  static String sentence(ActivityLog a) {
    final rank = a.rankPosition == null ? '' : ' #${a.rankPosition}';
    return switch (a.activityType) {
      ActivityType.rankingCreated || ActivityType.upsetAlert => 'ranked ${a.titleName}$rank',
      ActivityType.showDropped => 'dropped ${a.titleName}',
      ActivityType.queueAdded => 'queued ${a.titleName}',
      ActivityType.commentPosted => 'commented on ${a.titleName}',
      ActivityType.watchStarted => 'started watching ${a.titleName}',
      ActivityType.watchFinished => 'finished ${a.titleName}',
      ActivityType.medalUnlocked => 'unlocked ${a.medal?.name ?? 'a medal'}',
      ActivityType.challengeCompleted => 'finished ${a.challenge?.name ?? 'a challenge'}',
      ActivityType.unknown => 'did something new',
    };
  }

  /// "now", "5m", "2h" or "3d".
  static String ago(DateTime at, DateTime now) {
    final d = now.difference(at);
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inDays < 1) return '${d.inHours}h';
    return '${d.inDays}d';
  }

  /// Friends' title activity from the Following [feed], or null when there is none. Your own posts ([me]),
  /// medal posts and challenge posts are left out.
  static FriendsLineData? from({required List<ActivityLog> feed, required String? me, required DateTime now}) {
    final items = [
      for (final a in feed)
        if (a.userId != me &&
            a.activityType != ActivityType.medalUnlocked &&
            a.activityType != ActivityType.challengeCompleted &&
            a.activityType != ActivityType.unknown)
          a,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (items.isEmpty) return null;

    final today = [
      for (final a in items)
        if ((a.activityType == ActivityType.rankingCreated || a.activityType == ActivityType.upsetAlert) &&
            _sameDay(a.createdAt, now))
          a,
    ];

    if (today.isEmpty) {
      final newest = items.first;
      return FriendsLineData(
        faces: [_face(newest)],
        title: nameOf(newest),
        meta: '${sentence(newest)} · ${ago(newest.createdAt, now)}',
      );
    }

    final friends = <String, ActivityLog>{};
    for (final a in today) {
      friends.putIfAbsent(a.userId, () => a);
    }
    final lead = friends.values.toList();
    final titles = {for (final a in today) (a.mediaType, a.titleId)}.length;
    return FriendsLineData(
      faces: [for (final a in lead.take(maxFaces)) _face(a)],
      title: _names([for (final a in lead) nameOf(a)]),
      meta: 'ranked $titles ${titles == 1 ? 'title' : 'titles'} today',
    );
  }

  static FriendFace _face(ActivityLog a) => FriendFace(userId: a.userId, name: nameOf(a), avatarUrl: a.userAvatarUrl);

  static String _names(List<String> names) {
    if (names.length == 1) return names[0];
    if (names.length == 2) return '${names[0]} and ${names[1]}';
    final others = names.length - 2;
    return '${names[0]}, ${names[1]} and $others ${others == 1 ? 'other' : 'others'}';
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final x = a.toLocal(), y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }
}
