import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';

import '../../fakes/fake_auth_repository.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/widgets/telly_logo.dart';
import 'package:telly_app/features/auth/presentation/screens/auth_screen.dart';
import 'package:telly_app/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:telly_app/features/auth/presentation/widgets/auth_poster_backdrop.dart';
import 'package:telly_app/features/legal/domain/legal_markdown.dart';
import 'package:telly_app/features/legal/presentation/screens/legal_document_screen.dart';

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

    testWidgets('renders the vector Telly logo over the scrimmed poster mosaic (FE-AUTH-01)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(FakeAuthRepository())],
          child: const MaterialApp(home: AuthScreen()),
        ),
      );

      expect(find.byType(TellyLogo), findsOneWidget);
      expect(find.text('📺'), findsNothing);
      expect(find.byType(AuthPosterBackdrop), findsOneWidget);
      expect(
        find.byWidgetPredicate(
            (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('auth-backdrop-poster-')),
        findsNWidgets(AuthPosterBackdrop.columns * AuthPosterBackdrop.rows),
      );

      final scrim = tester.widget<DecoratedBox>(find.byKey(const ValueKey('auth-backdrop-scrim')));
      final gradient = (scrim.decoration as BoxDecoration).gradient! as LinearGradient;
      expect(gradient.colors.first, TellyColors.backgroundPrimary.withValues(alpha: 0.8));
      expect(gradient.colors.every((c) => c.a >= 0.8), isTrue);
    });

    testWidgets('Forgot Password? sends a reset email and confirms (FE-AUTH-03)', (tester) async {
      final fakeRepo = FakeAuthRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
          child: const MaterialApp(home: AuthScreen()),
        ),
      );

      await tester.tap(find.text('Continue with Email'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'maya@example.com');
      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      expect(find.text('Reset Your Password'), findsOneWidget);
      // The email typed in the sign-in sheet is carried over.
      expect(find.widgetWithText(TextField, 'maya@example.com'), findsNWidgets(2));

      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(fakeRepo.resetEmailsSent, ['maya@example.com']);
      expect(find.byKey(const ValueKey('reset-email-sent-banner')), findsOneWidget);
    });

    testWidgets('Forgot Password? is hidden in sign-up mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(FakeAuthRepository())],
          child: const MaterialApp(home: AuthScreen()),
        ),
      );
      await tester.tap(find.text('Continue with Email'));
      await tester.pumpAndSettle();
      expect(find.text('Forgot Password?'), findsOneWidget);
      await tester.tap(find.text("Don't have an account? Sign Up"));
      await tester.pumpAndSettle();
      expect(find.text('Forgot Password?'), findsNothing);
    });

    testWidgets('ResetPasswordScreen validates and saves the new password (FE-AUTH-03)', (tester) async {
      final fakeRepo = FakeAuthRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
          child: const MaterialApp(home: ResetPasswordScreen()),
        ),
      );

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'n3w-secret');
      await tester.enterText(fields.at(1), 'different');
      await tester.tap(find.text('Save Password'));
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(fakeRepo.updatedPassword, isNull);

      await tester.enterText(fields.at(1), 'n3w-secret');
      await tester.tap(find.text('Save Password'));
      await tester.pumpAndSettle();
      expect(fakeRepo.updatedPassword, 'n3w-secret');
    });

    for (final doc in LegalDocument.values) {
      testWidgets('tapping ${doc.title} opens the in-app legal viewer (FE-AUTH-04)', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [authRepositoryProvider.overrideWithValue(FakeAuthRepository())],
            child: const MaterialApp(home: AuthScreen()),
          ),
        );

        await tester.tap(find.widgetWithText(TextButton, doc.title));
        await tester.pumpAndSettle();

        expect(find.byType(LegalDocumentScreen), findsOneWidget);
        expect(find.textContaining('Last Updated', findRichText: true), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(LegalDocumentScreen), findsNothing);
      });
    }
  });
}
