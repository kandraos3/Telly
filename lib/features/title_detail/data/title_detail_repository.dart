import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_providers.dart';
import '../domain/title_detail_models.dart';

abstract interface class TitleDetailRepository {
  Future<TitleDetail?> fetchTitleDetail({
    required int id,
    required String mediaType,
  });
}

class SupabaseTitleDetailRepository implements TitleDetailRepository {
  final SupabaseClient _client;

  SupabaseTitleDetailRepository(this._client);

  @override
  Future<TitleDetail?> fetchTitleDetail({
    required int id,
    required String mediaType,
  }) async {
    final titleRow = await _client
        .from('titles')
        .select()
        .eq('id', id)
        .eq('media_type', mediaType)
        .maybeSingle();

    if (titleRow == null) return null;

    List<Map<String, dynamic>> seasonRows = const [];
    if (mediaType == 'tv') {
      final seasonsResponse = await _client
          .from('tv_seasons')
          .select()
          .eq('title_id', id)
          .eq('media_type', mediaType)
          .order('season_number', ascending: true);
      seasonRows = seasonsResponse
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    }

    final availabilityResponse = await _client
        .from('title_availability')
        .select()
        .eq('title_id', id)
        .eq('media_type', mediaType);
    final availabilityRows = availabilityResponse
        .map((r) => Map<String, dynamic>.from(r))
        .toList();

    Map<String, dynamic>? socialSummaryJson;
    try {
      final socialResponse = await _client.rpc(
        'get_title_social_summary',
        params: {
          'p_title_id': id,
          'p_media_type': mediaType,
        },
      );
      if (socialResponse is Map) {
        socialSummaryJson = Map<String, dynamic>.from(socialResponse);
      }
    } catch (_) {
      // Social summary is optional if offline / unauthenticated
    }

    return TitleDetail.fromJson(
      titleRow: Map<String, dynamic>.from(titleRow),
      seasonRows: seasonRows,
      availabilityRows: availabilityRows,
      socialSummaryJson: socialSummaryJson,
    );
  }
}

class FakeTitleDetailRepository implements TitleDetailRepository {
  final Map<(int, String), TitleDetail> _titles = {};

  FakeTitleDetailRepository([List<TitleDetail> initial = const []]) {
    for (final t in initial) {
      _titles[(t.id, t.mediaType)] = t;
    }
  }

  void addTitle(TitleDetail title) {
    _titles[(title.id, title.mediaType)] = title;
  }

  @override
  Future<TitleDetail?> fetchTitleDetail({
    required int id,
    required String mediaType,
  }) async {
    return _titles[(id, mediaType)];
  }
}

final titleDetailRepositoryProvider = Provider<TitleDetailRepository>((ref) {
  return SupabaseTitleDetailRepository(ref.watch(supabaseClientProvider));
});

final titleDetailFutureProvider = FutureProvider.family<TitleDetail?, (int, String)>((ref, args) {
  final (id, mediaType) = args;
  return ref.watch(titleDetailRepositoryProvider).fetchTitleDetail(
        id: id,
        mediaType: mediaType,
      );
});
