import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:telly_app/app.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/core/router/app_router.dart';
import 'package:telly_app/core/sync/connectivity_signal.dart';
import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/features/auth/presentation/screens/auth_screen.dart';
import 'package:telly_app/features/discovery/presentation/screens/explore_discover_screen.dart';
import 'package:telly_app/features/feed/presentation/screens/activity_feed_screen.dart';
import 'package:telly_app/features/home/presentation/screens/home_screen.dart';
import 'package:telly_app/features/more/presentation/screens/more_hub_screen.dart';
import 'package:telly_app/features/profile/presentation/screens/dual_canon_profile_screen.dart';
import 'package:telly_app/features/profile/presentation/screens/settings_hub_screen.dart';
import 'package:telly_app/features/profile/presentation/screens/tv_graveyard_screen.dart';
import 'package:telly_app/features/queue/presentation/screens/smart_queue_screen.dart';
import 'package:telly_app/features/sharing/presentation/screens/telly_wrapped_studio_screen.dart';
import 'package:telly_app/features/squads/presentation/screens/squads_list_screen.dart';
import 'package:telly_app/features/logging/presentation/screens/logging_studio_screen.dart';
import 'package:telly_app/features/ranking/data/canon_hydration.dart';
import 'package:telly_app/features/ranking/data/ranking_repository.dart';
import 'package:telly_app/features/discovery/data/discovery_repository.dart';
import 'package:telly_app/features/onboarding/presentation/screens/streaming_setup_screen.dart';

import 'fakes/fake_auth_repository.dart';

class _EmptyRemoteCanon implements RemoteCanonSource {
  @override
  Future<List<RemoteRanking>> fetchMyCanon(String userId) async => const [];
}

