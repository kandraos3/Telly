import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/network/supabase_providers.dart';
import '../domain/title_search_result.dart';

/// Title search for the Logging Studio (FE-603).
abstract interface class TitleRepository {
  Future<TitleSearchOutcome> search(String query);

  /// Cast and director for `SCR-11`; [TitleCredits.empty] when unavailable (e.g. offline).
  Future<TitleCredits> fetchCredits(int id, String mediaType);
}

/// Searches TMDB through the `tmdb-search` edge function and caches results into Drift
/// `CachedTitles`; when the network call fails it falls back to the local cache.
class SupabaseTitleRepository implements TitleRepository {
  SupabaseTitleRepository(this._functions, this._titles);

  final FunctionsClient _functions;
  final LocalTitleDao _titles;

  @override
  Future<TitleSearchOutcome> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const TitleSearchOutcome([]);

    final List<TitleSearchResult> results;
    try {
      final response = await _functions.invoke(
        'tmdb-search',
        method: HttpMethod.get,
        queryParameters: {'query': q},
      );
      final body = response.data as Map<String, dynamic>;
      results = [
        for (final r in (body['results'] as List? ?? const []))
          TitleSearchResult.fromJson(r as Map<String, dynamic>),
      ];
    } catch (_) {
      final cached = await _titles.searchTitles(q);
      return TitleSearchOutcome(cached.map(TitleSearchResult.fromCached).toList(), fromLocalCache: true);
    }

    // Best effort: a failed cache write must not fail the search.
    try {
      await _titles.upsertBatchTitles([
        for (final r in results)
          CachedTitlesCompanion.insert(
            id: r.id,
            mediaType: r.mediaType,
            title: r.title,
            posterPath: Value(r.posterPath),
            releaseDate: Value(r.releaseYear.isEmpty ? null : r.releaseYear),
            isAnime: Value(r.isAnime),
          ),
      ]);
    } catch (_) {}
    return TitleSearchOutcome(results);
  }

  @override
  Future<TitleCredits> fetchCredits(int id, String mediaType) async {
    try {
      final response = await _functions
          .invoke('tmdb-details', method: HttpMethod.get, queryParameters: {'id': '$id', 'media_type': mediaType})
          .timeout(creditsTimeout);
      return TitleCredits.fromDetailsJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return TitleCredits.empty;
    }
  }

  /// Credits only enrich the editorial sheet, so they never hold up the flow for long.
  static const creditsTimeout = Duration(seconds: 3);
}

final titleRepositoryProvider = Provider<TitleRepository>(
  (ref) => SupabaseTitleRepository(ref.watch(supabaseClientProvider).functions, ref.watch(localTitleDaoProvider)),
);
