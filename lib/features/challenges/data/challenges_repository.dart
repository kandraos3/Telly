import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_providers.dart';
import '../domain/challenge.dart';

/// SCR-25 / SCR-26 ↔ the challenge RPCs (features/10 §8; #142, #144).
abstract interface class ChallengesRepository {
  Future<List<Challenge>> mine();

  Future<List<Challenge>> discover();

  /// Null when hidden, a draft, or ended and never joined.
  Future<Challenge?> bySlug(String slug);

  /// Returns my progress; rankings made earlier in the window count.
  Future<int> join(String challengeId);

  Future<void> leave(String challengeId);

  Future<List<ChallengeRacer>> racers(String challengeId);

  Future<List<ChallengePick>> picks(String challengeId);

  Future<List<ChallengeTemplate>> templates();

  Future<Challenge?> createSquadChallenge({
    required String squadId,
    required String templateKey,
    required String name,
    required DateTime startsAt,
    required DateTime endsAt,
    Map<String, Object> params = const {},
    int? target,
  });
}

class SupabaseChallengesRepository implements ChallengesRepository {
  SupabaseChallengesRepository(this._client);

  final SupabaseClient _client;

  List<Challenge> _cards(Object? rows) =>
      [for (final r in rows as List) Challenge.fromJson(Map<String, dynamic>.from(r as Map))];

  @override
  Future<List<Challenge>> mine() async => _cards(await _client.rpc('my_challenges'));

  @override
  Future<List<Challenge>> discover() async => _cards(await _client.rpc('discover_challenges'));

  @override
  Future<Challenge?> bySlug(String slug) async =>
      _cards(await _client.rpc('get_challenge', params: {'p_slug': slug})).firstOrNull;

  @override
  Future<int> join(String challengeId) async =>
      ((await _client.rpc('join_challenge', params: {'p_challenge_id': challengeId})) as num).toInt();

  @override
  Future<void> leave(String challengeId) => _client.rpc('leave_challenge', params: {'p_challenge_id': challengeId});

  @override
  Future<List<ChallengeRacer>> racers(String challengeId) async {
    final rows = await _client.rpc('challenge_progress', params: {'p_challenge_id': challengeId}) as List;
    return [for (final r in rows) ChallengeRacer.fromJson(Map<String, dynamic>.from(r as Map))];
  }

  @override
  Future<List<ChallengePick>> picks(String challengeId) async {
    final rows = await _client.rpc('challenge_picks', params: {'p_challenge_id': challengeId}) as List;
    return [for (final r in rows) ChallengePick.fromJson(Map<String, dynamic>.from(r as Map))];
  }

  @override
  Future<List<ChallengeTemplate>> templates() async {
    final rows = await _client
        .from('challenge_templates')
        .select('key, name, description, params, target')
        .order('sort');
    return [for (final r in rows) ChallengeTemplate.fromJson(r)];
  }

  @override
  Future<Challenge?> createSquadChallenge({
    required String squadId,
    required String templateKey,
    required String name,
    required DateTime startsAt,
    required DateTime endsAt,
    Map<String, Object> params = const {},
    int? target,
  }) async {
    final row = await _client.rpc('create_squad_challenge', params: {
      'p_squad_id': squadId,
      'p_template_key': templateKey,
      'p_name': name,
      'p_starts_at': startsAt.toUtc().toIso8601String(),
      'p_ends_at': endsAt.toUtc().toIso8601String(),
      'p_params': params,
      'p_target': target,
    }) as Map;
    return bySlug(row['slug'] as String);
  }
}

final challengesRepositoryProvider =
    Provider<ChallengesRepository>((ref) => SupabaseChallengesRepository(ref.watch(supabaseClientProvider)));
