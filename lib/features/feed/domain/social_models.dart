import 'package:flutter/foundation.dart';
import '../../achievements/domain/medal.dart';

/// Status of a social follow relationship.
enum FollowStatus {
  pending,
  accepted,
  rejected,
  blocked;

  static FollowStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return FollowStatus.pending;
      case 'accepted':
        return FollowStatus.accepted;
      case 'rejected':
        return FollowStatus.rejected;
      case 'blocked':
        return FollowStatus.blocked;
      default:
        return FollowStatus.accepted;
    }
  }
}

/// A social follow entity between two users (BE-301).
@immutable
class SocialFollow {
  final String id;
  final String followerId;
  final String followingId;
  final FollowStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SocialFollow({
    required this.id,
    required this.followerId,
    required this.followingId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAccepted => status == FollowStatus.accepted;
  bool get isPending => status == FollowStatus.pending;
}

/// Types of activity items appearing in the activity feed (SCR-05).
enum ActivityType {
  rankingCreated,
  upsetAlert,
  showDropped,
  queueAdded,
  commentPosted,
  medalUnlocked,
  challengeCompleted,

  /// Watch tracking (#168; features/11 §7.2): no score, no rank.
  watchStarted,
  watchFinished,

  /// A type this app doesn't know yet; the feed skips these rows (#144).
  unknown;

  static ActivityType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'RANKING_CREATED':
        return ActivityType.rankingCreated;
      case 'UPSET_ALERT':
        return ActivityType.upsetAlert;
      case 'SHOW_DROPPED':
        return ActivityType.showDropped;
      case 'QUEUE_ADDED':
        return ActivityType.queueAdded;
      case 'COMMENT_POSTED':
        return ActivityType.commentPosted;
      case 'MEDAL_UNLOCKED':
        return ActivityType.medalUnlocked;
      case 'CHALLENGE_COMPLETED':
        return ActivityType.challengeCompleted;
      case 'WATCH_STARTED':
        return ActivityType.watchStarted;
      case 'WATCH_FINISHED':
        return ActivityType.watchFinished;
      default:
        return ActivityType.unknown;
    }
  }
}

/// Expressive reaction emojis on activity cards (SCR-05, Feature Spec 04 §5).
enum FeedReactionType {
  // SCR-05 presets (FE-FEED-01), in bar order.
  cinema('🎬', 'Cinema', 'CINEMA'),
  kudos('👏', 'Kudos', 'KUDOS'),
  stunned('😮', 'Stunned', 'STUNNED'),
  heartbreak('💔', 'Heartbreak', 'HEARTBREAK'),
  masterpiece('🏆', 'Masterpiece', 'MASTERPIECE'),

  // Retired presets: still valid, shown only on posts that already have them.
  fire('🔥', 'Facts / Peak', 'FIRE'),
  mindBlown('🤯', 'Mind Blown', 'MIND_BLOWN'),
  trashTake('🗑️', 'Trash Take', 'TRASH'),
  tasteTwin('🤝', 'Taste Twin', 'TASTE_TWIN'),

  /// A custom emoji from the picker; the emoji itself lives on [FeedReaction.emoji].
  custom('', 'Emoji', 'EMOJI');

  final String emoji;
  final String label;

  /// `reaction_type_enum` value.
  final String dbValue;

  const FeedReactionType(this.emoji, this.label, this.dbValue);

  /// The reactions offered on every card (FE-FEED-01).
  static const presets = [cinema, kudos, stunned, heartbreak, masterpiece];

  static FeedReactionType? fromDbValue(String value) {
    for (final r in values) {
      if (r.dbValue == value) return r;
    }
    return null;
  }
}

/// One reaction on a feed post: a preset [FeedReactionType], or a custom emoji
/// (`EMOJI` with [emoji] set). A user has at most one custom emoji per post.
@immutable
class FeedReaction {
  final FeedReactionType type;
  final String? emoji;

  const FeedReaction(this.type) : emoji = null;
  const FeedReaction.custom(String this.emoji) : type = FeedReactionType.custom;

  static const cinema = FeedReaction(FeedReactionType.cinema);
  static const kudos = FeedReaction(FeedReactionType.kudos);
  static const stunned = FeedReaction(FeedReactionType.stunned);
  static const heartbreak = FeedReaction(FeedReactionType.heartbreak);
  static const masterpiece = FeedReaction(FeedReactionType.masterpiece);
  static const fire = FeedReaction(FeedReactionType.fire);
  static const mindBlown = FeedReaction(FeedReactionType.mindBlown);

  bool get isCustom => emoji != null;

  /// What the reaction bar shows.
  String get glyph => emoji ?? type.emoji;

  String get label => isCustom ? 'React $emoji' : type.label;

