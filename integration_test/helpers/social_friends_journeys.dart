import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/app.dart';
import 'package:telly_app/core/config/app_config.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/sync/connectivity_signal.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/profile/data/profile_repository.dart';
import 'package:telly_app/features/profile/domain/user_search_result.dart';
import 'package:telly_app/features/profile/presentation/screens/search_users_screen.dart';
import 'package:telly_app/features/ranking/data/canon_hydration.dart';
import 'package:telly_app/features/ranking/data/ranking_repository.dart';
import 'package:telly_app/features/ranking/domain/franchise_rollup_service.dart';

import '../../test/fakes/fake_auth_repository.dart';
import '../../test/fakes/fake_profile_repository.dart';
import '../../test/fakes/fake_social_repository.dart';

const _me = 'usr_social_test';

class _EmptyRemoteCanon implements RemoteCanonSource {
  @override
  Future<List<RemoteRanking>> fetchMyCanon(String userId) async => const [];
}

Future<void> _launch(
  WidgetTester tester, {
  required FakeProfileRepository profileRepo,
  required FakeSocialRepository socialRepo,
}) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final db = AppDatabase.inMemory();
  addTearDown(db.close);

  final container = ProviderContainer(overrides: [
    databaseProvider.overrideWithValue(db),
    authRepositoryProvider.overrideWithValue(FakeAuthRepository(
      signedInUserId: _me,
      profile: UserProfile(
        id: _me,
        username: 'tester',
        displayName: 'Tester',
        onboardingCompleted: true,
        createdAt: DateTime(2026),
      ),
    )),
    appConfigProvider.overrideWithValue(const AppConfig(
      appEnv: 'test',
      supabaseUrl: 'https://test.supabase.co',
      supabaseAnonKey: 'test-anon-key',
    )),
    hapticsEnabledProvider.overrideWith((ref) => false),
    connectivityProvider.overrideWith((ref) => Stream.value(true)),
    remoteCanonSourceProvider.overrideWithValue(_EmptyRemoteCanon()),
    profileRepositoryProvider.overrideWithValue(profileRepo),
    socialRepositoryProvider.overrideWithValue(socialRepo),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const TellyApp()));
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpFor(WidgetTester tester, [int frames = 15]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  await tester.tap(finder.first);
  await _pumpFor(tester, 10);
}

