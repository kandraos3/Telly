import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/achievements_repository.dart';
import '../../domain/medal.dart';

/// Thrown when pinning is attempted from an offline snapshot: pins wait until the app is
/// back online (features/10 §9.9).
class AchievementsOfflineException implements Exception {
  const AchievementsOfflineException();

  @override
  String toString() => "You're offline. Pin medals once you're back online.";
}

/// `SCR-23` state (#137): the server snapshot, cached in Drift; the cached copy (marked
/// offline, read-only) when the server can't be reached.
class AchievementsController extends AsyncNotifier<AchievementsSnapshot> {
  @override
  Future<AchievementsSnapshot> build() async {
    final cache = ref.watch(achievementsCacheProvider);
    try {
      final snapshot = await ref.watch(achievementsRepositoryProvider).fetch();
      await cache.write(snapshot);
      return snapshot;
    } catch (_) {
      final cached = await cache.read();
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// Pins [medal] to [slot], or to the first free slot. Pinning into a taken slot replaces
  /// that medal; pinning a pinned medal moves it (§4.4).
  Future<void> pin(Medal medal, {int? slot}) async {
    final current = _requireOnline();
    final target = slot ?? current.freePinSlot;
    if (target == null) throw StateError('No free pin slot; choose one to replace');
    await ref.read(achievementsRepositoryProvider).pin(medal.id, target);
    await _apply(current.copyWith(medals: [
      for (final m in current.medals)
        if (m.id == medal.id)
          m.copyWith(pinnedSlot: target)
        else if (m.pinnedSlot == target)
          m.copyWith(clearPin: true)
        else
          m,
    ]));
  }

  Future<void> unpin(Medal medal) async {
    final current = _requireOnline();
    final slot = medal.pinnedSlot;
    if (slot == null) return;
    await ref.read(achievementsRepositoryProvider).unpin(slot);
    await _apply(current.copyWith(medals: [
      for (final m in current.medals) m.id == medal.id ? m.copyWith(clearPin: true) : m,
    ]));
  }

  AchievementsSnapshot _requireOnline() {
    final current = state.valueOrNull ?? (throw StateError('Achievements not loaded'));
    if (current.offline) throw const AchievementsOfflineException();
    return current;
  }

  Future<void> _apply(AchievementsSnapshot next) async {
    state = AsyncData(next);
    await ref.read(achievementsCacheProvider).write(next);
  }
}

final achievementsControllerProvider =
    AsyncNotifierProvider<AchievementsController, AchievementsSnapshot>(AchievementsController.new);
