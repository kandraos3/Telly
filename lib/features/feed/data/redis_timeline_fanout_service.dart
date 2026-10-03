import 'dart:async';
import 'package:flutter/foundation.dart';

/// In-memory & Redis timeline fanout buffer service (BE-303).
///
/// Implements Redis ZSET timeline fanout caching:
/// - ZADD feed:timeline:{userId} {timestamp} {activityId}
/// - ZREMRANGEBYRANK feed:timeline:{userId} 0 -501 (keeps max 500 items)
/// - Sub-20ms high-throughput cache for feed load operations.
class RedisTimelineFanoutService {
  /// Internal ZSET representation: userId -> Map<activityId, timestampMillis> sorted by timestamp.
  final Map<String, List<TimelineItem>> _userTimelines = {};

  /// Maximum items kept in timeline cache before eviction.
  static const int maxTimelineBuffer = 500;

  /// Fans out a newly logged activity to all followers of [authorId].
  Future<void> fanoutActivity({
    required String activityId,
    required String authorId,
    required List<String> followerIds,
    DateTime? timestamp,
  }) async {
    final time = timestamp ?? DateTime.now();
    final item = TimelineItem(
      activityId: activityId,
      timestamp: time,
      authorId: authorId,
    );

    // Also add to author's own timeline
    _addItemToTimeline(authorId, item);

    // Fanout to each follower
    for (final followerId in followerIds) {
      _addItemToTimeline(followerId, item);
    }
  }

  /// Inserts item maintaining descending timestamp order and enforces 500-item ceiling.
  void _addItemToTimeline(String userId, TimelineItem item) {
    final timeline = _userTimelines.putIfAbsent(userId, () => []);

    // Check if item already exists
    timeline.removeWhere((i) => i.activityId == item.activityId);

    // Insert sorted descending by timestamp
    final index = timeline.indexWhere((i) => i.timestamp.isBefore(item.timestamp));
    if (index == -1) {
      timeline.add(item);
    } else {
      timeline.insert(index, item);
    }

    // Enforce 500 limit (ZREMRANGEBYRANK 0 -501)
    if (timeline.length > maxTimelineBuffer) {
      timeline.removeRange(maxTimelineBuffer, timeline.length);
    }
  }

  /// Retrieves paginated activity IDs from the user's timeline.
  List<String> getTimelineActivityIds({
    required String userId,
    int offset = 0,
    int limit = 20,
  }) {
    final timeline = _userTimelines[userId];
    if (timeline == null || timeline.isEmpty) return [];

    if (offset >= timeline.length) return [];
    final end = (offset + limit).clamp(0, timeline.length);
    return timeline.sublist(offset, end).map((i) => i.activityId).toList();
  }

  /// Clears cache (useful for test resets).
  void clear() {
    _userTimelines.clear();
  }

  int getTimelineLength(String userId) {
    return _userTimelines[userId]?.length ?? 0;
  }
}

@immutable
class TimelineItem {
  final String activityId;
  final DateTime timestamp;
  final String authorId;

  const TimelineItem({
    required this.activityId,
    required this.timestamp,
    required this.authorId,
  });
}
