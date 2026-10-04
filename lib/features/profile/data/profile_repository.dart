import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_providers.dart';
import '../../ranking/domain/franchise_rollup_service.dart';

/// What anyone allowed to see a profile can read (`public.users`, RLS `can_view_user`).
class PublicProfile {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final String visibility; // PUBLIC | FRIENDS_ONLY | GHOST

  /// Up to three pinned `{title_id, media_type}` entries (Edit Profile "Top 3").
  final List<({int titleId, String mediaType})> pinnedShowcase;

  /// False for a friends-only profile I don't follow: only the card (no bio/canon) is known.
  final bool canView;

  const PublicProfile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.visibility = 'PUBLIC',
    this.pinnedShowcase = const [],
    this.canView = true,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> j) => PublicProfile(
        id: j['id'] as String,
        username: (j['username'] as String?) ?? '',
        displayName: (j['display_name'] as String?) ?? '',
        avatarUrl: j['avatar_url'] as String?,
        bio: j['bio'] as String?,
        visibility: (j['visibility_mode'] as String?) ?? 'PUBLIC',
        pinnedShowcase: [
          for (final p in (j['pinned_showcase'] as List? ?? const []).cast<Map<String, dynamic>>())
            (titleId: (p['title_id'] as num).toInt(), mediaType: p['media_type'] as String),
        ],
        canView: (j['can_view'] as bool?) ?? true,
      );
}

/// Per-canon Spearman match from `calculate_taste_match_rpc` (features/05 §2).
class CanonMatch {
  final int percentage;
  final int mutualCount;
  const CanonMatch(this.percentage, this.mutualCount);
}

/// Profiles, other users' canons, taste match, profile edits and preferences (FE-608).
abstract interface class ProfileRepository {
  Future<PublicProfile?> fetchByHandle(String handle);

  /// Another user's canon, best first; empty when RLS hides it.
  Future<List<CanonEntry>> fetchCanon(String userId, String mediaType);

  /// Null when the server refuses (not visible, or myself).
  Future<CanonMatch?> tasteMatch(String otherUserId, String mediaType);

  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? visibility,
    List<({int titleId, String mediaType})>? pinnedShowcase,
  });

  /// Uploads a square JPEG to `avatars/<uid>/avatar.jpg` and returns its public URL.
  Future<String> uploadAvatar(Uint8List jpeg);

  Future<Map<String, dynamic>> fetchPreferences();

  /// Shallow-merges [changes] into `users.preferences`.
  Future<void> updatePreferences(Map<String, dynamic> changes);
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client, {String? Function()? currentUserId})
      : _currentUserId = currentUserId ?? (() => _client.auth.currentUser?.id);

  final SupabaseClient _client;
  final String? Function() _currentUserId;

  String get _me => _currentUserId() ?? (throw StateError('Not signed in'));

  @override
  Future<PublicProfile?> fetchByHandle(String handle) async {
    // `lookup_profile_card` (migration 0600) still finds friends-only users I don't follow,
    // so the follow button has an id; bio/showcase come back only when visible.
    final rows = await _client.rpc('lookup_profile_card', params: {'p_handle': handle}) as List;
    return rows.isEmpty ? null : PublicProfile.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<List<CanonEntry>> fetchCanon(String userId, String mediaType) async {
    final rows = await _client
        .from('user_rankings')
        .select('title_id, media_type, rank_position, calculated_score, favorite_character, review_short, '
            'titles(title, poster_path, is_anime)')
        .eq('user_id', userId)
        .eq('media_type', mediaType)
        .order('rank_position');
    return [
      for (final r in rows)
        CanonEntry(
          id: (r['title_id'] as num).toInt(),
          title: ((r['titles'] as Map?)?['title'] as String?) ?? 'Untitled',
          mediaType: r['media_type'] as String,
          rankPosition: (r['rank_position'] as num).toInt(),
          calculatedScore: (r['calculated_score'] as num).toDouble(),
          posterPath: (r['titles'] as Map?)?['poster_path'] as String?,
          isAnime: ((r['titles'] as Map?)?['is_anime'] as bool?) ?? false,
          mvpCharacter: r['favorite_character'] as String?,
          shortReview: r['review_short'] as String?,
        ),
    ];
  }

  @override
  Future<CanonMatch?> tasteMatch(String otherUserId, String mediaType) async {
    try {
      final rows = await _client.rpc('calculate_taste_match_rpc', params: {
        'p_other': otherUserId,
        'p_media_type': mediaType,
      }) as List;
      if (rows.isEmpty) return null;
      final r = rows.first as Map<String, dynamic>;
      return CanonMatch((r['match_pct'] as num).toInt(), (r['mutual_count'] as num).toInt());
    } on PostgrestException catch (e) {
      if (e.code == '42501') return null; // not visible to me
      rethrow;
    }
  }

  @override
  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? visibility,
    List<({int titleId, String mediaType})>? pinnedShowcase,
  }) async {
    final changes = <String, Object?>{
      if (displayName != null) 'display_name': displayName,
      if (bio != null) 'bio': bio,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (visibility != null) 'visibility_mode': visibility,
      if (pinnedShowcase != null)
        'pinned_showcase': [for (final p in pinnedShowcase) {'title_id': p.titleId, 'media_type': p.mediaType}],
    };
    if (changes.isEmpty) return;
    await _client.from('users').update(changes).eq('id', _me);
  }

  @override
  Future<String> uploadAvatar(Uint8List jpeg) async {
    final path = '$_me/avatar.jpg';
    final storage = _client.storage.from('avatars');
    await storage.uploadBinary(
      path,
      jpeg,
      fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
    );
    // Cache-bust so every client shows the new picture.
    return '${storage.getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<Map<String, dynamic>> fetchPreferences() async {
    final row = await _client.from('users').select('preferences').eq('id', _me).single();
    return Map<String, dynamic>.from((row['preferences'] as Map?) ?? const {});
  }

  @override
  Future<void> updatePreferences(Map<String, dynamic> changes) async {
    final merged = {...await fetchPreferences(), ...changes};
    await _client.from('users').update({'preferences': merged}).eq('id', _me);
  }
}

final profileRepositoryProvider =
    Provider<ProfileRepository>((ref) => SupabaseProfileRepository(ref.watch(supabaseClientProvider)));
