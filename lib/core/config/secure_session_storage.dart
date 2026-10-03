import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists the Supabase session in the platform keychain / keystore instead of
/// SharedPreferences (FE-106 "session persistence", auth spec §4.2).
class SecureSessionStorage extends LocalStorage {
  static const _key = 'telly.supabase.session';

  final FlutterSecureStorage _storage;

  const SecureSessionStorage([this._storage = const FlutterSecureStorage()]);

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: _key);

  @override
  Future<String?> accessToken() => _storage.read(key: _key);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _key, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _key);
}
