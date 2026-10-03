import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';

/// Feed tab filters (SCR-05).
enum FeedFilter {
  following,
  squads,
  global;

  String get displayName {
    switch (this) {
      case FeedFilter.following:
        return 'Following';
      case FeedFilter.squads:
        return 'Squads';
      case FeedFilter.global:
        return 'Global';
    }
  }
}

/// Abstract contract for social interactions, feeds, and comments.
abstract class SocialRepository {
  Future<List<ActivityLog>> getFeedActivities({
    required FeedFilter filter,
    int offset = 0,
    int limit = 20,
  });

  Future<void> toggleQueue({
    required String activityId,
    required int titleId,
    required bool addToQueue,
  });

  Future<ActivityLog> toggleReaction({
    required String activityId,
    required FeedReactionType reaction,
  });

  Future<List<RankingComment>> getComments({required String activityId});

  Future<RankingComment> addComment({
    required String activityId,
    required String text,
    required bool containsSpoilers,
  });

  Future<FollowStatus> followUser({required String targetUserId});

  Future<void> unfollowUser({required String targetUserId});

  Future<FollowStatus> getFollowStatus({required String targetUserId});
}

/// In-memory implementation of SocialRepository (replaced by the Supabase-backed repository in FE-607).
class InMemorySocialRepository implements SocialRepository {
  InMemorySocialRepository() {
    _seedInitialData();
  }

  final List<ActivityLog> _activities = [];
  final Map<String, List<RankingComment>> _comments = {};
  final Map<String, FollowStatus> _followStatuses = {};

