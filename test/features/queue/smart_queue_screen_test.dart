import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/queue/data/streaming_availability_service.dart';
import 'package:telly_app/features/queue/domain/streaming_models.dart';
import 'package:telly_app/features/queue/presentation/screens/smart_queue_screen.dart';

import '../../helpers/real_fonts.dart';

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

  Widget createTestWidget({Set<String>? userSubscriptions}) {
    return ProviderScope(
      overrides: [
        if (userSubscriptions != null)
          userSubscriptionsProvider.overrideWith((ref) => userSubscriptions),
      ],
      child: MaterialApp(
        theme: TellyTheme.dark,
        home: SmartQueueScreen(testItems: testWatchlist),
      ),
    );
  }

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
      expect(find.text('APPLE TV+'), findsOneWidget);
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
      expect(find.text('⚠️ LEAVING SOON'), findsOneWidget);
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

      // Toggle "On My Services" filter ON
      await tester.tap(find.text('On My Services'));
      await tester.pumpAndSettle();

      // Fargo (on Hulu) should be filtered out; Slow Horses (on Apple TV+) remains
      expect(find.text('Slow Horses'), findsOneWidget);
      expect(find.text('Fargo'), findsNothing);
    });

    testWidgets('the header sort action re-sorts the watchlist (FE-HEADER-01)', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('TV Shows 2'));
      await tester.pumpAndSettle();

      double y(String title) => tester.getTopLeft(find.text(title)).dy;
      // Default: friends' score, so Slow Horses (8.94) sits above Fargo (8.75).
      expect(y('Slow Horses'), lessThan(y('Fargo')));
      expect(find.byType(DropdownButton<String>), findsNothing, reason: 'sorting moved to the header');

      await tester.tap(find.byKey(const Key('queue_sort_button')));
      await tester.pumpAndSettle();
      expect(find.text('SORT BY'), findsOneWidget);
      await tester.tap(find.byKey(const Key('queue_sort_option_leaving_soon')));
      await tester.pumpAndSettle();

      expect(find.text('SORT BY'), findsNothing);
      expect(y('Fargo'), lessThan(y('Slow Horses')));
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
