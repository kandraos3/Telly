import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/discovery/data/discovery_repository.dart';
import 'package:telly_app/features/discovery/presentation/controllers/explore_rows_controller.dart';
import 'package:telly_app/features/discovery/presentation/screens/explore_discover_screen.dart';
import 'package:telly_app/features/discovery/presentation/widgets/explore_rows_view.dart';
import 'package:telly_app/features/logging/data/title_repository.dart';
import 'package:telly_app/features/queue/data/watchlist_repository.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_title_repository.dart';
import '../../fakes/fake_watchlist_repository.dart';

// #180: SCR-07's hero and rows. Spec: docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md
// §SCR-07 and docs/features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md §7.2, §7.5.

final _today = DateTime(2026, 10, 8, 12);

Map<String, dynamic> _cand(int id, String title, {List<String> genres = const ['Drama'], Map<String, dynamic> extra = const {}}) =>
    {'title_id': id, 'title': title, 'genres': genres, ...extra};

/// A movie canon: Parasite seeds Decision to Leave (the hero) and four Because titles; four
/// trending titles; one friends title; one leaving Netflix in 3 days; four top picks.
Map<String, dynamic> _movies({int rankings = 5}) => {
      'media_type': 'movie',
      'profile': {
        'rankings': [
          for (var i = 0; i < rankings; i++) {'title_id': 9000 + i, 'score': 9.0, 'rank': i + 1, 'genres': ['Drama']},
        ],
        'seeds': [
          {'title_id': 496243, 'title': 'Parasite', 'score': 9.72, 'rank': 2},
        ],
        'services': ['netflix'],
        'missing_related': const [],
      },
      'candidates': [
        _cand(705996, 'Decision to Leave', extra: {
          'director': 'Park Chan-wook',
          'release_year': 2022,
          'providers': ['mubi'],
          'seed_links': [{'seed_id': 496243, 'position': 1}],
          'community_score': 9.5,
          'community_count': 30,
        }),
        for (final (i, t) in const ['Anora', 'The Brutalist', 'Sinners', 'Nosferatu'].indexed)
          _cand(100 + i, t, genres: const ['Horror'], extra: {'trending_rank': i + 1}),
        for (final (i, t) in const ['Memories of Murder', 'The Handmaiden', 'Burning', 'Shoplifters'].indexed)
          _cand(200 + i, t, extra: {'seed_links': [{'seed_id': 496243, 'position': i + 2}]}),
        _cand(300, 'Conclave', extra: {
          'friends': [
            {'user_id': 'a', 'display_name': 'Maya', 'score': 9.1, 'match_pct': 81},
            {'user_id': 'b', 'display_name': 'Jo', 'score': 8.1, 'match_pct': 70},
          ],
        }),
        _cand(400, 'The Social Network', extra: {'providers': ['netflix'], 'on_my_services': true, 'leaving_until': '2026-10-11'}),
        for (final (i, t) in const ['Prisoners', 'Sicario', 'Aftersun', 'Drive My Car'].indexed) _cand(500 + i, t),
      ],
    };

Map<String, dynamic> _series() => {
      'media_type': 'tv',
      'profile': {
        'rankings': [
          for (var i = 0; i < 4; i++) {'title_id': 8000 + i, 'score': 9.0, 'rank': i + 1, 'genres': ['Drama']},
        ],
        'seeds': const [],
        'services': const [],
        'missing_related': const [],
      },
      'candidates': [for (final (i, t) in const ['Pachinko', 'Andor', 'Dark', 'Slow Horses', 'The Bear'].indexed) _cand(600 + i, t)],
    };

