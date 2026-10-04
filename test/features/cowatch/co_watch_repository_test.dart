import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/cowatch/data/co_watch_repository.dart';
import 'package:telly_app/features/cowatch/domain/two_to_watch_engine.dart';

void main() {
  group('FE-610: CoWatch Candidate Deserialization & Session Logic', () {
    test('CoWatchCandidate.fromJson parses RPC columns correctly', () {
      final json = {
        'show_id': 87108,
        'title': 'Chernobyl',
        'media_type': 'tv',
        'runtime_minutes': 60,
        'poster_path': '/poster.jpg',
        'network': 'HBO',
        'available_providers': ['max'],
        'vibe_tags': ['thriller', 'miniseries'],
        'in_watchlist_a': true,
        'in_watchlist_b': true,
        'rating_a': 9.8,
        'rating_b': null,
        'community_score': 9.6,
        'overview': 'Nuclear disaster dramatization',
      };

      final candidate = CoWatchCandidate.fromJson(json);

      expect(candidate.showId, 87108);
      expect(candidate.title, 'Chernobyl');
      expect(candidate.mediaType, 'tv');
      expect(candidate.runtimeMinutes, 60);
      expect(candidate.posterPath, '/poster.jpg');
      expect(candidate.network, 'HBO');
      expect(candidate.availableProviders, ['max']);
      expect(candidate.vibeTags, ['thriller', 'miniseries']);
      expect(candidate.inWatchlistA, isTrue);
      expect(candidate.inWatchlistB, isTrue);
      expect(candidate.inBothWatchlists, isTrue);
      expect(candidate.ratingA, 9.8);
      expect(candidate.ratingB, isNull);
      expect(candidate.communityScore, 9.6);
      expect(candidate.overview, 'Nuclear disaster dramatization');
    });

    test('CoWatchSwipeEvent serialization and deserialization roundtrip', () {
      const event = CoWatchSwipeEvent(
        userId: 'user-123',
        titleId: 501,
        direction: SwipeDirection.right,
      );

      final json = event.toJson();
      expect(json['user_id'], 'user-123');
      expect(json['title_id'], 501);
      expect(json['direction'], 'right');

      final deserialized = CoWatchSwipeEvent.fromJson(json);
      expect(deserialized.userId, 'user-123');
      expect(deserialized.titleId, 501);
      expect(deserialized.direction, SwipeDirection.right);
    });
  });

  group('FE-610: Quick-Swipe Realtime Multiplayer Invariants', () {
    late FakeCoWatchSessionClient client;

    setUp(() {
      client = FakeCoWatchSessionClient(
        sessionId: 'test-session-1',
        currentUserId: 'user-a',
      );
    });

    tearDown(() {
      client.dispose();
    });

    test('one-sided right swipe does NOT trigger mutual match', () async {
      final matches = <int>[];
      client.onMutualMatch.listen(matches.add);

      await client.sendSwipe(titleId: 101, direction: SwipeDirection.right);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(matches, isEmpty, reason: 'Partner has not swiped right yet; one-sided swipe is not a match.');
      expect(client.localSwipes[101], SwipeDirection.right);
    });

    test('partner right swipe after user right swipe triggers mutual match', () async {
      final matches = <int>[];
      client.onMutualMatch.listen(matches.add);

      // User A swipes right
      await client.sendSwipe(titleId: 101, direction: SwipeDirection.right);
      expect(matches, isEmpty);

      // User B swipes right on the same title
      client.simulatePartnerSwipe(
        const CoWatchSwipeEvent(
          userId: 'user-b',
          titleId: 101,
          direction: SwipeDirection.right,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(matches, [101], reason: 'Both users swiped right on 101; mutual match triggered.');
    });

    test('user right swipe after partner right swipe triggers mutual match', () async {
      final matches = <int>[];
      client.onMutualMatch.listen(matches.add);

      // User B swiped right earlier
      client.simulatePartnerSwipe(
        const CoWatchSwipeEvent(
          userId: 'user-b',
          titleId: 202,
          direction: SwipeDirection.right,
        ),
      );
      expect(matches, isEmpty);

      // User A now swipes right on 202
      await client.sendSwipe(titleId: 202, direction: SwipeDirection.right);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(matches, [202], reason: 'Both users swiped right on 202; mutual match triggered.');
    });

    test('partner left swipe and user right swipe does NOT trigger match', () async {
      final matches = <int>[];
      client.onMutualMatch.listen(matches.add);

      // Partner passes (swipes left)
      client.simulatePartnerSwipe(
        const CoWatchSwipeEvent(
          userId: 'user-b',
          titleId: 103,
          direction: SwipeDirection.left,
        ),
      );

      // User swipes right
      await client.sendSwipe(titleId: 103, direction: SwipeDirection.right);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(matches, isEmpty, reason: 'Partner swiped left; no match.');
    });

    test('user left swipe and partner right swipe does NOT trigger match', () async {
      final matches = <int>[];
      client.onMutualMatch.listen(matches.add);

      // User passes (swipes left)
      await client.sendSwipe(titleId: 104, direction: SwipeDirection.left);

      // Partner swipes right
      client.simulatePartnerSwipe(
        const CoWatchSwipeEvent(
          userId: 'user-b',
          titleId: 104,
          direction: SwipeDirection.right,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(matches, isEmpty, reason: 'User swiped left; no match.');
    });

    test('two connected client instances over simulated Realtime channel', () async {
      final clientA = FakeCoWatchSessionClient(sessionId: 'room-1', currentUserId: 'alice');
      final clientB = FakeCoWatchSessionClient(sessionId: 'room-1', currentUserId: 'bob');

      FakeCoWatchSessionClient.connectPair(clientA, clientB);

      final matchesA = <int>[];
      final matchesB = <int>[];
      clientA.onMutualMatch.listen(matchesA.add);
      clientB.onMutualMatch.listen(matchesB.add);

      // Alice swipes right on title 999
      await clientA.sendSwipe(titleId: 999, direction: SwipeDirection.right);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(matchesA, isEmpty);
      expect(matchesB, isEmpty);

      // Bob also swipes right on title 999
      await clientB.sendSwipe(titleId: 999, direction: SwipeDirection.right);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Both receive the mutual match notification simultaneously!
      expect(matchesA, [999]);
      expect(matchesB, [999]);

      clientA.dispose();
      clientB.dispose();
    });
  });
}
