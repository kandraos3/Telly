import 'package:telly_app/features/achievements/domain/medal.dart';
import 'package:telly_app/features/levels/data/levels_repository.dart';
import 'package:telly_app/features/levels/domain/level_models.dart';

/// Mockup B1: level 12 Cinephile, 2,340 / 3,000 XP to 13, a 6-week streak with a frozen
/// week, and three quests (one done).
YourLevel sampleLevel({int level = 12, int total = 18840, int streak = 6, bool questDone = true}) => YourLevel(
      level: LevelInfo(
        level: level,
        name: level >= 10 ? 'Cinephile' : 'Regular',
        totalXp: total,
        floor: 125 * level * (level - 1),
        ceiling: 125 * (level + 1) * level,
        weekXp: 580,
      ),
      streak: WeeklyStreak(currentWeeks: streak, bestWeeks: 9, weeks: const [
        StreakWeek(label: '2026-W36', status: StreakWeekStatus.counted),
        StreakWeek(label: '2026-W37', status: StreakWeekStatus.counted),
        StreakWeek(label: '2026-W38', status: StreakWeekStatus.frozen),
        StreakWeek(label: '2026-W39', status: StreakWeekStatus.counted),
        StreakWeek(label: '2026-W40', status: StreakWeekStatus.counted),
        StreakWeek(label: '2026-W41', status: StreakWeekStatus.counted),
        StreakWeek(label: '2026-W42', status: StreakWeekStatus.current),
      ]),
      quests: [
        Quest(slot: 1, key: 'explore_decade', title: 'Rank a film from the 1970s', difficulty: 'explore', target: 1,
            progress: questDone ? 1 : 0, xp: 50, completedAt: questDone ? DateTime(2026, 10, 13) : null, week: '2026-W42'),
        const Quest(slot: 2, key: 'rank_three', title: 'Rank 3 titles this week', difficulty: 'easy', target: 3,
            progress: 1, xp: 60, week: '2026-W42'),
        const Quest(slot: 3, key: 'queue_one', title: 'Rank something from your Queue', difficulty: 'queue',
            target: 1, xp: 40, week: '2026-W42'),
      ],
    );

const sampleWeek = [
  WeeklyRow(userId: 'm', displayName: 'Maya', level: 18, streakWeeks: 11, weekXp: 640, rank: 1),
  WeeklyRow(userId: 'me', displayName: 'Jordan', level: 12, streakWeeks: 6, weekXp: 580, rank: 2, isMe: true),
  WeeklyRow(userId: 'j', displayName: 'Jo', level: 9, streakWeeks: 2, weekXp: 410, rank: 3),
  WeeklyRow(userId: 's', displayName: 'Sam', level: 14, weekXp: 220, rank: 4),
];

class FakeLevelsRepository implements LevelsRepository {
  FakeLevelsRepository([YourLevel? level]) : level = level ?? sampleLevel();

  YourLevel level;
  Object? error;
  Map<String?, List<WeeklyRow>> tables = {null: sampleWeek};
  List<Reward> rewardList = const [
    Reward(id: 'lime_frame', name: 'Lime profile frame', kind: RewardKind.frame, levelRequired: 5, unlocked: true, equipped: true),
    Reward(id: 'noir_card', name: '"Noir" card style', kind: RewardKind.cardStyle, levelRequired: 10, unlocked: true),
    Reward(id: 'gold_podium', name: 'Gold podium tags', kind: RewardKind.canonDecoration, levelRequired: 15, xpToGo: 660),
    Reward(id: 'alt_app_icons', name: 'Alternate app icons', kind: RewardKind.appIcon, levelRequired: 20, xpToGo: 28660),
    Reward(id: 'canon_header_art', name: 'Custom canon header art', kind: RewardKind.headerArt, levelRequired: 30, xpToGo: 89910),
  ];
  final equipped = <String>[];
  final unequipped = <RewardKind>[];

  @override
  Future<YourLevel> fetch() async {
    if (error != null) throw error!;
    return level;
  }

  @override
  Future<List<WeeklyRow>> weeklyTable({String? squadId}) async => tables[squadId] ?? const [];

  @override
  Future<List<Reward>> rewards() async => rewardList;

  @override
  Future<void> equip(String rewardId) async => equipped.add(rewardId);

  @override
  Future<void> unequip(RewardKind kind) async => unequipped.add(kind);

  Set<String> framed = {};
  final frameQueries = <Set<String>>[];

  @override
  Future<Set<String>> framedUsers(Iterable<String> userIds) async {
    frameQueries.add(userIds.toSet());
    return framed.intersection(userIds.toSet());
  }
}
