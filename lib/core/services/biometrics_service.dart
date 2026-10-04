import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// Biometric authentication contract for quick unlock (auth spec §4.1).
abstract interface class BiometricsService {
  /// Whether the device hardware supports biometrics and has enrolled credentials.
  Future<bool> canAuthenticate();

  /// Prompts the native biometric modal (FaceID / Fingerprint).
  Future<bool> authenticate({String localizedReason = 'Please authenticate to unlock Telly'});
}

/// Real implementation backed by `package:local_auth`.
class LocalAuthBiometricsService implements BiometricsService {
  final LocalAuthentication _auth;

  LocalAuthBiometricsService([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  @override
  Future<bool> canAuthenticate() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return isSupported && canCheck;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate({String localizedReason = 'Please authenticate to unlock Telly'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

/// In-memory fake for widget & unit tests (no native platform channel calls).
class FakeBiometricsService implements BiometricsService {
  bool supported;
  bool authenticateResult;
  int authenticateCallCount = 0;

  FakeBiometricsService({
    this.supported = true,
    this.authenticateResult = true,
  });

  @override
  Future<bool> canAuthenticate() async => supported;

  @override
  Future<bool> authenticate({String localizedReason = 'Please authenticate to unlock Telly'}) async {
    authenticateCallCount++;
    return authenticateResult;
  }
}

final biometricsServiceProvider = Provider<BiometricsService>((ref) => LocalAuthBiometricsService());

