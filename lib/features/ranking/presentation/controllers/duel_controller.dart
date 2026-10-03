import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database.dart';
import '../../../../core/database/database_provider.dart';
import '../../domain/binary_insertion_tournament.dart';
import '../../domain/canon_type.dart';
import '../../domain/score_curve_calculator.dart';
import '../../domain/sentiment_bracket.dart';

/// Sealed hierarchy representing states of the pairwise duel tournament.
sealed class DuelState {
  const DuelState();
}

/// Initial state before a tournament begins.
class DuelInitial extends DuelState {
  const DuelInitial();
}

/// Active duel state presenting [candidate] against [currentOpponent].
class DuelActive extends DuelState {
  final LocalRanking candidate;
  final LocalRanking currentOpponent;
  final int step;
  final int totalEstimatedSteps;
  final BinaryInsertionTournament<LocalRanking> tournament;

  const DuelActive({
    required this.candidate,
    required this.currentOpponent,
    required this.step,
    required this.totalEstimatedSteps,
    required this.tournament,
  });
}

/// Intermediate state while computing rank shifts and batch persisting.
class DuelResolving extends DuelState {
  const DuelResolving();
}

/// Final state once exact rank slot and dynamic score are calculated and persisted.
class DuelComplete extends DuelState {
  final LocalRanking candidate;
  final int insertedIndex;
  final int finalRank;
  final double finalScore;
  final List<LocalRanking> updatedCanon;

  const DuelComplete({
    required this.candidate,
    required this.insertedIndex,
    required this.finalRank,
    required this.finalScore,
    required this.updatedCanon,
  });
}

/// Reactive StateNotifier orchestrating tournament progression, UI events,
/// optimistic Drift SQLite persistence, and offline duel queue logging.
///
/// Conforms to:
/// - `docs/technical_architecture/04_CLIENT_ARCHITECTURE_AND_OFFLINE_SYNC.md` §2
/// - `docs/design_system/04_USER_INTERACTION_FLOWS_AND_GESTURES.md` §1
class DuelController extends StateNotifier<DuelState> {
  final LocalRankingDao _rankingDao;

  DuelController({required LocalRankingDao rankingDao})
      : _rankingDao = rankingDao,
        super(const DuelInitial());

  /// Initializes and starts a new duel tournament for [candidate] against [existingCanon].
  Future<void> initTournament({
    required LocalRanking candidate,
    required List<LocalRanking> existingCanon,
    SentimentBracket? seedBracket,
  }) async {
    // 1. Enforce strict Dual-Canon segregation rules
    DualCanonService.validateMediaTypes(
      candidateMediaType: candidate.mediaType,
      existingMediaTypes: existingCanon.map((e) => e.mediaType),
    );

    // 2. Handle empty canon edge case (N = 0)
    if (existingCanon.isEmpty) {
      final score = ScoreCurveCalculator.calculateScore(1, 1);
      final finalCandidate = candidate.copyWith(
        rankPosition: 1,
        calculatedScore: score,
        syncStatus: 'PENDING',
        updatedAt: DateTime.now(),
      );

      await _rankingDao.upsertRanking(
        LocalRankingsCompanion(
          showId: Value(finalCandidate.showId),
          mediaType: Value(finalCandidate.mediaType),
          title: Value(finalCandidate.title),
          posterPath: Value(finalCandidate.posterPath),
          rankPosition: const Value(1),
          calculatedScore: Value(score),
          bracket: Value(seedBracket?.name),
          syncStatus: const Value('PENDING'),
          updatedAt: Value(DateTime.now()),
        ),
      );

      state = DuelComplete(
        candidate: finalCandidate,
        insertedIndex: 0,
        finalRank: 1,
        finalScore: score,
        updatedCanon: [finalCandidate],
      );
      return;
    }

    // 3. Initialize binary insertion tournament
    final tournament = BinaryInsertionTournament<LocalRanking>(
      existingCanon: existingCanon,
      candidate: candidate,
      seedBracket: seedBracket,
    );

    if (tournament.isComplete) {
      await _resolveTournament(tournament, candidate);
    } else {
      state = DuelActive(
        candidate: candidate,
        currentOpponent: tournament.currentOpponent!,
        step: tournament.roundNumber,
        totalEstimatedSteps: tournament.totalEstimatedRounds,
        tournament: tournament,
      );
    }
  }

