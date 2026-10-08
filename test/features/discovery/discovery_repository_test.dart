import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:telly_app/features/discovery/data/discovery_repository.dart';

// #189 (decision 0008): "Not for me" writes user_dismissed_recommendations, never user_muted_titles.
void main() {
  late List<http.Request> requests;

  SupabaseDiscoveryRepository repo({String? userId = 'u-me'}) => SupabaseDiscoveryRepository(
        SupabaseClient(
          'http://supabase.test',
          'anon-key',
          httpClient: MockClient((req) async {
            requests.add(req);
            return http.Response('[]', 200, headers: {'content-type': 'application/json'}, request: req);
          }),
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        currentUserId: () => userId,
      );

  setUp(() => requests = []);

  test('dismissing upserts my row into user_dismissed_recommendations', () async {
    await repo().dismissRecommendation(27205, 'movie');

    final req = requests.single;
    expect(req.method, 'POST');
    expect(req.url.path, '/rest/v1/user_dismissed_recommendations');
    expect(req.headers['Prefer'], contains('resolution=merge-duplicates'));
    expect(jsonDecode(req.body), {'user_id': 'u-me', 'title_id': 27205, 'media_type': 'movie'});
  });

  test('undo deletes exactly that row', () async {
    await repo().undoDismissRecommendation(27205, 'movie');

    final req = requests.single;
    expect(req.method, 'DELETE');
    expect(req.url.path, '/rest/v1/user_dismissed_recommendations');
    expect(req.url.queryParameters, {'user_id': 'eq.u-me', 'title_id': 'eq.27205', 'media_type': 'eq.movie'});
  });

  test('signed out, nothing is sent', () async {
    expect(() => repo(userId: null).dismissRecommendation(1, 'tv'), throwsStateError);
    expect(requests, isEmpty);
  });
}
