import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/router/auth_redirect.dart';
import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/features/auth/presentation/controllers/auth_controller.dart';

void main() {
  final created = DateTime(2026);
  AuthState signedIn({String? handle, bool onboarded = false}) => AuthState(
        status: AuthStepStatus.authenticated,
        user: UserProfile(
          id: 'u1',
          username: handle,
          displayName: 'U',
          onboardingCompleted: onboarded,
          createdAt: created,
        ),
      );

  group('FE-602: authRedirect', () {
    test('initializing holds every location on the splash', () {
      const s = AuthState(status: AuthStepStatus.initializing);
      expect(authRedirect(s, Routes.home), Routes.splash);
      expect(authRedirect(s, Routes.splash), isNull);
    });

    test('no session → SCR-01, whatever was requested', () {
      for (final status in [
        AuthStepStatus.unauthenticated,
        AuthStepStatus.authenticating,
        AuthStepStatus.awaitingOtp,
        AuthStepStatus.error,
      ]) {
        final s = AuthState(status: status);
        expect(authRedirect(s, Routes.home), Routes.auth, reason: '$status');
        expect(authRedirect(s, Routes.title('tv', 1396)), Routes.auth, reason: '$status');
        expect(authRedirect(s, Routes.auth), isNull, reason: '$status');
      }
    });

    test('session without handle → handle reservation', () {
      expect(authRedirect(signedIn(), Routes.home), Routes.handle);
      expect(authRedirect(signedIn(), Routes.streamingSetup), Routes.handle);
      expect(authRedirect(signedIn(), Routes.handle), isNull);
      // A profile that failed to load is treated the same (cannot prove a handle exists).
      expect(authRedirect(const AuthState(status: AuthStepStatus.authenticated), Routes.home), Routes.handle);
    });

    test('handle but onboarding incomplete → SCR-02, and SCR-02…SCR-04 are allowed', () {
      final s = signedIn(handle: 'maya');
      expect(authRedirect(s, Routes.home), Routes.streamingSetup);
      expect(authRedirect(s, Routes.handle), Routes.streamingSetup);
      expect(authRedirect(s, Routes.auth), Routes.streamingSetup);
      for (final step in [Routes.streamingSetup, Routes.seedGrid, Routes.tournament]) {
        expect(authRedirect(s, step), isNull, reason: step);
      }
    });

    test('onboarded users leave auth/onboarding/splash for Home and keep app routes', () {
      final s = signedIn(handle: 'maya', onboarded: true);
      for (final from in [Routes.splash, Routes.auth, Routes.handle, Routes.seedGrid]) {
        expect(authRedirect(s, from), Routes.home, reason: from);
      }
      for (final at in [
        Routes.home,
        Routes.social,
        Routes.more,
        Routes.queue,
        Routes.title('movie', 27205),
        Routes.profile('maya'),
        Routes.log,
      ]) {
        expect(authRedirect(s, at), isNull, reason: at);
      }
    });

    test('prefix matching does not treat /authors as /auth', () {
      final s = signedIn(handle: 'maya', onboarded: true);
      expect(authRedirect(s, '/authors'), isNull);
    });
  });

  test('FE-AUTH-03: a recovery session is held on the reset-password screen', () {
    final s = AuthState(
      status: AuthStepStatus.authenticated,
      user: signedIn(handle: 'maya', onboarded: true).user,
      passwordRecovery: true,
    );
    expect(authRedirect(s, Routes.home), Routes.resetPassword);
    expect(authRedirect(s, Routes.auth), Routes.resetPassword);
    expect(authRedirect(s, Routes.resetPassword), isNull);
    // Once saved, the screen hands back to the normal flow.
    expect(authRedirect(signedIn(handle: 'maya', onboarded: true), Routes.resetPassword), Routes.home);
    expect(authRedirect(signedIn(handle: 'maya'), Routes.resetPassword), Routes.streamingSetup);
    // Recovery never applies without a session.
    const out = AuthState(status: AuthStepStatus.unauthenticated, passwordRecovery: true);
    expect(authRedirect(out, Routes.resetPassword), Routes.auth);
  });
}
