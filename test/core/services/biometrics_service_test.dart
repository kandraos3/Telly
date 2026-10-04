import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/services/biometrics_service.dart';
import 'package:telly_app/features/profile/presentation/controllers/settings_controllers.dart';

void main() {
  group('DEV-601: BiometricsService & Preferences Tests', () {
    test('FakeBiometricsService allows controlling support and authentication outcome', () async {
      final fake = FakeBiometricsService(supported: true, authenticateResult: true);

      expect(await fake.canAuthenticate(), isTrue);
      expect(fake.authenticateCallCount, equals(0));

      final success = await fake.authenticate(localizedReason: 'Test Unlock');
      expect(success, isTrue);
      expect(fake.authenticateCallCount, equals(1));

      fake.authenticateResult = false;
      final fail = await fake.authenticate();
      expect(fail, isFalse);
      expect(fake.authenticateCallCount, equals(2));

      fake.supported = false;
      expect(await fake.canAuthenticate(), isFalse);
    });

    test('AppPreferences serializes and deserializes biometricEnabled', () {
      const defaultPrefs = AppPreferences();
      expect(defaultPrefs.biometricEnabled, isFalse);

      final enabled = defaultPrefs.copyWith(biometricEnabled: true);
      expect(enabled.biometricEnabled, isTrue);

      final json = enabled.toJson();
      expect(json['biometric_enabled'], isTrue);

      final deserialized = AppPreferences.fromJson(json);
      expect(deserialized.biometricEnabled, isTrue);
    });
  });
}

