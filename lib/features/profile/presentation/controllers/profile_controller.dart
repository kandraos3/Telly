import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database.dart';
import '../../../ranking/domain/canon_type.dart';
import '../../../ranking/domain/franchise_rollup_service.dart';
import '../../../ranking/domain/score_curve_calculator.dart';

/// Active presentation mode for viewing the user's Canon.
/// Conforms to `docs/features/06_PROFILE_THE_CANON_AND_STATS.md` §3.
enum CanonViewMode {
  rankedList(label: 'Ranked List', shortName: 'Ranked'),
  tierView(label: 'Tier View', shortName: 'Tiers'),
  grid3x3(label: '3x3 Poster Grid', shortName: '3x3 Grid');

  final String label;
  final String shortName;

  const CanonViewMode({required this.label, required this.shortName});
}

/// Provider managing the active dual-canon tab (Movie vs Series).
final selectedCanonProvider = StateProvider<CanonType>((ref) => CanonType.movie);

/// Provider managing the active visual presentation mode (Ranked List, Tier View, 3x3 Grid).
final canonViewModeProvider = StateProvider<CanonViewMode>((ref) => CanonViewMode.rankedList);

/// Provider tracking whether multi-season anime are rolled up into master franchise entries.
final franchiseRollupProvider = StateProvider<bool>((ref) => false);

/// State holding segregated Movie and Series canon entries.
class ProfileCanonState {
  final List<CanonEntry> movies;
  final List<CanonEntry> series;
  final bool isLoading;

  const ProfileCanonState({
    this.movies = const [],
    this.series = const [],
    this.isLoading = false,
  });

  ProfileCanonState copyWith({
    List<CanonEntry>? movies,
    List<CanonEntry>? series,
    bool? isLoading,
  }) {
    return ProfileCanonState(
      movies: movies ?? this.movies,
      series: series ?? this.series,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  List<CanonEntry> entriesFor(CanonType canon, {bool rollupAnime = false}) {
    if (canon == CanonType.movie) {
      return movies;
    } else {
      if (rollupAnime) {
        return FranchiseRollupService.rollupFranchises(series);
      }
      return series;
    }
  }
}

/// State notifier managing personal canon data, reordering, and score recalibrations.
class ProfileCanonNotifier extends StateNotifier<ProfileCanonState> {
  final LocalRankingDao? _dao;

  ProfileCanonNotifier({
    LocalRankingDao? dao,
    List<CanonEntry> initialMovies = const [],
    List<CanonEntry> initialSeries = const [],
  })  : _dao = dao,
        super(ProfileCanonState(
          movies: initialMovies,
          series: initialSeries,
        ));

  /// Update the movie canon list directly.
  void setMovies(List<CanonEntry> movies) {
    state = state.copyWith(movies: List.unmodifiable(movies));
  }

  /// Update the series canon list directly.
  void setSeries(List<CanonEntry> series) {
    state = state.copyWith(series: List.unmodifiable(series));
  }

  /// Re-orders an item from [oldIndex] to [newIndex] within the specified [canon].
  /// Recalculates dynamic percentile scores deterministically using [ScoreCurveCalculator].
  Future<void> reorder({
    required CanonType canon,
    required int oldIndex,
    required int newIndex,
  }) async {
    final currentList = List<CanonEntry>.from(
      canon == CanonType.movie ? state.movies : state.series,
    );

    if (oldIndex < 0 || oldIndex >= currentList.length) return;
    if (newIndex < 0 || newIndex > currentList.length) return;

    var targetIndex = newIndex;
    if (oldIndex < targetIndex) {
      targetIndex -= 1;
    }

    final item = currentList.removeAt(oldIndex);
    currentList.insert(targetIndex, item);

    final totalCount = currentList.length;

    // Recalculate dynamic scores for all shifted items
    final recalculated = <CanonEntry>[];
    for (int i = 0; i < totalCount; i++) {
      final rank = i + 1;
      final score = ScoreCurveCalculator.calculateRoundedScore(rank, totalCount);
      recalculated.add(currentList[i].copyWith(
        rankPosition: rank,
        calculatedScore: score,
      ));
    }

    if (canon == CanonType.movie) {
      state = state.copyWith(movies: List.unmodifiable(recalculated));
    } else {
      state = state.copyWith(series: List.unmodifiable(recalculated));
    }

    // Persist to local Drift database if DAO is available
    if (_dao != null) {
      final companions = recalculated.map((e) {
        return LocalRankingsCompanion.insert(
          showId: e.id,
          mediaType: e.mediaType,
          title: e.title,
          posterPath: driftValue(e.posterPath),
          rankPosition: e.rankPosition,
          calculatedScore: e.calculatedScore,
          syncStatus: driftValue('PENDING'),
        );
      }).toList();

      await _dao.updateBatchRanks(companions);
    }
  }

  static driftValue<T>(T? val) => val == null ? const Value.absent() : Value(val);
}

/// Provider for accessing the [ProfileCanonNotifier].
final profileCanonProvider =
    StateNotifierProvider<ProfileCanonNotifier, ProfileCanonState>((ref) {
  return ProfileCanonNotifier();
});
