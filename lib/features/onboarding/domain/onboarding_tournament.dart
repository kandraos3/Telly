import 'dart:math' as math;

import '../../ranking/data/ranking_repository.dart';
import '../../ranking/domain/binary_insertion_tournament.dart';

/// The `SCR-04` 60-second onboarding tournament (features/01 §2 Screen 4, FE-606).
///
/// Picks are split by canon (a film never duels a series) and each canon is sorted by
/// binary insertion under a duel budget: nominally 3 + 4 (the larger canon gets 4), with a
/// canon that needs fewer handing the rest to the other, 7 at most in total — so a typical
/// 8+ title selection calibrates in 5–7 taps. When the budget runs out mid-insertion the
/// title lands in the middle of its remaining window; titles never reached keep their
/// selection order at the bottom. Ties ("Too different / Hard to say") spend a duel but
/// record nothing.
class OnboardingTournament {
  static const maxTotalDuels = 7;

  OnboardingTournament(List<CanonCandidate> picks)
      : _canons = _plan(
          picks.where((p) => p.mediaType == 'movie').toList(),
          picks.where((p) => p.mediaType == 'tv').toList(),
        ) {
    _advance();
  }

  final List<_CanonSort> _canons;
  int _active = 0;

  static List<_CanonSort> _plan(List<CanonCandidate> movies, List<CanonCandidate> series) {
    // Nominal split is 3 + 4 (the larger canon gets 4); a canon that needs fewer duels
    // hands the rest of the 7 to the other one.
    final needMovies = fullSortWorstCase(movies.length);
    final needSeries = fullSortWorstCase(series.length);
    var movieBudget = math.min(needMovies, movies.length > series.length ? 4 : 3);
    final seriesBudget = math.min(needSeries, maxTotalDuels - movieBudget);
    movieBudget = math.min(needMovies, maxTotalDuels - seriesBudget);
    return [
      if (movies.isNotEmpty) _CanonSort('movie', movies, movieBudget),
      if (series.isNotEmpty) _CanonSort('tv', series, seriesBudget),
    ];
  }

  /// Worst-case duels to binary-insert into a sorted list of [length] titles.
  static int worstCase(int length) => (math.log(length + 1) / math.ln2).ceil();

  /// Worst-case duels to fully sort [n] titles by binary insertion.
  static int fullSortWorstCase(int n) => [for (var k = 1; k < n; k++) worstCase(k)].fold(0, (a, b) => a + b);

  bool get isComplete => _active >= _canons.length;

  /// The duel on screen, or null when complete.
  OnboardingDuel? get current {
    if (isComplete) return null;
    final c = _canons[_active];
    final t = c.insertion!;
    return OnboardingDuel(
      mediaType: c.mediaType,
      candidate: c.items[c.next],
      opponent: t.currentOpponent!,
      number: c.used + 1,
      planned: c.planned,
    );
  }

  /// Duels taken so far across both canons.
  int get duelCount => _canons.fold(0, (sum, c) => sum + c.used);

  /// The resulting canon for [mediaType], best first.
  List<CanonCandidate> ranked(String mediaType) =>
      _canons.where((c) => c.mediaType == mediaType).expand((c) => c.sorted).toList();

  /// Decided duels for [mediaType].
  List<LoggedDuel> duels(String mediaType) =>
      _canons.where((c) => c.mediaType == mediaType).expand((c) => c.duels).toList();

  void vote({required bool candidateWins}) {
    if (isComplete) return;
    final c = _canons[_active];
    final opponent = c.insertion!.currentOpponent!;
    final candidate = c.items[c.next];
    c.duels.add(LoggedDuel(
      winnerTitleId: candidateWins ? candidate.titleId : opponent.titleId,
      loserTitleId: candidateWins ? opponent.titleId : candidate.titleId,
    ));
    c.used++;
    c.insertion = candidateWins ? c.insertion!.onCandidateWins() : c.insertion!.onOpponentWins();
    _advance();
  }

  /// "Too different / Hard to say".
  void skip() {
    if (isComplete) return;
    final c = _canons[_active];
    c.used++;
    c.insertion = c.insertion!.onTieOrCantCompare();
    _advance();
  }

  void _advance() {
    while (!isComplete) {
      final c = _canons[_active];
      final t = c.insertion;
      if (t != null) {
        if (!t.isComplete && c.used < c.budget) return; // waiting for a vote
        // Finished, or out of budget mid-insertion: the middle of the remaining window.
        final index = t.isComplete ? t.insertionIndex! : ((t.low + t.high + 1) ~/ 2).clamp(0, c.sorted.length);
        c.sorted.insert(index, c.items[c.next]);
        c.insertion = null;
        c.next++;
      }
      if (c.next == 0 && c.items.isNotEmpty) {
        c.sorted.add(c.items.first);
        c.next = 1;
      }
      if (c.next < c.items.length && c.used < c.budget) {
        c.insertion = BinaryInsertionTournament<CanonCandidate>(
          existingCanon: List.of(c.sorted),
          candidate: c.items[c.next],
        );
        continue;
      }
      // Out of budget: the rest keep their selection order.
      c.sorted.addAll(c.items.skip(c.next));
      c.next = c.items.length;
      _active++;
    }
  }
}

class OnboardingDuel {
  final String mediaType;
  final CanonCandidate candidate;
  final CanonCandidate opponent;

  /// 1-based duel number within this canon, and how many are planned for it.
  final int number;
  final int planned;

  const OnboardingDuel({
    required this.mediaType,
    required this.candidate,
    required this.opponent,
    required this.number,
    required this.planned,
  });

  /// `Movie Duel 2 of 3 • Calibrating your Movie Rankings` (features/01 Screen 4).
  String get progressLabel => label(mediaType, number, planned);

  static String label(String mediaType, int number, int planned) => mediaType == 'movie'
      ? 'Movie Duel $number of $planned • Calibrating your Movie Rankings'
      : 'Series Duel $number of $planned • Calibrating your TV Rankings';
}

class _CanonSort {
  _CanonSort(this.mediaType, this.items, this.budget)
      : planned = math.min(budget, OnboardingTournament.fullSortWorstCase(items.length));

  final String mediaType;
  final List<CanonCandidate> items;
  final int budget;

  /// Duels shown as "X of [planned]": the budget, or less if the full sort needs fewer.
  final int planned;

  final sorted = <CanonCandidate>[];
  final duels = <LoggedDuel>[];
  BinaryInsertionTournament<CanonCandidate>? insertion;
  int next = 0;
  int used = 0;
}
