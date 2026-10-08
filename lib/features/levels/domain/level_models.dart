/// Levels, weekly quests, rewards and the weekly table (features/10 §5, §6, §9.7–§9.8; #146).
library;

import '../../achievements/domain/medal.dart';

class LevelInfo {
  final int level;
  final String name;
  final int totalXp;
  final int floor;
  final int ceiling;
  final int weekXp;

  const LevelInfo({
    required this.level,
    required this.name,
    required this.totalXp,
    required this.floor,
    required this.ceiling,
    this.weekXp = 0,
  });

  int get intoLevel => totalXp - floor;
  int get span => ceiling - floor;
  double get fraction => span <= 0 ? 0 : (intoLevel / span).clamp(0, 1).toDouble();

  /// "2,340 / 3,000 XP to Level 13" (§5.1).
  String get progressLabel => '${groupDigits(intoLevel)} / ${groupDigits(span)} XP to Level ${level + 1}';

  factory LevelInfo.fromJson(Map<String, dynamic> j) => LevelInfo(
        level: (j['level'] as num).toInt(),
        name: j['name'] as String,
        totalXp: (j['total_xp'] as num).toInt(),
        floor: (j['level_floor'] as num).toInt(),
        ceiling: (j['level_ceiling'] as num).toInt(),
        weekXp: (j['week_xp'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'level': level,
        'name': name,
        'total_xp': totalXp,
        'level_floor': floor,
        'level_ceiling': ceiling,
        'week_xp': weekXp,
      };
}

/// 2340 → "2,340".
String groupDigits(int n) {
  final s = n.abs().toString();
  final out = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

class Quest {
  final int slot;
  final String key;
  final String title;
  final String difficulty;
  final int target;
  final int progress;
  final int xp;
  final DateTime? completedAt;
  final String week;

  const Quest({
    required this.slot,
    required this.key,
    required this.title,
    required this.difficulty,
    required this.target,
    this.progress = 0,
    required this.xp,
    this.completedAt,
    required this.week,
  });

  bool get isDone => completedAt != null || progress >= target;

  /// Stable id for "completed already" tracking: the ledger ref.
  String get ref => '$week:$key';

  factory Quest.fromJson(Map<String, dynamic> j) => Quest(
        slot: (j['slot'] as num).toInt(),
        key: j['quest_key'] as String,
        title: j['title'] as String,
        difficulty: (j['difficulty'] as String?) ?? 'easy',
        target: (j['target'] as num).toInt(),
        progress: (j['progress'] as num?)?.toInt() ?? 0,
        xp: (j['xp'] as num).toInt(),
        completedAt: j['completed_at'] == null ? null : DateTime.parse(j['completed_at'] as String).toLocal(),
        week: (j['week'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'slot': slot,
        'quest_key': key,
        'title': title,
        'difficulty': difficulty,
        'target': target,
        'progress': progress,
        'xp': xp,
        'completed_at': completedAt?.toUtc().toIso8601String(),
        'week': week,
      };
}

/// Everything `SCR-27` shows. [offline] marks a cached copy (§9.9).
class YourLevel {
  final LevelInfo level;
  final WeeklyStreak streak;
  final List<Quest> quests;
  final bool offline;

  const YourLevel({required this.level, required this.streak, this.quests = const [], this.offline = false});

  factory YourLevel.fromJson(Map<String, dynamic> j, {bool offline = false}) => YourLevel(
        level: LevelInfo.fromJson(Map<String, dynamic>.from(j['level'] as Map)),
        streak: WeeklyStreak.fromJson(Map<String, dynamic>.from(j['streak'] as Map)),
        quests: [for (final q in j['quests'] as List) Quest.fromJson(Map<String, dynamic>.from(q as Map))],
        offline: offline,
      );

  Map<String, dynamic> toJson() => {
        'level': level.toJson(),
        'streak': streak.toJson(),
        'quests': [for (final q in quests) q.toJson()],
      };
}

/// A row of "Friends this week" (§9.7, mockup B3).
class WeeklyRow {
  final String userId;
  final String? username;
  final String displayName;
  final String? avatarUrl;
  final int level;
  final int streakWeeks;
  final int weekXp;
  final int rank;
  final bool isMe;

  const WeeklyRow({
    required this.userId,
    this.username,
    this.displayName = '',
    this.avatarUrl,
    this.level = 1,
    this.streakWeeks = 0,
    this.weekXp = 0,
    required this.rank,
    this.isMe = false,
  });

  String get name => isMe ? 'You' : (displayName.isNotEmpty ? displayName : '@${username ?? ''}');

  factory WeeklyRow.fromJson(Map<String, dynamic> j) => WeeklyRow(
        userId: j['user_id'] as String,
        username: j['username'] as String?,
        displayName: (j['display_name'] as String?) ?? '',
        avatarUrl: j['avatar_url'] as String?,
        level: (j['level'] as num?)?.toInt() ?? 1,
        streakWeeks: (j['streak_weeks'] as num?)?.toInt() ?? 0,
        weekXp: (j['week_xp'] as num?)?.toInt() ?? 0,
        rank: (j['rank'] as num).toInt(),
        isMe: (j['is_me'] as bool?) ?? false,
      );
}

enum RewardKind {
  frame,
  cardStyle,
  canonDecoration,
  appIcon,
  headerArt;

  static RewardKind parse(String v) => switch (v) {
        'frame' => frame,
        'card_style' => cardStyle,
        'canon_decoration' => canonDecoration,
        'app_icon' => appIcon,
        _ => headerArt,
      };

  String get dbValue => switch (this) {
        frame => 'frame',
        cardStyle => 'card_style',
        canonDecoration => 'canon_decoration',
        appIcon => 'app_icon',
        headerArt => 'header_art',
      };
}

/// A cosmetic reward on the track (§5.2).
class Reward {
  final String id;
  final String name;
  final String description;
  final RewardKind kind;
  final int levelRequired;
  final bool unlocked;
  final bool equipped;
  final int xpToGo;

  const Reward({
    required this.id,
    required this.name,
    this.description = '',
    required this.kind,
    required this.levelRequired,
    this.unlocked = false,
    this.equipped = false,
    this.xpToGo = 0,
  });

  Reward copyWith({bool? equipped}) => Reward(
        id: id,
        name: name,
        description: description,
        kind: kind,
        levelRequired: levelRequired,
        unlocked: unlocked,
        equipped: equipped ?? this.equipped,
        xpToGo: xpToGo,
      );

  factory Reward.fromJson(Map<String, dynamic> j) => Reward(
        id: j['id'] as String,
        name: j['name'] as String,
        description: (j['description'] as String?) ?? '',
        kind: RewardKind.parse(j['kind'] as String),
        levelRequired: (j['level_required'] as num).toInt(),
        unlocked: (j['unlocked'] as bool?) ?? false,
        equipped: (j['equipped'] as bool?) ?? false,
        xpToGo: (j['xp_to_go'] as num?)?.toInt() ?? 0,
      );
}

/// Custom canon header art (level 30 reward, §5.2; #148): a still from a God-tier title.
class HeaderArt {
  final int titleId;
  final String mediaType;
  final String title;
  final String backdropPath;
  final double? score;

  const HeaderArt({
    required this.titleId,
    required this.mediaType,
    required this.title,
    required this.backdropPath,
    this.score,
  });

  factory HeaderArt.fromJson(Map<String, dynamic> j) => HeaderArt(
        titleId: (j['title_id'] as num).toInt(),
        mediaType: j['media_type'] as String,
        title: j['title'] as String,
        backdropPath: j['backdrop_path'] as String,
        score: (j['calculated_score'] as num?)?.toDouble(),
      );

  @override
  bool operator ==(Object other) => other is HeaderArt && other.titleId == titleId && other.mediaType == mediaType;

  @override
  int get hashCode => Object.hash(titleId, mediaType);
}
