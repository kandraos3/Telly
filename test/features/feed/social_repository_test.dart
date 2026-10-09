import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';

import '../../fakes/fake_social_repository.dart';
import '../../fakes/fake_watchlist_repository.dart';

Map<String, dynamic> feedRow({String id = 'a1', String createdAt = '2026-10-03T11:00:00.123456+00:00'}) => {
      'id': id,
      'user_id': 'u-b',
      'username': 'jordan',
      'display_name': 'Jordan Miller',
      'avatar_url': null,
      'activity_type': 'UPSET_ALERT',
      'title_id': 110492,
      'media_type': 'tv',
      'title': 'Severance',
      'poster_path': '/sev.jpg',
      'release_year': 2022,
      'rank_position': 2,
      'calculated_score': 9.72,
      'canon_size': 40,
      'review_short': 'Peak.',
      'favorite_character': 'Helly R.',
      'tags': ['Mind-Bending'],
      'is_upset': true,
      'upset_delta': 0.31,
      'upset_over_title': 'Succession',
      'upset_over_rank': 4,
      'metadata': {'loser_title_id': 76331},
      'created_at': createdAt,
      'reaction_counts': {'FIRE': 18, 'MIND_BLOWN': 9, 'UNKNOWN': 1, 'EMOJI:🍿': 2},
      'my_reactions': ['FIRE', 'EMOJI:🍿'],
      'comment_count': 7,
      'in_my_queue': true,
    };

