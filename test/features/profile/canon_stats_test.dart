import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/profile/domain/canon_stats.dart';
import 'package:telly_app/features/profile/presentation/widgets/canon_stats_panel.dart';

void main() {
  group('FE-PROFILE-03: CanonStats', () {
    test('parses the get_canon_stats payload', () {
      final s = CanonStats.fromJson({
        'media_type': 'movie',
        'total_titles': 4,
        'total_minutes': 650,
        'hours_estimated': false,
        'top_genre': {'name': 'Crime', 'count': 3, 'percent': 75},
        'top_creator': {'name': 'Christopher Nolan', 'count': 2, 'kind': 'director'},
      });
      expect(s.totalTitles, 4);
      expect(s.hours, 11);
      expect(s.topGenre!.name, 'Crime');
      expect(s.topGenre!.percent, 75);
      expect(s.topCreator!.count, 2);
      expect(s.creatorLabel, 'Top Director');
      expect(CanonStatsPanel.formatHours(s), '11h');
    });

    test('series hours are marked as estimates and empty leaders stay null', () {
      final s = CanonStats.fromJson({'media_type': 'tv', 'total_titles': 0, 'total_minutes': 75000});
      expect(s.hoursEstimated, isTrue);
      expect(s.topGenre, isNull);
      expect(s.topCreator, isNull);
      expect(s.creatorLabel, 'Top Network');
      expect(CanonStatsPanel.formatHours(s), '≈1,250h');
    });
  });
}
