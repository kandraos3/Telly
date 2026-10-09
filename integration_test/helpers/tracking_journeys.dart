// CUJ-06 tracking journey (#233, epic #168; features/11 §4, §11). Shared by the device suite
// (integration_test/cuj_06_tracking_test.dart) and the host runner
// (test/integration/tracking_journeys_test.dart), so it also runs on every `flutter test`.
//
// The client is real end to end: the real TrackingRepository over Drift's TrackingCache, the
// offline queue and the SyncEngine, and the real screens. Only the server is faked: [TrackingServer]
// applies the rules the RPCs implement, using the same progress functions that the shared vectors
// (test/fixtures/tracking_progress_vectors.json) hold equal to `_tracking_state` / `_tracking_move`
// in SQL, which pgTAP 035–038 verify against Postgres.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:telly_app/app.dart';
import 'package:telly_app/core/config/app_config.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/core/router/app_router.dart';
import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/sync/connectivity_signal.dart';
import 'package:telly_app/core/sync/mutation_transport.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/features/discovery/data/discovery_repository.dart';
import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/logging/domain/title_search_result.dart';
import 'package:telly_app/features/logging/domain/watch_status.dart';
import 'package:telly_app/features/logging/presentation/controllers/logging_session_controller.dart';
import 'package:telly_app/features/queue/data/streaming_availability_repository.dart';
import 'package:telly_app/features/queue/data/watchlist_repository.dart';
import 'package:telly_app/features/queue/domain/streaming_models.dart';
import 'package:telly_app/features/ranking/data/canon_hydration.dart';
import 'package:telly_app/features/ranking/data/ranking_repository.dart';
import 'package:telly_app/features/title_detail/data/title_detail_repository.dart';
import 'package:telly_app/features/title_detail/domain/title_detail_models.dart';
import 'package:telly_app/features/tracking/data/tracking_repository.dart';
import 'package:telly_app/features/tracking/domain/tracking_models.dart';
import 'package:telly_app/features/tracking/domain/tracking_progress.dart';
import 'package:telly_app/features/tracking/presentation/providers/tracking_providers.dart';

import '../../test/fakes/fake_auth_repository.dart';
import '../../test/fakes/fake_social_repository.dart';

const _me = 'usr_cuj06';
const _showId = 4242;

/// Today on the fake clock, and the day the journey starts.
final _today = DateTime(2026, 10, 9, 12);

class _EmptyRemoteCanon implements RemoteCanonSource {
  @override
  Future<List<RemoteRanking>> fetchMyCanon(String userId) async => const [];
}

class _NoStreaming implements StreamingAvailabilityRepository {
  @override
  Future<List<ShowStreamingAvailability>> getAvailability({
    required int titleId,
    required String mediaType,
    String? country,
  }) async =>
      const [];
}

/// "The Miniseries": one ended season of eight episodes, long since aired.
const _miniseries = TitleDetail(
  id: _showId,
  mediaType: 'tv',
  title: 'The Miniseries',
  status: 'Ended',
  overview: 'Eight episodes, one finale.',
  communityScore: 8.2,
  numberOfSeasons: 1,
  numberOfEpisodes: 8,
  seasons: [
    TitleSeasonDetail(
        seasonNumber: 1,
        name: 'Season 1',
        episodeCount: 8,
        airDate: '2000-01-01')
  ],
);

/// The server's view of one tracked series, and what the RPCs do to it (features/11 §6.2).
class _ServerRow {
  _ServerRow({this.place});
  EpisodeRef? place;
  bool ranked = false;
}

/// The server side of the journey: the sync transport plus what `get_my_tracking` would return.
class TrackingServer implements MutationTransport {
  final rows = <int, _ServerRow>{};
  final removedFromQueue = <int>[];
  final applied = <String>[];
  final _seen = <String>{};

  final _schedule = ShowSchedule(
    seasons: [SeasonInfo(number: 1, episodeCount: 8, airDate: DateTime(2000))],
    status: 'Ended',
  );

  EpisodeRef? _placeOf(Map<String, dynamic> p) {
    final s = p['last_season'], e = p['last_episode'];
    return s is int && e is int ? EpisodeRef(s, e) : null;
  }

