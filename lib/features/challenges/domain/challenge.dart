/// Challenges (features/10 §8; #144): a `challenge_card` row from `discover_challenges`,
/// `my_challenges` and `get_challenge`, plus the racers, picks and templates around it.
library;

class Challenge {
  final String id;
  final String slug;
  final String name;
  final String description;
  final String art;
  final String medalGlyph;
  final DateTime startsAt;
  final DateTime? endsAt;
  final int target;
  final bool featured;
  final String? squadId;
  final String? squadName;
  final int participantCount;
  final int friendCount;
  final bool joined;
  final int myProgress;
  final DateTime? completedAt;

  const Challenge({
    required this.id,
    required this.slug,
    required this.name,
    this.description = '',
    this.art = 'gold',
    this.medalGlyph = '★',
    required this.startsAt,
    this.endsAt,
    required this.target,
    this.featured = false,
    this.squadId,
    this.squadName,
    this.participantCount = 0,
    this.friendCount = 0,
    this.joined = false,
    this.myProgress = 0,
    this.completedAt,
  });

  bool get isSquad => squadId != null;
  bool get isCompleted => completedAt != null;
  bool hasEnded(DateTime now) => endsAt != null && !endsAt!.isAfter(now);

  /// Whole days left, rounding up ("24 DAYS LEFT"); null when open-ended.
  int? daysLeft(DateTime now) {
    final end = endsAt;
    if (end == null) return null;
    final left = end.difference(now);
    if (left.isNegative) return 0;
    return (left.inMinutes / (24 * 60)).ceil();
  }

  /// "24 days left", "Last day", "Ended" or "Open-ended".
  String timeLabel(DateTime now) {
    final days = daysLeft(now);
    if (days == null) return 'Open-ended';
    if (days == 0) return 'Ended';
    if (days == 1) return 'Last day';
    return '$days days left';
  }

  double get fraction => target <= 0 ? 0 : (myProgress / target).clamp(0, 1).toDouble();

  Challenge copyWith({bool? joined, int? myProgress, DateTime? completedAt, int? participantCount}) => Challenge(
        id: id,
        slug: slug,
        name: name,
        description: description,
        art: art,
        medalGlyph: medalGlyph,
        startsAt: startsAt,
        endsAt: endsAt,
        target: target,
        featured: featured,
        squadId: squadId,
        squadName: squadName,
        participantCount: participantCount ?? this.participantCount,
        friendCount: friendCount,
        joined: joined ?? this.joined,
        myProgress: myProgress ?? this.myProgress,
        completedAt: completedAt ?? this.completedAt,
      );

  factory Challenge.fromJson(Map<String, dynamic> j) => Challenge(
        id: j['id'] as String,
        slug: j['slug'] as String,
        name: j['name'] as String,
        description: (j['description'] as String?) ?? '',
        art: (j['art'] as String?) ?? 'gold',
        medalGlyph: (j['medal_glyph'] as String?) ?? '★',
        startsAt: DateTime.parse(j['starts_at'] as String).toLocal(),
        endsAt: j['ends_at'] == null ? null : DateTime.parse(j['ends_at'] as String).toLocal(),
        target: (j['target'] as num).toInt(),
        featured: (j['featured'] as bool?) ?? false,
        squadId: j['squad_id'] as String?,
        squadName: j['squad_name'] as String?,
        participantCount: (j['participant_count'] as num?)?.toInt() ?? 0,
        friendCount: (j['friend_count'] as num?)?.toInt() ?? 0,
        joined: (j['joined'] as bool?) ?? false,
        myProgress: (j['my_progress'] as num?)?.toInt() ?? 0,
        completedAt: j['completed_at'] == null ? null : DateTime.parse(j['completed_at'] as String).toLocal(),
      );
}

/// SCR-25: the featured hero, "Yours", "Join next" and "Ended".
class ChallengesOverview {
  final Challenge? featured;
  final List<Challenge> yours;
  final List<Challenge> joinNext;
  final List<Challenge> ended;

  const ChallengesOverview({this.featured, this.yours = const [], this.joinNext = const [], this.ended = const []});

  bool get isEmpty => featured == null && yours.isEmpty && joinNext.isEmpty && ended.isEmpty;