void main() {
  final onboarded = UserProfile(
    id: 'u1',
    username: 'maya',
    displayName: 'Maya',
    onboardingCompleted: true,
    createdAt: DateTime(2026),
  );

  Future<ProviderContainer> launch(WidgetTester tester, FakeAuthRepository repo) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      databaseProvider.overrideWithValue(db),
      remoteCanonSourceProvider.overrideWithValue(_EmptyRemoteCanon()),
      connectivityProvider.overrideWith((ref) => Stream.value(true)),
      discoveryRepositoryProvider.overrideWithValue(FakeDiscoveryRepository()),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const TellyApp()));
    await tester.pumpAndSettle();
    return container;
  }

  String location(ProviderContainer c) =>
      c.read(appRouterProvider).routerDelegate.currentConfiguration.uri.toString();

  group('FE-602: app router', () {
    testWidgets('unauthenticated launch lands on SCR-01', (tester) async {
      final c = await launch(tester, FakeAuthRepository());
      expect(location(c), Routes.auth);
      expect(find.byType(AuthScreen), findsOneWidget);
    });

    testWidgets('signed in without onboarding lands on SCR-02', (tester) async {
      final repo = FakeAuthRepository(
        signedInUserId: 'u1',
        profile: UserProfile(id: 'u1', username: 'maya', displayName: 'Maya', createdAt: DateTime(2026)),
      );
      final c = await launch(tester, repo);
      expect(location(c), Routes.streamingSetup);
      expect(find.byType(StreamingSetupScreen), findsOneWidget);
    });

    testWidgets('authenticated + onboarded launch lands on Home inside the shell (#44)', (tester) async {
      final c = await launch(tester, FakeAuthRepository(signedInUserId: 'u1', profile: onboarded));
      expect(location(c), Routes.home);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byKey(const Key('nav_bar_surface')), findsOneWidget);
      expect(find.byKey(const Key('log_fab')), findsOneWidget);
    });

    testWidgets('the five tabs switch branch and keep the other branches alive', (tester) async {
      final c = await launch(tester, FakeAuthRepository(signedInUserId: 'u1', profile: onboarded));
      for (final (tab, path, screen) in [
        ('explore', Routes.explore, ExploreDiscoverScreen),
        ('canon', Routes.canon, DualCanonProfileScreen),
        ('social', Routes.social, ActivityFeedScreen),
        ('more', Routes.more, MoreHubScreen),
        ('home', Routes.home, HomeScreen),
      ]) {
        await tester.tap(find.byKey(Key('nav_tab_$tab')));
        await tester.pumpAndSettle();
        expect(location(c), path, reason: tab);
        expect(find.byType(screen), findsOneWidget, reason: tab);
      }
      // indexedStack: visiting another tab leaves the feed state mounted offstage.
      await tester.tap(find.byKey(const Key('nav_tab_social')));
      await tester.pumpAndSettle();
      final feedState = tester.state(find.byType(ActivityFeedScreen));
      await tester.tap(find.byKey(const Key('nav_tab_more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav_tab_social')));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(ActivityFeedScreen)), same(feedState));
    });

    testWidgets('the Log button shows on Home, Explore, Canon and Social but not on More', (tester) async {
      await launch(tester, FakeAuthRepository(signedInUserId: 'u1', profile: onboarded));
      for (final (tab, shown) in [
        ('home', true),
        ('explore', true),
        ('canon', true),
        ('social', true),
        ('more', false),
      ]) {
        await tester.tap(find.byKey(Key('nav_tab_$tab')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('log_fab')), shown ? findsOneWidget : findsNothing, reason: tab);
      }
    });

    testWidgets('the Log button does not raise where tab content is cut off (#44)', (tester) async {
      await launch(tester, FakeAuthRepository(signedInUserId: 'u1', profile: onboarded));
      // Home shows the button, More does not: both must see the same bottom inset (the nav bar only).
      final withButton = MediaQuery.paddingOf(tester.element(find.byType(HomeScreen))).bottom;
      await tester.tap(find.byKey(const Key('nav_tab_more')));
      await tester.pumpAndSettle();
      final withoutButton = MediaQuery.paddingOf(tester.element(find.byType(MoreHubScreen))).bottom;
      expect(withButton, withoutButton);
    });

    testWidgets('floating Log button opens the logging flow (SCR-09)', (tester) async {
      final c = await launch(tester, FakeAuthRepository(signedInUserId: 'u1', profile: onboarded));
      await tester.tap(find.byKey(const Key('log_fab')));
      await tester.pumpAndSettle();
      // Pushed full-screen over the shell (imperative match, so assert on what renders).
      expect(find.byType(LoggingStudioScreen), findsOneWidget);
      expect(find.byKey(const Key('nav_bar_surface')), findsNothing);
      expect(find.byKey(const Key('log_fab')), findsNothing);
      expect(c.read(appRouterProvider).canPop(), isTrue);
    });

    testWidgets('More reaches Queue, Wrapped, Graveyard and Settings as pushed screens', (tester) async {
      final c = await launch(tester, FakeAuthRepository(signedInUserId: 'u1', profile: onboarded));
      // Pushed imperatively, so the reported location stays /more: assert on what renders.
      for (final (key, screen) in [
        ('more_tile_queue', SmartQueueScreen),
        ('more_tile_wrapped', TellyWrappedStudioScreen),
        ('more_tile_graveyard', TvGraveyardScreen),
        ('more_row_settings', SettingsHubScreen),
      ]) {
        c.read(appRouterProvider).go(Routes.more);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        expect(find.byType(screen), findsOneWidget, reason: key);
        expect(find.byKey(const Key('nav_bar_surface')), findsNothing, reason: key);
      }
    });

    testWidgets('My Squads opens from the Social header', (tester) async {
      await launch(tester, FakeAuthRepository(signedInUserId: 'u1', profile: onboarded));
      await tester.tap(find.byKey(const Key('nav_tab_social')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('feed_squads_button')));
      await tester.pumpAndSettle();
      expect(find.byType(SquadsListScreen), findsOneWidget);
    });

    testWidgets('old paths redirect to their new homes (screen spec §0.0)', (tester) async {
      final c = await launch(tester, FakeAuthRepository(signedInUserId: 'u1', profile: onboarded));
      for (final (old, now) in [
        ('/feed', Routes.social),
        ('/queue', Routes.queue),
        ('/canon/settings', Routes.settings),
        ('/canon/graveyard', Routes.graveyard),
        ('/canon/wrapped', Routes.wrapped),
        ('/canon/edit', Routes.editProfile),
      ]) {
        c.read(appRouterProvider).go(old);
        await tester.pumpAndSettle();
        expect(location(c), now, reason: old);
      }
    });

    testWidgets('deep link /title/tv/1396 opens SCR-08; malformed media types fall back to Home',
        (tester) async {
      final c = await launch(tester, FakeAuthRepository(signedInUserId: 'u1', profile: onboarded));
      c.read(appRouterProvider).go('/title/tv/1396');
      await tester.pumpAndSettle();
      expect(location(c), '/title/tv/1396');
      expect(find.textContaining('Show Detail (tv/1396)'), findsWidgets);

      c.read(appRouterProvider).go('/title/anime/1');
      await tester.pumpAndSettle();
      expect(location(c), Routes.home);
    });

    testWidgets('a deep link while signed out is sent to SCR-01', (tester) async {
      final c = await launch(tester, FakeAuthRepository());
      c.read(appRouterProvider).go('/title/tv/1396');
      await tester.pumpAndSettle();
      expect(location(c), Routes.auth);
    });

    testWidgets('signing out from the app returns to SCR-01', (tester) async {
      final repo = FakeAuthRepository(signedInUserId: 'u1', profile: onboarded);
      final c = await launch(tester, repo);
      await repo.signOut();
      await tester.pumpAndSettle();
      expect(location(c), Routes.auth);
      expect(c.read(appRouterProvider), isA<GoRouter>());
    });
  });
}
