import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/ranking/domain/upset_detector.dart';

void main() {
  group('QA-302: UpsetDetector Algorithmic Invariants', () {
    test('standard consensus pick yields isUpset = false', () {
      // Winner has 70% win rate, loser has 40% win rate
      final result = UpsetDetector.evaluateDuel(
        winnerWinRate: 0.70,
        loserWinRate: 0.40,
      );

      expect(result.isUpset, isFalse);
      expect(result.severity, equals(UpsetSeverity.none));
      expect(result.delta, lessThan(0.0));
    });

    test('borderline condition 0.249 yields isUpset = false', () {
      final result = UpsetDetector.evaluateDuel(
        winnerWinRate: 0.50,
        loserWinRate: 0.749, // delta = 0.249 < 0.250
      );

      expect(result.isUpset, isFalse);
      expect(result.severity, equals(UpsetSeverity.none));
    });

    test('borderline condition 0.250 yields isUpset = true (spicy)', () {
      final result = UpsetDetector.evaluateDuel(
        winnerWinRate: 0.50,
        loserWinRate: 0.750, // delta = 0.250 >= 0.250
      );

      expect(result.isUpset, isTrue);
      expect(result.severity, equals(UpsetSeverity.spicy));
      expect(result.delta, equals(0.25));
    });

    test('spicy upset condition (0.25 <= delta < 0.35)', () {
      final result = UpsetDetector.evaluateDuel(
        winnerWinRate: 0.40,
        loserWinRate: 0.70, // delta = 0.30
      );

      expect(result.isUpset, isTrue);
      expect(result.severity, equals(UpsetSeverity.spicy));
      expect(result.delta, equals(0.30));
    });

    test('chaos pick / taste crime condition (delta >= 0.35)', () {
      // Underdog with 20% win rate beats 80% consensus titan (delta = 0.60)
      final result = UpsetDetector.evaluateDuel(
        winnerWinRate: 0.20,
        loserWinRate: 0.80,
      );

      expect(result.isUpset, isTrue);
      expect(result.severity, equals(UpsetSeverity.chaosPick));
      expect(result.delta, equals(0.60));
    });

    test('calculateWinRate edge cases handle zero matches gracefully', () {
      expect(
        UpsetDetector.calculateWinRate(wins: 0, totalMatches: 0),
        equals(0.50), // neutral prior
      );

      expect(
        UpsetDetector.calculateWinRate(wins: 10, totalMatches: 20),
        equals(0.50),
      );

      expect(
        UpsetDetector.calculateWinRate(wins: 8, totalMatches: 10),
        equals(0.80),
      );
    });
  });
}
