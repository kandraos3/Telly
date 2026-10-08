import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/features/discovery/data/discovery_repository.dart';
import 'package:telly_app/features/discovery/data/explore_sample_payloads.dart';
import 'package:telly_app/features/discovery/domain/explore_candidates.dart';
import 'package:telly_app/features/discovery/domain/explore_ranker.dart';
import 'package:telly_app/features/discovery/presentation/controllers/explore_rows_controller.dart';
import 'package:telly_app/features/discovery/presentation/screens/explore_row_screen.dart';
import 'package:telly_app/features/discovery/presentation/widgets/explore_rows_view.dart';

import 'explore_rows_view_test.dart' show expectReadableText;

// #181: SCR-07 See all, `/explore/row/:rowId?canon=`. Spec: features/07 §7.5 (Actions) and
// docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md §SCR-07 user actions.

final _today = DateTime(2026, 10, 8, 12);

/// 40 Drama movies and no seeds: Top picks fills to its See all cap.
Map<String, dynamic> _manyPicks() => {
      'media_type': 'movie',
      'profile': {
        'rankings': [
          for (var i = 0; i < 3; i++) {'title_id': 9000 + i, 'score': 9.0, 'rank': i + 1, 'genres': ['Drama']},
        ],
        'seeds': const [],
        'services': const [],
        'missing_related': const [],
      },
      'candidates': [
        for (var i = 0; i < 40; i++)
          {
            'title_id': 1000 + i,
            'title': 'Pick $i',
            'genres': ['Drama'],
            'community_score': 6.0 + i / 20,
            'community_count': 10,
          },
      ],
    };

