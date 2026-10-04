import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logging/data/title_repository.dart';
import '../../logging/domain/title_search_result.dart';
import '../../ranking/data/ranking_repository.dart';
import '../../ranking/domain/sentiment_bracket.dart';
import '../domain/anilist_importer.dart';
import '../domain/letterboxd_csv_parser.dart';

class ImportResult {
  /// Titles added to the canon(s).
  final int added;

  /// Entries that could not be matched to a TMDB title.
  final List<String> unmatched;

  const ImportResult({required this.added, this.unmatched = const []});
}

/// Turns Letterboxd / AniList exports into persisted canons (features/01 Screen 3, FE-606).
///
/// Entries are matched to TMDB titles through [TitleRepository.search] (which also caches
/// them server-side, satisfying the `user_rankings → titles` FK), ordered by the user's own
/// rating, and appended through [RankingRepository.appendCanon].
class CanonImportService {
  CanonImportService(this._titles, this._rankings);

  final TitleRepository _titles;
  final RankingRepository _rankings;

  /// Upper bound on lookups per import, so a 2,000-row diary cannot stall onboarding.
  static const maxEntries = 200;

  Future<ImportResult> importLetterboxd(String csv) async {
    final entries = LetterboxdCsvParser.parse(csv);
    final best = <String, LetterboxdEntry>{}; // diaries repeat rewatches: keep the best rating
    for (final e in entries) {
      final key = '${_normalize(e.title)}|${e.releaseYear}';
      final current = best[key];
      if (current == null || (e.rating ?? 0) > (current.rating ?? 0)) best[key] = e;
    }
    final ordered = _byRating(best.values.take(maxEntries).toList(), (e) => e.rating);

    final matched = <(CanonCandidate, String?)>[];
    final unmatched = <String>[];
    for (final e in ordered) {
      final hit = await _match(e.title, mediaType: 'movie', year: e.releaseYear?.toString());
      if (hit == null) {
        unmatched.add(e.title);
      } else {
        final bracket = e.rating == null ? null : SentimentBracketExtension.fromStarRating(e.rating!).name;
        matched.add((hit, bracket));
      }
    }
    final added = await _append('movie', matched);
    return ImportResult(added: added, unmatched: unmatched);
  }

  Future<ImportResult> importAniList(List<AniListEntry> entries) async {
    final ordered = _byRating(entries.take(maxEntries).toList(), (e) => e.userScore);
    final movies = <(CanonCandidate, String?)>[];
    final series = <(CanonCandidate, String?)>[];
    final unmatched = <String>[];
    for (final e in ordered) {
      final mediaType = e.format.toUpperCase() == 'MOVIE' ? 'movie' : 'tv';
      final hit = await _match(e.englishTitle ?? e.romajiTitle, mediaType: mediaType, preferAnime: true) ??
          (e.englishTitle != null ? await _match(e.romajiTitle, mediaType: mediaType, preferAnime: true) : null);
      if (hit == null) {
        unmatched.add(e.preferredTitle);
        continue;
      }
      final bracket = e.userScore == null ? null : SentimentBracketExtension.fromScore(e.userScore!).name;
      (mediaType == 'movie' ? movies : series).add((hit, bracket));
    }
    final added = await _append('movie', movies) + await _append('tv', series);
    return ImportResult(added: added, unmatched: unmatched);
  }

  Future<int> _append(String mediaType, List<(CanonCandidate, String?)> matched) {
    if (matched.isEmpty) return Future.value(0);
    final brackets = {for (final (c, b) in matched) c.titleId: b};
    return _rankings.appendCanon(
      mediaType: mediaType,
      ordered: [for (final (c, _) in matched) c],
      bracketOf: (c) => brackets[c.titleId],
    );
  }

  Future<CanonCandidate?> _match(String title, {required String mediaType, String? year, bool preferAnime = false}) async {
    final results = (await _titles.search(title)).results.where((r) => r.mediaType == mediaType).toList();
    if (results.isEmpty) return null;
    final wanted = _normalize(title);
    int score(TitleSearchResult r) =>
        (_normalize(r.title) == wanted ? 4 : 0) +
        (year != null && r.releaseYear == year ? 2 : 0) +
        (preferAnime && r.isAnime ? 1 : 0);
    final best = results.reduce((a, b) => score(b) > score(a) ? b : a);
    // Without an exact title or year match, a top search hit is too likely to be wrong.
    if (score(best) < 2 && !(year == null && results.length == 1)) return null;
    return CanonCandidate(titleId: best.id, mediaType: mediaType, title: best.title, posterPath: best.posterPath);
  }

  /// Highest rating first; unrated entries last; ties keep export order.
  static List<T> _byRating<T>(List<T> items, double? Function(T) rating) {
    final indexed = items.indexed.toList()
      ..sort((a, b) {
        final ra = rating(a.$2) ?? -1, rb = rating(b.$2) ?? -1;
        return rb != ra ? rb.compareTo(ra) : a.$1.compareTo(b.$1);
      });
    return [for (final (_, item) in indexed) item];
  }

  static String _normalize(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

final canonImportServiceProvider = Provider<CanonImportService>(
  (ref) => CanonImportService(ref.watch(titleRepositoryProvider), ref.watch(rankingRepositoryProvider)),
);

final aniListImporterProvider = Provider<AniListImporter>((ref) => AniListImporter());
