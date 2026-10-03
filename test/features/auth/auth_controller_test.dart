import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:telly_app/features/auth/presentation/controllers/handle_reservation_controller.dart';

import '../../fakes/fake_auth_repository.dart';

/// FE-601: AuthController is driven by the session stream; no mock pass-through in lib/.
void main() {
  late FakeAuthRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeAuthRepository();
    container = ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);
  });

  Future<void> settle() => pumpEventQueue();

  test('starts initializing, then reflects the restored session', () async {
    final sub = container.listen(authControllerProvider, (_, __) {});
    expect(sub.read().status, AuthStepStatus.initializing);
    await settle();
    expect(container.read(authControllerProvider).status, AuthStepStatus.unauthenticated);
  });

  test('a wrong OTP keeps the user signed out with an error', () async {
    container.listen(authControllerProvider, (_, __) {});
    final controller = container.read(authControllerProvider.notifier);
    await controller.requestPhoneOtp('+1 (555) 123-4567');
    expect(container.read(authControllerProvider).phoneNumber, '+15551234567');

    expect(await controller.verifyOtp('000000'), isFalse);
    final state = container.read(authControllerProvider);
    expect(state.status, AuthStepStatus.awaitingOtp);
    expect(state.errorMessage, contains('Invalid verification code'));
  });

  test('a valid OTP authenticates via the session stream and loads the profile', () async {
    container.listen(authControllerProvider, (_, __) {});
    final controller = container.read(authControllerProvider.notifier);
    await controller.requestPhoneOtp('+15551234567');
    expect(await controller.verifyOtp('123456'), isTrue);
    await settle();

    final state = container.read(authControllerProvider);
    expect(state.status, AuthStepStatus.authenticated);
    expect(state.user?.id, 'phone-user');
    expect(state.user?.hasHandle, isFalse);
  });

  test('sign out returns to unauthenticated through the stream', () async {
    container.listen(authControllerProvider, (_, __) {});
    await container.read(authControllerProvider.notifier).signInWithApple();
    await settle();
    expect(container.read(authControllerProvider).isSignedIn, isTrue);

    await container.read(authControllerProvider.notifier).signOut();
    await settle();
    expect(container.read(authControllerProvider).status, AuthStepStatus.unauthenticated);
  });

  test('OAuth launch failure surfaces an error', () async {
    container.listen(authControllerProvider, (_, __) {});
    repo.failNextCall = true;
    await container.read(authControllerProvider.notifier).signInWithGoogle();
    expect(container.read(authControllerProvider).status, AuthStepStatus.error);
  });

  group('HandleReservationController', () {
    test('debounces lookups: a burst of keystrokes triggers one availability check', () async {
      final sub = container.listen(handleReservationProvider, (_, __) {});
      final c = container.read(handleReservationProvider.notifier);
      c.onHandleChanged('cin');
      c.onHandleChanged('cine');
      c.onHandleChanged('cinelover');
      expect(sub.read().availability, HandleAvailabilityState.checking);

      await Future<void>.delayed(HandleReservationController.debounce + const Duration(milliseconds: 50));
      expect(repo.handleChecks, 1);
      expect(sub.read().availability, HandleAvailabilityState.available);
    });

    test('a handle claimed in a race is reported as taken on submit', () async {
      container.listen(authControllerProvider, (_, __) {});
      await container.read(authControllerProvider.notifier).signInWithApple();
      await settle();

      final sub = container.listen(handleReservationProvider, (_, __) {});
      final c = container.read(handleReservationProvider.notifier)..onHandleChanged('racer');
      await Future<void>.delayed(HandleReservationController.debounce + const Duration(milliseconds: 50));
      repo.takenHandles.add('racer'); // someone else claims it before submit

      expect(await c.submit(displayName: 'Racer'), isFalse);
      expect(sub.read().error, '@racer is already taken');
      expect(sub.read().canSubmit, isFalse);
    });
  });
}
