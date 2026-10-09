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
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/features/achievements/data/achievements_repository.dart';
import 'package:telly_app/features/achievements/domain/medal.dart';

import 'package:telly_app/features/tracking/data/tracking_repository.dart';
import 'package:telly_app/features/tracking/domain/tracking_item.dart';
import 'package:telly_app/features/tracking/domain/tracking_models.dart';
import 'package:telly_app/features/tracking/presentation/providers/tracking_providers.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_tracking_repository.dart';
import '../achievements/achievements_fixtures.dart';

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
  Future<void> pumpHub(WidgetTester tester,
      {ThemeData? theme, UserProfile? user, AchievementsSnapshot? medals, List<TrackingItem> tracked = const []}) async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
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
        databaseProvider.overrideWithValue(db),
        trackingRepositoryProvider.overrideWithValue(FakeTrackingRepository(tracked)),
        trackingNowProvider.overrideWithValue(() => DateTime(2026, 10, 9, 12)),
        achievementsRepositoryProvider.overrideWithValue(FakeAchievementsRepository(medals ?? sampleSnapshot(empty: true))),
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
      expect(find.text('Achievements'), findsOneWidget);
      expect(find.text('Challenges'), findsOneWidget);
      expect(find.text('Your level'), findsOneWidget);
      expect(find.text('Wrapped'), findsOneWidget);
      expect(find.text('Graveyard'), findsOneWidget);
      expect(find.text('Settings and account'), findsOneWidget);

      double top(Key k) => tester.getTopLeft(find.byKey(k)).dy;
      expect(top(const Key('more_profile_card')), lessThan(top(const Key('more_tile_queue'))));
      expect(top(const Key('more_tile_queue')), lessThan(top(const Key('more_tile_achievements'))));
      // #137 / #144: Achievements and Challenges lead the feature grid, then Wrapped and Graveyard.
      expect(top(const Key('more_tile_achievements')), top(const Key('more_tile_challenges')));
      expect(tester.getTopLeft(find.byKey(const Key('more_tile_achievements'))).dx,
          lessThan(tester.getTopLeft(find.byKey(const Key('more_tile_challenges'))).dx));
      // #146: Your level follows, beside Wrapped; Graveyard closes the grid.
      expect(top(const Key('more_tile_challenges')), lessThan(top(const Key('more_tile_level'))));
      expect(top(const Key('more_tile_level')), top(const Key('more_tile_wrapped')));
      expect(top(const Key('more_tile_wrapped')), lessThan(top(const Key('more_tile_graveyard'))));
      expect(top(const Key('more_tile_wrapped')), lessThan(top(const Key('more_row_settings'))));
    });

    testWidgets('ships no placeholders for unbuilt features', (tester) async {
      await pumpHub(tester);
      for (final text in ['Soon', 'Invite friends', 'Telly Pro', 'Help and feedback']) {
        expect(find.text(text), findsNothing, reason: text);
      }
    });

    testWidgets('Queue tile is full width; feature tiles split the row and are 104 tall', (tester) async {
      await pumpHub(tester);
      final queue = tester.getRect(find.byKey(const Key('more_tile_queue')));
      expect(queue.left, 16);
      expect(queue.right, 390 - 16);
      final achievements = tester.getRect(find.byKey(const Key('more_tile_achievements')));
      final challenges = tester.getRect(find.byKey(const Key('more_tile_challenges')));
      final level = tester.getRect(find.byKey(const Key('more_tile_level')));
      final wrapped = tester.getRect(find.byKey(const Key('more_tile_wrapped')));
      final graveyard = tester.getRect(find.byKey(const Key('more_tile_graveyard')));
      for (final tile in [achievements, challenges, level, wrapped, graveyard]) {
        expect(tile.height, 104);
        expect(tile.width, closeTo(wrapped.width, 0.01));
      }
      expect(challenges.left - achievements.right, 12);
      expect(wrapped.left - level.right, 12);
      expect(level.top - achievements.bottom, 12);
      // The odd last tile keeps half the width, on the left.
      expect(graveyard.left, achievements.left);
      expect(graveyard.top - level.bottom, 12);
      expect(tester.getSize(find.byKey(const Key('more_row_settings'))).height, 52);
    });

    testWidgets("#138: pinned medals sit under the handle and join the card's label", (tester) async {
      await pumpHub(tester, medals: sampleSnapshot());
      expect(find.byKey(const Key('more_profile_medals')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('more_profile_medals'))).dy,
        greaterThan(tester.getTopLeft(find.text('@jordan · View profile')).dy),
      );
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Jordan Miller, @jordan · View profile, Pinned medals: Upset Artist, Ticket Stub'),
          findsOneWidget);
      handle.dispose();
    });

    testWidgets('#138: no unlocks, no medal row', (tester) async {
      await pumpHub(tester);
      expect(find.byKey(const Key('more_profile_medals')), findsNothing);
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
      expect(iconColorIn(tester, const Key('more_tile_achievements')), TellyColors.warmAmber);
      expect(iconColorIn(tester, const Key('more_tile_challenges')), TellyColors.electricCyan);
      expect(iconColorIn(tester, const Key('more_tile_level')), TellyColors.phosphorLime);
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
      expect(iconColorIn(tester, const Key('more_tile_achievements')), TellyColors.lightWarmAmber);
      expect(iconColorIn(tester, const Key('more_tile_challenges')), TellyColors.lightElectricCyan);
      expect(iconColorIn(tester, const Key('more_tile_level')), TellyColors.lightPhosphorLime);
      expect(tester.widget<Text>(find.text('Jordan Miller')).style!.color, TellyColors.lightTextPrimary);
    });

    for (final (key, target) in [
      (const Key('more_profile_card'), '/u/jordan'),
      (const Key('more_tile_queue'), Routes.queue),
      (const Key('more_watching_tile'), Routes.watching),
      (const Key('more_tile_achievements'), Routes.achievements),
      (const Key('more_tile_challenges'), Routes.challenges),
      (const Key('more_tile_level'), Routes.level),
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
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final taps = <String>[];
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository(signedInUserId: 'u1')),
          trackingRepositoryProvider.overrideWithValue(FakeTrackingRepository()),
        ],
        child: MaterialApp(
          theme: TellyTheme.dark,
          home: MoreHubScreen(
            onProfileTap: () => taps.add('profile'),
            onQueueTap: () => taps.add('queue'),
            onWatchingTap: () => taps.add('watching'),
            onAchievementsTap: () => taps.add('achievements'),
            onChallengesTap: () => taps.add('challenges'),
            onLevelTap: () => taps.add('level'),
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
        'more_watching_tile',
        'more_tile_achievements',
        'more_tile_challenges',
        'more_tile_level',
        'more_tile_wrapped',
        'more_tile_graveyard',
        'more_row_settings'
      ]) {
        await tester.tap(find.byKey(Key(k)));
      }
      expect(taps, ['profile', 'queue', 'watching', 'achievements', 'challenges', 'level', 'wrapped', 'graveyard', 'settings']);
    });

    group('Watching tile (#231)', () {
      final now = DateTime(2026, 10, 9, 12);
      var id = 1;
      TrackingItem show(String title, {int idle = 1, DateTime? newSince, EpisodeRef next = const EpisodeRef(2, 6), int watched = 5}) =>
          TrackingItem(
            titleId: id++,
            mediaType: 'tv',
            title: title,
            state: TrackingState.watching,
            startedAt: now.subtract(const Duration(days: 90)),
            lastProgressAt: now.subtract(Duration(days: idle)),
            newEpisodesSince: newSince,
            place: const EpisodeRef(2, 5),
            nextEpisode: NextEpisode(ref: next),
            airedTotal: 10,
            watched: watched,
          );

      String subtitle(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('more_watching_subtitle'))).data!;

      testWidgets('sits second, full width, under Queue and above the feature tiles', (tester) async {
        await pumpHub(tester);
        double top(Key k) => tester.getTopLeft(find.byKey(k)).dy;
        expect(top(const Key('more_tile_queue')), lessThan(top(const Key('more_watching_tile'))));
        expect(top(const Key('more_watching_tile')), lessThan(top(const Key('more_tile_achievements'))));
        expect(tester.getSize(find.byKey(const Key('more_watching_tile'))).width, tester.getSize(find.byKey(const Key('more_tile_queue'))).width);
      });

      testWidgets('empty: the prompt, and no bars', (tester) async {
        await pumpHub(tester);
        expect(subtitle(tester), "Track what you're watching");
        expect(find.byKey(const Key('more_watching_bars')), findsNothing);
      });

      testWidgets('new episodes come first', (tester) async {
        await pumpHub(tester, tracked: [show('A', newSince: now), show('B', newSince: now), show('C')]);
        expect(subtitle(tester), '2 new episodes');
        await tester.pumpWidget(const SizedBox());
        await pumpHub(tester, tracked: [show('A', newSince: now)]);
        expect(subtitle(tester), '1 new episode');
      });

      testWidgets('in progress names the latest show and its next episode', (tester) async {
        await pumpHub(tester, tracked: [show('Old', idle: 9), show('Severance', idle: 1), show('Other', idle: 4)]);
        expect(subtitle(tester), '3 in progress · Severance S2 · E6 next');
      });

      testWidgets('one bar per in-progress series, at most six', (tester) async {
        await pumpHub(tester, tracked: [for (var i = 0; i < 8; i++) show('S$i', idle: i + 1)]);
        expect(find.descendant(of: find.byKey(const Key('more_watching_bars')), matching: find.byType(LinearProgressIndicator)), findsNWidgets(6));
      });

      testWidgets('everything finished reads All caught up', (tester) async {
        final done = show('Done').copyWith(state: TrackingState.caughtUp);
        await pumpHub(tester, tracked: [done]);
        expect(subtitle(tester), 'All caught up');
      });

      testWidgets('announces itself with the live subtitle', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpHub(tester, tracked: [show('Severance')]);
        expect(find.bySemanticsLabel('Watching, 1 in progress · Severance S2 · E6 next'), findsOneWidget);
        handle.dispose();
      });
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
      expect(find.bySemanticsLabel('Achievements, Medals and your streak'), findsOneWidget);
      expect(find.bySemanticsLabel('Challenges, Race friends to the finish'), findsOneWidget);
      expect(find.bySemanticsLabel('Your level, XP, quests and rewards'), findsOneWidget);
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
