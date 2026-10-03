import 'sentiment_bracket.dart';

/// A pure domain state machine representing a pairwise binary insertion sort tournament.
///
/// Implements logarithmic bounds ($\mathcal{O}(\log_2 N)$) to determine the exact rank slot
/// of a new [candidate] within an existing sorted [existingCanon] list.
///
/// Conforms to:
/// - `docs/features/02_PAIRWISE_RANKING_ENGINE_AND_LOGGING.md` §3.1
/// - `docs/technical_architecture/04_CLIENT_ARCHITECTURE_AND_OFFLINE_SYNC.md` §2
/// - `docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md` §2.1
class BinaryInsertionTournament<T> {
  final List<T> existingCanon;
  final T candidate;
  final SentimentBracket? seedBracket;
  final int low;
  final int high;
  final int currentComparisonIndex;
  final int roundNumber;
  final int totalEstimatedRounds;
  final bool isComplete;
  final int? insertionIndex;
  final int? _tiedNeighborIndex;
  final int? _originalMidBeforeTie;

  const BinaryInsertionTournament._({
    required this.existingCanon,
    required this.candidate,
    required this.seedBracket,
    required this.low,
    required this.high,
    required this.currentComparisonIndex,
    required this.roundNumber,
    required this.totalEstimatedRounds,
    required this.isComplete,
    required this.insertionIndex,
    int? tiedNeighborIndex,
    int? originalMidBeforeTie,
  })  : _tiedNeighborIndex = tiedNeighborIndex,
        _originalMidBeforeTie = originalMidBeforeTie;

  /// Factory constructor to initialize a tournament for inserting [candidate] into [existingCanon].
  factory BinaryInsertionTournament({
    required List<T> existingCanon,
    required T candidate,
    SentimentBracket? seedBracket,
  }) {
    final n = existingCanon.length;

    // Edge case 1: Empty canon -> candidate is rank 1 immediately with 0 comparisons.
    if (n == 0) {
      return BinaryInsertionTournament._(
        existingCanon: existingCanon,
        candidate: candidate,
        seedBracket: seedBracket,
        low: 0,
        high: -1,
        currentComparisonIndex: 0,
        roundNumber: 0,
        totalEstimatedRounds: 0,
        isComplete: true,
        insertionIndex: 0,
      );
    }

    // Determine initial binary bounds based on optional sentiment bracket seeding.
    int initialLow = 0;
    int initialHigh = n - 1;

    if (seedBracket != null) {
      final bounds = _calculateBracketBounds(n, seedBracket);
      initialLow = bounds.$1;
      initialHigh = bounds.$2;
    }

    final initialMid = (initialLow + initialHigh) ~/ 2;
    final totalEstimated = _calculateMaxComparisons(initialHigh - initialLow + 1);

    return BinaryInsertionTournament._(
      existingCanon: existingCanon,
      candidate: candidate,
      seedBracket: seedBracket,
      low: initialLow,
      high: initialHigh,
      currentComparisonIndex: initialMid,
      roundNumber: 1,
      totalEstimatedRounds: totalEstimated,
      isComplete: false,
      insertionIndex: null,
    );
  }

  /// The opponent title at the current comparison midpoint.
  /// Returns null if the tournament is already complete.
  T? get currentOpponent =>
      isComplete ? null : existingCanon[currentComparisonIndex];

  /// The 1-indexed target rank position once the tournament completes.
  /// Returns null while tournament is active.
  int? get finalRank => insertionIndex == null ? null : insertionIndex! + 1;

  /// The resulting sorted canon containing [candidate] inserted at [insertionIndex].
  List<T> get updatedCanon {
    if (!isComplete || insertionIndex == null) {
      throw StateError('Cannot retrieve updatedCanon before tournament is complete.');
    }
    final result = List<T>.from(existingCanon);
    result.insert(insertionIndex!, candidate);
    return result;
  }

  /// Calculates bracket search boundaries from sentiment bracket percentages.
  /// Conforms to `docs/features/02_PAIRWISE_RANKING_ENGINE_AND_LOGGING.md` §3.1:
  /// - Masterpiece: [0, floor(0.10 * n)]
  /// - Loved It: [floor(0.10 * n), floor(0.35 * n)]
  /// - Liked It: [floor(0.35 * n), floor(0.75 * n)]
  /// - Meh: [floor(0.75 * n), floor(0.95 * n)]
  /// - Regret: [floor(0.95 * n), n - 1]
  static (int, int) _calculateBracketBounds(int n, SentimentBracket bracket) {
    int lowBound;
    int highBound;

    switch (bracket) {
      case SentimentBracket.masterpiece:
        lowBound = 0;
        highBound = (n * 0.10).floor();
        break;
      case SentimentBracket.loved:
        lowBound = (n * 0.10).floor();
        highBound = (n * 0.35).floor();
        break;
      case SentimentBracket.liked:
        lowBound = (n * 0.35).floor();
        highBound = (n * 0.75).floor();
        break;
      case SentimentBracket.meh:
        lowBound = (n * 0.75).floor();
        highBound = (n * 0.95).floor();
        break;
      case SentimentBracket.regret:
        lowBound = (n * 0.95).floor();
        highBound = n - 1;
        break;
    }

    lowBound = lowBound.clamp(0, n - 1);
    highBound = highBound.clamp(lowBound, n - 1);
    return (lowBound, highBound);
  }

