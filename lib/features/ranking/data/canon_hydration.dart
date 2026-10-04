import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_providers.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import 'ranking_repository.dart';

/// Reads the signed-in user's server canon (FE-604 pull-hydration).
abstract interface class RemoteCanonSource {
  Future<List<RemoteRanking>> fetchMyCanon(String userId);
}

class SupabaseRemoteCanonSource implements RemoteCanonSource {
  SupabaseRemoteCanonSource(this._client);
  final SupabaseClient _client;

  @override
  Future<List<RemoteRanking>> fetchMyCanon(String userId) async {
    final rows = await _client
        .from('user_rankings')
        .select('title_id, media_type, rank_position, calculated_score, favorite_character, titles(title, poster_path)')
        .eq('user_id', userId);
    return [
      for (final r in rows)
        RemoteRanking(
          titleId: (r['title_id'] as num).toInt(),
          mediaType: r['media_type'] as String,
          title: ((r['titles'] as Map?)?['title'] as String?) ?? 'Untitled',
          posterPath: (r['titles'] as Map?)?['poster_path'] as String?,
          rank: (r['rank_position'] as num).toInt(),
          score: (r['calculated_score'] as num).toDouble(),
          favoriteCharacter: r['favorite_character'] as String?,
        ),
    ];
  }
}

final remoteCanonSourceProvider =
    Provider<RemoteCanonSource>((ref) => SupabaseRemoteCanonSource(ref.watch(supabaseClientProvider)));

/// Hydrates Drift from the server once per signed-in user. Resolves to true when the
/// local canons were replaced, false when skipped (signed out or local changes pending).
final canonHydrationProvider = FutureProvider<bool>((ref) async {
  final userId = ref.watch(authControllerProvider.select((s) => s.isSignedIn ? s.user?.id : null));
  if (userId == null) return false;
  final remote = await ref.read(remoteCanonSourceProvider).fetchMyCanon(userId);
  return ref.read(rankingRepositoryProvider).replaceFromRemote(remote);
});