  /// Key used by `get_activity_feed` (`reaction_counts`, `my_reactions`).
  String get dbKey => isCustom ? 'EMOJI:$emoji' : type.dbValue;

  static FeedReaction? fromDbKey(String key) {
    if (key.startsWith('EMOJI:')) {
      final emoji = key.substring(6);
      return emoji.isEmpty ? null : FeedReaction.custom(emoji);
    }
    final type = FeedReactionType.fromDbValue(key);
    return type == null || type == FeedReactionType.custom ? null : FeedReaction(type);
  }

  @override
  bool operator ==(Object other) => other is FeedReaction && other.type == type && other.emoji == emoji;

  @override
  int get hashCode => Object.hash(type, emoji);

  @override
  String toString() => 'FeedReaction($dbKey)';
}

/// `report_target_enum` (features/04, TA-02 moderation).
enum ReportTarget {
  comment('COMMENT'),
  activity('ACTIVITY'),
  ranking('RANKING'),
  user('USER');

  final String dbValue;
  const ReportTarget(this.dbValue);
}

/// `report_reason_enum`.
enum ReportReason {
  unmarkedSpoiler('UNMARKED_SPOILER', 'Unmarked spoiler'),
  harassment('HARASSMENT', 'Harassment or hate'),
  spam('SPAM', 'Spam'),
  inaccurateMetadata('INACCURATE_METADATA', 'Wrong title or details');

  final String dbValue;
  final String label;
  const ReportReason(this.dbValue, this.label);
}

/// The medal on a `MEDAL_UNLOCKED` post (features/10 §10): the activity's metadata.
@immutable
class FeedMedal {
  final String id;
  final String name;
  final MedalTier tier;
  final String glyph;

  const FeedMedal({required this.id, required this.name, required this.tier, required this.glyph});

  static FeedMedal? fromMetadata(Map<String, dynamic> m) {
    final id = m['achievement_id'] as String?;
    if (id == null) return null;
    return FeedMedal(
      id: id,
      name: (m['name'] as String?) ?? 'Medal',
      tier: MedalTier.parse(m['tier'] as String?),
      glyph: (m['glyph'] as String?) ?? '',
    );
  }
}

/// The challenge on a `CHALLENGE_COMPLETED` post (features/10 §10, #144): its metadata.
@immutable
class FeedChallenge {
  final String challengeId;
  final String slug;
  final String name;
  final int count;
  final String medalGlyph;
  final String? bestTitle;
  final int? bestRank;
  final double? bestScore;

  const FeedChallenge({
    required this.challengeId,
    required this.slug,
    required this.name,
    required this.count,
    this.medalGlyph = '★',
    this.bestTitle,
    this.bestRank,
    this.bestScore,
  });

  static FeedChallenge? fromMetadata(Map<String, dynamic> m) {
    final slug = m['slug'] as String?;
    final id = m['challenge_id'] as String?;
    if (slug == null || id == null) return null;
    return FeedChallenge(
      challengeId: id,
      slug: slug,
      name: (m['name'] as String?) ?? 'Challenge',
      count: (m['count'] as num?)?.toInt() ?? 0,
      medalGlyph: (m['medal_glyph'] as String?) ?? '★',
      bestTitle: m['best_title'] as String?,
      bestRank: (m['best_rank'] as num?)?.toInt(),
      bestScore: (m['best_score'] as num?)?.toDouble(),
    );
  }

  /// "Best of the 8: The Thing (#1, 9.40)".
  String? get bestLine {
    final title = bestTitle;
    if (title == null) return null;
    final detail = [if (bestRank != null) '#$bestRank', if (bestScore != null) bestScore!.toStringAsFixed(2)].join(', ');
    return 'Best of the $count: $title${detail.isEmpty ? '' : ' ($detail)'}';
  }
}

/// "Spooktober 2 of 8" under a ranking made inside a challenge the poster joined (#144).
@immutable
class ChallengeContext {
  final String slug;
  final String name;
  final int count;
  final int target;

  const ChallengeContext({required this.slug, required this.name, required this.count, required this.target});

  static ChallengeContext? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final slug = m['slug'] as String?;
    if (slug == null) return null;
    return ChallengeContext(
      slug: slug,
      name: (m['name'] as String?) ?? 'Challenge',
      count: (m['count'] as num?)?.toInt() ?? 0,
      target: (m['target'] as num?)?.toInt() ?? 0,
    );
  }

  String get label => '$name $count of $target';
}

/// An activity feed item representing an action taken by a user in the social graph.
@immutable
class ActivityLog {
  final String id;
  final String userId;
  final String username;
  final String userDisplayName;
  final String? userAvatarUrl;
  final ActivityType activityType;
  final int titleId;
  final String titleName;
  final String? titlePosterUrl;
  final int? releaseYear;
  final String mediaType; // 'movie' or 'tv'
  final int? rankPosition;
  final double? calculatedScore;
  final String? culturalTier;
  final String? favoriteCharacter;
  final List<String> vibeTags;
  final String? microReview;

