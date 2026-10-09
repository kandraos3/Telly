import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database.dart';
import '../../../ranking/data/ranking_repository.dart';
import '../../../ranking/presentation/controllers/duel_controller.dart';
import '../../data/onboarding_repository.dart';
import '../../data/top_50_seeds.dart';
import '../../domain/onboarding_tournament.dart';

// ---------------------------------------------------------------------------
// SCR-02 Streaming setup
// ---------------------------------------------------------------------------

class StreamingSetupState {
  final Set<String> selected;
  final bool includeFree;
  final bool saving;
  final String? error;

  const StreamingSetupState({this.selected = const {}, this.includeFree = false, this.saving = false, this.error});
}

/// `SCR-02` selection, saved to `user_streaming_subscriptions` on Continue (FE-606).
class StreamingSetupController extends Notifier<StreamingSetupState> {
  @override
  StreamingSetupState build() => const StreamingSetupState();

  void toggle(String platformId) {
    final next = Set<String>.of(state.selected);
    if (!next.remove(platformId)) next.add(platformId);
    state = StreamingSetupState(selected: next, includeFree: state.includeFree);
  }

  void setIncludeFree(bool value) => state = StreamingSetupState(selected: state.selected, includeFree: value);

  /// Saves the selection; returns false (with [StreamingSetupState.error]) on failure.
  Future<bool> save() async {
    state = StreamingSetupState(selected: state.selected, includeFree: state.includeFree, saving: true);
    try {
      await ref
          .read(onboardingRepositoryProvider)
          .saveStreamingSetup(platformIds: state.selected, includeFreePlatforms: state.includeFree);
      state = StreamingSetupState(selected: state.selected, includeFree: state.includeFree);
      return true;
    } catch (_) {
      state = StreamingSetupState(
        selected: state.selected,
        includeFree: state.includeFree,
        error: "Couldn't save your services. Check your connection and try again.",
      );
      return false;
    }
  }
}

final streamingSetupProvider =
    NotifierProvider<StreamingSetupController, StreamingSetupState>(StreamingSetupController.new);

// ---------------------------------------------------------------------------
// SCR-03 Seed grid
// ---------------------------------------------------------------------------

/// Seed-grid filter pills.
enum SeedFilter { all, movie, tv, anime }

class SeedSelectionState {
  /// Selected seeds keyed by [seedKey] — TMDB ids collide across movie and tv.
  final Set<String> selected;
  final SeedFilter filter;

  /// Titles already added to a canon by an importer during onboarding.
  final int imported;

  const SeedSelectionState({this.selected = const {}, this.filter = SeedFilter.all, this.imported = 0});

  static const minimumPicks = 8;

  /// `Start Ranking Duels` unlocks at 8 picks, or once an import has seeded a canon.
  bool get canStart => selected.length >= minimumPicks || imported > 0;

  List<SeedTitle> get picks => [for (final s in kTop50SeedTitles) if (selected.contains(seedKey(s))) s];

  SeedSelectionState copyWith({Set<String>? selected, SeedFilter? filter, int? imported}) => SeedSelectionState(
        selected: selected ?? this.selected,
        filter: filter ?? this.filter,
        imported: imported ?? this.imported,
      );
}

String seedKey(SeedTitle s) => '${s.mediaType}:${s.id}';

class SeedSelectionController extends Notifier<SeedSelectionState> {
  @override
  SeedSelectionState build() => const SeedSelectionState();

  void toggle(SeedTitle seed) {
    final next = Set<String>.of(state.selected);
    final key = seedKey(seed);
    if (!next.remove(key)) next.add(key);
    state = state.copyWith(selected: next);
  }

  void setFilter(SeedFilter filter) => state = state.copyWith(filter: filter);

  void recordImport(int added) => state = state.copyWith(imported: state.imported + added);
}

final seedSelectionProvider = NotifierProvider<SeedSelectionController, SeedSelectionState>(SeedSelectionController.new);

// ---------------------------------------------------------------------------
// SCR-04 Onboarding tournament
// ---------------------------------------------------------------------------

class OnboardingTournamentState {
  final DuelState duel;

  /// True once both starter canons are persisted.
  final bool done;
  final String? error;

  const OnboardingTournamentState({required this.duel, this.done = false, this.error});
}

/// Runs [OnboardingTournament] over the `SCR-03` picks and persists the starter canons
/// through [RankingRepository.appendCanon] (FE-606). Drives the shared duel arena.
class OnboardingTournamentController extends AutoDisposeNotifier<OnboardingTournamentState> implements DuelActions {
  late OnboardingTournament _tournament;

  @override
  OnboardingTournamentState build() {
    final picks = ref.read(seedSelectionProvider).picks;
    _tournament = OnboardingTournament([
      for (final s in picks)
        CanonCandidate(titleId: s.id, mediaType: s.mediaType, title: s.title, posterPath: s.posterPath),
    ]);
    if (_tournament.isComplete) {
      Future.microtask(_persist);
      return const OnboardingTournamentState(duel: DuelResolving());
    }
    return OnboardingTournamentState(duel: _active());
  }

  DuelActive _active() {
    final d = _tournament.current!;
    LocalRanking row(CanonCandidate c) => LocalRanking(
          showId: c.titleId,
          mediaType: c.mediaType,
          title: c.title,
          posterPath: c.posterPath,
          rankPosition: 0,
          calculatedScore: 0,
          syncStatus: 'PENDING',
          updatedAt: DateTime.now(),
        );
    return DuelActive(
      candidate: row(d.candidate),
      currentOpponent: row(d.opponent),
      step: d.number,
      totalEstimatedSteps: d.planned,
    );
  }

  @override
  Future<void> voteWinner(int winnerTitleId) async {
    final current = _tournament.current;
    if (current == null) return;
    _tournament.vote(candidateWins: winnerTitleId == current.candidate.titleId);
    await _next();
  }

  @override
  Future<void> skipOrTie() async {
    _tournament.skip();
    await _next();
  }

  Future<void> _next() async {
    if (!_tournament.isComplete) {
      state = OnboardingTournamentState(duel: _active());
      return;
    }
    state = const OnboardingTournamentState(duel: DuelResolving());
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final repo = ref.read(rankingRepositoryProvider);
      for (final mediaType in const ['movie', 'tv']) {
        await repo.appendCanon(
          mediaType: mediaType,
          ordered: _tournament.ranked(mediaType),
          duels: _tournament.duels(mediaType),
        );
      }
      state = const OnboardingTournamentState(duel: DuelResolving(), done: true);
    } catch (e) {
      state = OnboardingTournamentState(duel: DuelFailed(e), error: "Couldn't save your starter rankings.");
    }
  }
}

final onboardingTournamentProvider =
    AutoDisposeNotifierProvider<OnboardingTournamentController, OnboardingTournamentState>(
  OnboardingTournamentController.new,
);
