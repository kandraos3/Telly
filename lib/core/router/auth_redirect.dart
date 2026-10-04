import '../../features/auth/presentation/controllers/auth_controller.dart';
import 'routes.dart';

/// Pure redirect policy for the router (FE-602), unit-testable without widgets.
///
/// no session → SCR-01; session without handle → handle reservation;
/// onboarding incomplete → SCR-02 → SCR-03 → SCR-04; otherwise the app.
String? authRedirect(AuthState auth, String location) {
  bool at(String prefix) => location == prefix || location.startsWith('$prefix/');

  if (auth.status == AuthStepStatus.initializing) {
    return location == Routes.splash ? null : Routes.splash;
  }

  if (!auth.isSignedIn) {
    return at(Routes.auth) ? null : Routes.auth;
  }

  final user = auth.user;
  if (user == null || !user.hasHandle) {
    return location == Routes.handle ? null : Routes.handle;
  }

  if (!user.onboardingCompleted) {
    final inOnboarding = at(Routes.onboarding) && location != Routes.handle;
    return inOnboarding ? null : Routes.streamingSetup;
  }

  if (at(Routes.auth) || at(Routes.onboarding) || location == Routes.splash) {
    return Routes.feed;
  }
  return null;
}
