import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/title_detail/domain/title_detail_models.dart';

void main() {
  group('FE-DETAIL-02: TitleDuelStats', () {
    test('parses the get_title_duel_stats payload', () {
      final stats = TitleDuelStats.fromJson({
        'total_duels': 3,
        'wins': 2,
        'top_defeated': {'title_id': 76331, 'title': 'Succession', 'count': 2},
        'tiers': {'god': 1, 'prestige': 0, 'great': 1, 'other': 0, 'total': 2},
      });
      expect(stats.winRatePct, 67);
      expect(stats.topDefeated!.title, 'Succession');
      expect(stats.tiers.total, 2);
    });

    test('no duels means no win rate, and a null top opponent is tolerated', () {
      final stats = TitleDuelStats.fromJson({'total_duels': 0, 'wins': 0, 'top_defeated': null, 'tiers': null});
      expect(stats.hasDuels, isFalse);
      expect(stats.winRatePct, isNull);
      expect(stats.topDefeated, isNull);
      expect(stats.tiers.percentages, isNull);
    });

    test('tier percentages always sum to 100', () {
      for (final t in const [
        TierDistribution(god: 1, prestige: 1, great: 1),
        TierDistribution(god: 2, prestige: 1, great: 1, other: 3),
        TierDistribution(other: 7),
        TierDistribution(god: 5, prestige: 3, great: 1, other: 1),
      ]) {
        expect(t.percentages!.reduce((a, b) => a + b), 100, reason: '$t');
      }
      expect(const TierDistribution(god: 1, prestige: 1, great: 1).percentages, [34, 33, 33, 0]);
    });
  });
}
