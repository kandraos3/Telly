import '../../../core/database/database.dart';

/// A searchable movie/tv title as returned by the `tmdb-search` edge function (FE-603).
/// `(id, mediaType)` is the title key — TMDB ids collide across movies and tv.
class TitleSearchResult {
  final int id;
  final String mediaType; // 'movie' | 'tv'
  final String title;
  final String releaseYear;
  final String? posterPath;
  final bool isAnime;

  const TitleSearchResult({
    required this.id,
    required this.mediaType,
    required this.title,
    this.releaseYear = '',
    this.posterPath,
    this.isAnime = false,
  });

  bool get isMovie => mediaType == 'movie';

  factory TitleSearchResult.fromJson(Map<String, dynamic> json) => TitleSearchResult(
        id: (json['id'] as num).toInt(),
        mediaType: json['media_type'] as String,
        title: json['title'] as String,
        releaseYear: (json['release_year'] as String?) ?? '',
        posterPath: json['poster_path'] as String?,
        isAnime: (json['is_anime'] as bool?) ?? false,
      );

  factory TitleSearchResult.fromCached(CachedTitle row) => TitleSearchResult(
        id: row.id,
        mediaType: row.mediaType,
        title: row.title,
        releaseYear: (row.releaseDate?.length ?? 0) >= 4 ? row.releaseDate!.substring(0, 4) : '',
        posterPath: row.posterPath,
        isAnime: row.isAnime,
      );

  @override
  bool operator ==(Object other) => other is TitleSearchResult && other.id == id && other.mediaType == mediaType;

  @override
  int get hashCode => Object.hash(id, mediaType);
}

/// Search results plus where they came from, so the UI can say when it is offline.
class TitleSearchOutcome {
  final List<TitleSearchResult> results;
  final bool fromLocalCache;

  const TitleSearchOutcome(this.results, {this.fromLocalCache = false});
}
