import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';
import '../../domain/user_profile.dart';

enum AuthStepStatus {
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

  const AuthState({
    this.status = AuthStepStatus.unauthenticated,
    this.user,
    this.phoneNumber,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStepStatus? status,
    UserProfile? user,
    String? phoneNumber,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      errorMessage: errorMessage,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthController(this._repository) : super(const AuthState());

  Future<void> signInWithApple() async {
    state = state.copyWith(status: AuthStepStatus.authenticating, errorMessage: null);
    try {
      await _repository.signInWithApple();
      state = state.copyWith(
        status: AuthStepStatus.authenticated,
        user: _repository.currentUser,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStepStatus.error,
        errorMessage: 'Apple sign in failed. Please try again.',
      );
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(status: AuthStepStatus.authenticating, errorMessage: null);
    try {
      await _repository.signInWithGoogle();
      state = state.copyWith(
        status: AuthStepStatus.authenticated,
        user: _repository.currentUser,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStepStatus.error,
        errorMessage: 'Google sign in failed. Please try again.',
      );
    }
  }

  Future<void> requestPhoneOtp(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    state = state.copyWith(
      status: AuthStepStatus.authenticating,
      phoneNumber: cleanPhone,
      errorMessage: null,
    );
    try {
      await _repository.sendPhoneOtp(cleanPhone);
      state = state.copyWith(status: AuthStepStatus.awaitingOtp);
    } catch (e) {
      state = state.copyWith(
        status: AuthStepStatus.error,
        errorMessage: 'Failed to send SMS verification code.',
      );
    }
  }

  Future<bool> verifyOtp(String otpCode) async {
    final phone = state.phoneNumber;
    if (phone == null) return false;

    state = state.copyWith(status: AuthStepStatus.authenticating, errorMessage: null);
    try {
      final success = await _repository.verifyPhoneOtp(phone, otpCode);
      if (success) {
        state = state.copyWith(
          status: AuthStepStatus.authenticated,
          user: _repository.currentUser,
        );
        return true;
      } else {
        state = state.copyWith(
          status: AuthStepStatus.awaitingOtp,
          errorMessage: 'Invalid verification code. Please check and re-enter.',
        );
        return false;
      }
    } catch (e) {
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
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to save profile.');
      return false;
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AuthState();
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
