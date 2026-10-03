import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/widgets/telly_primary_button.dart';
import 'package:telly_app/features/onboarding/presentation/screens/seed_grid_screen.dart';

void main() {
  group('SCR-03 SeedGridScreen Widget & Gating Tests (FE-109)', () {
    void setupMobileViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    testWidgets('renders screen headers, 1-click import actions, and category chips', (tester) async {
      setupMobileViewport(tester);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SeedGridScreen(),
          ),
        ),
      );

      expect(find.text('Tap titles you have watched'), findsOneWidget);
      expect(find.text('Import from Letterboxd'), findsOneWidget);
      expect(find.text('Import from AniList / MyAnimeList'), findsOneWidget);

      // Verify category filter chips
      expect(find.text('All (50)'), findsOneWidget);
      expect(find.text('🎬 Movies (15)'), findsOneWidget);
      expect(find.text('📺 TV Series (20)'), findsOneWidget);
      expect(find.text('⛩️ Anime (15)'), findsOneWidget);

      // Verify CTA starts disabled with 0/5
      expect(find.text('SELECT AT LEAST 5 TITLES (0/5)'), findsOneWidget);
      final button = tester.widget<TellyPrimaryButton>(find.byType(TellyPrimaryButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('filtering by category changes displayed titles in grid', (tester) async {
      setupMobileViewport(tester);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SeedGridScreen(),
          ),
        ),
      );

      // Initially All (contains Succession and Interstellar)
      expect(find.text('Succession'), findsOneWidget);

      // Tap Movies filter chip
      await tester.ensureVisible(find.text('🎬 Movies (15)'));
      await tester.tap(find.text('🎬 Movies (15)'));
      await tester.pumpAndSettle();

      // Movie titles should be present, TV titles absent
      expect(find.text('Interstellar'), findsOneWidget);
      expect(find.text('Succession'), findsNothing);

      // Tap Anime filter chip
      await tester.ensureVisible(find.text('⛩️ Anime (15)'));
      await tester.tap(find.text('⛩️ Anime (15)'));
      await tester.pumpAndSettle();

      // Anime titles present, Movies absent
      expect(find.text('Attack on Titan'), findsOneWidget);
      expect(find.text('Interstellar'), findsNothing);

      // Tap All filter chip
      await tester.ensureVisible(find.text('All (50)'));
      await tester.tap(find.text('All (50)'));
      await tester.pumpAndSettle();

      expect(find.text('Succession'), findsOneWidget);
    });

    testWidgets('CTA button enables strictly when 5 or more titles are selected', (tester) async {
      setupMobileViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            selectedSeedTitlesProvider.overrideWith((ref) => <int>{}),
            seedCategoryFilterProvider.overrideWith((ref) => 'all'),
          ],
          child: const MaterialApp(
            home: SeedGridScreen(),
          ),
        ),
      );

      // 0 selected: disabled
      var button = tester.widget<TellyPrimaryButton>(find.byType(TellyPrimaryButton));
      expect(button.onPressed, isNull);
      expect(find.text('SELECT AT LEAST 5 TITLES (0/5)'), findsOneWidget);

      // Select 1st title: Succession (id: 76331)
      await tester.tap(find.byKey(const ValueKey('seed_card_76331')));
      await tester.pumpAndSettle();
      expect(find.text('SELECT AT LEAST 5 TITLES (1/5)'), findsOneWidget);

      // Select 2nd title: Severance (id: 110492)
      await tester.tap(find.byKey(const ValueKey('seed_card_110492')));
      await tester.pumpAndSettle();
      expect(find.text('SELECT AT LEAST 5 TITLES (2/5)'), findsOneWidget);

      // Select 3rd title: Breaking Bad (id: 1396)
      await tester.tap(find.byKey(const ValueKey('seed_card_1396')));
      await tester.pumpAndSettle();
      expect(find.text('SELECT AT LEAST 5 TITLES (3/5)'), findsOneWidget);

      // Select 4th title: The Bear (id: 124834)
      await tester.tap(find.byKey(const ValueKey('seed_card_124834')));
      await tester.pumpAndSettle();
      expect(find.text('SELECT AT LEAST 5 TITLES (4/5)'), findsOneWidget);

      // Still disabled at 4 items
      button = tester.widget<TellyPrimaryButton>(find.byType(TellyPrimaryButton));
      expect(button.onPressed, isNull);

      // Select 5th title: Game of Thrones (id: 1399)
      await tester.tap(find.byKey(const ValueKey('seed_card_1399')));
      await tester.pumpAndSettle();

      // Now 5 selected: Enabled!
      expect(find.text('BEGIN PAIRWISE DUELS (5 SELECTED) →'), findsOneWidget);
      button = tester.widget<TellyPrimaryButton>(find.byType(TellyPrimaryButton));
      expect(button.onPressed, isNotNull);

      // Deselect 1 title (tap Succession again)
      await tester.tap(find.byKey(const ValueKey('seed_card_76331')));
      await tester.pumpAndSettle();

      // Count drops back to 4: disabled again
      expect(find.text('SELECT AT LEAST 5 TITLES (4/5)'), findsOneWidget);
      button = tester.widget<TellyPrimaryButton>(find.byType(TellyPrimaryButton));
      expect(button.onPressed, isNull);
    });
  });
}
