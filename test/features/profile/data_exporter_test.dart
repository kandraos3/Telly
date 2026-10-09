import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/profile/domain/data_exporter.dart';

void main() {
  group('DataExporter Unit Tests (FE-506)', () {
    final sampleItems = [
      const ExportRankingItem(
        title: 'Succession',
        tmdbId: 76331,
        rank: 1,
        score: 10.0,
        status: 'COMPLETED',
        tier: 'God Tier',
        review: 'Flawless finale',
        mvpActor: 'Jeremy Strong',
        tags: ['FlawlessFinale', 'PeakDialogue'],
        dateLogged: '2024-05-12',
        year: 2018,
        mediaType: 'tv',
      ),
      const ExportRankingItem(
        title: 'Severance',
        tmdbId: 110492,
        rank: 2,
        score: 9.72,
        status: 'COMPLETED',
        tier: 'God Tier',
        review: 'Elevator sequence peak',
        mvpActor: 'Adam Scott',
        tags: ['MindBending'],
        dateLogged: '2024-06-20',
        year: 2022,
        mediaType: 'tv',
      ),
      const ExportRankingItem(
        title: 'Westworld, "Delos"',
        tmdbId: 63247,
        rank: null,
        score: null,
        status: 'DROPPED',
        tier: 'Graveyard',
        review: 'Lost mystery in S3',
        mvpActor: 'Jeffrey Wright',
        tags: ['PacingSlowedDown'],
        dateLogged: '2023-11-04',
        year: 2016,
        mediaType: 'tv',
      ),
    ];

    test('generateCanonCsv exports RFC 4180 compliant CSV', () {
      final csv = DataExporter.generateCanonCsv(sampleRankings: sampleItems);
      expect(csv, isNotEmpty);

      // Verify header row
      expect(csv, contains('title,tmdb_id,rank,score,status,tier,review,mvp_actor,tags,date_logged'));

      // Verify row 1 content
      expect(csv, contains('Succession,76331,1,10.00,COMPLETED,God Tier,Flawless finale,Jeremy Strong,FlawlessFinale;PeakDialogue,2024-05-12'));

      // Verify RFC 4180 escaping on comma/quotes
      expect(csv, contains('"Westworld, ""Delos"""'));
    });

    test('generateLetterboxdCsv formats according to Letterboxd specs', () {
      final csv = DataExporter.generateLetterboxdCsv(items: sampleItems);
      expect(csv, isNotEmpty);
      expect(csv, contains('Title,Year,Rating10,WatchedDate,Review,Tags'));
      expect(csv, contains('Succession,2018,10.0,2024-05-12,Flawless finale,"FlawlessFinale, PeakDialogue"'));
    });

    test('generateNotionJson formats Notion database schema correctly', () {
      final json = DataExporter.generateNotionJson(items: sampleItems);
      expect(json['database_title'], equals('Telly Rankings'));
      final items = json['items'] as List;
      expect(items.length, equals(3));

      final firstProps = items.first['properties'] as Map<String, dynamic>;
      expect(firstProps['Title']['title'][0]['text']['content'], equals('Succession'));
      expect(firstProps['Rank']['number'], equals(1));
      expect(firstProps['Score']['number'], equals(10.0));
      expect(firstProps['Tier']['select']['name'], equals('God Tier'));
    });

    test('generateNotionMarkdown outputs valid markdown table', () {
      final md = DataExporter.generateNotionMarkdown(items: sampleItems);
      expect(md, contains('# Telly Rankings'));
      expect(md, contains('| Rank | Title | Score | Tier | Status | MVP | Date Logged |'));
      expect(md, contains('| #1 | Succession | 10.00 | God Tier | COMPLETED | Jeremy Strong | 2024-05-12 |'));
      expect(md, contains('| - | Westworld, "Delos" | - | Graveyard | DROPPED | Jeffrey Wright | 2023-11-04 |'));
    });

    test('generateAniListJson outputs structured JSON with media IDs and status', () {
      final aniList = DataExporter.generateAniListJson(items: sampleItems);
      expect(aniList['source'], equals('Telly App'));
      final entries = aniList['entries'] as List;
      expect(entries.length, equals(3));
      expect(entries[0]['media_id'], equals(76331));
      expect(entries[0]['title'], equals('Succession'));
    });
  });
}

