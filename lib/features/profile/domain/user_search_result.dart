import 'package:flutter/foundation.dart';
import '../../feed/domain/social_models.dart';

/// A user search result item (SCR-28, features/04 §8.2).
@immutable
class UserSearchResult {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String visibilityMode;
  final FollowStatus? followStatus;
  final int? tasteMatch;
  final int? mutualCount;

  const UserSearchResult({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.visibilityMode = 'PUBLIC',
    this.followStatus,
    this.tasteMatch,
    this.mutualCount,
  });

  String get handle => username;
  int? get tasteMatchPercent => tasteMatch;
  int get mutualFriendsCount => mutualCount ?? 0;

  factory UserSearchResult.fromJson(Map<String, dynamic> j) => UserSearchResult(
        id: j['id'] as String,
        username: (j['username'] as String?) ?? '',
        displayName: (j['display_name'] as String?) ?? '',
        avatarUrl: j['avatar_url'] as String?,
        visibilityMode: (j['visibility_mode'] as String?) ?? 'PUBLIC',
        followStatus: j['follow_status'] == null
            ? null
            : FollowStatus.fromString(j['follow_status'] as String),
        tasteMatch: (j['taste_match'] as num?)?.toInt(),
        mutualCount: (j['mutual_count'] as num?)?.toInt(),
      );

  UserSearchResult copyWith({
    String? id,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? visibilityMode,
    FollowStatus? followStatus,
    bool clearFollowStatus = false,
    int? tasteMatch,
    int? mutualCount,
  }) =>
      UserSearchResult(
        id: id ?? this.id,
        username: username ?? this.username,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        visibilityMode: visibilityMode ?? this.visibilityMode,
        followStatus: clearFollowStatus ? null : (followStatus ?? this.followStatus),
        tasteMatch: tasteMatch ?? this.tasteMatch,
        mutualCount: mutualCount ?? this.mutualCount,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSearchResult &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          username == other.username &&
          displayName == other.displayName &&
          avatarUrl == other.avatarUrl &&
          visibilityMode == other.visibilityMode &&
          followStatus == other.followStatus &&
          tasteMatch == other.tasteMatch &&
          mutualCount == other.mutualCount;

  @override
  int get hashCode => Object.hash(
        id,
        username,
        displayName,
        avatarUrl,
        visibilityMode,
        followStatus,
        tasteMatch,
        mutualCount,
      );
}
