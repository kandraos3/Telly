import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/ranking/domain/canon_type.dart';
import 'package:telly_app/features/ranking/domain/score_curve_calculator.dart';

class TestTitle with HasMediaType {
  final String title;
  @override
  final String mediaType;
  final double score;

  const TestTitle({
    required this.title,
    required this.mediaType,
    this.score = 10.0,
  });
}

void main() {
  group('ALGO-204: Dual-Canon Media-Type Segregation Rules', () {
    test('CanonType maps media_type strings accurately', () {
      expect(CanonType.fromMediaType('movie'), equals(CanonType.movie));
      expect(CanonType.fromMediaType('MOVIE'), equals(CanonType.movie));
      expect(CanonType.fromMediaType('tv'), equals(CanonType.series));
      expect(CanonType.fromMediaType('series'), equals(CanonType.series));
      expect(CanonType.fromMediaType('anime'), equals(CanonType.series));

      expect(() => CanonType.fromMediaType('podcast'), throwsArgumentError);
    });

    test('Cross-canon tournament pairing is strictly prohibited', () {
      const darkKnight = TestTitle(title: 'The Dark Knight', mediaType: 'movie');
      const breakingBad = TestTitle(title: 'Breaking Bad', mediaType: 'tv');
      const severance = TestTitle(title: 'Severance', mediaType: 'tv');

      // Attempting to pair a Movie with a Series Canon throws CrossCanonDuelException
      expect(
        () => DualCanonService.validateTournamentPairing(
          candidate: darkKnight,
          existingCanon: [breakingBad, severance],
        ),
        throwsA(isA<CrossCanonDuelException>()),
      );

      // Attempting to pair a Series with a Movie Canon throws CrossCanonDuelException
      const interstellar = TestTitle(title: 'Interstellar', mediaType: 'movie');
      expect(
        () => DualCanonService.validateTournamentPairing(
          candidate: breakingBad,
          existingCanon: [darkKnight, interstellar],
        ),
        throwsA(isA<CrossCanonDuelException>()),
      );
    });

    test('Valid single-medium pairings pass validation cleanly', () {
      const darkKnight = TestTitle(title: 'The Dark Knight', mediaType: 'movie');
      const interstellar = TestTitle(title: 'Interstellar', mediaType: 'movie');
      const oppenheimer = TestTitle(title: 'Oppenheimer', mediaType: 'movie');

      expect(
        () => DualCanonService.validateTournamentPairing(
          candidate: darkKnight,
          existingCanon: [interstellar, oppenheimer],
        ),
        returnsNormally,
      );

      const theBear = TestTitle(title: 'The Bear', mediaType: 'tv');
      const succession = TestTitle(title: 'Succession', mediaType: 'tv');
      expect(
        () => DualCanonService.validateTournamentPairing(
          candidate: theBear,
          existingCanon: [succession],
        ),
        returnsNormally,
      );
    });

    test('partitionByCanon accurately segregates mixed media titles', () {
      final mixed = [
        const TestTitle(title: 'Interstellar', mediaType: 'movie'),
        const TestTitle(title: 'Succession', mediaType: 'tv'),
        const TestTitle(title: 'The Dark Knight', mediaType: 'movie'),
        const TestTitle(title: 'Severance', mediaType: 'tv'),
        const TestTitle(title: 'Spirited Away', mediaType: 'movie'),
      ];

      final partitioned = DualCanonService.partitionByCanon(mixed);

      expect(partitioned.movies.length, equals(3));
      expect(partitioned.movies.map((m) => m.title),
          containsAll(['Interstellar', 'The Dark Knight', 'Spirited Away']));

      expect(partitioned.series.length, equals(2));
      expect(partitioned.series.map((s) => s.title),
          containsAll(['Succession', 'Severance']));
    });

    test('Independent score curves: Rank 1 movie and Rank 1 series both receive 10.00', () {
      final movieScore1 = ScoreCurveCalculator.calculateScore(1, 50);
      final seriesScore1 = ScoreCurveCalculator.calculateScore(1, 30);

      expect(movieScore1, equals(10.00));
      expect(seriesScore1, equals(10.00));
    });

    test('buildUnifiedMasterCanon interleaves titles strictly by descending score', () {
      final movieCanon = [
        const TestTitle(title: 'Interstellar', mediaType: 'movie', score: 10.00),
        const TestTitle(title: 'Parasite', mediaType: 'movie', score: 9.75),
        const TestTitle(title: 'Dune: Part Two', mediaType: 'movie', score: 9.30),
      ];

      final seriesCanon = [
        const TestTitle(title: 'Succession', mediaType: 'tv', score: 9.90),
        const TestTitle(title: 'The Bear', mediaType: 'tv', score: 9.50),
        const TestTitle(title: 'Fleabag', mediaType: 'tv', score: 8.90),
      ];

      final unified = DualCanonService.buildUnifiedMasterCanon(
        movieCanon: movieCanon,
        seriesCanon: seriesCanon,
        getScore: (item) => item.score,
      );

      final expectedOrder = [
        'Interstellar',   // 10.00 (movie)
        'Succession',     // 9.90 (tv)
        'Parasite',       // 9.75 (movie)
        'The Bear',       // 9.50 (tv)
        'Dune: Part Two', // 9.30 (movie)
        'Fleabag',        // 8.90 (tv)
      ];

      expect(unified.map((t) => t.title).toList(), equals(expectedOrder));
    });
  });
}
