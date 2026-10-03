import 'package:url_launcher/url_launcher.dart';

/// Service responsible for generating native streaming deep links and fallback web URLs.
/// Conforms to `docs/technical_architecture/03_EXTERNAL_APIS_AND_DATA_PIPELINES.md` §3
/// and `docs/features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md` §3.2.
class StreamingDeepLinkFactory {
  /// Generates the native app URI scheme for direct playback on iOS & Android.
  static Uri generateDeepLink({
    required String providerId,
    required String externalShowId,
    String countryCode = 'us',
    String showSlug = '',
  }) {
    final cleanProvider = providerId.toLowerCase().replaceAll('-', '_');
    final slug = showSlug.isNotEmpty ? showSlug : externalShowId;

    switch (cleanProvider) {
      case 'netflix':
        return Uri.parse('nflx://www.netflix.com/title/$externalShowId');

      case 'max':
      case 'hbo':
      case 'hbo_max':
        return Uri.parse('max://play/$externalShowId');

      case 'apple_tv_plus':
      case 'apple_tv':
      case 'appletv':
        return Uri.parse('videos://tv.apple.com/$countryCode/show/$slug/$externalShowId');

      case 'hulu':
        return Uri.parse('hulu://series/$externalShowId');

      case 'prime_video':
      case 'amazon_prime':
      case 'prime':
        return Uri.parse('primevideo://watch?asin=$externalShowId');

      case 'crunchyroll':
        return Uri.parse('crunchyroll://series/$externalShowId');

      case 'disney_plus':
      case 'disney':
        return Uri.parse('https://www.disneyplus.com/series/$slug/$externalShowId');

      default:
        return Uri.parse('https://www.google.com/search?q=watch+$slug+online');
    }
  }

  /// Generates the fallback HTTPS web URL if the native streaming app is not installed.
  static Uri generateWebFallbackUrl({
    required String providerId,
    required String externalShowId,
    String countryCode = 'us',
    String showSlug = '',
  }) {
    final cleanProvider = providerId.toLowerCase().replaceAll('-', '_');
    final slug = showSlug.isNotEmpty ? showSlug : externalShowId;

    switch (cleanProvider) {
      case 'netflix':
        return Uri.parse('https://www.netflix.com/title/$externalShowId');

      case 'max':
      case 'hbo':
      case 'hbo_max':
        return Uri.parse('https://play.max.com/show/$externalShowId');

      case 'apple_tv_plus':
      case 'apple_tv':
      case 'appletv':
        return Uri.parse('https://tv.apple.com/$countryCode/show/$slug/$externalShowId');

      case 'hulu':
        return Uri.parse('https://www.hulu.com/series/$externalShowId');

      case 'prime_video':
      case 'amazon_prime':
      case 'prime':
        return Uri.parse('https://www.amazon.com/gp/video/detail/$externalShowId');

      case 'crunchyroll':
        return Uri.parse('https://www.crunchyroll.com/series/$externalShowId');

      case 'disney_plus':
      case 'disney':
        return Uri.parse('https://www.disneyplus.com/series/$slug/$externalShowId');

      default:
        return Uri.parse('https://www.google.com/search?q=watch+$slug+online');
    }
  }

  /// Attempts to launch native app via deep link; on failure or if not supported,
  /// opens web fallback in external browser.
  static Future<bool> launchPlayback({
    required String providerId,
    required String externalShowId,
    String countryCode = 'us',
    String showSlug = '',
  }) async {
    final deepLink = generateDeepLink(
      providerId: providerId,
      externalShowId: externalShowId,
      countryCode: countryCode,
      showSlug: showSlug,
    );

    final webFallback = generateWebFallbackUrl(
      providerId: providerId,
      externalShowId: externalShowId,
      countryCode: countryCode,
      showSlug: showSlug,
    );

    try {
      if (await canLaunchUrl(deepLink)) {
        return await launchUrl(deepLink, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Fallback below
    }

    try {
      return await launchUrl(webFallback, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