  /// Records the user's vote for [winnerTitleId] between candidate and current opponent.
  Future<void> voteWinner(int winnerTitleId) async {
    final current = state;
    if (current is! DuelActive) return;

    final candidate = current.candidate;
    final opponent = current.currentOpponent;

    final bool candidateWon = winnerTitleId == candidate.showId;
    final int winnerId = candidateWon ? candidate.showId : opponent.showId;
    final int loserId = candidateWon ? opponent.showId : candidate.showId;

    // 1. Log to offline duel queue for background sync & taste match aggregations
    final duelRecord = OfflineDuelQueueCompanion.insert(
      id: '${DateTime.now().microsecondsSinceEpoch}-$winnerId-$loserId',
      winnerTitleId: winnerId,
      loserTitleId: loserId,
      mediaType: candidate.mediaType,
      roundNumber: current.step,
    );
    await _rankingDao.enqueueOfflineDuel(duelRecord);

    // 2. Advance binary tournament search window
    final nextTournament = candidateWon
        ? current.tournament.onCandidateWins()
        : current.tournament.onOpponentWins();

    if (nextTournament.isComplete) {
      await _resolveTournament(nextTournament, candidate);
    } else {
      state = DuelActive(
        candidate: candidate,
        currentOpponent: nextTournament.currentOpponent!,
        step: nextTournament.roundNumber,
        totalEstimatedSteps: nextTournament.totalEstimatedRounds,
        tournament: nextTournament,
      );
    }
  }

  /// Steps to adjacent neighbor or resolves adjacent on tie / can't compare.
  Future<void> skipOrTie() async {
    final current = state;
    if (current is! DuelActive) return;

    final nextTournament = current.tournament.onTieOrCantCompare();

    if (nextTournament.isComplete) {
      await _resolveTournament(nextTournament, current.candidate);
    } else {
      state = DuelActive(
        candidate: current.candidate,
        currentOpponent: nextTournament.currentOpponent!,
        step: nextTournament.roundNumber,
        totalEstimatedSteps: nextTournament.totalEstimatedRounds,
        tournament: nextTournament,
      );
    }
  }

  /// Commits final slot placement and batch-recalculates all dynamic percentile scores.
  Future<void> _resolveTournament(
    BinaryInsertionTournament<LocalRanking> tournament,
    LocalRanking candidate,
  ) async {
    state = const DuelResolving();

    final insertedIndex = tournament.insertionIndex!;
    final finalRank = insertedIndex + 1;

    // Insert into canon copy
    final rawUpdated = List<LocalRanking>.from(tournament.existingCanon)
      ..insert(insertedIndex, candidate);

    final totalCount = rawUpdated.length;
    final updatedRankings = <LocalRanking>[];
    final companions = <LocalRankingsCompanion>[];

    for (int i = 0; i < totalCount; i++) {
      final rank = i + 1;
      final score = ScoreCurveCalculator.calculateRoundedScore(rank, totalCount);
      final item = rawUpdated[i];

      final updated = item.copyWith(
        rankPosition: rank,
        calculatedScore: score,
        syncStatus: 'PENDING',
        updatedAt: DateTime.now(),
      );
      updatedRankings.add(updated);

      companions.add(
        LocalRankingsCompanion(
          showId: Value(updated.showId),
          mediaType: Value(updated.mediaType),
          title: Value(updated.title),
          posterPath: Value(updated.posterPath),
          rankPosition: Value(updated.rankPosition),
          calculatedScore: Value(updated.calculatedScore),
          bracket: Value(updated.bracket),
          syncStatus: const Value('PENDING'),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }

    // Persist all shifted ranks and scores atomically in Drift SQLite
    await _rankingDao.updateBatchRanks(companions);

    final finalScore = updatedRankings[insertedIndex].calculatedScore;

    state = DuelComplete(
      candidate: updatedRankings[insertedIndex],
      insertedIndex: insertedIndex,
      finalRank: finalRank,
      finalScore: finalScore,
      updatedCanon: updatedRankings,
    );
  }
}

/// Riverpod provider exposing the [DuelController].
final duelControllerProvider =
    StateNotifierProvider.autoDispose<DuelController, DuelState>((ref) {
  final rankingDao = ref.watch(localRankingDaoProvider);
  return DuelController(rankingDao: rankingDao);
});
