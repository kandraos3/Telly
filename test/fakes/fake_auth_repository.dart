import 'dart:async';

import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';

/// Deterministic in-memory [AuthRepository] for widget/provider tests (FE-601).
/// Lives under test/ — production code has no mock fallback.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.validOtp = '123456',
    Set<String>? takenHandles,
    String? signedInUserId,
    UserProfile? profile,
  })  : takenHandles = takenHandles ?? {'taken_user'},
        _userId = signedInUserId,
        _profile = profile;

  final String validOtp;
  final Set<String> takenHandles;
  final _sessions = StreamController<String?>.broadcast();
  String? _userId;
  UserProfile? _profile;

  int handleChecks = 0;
  bool failNextCall = false;

  void _maybeFail() {
    if (failNextCall) {
      failNextCall = false;
      throw Exception('simulated failure');
    }
  }

  void _signIn(String id, String name) {
    _userId = id;
    _profile ??= UserProfile(id: id, displayName: name, createdAt: DateTime(2026));
    _sessions.add(id);
  }

  @override
  String? get currentUserId => _userId;

  @override
  Stream<String?> watchSignedInUserId() => currentThenChanges(() => _userId, _sessions.stream);

  @override
  Future<void> signInWithApple() async {
    _maybeFail();
    _signIn('apple-user', 'Apple User');
  }

  @override
  Future<void> signInWithGoogle() async {
    _maybeFail();
    _signIn('google-user', 'Google User');
  }

  @override
  Future<void> signInWithEmail({required String email, required String password}) async {
    _maybeFail();
    _signIn('email-user', 'Email User');
  }

  @override
  Future<bool> signUpWithEmail({required String email, required String password}) async {
    _maybeFail();
    _signIn('email-user', 'Email User');
    return true;
  }

  @override
  Future<void> sendPhoneOtp(String phoneNumber) async => _maybeFail();

  @override
  Future<bool> verifyPhoneOtp(String phoneNumber, String token) async {
    _maybeFail();
    if (token != validOtp) return false;
    _signIn('phone-user', '');
    return true;
  }

  @override
  Future<UserProfile?> fetchCurrentProfile() async => _userId == null ? null : _profile;

  @override
  Future<bool> checkHandleAvailable(String handle) async {
    handleChecks++;
    _maybeFail();
    final h = HandleRules.normalize(handle);
    return HandleRules.validate(h) == null && !takenHandles.contains(h);
  }

  @override
  Future<UserProfile> completeRegistration({
    required String username,
    required String displayName,
    String? avatarUrl,
  }) async {
    _maybeFail();
    final h = HandleRules.normalize(username);
    if (takenHandles.contains(h)) throw HandleTakenException(h);
    takenHandles.add(h);
    _profile = (_profile ?? UserProfile(id: _userId ?? 'u', displayName: '', createdAt: DateTime(2026)))
        .copyWith(username: h, displayName: displayName, avatarUrl: avatarUrl);
    return _profile!;
  }

  @override
  Future<void> markOnboardingCompleted() async {
    _maybeFail();
    _profile = _profile?.copyWith(onboardingCompleted: true);
  }

  bool deletionRequested = false;

  @override
  Future<DateTime> requestAccountDeletion() async {
    _maybeFail();
    deletionRequested = true;
    return DateTime.now().add(const Duration(days: 30));
  }

  @override
  Future<void> signOut() async {
    _userId = null;
    _profile = null;
    _sessions.add(null);
  }
}
