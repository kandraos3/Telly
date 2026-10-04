import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';

import '../../fakes/fake_auth_repository.dart';
import 'package:telly_app/features/auth/presentation/screens/auth_screen.dart';

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
      expect(find.text('Continue with Email'), findsOneWidget);
    });

    testWidgets('tapping Continue with Email opens the email auth sheet', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(FakeAuthRepository())],
          child: const MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );

      // Tap Email Auth Button
      await tester.tap(find.text('Continue with Email'));
      await tester.pumpAndSettle();

      // Verify Frosted Sheet appears
      expect(find.text('Sign In with Email'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text("Don't have an account? Sign Up"), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2)); // Email & Password
    });

    testWidgets('complete email sign-in flow', (tester) async {
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

      // Open Email Auth
      await tester.tap(find.text('Continue with Email'));
      await tester.pumpAndSettle();

      // Enter email and password
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'alex@example.com');
      await tester.enterText(textFields.at(1), 'password123');
      await tester.pumpAndSettle();

      // Tap Sign In
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // Signed in through the session stream; sheet closes
      expect(fakeRepo.currentUserId, 'email-user');
      expect(find.text('Sign In with Email'), findsNothing);
    });

    testWidgets('toggle to sign up mode and complete email registration', (tester) async {
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

      // Open Email Auth
      await tester.tap(find.text('Continue with Email'));
      await tester.pumpAndSettle();

      // Toggle to Sign Up
      await tester.tap(find.text("Don't have an account? Sign Up"));
      await tester.pumpAndSettle();

      expect(find.text('Create an Account'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(3)); // Email, Password, Confirm Password

      // Fill in registration fields
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'newuser@example.com');
      await tester.enterText(textFields.at(1), 'securepassword');
      await tester.enterText(textFields.at(2), 'securepassword');
      await tester.pumpAndSettle();

      // Tap Create Account
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(fakeRepo.currentUserId, 'email-user');
      expect(find.text('Create an Account'), findsNothing);
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

      // Signed in through the session stream; navigation is the router's job (FE-602).
      expect(fakeRepo.currentUserId, isNotNull);
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

      // Signed in through the session stream; navigation is the router's job (FE-602).
      expect(fakeRepo.currentUserId, isNotNull);
    });
  });
}
