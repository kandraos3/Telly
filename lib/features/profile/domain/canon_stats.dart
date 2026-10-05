/// Per-canon viewing stats for the SCR-14 stats header (FE-PROFILE-03), from the
/// `get_canon_stats` RPC (migration 20261010001100).
class CanonStats {
  final String mediaType;
  final int totalTitles;
  final int totalMinutes;

  /// True for series, whose hours are estimated from episode counts.
  final bool hoursEstimated;
  final StatLeader? topGenre;

  /// Top director for movies, top network for series (see [creatorLabel]).
  final StatLeader? topCreator;

  const CanonStats({
    required this.mediaType,
    this.totalTitles = 0,
    this.totalMinutes = 0,
    this.hoursEstimated = false,
    this.topGenre,
    this.topCreator,
  });

  factory CanonStats.fromJson(Map<String, dynamic> json) {
    StatLeader? leader(Object? raw) =>
        raw is Map ? StatLeader.fromJson(Map<String, dynamic>.from(raw)) : null;
    final mediaType = json['media_type'] as String? ?? 'movie';
    return CanonStats(
      mediaType: mediaType,
      totalTitles: (json['total_titles'] as num?)?.toInt() ?? 0,
      totalMinutes: (json['total_minutes'] as num?)?.toInt() ?? 0,
      hoursEstimated: json['hours_estimated'] as bool? ?? mediaType == 'tv',
      topGenre: leader(json['top_genre']),
      topCreator: leader(json['top_creator']),
    );
  }

  int get hours => (totalMinutes / 60).round();

  String get creatorLabel => mediaType == 'movie' ? 'Top Director' : 'Top Network';
}

class StatLeader {
  final String name;
  final int count;

  /// Share of the canon's titles, 0–100 (genres only).
  final int? percent;

  const StatLeader({required this.name, required this.count, this.percent});

  factory StatLeader.fromJson(Map<String, dynamic> json) => StatLeader(
        name: json['name'] as String? ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
        percent: (json['percent'] as num?)?.toInt(),
      );
}