  /// `_claim_mutation`: a replay of a mutation the server already applied does nothing (I-5).
  @override
  Future<void> apply(PendingMutation m) async {
    if (!_seen.add(m.id)) return;
    final p = jsonDecode(m.payload) as Map<String, dynamic>;
    final id = p['title_id'] as int?;
    switch (m.kind) {
      case MutationKind.trackingStart:
        rows[id!] =
            _ServerRow(place: TrackingProgress.clamp(_schedule, _placeOf(p)));
        removedFromQueue
            .add(id); // start_tracking also deletes the watchlist row
      case MutationKind.trackingPlace:
        rows[id!]?.place = TrackingProgress.clamp(_schedule, _placeOf(p));
      case MutationKind.trackingStop:
        rows.remove(id);
      case MutationKind.logTitle:
        rows[id]?.ranked = true;
      default:
        break;
    }
    applied.add(m.kind);
  }

  TrackingState stateOf(int id) =>
      TrackingProgress.seriesState(_schedule, rows[id]!.place, _today);

  /// One `get_my_tracking().items` element.
  Map<String, Object?> _item(int id, _ServerRow r) {
    final next = TrackingProgress.next(_schedule, r.place, _today);
    final last = TrackingProgress.lastAired(_schedule, _today);
    final state = stateOf(id);
    return {
      'title_id': id,
      'media_type': 'tv',
      'title': 'The Miniseries',
      'title_status': 'Ended',
      'state': state.dbValue,
      'last_season': r.place?.season,
      'last_episode': r.place?.episode,
      'is_rewatch': false,
      'started_at': _today.toIso8601String(),
      'last_progress_at': _today.toIso8601String(),
      'finished_at':
          state == TrackingState.finished ? _today.toIso8601String() : null,
      'seasons': [
        {'number': 1, 'episode_count': 8, 'air_date': '2000-01-01'},
      ],
      'watched': TrackingProgress.watchedCount(_schedule, r.place),
      'aired_total': TrackingProgress.airedTotal(_schedule, _today),
      'next_episode': next == null
          ? null
          : {'season': next.season, 'episode': next.episode},
      'last_aired': last == null
          ? null
          : {'season': last.season, 'episode': last.episode},
      'ranked': r.ranked,
    };
  }

  /// A Supabase client whose HTTP layer answers the reads the tracking repository makes.
  SupabaseClient client() => SupabaseClient(
        'http://supabase.test',
        'anon-key',
        httpClient: MockClient((req) async {
          Object? body;
          switch (req.url.path) {
            case '/rest/v1/rpc/get_my_tracking':
              body = {
                'today': '2026-10-09',
                'items': [for (final e in rows.entries) _item(e.key, e.value)],
              };
            case '/functions/v1/tmdb-season':
              body = {'episodes': <Object>[]};
            case '/rest/v1/rpc/get_tracking_stats':
              body = <String, Object?>{};
            default:
              body = <Object>[]; // get_title_watchers: nobody is watching
          }
          return http.Response(jsonEncode(body), 200,
              headers: {'content-type': 'application/json'}, request: req);
        }),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
}

/// Launches the whole app, signed in and onboarded, against [server]. [online] drives connectivity.
Future<ProviderContainer> launchAgainst(WidgetTester tester,
    TrackingServer server, StreamController<bool> online) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db = AppDatabase.inMemory();
  addTearDown(db.close);
  final repo =
      LocalFirstTrackingRepository(db, server.client(), clock: () => _today);
  final container = ProviderContainer(overrides: [
    databaseProvider.overrideWithValue(db),
    authRepositoryProvider.overrideWithValue(FakeAuthRepository(
      signedInUserId: _me,
      profile: UserProfile(
          id: _me,
          username: 'watcher',
          displayName: 'Watcher',
          onboardingCompleted: true,
          createdAt: DateTime(2026)),
    )),
    appConfigProvider.overrideWithValue(const AppConfig(
      appEnv: 'test',
      supabaseUrl: 'https://test.supabase.co',
      supabaseAnonKey: 'test-anon-key',
    )),
    hapticsEnabledProvider.overrideWith((ref) => false),
    connectivityProvider.overrideWith((ref) async* {
      yield true;
      yield* online.stream;
    }),
    remoteCanonSourceProvider.overrideWithValue(_EmptyRemoteCanon()),
    discoveryRepositoryProvider.overrideWithValue(FakeDiscoveryRepository()),
    socialRepositoryProvider.overrideWithValue(FakeSocialRepository(me: _me)),
    mutationTransportProvider.overrideWithValue(server),
    streamingAvailabilityRepositoryProvider.overrideWithValue(_NoStreaming()),
    titleDetailRepositoryProvider
        .overrideWithValue(FakeTitleDetailRepository([_miniseries])),
    titleCreditsProvider.overrideWith((ref, _) async => TitleCredits.empty),
    titleStreamingProvider.overrideWith((ref, _) async => const []),
    trackingRepositoryProvider.overrideWithValue(repo),
    // The real local-first Queue over Drift; its server reads hit the same fake HTTP layer.
    watchlistRepositoryProvider
        .overrideWithValue(LocalFirstWatchlistRepository(db, server.client())),
    trackingNowProvider.overrideWithValue(() => _today),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const TellyApp()));
  await _pumpFor(tester);
  return container;
}

