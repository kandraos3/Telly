import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/network/supabase_providers.dart';
import '../domain/medal.dart';

/// `SCR-23` ↔ `my_achievements()`, `weekly_streak()` and the pin RPCs (features/10 §3–§4, #137).
abstract interface class AchievementsRepository {
  Future<AchievementsSnapshot> fetch();

  Future<void> pin(String achievementId, int slot);

  Future<void> unpin(int slot);
}

class SupabaseAchievementsRepository implements AchievementsRepository {
  SupabaseAchievementsRepository(this._client, {String? Function()? currentUserId, DateTime Function()? now})
      : _currentUserId = currentUserId ?? (() => _client.auth.currentUser?.id),
        _now = now ?? DateTime.now;

  final SupabaseClient _client;
  final String? Function() _currentUserId;
  final DateTime Function() _now;

  @override
  Future<AchievementsSnapshot> fetch() async {
    final me = _currentUserId() ?? (throw StateError('Not signed in'));
    final (medals, streak) = await (
      _client.rpc('my_achievements').then((rows) => rows as List),
      _client.rpc('weekly_streak', params: {'p_user': me}).then((rows) => rows as List),
    ).wait;
    return AchievementsSnapshot(
      medals: [for (final r in medals) Medal.fromJson(Map<String, dynamic>.from(r as Map))],
      streak: streak.isEmpty
          ? const WeeklyStreak()
          : WeeklyStreak.fromJson(Map<String, dynamic>.from(streak.first as Map)),
      savedAt: _now(),
    );
  }

  @override
  Future<void> pin(String achievementId, int slot) =>
      _client.rpc('pin_achievement', params: {'p_achievement_id': achievementId, 'p_slot': slot});

  @override
  Future<void> unpin(int slot) => _client.rpc('unpin_achievement', params: {'p_slot': slot});
}

/// The last `SCR-23` snapshot in Drift's `gamification_cache` (§9.9).
class AchievementsCache {
  AchievementsCache(this._db);

  static const key = 'achievements';
  final AppDatabase _db;

  Future<AchievementsSnapshot?> read() async {
    final row = await (_db.select(_db.gamificationCache)..where((t) => t.key.equals(key))).getSingleOrNull();
    if (row == null) return null;
    try {
      return AchievementsSnapshot.fromJson(jsonDecode(row.json) as Map<String, dynamic>, offline: true);
    } on Object {
      return null; // an unreadable snapshot is as good as none
    }
  }

  Future<void> write(AchievementsSnapshot snapshot) => _db.into(_db.gamificationCache).insertOnConflictUpdate(
        GamificationCacheCompanion.insert(key: key, json: jsonEncode(snapshot.toJson()), savedAt: Value(snapshot.savedAt)),
      );
}

final achievementsRepositoryProvider =
    Provider<AchievementsRepository>((ref) => SupabaseAchievementsRepository(ref.watch(supabaseClientProvider)));

final achievementsCacheProvider = Provider<AchievementsCache>((ref) => AchievementsCache(ref.watch(databaseProvider)));
