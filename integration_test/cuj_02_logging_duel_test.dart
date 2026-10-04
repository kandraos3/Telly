import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/features/ranking/data/ranking_repository.dart';
import 'package:telly_app/features/ranking/domain/binary_insertion_tournament.dart';
import 'package:telly_app/features/ranking/domain/sentiment_bracket.dart';

import '../test/helpers/canon_seed.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CUJ-02: Complete Movie Logging & Slot Insertion (E2E Integration)', (tester) async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);

    // 1. Seed existing 25-movie canon
    final existingTitles = List.generate(25, (i) => 'Film #${i + 1}');
    await seedCanon(db, 'movie', existingTitles, baseId: 100);

    final repo = RankingRepository(db);
    final canonBefore = await repo.getCanon('movie');
    expect(canonBefore, hasLength(25));

    // 2. Candidate movie "Dune: Part Two" selected with Masterpiece bracket
    const candidateTitle = 'Dune: Part Two';
    const candidateId = 693134;

    var tournament = BinaryInsertionTournament<String>(
      existingCanon: existingTitles,
      candidate: candidateTitle,
      seedBracket: SentimentBracket.masterpiece,
    );

    int duelCount = 0;
    while (!tournament.isComplete) {
      duelCount++;
      // Candidate wins all duels in Masterpiece bracket
      tournament = tournament.onCandidateWins();
    }

    // Logarithmic comparisons bounded by ceil(log2(searchRange)) <= 4
    expect(duelCount, lessThanOrEqualTo(4));
    expect(tournament.insertionIndex, equals(0)); // Wins and places at #1

    // 3. Commit placement to Drift SQLite with editorial tagging
    final outcome = await repo.commitPlacement(
      candidate: const CanonCandidate(titleId: candidateId, mediaType: 'movie', title: candidateTitle),
      targetRank: 1,
      bracket: SentimentBracket.masterpiece.name,
      duels: const [
        LoggedDuel(winnerTitleId: candidateId, loserTitleId: 100),
      ],
    );

    expect(outcome.mutationId, isNotEmpty);
    expect(outcome.rank, equals(1));
    expect(outcome.score, equals(10.00));

    // 4. Verify canon was updated and all ranks/scores shifted
    final canonAfter = await repo.getCanon('movie');
    expect(canonAfter, hasLength(26));
    expect(canonAfter.first.title, equals(candidateTitle));
    expect(canonAfter.first.rankPosition, equals(1));
    expect(canonAfter.first.calculatedScore, equals(10.00));
    expect(canonAfter[1].title, equals('Film #1'));
    expect(canonAfter[1].rankPosition, equals(2));
    expect(canonAfter[1].calculatedScore, lessThan(10.00));

    // 5. Verify pending mutation enqueued for server sync
    final pendingCount = await db.pendingMutationDao.count();
    expect(pendingCount, equals(1));
  });
}
