import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/telemetry_service.dart';
import '../../../squads/data/squad_repository.dart';
import '../../../squads/domain/squad_models.dart';
import '../../data/levels_repository.dart';
import '../../domain/level_models.dart';

/// `SCR-27` state (#146): level, streak and this week's quests; the cached copy (offline,
/// read-only) when the server can't be reached. Compared with what the app last saw, a load
/// reports `level_up`, `quest_completed` and `streak_extended` (never on the first load, so
/// XP awarded before the screen existed doesn't fire a burst of events).
class YourLevelController extends AsyncNotifier<YourLevel> {
  @override
  Future<YourLevel> build() async {
    final cache = ref.watch(levelCacheProvider);
    final YourLevel fresh;
    try {
      fresh = await ref.watch(levelsRepositoryProvider).fetch();
    } catch (_) {
      final cached = await cache.readSnapshot();
      if (cached != null) return cached;
      rethrow;
    }
    final seen = await cache.readSeen();
    if (seen != null) _report(seen, fresh);
    await cache.writeSnapshot(fresh);
    await cache.writeSeen(fresh);
    return fresh;
  }

  void _report(Map<String, dynamic> seen, YourLevel now) {
    final telemetry = ref.read(telemetryServiceProvider);
    final level = (seen['level'] as num?)?.toInt() ?? now.level.level;
    if (now.level.level > level) telemetry.trackLevelUp(from: level, to: now.level.level);
    final streak = (seen['streak'] as num?)?.toInt() ?? 0;
    if (now.streak.currentWeeks > streak) telemetry.trackStreakExtended(weeks: now.streak.currentWeeks);
    final done = {for (final r in (seen['quests'] as List?) ?? const []) r as String};
    for (final q in now.quests) {
      if (q.isDone && !done.contains(q.ref)) telemetry.trackQuestCompleted(questKey: q.key, xp: q.xp);
    }
  }
}

final yourLevelControllerProvider = AsyncNotifierProvider<YourLevelController, YourLevel>(YourLevelController.new);

/// "Friends this week": null for the people I follow, else a squad id.
final weeklyTableProvider = FutureProvider.autoDispose.family<List<WeeklyRow>, String?>(
    (ref, squadId) => ref.watch(levelsRepositoryProvider).weeklyTable(squadId: squadId));

/// My squads, for the Friends / squad segments.
final weeklyTableSquadsProvider = FutureProvider.autoDispose<List<Squad>>((ref) async {
  try {
    return await ref.watch(squadRepositoryProvider).mySquads();
  } catch (_) {
    return const [];
  }
});