/// Never answers, so Explore stays on its loading skeleton.
class _PendingDiscovery extends FakeDiscoveryRepository {
  final pending = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> fetchExploreCandidates(String mediaType) => pending.future;
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

/// Every text under [root] reaches 4.5:1 against its background: Surface inside cards and
/// the offline banner, the canvas elsewhere (the hero's text sits on its opaque scrim).
/// Button labels and the countdown badge sit on their own fills and are checked separately.
void expectReadableText(WidgetTester tester, Finder root) {
  final context = tester.element(root);
  final canvas = TellyColors.canvasOf(context);
  final surface = TellyColors.surfaceOf(context);
  const onSurface = ['explore_friend_', 'explore_seed_', 'explore_offline_banner', 'explore_new_user_prompt'];
  var checked = 0;
  for (final element in find.descendant(of: root, matching: find.byType(RichText)).evaluate()) {
    var bg = canvas;
    var skip = false;
    element.visitAncestorElements((a) {
      final key = a.widget.key;
      if (a.widget is TextButton) skip = true;
      if (key is ValueKey<String> && onSurface.any(key.value.startsWith)) bg = surface;
      return true;
    });
    final text = (element.widget as RichText).text;
    final plain = text.toPlainText().trim();
    if (skip || plain.isEmpty || RegExp(r'^(\d+ DAYS?|LAST DAY)$').hasMatch(plain)) continue;
    text.visitChildren((span) {
      final color = span.style?.color;
      if (color == null || (span is TextSpan && (span.text ?? '').trim().isEmpty)) return true;
      final c = Color.alphaBlend(color, bg);
      expect(_contrast(c, bg), greaterThanOrEqualTo(4.5),
          reason: '"${text.toPlainText()}" ($color on $bg) is ${_contrast(c, bg).toStringAsFixed(2)}:1');
      checked++;
      return true;
    });
  }
  expect(checked, greaterThan(10), reason: "the check found the rows' text");
}

void main() {
  late AppDatabase db;
  late FakeDiscoveryRepository repo;
  late FakeWatchlistRepository watchlist;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = FakeDiscoveryRepository(exploreCandidates: {'movie': _movies(), 'tv': _series()});
    watchlist = FakeWatchlistRepository();
  });
  tearDown(() => db.close());

  List<Override> overrides() => [
        databaseProvider.overrideWithValue(db),
        exploreNowProvider.overrideWithValue(() => _today),
        discoveryRepositoryProvider.overrideWithValue(repo),
        watchlistRepositoryProvider.overrideWithValue(watchlist),
        posterNetworkImagesProvider.overrideWithValue(false),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(signedInUserId: 'u-user')),
        titleRepositoryProvider.overrideWithValue(FakeTitleRepository()),
      ];

  Widget app({ThemeData? theme, bool reducedMotion = false, double textScale = 1}) {
    Widget stub(BuildContext _, GoRouterState state) => Scaffold(body: Text('route:${state.uri}'));
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: ExploreDiscoverScreen())),
      GoRoute(path: '/:a', builder: stub),
      GoRoute(path: '/:a/:b', builder: stub),
      GoRoute(path: '/:a/:b/:c', builder: stub),
    ]);
    return ProviderScope(
      overrides: overrides(),
      child: MaterialApp.router(
        theme: theme ?? TellyTheme.dark,
        routerConfig: router,
        builder: (context, child) =>
            MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reducedMotion, textScaler: TextScaler.linear(textScale)),
            child: child!),
      ),
    );
  }

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('shows the hero and every row in display order; curated canons are gone', (tester) async {
    tall(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('explore_hero')), findsOneWidget);
    expect(find.text('TOP PICK FOR YOU · 84% MATCH'), findsOneWidget);
    expect(find.text('Decision to Leave'), findsOneWidget);
    expect(find.textContaining('Like Parasite (9.72)'), findsOneWidget);
    expect(find.textContaining('Park Chan-wook, 2022 · on Mubi'), findsOneWidget);

    final order = [
      'explore_row_trending',
      'explore_row_topPicks',
      'explore_row_becauseYouRanked_496243',
      'explore_row_friends',
      'explore_row_leavingSoon',
    ].map((k) => tester.getTopLeft(find.byKey(Key(k))).dy).toList();
    expect(order, [...order]..sort(), reason: 'rows follow features/07 §7.2');

    expect(find.text('Top 10 movies this week'), findsOneWidget);
    expect(find.bySemanticsLabel('Number 1 trending, Anora'), findsOneWidget);
    expect(find.byKey(const Key('explore_seed_496243')), findsOneWidget);
    expect(find.text('#2 · 9.72'), findsOneWidget);
    expect(find.text('Maya and Jo'), findsOneWidget);
    expect(find.text("★ 8.6 friends' avg"), findsOneWidget);
    expect(find.text('3 DAYS'), findsOneWidget);
    expect(find.text('CURATED CANONS'), findsNothing);
    expect(find.text('RECOMMENDED FOR YOU'), findsNothing);
    // Fewer than 10 rankings: no Something different.
    expect(find.byKey(const Key('explore_row_somethingDifferent')), findsNothing);
    semantics.dispose();
  });

  testWidgets('the Series canon shows series only, then network battlegrounds', (tester) async {
    tall(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('NETWORK BATTLEGROUNDS'), findsNothing, reason: 'battlegrounds are a Series row');

    await tester.tap(find.byKey(const Key('explore_canon_tv')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('explore_rows_tv')), findsOneWidget);
    expect(find.text('Pachinko'), findsOneWidget);
    expect(find.text('Decision to Leave'), findsNothing);
    expect(find.text('Conclave'), findsNothing);
    expect(find.text('NETWORK BATTLEGROUNDS'), findsOneWidget);

    await tester.tap(find.text('See Full Network Rankings'));
    await tester.pumpAndSettle();
    expect(find.text('👑 NETWORK BATTLEGROUNDS'), findsOneWidget);
  });

  testWidgets('a new user gets the Rank 3 prompt, which opens the Log flow', (tester) async {
    tall(tester);
    final semantics = tester.ensureSemantics();
    repo.exploreCandidates = {'movie': _movies(rankings: 1), 'tv': _series()};
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('explore_hero')), findsNothing);
    expect(find.text('Rank 3 movies to unlock your picks'), findsOneWidget);
    expect(find.bySemanticsLabel('1 of 3 ranked'), findsOneWidget);
    expect(find.byKey(const Key('explore_row_topRated')), findsOneWidget);
    expect(find.byKey(const Key('explore_row_becauseYouRanked_496243')), findsNothing);

    await tester.tap(find.byKey(const Key('explore_new_user_log')));
    await tester.pumpAndSettle();
    expect(find.text('route:/log'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('+ Queue adds the hero to the watchlist and turns into In queue', (tester) async {
    tall(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('explore_hero_queue')));
    await tester.pumpAndSettle();
    expect(watchlist.items.single.titleId, 705996);
    expect(find.text('✓ In queue'), findsOneWidget);
  });

  testWidgets('Not for me dismisses the hero, the next pick takes its place, and Undo brings it back', (tester) async {
    tall(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('explore_hero_dismiss')));
    await tester.pumpAndSettle();
    expect(repo.dismissed, [(705996, 'movie')]);
    expect(find.text('Decision to Leave'), findsNothing);
    expect(find.byKey(const Key('explore_hero')), findsOneWidget, reason: 'the next pick becomes the hero');
    expect(find.byKey(const Key('explore_dismissed_snackbar')), findsOneWidget);
    final cached = jsonDecode((await db.exploreCacheDao.read('movie'))!.json) as Map<String, dynamic>;
    expect((cached['candidates'] as List).any((c) => c['title_id'] == 705996), isFalse);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(repo.dismissed, isEmpty);
    expect(find.text('Decision to Leave'), findsOneWidget);
  });

  testWidgets('hidden rows: no friends and nothing leaving means no such rows', (tester) async {
    tall(tester);
    final movies = _movies();
    movies['candidates'] = [
      for (final c in movies['candidates'] as List)
        if ((c as Map)['title_id'] != 300 && c['title_id'] != 400) c,
    ];
    repo.exploreCandidates = {'movie': movies, 'tv': _series()};
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('explore_row_friends')), findsNothing);
    expect(find.byKey(const Key('explore_row_leavingSoon')), findsNothing);
    expect(find.byKey(const Key('explore_row_topPicks')), findsOneWidget);
  });

  testWidgets('loading shows a skeleton, still under reduced motion', (tester) async {
    tall(tester);
    repo = _PendingDiscovery();
    await tester.pumpWidget(app(reducedMotion: true));
    await tester.pumpAndSettle(); // settles: the shimmer is stopped
    expect(find.byKey(const Key('explore_skeleton')), findsOneWidget);
  });

  testWidgets('offline with no cache shows the error; Try again loads the rows', (tester) async {
    tall(tester);
    repo.exploreOffline = true;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load Explore. Check your connection and pull to try again."), findsOneWidget);

    repo.exploreOffline = false;
    await tester.tap(find.byKey(const Key('explore_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('explore_hero')), findsOneWidget);
  });

  testWidgets('offline with a stale cache shows the cached rows and when they are from', (tester) async {
    tall(tester);
    await db.exploreCacheDao.write('movie', jsonEncode(_movies()), _today.subtract(const Duration(hours: 8)));
    repo.exploreOffline = true;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('explore_offline_banner')), findsOneWidget);
    expect(find.textContaining('Showing picks from 8 h ago.'), findsOneWidget);
    expect(find.text('Decision to Leave'), findsOneWidget);
  });

  testWidgets('pull to refresh refetches', (tester) async {
    tall(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final before = repo.exploreFetches;

    // RefreshIndicator arms after a pull of about a quarter of the (3000 dp) viewport.
    await tester.drag(find.byKey(const Key('explore_hero')), const Offset(0, 1500));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(repo.exploreFetches, greaterThan(before));
  });

  for (final (name, theme, badgeText) in [
    ('dark', TellyTheme.dark, TellyColors.backgroundPrimary),
    ('light', TellyTheme.light, Colors.white),
  ]) {
    testWidgets('meets the a11y guidelines in the $name theme, with a readable countdown badge', (tester) async {
      tall(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(app(theme: theme));
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(tester.widget<Text>(find.text('3 DAYS')).style!.color, badgeText);

      // Text contrast, from each text's colour and the background it sits on. Flutter's
      // textContrastGuideline reads the most common non-background pixel as the text colour,
      // which for small anti-aliased text is an edge tone: it reported 2.37 for a subtitle
      // whose glyphs render #7D8198 on #08090C (5.18:1). Checking the colours is exact.
      expectReadableText(tester, find.byType(ExploreRowsView));
      handle.dispose();
    });
  }

  // #197: rows, cards and the hero grow with the system text size instead of overflowing. Any
  // RenderFlex overflow fails the test; the hero's text must also stay inside its card.
  for (final (name, theme) in [('dark', TellyTheme.dark), ('light', TellyTheme.light)]) {
    for (final scale in const [1.0, 1.3, 2.0]) {
      testWidgets('every row fits at ${scale}x text in the $name theme', (tester) async {
        tall(tester);
        await tester.pumpWidget(app(theme: theme, textScale: scale));
        await tester.pumpAndSettle();
        for (final canon in const ['movie', 'tv']) {
          await tester.tap(find.byKey(Key('explore_canon_$canon')));
          await tester.pumpAndSettle();
          expect(find.byKey(Key('explore_rows_$canon')), findsOneWidget);
        }
        await tester.tap(find.byKey(const Key('explore_canon_movie')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('explore_row_friends')), findsOneWidget);
        expect(find.byKey(const Key('explore_row_becauseYouRanked_496243')), findsOneWidget);
        final hero = tester.getRect(find.byKey(const Key('explore_hero')));
        final eyebrow = tester.getRect(find.textContaining('TOP PICK FOR YOU'));
        expect(eyebrow.top, greaterThanOrEqualTo(hero.top + 14), reason: 'the hero text is not clipped');
        if (scale == 1.0) expect(hero.height, 252, reason: 'SCR-07 size at 1.0x');
      });
    }
  }
}
