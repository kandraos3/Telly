import 'package:flutter/foundation.dart';

/// Role within a squad circle.
enum SquadRole {
  owner,
  admin,
  member;

  static SquadRole fromString(String value) => switch (value.toUpperCase()) {
        'OWNER' => SquadRole.owner,
        'ADMIN' => SquadRole.admin,
        _ => SquadRole.member,
      };

  /// Owners and admins can invite (RLS `squad_members_insert`).
  bool get canInvite => this != SquadRole.member;
}

/// Someone an invite resolved to (`lookup_squad_invitee`, FE-SQUADS-02).
@immutable
class SquadInvitee {
  final String userId;
  final String username;
  final String displayName;
  final String? avatarUrl;

  /// True when the invite was typed as an email address rather than a handle.
  final bool matchedByEmail;

  const SquadInvitee({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.matchedByEmail = false,
  });

  factory SquadInvitee.fromJson(Map<String, dynamic> json) => SquadInvitee(
        userId: json['id'] as String,
        username: (json['username'] as String?) ?? '',
        displayName: (json['display_name'] as String?) ?? '',
        avatarUrl: json['avatar_url'] as String?,
        matchedByEmail: json['matched_by'] == 'email',
      );
}

/// Whether [input] is shaped like an email address (FE-SQUADS-02).
bool looksLikeEmail(String input) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(input.trim());

/// Whether [input] is shaped like a Telly handle, with or without a leading `@`
/// (`users.username` CHECK: 3–20 of a–z, 0–9, `_`, no `__`).
bool looksLikeHandle(String input) {
  final h = input.trim().toLowerCase().replaceFirst(RegExp('^@'), '');
  return RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(h) && !h.contains('__');
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

  bool get isAdmin => role == SquadRole.admin || role == SquadRole.owner;
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