void main() {
  late AppDatabase db;
  late FakeDiscoveryRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = FakeDiscoveryRepository(
      exploreCandidates: {'movie': sampleMoviePayload(_today), 'tv': sampleSeriesPayload(_today)},
    );
  });
  tearDown(() => db.close());

  ExploreRows ranked(String mediaType) =>
      const ExploreRanker().rank(ExploreCandidates.fromJson(repo.exploreCandidates[mediaType]!), _today);

  Widget app(String location, {ThemeData? theme}) {
    Widget stub(BuildContext _, GoRouterState state) => Scaffold(body: Text('route:${state.uri}'));
    final router = GoRouter(initialLocation: location, routes: [
      GoRoute(
        path: Routes.explore,
        builder: (_, __) => const Scaffold(body: SingleChildScrollView(child: ExploreRowsView(mediaType: 'tv'))),
        routes: [
          GoRoute(
            path: 'row/:rowId',
            builder: (_, state) => ExploreRowScreen(
              rowId: state.pathParameters['rowId']!,
              mediaType: state.uri.queryParameters['canon'],
            ),
          ),
        ],
      ),
      GoRoute(path: '/title/:t/:id', builder: stub),
    ]);
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        exploreNowProvider.overrideWithValue(() => _today),
        discoveryRepositoryProvider.overrideWithValue(repo),
        posterNetworkImagesProvider.overrideWithValue(false),
      ],
      child: MaterialApp.router(theme: theme ?? TellyTheme.dark, routerConfig: router),
    );
  }

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 9000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
  }

  /// The title ids of the grid's cards, top-left to bottom-right.
  List<int> gridIds(WidgetTester tester) {
    final cards = find.byWidgetPredicate((w) => w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('explore_card_'));
    final found = cards.evaluate().map((e) => e.widget.key! as ValueKey<String>).toList();
    final pos = {for (final k in found) k: tester.getTopLeft(find.byKey(k))};
    found.sort((a, b) => pos[a]!.dy != pos[b]!.dy ? pos[a]!.dy.compareTo(pos[b]!.dy) : pos[a]!.dx.compareTo(pos[b]!.dx));
    return [for (final k in found) int.parse(k.value.substring('explore_card_'.length))];
  }

  testWidgets("See all on a Because row opens its grid, titled with the seed, in the carousel's order",
      (tester) async {
    tall(tester);
    await tester.pumpWidget(app(Routes.explore));
    await tester.pumpAndSettle();

    final row = ranked('tv').row(ExploreRowKind.becauseYouRanked)!;
    expect(row.id, 'becauseYouRanked-${row.seed!.titleId}');
    await tester.tap(find.byKey(Key('explore_see_all_${row.id}')));
    await tester.pumpAndSettle();

    expect(find.byType(ExploreRowScreen), findsOneWidget);
    expect(find.text('Because you ranked ${row.seed!.title}'), findsOneWidget);
    expect(find.byKey(Key('explore_seed_${row.seed!.titleId}')), findsNothing, reason: 'the seed is in the title');
    expect(gridIds(tester), [for (final s in row.items) s.candidate.titleId]);
    expect(find.textContaining('% match'), findsWidgets);
  });

  testWidgets('every row of both canons opens with all its titles in order', (tester) async {
    tall(tester);
    for (final canon in const ['movie', 'tv']) {
      for (final row in ranked(canon).rows) {
        await tester.pumpWidget(app(Routes.exploreRow(row.id, canon)));
        await tester.pumpAndSettle();
        expect(find.byKey(Key('explore_grid_${row.id}')), findsOneWidget, reason: '$canon ${row.id}');
        expect(gridIds(tester), [for (final s in row.items) s.candidate.titleId], reason: '$canon ${row.id}');
        expect(find.text(ExploreRowGrid.titleOf(row, canon)), findsOneWidget);
      }
    }
  });

  testWidgets('Leaving soon keeps its countdowns; Trending shows each rank', (tester) async {
    tall(tester);
    await tester.pumpWidget(app(Routes.exploreRow('leavingSoon', 'movie')));
    await tester.pumpAndSettle();
    expect(find.text('3 DAYS'), findsOneWidget);
    expect(find.text('5 DAYS'), findsOneWidget);

    await tester.pumpWidget(app(Routes.exploreRow('trending', 'movie')));
    await tester.pumpAndSettle();
    expect(find.text('Top 10 movies this week'), findsOneWidget);
    expect(find.text('#1 this week'), findsOneWidget);
  });

  testWidgets('a grid holds up to 30 titles, against 15 in the carousel', (tester) async {
    tall(tester);
    repo.exploreCandidates = {'movie': _manyPicks()};
    final row = ranked('movie').row(ExploreRowKind.topPicks)!;
    expect(row.visible, hasLength(15));
    expect(row.items, hasLength(30));

    await tester.pumpWidget(app(Routes.exploreRow('topPicks', 'movie')));
    await tester.pumpAndSettle();
    expect(gridIds(tester), [for (final s in row.items) s.candidate.titleId]);
  });

  testWidgets('tapping a title opens it', (tester) async {
    tall(tester);
    await tester.pumpWidget(app(Routes.exploreRow('becauseYouRanked-110492', 'tv')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('explore_card_70523')));
    await tester.pumpAndSettle();
    expect(find.text('route:/title/tv/70523'), findsOneWidget);
  });

  for (final location in [
    Routes.exploreRow('nope', 'movie'),
    Routes.exploreRow('becauseYouRanked-1', 'tv'),
    Routes.exploreRow('becauseYouRanked-110492', 'movie'),
    Routes.exploreRow('trending', 'anime'),
    '${Routes.explore}/row/trending',
  ]) {
    testWidgets('$location shows that the list is not available', (tester) async {
      await tester.pumpWidget(app(location));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('explore_row_unavailable')), findsOneWidget);
      expect(find.text("This list isn't available"), findsOneWidget);
    });
  }

  testWidgets('a canon that cannot load shows that the list is not available', (tester) async {
    repo.exploreCandidates = {};
    await tester.pumpWidget(app(Routes.exploreRow('trending', 'movie')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('explore_row_unavailable')), findsOneWidget);
  });

  for (final (name, theme) in [('dark', TellyTheme.dark), ('light', TellyTheme.light)]) {
    testWidgets('meets the a11y guidelines in the $name theme', (tester) async {
      tall(tester);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(app(Routes.exploreRow('becauseYouRanked-496243', 'movie'), theme: theme));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(find.bySemanticsLabel(RegExp(r'^[^,]+, \d+% match, \d{4}$')), findsWidgets,
          reason: 'each card is one button whose label carries its meta line');
      expectReadableText(tester, find.byType(ExploreRowGrid));
      semantics.dispose();
    });
  }
}