void main() {
  late List<http.Request> requests;
  late Object? Function(http.Request) respond;

  SupabaseSocialRepository repo() => SupabaseSocialRepository(
        SupabaseClient(
          'http://supabase.test',
          'anon-key',
          httpClient: MockClient((req) async {
            requests.add(req);
            return http.Response(jsonEncode(respond(req)), 200,
                headers: {'content-type': 'application/json'}, request: req);
          }),
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        currentUserId: () => 'u-me',
      );

  Map<String, dynamic> body(http.Request r) => jsonDecode(r.body) as Map<String, dynamic>;

  setUp(() {
    requests = [];
    respond = (_) => null;
  });

  group('FE-607: SupabaseSocialRepository', () {
    test('first page calls get_activity_feed with no cursor and maps every card field', () async {
      respond = (_) => [feedRow()];
      final page = await repo().getFeedPage(filter: FeedFilter.squads, limit: 1);

      expect(requests.single.url.path, '/rest/v1/rpc/get_activity_feed');
      expect(body(requests.single), {
        'p_filter': 'squads',
        'p_before': null,
        'p_before_id': null,
        'p_limit': 1,
        'p_include_medals': true, // #139: this app renders medal cards
        'p_include_challenges': true, // #144: and challenge cards
        'p_include_tracking': true, // #168: and started / finished watching
      });
      expect(page.hasMore, isTrue, reason: 'a full page may have more');

      final a = page.items.single;
      expect(a.activityType, ActivityType.upsetAlert);
      expect(a.titlePosterUrl, 'https://image.tmdb.org/t/p/w342/sev.jpg');
      expect(a.releaseYear, 2022);
      expect(a.culturalTier, 'God Tier');
      expect(a.upsetOverTitleName, 'Succession');
      expect(a.upsetOverTitleRank, 4);
      expect(a.vibeTags, ['Mind-Bending']);
      expect(a.reactions, {FeedReaction.fire: 18, FeedReaction.mindBlown: 9, const FeedReaction.custom('🍿'): 2});
      expect(a.userReactions, {FeedReaction.fire, const FeedReaction.custom('🍿')});
      expect(a.inUserQueue, isTrue);
      expect(a.commentCount, 7);
    });

    test('the next page passes the last item as the (created_at, id) keyset cursor', () async {
      respond = (_) => [feedRow(id: 'a2', createdAt: '2026-10-03T10:00:00+00:00')];
      final first = activityFromFeedRow(feedRow());
      final page = await repo().getFeedPage(filter: FeedFilter.following, after: first, limit: 20);
      final params = body(requests.single);
      expect(params['p_before_id'], 'a1');
      expect(DateTime.parse(params['p_before'] as String), DateTime.parse('2026-10-03T11:00:00.123456Z'),
          reason: 'microseconds survive the round trip');
      expect(page.hasMore, isFalse);
    });

    test('#144: rows of an unknown type are skipped; the page still reports more by raw rows', () async {
      respond = (_) => [feedRow(), {...feedRow(), 'id': 'future-1', 'activity_type': 'SOMETHING_NEW'}];
      final page = await repo().getFeedPage(filter: FeedFilter.following, limit: 2);
      expect(page.items.map((a) => a.id), isNot(contains('future-1')));
      expect(page.items, hasLength(1));
      expect(page.hasMore, isTrue);
    });

    test('#144: challenge rows carry the challenge; rankings carry their challenge context', () {
      final done = activityFromFeedRow({
        ...feedRow(),
        'activity_type': 'CHALLENGE_COMPLETED',
        'metadata': {
          'challenge_id': 'c1', 'slug': 'spooktober-2026', 'name': 'Spooktober', 'count': 8, 'medal_glyph': '8',
          'best_title': 'The Thing', 'best_rank': 1, 'best_score': 9.4,
        },
      });
      expect(done.activityType, ActivityType.challengeCompleted);
      expect(done.challenge!.bestLine, 'Best of the 8: The Thing (#1, 9.40)');
      final ranked = activityFromFeedRow({
        ...feedRow(),
        'challenge_context': {'slug': 'spooktober-2026', 'name': 'Spooktober', 'count': 2, 'target': 8},
      });
      expect(ranked.challengeContext!.label, 'Spooktober 2 of 8');
    });

    test('dropped-show metadata maps to the Graveyard labels', () {
      final a = activityFromFeedRow({
        ...feedRow(),
        'activity_type': 'SHOW_DROPPED',
        'is_upset': false,
        'metadata': {'season': 2, 'episode': 3, 'reason': 'WRITING_JUMPED_SHARK'},
      });
      expect((a.droppedSeason, a.droppedEpisode, a.dropReason), (2, 3, 'Writing jumped the shark'));
    });

    test('queue add upserts my watchlist row attributed to the poster; remove deletes it', () async {
      final activity = fakeActivity('a1', userId: 'u-b', titleId: 110492);
      await repo().setQueued(activity: activity, queued: true);
      await repo().setQueued(activity: activity, queued: false);

      expect(requests[0].method, 'POST');
      expect(requests[0].url.path, '/rest/v1/user_watchlist');
      expect(jsonDecode(requests[0].body), {
        'user_id': 'u-me',
        'title_id': 110492,
        'media_type': 'tv',
        'recommended_by_user_id': 'u-b',
      });
      expect(requests[1].method, 'DELETE');
      expect(requests[1].url.queryParameters, {'user_id': 'eq.u-me', 'title_id': 'eq.110492', 'media_type': 'eq.tv'});
    });

    test('queue add with watchlistRepository delegates to local-first cache and offline WAL', () async {
      final fakeWatchlist = FakeWatchlistRepository();
      final socialRepo = SupabaseSocialRepository(
        SupabaseClient(
          'http://supabase.test',
          'anon-key',
          httpClient: MockClient((req) async => http.Response('null', 200)),
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        currentUserId: () => 'u-me',
        watchlistRepository: fakeWatchlist,
      );

      final activity = fakeActivity('a1', userId: 'u-b', titleId: 110492, title: 'Severance');
      await socialRepo.setQueued(activity: activity, queued: true);
      expect(await fakeWatchlist.isInWatchlist(110492, 'tv'), isTrue);

      await socialRepo.setQueued(activity: activity, queued: false);
      expect(await fakeWatchlist.isInWatchlist(110492, 'tv'), isFalse);
    });

    test('reactions write the server enum value', () async {
      await repo().setReaction(activityId: 'a1', reaction: FeedReaction.masterpiece, active: true);
      await repo().setReaction(activityId: 'a1', reaction: FeedReaction.masterpiece, active: false);
      expect(jsonDecode(requests[0].body), {'activity_id': 'a1', 'user_id': 'u-me', 'reaction_type': 'MASTERPIECE'});
      expect(requests[1].url.queryParameters['reaction_type'], 'eq.MASTERPIECE');
    });

    test('FE-FEED-01: a custom emoji replaces my previous one', () async {
      await repo().setReaction(activityId: 'a1', reaction: const FeedReaction.custom('🍿'), active: true);
      expect(requests[0].method, 'DELETE');
      expect(requests[0].url.queryParameters['reaction_type'], 'eq.EMOJI');
      expect(requests[0].url.queryParameters['user_id'], 'eq.u-me');
      expect(requests[1].method, 'POST');
      expect(jsonDecode(requests[1].body),
          {'activity_id': 'a1', 'user_id': 'u-me', 'reaction_type': 'EMOJI', 'emoji': '🍿'});

      requests.clear();
      await repo().setReaction(activityId: 'a1', reaction: const FeedReaction.custom('🍿'), active: false);
      expect(requests.single.method, 'DELETE');
    });

    test('FE-FEED-01: reaction keys round-trip', () {
      expect(FeedReaction.fromDbKey('CINEMA'), FeedReaction.cinema);
      expect(FeedReaction.fromDbKey('EMOJI:😂'), const FeedReaction.custom('😂'));
      expect(FeedReaction.fromDbKey('EMOJI:'), isNull);
      expect(FeedReaction.fromDbKey('EMOJI'), isNull, reason: 'a bare EMOJI type has no glyph');
      expect(FeedReaction.fromDbKey('NOPE'), isNull);
      expect(const FeedReaction.custom('😂').dbKey, 'EMOJI:😂');
      expect(FeedReaction.kudos.glyph, '👏');
    });

    test('comments load with their author and post with the spoiler flag', () async {
      final row = {
        'id': 'c1',
        'activity_id': 'a1',
        'user_id': 'u-me',
        'body': 'The goat dies',
        'contains_spoilers': true,
        'created_at': '2026-10-03T11:00:00+00:00',
        'users': {'username': 'me', 'display_name': 'Me', 'avatar_url': null},
      };
      respond = (req) => req.method == 'GET' ? [row] : row;
      final list = await repo().getComments('a1');
      expect(requests.single.url.queryParameters['activity_id'], 'eq.a1');
      expect(list.single.username, 'me');

      final posted = await repo().addComment(activityId: 'a1', text: 'The goat dies', containsSpoilers: true);
      expect(jsonDecode(requests.last.body),
          {'activity_id': 'a1', 'user_id': 'u-me', 'body': 'The goat dies', 'contains_spoilers': true});
      expect(posted.containsSpoilers, isTrue);
    });

    test('follow returns the server-decided status; approve updates the request to me', () async {
      respond = (req) => req.method == 'POST' ? {'status': 'pending'} : null;
      expect(await repo().follow('u-private'), FollowStatus.pending);
      await repo().respondToFollow(followerId: 'u-fan', approve: true);
      expect(requests.last.method, 'PATCH');
      expect(requests.last.url.queryParameters, {'follower_id': 'eq.u-fan', 'following_id': 'eq.u-me'});
      expect(jsonDecode(requests.last.body), {'status': 'accepted'});
    });

    test('report and block go through submit_report / block_user', () async {
      await repo().report(target: ReportTarget.comment, targetId: 'c1', reason: ReportReason.unmarkedSpoiler);
      await repo().blockUser('u-troll');
      expect(requests[0].url.path, '/rest/v1/rpc/submit_report');
      expect(body(requests[0]),
          {'p_target_type': 'COMMENT', 'p_target_id': 'c1', 'p_reason': 'UNMARKED_SPOILER', 'p_notes': null});
      expect(requests[1].url.path, '/rest/v1/rpc/block_user');
      expect(body(requests[1]), {'p_user': 'u-troll'});
    });
  });
}