  /// Theoretical maximum comparisons: ceil(log2(rangeSize + 1))
  static int _calculateMaxComparisons(int rangeSize) {
    if (rangeSize <= 0) return 0;
    final slots = rangeSize + 1;
    var power = 1;
    var rounds = 0;
    while (power < slots) {
      power <<= 1;
      rounds++;
    }
    return rounds;
  }

  /// User votes that the [candidate] is preferred over [currentOpponent].
  ///
  /// Since index 0 is rank #1 (highest quality), candidate being better means
  /// searching higher half towards 0 (smaller indices): `high = currentComparisonIndex - 1`.
  BinaryInsertionTournament<T> onCandidateWins() {
    if (isComplete) return this;

    final baseIndex = _tiedNeighborIndex ?? currentComparisonIndex;
    final newHigh = baseIndex - 1;
    final newLow = low;

    if (newLow > newHigh) {
      return BinaryInsertionTournament._(
        existingCanon: existingCanon,
        candidate: candidate,
        seedBracket: seedBracket,
        low: newLow,
        high: newHigh,
        currentComparisonIndex: baseIndex,
        roundNumber: roundNumber,
        totalEstimatedRounds: totalEstimatedRounds,
        isComplete: true,
        insertionIndex: newLow,
      );
    }

    final nextMid = (newLow + newHigh) ~/ 2;
    return BinaryInsertionTournament._(
      existingCanon: existingCanon,
      candidate: candidate,
      seedBracket: seedBracket,
      low: newLow,
      high: newHigh,
      currentComparisonIndex: nextMid,
      roundNumber: roundNumber + 1,
      totalEstimatedRounds: totalEstimatedRounds,
      isComplete: false,
      insertionIndex: null,
    );
  }

  /// User votes that [currentOpponent] is preferred over [candidate].
  ///
  /// Since index 0 is rank #1, candidate being worse means searching lower half
  /// towards N (larger indices): `low = currentComparisonIndex + 1`.
  BinaryInsertionTournament<T> onOpponentWins() {
    if (isComplete) return this;

    final baseIndex = _tiedNeighborIndex ?? currentComparisonIndex;
    final newLow = baseIndex + 1;
    final newHigh = high;

    if (newLow > newHigh) {
      return BinaryInsertionTournament._(
        existingCanon: existingCanon,
        candidate: candidate,
        seedBracket: seedBracket,
        low: newLow,
        high: newHigh,
        currentComparisonIndex: baseIndex,
        roundNumber: roundNumber,
        totalEstimatedRounds: totalEstimatedRounds,
        isComplete: true,
        insertionIndex: newLow,
      );
    }

    final nextMid = (newLow + newHigh) ~/ 2;
    return BinaryInsertionTournament._(
      existingCanon: existingCanon,
      candidate: candidate,
      seedBracket: seedBracket,
      low: newLow,
      high: newHigh,
      currentComparisonIndex: nextMid,
      roundNumber: roundNumber + 1,
      totalEstimatedRounds: totalEstimatedRounds,
      isComplete: false,
      insertionIndex: null,
    );
  }

  /// Handles "Can't Compare / Equal / Too Different" decisions without deadlocking.
  /// Conforms to `docs/features/02_PAIRWISE_RANKING_ENGINE_AND_LOGGING.md` §3.2.
  ///
  /// Steps to +/- 1 neighbor if available; if still tied or at bounds, places candidate
  /// adjacent to current index.
  BinaryInsertionTournament<T> onTieOrCantCompare() {
    if (isComplete) return this;

    // If we already stepped to a neighbor and the user ties AGAIN, terminate immediately
    // by placing candidate adjacent to the original comparison point.
    if (_tiedNeighborIndex != null) {
      final targetSlot = (_originalMidBeforeTie! + 1).clamp(0, existingCanon.length);
      return BinaryInsertionTournament._(
        existingCanon: existingCanon,
        candidate: candidate,
        seedBracket: seedBracket,
        low: low,
        high: high,
        currentComparisonIndex: currentComparisonIndex,
        roundNumber: roundNumber,
        totalEstimatedRounds: totalEstimatedRounds,
        isComplete: true,
        insertionIndex: targetSlot,
      );
    }

    // First tie: attempt to step to an adjacent neighbor within [low, high]
    int? neighborIndex;
    if (currentComparisonIndex + 1 <= high) {
      neighborIndex = currentComparisonIndex + 1;
    } else if (currentComparisonIndex - 1 >= low) {
      neighborIndex = currentComparisonIndex - 1;
    }

    if (neighborIndex != null) {
      return BinaryInsertionTournament._(
        existingCanon: existingCanon,
        candidate: candidate,
        seedBracket: seedBracket,
        low: low,
        high: high,
        currentComparisonIndex: neighborIndex,
        roundNumber: roundNumber + 1,
        totalEstimatedRounds: totalEstimatedRounds,
        isComplete: false,
        insertionIndex: null,
        tiedNeighborIndex: neighborIndex,
        originalMidBeforeTie: currentComparisonIndex,
      );
    }

    // No neighbor exists within bounds (e.g. low == high). Terminate adjacent.
    final targetSlot = (currentComparisonIndex + 1).clamp(0, existingCanon.length);
    return BinaryInsertionTournament._(
      existingCanon: existingCanon,
      candidate: candidate,
      seedBracket: seedBracket,
      low: low,
      high: high,
      currentComparisonIndex: currentComparisonIndex,
      roundNumber: roundNumber,
      totalEstimatedRounds: totalEstimatedRounds,
      isComplete: true,
      insertionIndex: targetSlot,
    );
  }
}
