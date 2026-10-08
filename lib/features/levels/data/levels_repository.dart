import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/network/supabase_providers.dart';
import '../../achievements/domain/medal.dart';
import '../domain/level_models.dart';

/// `SCR-27` and the Rewards track ↔ `my_level`, `weekly_streak`, `my_week`, `weekly_xp_table`
/// and the reward RPCs (features/10 §5–§6, §9.7–§9.8; #145, #146).
abstract interface class LevelsRepository {
  Future<YourLevel> fetch();

  /// Me and the people I follow, or one squad ([squadId]).
  Future<List<WeeklyRow>> weeklyTable({String? squadId});

  Future<List<Reward>> rewards();

  Future<void> equip(String rewardId);

  Future<void> unequip(RewardKind kind);

  /// Which of [userIds] have the profile frame equipped (#147); RLS hides hidden profiles.
  Future<Set<String>> framedUsers(Iterable<String> userIds);
}

class SupabaseLevelsRepository implements LevelsRepository {
  SupabaseLevelsRepository(this._client, {String? Function()? currentUserId})
      : _currentUserId = currentUserId ?? (() => _client.auth.currentUser?.id);

  final SupabaseClient _client;
  final String? Function() _currentUserId;

  @override
  Future<YourLevel> fetch() async {
    final me = _currentUserId() ?? (throw StateError('Not signed in'));
    final (level, streak, quests) = await (
      _client.rpc('my_level').then((r) => r as List),
      _client.rpc('weekly_streak', params: {'p_user': me}).then((r) => r as List),
      _client.rpc('my_week').then((r) => r as List),
    ).wait;
    return YourLevel(
      level: LevelInfo.fromJson(Map<String, dynamic>.from(level.first as Map)),
      streak: streak.isEmpty ? const WeeklyStreak() : WeeklyStreak.fromJson(Map<String, dynamic>.from(streak.first as Map)),
      quests: [for (final q in quests) Quest.fromJson(Map<String, dynamic>.from(q as Map))],
    );
  }

  @override
  Future<List<WeeklyRow>> weeklyTable({String? squadId}) async {
    final rows = await _client.rpc('weekly_xp_table', params: {'p_squad_id': squadId}) as List;
    return [for (final r in rows) WeeklyRow.fromJson(Map<String, dynamic>.from(r as Map))];
  }

  @override
  Future<List<Reward>> rewards() async {
    final rows = await _client.rpc('my_rewards') as List;
    return [for (final r in rows) Reward.fromJson(Map<String, dynamic>.from(r as Map))];
  }

  @override
  Future<void> equip(String rewardId) => _client.rpc('equip_reward', params: {'p_reward_id': rewardId});

  @override
  Future<void> unequip(RewardKind kind) => _client.rpc('unequip_reward', params: {'p_kind': kind.dbValue});

  @override
  Future<Set<String>> framedUsers(Iterable<String> userIds) async {
    final ids = userIds.toSet().toList();
    if (ids.isEmpty) return const {};
    final rows = await _client
        .from('user_reward_choices')
        .select('user_id')
        .eq('kind', RewardKind.frame.dbValue)
        .inFilter('user_id', ids);
    return {for (final r in rows) r['user_id'] as String};
  }
}

/// `SCR-27`'s offline snapshot and what the app last saw (to tell level-ups, finished quests
/// and streak extensions apart from old news), both in Drift's `gamification_cache`.
class LevelCache {
  LevelCache(this._db);

  static const snapshotKey = 'your_level';
  static const seenKey = 'level_seen';
  final AppDatabase _db;

  Future<Map<String, dynamic>?> _read(String key) async {
    final row = await (_db.select(_db.gamificationCache)..where((t) => t.key.equals(key))).getSingleOrNull();
    if (row == null) return null;
    try {
      return jsonDecode(row.json) as Map<String, dynamic>;
    } on Object {
      return null;
    }
  }

  Future<void> _write(String key, Map<String, dynamic> json) => _db
      .into(_db.gamificationCache)
      .insertOnConflictUpdate(GamificationCacheCompanion.insert(key: key, json: jsonEncode(json), savedAt: Value(DateTime.now())));

  Future<YourLevel?> readSnapshot() async {
    final j = await _read(snapshotKey);
    try {
      return j == null ? null : YourLevel.fromJson(j, offline: true);
    } on Object {
      return null;
    }
  }

  Future<void> writeSnapshot(YourLevel level) => _write(snapshotKey, level.toJson());

  /// `{level, streak, quests: [refs]}` as last seen, or null on first run.
  Future<Map<String, dynamic>?> readSeen() => _read(seenKey);

  Future<void> writeSeen(YourLevel level) => _write(seenKey, {
        'level': level.level.level,
        'streak': level.streak.currentWeeks,
        'quests': [for (final q in level.quests) if (q.isDone) q.ref],
      });
}

final levelsRepositoryProvider =
    Provider<LevelsRepository>((ref) => SupabaseLevelsRepository(ref.watch(supabaseClientProvider)));

final levelCacheProvider = Provider<LevelCache>((ref) => LevelCache(ref.watch(databaseProvider)));
