import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_providers.dart';
import '../../../core/widgets/poster_image.dart';
import '../domain/squad_models.dart';

/// A title several squad members have queued (`squad_shared_watchlist`).
class SharedWatchlistItem {
  final int titleId;
  final String mediaType;
  final String title;
  final String? posterUrl;
  final int queuedBy;
  final int memberCount;

  const SharedWatchlistItem({
    required this.titleId,
    required this.mediaType,
    required this.title,
    this.posterUrl,
    required this.queuedBy,
    required this.memberCount,
  });

  bool get everyone => queuedBy >= memberCount;
}

/// `SCR-17` Squads (features/04 §4, FE-608).
abstract interface class SquadRepository {
  /// Squads I belong to (members not loaded).
  Future<List<Squad>> mySquads();

  /// The squad with its members.
  Future<Squad> fetchSquad(String squadId);

  /// Borda-count leaderboard for one canon (`calculate_squad_canon`).
  Future<List<SquadConsensusItem>> consensus(Squad squad, String mediaType);

  Future<List<SharedWatchlistItem>> sharedWatchlist(String squadId);

  Future<Squad> create({required String name, String? description});

  /// Owners/admins add a member (RLS `squad_members_insert`).
  Future<void> addMember({required String squadId, required String userId});

  /// Owner only: deletes the squad and, by cascade, its memberships (RLS `squads_delete`).
  Future<void> deleteSquad(String squadId);

  /// Removes my own membership (RLS `squad_members_delete`).
  Future<void> leaveSquad(String squadId);
}

class SupabaseSquadRepository implements SquadRepository {
  SupabaseSquadRepository(this._client, {String? Function()? currentUserId})
      : _currentUserId = currentUserId ?? (() => _client.auth.currentUser?.id);

  final SupabaseClient _client;
  final String? Function() _currentUserId;

  @override
  Future<List<Squad>> mySquads() async {
    final rows = await _client
        .from('squads')
        .select('id, name, description, avatar_url, created_by, created_at')
        .order('created_at', ascending: false);
    return [for (final r in rows) _squad(r)];
  }

  @override
  Future<Squad> fetchSquad(String squadId) async {
    final row = await _client
        .from('squads')
        .select('id, name, description, avatar_url, created_by, created_at')
        .eq('id', squadId)
        .single();
    final members = await _client.rpc('get_squad_members', params: {'p_squad_id': squadId}) as List;
    return _squad(row, members: [
      for (final m in members.cast<Map<String, dynamic>>())
        SquadMember(
          userId: m['user_id'] as String,
          username: (m['username'] as String?) ?? '',
          displayName: (m['display_name'] as String?) ?? '',
          avatarUrl: m['avatar_url'] as String?,
          role: SquadRole.fromString(m['role'] as String),
          joinedAt: DateTime.parse(m['joined_at'] as String).toLocal(),
        ),
    ]);
  }

  @override
  Future<List<SquadConsensusItem>> consensus(Squad squad, String mediaType) async {
    final rows = await _client.rpc('calculate_squad_canon', params: {
      'p_squad_id': squad.id,
      'p_media_type': mediaType,
    }) as List;
    final names = {for (final m in squad.members) m.userId: m.displayName};
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        SquadConsensusItem(
          consensusRank: (r['consensus_rank'] as num).toInt(),
          titleId: (r['title_id'] as num).toInt(),
          title: (r['title'] as String?) ?? 'Untitled',
          posterUrl: TmdbImages.poster(r['poster_path'] as String?),
          releaseYear: 0,
          mediaType: mediaType,
          totalBordaPoints: (r['total_borda_points'] as num).toInt(),
          championUserId: r['champion_user_id'] as String,
          championDisplayName: names[r['champion_user_id']] ?? 'A member',
          championRank: (r['champion_rank'] as num).toInt(),
          lowestUserId: r['lowest_user_id'] as String,
          lowestDisplayName: names[r['lowest_user_id']] ?? 'A member',
          lowestRank: (r['lowest_rank'] as num).toInt(),
          membersRankedCount: (r['members_ranked_count'] as num).toInt(),
          rankVariance: (r['rank_variance'] as num?)?.toDouble() ?? 0,
        ),
    ];
  }

  @override
  Future<List<SharedWatchlistItem>> sharedWatchlist(String squadId) async {
    final rows = await _client.rpc('squad_shared_watchlist', params: {'p_squad_id': squadId}) as List;
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        SharedWatchlistItem(
          titleId: (r['title_id'] as num).toInt(),
          mediaType: r['media_type'] as String,
          title: (r['title'] as String?) ?? 'Untitled',
          posterUrl: TmdbImages.poster(r['poster_path'] as String?),
          queuedBy: (r['queued_by'] as num).toInt(),
          memberCount: (r['member_count'] as num).toInt(),
        ),
    ];
  }

  @override
  Future<Squad> create({required String name, String? description}) async {
    final me = _currentUserId() ?? (throw StateError('Not signed in'));
    final row = await _client
        .from('squads')
        .insert({'name': name, 'description': description, 'created_by': me})
        .select('id, name, description, avatar_url, created_by, created_at')
        .single();
    return _squad(row);
  }

  @override
  Future<void> addMember({required String squadId, required String userId}) =>
      _client.from('squad_members').insert({'squad_id': squadId, 'user_id': userId});

  @override
  Future<void> deleteSquad(String squadId) async {
    // RLS hides rows I may not delete, so an empty result means nothing was removed.
    final rows = await _client.from('squads').delete().eq('id', squadId).select('id');
    if (rows.isEmpty) throw StateError('Only the owner can delete this squad');
  }

  @override
  Future<void> leaveSquad(String squadId) async {
    final me = _currentUserId() ?? (throw StateError('Not signed in'));
    final rows =
        await _client.from('squad_members').delete().eq('squad_id', squadId).eq('user_id', me).select('squad_id');
    if (rows.isEmpty) throw StateError('Not a member of this squad');
  }

  static Squad _squad(Map<String, dynamic> r, {List<SquadMember> members = const []}) => Squad(
        id: r['id'] as String,
        name: r['name'] as String,
        description: r['description'] as String?,
        avatarUrl: r['avatar_url'] as String?,
        createdBy: r['created_by'] as String,
        members: members,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
      );
}

final squadRepositoryProvider =
    Provider<SquadRepository>((ref) => SupabaseSquadRepository(ref.watch(supabaseClientProvider)));
