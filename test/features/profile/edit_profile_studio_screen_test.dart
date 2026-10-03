import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/profile/presentation/screens/edit_profile_studio_screen.dart';

void main() {
  group('EditProfileStudioScreen Widget Tests (FE-507)', () {
    testWidgets('renders all profile fields, top 3 showcase and privacy modes', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      ProfileStudioData? savedData;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  savedData = await Navigator.of(context).push<ProfileStudioData>(
                    MaterialPageRoute(
                      builder: (_) => const EditProfileStudioScreen(),
                    ),
                  );
                },
                child: const Text('Open Studio'),
              ),
            ),
          ),
        ),
      );

      // Open the edit studio screen
      await tester.tap(find.text('Open Studio'));
      await tester.pumpAndSettle();

      // Verify title
      expect(find.text('EDIT PROFILE'), findsOneWidget);
      expect(find.text('DISPLAY NAME'), findsOneWidget);
      expect(find.text('HANDLE'), findsOneWidget);
      expect(find.text('BIO / TV MANIFESTO (MAX 160 CHARS)'), findsOneWidget);
      expect(find.text('FAVORITE SHOWRUNNER / CREATOR'), findsOneWidget);
      expect(find.text('TOP 3 PROFILE SHOWCASE'), findsOneWidget);
      expect(find.text('ACCOUNT VISIBILITY'), findsOneWidget);

      // Verify initial fields
      expect(find.text('Jordan Miller'), findsOneWidget);
      expect(find.text('Succession (HBO)'), findsOneWidget);
      expect(find.text('Severance (Apple TV+)'), findsOneWidget);

      // Test changing visibility mode to Ghost Mode
      await tester.tap(find.text('Ghost Mode'));
      await tester.pumpAndSettle();

      // Test changing iconic avatar
      await tester.tap(find.text('Change Iconic Avatar'));
      await tester.pumpAndSettle();

      expect(find.text('CHOOSE ICONIC AVATAR'), findsOneWidget);
      await tester.tap(find.text('🧇 Lumon Waffle'));
      await tester.pumpAndSettle();

      // Test saving profile
      await tester.tap(find.text('Save ✓'));
      await tester.pumpAndSettle();

      // Verify saved state returned
      expect(savedData, isNotNull);
      expect(savedData!.displayName, equals('Jordan Miller'));
      expect(savedData!.visibilityMode, equals('GHOST'));
      expect(savedData!.avatarUrl, equals('🧇 Lumon Waffle'));
    });
  });
}

