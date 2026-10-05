import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/database/database.dart';
import '../../data/auth_repository.dart';
import '../../domain/user_profile.dart';

enum AuthStepStatus {
  /// Waiting for the first session event (cold start / restored session).
  initializing,
  unauthenticated,
  authenticating,
  awaitingOtp,
  authenticated,
  error,
}

class AuthState {
  final AuthStepStatus status;
  final UserProfile? user;
  final String? phoneNumber;
  final String? errorMessage;

  /// Set when a password recovery link opened the app; the router holds the user on the
  /// reset-password screen until a new password is saved (FE-AUTH-03).
  final bool passwordRecovery;

  const AuthState({
    this.status = AuthStepStatus.unauthenticated,
    this.user,
    this.phoneNumber,
    this.errorMessage,
    this.passwordRecovery = false,
  });

  bool get isSignedIn => status == AuthStepStatus.authenticated;

  /// `errorMessage` is cleared unless explicitly provided.
  AuthState copyWith({
    AuthStepStatus? status,
    UserProfile? user,
    String? phoneNumber,
    String? errorMessage,
    bool? passwordRecovery,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      errorMessage: errorMessage,
      passwordRecovery: passwordRecovery ?? this.passwordRecovery,
    );
  }
}

/// Auth state machine driven by the Supabase session stream (FE-601).
/// Sign-in methods only start flows; the authenticated state always comes from the session.
class AuthController extends Notifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    final repository = ref.watch(authRepositoryProvider);
    final subscription = repository.watchSignedInUserId().listen(_onSessionChanged);
    final recovery = repository.watchPasswordRecovery().listen((_) {
      state = state.copyWith(passwordRecovery: true);
    });
    ref.onDispose(() {
      subscription.cancel();
      recovery.cancel();
    });
    return const AuthState(status: AuthStepStatus.initializing);
  }

  Future<void> _onSessionChanged(String? userId) async {
    if (userId == null) {
      // Only reset when leaving a signed-in/initial state; a signed-out event must not
      // wipe an in-progress OTP flow (phone number, awaitingOtp).
      if (state.isSignedIn || state.status == AuthStepStatus.initializing) {
        state = const AuthState(status: AuthStepStatus.unauthenticated);
      }
      return;
    }
    try {
      final profile = await _repository.fetchCurrentProfile();
      state = AuthState(status: AuthStepStatus.authenticated, user: profile, passwordRecovery: state.passwordRecovery);
    } catch (_) {
      state = AuthState(
        status: AuthStepStatus.authenticated,
        errorMessage: 'Signed in, but your profile could not be loaded.',
        passwordRecovery: state.passwordRecovery,
      );
    }
  }

  /// Re-reads the profile row (e.g. after onboarding marks it complete).
  Future<void> refreshProfile() => _onSessionChanged(_repository.currentUserId);

  Future<void> signInWithApple() => _startOAuth(_repository.signInWithApple, 'Apple sign in failed. Please try again.');

  Future<void> signInWithGoogle() =>
      _startOAuth(_repository.signInWithGoogle, 'Google sign in failed. Please try again.');

  Future<bool> signInWithEmail({required String email, required String password}) async {
    state = state.copyWith(status: AuthStepStatus.authenticating);
    try {
      await _repository.signInWithEmail(email: email, password: password);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(status: AuthStepStatus.error, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        status: AuthStepStatus.error,
        errorMessage: 'Invalid email or password.',
      );
      return false;
    }
  }

  Future<bool> signUpWithEmail({required String email, required String password}) async {
    state = state.copyWith(status: AuthStepStatus.authenticating);
    try {
      final hasSession = await _repository.signUpWithEmail(email: email, password: password);
      if (!hasSession) {
        state = state.copyWith(
          status: AuthStepStatus.unauthenticated,
          errorMessage: 'Account created! Please check your email to confirm.',
        );
      }
      return hasSession;
    } on AuthException catch (e) {
      state = state.copyWith(status: AuthStepStatus.error, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        status: AuthStepStatus.error,
        errorMessage: 'Account creation failed. Please try again.',
      );
      return false;
    }
  }

  /// Sends the recovery email. Returns true on success; failures land in `errorMessage`.
  Future<bool> sendPasswordReset(String email) async {
    try {
      await _repository.sendPasswordResetEmail(email);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Could not send the reset email. Please try again.');
      return false;
    }
  }

  /// Saves the new password and releases the router from the recovery screen.
  Future<bool> updatePassword(String newPassword) async {
    try {
      await _repository.updatePassword(newPassword);
      state = state.copyWith(passwordRecovery: false);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Could not update your password. Please try again.');
      return false;
    }
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }

  Future<void> _startOAuth(Future<void> Function() launch, String failure) async {
    state = state.copyWith(status: AuthStepStatus.authenticating);
    try {
      await launch();
      // The browser flow continues outside the app; the session stream completes sign-in.
      if (state.status == AuthStepStatus.authenticating) {
        state = state.copyWith(status: AuthStepStatus.unauthenticated);
      }
    } catch (_) {
      state = state.copyWith(status: AuthStepStatus.error, errorMessage: failure);
    }
  }

  Future<void> requestPhoneOtp(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[\s()-]'), '');
    state = state.copyWith(status: AuthStepStatus.authenticating, phoneNumber: cleanPhone);
    try {
      await _repository.sendPhoneOtp(cleanPhone);
      state = state.copyWith(status: AuthStepStatus.awaitingOtp);
    } catch (_) {
      state = state.copyWith(
        status: AuthStepStatus.error,
        errorMessage: 'Failed to send SMS verification code.',
      );
    }
  }

  Future<bool> verifyOtp(String otpCode) async {
    final phone = state.phoneNumber;
    if (phone == null) return false;

    state = state.copyWith(status: AuthStepStatus.authenticating);
    try {
      final success = await _repository.verifyPhoneOtp(phone, otpCode.trim());
      if (!success) {
        state = state.copyWith(
          status: AuthStepStatus.awaitingOtp,
          errorMessage: 'Invalid verification code. Please check and re-enter.',
        );
      }
      return success;
    } catch (_) {
      state = state.copyWith(
        status: AuthStepStatus.awaitingOtp,
        errorMessage: 'Verification failed. Please try again.',
      );
      return false;
    }
  }

  Future<bool> completeOnboarding({
    required String username,
    required String displayName,
    String? avatarUrl,
  }) async {
    try {
      final user = await _repository.completeRegistration(
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
      );
      state = state.copyWith(user: user);
      return true;
    } on HandleTakenException catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Failed to save profile.');
      return false;
    }
  }

  /// Marks onboarding complete and reloads the profile so the router leaves the onboarding flow.
  Future<void> finishOnboarding() async {
    await _repository.markOnboardingCompleted();
    await refreshProfile();
  }

  /// Deletes account via 30-day soft deletion RPC, wipes local Drift DB and secure storage, and signs out (LEGAL-601).
  Future<DateTime> deleteAccount({required AppDatabase database}) async {
    final gracePeriodEnd = await _repository.requestAccountDeletion();
    await database.wipeLocalData();
    try {
      await const FlutterSecureStorage().deleteAll();
    } catch (_) {}
    await signOut();
    return gracePeriodEnd;
  }

  Future<void> signOut() => _repository.signOut();
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
