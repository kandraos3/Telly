import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_providers.dart';
import '../../../core/widgets/poster_image.dart';
import '../../onboarding/data/top_50_seeds.dart';
import '../../profile/domain/dropped_show.dart';
import '../../queue/data/watchlist_repository.dart';
import '../../ranking/domain/canon_tier.dart';
import '../domain/social_models.dart';

/// Feed tab filters (SCR-05); the server's `get_activity_feed(p_filter)` values.
enum FeedFilter {
  following,
  squads,
  global;

  String get displayName => switch (this) {
        FeedFilter.following => 'Following',
        FeedFilter.squads => 'Squads',
        FeedFilter.global => 'Global',
      };
}

/// One keyset page of the feed.
class FeedPage {
  final List<ActivityLog> items;
  final bool hasMore;
  const FeedPage(this.items, {required this.hasMore});
}

/// Social graph, feed, reactions, comments and moderation (features/04, FE-607).
abstract interface class SocialRepository {
  /// Newest first; pass the last item of the previous page as [after] for the next one.
  Future<FeedPage> getFeedPage({required FeedFilter filter, ActivityLog? after, int limit = 20});

  /// 1-tap queue add/remove (features/04 §2.2), attributed to the poster.
  Future<void> setQueued({required ActivityLog activity, required bool queued});

  /// Adds a title to my queue, optionally crediting the friend who recommended it.
  Future<void> queueTitle({required int titleId, required String mediaType, String? recommendedBy});

  /// Adds or removes my [reaction]. Adding a custom emoji replaces my previous one.
  Future<void> setReaction({required String activityId, required FeedReaction reaction, required bool active});

  Future<List<RankingComment>> getComments(String activityId);

  Future<RankingComment> addComment({required String activityId, required String text, required bool containsSpoilers});

  /// Null when there is no relationship.
  Future<FollowStatus?> getFollowStatus(String targetUserId);

  /// Accepted immediately for public profiles, pending for friends-only ones (server rule).
  Future<FollowStatus> follow(String targetUserId);

  Future<void> unfollow(String targetUserId);

  /// Approve or reject [followerId]'s pending request to follow me.
  Future<void> respondToFollow({required String followerId, required bool approve});

  Future<void> report({required ReportTarget target, required String targetId, required ReportReason reason, String? notes});

  Future<void> blockUser(String userId);
}

class SupabaseSocialRepository implements SocialRepository {
  SupabaseSocialRepository(
    this._client, {
    String? Function()? currentUserId,
    WatchlistRepository? watchlistRepository,
  })  : _currentUserId = currentUserId ?? (() => _client.auth.currentUser?.id),
        _watchlistRepository = watchlistRepository;

  final SupabaseClient _client;
  final String? Function() _currentUserId;
  final WatchlistRepository? _watchlistRepository;

  String get _me => _currentUserId() ?? (throw StateError('Not signed in'));

  static const _commentColumns =
      'id, activity_id, user_id, body, contains_spoilers, created_at, users(username, display_name, avatar_url)';

  @override
  Future<FeedPage> getFeedPage({required FeedFilter filter, ActivityLog? after, int limit = 20}) async {
    final rows = await _client.rpc('get_activity_feed', params: {
      'p_filter': filter.name,
      'p_before': after?.createdAt.toUtc().toIso8601String(),
      'p_before_id': after?.id,
      'p_limit': limit,
      // This app renders medal cards, so it asks for MEDAL_UNLOCKED rows (#139).
      'p_include_medals': true,
      // ...and challenge cards (#144).
      'p_include_challenges': true,
    }) as List;
    // Rows of a type this app doesn't know are skipped rather than drawn as rankings (#144).
    final items = [
      for (final r in rows)
        if (activityFromFeedRow(r as Map<String, dynamic>) case final a when a.activityType != ActivityType.unknown) a,
    ];
    // Raw rows decide whether more exist; a full page of unknown rows stops paging (no cursor to move).
    return FeedPage(items, hasMore: rows.length == limit && items.isNotEmpty);
  }

  @override
  Future<void> setQueued({required ActivityLog activity, required bool queued}) async {
    final watchlistRepo = _watchlistRepository;
    if (watchlistRepo != null) {
      if (queued) {
        await watchlistRepo.add(
          titleId: activity.titleId,
          mediaType: activity.mediaType,
          title: activity.titleName,
          posterPath: activity.titlePosterUrl,
          recommendedBy: activity.userId != _currentUserId() ? activity.userId : null,
        );
      } else {
        await watchlistRepo.remove(
          titleId: activity.titleId,
          mediaType: activity.mediaType,
        );
      }
      return;
    }
    if (queued) {
      await queueTitle(titleId: activity.titleId, mediaType: activity.mediaType, recommendedBy: activity.userId);
    } else {
      await _client
          .from('user_watchlist')
          .delete()
          .eq('user_id', _me)
          .eq('title_id', activity.titleId)
          .eq('media_type', activity.mediaType);
    }
  }

