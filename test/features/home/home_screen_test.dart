import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/home/presentation/screens/home_screen.dart';
import 'package:telly_app/features/profile/presentation/controllers/profile_controller.dart';
import 'package:telly_app/features/ranking/domain/canon_tier.dart';
import 'package:telly_app/features/ranking/domain/canon_type.dart';
import 'package:telly_app/features/ranking/domain/franchise_rollup_service.dart';
import 'package:telly_app/features/ranking/presentation/widgets/canon_tier_style.dart';

import '../../fakes/fake_social_repository.dart';

/// Fixed canon state for screen tests.
class _SeededCanon extends ProfileCanonNotifier {
  _SeededCanon(this.seed);
  final ProfileCanonState seed;

  @override
  ProfileCanonState build() => seed;
}

/// A social repository whose feed never loads (loading state) or always fails (offline).
class _StuckSocialRepository extends FakeSocialRepository {
  _StuckSocialRepository({this.fail = false});
  final bool fail;

  @override
  Future<FeedPage> getFeedPage({required FeedFilter filter, ActivityLog? after, int limit = 20}) =>
      fail ? Future.error(Exception('offline')) : Completer<FeedPage>().future;
}

CanonEntry _entry(int id, String title, String mediaType, int rank, double score) => CanonEntry(
      id: id,
      title: title,
      mediaType: mediaType,
      rankPosition: rank,
      calculatedScore: score,
    );

final _movies = [
  _entry(1, 'Past Lives', 'movie', 1, 9.80),
  _entry(2, 'Arrival', 'movie', 2, 9.10),
  _entry(3, 'Heat', 'movie', 3, 8.40),
  _entry(4, 'Tenet', 'movie', 4, 7.10),
];
final _series = [
  _entry(11, 'Severance', 'tv', 1, 9.90),
  _entry(12, 'The Bear', 'tv', 2, 9.00),
];

