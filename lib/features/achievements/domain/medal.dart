/// Medals and the weekly streak (features/10 §3–§4), as returned by `my_achievements()` and
/// `weekly_streak()`. Plain value types with JSON round-trips so a snapshot can be cached in
/// Drift for offline reading (§9.9).
library;

enum MedalKind {
  milestone,
  taste,
  streak,
  collection,
  challenge,
  special;

  static MedalKind parse(String? value) =>
      MedalKind.values.firstWhere((k) => k.name == value, orElse: () => MedalKind.special);
}

enum MedalTier {
  bronze,
  silver,
  gold,
  special;

  static MedalTier parse(String? value) =>
      MedalTier.values.firstWhere((t) => t.name == value, orElse: () => MedalTier.bronze);

  String get label => switch (this) {
        MedalTier.bronze => 'Bronze',
        MedalTier.silver => 'Silver',
        MedalTier.gold => 'Gold',
        MedalTier.special => 'Special',
      };
}

/// Someone the viewer follows who holds a medal (medal sheet avatar stack).
class MedalFriend {
  final String userId;
  final String? username;
  final String displayName;
  final String? avatarUrl;

  const MedalFriend({required this.userId, this.username, this.displayName = '', this.avatarUrl});

  /// What the sheet calls them: display name, else handle.
  String get shortName {
    final name = displayName.trim();
    if (name.isNotEmpty) return name.split(RegExp(r'\s+')).first;
    return username ?? 'Someone';
  }

  factory MedalFriend.fromJson(Map<String, dynamic> j) => MedalFriend(
        userId: j['user_id'] as String,
        username: j['username'] as String?,
        displayName: (j['display_name'] as String?) ?? '',
        avatarUrl: j['avatar_url'] as String?,
      );

  Map<String, dynamic> toJson() =>
      {'user_id': userId, 'username': username, 'display_name': displayName, 'avatar_url': avatarUrl};
}

class Medal {
  final String id;
  final MedalKind kind;
  final MedalTier tier;
  final String name;
  final String description;
  final String glyph;
  final String? mediaType;
  final int? threshold;
  final int sort;
  final int progress;
  final DateTime? unlockedAt;
  final DateTime? seenAt;
  final int? pinnedSlot;
  final double? rarityPercent;
  final bool rarityIsNew;
  final int friendsCount;
  final List<MedalFriend> friends;

  const Medal({
    required this.id,
    required this.kind,
    required this.tier,
    required this.name,
    required this.description,
    required this.glyph,
    this.mediaType,
    this.threshold,
    this.sort = 0,
    this.progress = 0,
    this.unlockedAt,
    this.seenAt,
    this.pinnedSlot,
    this.rarityPercent,
    this.rarityIsNew = true,
    this.friendsCount = 0,
    this.friends = const [],
  });

  bool get isUnlocked => unlockedAt != null;

  /// 0–1 towards the target; 1 once unlocked.
  double get fraction {
    if (isUnlocked) return 1;
    final target = threshold;
    if (target == null || target <= 0) return 0;
    return (progress / target).clamp(0, 1).toDouble();
  }

  /// "94/100", or "78% / 92%" for Taste Twin, whose progress is a match percentage.
  String get progressLabel {
    final target = threshold;
    if (target == null) return '';
    return id == 'taste_twin' ? '$progress% / $target%' : '$progress/$target';
  }

  /// "Unlocked by 4.2% of Telly viewers", or the New line under 200 active viewers (§4.3).
  String get rarityLine {
    final pct = rarityPercent;
    if (rarityIsNew || pct == null) return 'New: not enough viewers yet';
    final shown = pct >= 10 ? pct.toStringAsFixed(0) : pct.toStringAsFixed(1);
    return 'Unlocked by $shown% of Telly viewers';
  }

  /// "Gold medal, Centurion, unlocked" / "Bronze medal, Ticket Stub, 4 of 10" (§9.1).
  String get semanticLabel {
    final state = isUnlocked
        ? 'unlocked'
        : threshold == null
            ? 'locked'
            : id == 'taste_twin'
                ? 'best match $progress%, needs ${threshold!}%'
                : '$progress of ${threshold!}';
    return '${tier.label} medal, $name, $state';
  }

