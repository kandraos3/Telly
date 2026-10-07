import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/queue/data/streaming_availability_service.dart';
import 'package:telly_app/features/queue/domain/streaming_models.dart';
import 'package:telly_app/features/queue/presentation/screens/smart_queue_screen.dart';

import '../../helpers/real_fonts.dart';
import '../../helpers/router_harness.dart';

/// Always the first choice: the Up next pick is the first title in sort order, and ↻
/// takes the first other title. Keeps widget tests deterministic (#134).
class _FirstRandom implements Random {
  @override
  int nextInt(int max) => 0;
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => false;
}

/// An in-memory watchlist whose remove / add land at once, for swipe and Undo tests.
class _MemoryWatchlist extends WatchlistNotifier {
  _MemoryWatchlist(this._items);
  final List<WatchlistItem> _items;

  @override
  Future<List<WatchlistItem>> build() async => List.of(_items);

  @override
  Future<void> removeItem(int showId, [String? mediaType]) async {
    state = AsyncData([for (final i in state.value!) if (i.showId != showId) i]);
  }

  @override
  Future<void> addItem({
    required int titleId,
    required String mediaType,
    required String title,
    String? posterPath,
    String? recommendedBy,
  }) async {
    final original = _items.firstWhere((i) => i.showId == titleId);
    state = AsyncData([...state.value!, original]);
  }
}

/// A watchlist that never finishes loading.
class _LoadingWatchlist extends WatchlistNotifier {
  @override
  Future<List<WatchlistItem>> build() => Completer<List<WatchlistItem>>().future;
}