void main() {
  late ProviderContainer container;

  Future<void> pumpHome(
    WidgetTester tester, {
    ProfileCanonState? canon,
    SocialRepository? social,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget stub(BuildContext _, GoRouterState state) => Scaffold(body: Text('route:${state.uri}'));
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/:a', builder: stub),
      GoRoute(path: '/:a/:b', builder: stub),
      GoRoute(path: '/:a/:b/:c', builder: stub),
    ]);
    container = ProviderContainer(overrides: [
      hapticsEnabledProvider.overrideWith((ref) => false),
      profileCanonProvider.overrideWith(
        () => _SeededCanon(canon ?? ProfileCanonState(movies: _movies, series: _series)),
      ),
      socialRepositoryProvider.overrideWithValue(
        social ??
            FakeSocialRepository(feed: [
              fakeActivity('a1', username: 'maya', title: 'The Bear', minutesAgo: 1),
              fakeActivity('a2', username: 'jordan', title: 'Severance', minutesAgo: 2),
              fakeActivity('a3', username: 'sam', title: 'Shogun', minutesAgo: 3),
              fakeActivity('a4', username: 'lee', title: 'Fargo', minutesAgo: 4),
            ]),
      ),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: theme ?? TellyTheme.dark, routerConfig: router),
    ));
    await tester.pump();
    await tester.pump();
  }

  group('#115: SCR-21 Home — your canon', () {
    testWidgets('shows the header with Search and the top 3 of the movie canon', (tester) async {
      await pumpHome(tester);
      expect(find.text('Home'), findsOneWidget);
      expect(find.byKey(const Key('home_search_button')), findsOneWidget);
      expect(find.text('YOUR CANON'), findsOneWidget);
      for (final id in [1, 2, 3]) {
        expect(find.byKey(Key('grid_poster_$id')), findsOneWidget);
      }
      expect(find.byKey(const Key('grid_poster_4')), findsNothing);
      expect(find.byKey(const Key('grid_poster_11')), findsNothing);
    });

    testWidgets('the toggle switches to the series canon only (never mixed)', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('home_canon_series')));
      await tester.pump();
      expect(container.read(selectedCanonProvider), CanonType.series);
      expect(find.byKey(const Key('grid_poster_11')), findsOneWidget);
      expect(find.byKey(const Key('grid_poster_12')), findsOneWidget);
      for (final id in [1, 2, 3]) {
        expect(find.byKey(Key('grid_poster_$id')), findsNothing);
      }
    });

    testWidgets('an empty canon offers "Log your first title" with a Log button', (tester) async {
      await pumpHome(tester, canon: ProfileCanonState(series: _series));
      expect(find.text('Log your first title to start your canon'), findsOneWidget);
      await tester.tap(find.byKey(const Key('home_canon_empty_log')));
      await tester.pumpAndSettle();
      expect(find.text('route:${Routes.log}'), findsOneWidget);
    });

    testWidgets('shows skeleton tiles while the canon loads', (tester) async {
      await pumpHome(tester, canon: const ProfileCanonState(isLoading: true));
      expect(find.byKey(const Key('home_canon_loading')), findsOneWidget);
      expect(find.byKey(const Key('home_canon_empty')), findsNothing);
    });

    testWidgets('See all opens the Canon tab', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('home_canon_see_all')));
      await tester.pumpAndSettle();
      expect(find.text('route:${Routes.canon}'), findsOneWidget);
    });

    testWidgets('a poster opens its title', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('grid_poster_2')));
      await tester.pumpAndSettle();
      expect(find.text('route:${Routes.title('movie', 2)}'), findsOneWidget);
    });
  });

  group('#115: SCR-21 Home — from your friends', () {
    testWidgets('shows the 3 newest Following items as compact rows', (tester) async {
      await pumpHome(tester);
      expect(find.text('FROM YOUR FRIENDS'), findsOneWidget);
      expect(find.byKey(const Key('home_friend_row_a1')), findsOneWidget);
      expect(find.byKey(const Key('home_friend_row_a2')), findsOneWidget);
      expect(find.byKey(const Key('home_friend_row_a3')), findsOneWidget);
      expect(find.byKey(const Key('home_friend_row_a4')), findsNothing);
      expect(find.textContaining('ranked The Bear #2', findRichText: true), findsOneWidget);
    });

    testWidgets('score chips use the tier colour and tabular figures', (tester) async {
      await pumpHome(tester);
      final chip = tester.widget<Container>(find.byKey(const Key('home_score_chip')).first);
      final tier = CanonTier.fromScore(9.72);
      expect((chip.decoration! as BoxDecoration).border!.top.color, tier.accent);
      expect(find.text('9.72'), findsNWidgets(3));
    });

    testWidgets('a row opens its title; See all opens Social', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('home_friend_row_a1')));
      await tester.pumpAndSettle();
      expect(find.text('route:${Routes.title('tv', 110492)}'), findsOneWidget);
    });

    testWidgets('See all opens the Social feed', (tester) async {
      await pumpHome(tester);
      await tester.ensureVisible(find.byKey(const Key('home_friends_see_all')));
      await tester.tap(find.byKey(const Key('home_friends_see_all')));
      await tester.pumpAndSettle();
      expect(find.text('route:${Routes.feed}'), findsOneWidget);
    });

    testWidgets('no friends activity offers "Find friends in Social"', (tester) async {
      await pumpHome(tester, social: FakeSocialRepository());
      expect(find.text('Find friends in Social'), findsOneWidget);
      await tester.tap(find.byKey(const Key('home_friends_empty_action')));
      await tester.pumpAndSettle();
      expect(find.text('route:${Routes.feed}'), findsOneWidget);
    });

    testWidgets('shows skeleton rows while the feed loads', (tester) async {
      await pumpHome(tester, social: _StuckSocialRepository());
      expect(find.byKey(const Key('home_friends_loading')), findsOneWidget);
    });

    testWidgets('offline with nothing loaded hides the section; the canon still shows', (tester) async {
      await pumpHome(tester, social: _StuckSocialRepository(fail: true));
      expect(find.byKey(const Key('home_friends_hidden')), findsOneWidget);
      expect(find.text('FROM YOUR FRIENDS'), findsNothing);
      expect(find.byKey(const Key('grid_poster_1')), findsOneWidget);
    });

    testWidgets('rows are labelled, tappable buttons', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHome(tester);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Maya ranked The Bear #2, score 9.72')),
        isSemantics(label: 'Maya ranked The Bear #2, score 9.72', isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('renders with light tokens', (tester) async {
      await pumpHome(tester, theme: TellyTheme.light);
      final row = tester.widget<Material>(find.byKey(const Key('home_friend_row_a1')));
      expect(row.color, TellyColors.lightBackgroundSurface);
      expect((row.shape! as RoundedRectangleBorder).side.color, TellyColors.lightStrokeSubtle);
    });
  });
}