  /// The unlock moment's personal line (`SCR-24`, §9.4).
  String get personalLine {
    final what = mediaType == 'tv' ? 'series' : 'films';
    final n = threshold ?? 0;
    return switch (id) {
      'upset_artist' => "You've called $n upsets against the crowd.",
      'taste_twin' => 'You follow someone who shares $n% of your taste.',
      'decade_hopper' => 'Your rankings now span $n decades.',
      'genre_explorer' => 'Your rankings now cover $n genres.',
      'graveyard_keeper' => '$n shows laid to rest in your TV Graveyard.',
      'founding_viewer' => 'You joined Telly in its first 90 days.',
      _ => switch (kind) {
          MedalKind.milestone => "You've ranked $n $what.",
          MedalKind.streak => '$n weeks in a row with at least one ranking.',
          _ => description,
        },
    };
  }

  Medal copyWith({int? pinnedSlot, bool clearPin = false, DateTime? seenAt}) => Medal(
        id: id,
        kind: kind,
        tier: tier,
        name: name,
        description: description,
        glyph: glyph,
        mediaType: mediaType,
        threshold: threshold,
        sort: sort,
        progress: progress,
        unlockedAt: unlockedAt,
        seenAt: seenAt ?? this.seenAt,
        pinnedSlot: clearPin ? null : (pinnedSlot ?? this.pinnedSlot),
        rarityPercent: rarityPercent,
        rarityIsNew: rarityIsNew,
        friendsCount: friendsCount,
        friends: friends,
      );

  factory Medal.fromJson(Map<String, dynamic> j) => Medal(
        id: j['id'] as String,
        kind: MedalKind.parse(j['kind'] as String?),
        tier: MedalTier.parse(j['tier'] as String?),
        name: j['name'] as String,
        description: (j['description'] as String?) ?? '',
        glyph: (j['glyph'] as String?) ?? '',
        mediaType: j['media_type'] as String?,
        threshold: (j['threshold'] as num?)?.toInt(),
        sort: (j['sort'] as num?)?.toInt() ?? 0,
        progress: (j['progress'] as num?)?.toInt() ?? 0,
        unlockedAt: _date(j['unlocked_at']),
        seenAt: _date(j['seen_at']),
        pinnedSlot: (j['pinned_slot'] as num?)?.toInt(),
        rarityPercent: (j['rarity_percent'] as num?)?.toDouble(),
        rarityIsNew: (j['rarity_is_new'] as bool?) ?? true,
        friendsCount: (j['friends_count'] as num?)?.toInt() ?? 0,
        friends: [
          for (final f in (j['friends'] as List?) ?? const [])
            MedalFriend.fromJson(Map<String, dynamic>.from(f as Map)),
        ],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'tier': tier.name,
        'name': name,
        'description': description,
        'glyph': glyph,
        'media_type': mediaType,
        'threshold': threshold,
        'sort': sort,
        'progress': progress,
        'unlocked_at': unlockedAt?.toUtc().toIso8601String(),
        'seen_at': seenAt?.toUtc().toIso8601String(),
        'pinned_slot': pinnedSlot,
        'rarity_percent': rarityPercent,
        'rarity_is_new': rarityIsNew,
        'friends_count': friendsCount,
        'friends': [for (final f in friends) f.toJson()],
      };
}

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

enum StreakWeekStatus {
  counted,
  frozen,
  missed,
  current;

  static StreakWeekStatus parse(String? v) =>
      StreakWeekStatus.values.firstWhere((s) => s.name == v, orElse: () => StreakWeekStatus.missed);
}

class StreakWeek {
  final String label; // ISO week, e.g. 2026-W42
  final StreakWeekStatus status;

  const StreakWeek({required this.label, required this.status});

  factory StreakWeek.fromJson(Map<String, dynamic> j) =>
      StreakWeek(label: j['week'] as String, status: StreakWeekStatus.parse(j['status'] as String?));

  Map<String, dynamic> toJson() => {'week': label, 'status': status.name};
}

class WeeklyStreak {
  final int currentWeeks;
  final int bestWeeks;
  final List<StreakWeek> weeks;

  const WeeklyStreak({this.currentWeeks = 0, this.bestWeeks = 0, this.weeks = const []});

  /// The lime chip text, "▲ 6 weeks" (§3).
  String get chipLabel => '▲ $currentWeeks ${currentWeeks == 1 ? 'week' : 'weeks'}';

  factory WeeklyStreak.fromJson(Map<String, dynamic> j) => WeeklyStreak(
        currentWeeks: (j['current_weeks'] as num?)?.toInt() ?? 0,
        bestWeeks: (j['best_weeks'] as num?)?.toInt() ?? 0,
        weeks: [
          for (final w in (j['weeks'] as List?) ?? const []) StreakWeek.fromJson(Map<String, dynamic>.from(w as Map)),
        ],
      );

