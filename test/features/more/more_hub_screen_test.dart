import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/core/widgets/telly_avatar.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/features/more/presentation/screens/more_hub_screen.dart';

import '../../fakes/fake_auth_repository.dart';

void main() {
  UserProfile profile({String? username = 'jordan', String displayName = 'Jordan Miller', String? avatarUrl}) =>
      UserProfile(
        id: 'u1',
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        onboardingCompleted: true,
        createdAt: DateTime(2026),
      );

  /// Hosts the hub at `/`; any other location renders `route:<location>`.
  Future<void> pumpHub(WidgetTester tester, {ThemeData? theme, UserProfile? user}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget stub(BuildContext _, GoRouterState state) => Scaffold(body: Text('route:${state.uri}'));
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const MoreHubScreen()),
      GoRoute(path: '/:a', builder: stub),
      GoRoute(path: '/:a/:b', builder: stub),
      GoRoute(path: '/:a/:b/:c', builder: stub),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        hapticsEnabledProvider.overrideWith((ref) => false),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(signedInUserId: 'u1', profile: user ?? profile()),
        ),
      ],
      child: MaterialApp.router(theme: theme ?? TellyTheme.dark, routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  Color? iconColorIn(WidgetTester tester, Key key) =>
      tester.widget<Icon>(find.descendant(of: find.byKey(key), matching: find.byType(Icon)).first).color;

  group('#114: SCR-22 More hub', () {
    testWidgets('shows the header, profile card, Queue tile, feature tiles and Settings, in order', (tester) async {
      await pumpHub(tester);
      expect(find.text('More'), findsOneWidget);
      expect(find.text('Jordan Miller'), findsOneWidget);
      expect(find.text('@jordan · View profile'), findsOneWidget);
      expect(find.text('Queue'), findsOneWidget);
      expect(find.text('Your watchlist and custom lists'), findsOneWidget);
      expect(find.text('Wrapped'), findsOneWidget);
      expect(find.text('Graveyard'), findsOneWidget);
      expect(find.text('Settings and account'), findsOneWidget);

      double top(Key k) => tester.getTopLeft(find.byKey(k)).dy;
      expect(top(const Key('more_profile_card')), lessThan(top(const Key('more_tile_queue'))));
      expect(top(const Key('more_tile_queue')), lessThan(top(const Key('more_tile_wrapped'))));
      expect(top(const Key('more_tile_wrapped')), lessThan(top(const Key('more_row_settings'))));
    });

    testWidgets('ships no placeholders for unbuilt features', (tester) async {
      await pumpHub(tester);
      for (final text in ['Soon', 'Achievements', 'Invite friends', 'Telly Pro', 'Help and feedback']) {
        expect(find.text(text), findsNothing, reason: text);
      }
    });

    testWidgets('Queue tile is full width; feature tiles split the row and are 104 tall', (tester) async {
      await pumpHub(tester);
      final queue = tester.getRect(find.byKey(const Key('more_tile_queue')));
      expect(queue.left, 16);
      expect(queue.right, 390 - 16);
      final wrapped = tester.getRect(find.byKey(const Key('more_tile_wrapped')));
      final graveyard = tester.getRect(find.byKey(const Key('more_tile_graveyard')));
      expect(wrapped.height, 104);
      expect(graveyard.height, 104);
      expect(wrapped.width, closeTo(graveyard.width, 0.01));
      expect(graveyard.left - wrapped.right, 12);
      expect(tester.getSize(find.byKey(const Key('more_row_settings'))).height, 52);
    });

    testWidgets('profile avatar is 56dp', (tester) async {
      await pumpHub(tester);
      expect(tester.getSize(find.byType(TellyAvatar)), const Size(56, 56));
    });

    testWidgets('uses the dark tokens and semantic accents', (tester) async {
      await pumpHub(tester);
      final card = tester.widget<Material>(
        find.descendant(of: find.byKey(const Key('more_tile_queue')), matching: find.byType(Material)).first,
      );
      expect(card.color, TellyColors.backgroundSurface);
      expect((card.shape! as RoundedRectangleBorder).side.color, TellyColors.strokeSubtle);
      expect((card.shape! as RoundedRectangleBorder).borderRadius, BorderRadius.circular(16));
      expect(iconColorIn(tester, const Key('more_tile_queue')), TellyColors.phosphorLime);
      expect(iconColorIn(tester, const Key('more_tile_wrapped')), TellyColors.phosphorLime);
      expect(iconColorIn(tester, const Key('more_tile_graveyard')), TellyColors.neonCoral);
    });

    testWidgets('uses the light tokens and accents', (tester) async {
      await pumpHub(tester, theme: TellyTheme.light);
      final card = tester.widget<Material>(
        find.descendant(of: find.byKey(const Key('more_tile_queue')), matching: find.byType(Material)).first,
      );
      expect(card.color, TellyColors.lightBackgroundSurface);
      expect((card.shape! as RoundedRectangleBorder).side.color, TellyColors.lightStrokeSubtle);
      expect(iconColorIn(tester, const Key('more_tile_queue')), TellyColors.lightPhosphorLime);
      expect(iconColorIn(tester, const Key('more_tile_graveyard')), TellyColors.lightNeonCoral);
      expect(tester.widget<Text>(find.text('Jordan Miller')).style!.color, TellyColors.lightTextPrimary);
    });

    for (final (key, target) in [
      (const Key('more_profile_card'), Routes.canon),
      (const Key('more_tile_queue'), Routes.queue),
      (const Key('more_tile_wrapped'), Routes.wrapped),
      (const Key('more_tile_graveyard'), Routes.graveyard),
      (const Key('more_row_settings'), Routes.settings),
    ]) {
      testWidgets('${key.toString()} opens $target', (tester) async {
        await pumpHub(tester);
        await tester.tap(find.byKey(key));
        await tester.pumpAndSettle();
        expect(find.text('route:$target'), findsOneWidget);
      });
    }

    testWidgets('callbacks override the default destinations', (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(FakeAuthRepository(signedInUserId: 'u1'))],
        child: MaterialApp(
          theme: TellyTheme.dark,
          home: MoreHubScreen(
            onProfileTap: () => taps.add('profile'),
            onQueueTap: () => taps.add('queue'),
            onWrappedTap: () => taps.add('wrapped'),
            onGraveyardTap: () => taps.add('graveyard'),
            onSettingsTap: () => taps.add('settings'),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      for (final k in [
        'more_profile_card',
        'more_tile_queue',
        'more_tile_wrapped',
        'more_tile_graveyard',
        'more_row_settings'
      ]) {
        await tester.tap(find.byKey(Key(k)));
      }
      expect(taps, ['profile', 'queue', 'wrapped', 'graveyard', 'settings']);
    });

    testWidgets('falls back to the initial avatar and a plain "View profile" without a photo or handle',
        (tester) async {
      await pumpHub(tester, user: profile(username: null, displayName: 'Sam'));
      expect(find.text('View profile'), findsOneWidget);
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.foregroundImage, isNull);
      expect(find.text('S'), findsOneWidget);
    });

    testWidgets('announces each entry as a labelled button', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHub(tester);
      expect(find.bySemanticsLabel('Jordan Miller, @jordan · View profile'), findsOneWidget);
      expect(find.bySemanticsLabel('Queue, your watchlist and custom lists'), findsOneWidget);
      expect(find.bySemanticsLabel('Wrapped, Your year in rankings'), findsOneWidget);
      expect(find.bySemanticsLabel('Graveyard, Dropped and DNF'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Queue, your watchlist and custom lists')),
        isSemantics(label: 'Queue, your watchlist and custom lists', isButton: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Settings and account')),
        isSemantics(label: 'Settings and account', isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });
  });
}
