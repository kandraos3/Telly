import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/logging/data/title_repository.dart';
import 'package:telly_app/features/logging/domain/title_search_result.dart';
import 'package:telly_app/features/logging/presentation/controllers/logging_session_controller.dart';
import 'package:telly_app/features/logging/presentation/screens/log_flow_screens.dart';
import 'package:telly_app/features/logging/presentation/screens/logging_studio_screen.dart';
import 'package:telly_app/features/profile/presentation/screens/dual_canon_profile_screen.dart';
import 'package:telly_app/features/ranking/domain/sentiment_bracket.dart';
import 'package:telly_app/features/sharing/data/story_share_service.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_title_repository.dart';
import '../../helpers/canon_seed.dart';

void main() {
  late AppDatabase db;
  late FakeStoryShareService stories;
  setUp(() {
    db = AppDatabase.inMemory();
    stories = FakeStoryShareService();
  });
  tearDown(() => db.close());

  Future<(ProviderContainer, GoRouter)> pumpFlow(WidgetTester tester, {String initial = Routes.log}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      hapticsEnabledProvider.overrideWith((ref) => false),
      titleRepositoryProvider.overrideWithValue(FakeTitleRepository()),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(signedInUserId: 'u1')),
      storyShareServiceProvider.overrideWithValue(stories),
    ]);
    addTearDown(container.dispose);
    Widget stub(BuildContext _, GoRouterState s) => Scaffold(body: Text('route:${s.uri}'));
    final router = GoRouter(initialLocation: initial, routes: [
      GoRoute(path: Routes.canon, builder: (_, __) => const DualCanonProfileScreen()),
      GoRoute(path: Routes.feed, builder: stub),
      GoRoute(
        path: Routes.log,
        builder: (_, s) => LoggingStudioScreen(initialTitle: s.extra as TitleSearchResult?),
        routes: [
          GoRoute(path: 'duel', builder: (_, __) => const LogDuelScreen()),
          GoRoute(path: 'reveal', builder: (_, __) => const LogRevealScreen()),
        ],
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: TellyTheme.dark, routerConfig: router),
    ));
    await tester.pumpAndSettle();
    return (container, router);
  }

  void draft(ProviderContainer c, TitleSearchResult title, SentimentBracket bracket) {
    c.read(loggingSessionProvider.notifier)
      ..selectTitle(title)
      ..setBracket(bracket);
  }

  group('FE-604: SCR-10 → SCR-11 → SCR-12', () {
    testWidgets('duel winner → editorial publish → slot reveal, persisted locally and queued', (tester) async {
      await seedCanon(db, 'tv', ['Succession'], baseId: 1);
      final (c, router) = await pumpFlow(tester);
      draft(c, const TitleSearchResult(id: 136315, mediaType: 'tv', title: 'The Bear', releaseYear: '2022'),
          SentimentBracket.masterpiece);
      router.push(Routes.duel);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('candidate_card_a')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // SCR-11 editorial sheet
      expect(find.byKey(const Key('placed_canon_banner')), findsOneWidget);
      expect(find.textContaining('Christopher Storer'), findsWidgets, reason: 'director optional tag available');
      expect(find.byKey(const Key('mvp_character_dropdown')), findsOneWidget, reason: 'MVP dropdown present and optional');
      await tester.tap(find.byKey(const Key('editorial_skip_button')));
      await tester.pumpAndSettle();

      // SCR-12 reveal of the committed slot
      expect(find.byKey(const Key('slot_reveal_rank_text')), findsOneWidget);
      expect(find.textContaining('#1'), findsWidgets);
      // FE-SHARE-01: leaderboard snippet with the new title highlighted at #1.
      expect(find.byKey(const Key('reveal_leaderboard_snippet')), findsOneWidget);
      expect(find.byKey(const Key('reveal_leaderboard_row_1')), findsOneWidget);
      expect(find.byKey(const Key('reveal_leaderboard_row_2')), findsOneWidget);

      await tester.tap(find.byKey(const Key('share_story_button')));
      await tester.pumpAndSettle();
      final story = stories.sharedReveals.single;
      expect((story.title, story.rank, story.total, story.canonLabel), ('The Bear', 1, 2, 'Series Canon'));
      expect(story.leaderboard.where((e) => e.isNew).single.title, 'The Bear');

      final canon = await db.localRankingDao.getRankingsByCanon('tv');
      expect(canon.map((e) => e.title), ['The Bear', 'Succession']);
      final queue = await db.pendingMutationDao.getAllFifo();
      expect(queue.map((m) => m.kind), [MutationKind.logTitle, MutationKind.editorial]);
      final duels = (jsonDecode(queue.first.payload) as Map)['duels'] as List;
      expect(duels.single, containsPair('winner_title_id', 136315));

      await tester.tap(find.byKey(const Key('view_in_canon_button')));
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, Routes.canon);
    });

    testWidgets('opening /log/duel without a draft returns to SCR-09', (tester) async {
      final (_, router) = await pumpFlow(tester, initial: Routes.duel);
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, Routes.log);
      expect(find.byType(LoggingStudioScreen), findsOneWidget);
    });

    testWidgets('Reset Duels on a canon row re-opens SCR-09 with that title selected', (tester) async {
      await seedCanon(db, 'movie', ['Inception', 'Heat'], baseId: 27205);
      await pumpFlow(tester, initial: Routes.canon);

      await tester.longPress(find.byKey(const ValueKey('ranked_row_27206')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reset_duels_action')));
      await tester.pumpAndSettle();

      expect(find.byType(LoggingStudioScreen), findsOneWidget);
      expect(find.text('Selected: HEAT'), findsOneWidget);
      expect(find.byKey(const Key('status_firstTime')), findsOneWidget);
    });
  });
}
