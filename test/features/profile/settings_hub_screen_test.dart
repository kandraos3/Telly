import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/profile/presentation/screens/settings_hub_screen.dart';

void main() {
  group('SettingsHubScreen Widget Tests (FE-505)', () {
    testWidgets('renders all settings sections and actions properly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsHubScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify app bar title
      expect(find.text('SETTINGS & PREFERENCES'), findsOneWidget);

      // Verify sections
      expect(find.text('ACCOUNT & SECURITY'), findsOneWidget);
      expect(find.text('STREAMING SUBSCRIPTIONS'), findsOneWidget);
      expect(find.text('NOTIFICATION PREFERENCES'), findsOneWidget);
      expect(find.text('STORAGE HYGIENE'), findsOneWidget);
      expect(find.text('DATA PORTABILITY & EXPORTS'), findsOneWidget);
      expect(find.text('LEGAL & COMPLIANCE'), findsOneWidget);

      // Verify toggles exist
      expect(find.text('Biometric FaceID Unlock'), findsOneWidget);
      expect(find.text('Spicy Upset Alerts'), findsOneWidget);
      expect(find.text('Co-Watch Invitations'), findsOneWidget);

      // Verify export buttons exist
      expect(find.text('Export Canon to CSV'), findsOneWidget);
      expect(find.text('Clear Cache'), findsOneWidget);
      expect(find.text('Delete Account'), findsOneWidget);

      // Test tapping clear cache
      await tester.tap(find.text('Clear Cache'));
      await tester.pumpAndSettle();
      expect(find.text('Image cache cleared successfully.'), findsOneWidget);

      // Test tapping export csv
      await tester.tap(find.text('Export Canon to CSV'));
      await tester.pumpAndSettle();
      expect(find.text('Exported 1 records to CSV!'), findsOneWidget);
    });
  });
}

