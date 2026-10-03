import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';
import 'auth_controller.dart';

enum HandleAvailabilityState { initial, checking, available, unavailable, invalid }

class HandleReservationState {
  final String handle;
  final HandleAvailabilityState availability;
  final String? error;
  final bool isSubmitting;

  const HandleReservationState({
    this.handle = '',
    this.availability = HandleAvailabilityState.initial,
    this.error,
    this.isSubmitting = false,
  });

  bool get canSubmit => availability == HandleAvailabilityState.available && !isSubmitting;

  HandleReservationState copyWith({
    String? handle,
    HandleAvailabilityState? availability,
    String? error,
    bool? isSubmitting,
  }) =>
      HandleReservationState(
        handle: handle ?? this.handle,
        availability: availability ?? this.availability,
        error: error,
        isSubmitting: isSubmitting ?? this.isSubmitting,
      );
}

/// Debounced `check_handle_available` lookups and handle submission (FE-107; auth spec §3).
class HandleReservationController extends AutoDisposeNotifier<HandleReservationState> {
  /// Auth spec §3 "Live Debouncing": 200 ms.
  static const debounce = Duration(milliseconds: 200);

  Timer? _timer;
  int _requestSeq = 0;

  @override
  HandleReservationState build() {
    ref.onDispose(() => _timer?.cancel());
    return const HandleReservationState();
  }

  void onHandleChanged(String raw) {
    _timer?.cancel();
    final handle = HandleRules.normalize(raw);

    if (handle.isEmpty) {
      state = const HandleReservationState();
      return;
    }

    final error = HandleRules.validate(handle);
    if (error != null) {
      state = HandleReservationState(handle: handle, availability: HandleAvailabilityState.invalid, error: error);
      return;
    }

    state = HandleReservationState(handle: handle, availability: HandleAvailabilityState.checking);
    final seq = ++_requestSeq;
    _timer = Timer(debounce, () async {
      bool available;
      try {
        available = await ref.read(authRepositoryProvider).checkHandleAvailable(handle);
      } catch (_) {
        if (seq == _requestSeq) {
          state = state.copyWith(
            availability: HandleAvailabilityState.invalid,
            error: 'Could not check availability. Check your connection.',
          );
        }
        return;
      }
      if (seq != _requestSeq) return; // a newer keystroke superseded this lookup
      state = state.copyWith(
        availability: available ? HandleAvailabilityState.available : HandleAvailabilityState.unavailable,
        error: available ? null : '@$handle is already taken',
      );
    });
  }

  Future<bool> submit({required String displayName}) async {
    if (!state.canSubmit) return false;
    state = state.copyWith(isSubmitting: true);
    final handle = state.handle;
    final ok = await ref.read(authControllerProvider.notifier).completeOnboarding(
          username: handle,
          displayName: displayName.trim().isEmpty ? handle : displayName.trim(),
        );
    state = ok
        ? state.copyWith(isSubmitting: false)
        : state.copyWith(
            isSubmitting: false,
            availability: HandleAvailabilityState.unavailable,
            error: ref.read(authControllerProvider).errorMessage ?? 'Failed to save profile.',
          );
    return ok;
  }
}

final handleReservationProvider =
    NotifierProvider.autoDispose<HandleReservationController, HandleReservationState>(HandleReservationController.new);
