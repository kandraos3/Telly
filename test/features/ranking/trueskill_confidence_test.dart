import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/ranking/domain/trueskill_confidence.dart';

void main() {
  group('ALGO-203: TrueSkillConfidence Domain Logic & State Transitions', () {
    test('Initial title starts in provisional state with sigma = 1.20', () {
      final confidence = TrueSkillConfidence.initial();

      expect(confidence.sigma, equals(1.20));
      expect(confidence.duelsCompleted, equals(0));
      expect(confidence.status, equals(RankingConfidenceStatus.provisional));
      expect(confidence.isProvisional, isTrue);
      expect(confidence.isLocked, isFalse);
      expect(confidence.confidencePercentage, equals(0));
    });

    test('4 consecutive duels decay sigma to < 0.50 and transition status to locked', () {
      var confidence = TrueSkillConfidence.initial();

      // Duel 1: 1.20 * 0.75 = 0.90
      confidence = confidence.recordDuel();
      expect(confidence.sigma, closeTo(0.90, 0.001));
      expect(confidence.duelsCompleted, equals(1));
      expect(confidence.status, equals(RankingConfidenceStatus.provisional));

      // Duel 2: 0.90 * 0.75 = 0.675
      confidence = confidence.recordDuel();
      expect(confidence.sigma, closeTo(0.675, 0.001));
      expect(confidence.duelsCompleted, equals(2));
      expect(confidence.status, equals(RankingConfidenceStatus.provisional));

      // Duel 3: 0.675 * 0.75 = 0.5063 (still >= 0.50)
      confidence = confidence.recordDuel();
      expect(confidence.sigma, closeTo(0.5063, 0.001));
      expect(confidence.duelsCompleted, equals(3));
      expect(confidence.status, equals(RankingConfidenceStatus.provisional));
      expect(confidence.isLocked, isFalse);

      // Duel 4: 0.50625 * 0.75 ≈ 0.3797 (< 0.50 -> Locked!)
      confidence = confidence.recordDuel();
      expect(confidence.sigma, closeTo(0.3797, 0.001));
      expect(confidence.duelsCompleted, equals(4));
      expect(confidence.status, equals(RankingConfidenceStatus.locked));
      expect(confidence.isLocked, isTrue);
      expect(confidence.isProvisional, isFalse);
    });

    test('Multiple duels adhere to minimum uncertainty floor of 0.15', () {
      var confidence = TrueSkillConfidence.initial();

      // Run 20 duels
      for (int i = 0; i < 20; i++) {
        confidence = confidence.recordDuel();
      }

      expect(confidence.sigma, equals(0.15));
      expect(confidence.status, equals(RankingConfidenceStatus.locked));
      expect(confidence.confidencePercentage, equals(100));
    });

    test('First title logged in empty canon initializes at boundary sigma = 0.50', () {
      final firstTitle = TrueSkillConfidence.firstTitle();

      expect(firstTitle.sigma, equals(0.50));
      expect(firstTitle.duelsCompleted, equals(0));
      expect(firstTitle.status, equals(RankingConfidenceStatus.provisional));

      // Just 1 duel transitions it to locked (0.50 * 0.75 = 0.375)
      final afterOneDuel = firstTitle.recordDuel();
      expect(afterOneDuel.isLocked, isTrue);
    });

    test('reset() restores initial uncertainty and provisional status', () {
      var confidence = TrueSkillConfidence.initial();
      confidence = confidence.recordDuel();
      confidence = confidence.recordDuel();
      confidence = confidence.recordDuel();
      confidence = confidence.recordDuel(); // locked

      expect(confidence.isLocked, isTrue);

      final resetConfidence = confidence.reset();
      expect(resetConfidence.sigma, equals(1.20));
      expect(resetConfidence.duelsCompleted, equals(0));
      expect(resetConfidence.isProvisional, isTrue);
    });

    test('UI helpers provide formatted values without errors', () {
      final provisional = TrueSkillConfidence.initial();
      expect(provisional.displayMarginOfError, equals('±0.4'));

      const locked = TrueSkillConfidence(sigma: 0.20, duelsCompleted: 8);
      expect(locked.displayMarginOfError, equals('±0.1'));
      expect(locked.confidencePercentage, greaterThan(90));
    });
  });
}
