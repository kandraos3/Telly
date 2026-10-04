import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:telly_app/app.dart';
import 'package:telly_app/core/router/app_router.dart';
import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/features/auth/presentation/screens/auth_screen.dart';
import 'package:telly_app/features/feed/presentation/screens/activity_feed_screen.dart';
import 'package:telly_app/features/logging/presentation/screens/logging_studio_screen.dart';
import 'package:telly_app/features/onboarding/presentation/screens/streaming_setup_screen.dart';

import 'fakes/fake_auth_repository.dart';

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
    final container = ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(repo)]);
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

    testWidgets('authenticated + onboarded launch lands on the Feed inside the shell', (tester) async {
      final c = await launch(tester, FakeAuthRepository(signedInUserId: 'u1', profile: onboarded));
      expect(location(c), Routes.feed);
      expect(find.byType(ActivityFeedScreen), findsOneWidget);
      expect(find.byKey(const Key('nav_bar_surface')), findsOneWidget);
    });

    testWidgets('each tab switches branch and keeps the other branches alive', (tester) async {
      final c = await launch(tester, FakeAuthRepository(signedInUserId: 'u1', profile: onboarded));
      for (final (tab, path) in [
        ('explore', Routes.explore),
        ('queue', Routes.queue),
        ('canon', Routes.canon),
        ('feed', Routes.feed),
      ]) {
        await tester.tap(find.byKey(Key('nav_tab_$tab')));
        await tester.pumpAndSettle();
        expect(location(c), path, reason: tab);
      }
      // indexedStack: visiting another tab leaves the feed's state mounted offstage.
      await tester.tap(find.byKey(const Key('nav_tab_queue')));
      await tester.pumpAndSettle();
      final feedState = tester.state(find.byType(ActivityFeedScreen, skipOffstage: false));
      await tester.tap(find.byKey(const Key('nav_tab_feed')));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(ActivityFeedScreen)), same(feedState));
    });

    testWidgets('center action opens the logging flow (SCR-09)', (tester) async {
      final c = await launch(tester, FakeAuthRepository(signedInUserId: 'u1', profile: onboarded));
      await tester.tap(find.byKey(const Key('nav_log_button')));
      await tester.pumpAndSettle();
      // Pushed full-screen over the shell (imperative match, so assert on what renders).
      expect(find.byType(LoggingStudioScreen), findsOneWidget);
      expect(find.byKey(const Key('nav_bar_surface')), findsNothing);
      expect(c.read(appRouterProvider).canPop(), isTrue);
    });

    testWidgets('deep link /title/tv/1396 opens SCR-08; malformed media types fall back to the feed',
        (tester) async {
      final c = await launch(tester, FakeAuthRepository(signedInUserId: 'u1', profile: onboarded));
      c.read(appRouterProvider).go('/title/tv/1396');
      await tester.pumpAndSettle();
      expect(location(c), '/title/tv/1396');
      expect(find.textContaining('Show Detail (tv/1396)'), findsWidgets);

      c.read(appRouterProvider).go('/title/anime/1');
      await tester.pumpAndSettle();
      expect(location(c), Routes.feed);
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
