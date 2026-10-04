import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/ranking/domain/franchise_rollup_service.dart';

CanonEntry aot(int id, int rank, double score, {int? season}) => CanonEntry(
      id: id,
      title: season == null ? 'Attack on Titan' : 'Attack on Titan Season $season',
      mediaType: 'tv',
      rankPosition: rank,
      calculatedScore: score,
      isAnime: true,
      franchiseId: 'attack-on-titan',
      franchiseName: 'Attack on Titan',
      seasonNumber: season,
    );

const succession = CanonEntry(id: 100, title: 'Succession', mediaType: 'tv', rankPosition: 1, calculatedScore: 10.0);
const severance = CanonEntry(id: 101, title: 'Severance', mediaType: 'tv', rankPosition: 4, calculatedScore: 9.31);

void main() {
  group('ALGO-602: franchise rollup via primary series duel (features/08 §4, D6)', () {
    // Raw series canon, contiguous 1..7.
    final canon = [
      succession,
      aot(3, 2, 9.85, season: 3),
      aot(1, 3, 9.68), // primary series entry the user dueled
      severance,
      aot(10, 5, 9.12, season: 1),
      aot(2, 6, 8.90, season: 2),
      aot(4, 7, 8.65, season: 4),
    ];

    test('4 seasons + primary → one entry with the primary rank/score and 4 breakdown rows', () {
      final rolled = FranchiseRollupService.rollupFranchises(canon);

      expect(rolled.map((e) => e.title), ['Succession', 'Attack on Titan', 'Severance']);
      final franchise = rolled[1];
      expect(franchise.isRolledUp, isTrue);
      expect(franchise.id, 1);
      expect(franchise.rankPosition, 3);
      expect(franchise.calculatedScore, 9.68); // never averaged (mean would be 9.24)
      expect(franchise.seasonBreakdown.map((s) => s.seasonNumber), [1, 2, 3, 4]);
      expect(franchise.seasonBreakdown.map((s) => s.calculatedScore), [9.12, 8.90, 9.85, 8.65]);
      // Other entries keep their canon positions.
      expect(rolled.map((e) => e.rankPosition), [1, 3, 4]);
    });

    test('without a primary ranking the highest-ranked season represents the franchise', () {
      final seasonsOnly = canon.where((e) => e.id != 1).toList();
      final franchise = FranchiseRollupService.rollupFranchises(seasonsOnly).singleWhere((e) => e.isRolledUp);
      expect(franchise.id, 3);
      expect(franchise.rankPosition, 2);
      expect(franchise.calculatedScore, 9.85);
      expect(franchise.title, 'Attack on Titan');
      expect(franchise.seasonBreakdown, hasLength(4));
    });

    test('the unbundled (raw) canon is unchanged by rolling up', () {
      final before = canon.map((e) => (e.id, e.rankPosition, e.calculatedScore, e.isRolledUp)).toList();
      FranchiseRollupService.rollupFranchises(canon);
      expect(canon.map((e) => (e.id, e.rankPosition, e.calculatedScore, e.isRolledUp)).toList(), before);
    });

    test('a franchise with a single ranked entry is not wrapped', () {
      final rolled = FranchiseRollupService.rollupFranchises([succession, aot(1, 2, 9.68)]);
      expect(rolled.every((e) => !e.isRolledUp), isTrue);
      expect(rolled, hasLength(2));
    });

    test('empty input', () {
      expect(FranchiseRollupService.rollupFranchises([]), isEmpty);
    });
  });
}
