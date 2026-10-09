import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/database.dart';
import '../network/supabase_providers.dart';

/// Replays one [PendingMutation] against the server (FE-605). Must throw on failure.
abstract interface class MutationTransport {
  Future<void> apply(PendingMutation mutation);
}

/// Maps mutation kinds to the `BE-603` RPCs (TA-02). Every call carries the mutation's
/// `client_mutation_id`, so replaying an already-applied mutation is a server no-op.
class SupabaseMutationTransport implements MutationTransport {
  SupabaseMutationTransport(this._client, {String? Function()? currentUserId})
      : _currentUserId = currentUserId ?? (() => _client.auth.currentUser?.id);

  final SupabaseClient _client;
  final String? Function() _currentUserId;

  @override
  Future<void> apply(PendingMutation m) async {
    final p = jsonDecode(m.payload) as Map<String, dynamic>;
    switch (m.kind) {
      case MutationKind.logTitle:
        await _client.rpc('insert_user_ranking_atomic', params: {
          'p_title_id': p['title_id'],
          'p_media_type': p['media_type'],
          'p_target_rank': p['target_rank'],
          'p_status': p['status'] ?? 'COMPLETED',
          'p_is_rewatch': p['is_rewatch'] ?? false,
          'p_client_mutation_id': m.id,
          'p_broadcast': p['broadcast'] ?? true,
        });
        await _duels(p);
      case MutationKind.move:
        await _client.rpc('move_user_ranking', params: {
          'p_title_id': p['title_id'],
          'p_media_type': p['media_type'],
          'p_new_rank': p['new_rank'],
          'p_client_mutation_id': m.id,
        });
        await _duels(p);
      case MutationKind.delete:
        await _client.rpc('delete_user_ranking', params: {
          'p_title_id': p['title_id'],
          'p_media_type': p['media_type'],
          'p_client_mutation_id': m.id,
        });
      case MutationKind.duels:
        await _duels(p);
      case MutationKind.editorial:
        final userId = _currentUserId();
        if (userId == null) throw StateError('Cannot sync editorial data while signed out');
        // Idempotent by nature: it sets the same column values on every replay.
        await _client
            .from('user_rankings')
            .update({
              'favorite_character': p['favorite_character'],
              'review_short': p['review_short'],
              'tags': p['tags'] ?? const <String>[],
              'is_rewatch': p['is_rewatch'] ?? false,
              'rewatch_count': p['rewatch_count'] ?? 1,
              'venue': p['venue'],
              'audio_language': p['audio_language'],
            })
            .eq('user_id', userId)
            .eq('title_id', p['title_id'] as Object)
            .eq('media_type', p['media_type'] as Object);
      case MutationKind.watchlistAdd:
        final userId = _currentUserId();
        if (userId == null) throw StateError('Cannot sync watchlist while signed out');
        await _client.from('user_watchlist').upsert({
          'user_id': userId,
          'title_id': p['title_id'],
          'media_type': p['media_type'],
          if (p['recommended_by_user_id'] != null) 'recommended_by_user_id': p['recommended_by_user_id'],
        }, onConflict: 'user_id,title_id,media_type', ignoreDuplicates: true);
      case MutationKind.watchlistRemove:
        final userId = _currentUserId();
        if (userId == null) throw StateError('Cannot sync watchlist while signed out');
        await _client
            .from('user_watchlist')
            .delete()
            .eq('user_id', userId)
            .eq('title_id', p['title_id'] as Object)
            .eq('media_type', p['media_type'] as Object);
      case MutationKind.trackingStart:
        await _client.rpc('start_tracking', params: {
          'p_title_id': p['title_id'],
          'p_media_type': p['media_type'],
          'p_last_season': p['last_season'],
          'p_last_episode': p['last_episode'],
          'p_rewatch': p['rewatch'] ?? false,
          'p_client_mutation_id': m.id,
        });
      case MutationKind.trackingPlace:
        await _client.rpc('set_tracking_place', params: {
          'p_title_id': p['title_id'],
          'p_media_type': p['media_type'],
          'p_last_season': p['last_season'],
          'p_last_episode': p['last_episode'],
          'p_client_mutation_id': m.id,
        });
      case MutationKind.trackingRewatch:
        await _client.rpc('log_episode_rewatch', params: {
          'p_title_id': p['title_id'],
          'p_season': p['season'],
          'p_episode': p['episode'],
          'p_client_mutation_id': m.id,
        });
      case MutationKind.trackingFinish:
        await _client.rpc('finish_tracking', params: {
          'p_title_id': p['title_id'],
          'p_media_type': p['media_type'],
          'p_client_mutation_id': m.id,
        });
      case MutationKind.trackingStop:
        await _client.rpc('stop_tracking', params: {
          'p_title_id': p['title_id'],
          'p_media_type': p['media_type'],
          'p_client_mutation_id': m.id,
        });
      case MutationKind.trackingRevive:
        await _client.rpc('revive_dropped_show', params: {
          'p_title_id': p['title_id'],
          'p_client_mutation_id': m.id,
        });
      default:
        throw UnsupportedError('Unknown mutation kind ${m.kind}');
    }
  }

  Future<void> _duels(Map<String, dynamic> payload) async {
    final duels = payload['duels'] as List? ?? const [];
    if (duels.isEmpty) return;
    // Each duel carries its own client_mutation_id; replays skip already-recorded duels.
    await _client.rpc('record_pairwise_duels', params: {'p_duels': duels});
  }
}

final mutationTransportProvider =
    Provider<MutationTransport>((ref) => SupabaseMutationTransport(ref.watch(supabaseClientProvider)));
