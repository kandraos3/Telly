import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';

/// Builds a feed item; [minutesAgo] orders the feed (newest first).
ActivityLog fakeActivity(
  String id, {
  String userId = 'u-jordan',
  String username = 'jordan',
  int titleId = 110492,
  String title = 'Severance',
  bool upset = false,
  int minutesAgo = 0,
  Set<FeedFilter> visibleIn = const {FeedFilter.following, FeedFilter.global},
}) =>
    ActivityLog(
      id: id,
      userId: userId,
      username: username,
      userDisplayName: username[0].toUpperCase() + username.substring(1),
      activityType: upset ? ActivityType.upsetAlert : ActivityType.rankingCreated,
      titleId: titleId,
      titleName: title,
      mediaType: 'tv',
      rankPosition: 2,
      calculatedScore: 9.72,
      isUpset: upset,
      upsetDelta: upset ? 0.31 : 0,
      upsetOverTitleName: upset ? 'Succession' : null,
      upsetOverTitleRank: upset ? 4 : null,
      reactions: const {FeedReactionType.fire: 3},
      createdAt: DateTime(2026, 10, 3, 12).subtract(Duration(minutes: minutesAgo)),
    );

/// Deterministic in-memory [SocialRepository] for widget tests (FE-607).
class FakeSocialRepository implements SocialRepository {
  FakeSocialRepository({List<ActivityLog>? feed, Map<FeedFilter, Set<String>>? tabs, this.me = 'u-me'})
      : feed = feed ?? [],
        tabs = tabs ?? const {};

  final String me;
  final List<ActivityLog> feed;

  /// Which ids each tab shows; tabs not listed show everything.
  final Map<FeedFilter, Set<String>> tabs;
  final comments = <String, List<RankingComment>>{};

  final pageRequests = <(FeedFilter, String?)>[];
  final reactions = <(String, FeedReactionType, bool)>[];
  final queued = <(int, bool)>[];
  final reports = <(ReportTarget, String, ReportReason)>[];
  final blocked = <String>[];
  bool failWrites = false;

  void _maybeFail() {
    if (failWrites) throw Exception('server rejected the write');
  }

  @override
  Future<FeedPage> getFeedPage({required FeedFilter filter, ActivityLog? after, int limit = 20}) async {
    pageRequests.add((filter, after?.id));
    final visible = [
      for (final a in feed)
        if (tabs[filter]?.contains(a.id) ?? true)
          if (!blocked.contains(a.userId)) a,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final start = after == null ? 0 : visible.indexWhere((a) => a.id == after.id) + 1;
    final page = visible.skip(start).take(limit).toList();
    return FeedPage(page, hasMore: start + page.length < visible.length);
  }

  @override
  Future<void> setQueued({required ActivityLog activity, required bool queued}) async {
    _maybeFail();
    this.queued.add((activity.titleId, queued));
  }

  @override
  Future<void> setReaction({required String activityId, required FeedReactionType reaction, required bool active}) async {
    _maybeFail();
    reactions.add((activityId, reaction, active));
  }

  @override
  Future<List<RankingComment>> getComments(String activityId) async => List.of(comments[activityId] ?? const []);

  @override
  Future<RankingComment> addComment({
    required String activityId,
    required String text,
    required bool containsSpoilers,
  }) async {
    _maybeFail();
    final c = RankingComment(
      id: 'c-${(comments[activityId]?.length ?? 0) + 1}',
      rankingId: activityId,
      userId: me,
      username: 'me',
      userDisplayName: 'Me',
      commentText: text,
      containsSpoilers: containsSpoilers,
      createdAt: DateTime(2026, 10, 3, 12),
    );
    comments.putIfAbsent(activityId, () => []).add(c);
    return c;
  }

  @override
  Future<FollowStatus?> getFollowStatus(String targetUserId) async => null;

  @override
  Future<FollowStatus> follow(String targetUserId) async => FollowStatus.accepted;

  @override
  Future<void> unfollow(String targetUserId) async {}

  @override
  Future<void> respondToFollow({required String followerId, required bool approve}) async {}

  @override
  Future<void> report({
    required ReportTarget target,
    required String targetId,
    required ReportReason reason,
    String? notes,
  }) async {
    _maybeFail();
    reports.add((target, targetId, reason));
  }

  @override
  Future<void> blockUser(String userId) async {
    _maybeFail();
    blocked.add(userId);
  }
}