  void _seedInitialData() {
    final now = DateTime.now();

    _activities.addAll([
      ActivityLog(
        id: 'act-1',
        userId: 'u-jordan',
        username: 'jordan',
        userDisplayName: 'Jordan Miller',
        activityType: ActivityType.upsetAlert,
        titleId: 102,
        titleName: 'Severance',
        releaseYear: 2022,
        mediaType: 'tv',
        rankPosition: 2,
        calculatedScore: 9.72,
        culturalTier: 'God Tier',
        vibeTags: const ['Mind-Bending', 'Flawless Finale'],
        microReview:
            'The season 2 finale was the most stressful 60 minutes of television in the last decade. Absolute peak.',
        isUpset: true,
        upsetDelta: 0.28,
        upsetOverTitleName: 'Succession',
        upsetOverTitleRank: 4,
        agreementPercentage: 14.0,
        reactions: const {
          FeedReactionType.fire: 18,
          FeedReactionType.mindBlown: 9,
        },
        userReactions: const {FeedReactionType.fire},
        commentCount: 4,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      ActivityLog(
        id: 'act-2',
        userId: 'u-maya',
        username: 'maya',
        userDisplayName: 'Maya Lin',
        activityType: ActivityType.showDropped,
        titleId: 104,
        titleName: 'The Morning Show',
        releaseYear: 2019,
        mediaType: 'tv',
        droppedSeason: 2,
        droppedEpisode: 3,
        dropReason: 'Writing jumped the shark',
        willingToRevisit: false,
        microReview:
            'Loved season 1 but season 2 lost completely what made the newsroom dynamic compelling.',
        reactions: const {
          FeedReactionType.tasteTwin: 12,
          FeedReactionType.trashTake: 6,
        },
        commentCount: 2,
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      ActivityLog(
        id: 'act-3',
        userId: 'u-alex',
        username: 'alex',
        userDisplayName: 'Alex Rivera',
        activityType: ActivityType.rankingCreated,
        titleId: 201,
        titleName: 'Dune: Part Two',
        releaseYear: 2024,
        mediaType: 'movie',
        rankPosition: 3,
        calculatedScore: 9.42,
        culturalTier: 'God Tier',
        favoriteCharacter: 'Paul Atreides',
        vibeTags: const ['Masterpiece Acting', 'Aesthetic Marvel'],
        microReview:
            'Hans Zimmer score vibrating in IMAX was religious. Timothée Chalamet commanding the Fremen army gives goosebumps.',
        reactions: const {
          FeedReactionType.fire: 24,
        },
        commentCount: 7,
        createdAt: now.subtract(const Duration(hours: 8)),
      ),
    ]);

    _comments['act-1'] = [
      RankingComment(
        id: 'comm-1',
        rankingId: 'act-1',
        userId: 'u-alex',
        username: 'alex',
        userDisplayName: 'Alex Rivera',
        commentText:
            'How could you rank it over Succession though? Logan Roy’s funeral episode is untouchable.',
        containsSpoilers: false,
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      RankingComment(
        id: 'comm-2',
        rankingId: 'act-1',
        userId: 'u-jordan',
        username: 'jordan',
        userDisplayName: 'Jordan Miller',
        commentText:
            'True, but Severance hasn’t had a single wasted scene. In the finale when Helly steps onto the stage...',
        containsSpoilers: true,
        createdAt: now.subtract(const Duration(minutes: 45)),
      ),
    ];
  }

  @override
  Future<List<ActivityLog>> getFeedActivities({
    required FeedFilter filter,
    int offset = 0,
    int limit = 20,
  }) async {
    List<ActivityLog> list;
    switch (filter) {
      case FeedFilter.following:
        list = _activities;
        break;
      case FeedFilter.squads:
        list = _activities.where((a) => a.userId == 'u-jordan' || a.userId == 'u-alex').toList();
        break;
      case FeedFilter.global:
        list = _activities;
        break;
    }

    if (offset >= list.length) return [];
    final end = (offset + limit).clamp(0, list.length);
    return list.sublist(offset, end);
  }

  @override
  Future<void> toggleQueue({
    required String activityId,
    required int titleId,
    required bool addToQueue,
  }) async {
    final index = _activities.indexWhere((a) => a.id == activityId);
    if (index != -1) {
      _activities[index] = _activities[index].copyWith(inUserQueue: addToQueue);
    }
  }

  @override
  Future<ActivityLog> toggleReaction({
    required String activityId,
    required FeedReactionType reaction,
  }) async {
    final index = _activities.indexWhere((a) => a.id == activityId);
    if (index == -1) {
      throw ArgumentError('Activity $activityId not found');
    }

    final current = _activities[index];
    final newUserReactions = Set<FeedReactionType>.from(current.userReactions);
    final newReactions = Map<FeedReactionType, int>.from(current.reactions);

    if (newUserReactions.contains(reaction)) {
      newUserReactions.remove(reaction);
      final count = (newReactions[reaction] ?? 1) - 1;
      if (count <= 0) {
        newReactions.remove(reaction);
      } else {
        newReactions[reaction] = count;
      }
    } else {
      newUserReactions.add(reaction);
      newReactions[reaction] = (newReactions[reaction] ?? 0) + 1;
    }

    final updated = current.copyWith(
      reactions: newReactions,
      userReactions: newUserReactions,
    );
    _activities[index] = updated;
    return updated;
  }

  @override
  Future<List<RankingComment>> getComments({required String activityId}) async {
    return _comments[activityId] ?? [];
  }

  @override
  Future<RankingComment> addComment({
    required String activityId,
    required String text,
    required bool containsSpoilers,
  }) async {
    final newComment = RankingComment(
      id: 'comm-${DateTime.now().millisecondsSinceEpoch}',
      rankingId: activityId,
      userId: 'current-user-id',
      username: 'you',
      userDisplayName: 'You',
      commentText: text,
      containsSpoilers: containsSpoilers,
      createdAt: DateTime.now(),
    );

    _comments.putIfAbsent(activityId, () => []).add(newComment);

    final actIndex = _activities.indexWhere((a) => a.id == activityId);
    if (actIndex != -1) {
      _activities[actIndex] = _activities[actIndex].copyWith(
        commentCount: _activities[actIndex].commentCount + 1,
      );
    }

    return newComment;
  }

  @override
  Future<FollowStatus> followUser({required String targetUserId}) async {
    // If target is private, returns pending; default public returns accepted
    const status = FollowStatus.accepted;
    _followStatuses[targetUserId] = status;
    return status;
  }

  @override
  Future<void> unfollowUser({required String targetUserId}) async {
    _followStatuses.remove(targetUserId);
  }

  @override
  Future<FollowStatus> getFollowStatus({required String targetUserId}) async {
    return _followStatuses[targetUserId] ?? FollowStatus.rejected;
  }
}

/// Global Riverpod providers for feed and social interactions
final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return InMemorySocialRepository();
});

final feedFilterProvider = StateProvider<FeedFilter>((ref) => FeedFilter.following);

final feedActivitiesProvider = FutureProvider<List<ActivityLog>>((ref) async {
  final filter = ref.watch(feedFilterProvider);
  final repo = ref.watch(socialRepositoryProvider);
  return repo.getFeedActivities(filter: filter);
});

final commentsProvider =
    FutureProvider.family<List<RankingComment>, String>((ref, activityId) async {
  final repo = ref.watch(socialRepositoryProvider);
  return repo.getComments(activityId: activityId);
});
