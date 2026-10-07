import 'package:telly_app/features/achievements/data/achievements_repository.dart';
import 'package:telly_app/features/achievements/domain/medal.dart';

/// A `my_achievements()` row as PostgREST returns it.
Map<String, dynamic> medalRow(
  String id, {
  String kind = 'milestone',
  String tier = 'bronze',
  String? name,
  String description = 'Rank 10 films',
  String glyph = '10',
  int? threshold = 10,
  int sort = 1,
  int progress = 0,
  String? unlockedAt,
  int? pinnedSlot,
  double? rarityPercent,
  bool rarityIsNew = true,
  List<Map<String, dynamic>> friends = const [],
}) =>
    {
      'id': id,
      'kind': kind,
      'tier': tier,
      'name': name ?? id,
      'description': description,
      'glyph': glyph,
      'media_type': null,
      'threshold': threshold,
      'sort': sort,
      'progress': progress,
      'unlocked_at': unlockedAt,
      'seen_at': null,
      'pinned_slot': pinnedSlot,
      'rarity_percent': rarityPercent,
      'rarity_is_new': rarityIsNew,
      'friends_count': friends.length,
      'friends': friends,
    };

/// A trophy case with a little of everything: unlocked and locked medals in each section,
/// a locked Founding Viewer (hidden), Taste Twin in progress, and a 6-week streak.
AchievementsSnapshot sampleSnapshot({bool pinned = true, bool offline = false, bool empty = false}) {
  Medal m(Map<String, dynamic> row) => Medal.fromJson(row);
  final unlock = empty ? null : '2026-10-01T12:00:00Z';
  return AchievementsSnapshot(
    medals: [
      m(medalRow('movies_10', name: 'Ticket Stub', progress: empty ? 3 : 10, unlockedAt: unlock,
          pinnedSlot: pinned && !empty ? 2 : null, rarityPercent: 4.2, rarityIsNew: false, friends: [
        {'user_id': 'f1', 'username': 'maya', 'display_name': 'Maya Chen', 'avatar_url': null},
        {'user_id': 'f2', 'username': 'jordan', 'display_name': 'Jordan Lee', 'avatar_url': null},
      ])),
      m(medalRow('movies_100', tier: 'gold', name: 'Centurion', description: 'Rank 100 films', glyph: '100',
          threshold: 100, sort: 5, progress: empty ? 3 : 94)),
      m(medalRow('upset_artist', kind: 'taste', tier: 'special', name: 'Upset Artist',
          description: 'Call 5 upsets in your duels', glyph: '↯', threshold: 5, progress: empty ? 0 : 5,
          unlockedAt: empty ? null : '2026-10-03T12:00:00Z', pinnedSlot: pinned && !empty ? 1 : null)),
      m(medalRow('taste_twin', kind: 'taste', tier: 'special', name: 'Taste Twin',
          description: 'Follow someone with a 92% taste match', glyph: 'TT', threshold: 92, sort: 2, progress: 78)),
      m(medalRow('streak_4', kind: 'streak', name: 'Regular', description: 'Keep a 4-week streak', glyph: '4',
          threshold: 4, progress: empty ? 0 : 6, unlockedAt: empty ? null : '2026-09-20T12:00:00Z')),
      m(medalRow('streak_12', kind: 'streak', tier: 'silver', name: 'Devotee', description: 'Keep a 12-week streak',
          glyph: '12', threshold: 12, sort: 2, progress: empty ? 0 : 6)),
      m(medalRow('founding_viewer', kind: 'special', tier: 'special', name: 'Founding Viewer',
          description: 'Joined Telly in its first 90 days', glyph: 'F', threshold: 1)),
    ],
    streak: WeeklyStreak(currentWeeks: empty ? 0 : 6, bestWeeks: empty ? 0 : 6),
    savedAt: DateTime.utc(2026, 10, 7),
    offline: offline,
  );
}

class FakeAchievementsRepository implements AchievementsRepository {
  FakeAchievementsRepository(this.snapshot);

  AchievementsSnapshot? snapshot;
  Object? error;
  final pins = <(String, int)>[];
  final unpins = <int>[];

  @override
  Future<AchievementsSnapshot> fetch() async {
    if (error != null) throw error!;
    return snapshot!;
  }

  @override
  Future<void> pin(String achievementId, int slot) async => pins.add((achievementId, slot));

  @override
  Future<void> unpin(int slot) async => unpins.add(slot);
}
