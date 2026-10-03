import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/services/streaming_deep_link_factory.dart';

void main() {
  group('QA-402: StreamingDeepLinkFactory Unit Tests', () {
    const testId = '87108';
    const testSlug = 'chernobyl';

    test('generates accurate native deep links for all major streaming platforms', () {
      final netflixUri = StreamingDeepLinkFactory.generateDeepLink(
        providerId: 'netflix',
        externalShowId: testId,
      );
      expect(netflixUri.scheme, 'nflx');
      expect(netflixUri.host, 'www.netflix.com');
      expect(netflixUri.path, '/title/$testId');

      final maxUri = StreamingDeepLinkFactory.generateDeepLink(
        providerId: 'max',
        externalShowId: testId,
      );
      expect(maxUri.scheme, 'max');
      expect(maxUri.host, 'play');
      expect(maxUri.path, '/$testId');

      final appleUri = StreamingDeepLinkFactory.generateDeepLink(
        providerId: 'apple_tv_plus',
        externalShowId: testId,
        countryCode: 'us',
        showSlug: testSlug,
      );
      expect(appleUri.scheme, 'videos');
      expect(appleUri.host, 'tv.apple.com');
      expect(appleUri.path, '/us/show/$testSlug/$testId');

      final huluUri = StreamingDeepLinkFactory.generateDeepLink(
        providerId: 'hulu',
        externalShowId: testId,
      );
      expect(huluUri.scheme, 'hulu');
      expect(huluUri.host, 'series');
      expect(huluUri.path, '/$testId');

      final primeUri = StreamingDeepLinkFactory.generateDeepLink(
        providerId: 'prime_video',
        externalShowId: testId,
      );
      expect(primeUri.scheme, 'primevideo');
      expect(primeUri.host, 'watch');
      expect(primeUri.queryParameters['asin'], testId);

      final crunchyUri = StreamingDeepLinkFactory.generateDeepLink(
        providerId: 'crunchyroll',
        externalShowId: testId,
      );
      expect(crunchyUri.scheme, 'crunchyroll');
      expect(crunchyUri.host, 'series');
      expect(crunchyUri.path, '/$testId');

      final disneyUri = StreamingDeepLinkFactory.generateDeepLink(
        providerId: 'disney_plus',
        externalShowId: testId,
        showSlug: testSlug,
      );
      expect(disneyUri.scheme, 'https');
      expect(disneyUri.host, 'www.disneyplus.com');
      expect(disneyUri.path, '/series/$testSlug/$testId');
    });

    test('generates proper web fallback URLs when app is not installed', () {
      final netflixWeb = StreamingDeepLinkFactory.generateWebFallbackUrl(
        providerId: 'netflix',
        externalShowId: testId,
      );
      expect(netflixWeb.scheme, 'https');
      expect(netflixWeb.host, 'www.netflix.com');

      final maxWeb = StreamingDeepLinkFactory.generateWebFallbackUrl(
        providerId: 'max',
        externalShowId: testId,
      );
      expect(maxWeb.scheme, 'https');
      expect(maxWeb.host, 'play.max.com');

      final appleWeb = StreamingDeepLinkFactory.generateWebFallbackUrl(
        providerId: 'apple_tv_plus',
        externalShowId: testId,
        showSlug: testSlug,
      );
      expect(appleWeb.scheme, 'https');
      expect(appleWeb.host, 'tv.apple.com');

      final huluWeb = StreamingDeepLinkFactory.generateWebFallbackUrl(
        providerId: 'hulu',
        externalShowId: testId,
      );
      expect(huluWeb.scheme, 'https');
      expect(huluWeb.host, 'www.hulu.com');

      final primeWeb = StreamingDeepLinkFactory.generateWebFallbackUrl(
        providerId: 'prime_video',
        externalShowId: testId,
      );
      expect(primeWeb.scheme, 'https');
      expect(primeWeb.host, 'www.amazon.com');

      final crunchyWeb = StreamingDeepLinkFactory.generateWebFallbackUrl(
        providerId: 'crunchyroll',
        externalShowId: testId,
      );
      expect(crunchyWeb.scheme, 'https');
      expect(crunchyWeb.host, 'www.crunchyroll.com');
    });

    test('fallback to web search for unknown provider', () {
      final fallback = StreamingDeepLinkFactory.generateDeepLink(
        providerId: 'unknown_streaming_service',
        externalShowId: '999',
        showSlug: 'obscure_movie',
      );
      expect(fallback.scheme, 'https');
      expect(fallback.host, 'www.google.com');
      expect(fallback.queryParameters['q'], contains('watch obscure_movie online'));
    });
  });
}