void socialFriendsJourneys() {
  testWidgets('Social: find friends, follow requests, and public vs private profile gates', (tester) async {
    final profileRepo = FakeProfileRepository();
    final socialRepo = FakeSocialRepository(me: _me);

    // 1. Setup Public User (Alex Morgan @alexm)
    profileRepo.profiles['alexm'] = const PublicProfile(
      id: 'usr_alex',
      username: 'alexm',
      displayName: 'Alex Morgan',
      visibility: 'PUBLIC',
      canView: true,
      bio: 'Cinephile & TV enthusiast',
    );
    profileRepo.canons[('usr_alex', 'movie')] = [
      const CanonEntry(id: 1, title: 'Interstellar', mediaType: 'movie', rankPosition: 1, calculatedScore: 9.8),
    ];
    profileRepo.canons[('usr_alex', 'tv')] = [
      const CanonEntry(id: 2, title: 'Succession', mediaType: 'tv', rankPosition: 1, calculatedScore: 9.9),
    ];
    profileRepo.matches[('usr_alex', 'movie')] = const CanonMatch(88, 12);
    profileRepo.matches[('usr_alex', 'tv')] = const CanonMatch(84, 10);

    // 2. Setup Private User (Alexander Ross @aross)
    profileRepo.profiles['aross'] = const PublicProfile(
      id: 'usr_aross',
      username: 'aross',
      displayName: 'Alexander Ross',
      visibility: 'FRIENDS_ONLY',
      canView: false,
      bio: 'Prestige TV purist',
    );
    socialRepo.privateUsers.add('usr_aross');

    // Populate search results in profileRepo
    profileRepo.searchResults.addAll([
      const UserSearchResult(
        id: 'usr_alex',
        username: 'alexm',
        displayName: 'Alex Morgan',
        visibilityMode: 'PUBLIC',
        tasteMatch: 88,
        mutualCount: 2,
      ),
      const UserSearchResult(
        id: 'usr_aross',
        username: 'aross',
        displayName: 'Alexander Ross',
        visibilityMode: 'FRIENDS_ONLY',
        tasteMatch: 74,
        mutualCount: 1,
      ),
    ]);

    await _launch(tester, profileRepo: profileRepo, socialRepo: socialRepo);

    // Navigate to Social tab
    await _tap(tester, find.byKey(const Key('nav_tab_social')));
    await _waitFor(tester, find.text('Social'));

    // Tap search button in header to open SCR-28 Find Friends
    await _tap(tester, find.byKey(const Key('feed_search_button')));
    await _waitFor(tester, find.byType(SearchUsersScreen));
    expect(find.text('Find Friends'), findsOneWidget);
    expect(find.byKey(const Key('user_search_empty_prompt')), findsOneWidget);

    // Enter query 'alex' to find both users
    await tester.enterText(find.byKey(const Key('user_search_input')), 'alex');
    await _pumpFor(tester, 10);

    expect(find.text('MATCHES'), findsOneWidget);
    expect(find.text('Alex Morgan'), findsOneWidget);
    expect(find.text('@alexm'), findsOneWidget);
    expect(find.text('🎯 88% Taste Match'), findsOneWidget);
    expect(find.text('Alexander Ross'), findsOneWidget);
    expect(find.text('@aross'), findsOneWidget);
    expect(find.text('🎯 74% Taste Match'), findsOneWidget);

    // Follow public user (Alex Morgan)
    await _tap(tester, find.byKey(const Key('user_search_follow_alexm')));
    expect(profileRepo.follows.containsKey('usr_alex'), isTrue);
    // Sync to socialRepo so FriendProfileScreen sees accepted status
    socialRepo.follows['usr_alex'] = FollowStatus.accepted;

    // Tap Alex Morgan's card to open public profile (SCR-15)
    await _tap(tester, find.byKey(const Key('user_search_card_alexm')));
    await _waitFor(tester, find.text('@alexm'));
    expect(find.text('Alex Morgan'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);

    // Verify public profile is NOT locked
    expect(find.byKey(const Key('friend_profile_private')), findsNothing);
    expect(find.textContaining('Two-to-Watch with @alexm'), findsOneWidget);

    // Navigate back to search
    final backBtn = find.byTooltip('Back');
    if (backBtn.evaluate().isNotEmpty) {
      await _tap(tester, backBtn);
    } else {
      await _tap(tester, find.byType(BackButton));
    }
    await _waitFor(tester, find.byType(SearchUsersScreen));

    // Send follow request to private user (Alexander Ross)
    profileRepo.follows['usr_aross'] = FollowStatus.pending;
    await _tap(tester, find.byKey(const Key('user_search_follow_aross')));
    expect(find.text('Requested'), findsOneWidget);
    socialRepo.follows['usr_aross'] = FollowStatus.pending;

    // Tap Alexander Ross's card to open private profile (SCR-15)
    await _tap(tester, find.byKey(const Key('user_search_card_aross')));
    await _waitFor(tester, find.text('@aross'));
    expect(find.text('Alexander Ross'), findsOneWidget);

    // Verify private lock gate is active and conceals Canon & Two-to-Watch
    expect(find.byKey(const Key('friend_profile_private')), findsOneWidget);
    expect(find.text('This Profile is Friends-Only'), findsOneWidget);
    expect(find.textContaining('Follow request sent. Their canon appears once @aross accepts.'), findsOneWidget);
    expect(find.textContaining('Two-to-Watch with @aross'), findsNothing);

    // Now simulate Ross approving the request
    socialRepo.follows['usr_aross'] = FollowStatus.accepted;
    profileRepo.follows['usr_aross'] = FollowStatus.accepted;
    profileRepo.profiles['aross'] = profileRepo.profiles['aross']!.copyWith(canView: true);
    profileRepo.matches[('usr_aross', 'tv')] = const CanonMatch(74, 5);

    // Tap back and re-enter profile
    final backBtn2 = find.byTooltip('Back');
    if (backBtn2.evaluate().isNotEmpty) {
      await _tap(tester, backBtn2);
    } else {
      await _tap(tester, find.byType(BackButton));
    }
    await _waitFor(tester, find.byType(SearchUsersScreen));

    await _tap(tester, find.byKey(const Key('user_search_card_aross')));
    await _waitFor(tester, find.text('@aross'));

    // Private gate is now unlocked
    expect(find.byKey(const Key('friend_profile_private')), findsNothing);
    expect(find.textContaining('Two-to-Watch with @aross'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
  });
}
