import 'dart:async';
import 'dart:typed_data';

import 'package:telly_app/features/profile/data/profile_repository.dart';
import 'package:telly_app/features/profile/domain/canon_stats.dart';
import 'package:telly_app/features/ranking/domain/franchise_rollup_service.dart';

/// In-memory [ProfileRepository] for notifier/widget tests (FE-608).
class FakeProfileRepository implements ProfileRepository {
  final profiles = <String, PublicProfile>{};
  final canons = <(String, String), List<CanonEntry>>{};
  final matches = <(String, String), CanonMatch>{};
  final stats = <String, CanonStats>{};
  Map<String, dynamic> preferences = {};
  final updates = <Map<String, Object?>>[];
  final uploads = <Uint8List>[];
  bool failReads = false;
  bool failWrites = false;

  /// When set, reads wait for it (to observe loading states).
  Completer<void>? gate;

  Future<void> _read() async {
    if (gate != null) await gate!.future;
    if (failReads) throw Exception('offline');
  }

  void _write() {
    if (failWrites) throw Exception('server rejected the write');
  }

  @override
  Future<PublicProfile?> fetchByHandle(String handle) async {
    await _read();
    return profiles[handle.toLowerCase()];
  }

  @override
  Future<List<CanonEntry>> fetchCanon(String userId, String mediaType) async {
    await _read();
    return canons[(userId, mediaType)] ?? const [];
  }

  @override
  Future<CanonStats> fetchCanonStats(String mediaType) async {
    await _read();
    return stats[mediaType] ?? CanonStats(mediaType: mediaType);
  }

  @override
  Future<CanonMatch?> tasteMatch(String otherUserId, String mediaType) async {
    await _read();
    return matches[(otherUserId, mediaType)];
  }

  @override
  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? visibility,
    bool? shareAchievements,
    List<({int titleId, String mediaType})>? pinnedShowcase,
  }) async {
    _write();
    updates.add({
      if (displayName != null) 'display_name': displayName,
      if (bio != null) 'bio': bio,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (visibility != null) 'visibility_mode': visibility,
      if (shareAchievements != null) 'share_achievements': shareAchievements,
      if (pinnedShowcase != null) 'pinned_showcase': pinnedShowcase,
    });
  }

  @override
  Future<String> uploadAvatar(Uint8List jpeg) async {
    _write();
    uploads.add(jpeg);
    return 'https://cdn.test/avatars/me.jpg';
  }

  @override
  Future<Map<String, dynamic>> fetchPreferences() async {
    await _read();
    return Map.of(preferences);
  }

  @override
  Future<void> updatePreferences(Map<String, dynamic> changes) async {
    _write();
    preferences = {...preferences, ...changes};
  }
}
