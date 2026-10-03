import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/widgets/telly_primary_button.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';

import '../../fakes/fake_auth_repository.dart';
import 'package:telly_app/features/auth/presentation/screens/handle_reservation_screen.dart';
import 'package:telly_app/features/onboarding/presentation/screens/streaming_setup_screen.dart';

void main() {
  group('HandleRules (auth spec §3 Username Validation Rules)', () {
    test('valid handles pass', () {
      for (final h in ['jordan', 'cinephile_99', 'film_fanatic', 'tv_buff_1']) {
        expect(HandleRules.validate(h), isNull, reason: h);
      }
    });

    test('input is normalized to lowercase', () {
      expect(HandleRules.normalize('  Jordan_K '), 'jordan_k');
      expect(HandleRules.validate('Jordan_K'), isNull);
    });

    test('short and long handles are rejected', () {
      expect(HandleRules.validate('ab'), 'Handle must be at least 3 characters');
      expect(HandleRules.validate('very_long_handle_exceeding_twenty'), 'Handle cannot exceed 20 characters');
    });

    test('invalid characters and double underscores are rejected', () {
      for (final h in ['with-hyphen', 'has space', 'name!exclamation', 'user@domain']) {
        expect(HandleRules.validate(h), 'Only letters, numbers, and underscores are allowed', reason: h);
      }
      expect(HandleRules.validate('a__b'), 'Underscores cannot be doubled');
    });

    test('reserved platform handles are rejected', () {
      for (final h in ['admin', 'telly', 'netflix', 'hbo', 'apple']) {
        expect(HandleRules.validate(h), '@$h is reserved');
      }
    });
  });

  group('HandleReservationScreen Widget & Flow Tests (FE-107)', () {
    testWidgets('renders screen headers and text fields', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(FakeAuthRepository())],
          child: const MaterialApp(
            home: HandleReservationScreen(),
          ),
        ),
      );

      expect(find.text('Claim your Telly handle'), findsOneWidget);
      expect(find.text('USERNAME'), findsOneWidget);
      expect(find.text('DISPLAY NAME'), findsOneWidget);
      expect(find.text('CONTINUE TO HOUSEHOLD SETUP →'), findsOneWidget);
    });

    testWidgets('entering invalid short handle shows error and disables submit', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(FakeAuthRepository())],
          child: const MaterialApp(
            home: HandleReservationScreen(),
          ),
        ),
      );

      final usernameField = find.widgetWithText(TextField, 'jordan');
      await tester.enterText(usernameField, 'ab');
      await tester.pump();

      expect(find.text('Handle must be at least 3 characters'), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget);

      // Verify submit button is disabled
      final buttonFinder = find.byType(TellyPrimaryButton);
      final button = tester.widget<TellyPrimaryButton>(buttonFinder);
      expect(button.onPressed, isNull);
    });

    testWidgets('entering available handle shows checkmark and enables submit button', (tester) async {
      final fakeRepo = FakeAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: HandleReservationScreen(),
          ),
        ),
      );

      final usernameField = find.widgetWithText(TextField, 'jordan');
      await tester.enterText(usernameField, 'cinelover');
      // Auth spec §3: 200 ms debounce
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Nice! @cinelover is available.'), findsOneWidget);

      // Verify submit button is enabled
      final buttonFinder = find.byType(TellyPrimaryButton);
      final button = tester.widget<TellyPrimaryButton>(buttonFinder);
      expect(button.onPressed, isNotNull);

      // Tap submit and verify navigation to StreamingSetupScreen
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(find.byType(StreamingSetupScreen), findsOneWidget);
    });

    testWidgets('entering taken handle shows taken error text', (tester) async {
      final fakeRepo = FakeAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: HandleReservationScreen(),
          ),
        ),
      );

      final usernameField = find.widgetWithText(TextField, 'jordan');
      await tester.enterText(usernameField, 'taken_user');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('@taken_user is already taken'), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
    });
  });
}
