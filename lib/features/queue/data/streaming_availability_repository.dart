import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_providers.dart';
import '../domain/streaming_models.dart';

/// Repository providing streaming availability queries and catalog metadata (FE-609, BE-605).
/// Conforms to `docs/features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md` §3 and
/// `docs/technical_architecture/03_EXTERNAL_APIS_AND_DATA_PIPELINES.md` §3.
abstract interface class StreamingAvailabilityRepository {
  Future<List<ShowStreamingAvailability>> getAvailability({
    required int titleId,
    required String mediaType,
    String? country,
  });
}

class SupabaseStreamingAvailabilityRepository implements StreamingAvailabilityRepository {
  SupabaseStreamingAvailabilityRepository(this._functions);

  final FunctionsClient _functions;

  static const _timeout = Duration(seconds: 4);

  @override
  Future<List<ShowStreamingAvailability>> getAvailability({
    required int titleId,
    required String mediaType,
    String? country,
  }) async {
    try {
      final response = await _functions.invoke(
        'streaming-availability',
        method: HttpMethod.get,
        queryParameters: {
          'tmdb_id': '$titleId',
          'media_type': mediaType,
          if (country != null) 'country': country,
        },
      ).timeout(_timeout);

      final data = response.data;
      if (data is! Map<String, dynamic>) return const [];
      final providers = data['providers'] as List? ?? const [];

      return [
        for (final p in providers.cast<Map<String, dynamic>>())
          ShowStreamingAvailability(
            platformId: p['platform_id'] as String,
            platformName: _platformDisplayName(p['platform_id'] as String),
            monetizationType: MonetizationType.fromString((p['monetization_type'] as String?) ?? 'flatrate'),
            webUrl: (p['web_url'] as String?) ?? '',
            deepLinkUrl: (p['ios_url'] as String?) ?? (p['android_url'] as String?) ?? (p['web_url'] as String?),
            availableUntil: p['available_until'] != null ? DateTime.tryParse(p['available_until'] as String) : null,
            isLeavingSoon: (p['is_leaving_soon'] as bool?) ?? false,
          ),
      ];
    } catch (_) {
      // Graceful offline fallback: title is treated as unknown availability.
      return const [];
    }
  }

  static String _platformDisplayName(String platformId) {
    for (final p in StreamingPlatform.standardPlatforms) {
      if (p.id == platformId) return p.displayName;
    }
    return platformId.replaceAll('_', ' ').toUpperCase();
  }
}

final streamingAvailabilityRepositoryProvider = Provider<StreamingAvailabilityRepository>(
  (ref) => SupabaseStreamingAvailabilityRepository(ref.watch(supabaseClientProvider).functions),
);

