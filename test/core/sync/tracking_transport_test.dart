import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/sync/mutation_transport.dart';

// #228: every tracking mutation replays to its §6.2 RPC with the client_mutation_id (I-5).
void main() {
  late List<http.Request> requests;
  int status = 200;

  SupabaseMutationTransport transport() {
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
    return SupabaseMutationTransport(client, currentUserId: () => 'u1');
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

  test('tracking_start → start_tracking with the place and the rewatch flag', () async {
    await transport().apply(mutation(MutationKind.trackingStart, {
      'title_id': 95396,
      'media_type': 'tv',
      'last_season': 2,
      'last_episode': 5,
      'rewatch': true,
    }));
    expect(requests.single.url.path, '/rest/v1/rpc/start_tracking');
    expect(body(requests.single), {
      'p_title_id': 95396,
      'p_media_type': 'tv',
      'p_last_season': 2,
      'p_last_episode': 5,
      'p_rewatch': true,
      'p_client_mutation_id': 'mut-1',
    });
  });

  test('tracking_start from the beginning sends a null place and no rewatch', () async {
    await transport().apply(mutation(MutationKind.trackingStart, {'title_id': 7, 'media_type': 'movie'}));
    expect(body(requests.single), {
      'p_title_id': 7,
      'p_media_type': 'movie',
      'p_last_season': null,
      'p_last_episode': null,
      'p_rewatch': false,
      'p_client_mutation_id': 'mut-1',
    });
  });

  test('tracking_place → set_tracking_place with an absolute place, null for the very beginning', () async {
    await transport().apply(mutation(MutationKind.trackingPlace,
        {'title_id': 95396, 'media_type': 'tv', 'last_season': 1, 'last_episode': 9}, id: 'm2'));
    await transport().apply(mutation(MutationKind.trackingPlace,
        {'title_id': 95396, 'media_type': 'tv', 'last_season': null, 'last_episode': null}, id: 'm3'));
    expect(requests.map((r) => r.url.path), ['/rest/v1/rpc/set_tracking_place', '/rest/v1/rpc/set_tracking_place']);
    expect(body(requests[0]), {
      'p_title_id': 95396,
      'p_media_type': 'tv',
      'p_last_season': 1,
      'p_last_episode': 9,
      'p_client_mutation_id': 'm2',
    });
    expect(body(requests[1])['p_last_season'], isNull);
    expect(body(requests[1])['p_client_mutation_id'], 'm3');
  });

  test('tracking_rewatch → log_episode_rewatch', () async {
    await transport().apply(mutation(MutationKind.trackingRewatch,
        {'title_id': 95396, 'media_type': 'tv', 'season': 2, 'episode': 6}));
    expect(requests.single.url.path, '/rest/v1/rpc/log_episode_rewatch');
    expect(body(requests.single),
        {'p_title_id': 95396, 'p_season': 2, 'p_episode': 6, 'p_client_mutation_id': 'mut-1'});
  });

  test('tracking_finish → finish_tracking and tracking_stop → stop_tracking', () async {
    await transport().apply(mutation(MutationKind.trackingFinish, {'title_id': 1, 'media_type': 'movie'}, id: 'f'));
    await transport().apply(mutation(MutationKind.trackingStop, {'title_id': 1, 'media_type': 'movie'}, id: 's'));
    expect(requests.map((r) => r.url.path), ['/rest/v1/rpc/finish_tracking', '/rest/v1/rpc/stop_tracking']);
    expect(body(requests[0]), {'p_title_id': 1, 'p_media_type': 'movie', 'p_client_mutation_id': 'f'});
    expect(body(requests[1]), {'p_title_id': 1, 'p_media_type': 'movie', 'p_client_mutation_id': 's'});
  });

  test('tracking_revive → revive_dropped_show', () async {
    await transport().apply(mutation(MutationKind.trackingRevive, {'title_id': 1396, 'media_type': 'tv'}));
    expect(requests.single.url.path, '/rest/v1/rpc/revive_dropped_show');
    expect(body(requests.single), {'p_title_id': 1396, 'p_client_mutation_id': 'mut-1'});
  });

  test('a server failure throws, so the sync engine keeps the mutation and backs off', () async {
    status = 500;
    await expectLater(
      transport().apply(mutation(MutationKind.trackingPlace,
          {'title_id': 1, 'media_type': 'tv', 'last_season': 1, 'last_episode': 1})),
      throwsA(isA<PostgrestException>()),
    );
  });
}
