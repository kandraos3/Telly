library data_exporter;

import 'package:csv/csv.dart';

/// Data representation of a user ranking entry prepared for export.
/// Conforms to `FE-506` and `docs/adjacent_systems/04_VIRAL_SHARING_AND_EXPORT_STUDIO.md` §5.
class ExportRankingItem {
  final String title;
  final int tmdbId;
  final int? rank;
  final double? score;
  final String status;
  final String tier;
  final String? review;
  final String? mvpActor;
  final List<String> tags;
  final String dateLogged;
  final int? year;
  final String mediaType;

  const ExportRankingItem({
    required this.title,
    required this.tmdbId,
    this.rank,
    this.score,
    this.status = 'COMPLETED',
    this.tier = 'God Tier',
    this.review,
    this.mvpActor,
    this.tags = const [],
    required this.dateLogged,
    this.year,
    this.mediaType = 'tv',
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'tmdb_id': tmdbId,
        'rank': rank,
        'score': score,
        'status': status,
        'tier': tier,
        'review': review,
        'mvp_actor': mvpActor,
        'tags': tags,
        'date_logged': dateLogged,
        'year': year,
        'media_type': mediaType,
      };
}

/// Service exporting personal canon and logs into RFC 4180 CSV, Letterboxd, Notion, and AniList formats.
/// Conforms to `FE-506`.
class DataExporter {
  /// Format 1: RFC 4180 Standard CSV Export for Telly Canon.
  /// Columns: `title,tmdb_id,rank,score,status,tier,review,mvp_actor,tags,date_logged`
  static String generateCanonCsv({
    List<ExportRankingItem>? sampleRankings,
    List<ExportRankingItem>? items,
  }) {
    final list = items ?? sampleRankings ?? [];
    final List<List<dynamic>> rows = [
      [
        'title',
        'tmdb_id',
        'rank',
        'score',
        'status',
        'tier',
        'review',
        'mvp_actor',
        'tags',
        'date_logged',
        // TMDB ids collide across movies and tv, so the canon must travel with the id.
        'media_type',
      ],
    ];

    for (final item in list) {
      rows.add([
        item.title,
        item.tmdbId,
        item.rank ?? '',
        item.score != null ? item.score!.toStringAsFixed(2) : '',
        item.status,
        item.tier,
        item.review ?? '',
        item.mvpActor ?? '',
        item.tags.join(';'),
        item.dateLogged,
        item.mediaType,
      ]);
    }

    return const ListToCsvConverter(eol: '\r\n').convert(rows);
  }

  /// Format 2: Letterboxd Compatible Diary/Watchlist CSV Import Format.
  /// Columns: `Title,Year,Rating10,WatchedDate,Review,Tags`
  static String generateLetterboxdCsv({List<ExportRankingItem>? items}) {
    final list = items ?? [];
    final List<List<dynamic>> rows = [
      [
        'Title',
        'Year',
        'Rating10',
        'WatchedDate',
        'Review',
        'Tags',
      ],
    ];

    for (final item in list) {
      rows.add([
        item.title,
        item.year ?? '',
        item.score != null ? item.score!.toStringAsFixed(1) : '',
        item.dateLogged,
        item.review ?? '',
        item.tags.join(', '),
      ]);
    }

    return const ListToCsvConverter(eol: '\r\n').convert(rows);
  }

  /// Format 3: Notion Database JSON Schema.
  /// Formatted as Notion properties for 1-click database imports.
  static Map<String, dynamic> generateNotionJson({List<ExportRankingItem>? items}) {
    final list = items ?? [];
    return {
      'schema': 'https://api.notion.com/v1',
      'database_title': 'Telly Rankings',
      'items': list.map((item) {
        return {
          'properties': {
            'Title': {
              'title': [
                {'text': {'content': item.title}}
              ]
            },
            'Rank': {'number': item.rank},
            'Score': {'number': item.score},
            'Status': {
              'select': {'name': item.status}
            },
            'Tier': {
              'select': {'name': item.tier}
            },
            'MVP': {
              'rich_text': [
                {'text': {'content': item.mvpActor ?? ''}}
              ]
            },
            'Tags': {
              'multi_select': item.tags.map((t) => {'name': t}).toList()
            },
            'Date': {'date': {'start': item.dateLogged}},
          }
        };
      }).toList(),
    };
  }

  /// Notion-compatible Markdown Table format.
  static String generateNotionMarkdown({List<ExportRankingItem>? items}) {
    final list = items ?? [];
    final buffer = StringBuffer();
    buffer.writeln('# Telly Rankings');
    buffer.writeln('| Rank | Title | Score | Tier | Status | MVP | Date Logged |');
    buffer.writeln('| :--- | :--- | :--- | :--- | :--- | :--- | :--- |');

    for (final item in list) {
      final rankStr = item.rank != null ? '#${item.rank}' : '-';
      final scoreStr = item.score != null ? item.score!.toStringAsFixed(2) : '-';
      final mvpStr = item.mvpActor ?? '-';
      buffer.writeln(
        '| $rankStr | ${item.title} | $scoreStr | ${item.tier} | ${item.status} | $mvpStr | ${item.dateLogged} |',
      );
    }

    return buffer.toString();
  }

  /// Format 4: AniList & MyAnimeList compatible JSON export.
  static Map<String, dynamic> generateAniListJson({List<ExportRankingItem>? items}) {
    final list = items ?? [];
    return {
      'source': 'Telly App',
      'exported_at': DateTime.now().toIso8601String(),
      'entries': list.map((item) {
        return {
          'media_id': item.tmdbId,
          'title': item.title,
          'media_type': item.mediaType,
          'score': item.score,
          'status': item.status,
          'tags': item.tags,
          'date_logged': item.dateLogged,
        };
      }).toList(),
    };
  }
}