  /// Splits the two RPC lists. The featured challenge leads (joined or not) and isn't repeated.
  factory ChallengesOverview.of({
    required List<Challenge> mine,
    required List<Challenge> discover,
    required DateTime now,
  }) {
    final live = [for (final c in [...mine, ...discover]) if (!c.hasEnded(now)) c];
    final featured = live.where((c) => c.featured).firstOrNull;
    return ChallengesOverview(
      featured: featured,
      yours: [for (final c in mine) if (!c.hasEnded(now) && c.id != featured?.id) c],
      joinNext: [for (final c in discover) if (!c.hasEnded(now) && c.id != featured?.id) c],
      ended: [for (final c in mine) if (c.hasEnded(now)) c],
    );
  }

  ChallengesOverview map(Challenge Function(Challenge) f) => ChallengesOverview(
        featured: featured == null ? null : f(featured!),
        yours: yours.map(f).toList(),
        joinNext: joinNext.map(f).toList(),
        ended: ended.map(f).toList(),
      );
}

/// SCR-26 "Friends in this challenge".
class ChallengeRacer {
  final String userId;
  final String? username;
  final String displayName;
  final String? avatarUrl;
  final int progress;
  final DateTime? completedAt;
  final bool isMe;

  const ChallengeRacer({
    required this.userId,
    this.username,
    this.displayName = '',
    this.avatarUrl,
    this.progress = 0,
    this.completedAt,
    this.isMe = false,
  });

  String get name => isMe ? 'You' : (displayName.isNotEmpty ? displayName : '@${username ?? ''}');

  factory ChallengeRacer.fromJson(Map<String, dynamic> j) => ChallengeRacer(
        userId: j['user_id'] as String,
        username: j['username'] as String?,
        displayName: (j['display_name'] as String?) ?? '',
        avatarUrl: j['avatar_url'] as String?,
        progress: (j['progress'] as num?)?.toInt() ?? 0,
        completedAt: j['completed_at'] == null ? null : DateTime.parse(j['completed_at'] as String).toLocal(),
        isMe: (j['is_me'] as bool?) ?? false,
      );
}

/// SCR-26 "Picks": a title that would count, from my Queue or what friends ranked.
class ChallengePick {
  final int titleId;
  final String mediaType;
  final String title;
  final String? posterPath;
  final int? releaseYear;
  final bool fromQueue;
  final double? friendsScore;
  final int friendCount;

  const ChallengePick({
    required this.titleId,
    required this.mediaType,
    required this.title,
    this.posterPath,
    this.releaseYear,
    this.fromQueue = false,
    this.friendsScore,
    this.friendCount = 0,
  });

  factory ChallengePick.fromJson(Map<String, dynamic> j) => ChallengePick(
        titleId: (j['title_id'] as num).toInt(),
        mediaType: j['media_type'] as String,
        title: (j['title'] as String?) ?? 'Untitled',
        posterPath: j['poster_path'] as String?,
        releaseYear: (j['release_year'] as num?)?.toInt(),
        fromQueue: j['source'] == 'queue',
        friendsScore: (j['friends_score'] as num?)?.toDouble(),
        friendCount: (j['friend_count'] as num?)?.toInt() ?? 0,
      );
}

/// SCR-26 in one load.
class ChallengeDetail {
  final Challenge challenge;
  final List<ChallengeRacer> racers;
  final List<ChallengePick> picks;

  const ChallengeDetail({required this.challenge, this.racers = const [], this.picks = const []});
}

/// A template squads create challenges from (`challenge_templates`, §8.3).
class ChallengeTemplate {
  final String key;
  final String name;
  final String description;
  final List<String> params;
  final int target;

  const ChallengeTemplate({
    required this.key,
    required this.name,
    this.description = '',
    this.params = const [],
    required this.target,
  });

  factory ChallengeTemplate.fromJson(Map<String, dynamic> j) => ChallengeTemplate(
        key: j['key'] as String,
        name: j['name'] as String,
        description: (j['description'] as String?) ?? '',
        params: [for (final p in (j['params'] as List?) ?? const []) p as String],
        target: (j['target'] as num).toInt(),
      );
}
