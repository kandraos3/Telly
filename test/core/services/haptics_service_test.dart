import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/profile/data/profile_repository.dart';
import 'package:telly_app/features/profile/presentation/controllers/settings_controllers.dart';
import 'package:telly_app/core/services/haptics_service.dart';

import '../../fakes/fake_profile_repository.dart';

class MockPlatformHaptics implements PlatformHaptics {
  int selectionClicks = 0;
  int lightImpacts = 0;
  int mediumImpacts = 0;
  int heavyImpacts = 0;
  int vibrates = 0;

  @override
  Future<void> selectionClick() async {
    selectionClicks++;
  }

  @override
  Future<void> lightImpact() async {
    lightImpacts++;
  }

  @override
  Future<void> mediumImpact() async {
    mediumImpacts++;
  }

  @override
  Future<void> heavyImpact() async {
    heavyImpacts++;
  }

  @override
  Future<void> vibrate() async {
    vibrates++;
  }

  void reset() {
    selectionClicks = 0;
    lightImpacts = 0;
    mediumImpacts = 0;
    heavyImpacts = 0;
    vibrates = 0;
  }
}

void main() {
  late MockPlatformHaptics mockPlatform;

  setUp(() {
    mockPlatform = MockPlatformHaptics();
  });

  group('HapticsService Enabled', () {
    late HapticsService service;

    setUp(() {
      service = HapticsService(enabled: true, platform: mockPlatform);
    });

    test('duelWinner triggers mediumImpact', () async {
      await service.duelWinner();
      expect(mockPlatform.mediumImpacts, equals(1));
    });

    test('duelSelectCandidate triggers selectionClick', () async {
      await service.duelSelectCandidate();
      expect(mockPlatform.selectionClicks, equals(1));
    });

    test('upsetAlertTriggered triggers two heavy impacts', () async {
      await service.upsetAlertTriggered(delay: Duration.zero);
      expect(mockPlatform.heavyImpacts, equals(2));
    });

    test('scoreReveal triggers sequential light impacts', () async {
      await service.scoreReveal(pulses: 3, interval: Duration.zero);
      expect(mockPlatform.lightImpacts, equals(3));
    });

    test('saveToWatchlist triggers lightImpact', () async {
      await service.saveToWatchlist();
      expect(mockPlatform.lightImpacts, equals(1));
    });

    test('rankSlotTick triggers selectionClick', () async {
      await service.rankSlotTick();
      expect(mockPlatform.selectionClicks, equals(1));
    });
  });

  group('HapticsService Disabled (User setting: haptics_enabled = false)', () {
    late HapticsService service;

    setUp(() {
      service = HapticsService(enabled: false, platform: mockPlatform);
    });

    test('duelWinner does nothing when haptics disabled', () async {
      await service.duelWinner();
      expect(mockPlatform.mediumImpacts, equals(0));
    });

    test('upsetAlertTriggered does nothing when haptics disabled', () async {
      await service.upsetAlertTriggered(delay: Duration.zero);
      expect(mockPlatform.heavyImpacts, equals(0));
    });

    test('scoreReveal does nothing when haptics disabled', () async {
      await service.scoreReveal(pulses: 3, interval: Duration.zero);
      expect(mockPlatform.lightImpacts, equals(0));
    });
  });

  group('Riverpod hapticsServiceProvider Integration', () {
    test('follows the Settings haptics preference (FE-608)', () async {
      final profiles = FakeProfileRepository();
      final container = ProviderContainer(overrides: [profileRepositoryProvider.overrideWithValue(profiles)]);
      addTearDown(container.dispose);

      expect(container.read(hapticsServiceProvider).enabled, isTrue, reason: 'on before preferences load');
      await container.read(preferencesProvider.future);
      await container.read(preferencesProvider.notifier).edit((p) => p.copyWith(haptics: HapticsMode.off));
      expect(container.read(hapticsServiceProvider).enabled, isFalse);
      expect(profiles.preferences['haptics'], 'off');

      await container.read(preferencesProvider.notifier).edit((p) => p.copyWith(haptics: HapticsMode.subtle));
      expect(container.read(hapticsServiceProvider).enabled, isTrue);
    });
  });
}
