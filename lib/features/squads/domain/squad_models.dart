import 'package:flutter/foundation.dart';

/// Role within a squad circle.
enum SquadRole {
  admin,
  member;

  static SquadRole fromString(String value) {
    return value.toUpperCase() == 'ADMIN' ? SquadRole.admin : SquadRole.member;
  }
}

/// A Squad / Circle of friends sharing a collective canon (Feature Spec 04 §4).
@immutable
class Squad {
  final String id;
  final String name;
  final String? description;
  final String? avatarUrl;
  final String createdBy;
  final List<SquadMember> members;
  final DateTime createdAt;

  const Squad({
    required this.id,
    required this.name,
    this.description,
    this.avatarUrl,
    required this.createdBy,
    this.members = const [],
    required this.createdAt,
  });

  int get memberCount => members.length;
}

/// A member of a squad with profile information.
@immutable
class SquadMember {
  final String userId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final SquadRole role;
  final DateTime joinedAt;

  const SquadMember({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.role = SquadRole.member,
    required this.joinedAt,
  });

  bool get isAdmin => role == SquadRole.admin;
}

/// An entry in a squad's consensus canon calculated via Borda Count (BE-304).
@immutable
class SquadConsensusItem {
  final int consensusRank;
  final int titleId;
  final String title;
  final String? posterUrl;
  final int releaseYear;
  final String mediaType; // 'movie' or 'tv'
  final int totalBordaPoints;
  final String championUserId;
  final String championDisplayName;
  final int championRank;
  final String lowestUserId;
  final String lowestDisplayName;
  final int lowestRank;
  final int membersRankedCount;
  final double rankVariance;

  const SquadConsensusItem({
    required this.consensusRank,
    required this.titleId,
    required this.title,
    this.posterUrl,
    required this.releaseYear,
    this.mediaType = 'tv',
    required this.totalBordaPoints,
    required this.championUserId,
    required this.championDisplayName,
    required this.championRank,
    required this.lowestUserId,
    required this.lowestDisplayName,
    required this.lowestRank,
    required this.membersRankedCount,
    required this.rankVariance,
  });

  /// Check if this item is a high-controversy debate item (rank variance >= 10.0 or rank diff >= 10).
  bool get isHotDebate => (lowestRank - championRank).abs() >= 10;
}
