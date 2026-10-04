import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:telly_app/features/queue/data/streaming_availability_repository.dart';
import 'package:telly_app/features/queue/domain/streaming_models.dart';

void main() {
  group('FE-609: SupabaseStreamingAvailabilityRepository tests', () {
    test('invokes streaming-availability with query parameters and parses providers', () async {
      late http.Request seenRequest;
      final payload = {
        'tmdb_id': 101,
        'media_type': 'tv',
        'country_code': 'US',
        'providers': [
          {
            'platform_id': 'apple_tv_plus',
            'monetization_type': 'flatrate',
            'web_url': 'https://tv.apple.com/us/show/slow-horses/101',
            'ios_url': 'videos://tv.apple.com/us/show/slow-horses/101',
            'android_url': null,
            'available_until': '2026-12-31',
            'is_leaving_soon': false,
          },
          {
            'platform_id': 'max',
            'monetization_type': 'rent',
            'web_url': 'https://play.max.com/show/101',
            'ios_url': 'max://play/101',
            'android_url': null,
            'available_until': null,
            'is_leaving_soon': true,
          },
        ],
      };

      final client = FunctionsClient(
        'https://x.supabase.co/functions/v1',
        const {},
        httpClient: MockClient((req) async {
          seenRequest = req;
          return http.Response(
            jsonEncode(payload),
            200,
            headers: {'content-type': 'application/json'},
            request: req,
          );
        }),
      );

      final repo = SupabaseStreamingAvailabilityRepository(client);
      final results = await repo.getAvailability(
        titleId: 101,
        mediaType: 'tv',
        country: 'US',
      );

      expect(seenRequest.method, 'GET');
      expect(seenRequest.url.path, endsWith('/streaming-availability'));
      expect(seenRequest.url.queryParameters['tmdb_id'], '101');
      expect(seenRequest.url.queryParameters['media_type'], 'tv');
      expect(seenRequest.url.queryParameters['country'], 'US');

      expect(results, hasLength(2));
      expect(results.first.platformId, 'apple_tv_plus');
      expect(results.first.platformName, 'Apple TV+');
      expect(results.first.monetizationType, MonetizationType.flatrate);
      expect(results.first.deepLinkUrl, 'videos://tv.apple.com/us/show/slow-horses/101');
      expect(results.first.isLeavingSoon, isFalse);

      expect(results.last.platformId, 'max');
      expect(results.last.monetizationType, MonetizationType.rent);
      expect(results.last.isLeavingSoon, isTrue);
    });

    test('degrades gracefully to empty list on network error', () async {
      final client = FunctionsClient(
        'https://x.supabase.co/functions/v1',
        const {},
        httpClient: MockClient((req) async {
          throw http.ClientException('Network unreachable');
        }),
      );

      final repo = SupabaseStreamingAvailabilityRepository(client);
      final results = await repo.getAvailability(titleId: 999, mediaType: 'movie');
      expect(results, isEmpty);
    });
  });
}

