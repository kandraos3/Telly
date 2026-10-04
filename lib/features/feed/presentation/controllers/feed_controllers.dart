import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/social_repository.dart';
import '../../domain/social_models.dart';

/// The selected `SCR-05` tab.
class FeedFilterController extends Notifier<FeedFilter> {
  @override
  FeedFilter build() => FeedFilter.following;

  void select(FeedFilter filter) => state = filter;
}

final feedFilterProvider = NotifierProvider<FeedFilterController, FeedFilter>(FeedFilterController.new);

class FeedState {
  final List<ActivityLog> items;
  final bool hasMore;
  final bool loadingMore;

  const FeedState({this.items = const [], this.hasMore = false, this.loadingMore = false});

  FeedState copyWith({List<ActivityLog>? items, bool? hasMore, bool? loadingMore}) => FeedState(
        items: items ?? this.items,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

/// One feed tab (FE-607): keyset pagination plus optimistic reactions and queue saves that
/// roll back if the server rejects them. Each tab keeps its own list.
class FeedController extends FamilyAsyncNotifier<FeedState, FeedFilter> {
  static const pageSize = 20;

  SocialRepository get _repo => ref.read(socialRepositoryProvider);

  @override
  Future<FeedState> build(FeedFilter arg) async {
    final page = await ref.watch(socialRepositoryProvider).getFeedPage(filter: arg, limit: pageSize);
    return FeedState(items: page.items, hasMore: page.hasMore);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore || current.items.isEmpty) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await _repo.getFeedPage(filter: arg, after: current.items.last, limit: pageSize);
      final seen = {for (final a in current.items) a.id};
      state = AsyncData(FeedState(
        items: [...current.items, ...page.items.where((a) => !seen.contains(a.id))],
        hasMore: page.hasMore,
      ));
    } catch (_) {
      // Keep what we have; the next scroll to the bottom retries.
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  Future<void> toggleReaction(String activityId, FeedReactionType reaction) async {
    final before = _find(activityId);
    if (before == null) return;
    final active = !before.userReactions.contains(reaction);
    final counts = Map<FeedReactionType, int>.of(before.reactions);
    final next = (counts[reaction] ?? 0) + (active ? 1 : -1);
    if (next > 0) {
      counts[reaction] = next;
    } else {
      counts.remove(reaction);
    }
    _replace(before.copyWith(
      reactions: counts,
      userReactions: active ? {...before.userReactions, reaction} : ({...before.userReactions}..remove(reaction)),
    ));
    try {
      await _repo.setReaction(activityId: activityId, reaction: reaction, active: active);
    } catch (_) {
      _replace(before);
      rethrow;
    }
  }

  Future<void> setQueued(String activityId, bool queued) async {
    final before = _find(activityId);
    if (before == null || before.inUserQueue == queued) return;
    // The same title can appear in several cards: they share one queue state.
    _replaceWhere((a) => a.titleId == before.titleId && a.mediaType == before.mediaType,
        (a) => a.copyWith(inUserQueue: queued));
    try {
      await _repo.setQueued(activity: before, queued: queued);
    } catch (_) {
      _replaceWhere((a) => a.titleId == before.titleId && a.mediaType == before.mediaType,
          (a) => a.copyWith(inUserQueue: !queued));
      rethrow;
    }
  }

  void incrementCommentCount(String activityId) {
    final a = _find(activityId);
    if (a != null) _replace(a.copyWith(commentCount: a.commentCount + 1));
  }

  /// After a report: the item disappears for me immediately (moderation decides the rest).
  void hideActivity(String activityId) => _update((items) => items.where((a) => a.id != activityId).toList());

  /// After a block: everything by that user disappears.
  void hideUser(String userId) => _update((items) => items.where((a) => a.userId != userId).toList());

  ActivityLog? _find(String id) => state.valueOrNull?.items.where((a) => a.id == id).firstOrNull;

  void _replace(ActivityLog updated) => _replaceWhere((a) => a.id == updated.id, (_) => updated);

  void _replaceWhere(bool Function(ActivityLog) test, ActivityLog Function(ActivityLog) change) =>
      _update((items) => [for (final a in items) test(a) ? change(a) : a]);

  void _update(List<ActivityLog> Function(List<ActivityLog>) change) {
    final current = state.valueOrNull;
    if (current != null) state = AsyncData(current.copyWith(items: change(current.items)));
  }
}

final feedControllerProvider =
    AsyncNotifierProviderFamily<FeedController, FeedState, FeedFilter>(FeedController.new);

/// Comments of one activity (`SCR-06`).
class CommentsController extends AutoDisposeFamilyAsyncNotifier<List<RankingComment>, String> {
  @override
  Future<List<RankingComment>> build(String arg) => ref.watch(socialRepositoryProvider).getComments(arg);

  Future<void> add(String text, {required bool containsSpoilers}) async {
    final comment = await ref
        .read(socialRepositoryProvider)
        .addComment(activityId: arg, text: text, containsSpoilers: containsSpoilers);
    state = AsyncData([...?state.valueOrNull, comment]);
  }

  void hideComment(String commentId) =>
      state = AsyncData([for (final c in state.valueOrNull ?? const <RankingComment>[]) if (c.id != commentId) c]);

  void hideUser(String userId) =>
      state = AsyncData([for (final c in state.valueOrNull ?? const <RankingComment>[]) if (c.userId != userId) c]);
}

final commentsControllerProvider =
    AsyncNotifierProvider.autoDispose.family<CommentsController, List<RankingComment>, String>(CommentsController.new);

class CommentComposerState {
  final bool containsSpoilers;
  final bool submitting;
  final String? error;

  const CommentComposerState({this.containsSpoilers = false, this.submitting = false, this.error});
}

/// The `SCR-06` composer: spoiler tag + send (FE-607 moves this out of widget `setState`).
class CommentComposerController extends AutoDisposeFamilyNotifier<CommentComposerState, String> {
  @override
  CommentComposerState build(String arg) => const CommentComposerState();

  void toggleSpoiler() => state = CommentComposerState(containsSpoilers: !state.containsSpoilers);

  /// Returns true when the comment was posted.
  Future<bool> submit(String text) async {
    final body = text.trim();
    if (body.isEmpty || state.submitting) return false;
    state = CommentComposerState(containsSpoilers: state.containsSpoilers, submitting: true);
    try {
      await ref.read(commentsControllerProvider(arg).notifier).add(body, containsSpoilers: state.containsSpoilers);
      for (final filter in FeedFilter.values) {
        if (ref.exists(feedControllerProvider(filter))) {
          ref.read(feedControllerProvider(filter).notifier).incrementCommentCount(arg);
        }
      }
      state = const CommentComposerState();
      return true;
    } catch (_) {
      state = CommentComposerState(
        containsSpoilers: state.containsSpoilers,
        error: "Couldn't post your comment. Try again.",
      );
      return false;
    }
  }
}

final commentComposerProvider =
    NotifierProvider.autoDispose.family<CommentComposerController, CommentComposerState, String>(
  CommentComposerController.new,
);
