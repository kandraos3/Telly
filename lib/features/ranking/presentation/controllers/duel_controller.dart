import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database.dart';
import '../../../logging/domain/watch_status.dart';
import '../../data/ranking_repository.dart';
import '../../domain/binary_insertion_tournament.dart';
import '../../domain/canon_type.dart';
import '../../domain/sentiment_bracket.dart';

/// Sealed hierarchy representing states of the pairwise duel tournament.
sealed class DuelState {
  const DuelState();
}

/// Loading the canon snapshot before the first duel.
class DuelInitial extends DuelState {
  const DuelInitial();
}

/// Active duel state presenting [candidate] against [currentOpponent].
class DuelActive extends DuelState {
  final LocalRanking candidate;
  final LocalRanking currentOpponent;
  final int step;
  final int totalEstimatedSteps;

  /// The logging tournament; null for duel loops that track their own (onboarding).
  final BinaryInsertionTournament<LocalRanking>? tournament;

  const DuelActive({
    required this.candidate,
    required this.currentOpponent,
    required this.step,
    required this.totalEstimatedSteps,
    this.tournament,
  });
}

/// Committing the placement through the repository.
class DuelResolving extends DuelState {
  const DuelResolving();
}

/// The placement is committed locally (and queued for sync).
class DuelComplete extends DuelState {
  final RankingCommit commit;

  const DuelComplete(this.commit);

  int get finalRank => commit.rank;
  double get finalScore => commit.score;
  int get insertedIndex => commit.rank - 1;
  List<LocalRanking> get updatedCanon => commit.canon;
  LocalRanking get candidate => commit.canon[insertedIndex];
}

/// The commit failed (e.g. storage error); the tournament can be retried.
class DuelFailed extends DuelState {
  final Object error;
  const DuelFailed(this.error);
}

/// What the duel loop needs from a logging session (`SCR-09` draft).
class DuelRequest {
  final CanonCandidate candidate;
  final SentimentBracket bracket;
  final WatchStatus status;

  /// False logs privately: ranked, but no feed post (FE-LOG-02).
  final bool broadcast;

  const DuelRequest({required this.candidate, required this.bracket, required this.status, this.broadcast = true});

  @override
  bool operator ==(Object other) =>
      other is DuelRequest &&
      other.candidate.titleId == candidate.titleId &&
      other.candidate.mediaType == candidate.mediaType &&
      other.bracket == bracket &&
      other.status == status &&
      other.broadcast == broadcast;

  @override
  int get hashCode => Object.hash(candidate.titleId, candidate.mediaType, bracket, status, broadcast);
}

/// What the arena (`SCR-10`, reused by `SCR-04`) can ask of a duel loop.
abstract interface class DuelActions {
  Future<void> voteWinner(int winnerTitleId);
  Future<void> skipOrTie();
}

/// Binary-insertion duel loop for one logging session (FE-604, TA-04 §2.1).
///
/// Opponents come only from the candidate's own canon (`RankingRepository.getCanon`), so a
/// movie never duels a series. Decided duels are kept in memory and committed together with
/// the placement in a single repository transaction.
class DuelController extends AutoDisposeFamilyNotifier<DuelState, DuelRequest> implements DuelActions {
  final _duels = <LoggedDuel>[];
  final _clock = Stopwatch();
  bool _disposed = false;

  RankingRepository get _repository => ref.read(rankingRepositoryProvider);

  @override
  DuelState build(DuelRequest arg) {
    ref.onDispose(() => _disposed = true);
    scheduleMicrotask(_start);
    return const DuelInitial();
  }

  Future<void> _start() async {
    final c = arg.candidate;
    // A title already in the canon is re-dueled from scratch (features/02 §7.2).
    final opponents = (await _repository.getCanon(c.mediaType)).where((r) => r.showId != c.titleId).toList();
    if (_disposed) return;
    DualCanonService.validateMediaTypes(
      candidateMediaType: c.mediaType,
      existingMediaTypes: opponents.map((e) => e.mediaType),
    );

    final candidate = LocalRanking(
      showId: c.titleId,
      mediaType: c.mediaType,
      title: c.title,
      posterPath: c.posterPath,
      rankPosition: 0,
      calculatedScore: 0,
      bracket: arg.bracket.name,
      syncStatus: 'PENDING',
      updatedAt: DateTime.now(),
    );
    _advance(BinaryInsertionTournament<LocalRanking>(
      existingCanon: opponents,
      candidate: candidate,
      seedBracket: arg.bracket,
    ));
  }

  /// Records the user's pick between the candidate and the current opponent.
  @override
  Future<void> voteWinner(int winnerTitleId) async {
    final current = state;
    if (current is! DuelActive) return;
    final candidateWon = winnerTitleId == current.candidate.showId;
    _duels.add(LoggedDuel(
      winnerTitleId: candidateWon ? current.candidate.showId : current.currentOpponent.showId,
      loserTitleId: candidateWon ? current.currentOpponent.showId : current.candidate.showId,
      decisionTimeMs: _clock.elapsedMilliseconds,
    ));
    await _advance(candidateWon ? current.tournament!.onCandidateWins() : current.tournament!.onOpponentWins());
  }

  /// "Can't Compare / Equal": steps to a neighbour without recording a duel.
  @override
  Future<void> skipOrTie() async {
    final current = state;
    if (current is! DuelActive) return;
    await _advance(current.tournament!.onTieOrCantCompare());
  }

  Future<void> _advance(BinaryInsertionTournament<LocalRanking> t) async {
    if (!t.isComplete) {
      _clock
        ..reset()
        ..start();
      state = DuelActive(
        candidate: t.candidate,
        currentOpponent: t.currentOpponent!,
        step: t.roundNumber,
        totalEstimatedSteps: t.totalEstimatedRounds,
        tournament: t,
      );
      return;
    }
    state = const DuelResolving();
    try {
      final commit = await _repository.commitPlacement(
        candidate: arg.candidate,
        targetRank: t.finalRank!,
        duels: List.unmodifiable(_duels),
        status: arg.status.serverStatus,
        isRewatch: arg.status.isRewatch,
        bracket: arg.bracket.name,
        broadcast: arg.broadcast,
      );
      if (!_disposed) state = DuelComplete(commit);
    } catch (e) {
      if (!_disposed) state = DuelFailed(e);
    }
  }
}

final duelControllerProvider =
    AutoDisposeNotifierProviderFamily<DuelController, DuelState, DuelRequest>(DuelController.new);
