import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/onboarding/domain/letterboxd_csv_parser.dart';
import 'package:telly_app/features/ranking/domain/sentiment_bracket.dart';

void main() {
  group('Letterboxd CSV Parser Unit Tests (FE-111, QA-102)', () {
    const sampleCsv = '''Date,Name,Year,Letterboxd URI,Rating,Rewatch,Tags,Watched Date
2024-03-01,Dune: Part Two,2024,https://boxd.it/mYqO,5.0,,imax,2024-03-01
2023-07-21,Oppenheimer,2023,https://boxd.it/t2S4,4.5,,70mm,2023-07-21
2022-04-10,"Everything Everywhere All at Once",2022,https://boxd.it/kEaw,4.0,Yes,,2022-04-10
2019-10-11,Parasite,2019,https://boxd.it/hMC2,4.5,Yes,,2019-10-11
2023-10-20,Killers of the Flower Moon,2023,https://boxd.it/p1yO,3.5,,,2023-10-20
2023-06-15,The Flash,2023,https://boxd.it/70hS,2.0,,,2023-06-15
2021-01-15,The Room,2003,https://boxd.it/1uHQ,0.5,,,2021-01-15
2024-05-12,Challengers,2024,https://boxd.it/w9q2,,,theaters,2024-05-12
''';

    test('parses diary.csv rows into structured LetterboxdEntry list', () {
      final entries = LetterboxdCsvParser.parse(sampleCsv);

      expect(entries, hasLength(8));

      final dune = entries[0];
      expect(dune.title, equals('Dune: Part Two'));
      expect(dune.releaseYear, equals(2024));
      expect(dune.rating, equals(5.0));
      expect(dune.isRewatch, isFalse);
      expect(dune.tags, contains('imax'));
      expect(dune.letterboxdUri, equals('https://boxd.it/mYqO'));
    });

    test('properly parses titles containing commas inside quotes', () {
      final entries = LetterboxdCsvParser.parse(sampleCsv);
      final eeaao = entries[2];

      expect(eeaao.title, equals('Everything Everywhere All at Once'));
      expect(eeaao.releaseYear, equals(2022));
      expect(eeaao.rating, equals(4.0));
      expect(eeaao.isRewatch, isTrue);
    });

    test('maps star ratings accurately to SentimentBrackets', () {
      final entries = LetterboxdCsvParser.parse(sampleCsv);

      // 5.0 -> masterpiece
      expect(entries[0].sentimentBracket, equals(SentimentBracket.masterpiece));
      // 4.5 -> masterpiece
      expect(entries[1].sentimentBracket, equals(SentimentBracket.masterpiece));
      // 4.0 -> loved
      expect(entries[2].sentimentBracket, equals(SentimentBracket.loved));
      // 4.5 -> masterpiece
      expect(entries[3].sentimentBracket, equals(SentimentBracket.masterpiece));
      // 3.5 -> liked
      expect(entries[4].sentimentBracket, equals(SentimentBracket.liked));
      // 2.0 -> meh
      expect(entries[5].sentimentBracket, equals(SentimentBracket.meh));
      // 0.5 -> regret
      expect(entries[6].sentimentBracket, equals(SentimentBracket.regret));
      // Unrated -> liked (neutral default)
      expect(entries[7].sentimentBracket, equals(SentimentBracket.liked));
    });

    test('handles resilient edge cases: empty strings, missing years, Windows CRLF line endings', () {
      const edgeCsv = "Date,Name,Year,Letterboxd URI,Rating,Rewatch\r\n"
          "2024-01-01,Unknown Movie,,https://boxd.it/123,,No\r\n"
          "\r\n"
          "2024-01-02,\"Film with \"\"Escaped Quotes\"\"\",1999,,4.0,1\r\n";

      final entries = LetterboxdCsvParser.parse(edgeCsv);
      expect(entries, hasLength(2));
      expect(entries[0].title, equals('Unknown Movie'));
      expect(entries[0].releaseYear, isNull);
      expect(entries[0].rating, isNull);

      expect(entries[1].title, equals('Film with "Escaped Quotes"'));
      expect(entries[1].releaseYear, equals(1999));
      expect(entries[1].isRewatch, isTrue);
    });

    test('performance benchmark: 500 rows parsed in under 300ms', () {
      final buffer = StringBuffer();
      buffer.writeln('Date,Name,Year,Letterboxd URI,Rating,Rewatch,Tags,Watched Date');
      for (int i = 0; i < 500; i++) {
        buffer.writeln('2024-01-01,"Movie Title $i, Special Edition",2020,https://boxd.it/$i,4.5,Yes,theater,2024-01-01');
      }

      final stopwatch = Stopwatch()..start();
      final entries = LetterboxdCsvParser.parse(buffer.toString());
      stopwatch.stop();

      expect(entries, hasLength(500));
      expect(stopwatch.elapsedMilliseconds, lessThan(300));
    });

    test('returns empty list when input is empty or lacks required Name column', () {
      expect(LetterboxdCsvParser.parse(''), isEmpty);
      expect(LetterboxdCsvParser.parse('   \n\r  '), isEmpty);
      expect(LetterboxdCsvParser.parse('Date,Year,Rating\n2024,2024,4.5'), isEmpty);
    });
  });
}
