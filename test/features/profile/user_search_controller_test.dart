import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/profile/data/profile_repository.dart';
import 'package:telly_app/features/profile/domain/user_search_result.dart';
import 'package:telly_app/features/profile/presentation/controllers/user_search_controller.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_profile_repository.dart';

void main() {
  group('UserSearchResult', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'u100',
        'username': 'alex',
        'display_name': 'Alex Morgan',
        'avatar_url': 'https://cdn.test/avatar.jpg',
        'visibility_mode': 'FRIENDS_ONLY',
        'follow_status': 'pending',
        'taste_match': 88,
        'mutual_count': 12,
      };

      final result = UserSearchResult.fromJson(json);

      expect(result.id, 'u100');
      expect(result.username, 'alex');
      expect(result.displayName, 'Alex Morgan');
      expect(result.avatarUrl, 'https://cdn.test/avatar.jpg');
      expect(result.visibilityMode, 'FRIENDS_ONLY');
      expect(result.followStatus, FollowStatus.pending);
      expect(result.tasteMatch, 88);
      expect(result.mutualCount, 12);
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'id': 'u101',
        'username': 'bob',
        'display_name': 'Bob',
      };

      final result = UserSearchResult.fromJson(json);

      expect(result.id, 'u101');
      expect(result.username, 'bob');
      expect(result.displayName, 'Bob');
      expect(result.avatarUrl, isNull);
      expect(result.visibilityMode, 'PUBLIC');
      expect(result.followStatus, isNull);
      expect(result.tasteMatch, isNull);
      expect(result.mutualCount, isNull);
    });

    test('copyWith updates fields and clears follow status', () {
      const original = UserSearchResult(
        id: 'u1',
        username: 'sam',
        displayName: 'Sam',
        followStatus: FollowStatus.accepted,
      );

      final updated = original.copyWith(displayName: 'Samantha');
      expect(updated.displayName, 'Samantha');
      expect(updated.followStatus, FollowStatus.accepted);

      final cleared = original.copyWith(clearFollowStatus: true);
      expect(cleared.followStatus, isNull);
    });

    test('equality and hashCode', () {
      const a = UserSearchResult(id: 'u1', username: 'sam', displayName: 'Sam');
      const b = UserSearchResult(id: 'u1', username: 'sam', displayName: 'Sam');
      const c = UserSearchResult(id: 'u2', username: 'alex', displayName: 'Alex');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('UserSearchController', () {
    late FakeProfileRepository profileRepo;
    late FakeAuthRepository authRepo;
    late ProviderContainer container;

    setUp(() {
      profileRepo = FakeProfileRepository();
      authRepo = FakeAuthRepository(
        signedInUserId: 'me',
        profile: UserProfile(
          id: 'me',
          username: 'my_user',
          displayName: 'Me',
          createdAt: DateTime(2026),
        ),
      );
      container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(profileRepo),
          authRepositoryProvider.overrideWithValue(authRepo),
        ],
      );
      addTearDown(container.dispose);
    });

    test('initial state is empty list', () async {
      final state = await container.read(userSearchProvider.future);
      expect(state, isEmpty);
    });

    test('empty or whitespace query yields empty list without calling repo', () async {
      profileRepo.searchResults.add(
        const UserSearchResult(id: 'u1', username: 'alex', displayName: 'Alex'),
      );

      await container.read(userSearchProvider.notifier).search('   ');

      final state = container.read(userSearchProvider).value;
      expect(state, isEmpty);
    });

    test('search finds matching users and trims query', () async {
      profileRepo.searchResults.addAll([
        const UserSearchResult(id: 'u1', username: 'alex', displayName: 'Alex Morgan'),
        const UserSearchResult(id: 'u2', username: 'alexander', displayName: 'Alexander Ross'),
        const UserSearchResult(id: 'u3', username: 'charlie', displayName: 'Charlie'),
      ]);

      await container.read(userSearchProvider.notifier).search('  alex  ');

      final results = container.read(userSearchProvider).value!;
      expect(results.length, 2);
      expect(results[0].username, 'alex');
      expect(results[1].username, 'alexander');
    });

    test('search handles repository error', () async {
      profileRepo.failReads = true;

      await container.read(userSearchProvider.notifier).search('alex');

      expect(container.read(userSearchProvider).hasError, isTrue);
    });

    test('toggleFollow follows an unfollowed user', () async {
      profileRepo.searchResults.add(
        const UserSearchResult(id: 'u1', username: 'alex', displayName: 'Alex'),
      );
      profileRepo.follows['u1'] = FollowStatus.pending;

      await container.read(userSearchProvider.notifier).search('alex');
      await container.read(userSearchProvider.notifier).toggleFollow('u1');

      final results = container.read(userSearchProvider).value!;
      expect(results[0].followStatus, FollowStatus.pending);
    });

    test('toggleFollow unfollows an already followed user', () async {
      profileRepo.searchResults.add(
        const UserSearchResult(
          id: 'u1',
          username: 'alex',
          displayName: 'Alex',
          followStatus: FollowStatus.accepted,
        ),
      );

      await container.read(userSearchProvider.notifier).search('alex');
      await container.read(userSearchProvider.notifier).toggleFollow('u1');

      final results = container.read(userSearchProvider).value!;
      expect(results[0].followStatus, isNull);
    });

    test('toggleFollow throws StateError if trying to follow oneself', () async {
      profileRepo.searchResults.add(
        const UserSearchResult(id: 'me', username: 'my_user', displayName: 'Me'),
      );

      await container.read(userSearchProvider.notifier).search('my_user');

      expect(
        () => container.read(userSearchProvider.notifier).toggleFollow('me'),
        throwsStateError,
      );
    });

    test('respondToFollow updates request status in state', () async {
      profileRepo.searchResults.add(
        const UserSearchResult(
          id: 'u1',
          username: 'alex',
          displayName: 'Alex',
          followStatus: FollowStatus.pending,
        ),
      );

      await container.read(userSearchProvider.notifier).search('alex');
      await container.read(userSearchProvider.notifier).respondToFollow(
            requesterId: 'u1',
            approve: true,
          );

      final results = container.read(userSearchProvider).value!;
      expect(results[0].followStatus, FollowStatus.accepted);
    });
  });
}
