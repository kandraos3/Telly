import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/telemetry_service.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/levels_repository.dart';
import '../../domain/level_models.dart';
import 'levels_controller.dart';

/// The Rewards track (`/more/level/rewards`, features/10 §5.2; #147): every reward with whether
/// it's unlocked (from level) and equipped. Equipping is one per kind.
class RewardsController extends AsyncNotifier<List<Reward>> {
  @override
  Future<List<Reward>> build() => ref.watch(levelsRepositoryProvider).rewards();

  Future<void> equip(Reward reward) async {
    await ref.read(levelsRepositoryProvider).equip(reward.id);
    ref.read(telemetryServiceProvider).trackRewardEquipped(rewardId: reward.id);
    _set([
      for (final r in state.valueOrNull ?? const <Reward>[])
        r.kind == reward.kind ? r.copyWith(equipped: r.id == reward.id) : r,
    ]);
    _syncFrame(reward.kind, equipped: true);
  }

  Future<void> unequip(Reward reward) async {
    await ref.read(levelsRepositoryProvider).unequip(reward.kind);
    _set([
      for (final r in state.valueOrNull ?? const <Reward>[]) r.kind == reward.kind ? r.copyWith(equipped: false) : r,
    ]);
    _syncFrame(reward.kind, equipped: false);
  }

  void _set(List<Reward> rewards) {
    state = AsyncData(rewards);
    ref.invalidate(yourLevelControllerProvider);
  }

  /// My own frame shows at once, without waiting for the directory to refetch.
  void _syncFrame(RewardKind kind, {required bool equipped}) {
    if (kind != RewardKind.frame) return;
    final me = ref.read(authRepositoryProvider).currentUserId;
    if (me != null) ref.read(frameDirectoryProvider.notifier).set(me, equipped);
  }
}

final rewardsControllerProvider = AsyncNotifierProvider<RewardsController, List<Reward>>(RewardsController.new);

/// The reward kinds I have equipped (empty until loaded, or offline): drives my own cosmetics.
final equippedKindsProvider = Provider<Set<RewardKind>>((ref) => {
      for (final r in ref.watch(rewardsControllerProvider).valueOrNull ?? const <Reward>[])
        if (r.equipped && r.unlocked) r.kind,
    });

/// "Noir" story cards (Wrapped and share cards).
final noirCardsProvider = Provider<bool>((ref) => ref.watch(equippedKindsProvider).contains(RewardKind.cardStyle));

/// Gold rank tags on my Canon podium.
final goldPodiumProvider =
    Provider<bool>((ref) => ref.watch(equippedKindsProvider).contains(RewardKind.canonDecoration));

/// Who wears the lime profile frame, looked up in batches as avatars appear (profiles, feed).
/// Unknown ids read as unframed until their batch returns.
class FrameDirectory extends Notifier<Map<String, bool>> {
  final _pending = <String>{};
  bool _scheduled = false;

  @override
  Map<String, bool> build() => const {};

  /// Queues [userId] for the next batch if it isn't known yet.
  void ensure(String userId) {
    if (state.containsKey(userId) || _pending.contains(userId)) return;
    _pending.add(userId);
    if (_scheduled) return;
    _scheduled = true;
    scheduleMicrotask(_flush);
  }

  Future<void> _flush() async {
    _scheduled = false;
    final batch = {..._pending};
    _pending.clear();
    if (batch.isEmpty) return;
    try {
      final framed = await ref.read(levelsRepositoryProvider).framedUsers(batch);
      state = {...state, for (final id in batch) id: framed.contains(id)};
    } catch (_) {
      // Decoration only: leave them unframed; a later screen asks again.
    }
  }

  void set(String userId, bool framed) => state = {...state, userId: framed};
}

final frameDirectoryProvider = NotifierProvider<FrameDirectory, Map<String, bool>>(FrameDirectory.new);
