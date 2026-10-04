import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/supabase_providers.dart';
import '../domain/user_profile.dart';

/// Thrown when a handle was claimed by someone else between the availability check and submit.
class HandleTakenException implements Exception {
  final String handle;
  const HandleTakenException(this.handle);
  @override
  String toString() => '@$handle is already taken';
}

/// Authentication & profile bootstrap (adjacent_systems/01, BE-103, FE-106, FE-107).
abstract class AuthRepository {
  /// Emits the signed-in user id, or null when signed out. Emits the current value first.
  Stream<String?> watchSignedInUserId();

  String? get currentUserId;

  /// Starts the provider OAuth flow; completion arrives through [watchSignedInUserId].
  Future<void> signInWithApple();
  Future<void> signInWithGoogle();

  Future<void> sendPhoneOtp(String phoneNumber);

  /// Returns true when the code is valid and a session was created.
  Future<bool> verifyPhoneOtp(String phoneNumber, String token);

  /// The `public.users` row of the signed-in user (created by the `on_auth_user_created` trigger).
  Future<UserProfile?> fetchCurrentProfile();

  Future<bool> checkHandleAvailable(String handle);

  /// Claims the handle on the trigger-created profile row. Throws [HandleTakenException] on a race.
  Future<UserProfile> completeRegistration({
    required String username,
    required String displayName,
    String? avatarUrl,
  });

  /// Sets `users.onboarding_completed` once SCR-04 finishes (router stops redirecting to onboarding).
  Future<void> markOnboardingCompleted();

  Future<void> signOut();
}

/// Emits `current()` on listen, then [changes], de-duplicated. Subscribes to [changes]
/// *before* emitting so no event can fall into a gap between the two.
Stream<String?> currentThenChanges(String? Function() current, Stream<String?> changes) {
  late final StreamController<String?> controller;
  StreamSubscription<String?>? subscription;
  controller = StreamController<String?>(
    onListen: () {
      subscription = changes.listen(controller.add, onError: controller.addError);
      controller.add(current());
    },
    onCancel: () => subscription?.cancel(),
  );
  return controller.stream.distinct();
}

/// Reserved handles that cannot be claimed (auth spec §3). Mirrored server-side in
/// `check_handle_available` (supabase/migrations/20261010000000_baseline_schema.sql).
const kReservedHandles = {
  'admin',
  'telly',
  'support',
  'explore',
  'official',
  'hbo',
  'netflix',
  'apple',
  'max',
  'disney',
  'hulu',
  'criterion',
  'prime',
};

/// Client-side handle rules (auth spec §3): lowercase a–z, 0–9 and single underscores, 3–20 chars.
class HandleRules {
  static final _pattern = RegExp(r'^[a-z0-9_]{3,20}$');

  static String normalize(String raw) => raw.trim().toLowerCase();

  /// Returns a user-facing error, or null when the handle is well-formed and not reserved.
  static String? validate(String raw) {
    final h = normalize(raw);
    if (h.length < 3) return 'Handle must be at least 3 characters';
    if (h.length > 20) return 'Handle cannot exceed 20 characters';
    if (!_pattern.hasMatch(h)) return 'Only letters, numbers, and underscores are allowed';
    if (h.contains('__')) return 'Underscores cannot be doubled';
    if (kReservedHandles.contains(h)) return '@$h is reserved';
    return null;
  }
}

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;
  final String _redirectUrl;

  SupabaseAuthRepository(this._client, {required String redirectUrl}) : _redirectUrl = redirectUrl;

  GoTrueClient get _auth => _client.auth;

  @override
  String? get currentUserId => _auth.currentUser?.id;

  @override
  Stream<String?> watchSignedInUserId() => currentThenChanges(
        () => currentUserId,
        _auth.onAuthStateChange.map((event) => event.session?.user.id),
      );

  @override
  Future<void> signInWithApple() => _auth.signInWithOAuth(OAuthProvider.apple, redirectTo: _redirectUrl);

  @override
  Future<void> signInWithGoogle() => _auth.signInWithOAuth(OAuthProvider.google, redirectTo: _redirectUrl);

  @override
  Future<void> sendPhoneOtp(String phoneNumber) => _auth.signInWithOtp(phone: phoneNumber);

  @override
  Future<bool> verifyPhoneOtp(String phoneNumber, String token) async {
    try {
      final res = await _auth.verifyOTP(phone: phoneNumber, token: token, type: OtpType.sms);
      return res.session != null;
    } on AuthException {
      return false;
    }
  }

  @override
  Future<UserProfile?> fetchCurrentProfile() async {
    final uid = currentUserId;
    if (uid == null) return null;
    final row = await _client.from('users').select().eq('id', uid).maybeSingle();
    return row == null ? null : UserProfile.fromJson(row);
  }

  @override
  Future<bool> checkHandleAvailable(String handle) async {
    if (HandleRules.validate(handle) != null) return false;
    final result = await _client.rpc('check_handle_available', params: {'p_handle': HandleRules.normalize(handle)});
    return result == true;
  }

  @override
  Future<UserProfile> completeRegistration({
    required String username,
    required String displayName,
    String? avatarUrl,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('Not signed in');
    final handle = HandleRules.normalize(username);
    try {
      final row = await _client
          .from('users')
          .update({
            'username': handle,
            'display_name': displayName.trim(),
            if (avatarUrl != null) 'avatar_url': avatarUrl,
          })
          .eq('id', uid)
          .select()
          .single();
      return UserProfile.fromJson(row);
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw HandleTakenException(handle);
      rethrow;
    }
  }

  @override
  Future<void> markOnboardingCompleted() async {
    final uid = currentUserId;
    if (uid == null) throw StateError('Not signed in');
    await _client.from('users').update({'onboarding_completed': true}).eq('id', uid);
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(
    ref.watch(supabaseClientProvider),
    redirectUrl: ref.watch(appConfigProvider).authRedirectUrl,
  );
});
