import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_providers.dart';

/// Persists `SCR-02` household setup (FE-606).
abstract interface class OnboardingRepository {
  Future<void> saveStreamingSetup({required Set<String> platformIds, required bool includeFreePlatforms});
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
}

final onboardingRepositoryProvider =
    Provider<OnboardingRepository>((ref) => SupabaseOnboardingRepository(ref.watch(supabaseClientProvider)));