  // Upset specific metadata
  final bool isUpset;
  final double upsetDelta;
  final int? upsetOverTitleId;
  final String? upsetOverTitleName;
  final String? upsetOverTitlePoster;
  final int? upsetOverTitleRank;
  final double? agreementPercentage;

  // TV Graveyard drop metadata
  final int? droppedSeason;
  final int? droppedEpisode;
  final String? dropReason;
  final bool willingToRevisit;

  /// Set for [ActivityType.medalUnlocked] posts.
  final FeedMedal? medal;

  /// Set for [ActivityType.challengeCompleted] posts.
  final FeedChallenge? challenge;

  /// Set on rankings made inside a challenge the poster joined.
  final ChallengeContext? challengeContext;

  // Interaction states
  final bool inUserQueue;
  final Map<FeedReaction, int> reactions;
  final Set<FeedReaction> userReactions;
  final int commentCount;
  final DateTime createdAt;

  const ActivityLog({
    required this.id,
    required this.userId,
    required this.username,
    required this.userDisplayName,
    this.userAvatarUrl,
    required this.activityType,
    required this.titleId,
    required this.titleName,
    this.titlePosterUrl,
    this.releaseYear,
    this.mediaType = 'tv',
    this.rankPosition,
    this.calculatedScore,
    this.culturalTier,
    this.favoriteCharacter,
    this.vibeTags = const [],
    this.microReview,
    this.isUpset = false,
    this.upsetDelta = 0.0,
    this.upsetOverTitleId,
    this.upsetOverTitleName,
    this.upsetOverTitlePoster,
    this.upsetOverTitleRank,
    this.agreementPercentage,
    this.droppedSeason,
    this.droppedEpisode,
    this.dropReason,
    this.willingToRevisit = false,
    this.medal,
    this.challenge,
    this.challengeContext,
    this.inUserQueue = false,
    this.reactions = const {},
    this.userReactions = const {},
    this.commentCount = 0,
    required this.createdAt,
  });

  /// Returns a copy with updated interaction states.
  ActivityLog copyWith({
    bool? inUserQueue,
    Map<FeedReaction, int>? reactions,
    Set<FeedReaction>? userReactions,
    int? commentCount,
    int? upsetOverTitleId,
  }) {
    return ActivityLog(
      id: id,
      userId: userId,
      username: username,
      userDisplayName: userDisplayName,
      userAvatarUrl: userAvatarUrl,
      activityType: activityType,
      titleId: titleId,
      titleName: titleName,
      titlePosterUrl: titlePosterUrl,
      releaseYear: releaseYear,
      mediaType: mediaType,
      rankPosition: rankPosition,
      calculatedScore: calculatedScore,
      culturalTier: culturalTier,
      favoriteCharacter: favoriteCharacter,
      vibeTags: vibeTags,
      microReview: microReview,
      isUpset: isUpset,
      upsetDelta: upsetDelta,
      upsetOverTitleId: upsetOverTitleId ?? this.upsetOverTitleId,
      upsetOverTitleName: upsetOverTitleName,
      upsetOverTitlePoster: upsetOverTitlePoster,
      upsetOverTitleRank: upsetOverTitleRank,
      agreementPercentage: agreementPercentage,
      droppedSeason: droppedSeason,
      droppedEpisode: droppedEpisode,
      dropReason: dropReason,
      willingToRevisit: willingToRevisit,
      medal: medal,
      challenge: challenge,
      challengeContext: challengeContext,
      inUserQueue: inUserQueue ?? this.inUserQueue,
      reactions: reactions ?? this.reactions,
      userReactions: userReactions ?? this.userReactions,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt,
    );
  }

  /// "Started watching" or "finished": a watch tracking event, which never shows a score (features/11 §7.2).
  bool get isWatchEvent => activityType == ActivityType.watchStarted || activityType == ActivityType.watchFinished;

  /// Human-friendly relative timestamp (e.g. "2h ago", "Just now").
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${createdAt.month}/${createdAt.day}/${createdAt.year}';
  }
}

/// A comment on an activity post with spoiler mask support (SCR-06, FE-305).
@immutable
class RankingComment {
  final String id;
  final String rankingId;
  final String userId;
  final String username;
  final String userDisplayName;
  final String? userAvatarUrl;
  final String commentText;
  final bool containsSpoilers;
  final DateTime createdAt;

  const RankingComment({
    required this.id,
    required this.rankingId,
    required this.userId,
    required this.username,
    required this.userDisplayName,
    this.userAvatarUrl,
    required this.commentText,
    this.containsSpoilers = false,
    required this.createdAt,
  });

  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}
