import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';

/// FE-601: SupabaseAuthRepository against a real SupabaseClient whose HTTP layer is mocked,
/// so request shapes (paths, bodies) and error mapping are exercised without a network.
void main() {
  const userId = '11111111-1111-1111-1111-111111111111';
  late List<http.Request> requests;

  String fakeJwt() {
    String b64(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
    final exp = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
    return '${b64({'alg': 'HS256'})}.${b64({'sub': userId, 'exp': exp, 'role': 'authenticated'})}.sig';
  }

  Map<String, dynamic> sessionJson() => {
        'access_token': fakeJwt(),
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': 'refresh',
        'user': {
          'id': userId,
          'aud': 'authenticated',
          'role': 'authenticated',
          'phone': '15551234567',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'created_at': '2026-10-01T00:00:00Z',
        },
      };

  SupabaseAuthRepository repoWith(
    Future<http.Response> Function(http.Request) handler, {
    AuthFlowType flowType = AuthFlowType.pkce,
  }) {
    final client = SupabaseClient(
      'http://supabase.test',
      'anon-key',
      httpClient: MockClient((req) async {
        requests.add(req);
        final res = await handler(req);
        // postgrest reads response.request; a bare http.Response leaves it null.
        return http.Response(res.body, res.statusCode, headers: res.headers, request: req);
      }),
      authOptions: AuthClientOptions(autoRefreshToken: false, authFlowType: flowType),
    );
    return SupabaseAuthRepository(client, redirectUrl: 'app.telly.mobile://login-callback');
  }

  setUp(() => requests = []);

  test('checkHandleAvailable calls the check_handle_available RPC with the normalized handle', () async {
    final repo = repoWith((_) async => http.Response('true', 200, headers: {'content-type': 'application/json'}));

    expect(await repo.checkHandleAvailable('  Jordan '), isTrue);
    expect(requests.single.url.path, '/rest/v1/rpc/check_handle_available');
    expect(jsonDecode(requests.single.body), {'p_handle': 'jordan'});
  });

  test('checkHandleAvailable rejects malformed or reserved handles without a network call', () async {
    final repo = repoWith((_) async => http.Response('true', 200));

    expect(await repo.checkHandleAvailable('ab'), isFalse);
    expect(await repo.checkHandleAvailable('netflix'), isFalse);
    expect(requests, isEmpty);
  });

  test('verifyPhoneOtp returns false for an invalid code (no mock pass-through)', () async {
    final repo = repoWith((_) async => http.Response(
          jsonEncode({'code': 403, 'error_code': 'otp_expired', 'msg': 'Token has expired or is invalid'}),
          403,
          headers: {'content-type': 'application/json'},
        ));

    expect(await repo.verifyPhoneOtp('+15551234567', '999999'), isFalse);
    expect(requests.single.url.path, '/auth/v1/verify');
    expect(repo.currentUserId, isNull);
  });

  test('verifyPhoneOtp creates a session on success; completeRegistration maps 23505 to HandleTakenException',
      () async {
    final repo = repoWith((req) async {
      if (req.url.path == '/auth/v1/verify') {
        return http.Response(jsonEncode(sessionJson()), 200, headers: {'content-type': 'application/json'});
      }
      if (req.url.path == '/rest/v1/users' && req.method == 'PATCH') {
        return http.Response(
          jsonEncode(
              {'code': '23505', 'message': 'duplicate key value violates unique constraint "users_username_key"'}),
          409,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('not found', 404);
    });

    expect(await repo.verifyPhoneOtp('+15551234567', '123456'), isTrue);
    expect(repo.currentUserId, userId);

    await expectLater(
      repo.completeRegistration(username: 'Taken_User', displayName: 'X'),
      throwsA(isA<HandleTakenException>().having((e) => e.handle, 'handle', 'taken_user')),
    );
    final patch = requests.last;
    expect(patch.url.queryParameters['id'], 'eq.$userId');
    expect(jsonDecode(patch.body), {'username': 'taken_user', 'display_name': 'X'});
  });

  test('completeRegistration requires a signed-in user', () async {
    final repo = repoWith((_) async => http.Response('{}', 200));
    await expectLater(repo.completeRegistration(username: 'jordan', displayName: 'J'), throwsStateError);
  });

  test('FE-AUTH-03: sendPasswordResetEmail posts to /recover with the app redirect URL', () async {
    // PKCE needs platform storage for the code verifier; the request shape is the same.
    final repo = repoWith(
      (_) async => http.Response('{}', 200, headers: {'content-type': 'application/json'}),
      flowType: AuthFlowType.implicit,
    );

    await repo.sendPasswordResetEmail('  jordan@example.com ');

    final req = requests.single;
    expect(req.url.path, '/auth/v1/recover');
    expect(req.url.queryParameters['redirect_to'], 'app.telly.mobile://login-callback');
    expect((jsonDecode(req.body) as Map)['email'], 'jordan@example.com');
  });
}