  @override
  Future<void> queueTitle({required int titleId, required String mediaType, String? recommendedBy}) async {
    final watchlistRepo = _watchlistRepository;
    if (watchlistRepo != null) {
      await watchlistRepo.add(
        titleId: titleId,
        mediaType: mediaType,
        title: 'Title $titleId',
        recommendedBy: recommendedBy != _currentUserId() ? recommendedBy : null,
      );
      return;
    }
    final me = _me;
    await _client.from('user_watchlist').upsert({
      'user_id': me,
      'title_id': titleId,
      'media_type': mediaType,
      if (recommendedBy != null && recommendedBy != me) 'recommended_by_user_id': recommendedBy,
    }, onConflict: 'user_id,title_id,media_type', ignoreDuplicates: true);
  }

  @override
  Future<void> setReaction({required String activityId, required FeedReaction reaction, required bool active}) async {
    final me = _me;
    if (reaction.isCustom) {
      // One EMOJI row per user per post (UNIQUE activity/user/type): replace, don't stack.
      await _client
          .from('feed_reactions')
          .delete()
          .eq('activity_id', activityId)
          .eq('user_id', me)
          .eq('reaction_type', FeedReactionType.custom.dbValue);
      if (active) {
        await _client.from('feed_reactions').insert({
          'activity_id': activityId,
          'user_id': me,
          'reaction_type': FeedReactionType.custom.dbValue,
          'emoji': reaction.emoji,
        });
      }
      return;
    }
    if (active) {
      await _client.from('feed_reactions').upsert(
        {'activity_id': activityId, 'user_id': me, 'reaction_type': reaction.type.dbValue},
        onConflict: 'activity_id,user_id,reaction_type',
        ignoreDuplicates: true,
      );
    } else {
      await _client
          .from('feed_reactions')
          .delete()
          .eq('activity_id', activityId)
          .eq('user_id', me)
          .eq('reaction_type', reaction.type.dbValue);
    }
  }

  @override
  Future<List<RankingComment>> getComments(String activityId) async {
    final rows = await _client
        .from('comments')
        .select(_commentColumns)
        .eq('activity_id', activityId)
        .order('created_at', ascending: true);
    return [for (final r in rows) _comment(r)];
  }

  @override
  Future<RankingComment> addComment({
    required String activityId,
    required String text,
    required bool containsSpoilers,
  }) async {
    final row = await _client
        .from('comments')
        .insert({'activity_id': activityId, 'user_id': _me, 'body': text, 'contains_spoilers': containsSpoilers})
        .select(_commentColumns)
        .single();
    return _comment(row);
  }

  @override
  Future<FollowStatus?> getFollowStatus(String targetUserId) async {
    final row = await _client
        .from('social_follows')
        .select('status')
        .eq('follower_id', _me)
        .eq('following_id', targetUserId)
        .maybeSingle();
    return row == null ? null : FollowStatus.fromString(row['status'] as String);
  }

  @override
  Future<FollowStatus> follow(String targetUserId) async {
    final row = await _client
        .from('social_follows')
        .insert({'follower_id': _me, 'following_id': targetUserId})
        .select('status')
        .single();
    return FollowStatus.fromString(row['status'] as String);
  }

  @override
  Future<void> unfollow(String targetUserId) =>
      _client.from('social_follows').delete().eq('follower_id', _me).eq('following_id', targetUserId);

  @override
  Future<void> respondToFollow({required String followerId, required bool approve}) => _client
      .from('social_follows')
      .update({'status': approve ? 'accepted' : 'rejected'})
      .eq('follower_id', followerId)
      .eq('following_id', _me);

  @override
  Future<void> report({
    required ReportTarget target,
    required String targetId,
    required ReportReason reason,
    String? notes,
  }) =>
      _client.rpc('submit_report', params: {
        'p_target_type': target.dbValue,
        'p_target_id': targetId,
        'p_reason': reason.dbValue,
        'p_notes': notes,
      });

  @override
  Future<void> blockUser(String userId) => _client.rpc('block_user', params: {'p_user': userId});

