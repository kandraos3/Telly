import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/presentation/controllers/settings_controllers.dart';

/// Provider holding the user's global haptic feedback preference.
/// Whether haptics fire: Settings → Haptics (`users.preferences.haptics`, FE-608).
/// On until preferences load.
final hapticsEnabledProvider = Provider<bool>(
  (ref) => ref.watch(preferencesProvider.select((p) => p.valueOrNull?.haptics ?? HapticsMode.full)) != HapticsMode.off,
);

/// Interface to allow clean mocking and testing of platform haptic calls.
class PlatformHaptics {
  const PlatformHaptics();

  Future<void> selectionClick() => HapticFeedback.selectionClick();
  Future<void> lightImpact() => HapticFeedback.lightImpact();
  Future<void> mediumImpact() => HapticFeedback.mediumImpact();
  Future<void> heavyImpact() => HapticFeedback.heavyImpact();
  Future<void> vibrate() => HapticFeedback.vibrate();
}

/// Central Haptics Engine delivering tactile sensations for Telly interactions.
/// Defined according to `docs/design_system/01_DESIGN_PHILOSOPHY_AND_STYLE_GUIDE.md` §5.
class HapticsService {
  final bool enabled;
  final PlatformHaptics _platform;

  const HapticsService({
    required this.enabled,
    PlatformHaptics platform = const PlatformHaptics(),
  }) : _platform = platform;

  static Future<void> lightImpact() => HapticFeedback.lightImpact();
  static Future<void> mediumImpact() => HapticFeedback.mediumImpact();
  static Future<void> heavyImpact() => HapticFeedback.heavyImpact();
  static Future<void> selectionClick() => HapticFeedback.selectionClick();

  /// Tactile feedback when selecting the winner in a pairwise duel.
  Future<void> duelWinner() async {
    if (!enabled) return;
    await _platform.mediumImpact();
  }

  /// Tactile click when tapping a candidate card or moving selection.
  Future<void> duelSelectCandidate() async {
    if (!enabled) return;
    await _platform.selectionClick();
  }

  /// High-impact alert / double heavy pulse for spicy hot takes and major upsets.
  Future<void> upsetAlertTriggered({Duration delay = const Duration(milliseconds: 100)}) async {
    if (!enabled) return;
    await _platform.heavyImpact();
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    await _platform.heavyImpact();
  }

  /// Sequential light vibration pulse for celebratory score reveals and duel completion.
  Future<void> scoreReveal({int pulses = 3, Duration interval = const Duration(milliseconds: 80)}) async {
    if (!enabled) return;
    for (int i = 0; i < pulses; i++) {
      await _platform.lightImpact();
      if (i < pulses - 1 && interval > Duration.zero) {
        await Future<void>.delayed(interval);
      }
    }
  }

  /// 1-tap bookmark / save to watchlist feedback.
  Future<void> saveToWatchlist() async {
    if (!enabled) return;
    await _platform.lightImpact();
  }

  /// Tactile tick when dragging a title across slots in the canon leaderboard.
  Future<void> rankSlotTick() async {
    if (!enabled) return;
    await _platform.selectionClick();
  }
}

/// Riverpod provider for accessing [HapticsService] throughout the widget tree.
final hapticsServiceProvider = Provider<HapticsService>((ref) {
  final enabled = ref.watch(hapticsEnabledProvider);
  return HapticsService(enabled: enabled);
});

