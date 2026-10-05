import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/ranking/domain/binary_insertion_tournament.dart';
import 'package:telly_app/features/ranking/domain/sentiment_bracket.dart';

void main() {
  group('ALGO-201 / QA-201: BinaryInsertionTournament Invariants', () {
    test('N=0: Empty canon inserts candidate immediately at rank 1 with 0 comparisons', () {
      final tournament = BinaryInsertionTournament<String>(
        existingCanon: const [],
        candidate: 'Severance',
      );

      expect(tournament.isComplete, isTrue);
      expect(tournament.insertionIndex, equals(0));
      expect(tournament.finalRank, equals(1));
      expect(tournament.currentOpponent, isNull);
      expect(tournament.roundNumber, equals(0));
      expect(tournament.totalEstimatedRounds, equals(0));
      expect(tournament.updatedCanon, equals(['Severance']));
    });

    test('N=1: Single-item canon requires exactly 1 comparison', () {
      final existing = ['Succession'];

      // Candidate wins -> rank 1
      var t1 = BinaryInsertionTournament<String>(
        existingCanon: existing,
        candidate: 'The Bear',
      );
      expect(t1.isComplete, isFalse);
      expect(t1.currentOpponent, equals('Succession'));
      expect(t1.roundNumber, equals(1));
      expect(t1.totalEstimatedRounds, equals(1));

      t1 = t1.onCandidateWins();
      expect(t1.isComplete, isTrue);
      expect(t1.insertionIndex, equals(0));
      expect(t1.finalRank, equals(1));
      expect(t1.updatedCanon, equals(['The Bear', 'Succession']));

      // Opponent wins -> rank 2
      var t2 = BinaryInsertionTournament<String>(
        existingCanon: existing,
        candidate: 'The Bear',
      );
      t2 = t2.onOpponentWins();
      expect(t2.isComplete, isTrue);
      expect(t2.insertionIndex, equals(1));
      expect(t2.finalRank, equals(2));
      expect(t2.updatedCanon, equals(['Succession', 'The Bear']));
    });

    test('N=2: Can insert into head, middle, or tail', () {
      final existing = ['Rank 1', 'Rank 2'];

      // Target head (beats Rank 1)
      var tHead = BinaryInsertionTournament<String>(
        existingCanon: existing,
        candidate: 'New Top',
      );
      expect(tHead.currentComparisonIndex, equals(0));
      tHead = tHead.onCandidateWins();
      expect(tHead.isComplete, isTrue);
      expect(tHead.insertionIndex, equals(0));
      expect(tHead.finalRank, equals(1));

      // Target tail (loses to Rank 1, loses to Rank 2)
      var tTail = BinaryInsertionTournament<String>(
        existingCanon: existing,
        candidate: 'New Bottom',
      );
      tTail = tTail.onOpponentWins(); // loses to index 0
      expect(tTail.isComplete, isFalse);
      expect(tTail.currentComparisonIndex, equals(1));
      tTail = tTail.onOpponentWins(); // loses to index 1
      expect(tTail.isComplete, isTrue);
      expect(tTail.insertionIndex, equals(2));
      expect(tTail.finalRank, equals(3));

      // Target middle (loses to Rank 1, beats Rank 2)
      var tMid = BinaryInsertionTournament<String>(
        existingCanon: existing,
        candidate: 'New Mid',
      );
      tMid = tMid.onOpponentWins(); // loses to index 0
      tMid = tMid.onCandidateWins(); // beats index 1
      expect(tMid.isComplete, isTrue);
      expect(tMid.insertionIndex, equals(1));
      expect(tMid.finalRank, equals(2));
      expect(tMid.updatedCanon, equals(['Rank 1', 'New Mid', 'Rank 2']));
    });

    test('N=100: Exhaustive verification across all 101 target slots', () {
      // Create a sorted list of 100 integer scores: [1000, 990, 980, ..., 10]
      // index 0 is 1000 (highest), index 99 is 10 (lowest)
      final existingScores = List.generate(100, (i) => (100 - i) * 10);

      // Verify inserting a candidate targeting every possible final slot: 0 to 100
      for (int targetSlot = 0; targetSlot <= 100; targetSlot++) {
        // Assign candidate a score strictly between existingScores[targetSlot - 1] and existingScores[targetSlot]
        final double candidateScore;
        if (targetSlot == 0) {
          candidateScore = existingScores.first + 5.0; // higher than top
        } else if (targetSlot == 100) {
          candidateScore = existingScores.last - 5.0; // lower than bottom
        } else {
          candidateScore = existingScores[targetSlot] + 5.0; // between targetSlot-1 and targetSlot
        }

        var tournament = BinaryInsertionTournament<int>(
          existingCanon: existingScores,
          candidate: candidateScore.toInt(),
        );

        int comparisons = 0;
        while (!tournament.isComplete) {
          comparisons++;
          final opponentScore = tournament.currentOpponent!;
          if (candidateScore > opponentScore) {
            tournament = tournament.onCandidateWins();
          } else {
            tournament = tournament.onOpponentWins();
          }
        }

        // Must terminate in <= ceil(log2(101)) = 7 comparisons
        expect(comparisons, lessThanOrEqualTo(7), reason: 'Target slot $targetSlot exceeded 7 comparisons');
        expect(tournament.insertionIndex, equals(targetSlot),
            reason: 'Target slot $targetSlot resolved to incorrect index ${tournament.insertionIndex}');
        expect(tournament.finalRank, equals(targetSlot + 1));
      }
    });

    test('Sentiment bracket seeding narrows search space and comparison count', () {
      final existing = List.generate(100, (i) => 'Show #$i');

      // Masterpiece: bounds [0, 10] -> max comparisons <= 4
      final tMasterpiece = BinaryInsertionTournament<String>(
        existingCanon: existing,
        candidate: 'New Masterpiece',
        seedBracket: SentimentBracket.masterpiece,
      );
      expect(tMasterpiece.low, equals(0));
      expect(tMasterpiece.high, equals(10));
      expect(tMasterpiece.totalEstimatedRounds, lessThanOrEqualTo(4));

      // Loved: bounds [10, 35] -> max comparisons <= 5
      final tLoved = BinaryInsertionTournament<String>(
        existingCanon: existing,
        candidate: 'New Favorite',
        seedBracket: SentimentBracket.loved,
      );
      expect(tLoved.low, equals(10));
      expect(tLoved.high, equals(35));
      expect(tLoved.totalEstimatedRounds, lessThanOrEqualTo(5));

      // Liked: bounds [35, 75] -> max comparisons <= 6
      final tLiked = BinaryInsertionTournament<String>(
        existingCanon: existing,
        candidate: 'Decent Show',
        seedBracket: SentimentBracket.liked,
      );
      expect(tLiked.low, equals(35));
      expect(tLiked.high, equals(75));
      expect(tLiked.totalEstimatedRounds, lessThanOrEqualTo(6));

      // Meh: bounds [75, 95] -> max comparisons <= 5
      final tMeh = BinaryInsertionTournament<String>(
        existingCanon: existing,
        candidate: 'Average Show',
        seedBracket: SentimentBracket.meh,
      );
      expect(tMeh.low, equals(75));
      expect(tMeh.high, equals(95));
      expect(tMeh.totalEstimatedRounds, lessThanOrEqualTo(5));

      // Regret: bounds [95, 99] -> max comparisons <= 3
      final tRegret = BinaryInsertionTournament<String>(
        existingCanon: existing,
        candidate: 'Bin Show',
        seedBracket: SentimentBracket.regret,
      );
      expect(tRegret.low, equals(95));
      expect(tRegret.high, equals(99));
      expect(tRegret.totalEstimatedRounds, lessThanOrEqualTo(3));
    });

    test('Tie handling: "Can\'t Compare" steps to neighbor and resolves adjacent on repeat tie', () {
      final existing = ['Show A', 'Show B', 'Show C', 'Show D', 'Show E'];

      var t = BinaryInsertionTournament<String>(
        existingCanon: existing,
        candidate: 'Unusual Art Film',
      );
      expect(t.currentComparisonIndex, equals(2)); // Midpoint 'Show C'

      // First tie: steps to neighbor
      t = t.onTieOrCantCompare();
      expect(t.isComplete, isFalse);
      expect(t.currentComparisonIndex, equals(3)); // Neighbor 'Show D'

      // Second consecutive tie: resolves adjacent to original mid
      t = t.onTieOrCantCompare();
      expect(t.isComplete, isTrue);
      expect(t.insertionIndex, equals(3)); // Adjacent to Show C (index 2 + 1)
      expect(t.updatedCanon, equals(['Show A', 'Show B', 'Show C', 'Unusual Art Film', 'Show D', 'Show E']));
    });

    test('Single-element tie terminates immediately without stepping out of bounds', () {
      final existing = ['Only Show'];

      var t = BinaryInsertionTournament<String>(
        existingCanon: existing,
        candidate: 'Tied Show',
      );

      t = t.onTieOrCantCompare();
      expect(t.isComplete, isTrue);
      expect(t.insertionIndex, equals(1));
    });

    test('updatedCanon throws StateError if accessed before tournament completion', () {
      final t = BinaryInsertionTournament<String>(
        existingCanon: ['Show 1', 'Show 2'],
        candidate: 'In Progress Show',
      );

      expect(() => t.updatedCanon, throwsStateError);
    });
  });

  group('FE-ALGO-01: minimum verification duels', () {
    /// Plays a tournament where the candidate truly belongs at [slot] of a canon of size [n].
    (int index, int duels, List<int> faced) play(int n, int slot, SentimentBracket? bracket) {
      final canon = List.generate(n, (i) => i); // index i = rank i + 1
      var t = BinaryInsertionTournament<int>(existingCanon: canon, candidate: -1, seedBracket: bracket);
      final faced = <int>[];
      while (!t.isComplete) {
        final opponent = t.currentOpponent!;
        faced.add(opponent);
        t = slot <= opponent ? t.onCandidateWins() : t.onOpponentWins();
        expect(faced.length, lessThan(n + 2), reason: 'must terminate');
      }
      return (t.insertionIndex!, faced.length, faced);
    }

    test('every bracket finds the true slot, even outside its window, for every canon size', () {
      for (final bracket in [null, ...SentimentBracket.values]) {
        for (final n in [1, 2, 3, 4, 5, 7, 10, 20, 37, 100]) {
          for (var slot = 0; slot <= n; slot++) {
            final (index, _, _) = play(n, slot, bracket);
            expect(index, slot, reason: '$bracket n=$n slot=$slot');
          }
        }
      }
    });

    test('with 3+ titles no placement rests on a single duel, top and bottom included', () {
      for (final bracket in [null, ...SentimentBracket.values]) {
        for (final n in [3, 4, 5, 10, 20, 100]) {
          for (var slot = 0; slot <= n; slot++) {
            final (_, duels, _) = play(n, slot, bracket);
            expect(duels, greaterThanOrEqualTo(2), reason: '$bracket n=$n slot=$slot');
          }
        }
      }
    });

    test('a Masterpiece #1 in a 5-title canon faces both of the top two titles', () {
      final (index, duels, faced) = play(5, 0, SentimentBracket.masterpiece);
      expect(index, 0);
      expect(duels, 2);
      expect(faced.toSet(), {0, 1});
    });

    test('a window-edge placement duels the adjacent title just outside the window', () {
      // Loved in a 100-title canon searches [10, 35]; a candidate that truly ranks 11th
      // must still be checked against #10 (index 9) before committing.
      final (index, _, faced) = play(100, 10, SentimentBracket.loved);
      expect(index, 10);
      expect(faced.last, 9);
    });

    test('Regret with a bottom-of-canon result is verified against the last two titles', () {
      final (index, duels, faced) = play(10, 10, SentimentBracket.regret);
      expect(index, 10);
      expect(duels, greaterThanOrEqualTo(2));
      expect(faced, containsAll([8, 9]));
    });

    test('the progress estimate never falls behind the round counter', () {
      final canon = List.generate(100, (i) => i);
      var t = BinaryInsertionTournament<int>(
          existingCanon: canon, candidate: -1, seedBracket: SentimentBracket.masterpiece);
      while (!t.isComplete) {
        expect(t.totalEstimatedRounds, greaterThanOrEqualTo(t.roundNumber));
        t = 60 <= t.currentOpponent! ? t.onCandidateWins() : t.onOpponentWins(); // truly ranks 61st
      }
      expect(t.insertionIndex, 60);
    });
  });
}