  static RankingComment _comment(Map<String, dynamic> r) {
    final user = (r['users'] as Map?) ?? const {};
    return RankingComment(
      id: r['id'] as String,
      rankingId: r['activity_id'] as String,
      userId: r['user_id'] as String,
      username: (user['username'] as String?) ?? '',
      userDisplayName: (user['display_name'] as String?) ?? '',
      userAvatarUrl: user['avatar_url'] as String?,
      commentText: r['body'] as String,
      containsSpoilers: (r['contains_spoilers'] as bool?) ?? false,
      createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
    );
  }
}


/// Maps one `get_activity_feed` row (see migration `20261010000500`) to a card model.
ActivityLog activityFromFeedRow(Map<String, dynamic> r) {
  final metadata = (r['metadata'] as Map?)?.cast<String, dynamic>() ?? const {};
  final score = (r['calculated_score'] as num?)?.toDouble();
  final counts = (r['reaction_counts'] as Map?) ?? const {};
  final titleId = (r['title_id'] as num?)?.toInt() ?? 0;
  final mediaType = (r['media_type'] as String?) ?? 'tv';
  final titleName = (r['title'] as String?) ?? 'Unknown title';
  final rawPoster = r['poster_path'] as String?;
  final seedPoster = findSeedPoster(titleId, mediaType, titleName);
  final effectivePoster = (rawPoster != null && rawPoster.isNotEmpty) ? rawPoster : seedPoster;

  final loserTitleName = r['upset_over_title'] as String?;
  int? effectiveLoserId = (metadata['loser_title_id'] as num?)?.toInt();
  if ((effectiveLoserId == null || effectiveLoserId == 0) && loserTitleName != null) {
    for (final s in kTop50SeedTitles) {
      if (s.title.toLowerCase() == loserTitleName.toLowerCase()) {
        effectiveLoserId = s.id;
        break;
      }
    }
  }
  final loserTitleId = effectiveLoserId ?? 0;
  final loserSeedPoster = findSeedPoster(loserTitleId, mediaType, loserTitleName);
  final loserPoster = (metadata['loser_poster_path'] as String?) ?? loserSeedPoster;

  return ActivityLog(
    id: r['id'] as String,
    userId: r['user_id'] as String,
    username: (r['username'] as String?) ?? '',
    userDisplayName: (r['display_name'] as String?) ?? '',
    userAvatarUrl: r['avatar_url'] as String?,
    activityType: ActivityType.fromString(r['activity_type'] as String),
    titleId: titleId,
    titleName: titleName,
    titlePosterUrl: TmdbImages.poster(effectivePoster),
    releaseYear: (r['release_year'] as num?)?.toInt(),
    mediaType: mediaType,
    rankPosition: (r['rank_position'] as num?)?.toInt(),
    calculatedScore: score,
    culturalTier: score == null ? null : CanonTier.fromScore(score).label,
    favoriteCharacter: r['favorite_character'] as String?,
    vibeTags: [for (final t in (r['tags'] as List? ?? const [])) t as String],
    microReview: r['review_short'] as String?,
    isUpset: (r['is_upset'] as bool?) ?? false,
    upsetDelta: (r['upset_delta'] as num?)?.toDouble() ?? 0,
    upsetOverTitleId: effectiveLoserId,
    upsetOverTitleName: loserTitleName,
    upsetOverTitlePoster: TmdbImages.poster(loserPoster),
    upsetOverTitleRank: (r['upset_over_rank'] as num?)?.toInt(),
    droppedSeason: (metadata['season'] as num?)?.toInt(),
    droppedEpisode: (metadata['episode'] as num?)?.toInt(),
    dropReason: DropReasonTaxonomy.fromDbValue(metadata['reason'] as String?) ?? metadata['reason'] as String?,
    medal: FeedMedal.fromMetadata(metadata),
    challenge: FeedChallenge.fromMetadata(metadata),
    challengeContext: ChallengeContext.fromJson(r['challenge_context']),
    inUserQueue: (r['in_my_queue'] as bool?) ?? false,
    reactions: {
      for (final MapEntry(:key, :value) in counts.entries)
        if (FeedReaction.fromDbKey(key as String) case final reaction?) reaction: (value as num).toInt(),
    },
    userReactions: {
      for (final v in (r['my_reactions'] as List? ?? const []))
        if (FeedReaction.fromDbKey(v as String) case final reaction?) reaction,
    },
    commentCount: (r['comment_count'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
  );
}

final socialRepositoryProvider = Provider<SocialRepository>(
  (ref) => SupabaseSocialRepository(
    ref.watch(supabaseClientProvider),
    watchlistRepository: ref.watch(watchlistRepositoryProvider),
  ),
);
