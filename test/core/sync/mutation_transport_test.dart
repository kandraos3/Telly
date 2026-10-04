import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/sync/mutation_transport.dart';

void main() {
  late List<http.Request> requests;
  int status = 200;

  SupabaseMutationTransport transport({String? userId = 'u1'}) {
    final client = SupabaseClient(
      'http://supabase.test',
      'anon-key',
      httpClient: MockClient((req) async {
        requests.add(req);
        return http.Response(status == 200 ? 'null' : '{"message":"boom"}', status,
            headers: {'content-type': 'application/json'}, request: req);
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    return SupabaseMutationTransport(client, currentUserId: () => userId);
  }

  PendingMutation mutation(String kind, Map<String, Object?> payload, {String id = 'mut-1'}) => PendingMutation(
        seq: 1,
        id: id,
        kind: kind,
        payload: jsonEncode(payload),
        createdAt: DateTime(2026),
        attempts: 0,
      );

  Map<String, dynamic> body(http.Request r) => jsonDecode(r.body) as Map<String, dynamic>;

  setUp(() {
    requests = [];
    status = 200;
  });

  group('FE-605: SupabaseMutationTransport', () {
    test('log_title → insert_user_ranking_atomic with the client_mutation_id, then the duel batch', () async {
      await transport().apply(mutation(MutationKind.logTitle, {
        'title_id': 136315,
        'media_type': 'tv',
        'target_rank': 3,
        'status': 'COMPLETED',
        'is_rewatch': false,
        'duels': [
          {'client_mutation_id': 'd1', 'winner_title_id': 136315, 'loser_title_id': 1396, 'media_type': 'tv'},
        ],
      }));

      expect(requests.map((r) => r.url.path), ['/rest/v1/rpc/insert_user_ranking_atomic', '/rest/v1/rpc/record_pairwise_duels']);
      expect(body(requests[0]), {
        'p_title_id': 136315,
        'p_media_type': 'tv',
        'p_target_rank': 3,
        'p_status': 'COMPLETED',
        'p_is_rewatch': false,
        'p_client_mutation_id': 'mut-1',
      });
      expect((body(requests[1])['p_duels'] as List).single, containsPair('client_mutation_id', 'd1'));
    });

    test('a placement without duels makes no duel call', () async {
      await transport().apply(mutation(MutationKind.move, {'title_id': 1, 'media_type': 'movie', 'new_rank': 2, 'duels': []}));
      expect(requests.single.url.path, '/rest/v1/rpc/move_user_ranking');
      expect(body(requests.single), containsPair('p_client_mutation_id', 'mut-1'));
    });

    test('delete → delete_user_ranking', () async {
      await transport().apply(mutation(MutationKind.delete, {'title_id': 1, 'media_type': 'tv'}));
      expect(requests.single.url.path, '/rest/v1/rpc/delete_user_ranking');
    });

    test("editorial → PATCH of the caller's own user_rankings row", () async {
      await transport().apply(mutation(MutationKind.editorial, {
        'title_id': 872585,
        'media_type': 'movie',
        'favorite_character': 'Kitty Oppenheimer',
        'review_short': 'Loud.',
        'tags': ['Mind-Bending'],
        'venue': 'IMAX',
      }));
      final r = requests.single;
      expect(r.method, 'PATCH');
      expect(r.url.path, '/rest/v1/user_rankings');
      expect(r.url.queryParameters, {'user_id': 'eq.u1', 'title_id': 'eq.872585', 'media_type': 'eq.movie'});
      expect(body(r), containsPair('venue', 'IMAX'));
      expect(body(r).keys, isNot(contains('rank_position')), reason: 'only RLS-granted editorial columns');
    });

    test('editorial while signed out fails so the engine retries later', () async {
      expect(
        () => transport(userId: null).apply(mutation(MutationKind.editorial, {'title_id': 1, 'media_type': 'tv'})),
        throwsStateError,
      );
    });

    test('server errors propagate (so the queue halts)', () async {
      status = 500;
      expect(
        () => transport().apply(mutation(MutationKind.delete, {'title_id': 1, 'media_type': 'tv'})),
        throwsA(isA<PostgrestException>()),
      );
    });
  });
}
