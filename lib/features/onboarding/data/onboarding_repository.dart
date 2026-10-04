import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_providers.dart';

/// A saved streaming household setup.
class StreamingSetup {
  final Set<String> platformIds;
  final bool includeFreePlatforms;
  const StreamingSetup(this.platformIds, {required this.includeFreePlatforms});
}

/// Persists `SCR-02` household setup (FE-606); also read/edited from Settings (FE-608).
abstract interface class OnboardingRepository {
  Future<void> saveStreamingSetup({required Set<String> platformIds, required bool includeFreePlatforms});

  Future<StreamingSetup> fetchStreamingSetup();
}

class SupabaseOnboardingRepository implements OnboardingRepository {
  SupabaseOnboardingRepository(this._client, {String? Function()? currentUserId})
      : _currentUserId = currentUserId ?? (() => _client.auth.currentUser?.id);

  final SupabaseClient _client;
  final String? Function() _currentUserId;

  @override
  Future<void> saveStreamingSetup({required Set<String> platformIds, required bool includeFreePlatforms}) async {
    final userId = _currentUserId();
    if (userId == null) throw StateError('Sign in before saving streaming services');

    // Upsert the selection first, then drop the rest, so the set is never empty in between.
    if (platformIds.isNotEmpty) {
      await _client.from('user_streaming_subscriptions').upsert(
        [for (final id in platformIds) {'user_id': userId, 'platform_id': id}],
        onConflict: 'user_id,platform_id',
        ignoreDuplicates: true,
      );
    }
    var stale = _client.from('user_streaming_subscriptions').delete().eq('user_id', userId);
    if (platformIds.isNotEmpty) stale = stale.not('platform_id', 'in', '(${platformIds.join(',')})');
    await stale;

    // `preferences` is shared JSON: merge rather than overwrite.
    final row = await _client.from('users').select('preferences').eq('id', userId).single();
    final preferences = Map<String, dynamic>.from((row['preferences'] as Map?) ?? const {});
    preferences['include_free_platforms'] = includeFreePlatforms;
    await _client.from('users').update({'preferences': preferences}).eq('id', userId);
  }

  @override
  Future<StreamingSetup> fetchStreamingSetup() async {
    final userId = _currentUserId();
    if (userId == null) throw StateError('Not signed in');
    final rows = await _client.from('user_streaming_subscriptions').select('platform_id').eq('user_id', userId);
    final prefs = await _client.from('users').select('preferences').eq('id', userId).single();
    return StreamingSetup(
      {for (final r in rows) r['platform_id'] as String},
      includeFreePlatforms: ((prefs['preferences'] as Map?)?['include_free_platforms'] as bool?) ?? false,
    );
  }
}

final onboardingRepositoryProvider =
    Provider<OnboardingRepository>((ref) => SupabaseOnboardingRepository(ref.watch(supabaseClientProvider)));
