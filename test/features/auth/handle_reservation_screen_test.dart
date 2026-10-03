import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/widgets/telly_primary_button.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/presentation/screens/handle_reservation_screen.dart';
import 'package:telly_app/features/onboarding/presentation/screens/streaming_setup_screen.dart';

void main() {
  group('Handle Validation & Reservation Unit Tests (FE-107)', () {
    final repo = DefaultAuthRepository();

    test('valid handles pass regex and uniqueness check', () async {
      expect(await repo.checkHandleAvailable('jordan'), isTrue);
      expect(await repo.checkHandleAvailable('cinephile_99'), isTrue);
      expect(await repo.checkHandleAvailable('film_fanatic'), isTrue);
      expect(await repo.checkHandleAvailable('tv_buff_1'), isTrue);
    });

    test('short handles (< 3 characters) are rejected', () async {
      expect(await repo.checkHandleAvailable('a'), isFalse);
      expect(await repo.checkHandleAvailable('ab'), isFalse);
      expect(await repo.checkHandleAvailable(''), isFalse);
    });

    test('long handles (> 20 characters) are rejected', () async {
      expect(
        await repo.checkHandleAvailable('very_long_handle_exceeding_twenty'),
        isFalse,
      );
    });

    test('handles with invalid characters are rejected', () async {
      expect(await repo.checkHandleAvailable('with-hyphen'), isFalse);
      expect(await repo.checkHandleAvailable('has space'), isFalse);
      expect(await repo.checkHandleAvailable('name!exclamation'), isFalse);
      expect(await repo.checkHandleAvailable('user@domain'), isFalse);
    });

    test('reserved platform handles are rejected', () async {
      expect(await repo.checkHandleAvailable('admin'), isFalse);
      expect(await repo.checkHandleAvailable('telly'), isFalse);
      expect(await repo.checkHandleAvailable('netflix'), isFalse);
      expect(await repo.checkHandleAvailable('hbo'), isFalse);
      expect(await repo.checkHandleAvailable('apple'), isFalse);
    });

    test('already claimed handles are rejected', () async {
      expect(await repo.checkHandleAvailable('taken_user'), isFalse);
    });
  });

  group('HandleReservationScreen Widget & Flow Tests (FE-107)', () {
    testWidgets('renders screen headers and text fields', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
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
        const ProviderScope(
          child: MaterialApp(
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
      final fakeRepo = DefaultAuthRepository();

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
      // Wait for 300ms debounce timer
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
      final fakeRepo = DefaultAuthRepository();

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
