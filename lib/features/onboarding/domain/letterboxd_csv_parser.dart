import 'package:csv/csv.dart';
import '../../ranking/domain/sentiment_bracket.dart';

class LetterboxdEntry {
  final String date;
  final String title;
  final int? releaseYear;
  final String? letterboxdUri;
  final double? rating; // 0.5 to 5.0 stars
  final bool isRewatch;
  final List<String> tags;
  final String? watchedDate;

  const LetterboxdEntry({
    required this.date,
    required this.title,
    this.releaseYear,
    this.letterboxdUri,
    this.rating,
    this.isRewatch = false,
    this.tags = const [],
    this.watchedDate,
  });

  SentimentBracket get sentimentBracket {
    if (rating == null || rating! <= 0) {
      return SentimentBracket.liked;
    }
    return SentimentBracketExtension.fromStarRating(rating!);
  }
}

class LetterboxdCsvParser {
  /// Parses raw CSV content exported from Letterboxd (`diary.csv` or `watched.csv`).
  /// Conforms to `docs/features/09_MOVIE_INTEGRATION_AND_DUAL_CANON.md` §4
  /// and `docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md` §2.2.
  static List<LetterboxdEntry> parse(String csvContent) {
    if (csvContent.trim().isEmpty) {
      return [];
    }

    const converter = CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    );

    // Normalize Windows line endings to \n
    final normalizedContent = csvContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rows = converter.convert(normalizedContent);

    if (rows.isEmpty) return [];

    // Find column header indices dynamically
    final headerRow = rows.first.map((col) => col.toString().trim().toLowerCase()).toList();

    final nameIndex = headerRow.indexOf('name');
    if (nameIndex == -1) {
      // Not a valid Letterboxd export without 'Name'
      return [];
    }

    final dateIndex = headerRow.indexOf('date');
    final yearIndex = headerRow.indexOf('year');
    final uriIndex = headerRow.indexOf('letterboxd uri');
    final ratingIndex = headerRow.indexOf('rating');
    final rewatchIndex = headerRow.indexOf('rewatch');
    final tagsIndex = headerRow.indexOf('tags');
    final watchedDateIndex = headerRow.indexOf('watched date');

    final entries = <LetterboxdEntry>[];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;
      if (row.length <= nameIndex) continue;

      final title = row[nameIndex].toString().trim();
      if (title.isEmpty) continue;

      // Extract Year
      int? year;
      if (yearIndex != -1 && yearIndex < row.length) {
        final yearStr = row[yearIndex].toString().trim();
        year = int.tryParse(yearStr);
      }

      // Extract Rating
      double? rating;
      if (ratingIndex != -1 && ratingIndex < row.length) {
        final ratingStr = row[ratingIndex].toString().trim();
        if (ratingStr.isNotEmpty) {
          rating = double.tryParse(ratingStr);
        }
      }

      // Extract Rewatch
      bool isRewatch = false;
      if (rewatchIndex != -1 && rewatchIndex < row.length) {
        final rewatchStr = row[rewatchIndex].toString().trim().toLowerCase();
        isRewatch = rewatchStr == 'yes' || rewatchStr == 'true' || rewatchStr == '1';
      }

      // Extract URI
      String? uri;
      if (uriIndex != -1 && uriIndex < row.length) {
        final uriStr = row[uriIndex].toString().trim();
        if (uriStr.isNotEmpty) uri = uriStr;
      }

      // Extract Date
      String date = '';
      if (dateIndex != -1 && dateIndex < row.length) {
        date = row[dateIndex].toString().trim();
      }

      // Extract Tags
      List<String> tags = [];
      if (tagsIndex != -1 && tagsIndex < row.length) {
        final tagStr = row[tagsIndex].toString().trim();
        if (tagStr.isNotEmpty) {
          tags = tagStr.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
        }
      }

      // Extract Watched Date
      String? watchedDate;
      if (watchedDateIndex != -1 && watchedDateIndex < row.length) {
        final wStr = row[watchedDateIndex].toString().trim();
        if (wStr.isNotEmpty) watchedDate = wStr;
      }

      entries.add(
        LetterboxdEntry(
          date: date,
          title: title,
          releaseYear: year,
          letterboxdUri: uri,
          rating: rating,
          isRewatch: isRewatch,
          tags: tags,
          watchedDate: watchedDate,
        ),
      );
    }

    return entries;
  }
}