void main() {
  final testWatchlist = [
    WatchlistItem(
      showId: 101,
      title: 'Slow Horses',
      mediaType: 'tv',
      seasonCount: 4,
      episodeCount: 24,
      friendsAvgScore: 8.94,
      friendsCount: 6,
      savedFromHandle: '@maya',
      addedAt: DateTime.now(),
      availability: const [
        ShowStreamingAvailability(
          platformId: 'apple_tv_plus',
          platformName: 'Apple TV+',
          monetizationType: MonetizationType.flatrate,
          webUrl: 'https://tv.apple.com/us/show/slow-horses/101',
        ),
      ],
    ),
    WatchlistItem(
      showId: 103,
      title: 'Fargo',
      mediaType: 'tv',
      seasonCount: 5,
      episodeCount: 51,
      friendsAvgScore: 8.75,
      friendsCount: 5,
      savedFromHandle: '@jordan',
      isLeavingSoon: true,
      addedAt: DateTime.now(),
      availability: const [
        ShowStreamingAvailability(
          platformId: 'hulu',
          platformName: 'Hulu',
          monetizationType: MonetizationType.flatrate,
          webUrl: 'https://www.hulu.com/series/103',
          isLeavingSoon: true,
        ),
      ],
    ),
    WatchlistItem(
      showId: 201,
      title: 'Parasite',
      mediaType: 'movie',
      runtimeMinutes: 132,
      friendsAvgScore: 9.72,
      friendsCount: 12,
      savedFromHandle: '@maya',
      addedAt: DateTime.now(),
      availability: const [
        ShowStreamingAvailability(
          platformId: 'max',
          platformName: 'Max',
          monetizationType: MonetizationType.flatrate,
          webUrl: 'https://play.max.com/show/201',
        ),
      ],
    ),
  ];

  List<Override> queueOverrides({Set<String>? userSubscriptions, WatchlistNotifier? watchlist}) => [
        queueRandomProvider.overrideWithValue(_FirstRandom()),
        if (userSubscriptions != null) userSubscriptionsProvider.overrideWith((ref) => userSubscriptions),
        if (watchlist != null) userWatchlistProvider.overrideWith(() => watchlist),
      ];

  Widget createTestWidget({Set<String>? userSubscriptions, List<WatchlistItem>? items, ThemeData? theme}) {
    return ProviderScope(
      overrides: queueOverrides(userSubscriptions: userSubscriptions),
      child: MaterialApp(
        theme: theme ?? TellyTheme.dark,
        home: SmartQueueScreen(testItems: items ?? testWatchlist),
      ),
    );
  }

  /// The real watchlist provider over [_MemoryWatchlist], so swipes really remove titles.
  Widget createLiveWidget({List<WatchlistItem>? items, bool routed = false}) {
    final overrides = queueOverrides(watchlist: _MemoryWatchlist(items ?? testWatchlist));
    if (routed) return routerHarness(const SmartQueueScreen(), overrides: overrides);
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(theme: TellyTheme.dark, home: const SmartQueueScreen()),
    );
  }

  group('#133: SCR-13 one control row and Lists', () {
    testWidgets('one control row: the switcher and Filter share a row; no hub pills or services chip', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Watchlist'), findsNothing);
      expect(find.text('My Lists'), findsNothing);
      expect(find.text('On My Services'), findsNothing);
      expect(find.byKey(const Key('queue_sort_button')), findsNothing);
      final switcher = tester.getRect(find.byKey(const Key('queue_movies_tab')));
      final filter = tester.getRect(find.byKey(const Key('queue_filter_button')));
      expect(filter.center.dy, closeTo(switcher.center.dy, 1));
      expect(filter.left, greaterThan(switcher.right));
    });

    testWidgets('the Lists action opens the Lists screen', (tester) async {
      await tester.pumpWidget(routerHarness(SmartQueueScreen(testItems: testWatchlist), overrides: queueOverrides()));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Lists'), findsOneWidget);
      await tester.tap(find.byKey(const Key('queue_lists_button')));
      await tester.pumpAndSettle();
      expect(find.text('route:${Routes.queueLists}'), findsOneWidget);
    });
  });

  group('#134: SCR-13 Up next, rows and swipes', () {
    Finder inCard(String text) => find.descendant(of: find.byKey(const Key('queue_up_next_card')), matching: find.text(text));
    Future<void> openSeries(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('queue_series_tab')));
      await tester.pumpAndSettle();
    }

    testWidgets('leads with the Up next card; the pick is not repeated in the THEN rows', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await openSeries(tester);

      expect(inCard('UP NEXT'), findsOneWidget);
      expect(inCard('Slow Horses'), findsOneWidget);
      expect(find.byKey(const ValueKey('queue_row_101')), findsNothing);
      expect(find.byKey(const ValueKey('queue_row_103')), findsOneWidget);
      expect(find.text('THEN'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('queue_then_count'))).data, '1');
      expect(find.text('▶ Hulu'), findsOneWidget, reason: 'one action per row');
      expect(find.text('✓ Mark Seen'), findsNothing);
    });

    testWidgets('↻ Another picks a different title, and each canon keeps its own pick', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await openSeries(tester);

      expect(tester.getSize(find.byKey(const Key('queue_up_next_shuffle'))).height, greaterThanOrEqualTo(48));
      await tester.tap(find.byKey(const Key('queue_up_next_shuffle')));
      await tester.pumpAndSettle();
      expect(inCard('Fargo'), findsOneWidget);
      expect(find.byKey(const ValueKey('queue_row_101')), findsOneWidget, reason: 'the old pick joins the rows');

      await tester.tap(find.byKey(const Key('queue_movies_tab')));
      await tester.pumpAndSettle();
      await openSeries(tester);
      expect(inCard('Fargo'), findsOneWidget, reason: 'switching canons does not re-roll');
    });

    testWidgets('a pool of one: no ↻ and no THEN rows; films never show on the TV card', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(inCard('Parasite'), findsOneWidget);
      expect(find.byKey(const Key('queue_up_next_shuffle')), findsNothing);
      expect(find.text('THEN'), findsNothing);

      await openSeries(tester);
      expect(inCard('Parasite'), findsNothing);
    });

    testWidgets('swipe left removes a row, and Undo puts it back', (tester) async {
      await tester.pumpWidget(createLiveWidget());
      await tester.pumpAndSettle();
      await openSeries(tester);

      await tester.drag(find.byKey(const ValueKey('queue_row_103')), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('queue_row_103')), findsNothing);
      expect(find.text('Removed "Fargo" from queue'), findsOneWidget);

      await tester.tap(find.byKey(const Key('queue_undo_remove')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('queue_row_103')), findsOneWidget);
    });

    testWidgets('swipe right marks seen: the title leaves the queue and the Log flow opens', (tester) async {
      await tester.pumpWidget(createLiveWidget(routed: true));
      await tester.pumpAndSettle();
      await openSeries(tester);

      await tester.drag(find.byKey(const ValueKey('queue_row_103')), const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(find.text('route:${Routes.log}'), findsOneWidget);
    });

    testWidgets('✓ Seen on the card opens the Log flow, and the next pick takes its place', (tester) async {
      await tester.pumpWidget(createLiveWidget(routed: true));
      await tester.pumpAndSettle();
      await openSeries(tester);

      await tester.tap(find.byKey(const Key('queue_up_next_seen')));
      await tester.pumpAndSettle();
      expect(find.text('route:${Routes.log}'), findsOneWidget);
    });

    testWidgets('when the pick is removed, a new pick replaces it at once', (tester) async {
      await tester.pumpWidget(createLiveWidget());
      await tester.pumpAndSettle();
      await openSeries(tester);
      expect(inCard('Slow Horses'), findsOneWidget);

      await tester.drag(find.byKey(const Key('queue_up_next_card')), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(inCard('Fargo'), findsOneWidget);
      expect(find.text('THEN'), findsNothing);
    });

    testWidgets('filtered to nothing: "Show all" turns the filter off', (tester) async {
      await tester.pumpWidget(createTestWidget(userSubscriptions: {'netflix'}));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('queue_filter_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('queue_services_toggle')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Nothing here streams on your services'), findsOneWidget);
      await tester.tap(find.byKey(const Key('queue_show_all_button')));
      await tester.pumpAndSettle();
      expect(inCard('Parasite'), findsOneWidget);
      expect(find.byKey(const Key('filter_button_badge')), findsNothing);
    });

    testWidgets('loading shows the skeleton', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: queueOverrides(watchlist: _LoadingWatchlist()),
        child: MaterialApp(theme: TellyTheme.dark, home: const SmartQueueScreen()),
      ));
      await tester.pump();
      expect(find.byKey(const Key('queue_skeleton')), findsOneWidget);
    });

    testWidgets('the card reads in light mode: the eyebrow and title sit on the dark scrim', (tester) async {
      await tester.pumpWidget(createTestWidget(theme: TellyTheme.light));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(inCard('UP NEXT')).style!.color, TellyColors.phosphorLime);
      expect(tester.widget<Text>(inCard('Parasite')).style!.color, Colors.white);
    });

    test('each visit re-rolls: the pick provider is disposed with the screen', () async {
      final container = ProviderContainer(overrides: [queueRandomProvider.overrideWithValue(_FirstRandom())]);
      addTearDown(container.dispose);
      final sub = container.listen(queueUpNextProvider, (_, __) {});
      final first = container.read(queueUpNextProvider.notifier);
      sub.close();
      await Future<void>.delayed(Duration.zero);
      container.listen(queueUpNextProvider, (_, __) {});
      expect(identical(container.read(queueUpNextProvider.notifier), first), isFalse);
    });
  });

  group('FE-408: SmartQueueScreen Widget Tests (SCR-13)', () {
    testWidgets('renders segregated Movie and Series tabs with item counts',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Queue'), findsOneWidget);
      // Tabs: Movies 1 and TV Shows 2, no emoji (FE-HEADER-01)
      expect(find.text('Movies 1'), findsOneWidget);
      expect(find.text('TV Shows 2'), findsOneWidget);

      // Default selected tab is Movies: Parasite should be visible
      expect(find.text('Parasite'), findsOneWidget);
      expect(find.text('Watch on Max'), findsOneWidget);
    });

    testWidgets('FE-QUEUE-01: a long provider name fits an iPhone 15 width without overflow', (tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      // Measure with the real bundled fonts; the default test font is far wider.
      await tester.runAsync(loadRealFonts);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('TV Shows 2'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Slow Horses is the Up next pick; its primary action names the service in full.
      expect(find.text('Watch on Apple TV+'), findsOneWidget);
    });

    testWidgets(
        'switching to Series tab reveals series items with leaving soon badge',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap Series tab
      await tester.tap(find.text('TV Shows 2'));
      await tester.pumpAndSettle();

      expect(find.text('Slow Horses'), findsOneWidget);
      expect(find.text('Fargo'), findsOneWidget);
      expect(find.text('LEAVING SOON'), findsOneWidget);
      expect(find.text('Watch on Apple TV+'), findsOneWidget);
    });

    testWidgets('toggling "On My Services" filters out unsubscribed titles',
        (tester) async {
      // User only subscribes to Apple TV+ (does not have Hulu)
      await tester
          .pumpWidget(createTestWidget(userSubscriptions: {'apple_tv_plus'}));
      await tester.pumpAndSettle();

      // Switch to Series tab
      await tester.tap(find.text('TV Shows 2'));
      await tester.pumpAndSettle();

      // Both Slow Horses and Fargo are initially shown because filter is OFF
      expect(find.text('Slow Horses'), findsOneWidget);
      expect(find.text('Fargo'), findsOneWidget);

      // Turn "Only on my services" on in the Filter sheet (#133); the sheet stays open.
      expect(find.byKey(const Key('filter_button_badge')), findsNothing);
      await tester.tap(find.byKey(const Key('queue_filter_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('queue_services_toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('queue_filter_sheet')), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('filter_button_badge')), findsOneWidget);
      expect(find.bySemanticsLabel('Filter, 1 active'), findsOneWidget);

      // Fargo (on Hulu) should be filtered out; Slow Horses (on Apple TV+) remains
      expect(find.text('Slow Horses'), findsOneWidget);
      expect(find.text('Fargo'), findsNothing);
    });

    testWidgets('sorting from the Filter sheet re-sorts the rows and does not count as a filter (#133)', (tester) async {
      WatchlistItem tv(int id, String title, double score, {bool leaving = false}) => WatchlistItem(
            showId: id,
            title: title,
            mediaType: 'tv',
            friendsAvgScore: score,
            isLeavingSoon: leaving,
            addedAt: DateTime(2026),
          );
      await tester.pumpWidget(createTestWidget(items: [
        tv(1, 'Alpha', 9.5),
        tv(2, 'Bravo', 9.0),
        tv(3, 'Charlie', 8.5),
        tv(4, 'Delta', 8.0, leaving: true),
      ]));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('queue_series_tab')));
      await tester.pumpAndSettle();

      double y(String title) => tester.getTopLeft(find.text(title)).dy;
      // Friends' score: Alpha is the pick; the rows run Bravo, Charlie, Delta.
      expect(y('Bravo'), lessThan(y('Delta')));

      await tester.tap(find.byKey(const Key('queue_filter_button')));
      await tester.pumpAndSettle();
      expect(find.text('SORT BY'), findsOneWidget);
      await tester.tap(find.byKey(const Key('queue_sort_option_leaving_soon')));
      await tester.pumpAndSettle();

      expect(find.text('SORT BY'), findsNothing, reason: 'choosing a sort closes the sheet');
      expect(y('Delta'), lessThan(y('Bravo')), reason: 'leaving soon first');
      expect(find.descendant(of: find.byKey(const Key('queue_up_next_card')), matching: find.text('Alpha')), findsOneWidget,
          reason: 'sorting keeps the pick');
      expect(find.byKey(const Key('filter_button_badge')), findsNothing);
    });

    testWidgets('FE-UI-01: swiping the list moves the shared canon switcher with it', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      Color? labelColor(String text) => tester.widget<Text>(find.text(text)).style?.color;
      // The selected half lifts onto Overlay with a primary label; the other half is muted.
      expect(labelColor('Movies 1'), TellyColors.textPrimary);

      // Swipe on empty space below the cards: the cards themselves swipe to remove.
      final page = tester.getRect(find.byType(TabBarView));
      await tester.flingFrom(Offset(page.center.dx, page.bottom - 20), const Offset(-600, 0), 2000);
      await tester.pumpAndSettle();

      expect(find.text('Slow Horses'), findsOneWidget);
      expect(labelColor('TV Shows 2'), TellyColors.textPrimary);
      expect(labelColor('Movies 1'), TellyColors.textTertiary);
    });

    testWidgets('FE-UI-01: an empty watchlist shows the shared empty state with an Explore action', (tester) async {
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: SmartQueueScreen(testItems: [])),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Your queue is clear!'), findsOneWidget);
      expect(find.text('Explore titles'), findsOneWidget);
    });
  });
}
