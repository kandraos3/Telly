import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/user_profile.dart';

abstract class AuthRepository {
  Future<void> signInWithApple();
  Future<void> signInWithGoogle();
  Future<void> sendPhoneOtp(String phoneNumber);
  Future<bool> verifyPhoneOtp(String phoneNumber, String token);
  Future<bool> checkHandleAvailable(String handle);
  Future<UserProfile> completeRegistration({
    required String username,
    required String displayName,
    String? avatarUrl,
  });
  Future<void> signOut();
  UserProfile? get currentUser;
  Stream<UserProfile?> watchAuthState();
}

/// Reserved handles that cannot be claimed by users (Spec 01 §3).
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

class DefaultAuthRepository implements AuthRepository {
  final SupabaseClient? _supabase;
  UserProfile? _currentUser;
  final _authStreamController = StreamController<UserProfile?>.broadcast();

  DefaultAuthRepository({SupabaseClient? supabase}) : _supabase = supabase;

  @override
  UserProfile? get currentUser => _currentUser;

  @override
  Stream<UserProfile?> watchAuthState() => _authStreamController.stream;

  @override
  Future<void> signInWithApple() async {
    if (_supabase != null) {
      await _supabase.auth.signInWithOAuth(OAuthProvider.apple);
    } else {
      // Offline / Test mock state
      _currentUser = UserProfile(
        id: 'apple_user_test',
        username: '',
        displayName: 'Apple User',
        createdAt: DateTime.now(),
      );
      _authStreamController.add(_currentUser);
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    if (_supabase != null) {
      await _supabase.auth.signInWithOAuth(OAuthProvider.google);
    } else {
      _currentUser = UserProfile(
        id: 'google_user_test',
        username: '',
        displayName: 'Google User',
        createdAt: DateTime.now(),
      );
      _authStreamController.add(_currentUser);
    }
  }

  @override
  Future<void> sendPhoneOtp(String phoneNumber) async {
    if (_supabase != null) {
      await _supabase.auth.signInWithOtp(phone: phoneNumber);
    }
    // Simulation / testing: OTP sent
  }

  @override
  Future<bool> verifyPhoneOtp(String phoneNumber, String token) async {
    if (_supabase != null) {
      final res = await _supabase.auth.verifyOTP(
        phone: phoneNumber,
        token: token,
        type: OtpType.sms,
      );
      if (res.user != null) {
        _currentUser = UserProfile(
          id: res.user!.id,
          username: '',
          displayName: 'Telly Cinephile',
          createdAt: DateTime.now(),
        );
        _authStreamController.add(_currentUser);
        return true;
      }
      return false;
    } else {
      if (token == '123456' || token.length == 6) {
        _currentUser = UserProfile(
          id: 'phone_user_test',
          username: '',
          displayName: 'Phone User',
          createdAt: DateTime.now(),
        );
        _authStreamController.add(_currentUser);
        return true;
      }
      return false;
    }
  }

  @override
  Future<bool> checkHandleAvailable(String handle) async {
    final normalized = handle.trim().toLowerCase();
    // Validate character set and length: ^[a-zA-Z0-9_]{3,20}$
    final regex = RegExp(r'^[a-z0-9_]{3,20}$');
    if (!regex.hasMatch(normalized)) {
      return false;
    }

    if (kReservedHandles.contains(normalized)) {
      return false;
    }

    if (_supabase != null) {
      final res = await _supabase
          .from('users')
          .select('id')
          .eq('username', normalized)
          .maybeSingle();
      return res == null;
    }

    // Default mock check: 'taken_user' is taken, all others available
    return normalized != 'taken_user' && normalized != 'jordan_taken';
  }

  @override
  Future<UserProfile> completeRegistration({
    required String username,
    required String displayName,
    String? avatarUrl,
  }) async {
    final updated = UserProfile(
      id: _currentUser?.id ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
      username: username.toLowerCase().trim(),
      displayName: displayName.trim(),
      avatarUrl: avatarUrl,
      createdAt: _currentUser?.createdAt ?? DateTime.now(),
    );

    if (_supabase != null && _currentUser != null) {
      await _supabase.from('users').upsert({
        'id': updated.id,
        'username': updated.username,
        'display_name': updated.displayName,
        'avatar_url': updated.avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    _currentUser = updated;
    _authStreamController.add(_currentUser);
    return updated;
  }

  @override
  Future<void> signOut() async {
    if (_supabase != null) {
      await _supabase.auth.signOut();
    }
    _currentUser = null;
    _authStreamController.add(null);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  SupabaseClient? client;
  try {
    client = Supabase.instance.client;
  } catch (_) {
    // Supabase not yet initialized (e.g. testing or local preview)
  }
  return DefaultAuthRepository(supabase: client);
});
