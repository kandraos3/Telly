import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/widgets/telly_primary_button.dart';
import 'package:telly_app/features/onboarding/presentation/screens/seed_grid_screen.dart';
import 'package:telly_app/features/onboarding/presentation/screens/streaming_setup_screen.dart';

void main() {
  group('SCR-02 StreamingSetupScreen Widget & Flow Tests (FE-108)', () {
    void setupMobileViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    testWidgets('renders screen title, provider cards, free platforms checkbox, and CTA button', (tester) async {
      setupMobileViewport(tester);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: StreamingSetupScreen(),
          ),
        ),
      );

      expect(find.text('Where do you watch?'), findsOneWidget);
      expect(find.textContaining('Select your active subscriptions'), findsOneWidget);

      // Verify core providers exist
      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('Max'), findsOneWidget);
      expect(find.text('Apple TV+'), findsOneWidget);
      expect(find.text('Hulu'), findsOneWidget);
      expect(find.text('Disney+'), findsOneWidget);
      expect(find.text('Prime Video'), findsOneWidget);
      expect(find.text('Crunchyroll'), findsOneWidget);
      expect(find.text('Paramount+'), findsOneWidget);

      // Verify Free platforms toggle & skip option
      expect(find.textContaining('Include free platforms'), findsOneWidget);
      expect(find.textContaining("I don't have streaming services"), findsOneWidget);

      // Verify initial selected count in CTA button
      expect(find.byType(TellyPrimaryButton), findsOneWidget);
      expect(find.textContaining('CONTINUE (3 SELECTED) →'), findsOneWidget);
    });

    testWidgets('tapping a provider card toggles selection and updates counter', (tester) async {
      setupMobileViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            selectedProvidersProvider.overrideWith((ref) => {'netflix'}),
          ],
          child: const MaterialApp(
            home: StreamingSetupScreen(),
          ),
        ),
      );

      // Initially 1 selected
      expect(find.text('CONTINUE (1 SELECTED) →'), findsOneWidget);

      // Tap to add Disney+
      await tester.tap(find.text('Disney+'));
      await tester.pumpAndSettle();

      // Now 2 selected
      expect(find.text('CONTINUE (2 SELECTED) →'), findsOneWidget);

      // Tap to deselect Netflix
      await tester.tap(find.text('Netflix'));
      await tester.pumpAndSettle();

      // Now 1 selected
      expect(find.text('CONTINUE (1 SELECTED) →'), findsOneWidget);
    });

    testWidgets('toggling free platforms checkbox updates state', (tester) async {
      setupMobileViewport(tester);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: StreamingSetupScreen(),
          ),
        ),
      );

      final checkboxFinder = find.byType(Checkbox);
      expect(tester.widget<Checkbox>(checkboxFinder).value, isFalse);

      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<Checkbox>(checkboxFinder).value, isTrue);
    });

    testWidgets('tapping continue navigates to SeedGridScreen', (tester) async {
      setupMobileViewport(tester);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: StreamingSetupScreen(),
          ),
        ),
      );

      await tester.tap(find.byType(TellyPrimaryButton));
      await tester.pumpAndSettle();

      expect(find.byType(SeedGridScreen), findsOneWidget);
    });

    testWidgets('tapping skip for now navigates to SeedGridScreen', (tester) async {
      setupMobileViewport(tester);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: StreamingSetupScreen(),
          ),
        ),
      );

      await tester.tap(find.textContaining("I don't have streaming services"));
      await tester.pumpAndSettle();

      expect(find.byType(SeedGridScreen), findsOneWidget);
    });
  });
}