/// Pumps frames (not pumpAndSettle: sheets and the app's tickers never settle).
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
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await _pumpFor(tester, 10);
}

/// Waits for the offline queue to drain to the server.
Future<void> _synced(WidgetTester tester, ProviderContainer c) async {
  final db = c.read(databaseProvider);
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (await tester.runAsync(() => db.pendingMutationDao.count()) == 0) return;
  }
  fail('the offline queue never drained');
}

Finder _eyebrow(String text) => find.byWidgetPredicate((w) =>
    w is Text && w.key == const Key('tracking_eyebrow') && w.data == text);

void trackingJourneys() {
  testWidgets(
      'CUJ-06: track a series from the Queue to a rank, undo a ✓, and un-log offline',
      (tester) async {
    final server = TrackingServer();
    final online = StreamController<bool>.broadcast();
    addTearDown(online.close);
    final c = await launchAgainst(tester, server, online);

    // The series is in the Queue.
    await tester.runAsync(() => c
        .read(watchlistRepositoryProvider)
        .add(titleId: _showId, mediaType: 'tv', title: 'The Miniseries'));

    // 1. Open it from the Queue, Start watching, I'm partway through S1 · E7 of 8.
    await _tap(tester, find.byKey(const Key('nav_tab_more')));
    await _tap(tester, find.byKey(const Key('more_tile_queue')));
    await _tap(tester, find.byKey(const Key('queue_series_tab')));
    await _tap(tester, find.byKey(const Key('queue_up_next_card')));
    await _tap(tester, find.byKey(const Key('title_watch_action')));
    await _waitFor(tester, find.byKey(const Key('where_are_you_sheet')));
    await _tap(tester, find.byKey(const Key('where_partway')));
    final picker = tester.widget<CupertinoPicker>(find.byKey(const ValueKey('episode_wheel_1')));
    picker.scrollController?.jumpToItem(6); // six episodes down -> S1 · E7
    await _pumpFor(tester, 10);
    expect(find.text('Season 1 · Episode 7'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('start_tracking_button')));
    await _synced(tester, c);

    expect(server.rows[_showId]!.place, const EpisodeRef(1, 7));
    expect(server.removedFromQueue, [_showId],
        reason: 'starting leaves the Queue');
    expect(
        await tester.runAsync(() =>
            c.read(watchlistRepositoryProvider).isInWatchlist(_showId, 'tv')),
        isFalse);
    expect(_eyebrow('● WATCHING · S1 · E8 NEXT'), findsOneWidget);

    // ...and Home's Currently watching says "S1 · E8".
    c.read(appRouterProvider).go(Routes.home);
    await _waitFor(tester, find.byKey(const Key('home_currently_watching')));
    expect(
      find.descendant(
          of: find.byKey(const Key('home_currently_watching')),
          matching: find.text('S1 · E8')),
      findsOneWidget,
    );
    expect(find.text('✓ E8'), findsOneWidget);

    // 2. ✓ Watched E8 ends the show, so the finish sheet opens. Later, then Undo: back at E7.
    await _tap(tester, find.byKey(const Key('home_watching_row_tv_$_showId')));
    await _tap(tester, find.byKey(const Key('watched_episode_button')));
    await _waitFor(tester, find.byKey(const Key('finish_sheet')));
    await _tap(tester, find.byKey(const Key('finish_later_button')));
    await _tap(tester, find.text('Undo'));
    await _synced(tester, c);
    expect(server.rows[_showId]!.place, const EpisodeRef(1, 7),
        reason: 'Undo sent the previous absolute place');
    expect(_eyebrow('● WATCHING · S1 · E8 NEXT'), findsOneWidget);

    // 3. ✓ Watched E8 again: the finish sheet opens with Finished whole series selected → Log and duel.
    await _tap(tester, find.byKey(const Key('watched_episode_button')));
    await _waitFor(tester, find.byKey(const Key('finish_sheet')));
    expect(
      find.descendant(
          of: find.byKey(const Key('finish_sheet')),
          matching: find.text('You finished The Miniseries')),
      findsOneWidget,
    );
    expect(
      find.descendant(
          of: find.byKey(const Key('finish_status_finished')),
          matching: find.byIcon(Icons.radio_button_checked)),
      findsOneWidget,
      reason: 'Finished whole series is preselected',
    );
    await _tap(tester, find.byKey(const Key('finish_log_button')));
    await _waitFor(tester, find.byKey(const Key('logging_selected_title')));
    final draft = c.read(loggingSessionProvider);
    expect(draft.title!.id, _showId);
    expect(draft.status, WatchStatus.finished,
        reason: 'SCR-09 opens with the status prefilled');

    // The duels end with the series placed in the Series Canon (the commit SCR-12 makes).
    await tester
        .runAsync(() => c.read(rankingRepositoryProvider).commitPlacement(
              candidate: const CanonCandidate(
                  titleId: _showId, mediaType: 'tv', title: 'The Miniseries'),
              targetRank: 1,
              duels: const [],
            ));
    await _synced(tester, c);
    expect(server.rows[_showId]!.place, const EpisodeRef(1, 8));
    expect(server.stateOf(_showId), TrackingState.finished);
    expect(server.rows[_showId]!.ranked, isTrue);

    // It is ranked, so the hub files it under Caught up.
    c.read(appRouterProvider).go(Routes.more);
    await _tap(tester, find.byKey(const Key('more_watching_tile')));
    await _waitFor(tester, find.text('CAUGHT UP · 1'));
    expect(find.byKey(const Key('hub_caught_up_pill')), findsOneWidget);
    expect(find.text('FINISHED, NOT RANKED · 1'), findsNothing);

    // 4. Offline, un-log E8 from the title page; online again, the server row goes back to E7.
    online.add(false);
    await _pumpFor(tester, 5);
    await _tap(tester, find.text('The Miniseries'));
    await _waitFor(tester, find.byKey(const Key('episode_row_1_8')));
    await tester.drag(
        find.byType(CustomScrollView).last, const Offset(0, -600));
    await _pumpFor(tester, 5);
    await _tap(tester, find.byKey(const Key('episode_row_1_8')));
    await _tap(tester, find.byKey(const Key('episode_unlog_button')));
    final db = c.read(databaseProvider);
    expect(await tester.runAsync(() => db.pendingMutationDao.count()),
        greaterThan(0),
        reason: 'queued while offline');
    expect(server.rows[_showId]!.place, const EpisodeRef(1, 8),
        reason: 'the server has not heard yet');
    expect(_eyebrow('● WATCHING · S1 · E8 NEXT'), findsOneWidget,
        reason: 'the title page already shows it');

    online.add(true);
    await _synced(tester, c);
    expect(server.rows[_showId]!.place, const EpisodeRef(1, 7));
    expect(server.stateOf(_showId), TrackingState.watching);
  });
}
