import 'package:drift/drift.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/features/ranking/domain/score_curve_calculator.dart';

/// Seeds a synced canon, `titles[0]` = #1, with curve scores. Ids are `baseId + index`.
Future<void> seedCanon(AppDatabase db, String mediaType, List<String> titles, {int baseId = 100}) {
  final n = titles.length;
  return db.localRankingDao.updateBatchRanks([
    for (var i = 0; i < n; i++)
      LocalRankingsCompanion.insert(
        showId: baseId + i,
        mediaType: mediaType,
        title: titles[i],
        rankPosition: i + 1,
        calculatedScore: ScoreCurveCalculator.calculateRoundedScore(i + 1, n),
        syncStatus: const Value('SYNCED'),
      ),
  ]);
}
