import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/telemetry_service.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../domain/medal.dart';
import '../controllers/achievements_controller.dart';
import '../screens/unlock_moment_screen.dart';

/// Shows `SCR-24` for each unseen unlock, one after another (features/10 §4.2, §9.4; #138).
///
/// Lives in the app shell. Medals are re-read when the app returns to the foreground and when
/// the offline queue finishes syncing (which is right after a ranking reaches the server), so
/// new unlocks are celebrated promptly. Each moment is marked seen once it closes. Offline
/// snapshots never show moments: they couldn't be marked seen.
class UnlockMomentHost extends ConsumerStatefulWidget {
  final Widget child;

  const UnlockMomentHost({super.key, required this.child});

  @override
  ConsumerState<UnlockMomentHost> createState() => _UnlockMomentHostState();
}

class _UnlockMomentHostState extends ConsumerState<UnlockMomentHost> {
  late final AppLifecycleListener _lifecycle;
  bool _showing = false;

  /// Shown this session, so a slow mark-seen never shows the same medal twice.
  final _shown = <String>{};

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => ref.invalidate(achievementsControllerProvider));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeShow(ref.read(achievementsControllerProvider).valueOrNull);
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _maybeShow(AchievementsSnapshot? snapshot) async {
    if (_showing || snapshot == null || snapshot.offline || !mounted) return;
    final queue = [for (final m in snapshot.unseen) if (!_shown.contains(m.id)) m];
    if (queue.isEmpty) return;
    _showing = true;
    try {
      for (final medal in queue) {
        if (!mounted) return;
        _shown.add(medal.id);
        final telemetry = ref.read(telemetryServiceProvider)
          ..trackMedalUnlocked(achievementId: medal.id, tier: medal.tier.name, kind: medal.kind.name);
        // A challenge medal is only ever earned by finishing the challenge (#144).
        if (medal.kind == MedalKind.challenge) telemetry.trackChallengeCompleted(achievementId: medal.id);
        await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => UnlockMomentScreen(medal: medal),
        ));
        try {
          await ref.read(achievementsControllerProvider.notifier).markSeen(medal);
        } catch (_) {
          // Not fatal: the server still has it unseen, so it shows again next session.
        }
      }
    } finally {
      _showing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(achievementsControllerProvider, (_, next) => _maybeShow(next.valueOrNull));
    // A finished sync (pending → 0) may have unlocked something on the server.
    ref.listen(syncEngineProvider, (prev, next) {
      final before = prev?.valueOrNull?.pending ?? 0;
      final after = next.valueOrNull?.pending ?? 0;
      if (before > 0 && after == 0) ref.invalidate(achievementsControllerProvider);
    });
    return widget.child;
  }
}
