import 'package:flutter/foundation.dart';

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
  commentPosted;

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
      default:
        return ActivityType.rankingCreated;
    }
  }
}

/// Expressive reaction emojis on activity cards (SCR-05, Feature Spec 04 §5).
enum FeedReactionType {
  fire('🔥', 'Facts / Peak'),
  mindBlown('🤯', 'Mind Blown'),
  trashTake('🗑️', 'Trash Take'),
  heartbreak('💔', 'Heartbreak'),
  tasteTwin('🤝', 'Taste Twin');

  final String emoji;
  final String label;

  const FeedReactionType(this.emoji, this.label);
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
  final String? upsetOverTitleName;
  final String? upsetOverTitlePoster;
  final int? upsetOverTitleRank;
  final double? agreementPercentage;

  // TV Graveyard drop metadata
  final int? droppedSeason;
  final int? droppedEpisode;
  final String? dropReason;
  final bool willingToRevisit;

  // Interaction states
  final bool inUserQueue;
  final Map<FeedReactionType, int> reactions;
  final Set<FeedReactionType> userReactions;
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
    this.upsetOverTitleName,
    this.upsetOverTitlePoster,
    this.upsetOverTitleRank,
    this.agreementPercentage,
    this.droppedSeason,
    this.droppedEpisode,
    this.dropReason,
    this.willingToRevisit = false,
    this.inUserQueue = false,
    this.reactions = const {},
    this.userReactions = const {},
    this.commentCount = 0,
    required this.createdAt,
  });

  /// Returns a copy with updated interaction states.
  ActivityLog copyWith({
    bool? inUserQueue,
    Map<FeedReactionType, int>? reactions,
    Set<FeedReactionType>? userReactions,
    int? commentCount,
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
      upsetOverTitleName: upsetOverTitleName,
      upsetOverTitlePoster: upsetOverTitlePoster,
      upsetOverTitleRank: upsetOverTitleRank,
      agreementPercentage: agreementPercentage,
      droppedSeason: droppedSeason,
      droppedEpisode: droppedEpisode,
      dropReason: dropReason,
      willingToRevisit: willingToRevisit,
      inUserQueue: inUserQueue ?? this.inUserQueue,
      reactions: reactions ?? this.reactions,
      userReactions: userReactions ?? this.userReactions,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt,
    );
  }

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
