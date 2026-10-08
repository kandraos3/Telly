// Explore rows end to end (#183, epic #46; features/07 §7). Shared by the device suite
// (integration_test/explore_rows_test.dart, on the emulator CUJ job) and the host runner
// (test/integration/explore_journeys_test.dart), so they also run on every `flutter test`.
//
// The client is real end to end: the whole app, its router, Drift's ExploreCache, the
// controller and the ranker. Only the server is faked: FakeDiscoveryRepository answers
// get_explore_candidates with the sample payloads and records Not for me dismissals.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/app.dart';
import 'package:telly_app/core/config/app_config.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/sync/connectivity_signal.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/features/discovery/data/discovery_repository.dart';
import 'package:telly_app/features/discovery/data/explore_sample_payloads.dart';
import 'package:telly_app/features/discovery/presentation/controllers/explore_rows_controller.dart';
import 'package:telly_app/features/discovery/presentation/screens/explore_row_screen.dart';
import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/queue/data/watchlist_repository.dart';
import 'package:telly_app/features/logging/domain/title_search_result.dart';
import 'package:telly_app/features/ranking/data/canon_hydration.dart';
import 'package:telly_app/features/ranking/data/ranking_repository.dart';
import 'package:telly_app/features/title_detail/data/title_detail_repository.dart';
import 'package:telly_app/features/title_detail/domain/title_detail_models.dart';
import 'package:telly_app/features/title_detail/presentation/screens/show_detail_screen.dart';

import '../../test/fakes/fake_auth_repository.dart';
import '../../test/fakes/fake_social_repository.dart';
import '../../test/fakes/fake_watchlist_repository.dart';

const _me = 'usr_explore';
final _today = DateTime(2026, 10, 8, 12);

class _EmptyRemoteCanon implements RemoteCanonSource {
  @override
  Future<List<RemoteRanking>> fetchMyCanon(String userId) async => const [];
}

/// Launches the whole app, signed in and onboarded, with [discovery] as Explore's server.
Future<void> _launch(WidgetTester tester, FakeDiscoveryRepository discovery) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db = AppDatabase.inMemory();
  addTearDown(db.close);
  // Every sample title has a detail page, so SCR-08 opens from any card.
  final details = FakeTitleDetailRepository([
    for (final (mediaType, payload) in [('movie', sampleMoviePayload(_today)), ('tv', sampleSeriesPayload(_today))])
      for (final c in payload['candidates'] as List)
        TitleDetail(id: (c as Map)['title_id'] as int, mediaType: mediaType, title: c['title'] as String),
  ]);
  final container = ProviderContainer(overrides: [
    databaseProvider.overrideWithValue(db),
    authRepositoryProvider.overrideWithValue(FakeAuthRepository(
      signedInUserId: _me,
      profile: UserProfile(
          id: _me, username: 'explorer', displayName: 'Explorer', onboardingCompleted: true, createdAt: DateTime(2026)),
    )),
    appConfigProvider.overrideWithValue(const AppConfig(
      appEnv: 'test',
      supabaseUrl: 'https://test.supabase.co',
      supabaseAnonKey: 'test-anon-key',
    )),
    hapticsEnabledProvider.overrideWith((ref) => false),
    connectivityProvider.overrideWith((ref) => Stream.value(true)),
    remoteCanonSourceProvider.overrideWithValue(_EmptyRemoteCanon()),
    posterNetworkImagesProvider.overrideWithValue(false),
    discoveryRepositoryProvider.overrideWithValue(discovery),
    exploreNowProvider.overrideWithValue(() => _today),
    socialRepositoryProvider.overrideWithValue(FakeSocialRepository(me: _me)),
    watchlistRepositoryProvider.overrideWithValue(FakeWatchlistRepository()),
    titleDetailRepositoryProvider.overrideWithValue(details),
    titleCreditsProvider.overrideWith((ref, _) async => TitleCredits.empty),
    titleStreamingProvider.overrideWith((ref, _) async => const []),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const TellyApp()));
  await _pumpFor(tester);
}