  Map<String, dynamic> toJson() => {
        'current_weeks': currentWeeks,
        'best_weeks': bestWeeks,
        'weeks': [for (final w in weeks) w.toJson()],
      };
}

/// Everything `SCR-23` shows. [offline] marks a snapshot read from the Drift cache.
class AchievementsSnapshot {
  final List<Medal> medals;
  final WeeklyStreak streak;
  final DateTime savedAt;
  final bool offline;

  const AchievementsSnapshot({
    required this.medals,
    required this.streak,
    required this.savedAt,
    this.offline = false,
  });

  /// Medals the screen lists: special medals (Founding Viewer) only once unlocked.
  List<Medal> get visible => [for (final m in medals) if (m.kind != MedalKind.special || m.isUnlocked) m];

  int get unlockedCount => visible.where((m) => m.isUnlocked).length;

  List<Medal> section(MedalKind kind) =>
      [for (final m in visible) if (m.kind == kind) m]..sort((a, b) => a.sort.compareTo(b.sort));

  /// Pinned medals by slot.
  List<Medal> get pinned => [for (final m in medals) if (m.pinnedSlot != null) m]
    ..sort((a, b) => a.pinnedSlot!.compareTo(b.pinnedSlot!));

  /// The three most recent unlocks, shown as "Recent" when nothing is pinned (§4.4).
  List<Medal> get recent => ([for (final m in medals) if (m.isUnlocked) m]
        ..sort((a, b) => b.unlockedAt!.compareTo(a.unlockedAt!)))
      .take(3)
      .toList();

  /// Unlocks not yet celebrated (`SCR-24`), oldest first.
  List<Medal> get unseen => [for (final m in medals) if (m.isUnlocked && m.seenAt == null) m]
    ..sort((a, b) => a.unlockedAt!.compareTo(b.unlockedAt!));

  /// What profiles show under the name: pinned medals, else the latest unlocks (§4.4).
  MedalShowcase get showcase => MedalShowcase.of(medals);

  /// The first free pin slot (1–3), or null when all three are taken.
  int? get freePinSlot {
    final taken = {for (final m in medals) m.pinnedSlot};
    for (var slot = 1; slot <= 3; slot++) {
      if (!taken.contains(slot)) return slot;
    }
    return null;
  }

  AchievementsSnapshot copyWith({List<Medal>? medals, bool? offline}) => AchievementsSnapshot(
        medals: medals ?? this.medals,
        streak: streak,
        savedAt: savedAt,
        offline: offline ?? this.offline,
      );

  factory AchievementsSnapshot.fromJson(Map<String, dynamic> j, {bool offline = false}) => AchievementsSnapshot(
        medals: [for (final m in j['medals'] as List) Medal.fromJson(Map<String, dynamic>.from(m as Map))],
        streak: WeeklyStreak.fromJson(Map<String, dynamic>.from(j['streak'] as Map)),
        savedAt: DateTime.parse(j['saved_at'] as String).toLocal(),
        offline: offline,
      );

  Map<String, dynamic> toJson() => {
        'medals': [for (final m in medals) m.toJson()],
        'streak': streak.toJson(),
        'saved_at': savedAt.toUtc().toIso8601String(),
      };
}

/// The medals shown under a name (More profile card, friend profile, share card): the pinned
/// ones in slot order, or the three most recent unlocks marked [isRecent] (§4.4).
class MedalShowcase {
  final List<Medal> medals;
  final bool isRecent;

  const MedalShowcase({this.medals = const [], this.isRecent = false});

  static const empty = MedalShowcase();

  factory MedalShowcase.of(Iterable<Medal> all) {
    final pinned = [for (final m in all) if (m.isUnlocked && m.pinnedSlot != null) m]
      ..sort((a, b) => a.pinnedSlot!.compareTo(b.pinnedSlot!));
    if (pinned.isNotEmpty) return MedalShowcase(medals: pinned);
    final recent = [for (final m in all) if (m.isUnlocked) m]..sort((a, b) => b.unlockedAt!.compareTo(a.unlockedAt!));
    return MedalShowcase(medals: recent.take(3).toList(), isRecent: recent.isNotEmpty);
  }

  bool get isEmpty => medals.isEmpty;

  /// "Pinned medals: Centurion, Upset Artist" for screen readers.
  String get semanticLabel => '${isRecent ? 'Recent' : 'Pinned'} medals: ${medals.map((m) => m.name).join(', ')}';
}
