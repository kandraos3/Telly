import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/features/discovery/data/discovery_repository.dart';
import 'package:telly_app/features/discovery/presentation/screens/explore_discover_screen.dart';
import 'package:telly_app/features/logging/data/title_repository.dart';

import '../../fakes/fake_title_repository.dart';

void main() {
  Widget createTestWidget({
    DiscoveryRepository? discoveryRepo,
    TitleRepository? titleRepo,
  }) {
    return ProviderScope(
      overrides: [
        posterNetworkImagesProvider.overrideWithValue(false),
        discoveryRepositoryProvider.overrideWithValue(
          discoveryRepo ?? FakeDiscoveryRepository(),
        ),
        titleRepositoryProvider.overrideWithValue(
          titleRepo ?? FakeTitleRepository(),
        ),
      ],
      child: MaterialApp(
        theme: TellyTheme.dark,
        home: const Scaffold(
          body: ExploreDiscoverScreen(),
        ),
      ),
    );
  }

  group('FE-612: ExploreDiscoverScreen Component Tests (SCR-07)', () {
    testWidgets('renders search bar, network battlegrounds, binging carousel, and curated canons', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Header & Search Bar
      expect(find.text('🧭 DISCOVER'), findsOneWidget);
      expect(find.text('Search shows, actors, showrunners, friends...'), findsOneWidget);

      // Network Battlegrounds Section
      expect(find.text('NETWORK BATTLEGROUNDS'), findsOneWidget);
      expect(find.text('👑 HBO'), findsOneWidget);
      expect(find.text('🍏 Apple TV+'), findsOneWidget);
      expect(find.text('See Full Network Rankings'), findsOneWidget);

      // Friends Are Currently Binging Carousel
      expect(find.text('FRIENDS ARE CURRENTLY BINGING'), findsOneWidget);
      expect(find.text('Shogun'), findsOneWidget);
      expect(find.text('Slow Horses'), findsOneWidget);
      expect(find.text('8 watching'), findsOneWidget);

      // Curated Canons Section
      expect(find.text('CURATED CANONS'), findsOneWidget);
      expect(find.text('The "Stuck the Landing" Canon'), findsOneWidget);
      expect(find.text('Peak 1-Season Miniseries'), findsOneWidget);
    });

    testWidgets('tapping See Full Network Rankings opens bottom sheet with leaderboard', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap See Full Network Rankings
      final button = find.text('See Full Network Rankings');
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();

      // Modal Bottom Sheet appears
      expect(find.text('👑 NETWORK BATTLEGROUNDS'), findsOneWidget);
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
    });

    testWidgets('tapping curated canon opens detail sheet with sample titles', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Scroll down to make Curated Canons fully visible if needed
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Tap The "Stuck the Landing" Canon card
      await tester.tap(find.text('The "Stuck the Landing" Canon'));
      await tester.pumpAndSettle();

      // Modal Bottom Sheet displays description and sample titles
      expect(find.text('The "Stuck the Landing" Canon'), findsWidgets);
      expect(find.text('FEATURED TITLES'), findsOneWidget);
      expect(find.text('Shows with universally revered, transcendent final episodes.'), findsWidgets);
      expect(find.text('Breaking Bad'), findsOneWidget);
      expect(find.text('Succession'), findsOneWidget);
      expect(find.text('Six Feet Under'), findsOneWidget);
    });

    testWidgets('search query renders titles and people results with working filter chips', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter search text "bear"
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'bear');
      await tester.pumpAndSettle();

      // Filter chips should be visible
      expect(find.text('All'), findsOneWidget);
      expect(find.text('🎬 Titles'), findsOneWidget);
      expect(find.text('👥 People'), findsOneWidget);

      // Section for Titles shows count and "The Bear"
      expect(find.text('TITLES (1)'), findsOneWidget);
      expect(find.text('The Bear'), findsOneWidget);

      // Now search for "maya"
      await tester.enterText(searchField, 'maya');
      await tester.pumpAndSettle();

      expect(find.text('TITLES (0)'), findsOneWidget);
      expect(find.text('PEOPLE (1)'), findsOneWidget);
      expect(find.text('Maya Lin'), findsOneWidget);
      expect(find.text('@maya'), findsOneWidget);

      // Filter chips interaction: Tap "🎬 Titles"
      await tester.tap(find.text('🎬 Titles'));
      await tester.pumpAndSettle();

      // People section should be hidden
      expect(find.text('Maya Lin'), findsNothing);

      // Tap "👥 People"
      await tester.tap(find.text('👥 People'));
      await tester.pumpAndSettle();

      // People section shown
      expect(find.text('Maya Lin'), findsOneWidget);

      // Clear search query
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Returns to default Discover hub view
      expect(find.text('NETWORK BATTLEGROUNDS'), findsOneWidget);
      expect(find.text('FRIENDS ARE CURRENTLY BINGING'), findsOneWidget);
    });

    testWidgets('renders empty states when repository returns empty collections', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final emptyRepo = FakeDiscoveryRepository(
        battlegrounds: [],
        friendsBinging: [],
        users: [],
      );

      await tester.pumpWidget(createTestWidget(discoveryRepo: emptyRepo));
      await tester.pumpAndSettle();

      // Discover hub loads, empty battlegrounds and friends binging shrink away, curated canons remain
      expect(find.text('🧭 DISCOVER'), findsOneWidget);
      expect(find.text('NETWORK BATTLEGROUNDS'), findsNothing);
      expect(find.text('FRIENDS ARE CURRENTLY BINGING'), findsNothing);
      expect(find.text('CURATED CANONS'), findsOneWidget);
    });
  });
}

