import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';

import '../../fakes/fake_auth_repository.dart';
import 'package:telly_app/features/auth/presentation/screens/auth_screen.dart';
import 'package:telly_app/features/auth/presentation/screens/handle_reservation_screen.dart';

void main() {
  group('SCR-01 AuthScreen Widget & Flow Tests (FE-106)', () {
    testWidgets('renders brand title, tagline, and all three login buttons', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(FakeAuthRepository())],
          child: const MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );

      // Verify Brand Title & Tagline
      expect(find.text('TELLY'), findsOneWidget);
      expect(find.textContaining('Your Personal TV Canon'), findsOneWidget);

      // Verify 3 Auth Buttons
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Phone Number'), findsOneWidget);
    });

    testWidgets('tapping Continue with Phone opens the phone number sheet', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(FakeAuthRepository())],
          child: const MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );

      // Tap Phone Auth Button
      await tester.tap(find.text('Continue with Phone Number'));
      await tester.pumpAndSettle();

      // Verify Frosted Sheet appears
      expect(find.text('Sign In with Phone'), findsOneWidget);
      expect(find.text('Send Verification Code'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('complete phone authentication flow with 6-digit OTP verification', (tester) async {
      final fakeRepo = FakeAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );

      // Open Phone Auth
      await tester.tap(find.text('Continue with Phone Number'));
      await tester.pumpAndSettle();

      // Enter phone number
      await tester.enterText(find.byType(TextField), '+15551234567');
      await tester.pumpAndSettle();

      // Tap Send Verification Code
      await tester.tap(find.text('Send Verification Code'));
      await tester.pumpAndSettle();

      // Sheet should now display OTP entry
      expect(find.text('Enter 6-Digit Code'), findsOneWidget);
      expect(find.text('Verify & Continue'), findsOneWidget);

      // Enter 6-digit OTP
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pumpAndSettle();

      // Tap Verify & Continue
      await tester.tap(find.text('Verify & Continue'));
      await tester.pumpAndSettle();

      // Navigation to HandleReservationScreen
      expect(find.byType(HandleReservationScreen), findsOneWidget);
    });

    testWidgets('tapping Apple button triggers signInWithApple and transitions state', (tester) async {
      final fakeRepo = FakeAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );

      // Tap Apple Auth Button
      await tester.tap(find.text('Continue with Apple'));
      await tester.pumpAndSettle();

      // Should transition to HandleReservationScreen upon successful auth
      expect(find.byType(HandleReservationScreen), findsOneWidget);
    });

    testWidgets('tapping Google button triggers signInWithGoogle and transitions state', (tester) async {
      final fakeRepo = FakeAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );

      // Tap Google Auth Button
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      // Should transition to HandleReservationScreen upon successful auth
      expect(find.byType(HandleReservationScreen), findsOneWidget);
    });
  });
}