Future<void> _pumpFor(WidgetTester tester, [int frames = 20]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps until [finder] shows, or fails after ~10 s of frames.
Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  await _scrollTo(tester, finder.first);
  await tester.tap(finder.first);
  await _pumpFor(tester, 10);
}

/// Drags the screen until [finder] sits in its middle band, clear of the header and nav bar.
/// (Explore's floating-header scroll view doesn't move for `ensureVisible`.)
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  for (var i = 0; i < 20; i++) {
    final y = tester.getCenter(finder).dy;
    if (y > height * 0.15 && y < height * 0.75) return;
    await tester.dragFrom(Offset(20, height / 2), Offset(0, y > height / 2 ? -height / 3 : height / 3));
    await _pumpFor(tester, 5);
  }
}

Finder _keyStartsWith(String prefix) =>
    find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith(prefix));

/// The hero's title: the widget under `explore_hero` with the hero's 26 dp title style.
String _heroTitle(WidgetTester tester) {
  final texts = find.descendant(of: find.byKey(const Key('explore_hero')), matching: find.byType(Text));
  return tester.widgetList<Text>(texts).firstWhere((t) => t.style?.fontSize == 26).data!;
}

void exploreJourneys() {
  testWidgets('Explore: Series, a Because row\'s See all, a title, and back', (tester) async {
    await _launch(tester, FakeDiscoveryRepository());

    await _tap(tester, find.byKey(const Key('nav_tab_explore')));
    await _waitFor(tester, find.byKey(const Key('explore_hero')));
    await _tap(tester, find.byKey(const Key('explore_canon_tv')));
    await _waitFor(tester, find.byKey(const Key('explore_rows_tv')));

    await _tap(tester, _keyStartsWith('explore_see_all_becauseYouRanked-'));
    await _waitFor(tester, find.byType(ExploreRowScreen));
    expect(find.textContaining('Because you ranked '), findsOneWidget);

    final card = _keyStartsWith('explore_card_');
    final titleId = int.parse((tester.widget(card.first).key! as ValueKey<String>).value.split('_').last);
    await _tap(tester, card);
    await _waitFor(tester, find.byType(ShowDetailScreen));
    expect(tester.widget<ShowDetailScreen>(find.byType(ShowDetailScreen)).titleId, titleId);
    expect(tester.widget<ShowDetailScreen>(find.byType(ShowDetailScreen)).mediaType, 'tv');

    await tester.pageBack();
    await _pumpFor(tester);
    expect(find.byType(ShowDetailScreen), findsNothing);
    expect(find.byType(ExploreRowScreen), findsOneWidget);

    await tester.pageBack();
    await _pumpFor(tester);
    expect(find.byType(ExploreRowScreen), findsNothing);
    expect(find.byKey(const Key('explore_rows_tv')), findsOneWidget, reason: 'back on Explore, still on Series');
  });

  testWidgets('Explore: the hero\'s Not for me hides it, and Undo brings it back', (tester) async {
    final discovery = FakeDiscoveryRepository();
    await _launch(tester, discovery);

    await _tap(tester, find.byKey(const Key('nav_tab_explore')));
    await _waitFor(tester, find.byKey(const Key('explore_hero')));
    final hero = _heroTitle(tester);

    await _tap(tester, find.byKey(const Key('explore_hero_dismiss')));
    await _waitFor(tester, find.byKey(const Key('explore_dismissed_snackbar')));
    expect(find.text('Hidden from your picks: $hero'), findsOneWidget);
    expect(_heroTitle(tester), isNot(hero), reason: 'the next pick takes the hero');
    expect(discovery.dismissed, hasLength(1));

    // The snackbar floats over the page, so it is tapped where it is, before it times out.
    await tester.tap(find.text('Undo'));
    await _pumpFor(tester, 10);
    expect(_heroTitle(tester), hero);
    expect(discovery.dismissed, isEmpty);
  });
}
