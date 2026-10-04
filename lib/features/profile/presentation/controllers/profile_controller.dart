import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database.dart';
import '../../../onboarding/data/top_50_seeds.dart';
import '../../../ranking/data/ranking_repository.dart';
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

/// A single selectable value (tab, view mode, toggle) held in a [Notifier].
/// Tests override with `() => Selection(x)`.
class Selection<T> extends Notifier<T> {
  Selection(this._initial);
  final T _initial;

  @override
  T build() => _initial;

  void select(T value) => state = value;
}

/// Provider managing the active dual-canon tab (Movie vs Series).
final selectedCanonProvider =
    NotifierProvider<Selection<CanonType>, CanonType>(() => Selection(CanonType.movie));

/// Provider managing the active visual presentation mode (Ranked List, Tier View, 3x3 Grid).
final canonViewModeProvider =
    NotifierProvider<Selection<CanonViewMode>, CanonViewMode>(() => Selection(CanonViewMode.rankedList));

/// Provider tracking whether multi-season anime are rolled up into master franchise entries.
final franchiseRollupProvider = NotifierProvider<Selection<bool>, bool>(() => Selection(false));

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

/// The signed-in user's dual canon, streamed from Drift through [RankingRepository]
/// (FE-604). Writes go through the repository, which also queues them for sync.
class ProfileCanonNotifier extends Notifier<ProfileCanonState> {
  @override
  ProfileCanonState build() {
    final repository = ref.watch(rankingRepositoryProvider);
    final subscriptions = [
      repository.watchCanon('movie').listen(
            (rows) => state = state.copyWith(movies: List.unmodifiable(rows.map(_toEntry)), isLoading: false),
          ),
      repository.watchCanon('tv').listen(
            (rows) => state = state.copyWith(series: List.unmodifiable(rows.map(_toEntry)), isLoading: false),
          ),
    ];
    ref.onDispose(() {
      for (final s in subscriptions) {
        s.cancel();
      }
    });
    return const ProfileCanonState(isLoading: true);
  }

  static CanonEntry _toEntry(LocalRanking r) {
    final seedPoster = findSeedPoster(r.showId, r.mediaType);
    final poster = (seedPoster != null && seedPoster.isNotEmpty) ? seedPoster : r.posterPath;
    return CanonEntry(
      id: r.showId,
      title: r.title,
      mediaType: r.mediaType,
      rankPosition: r.rankPosition,
      calculatedScore: r.calculatedScore,
      posterPath: poster,
      mvpCharacter: r.favoriteCharacter,
    );
  }

  /// Moves [titleId] to canon rank [newRank] (drag-and-drop, features/02 §7.3): the list
  /// re-scores immediately, then the repository persists and queues the move.
  Future<void> moveTitle({required CanonType canon, required int titleId, required int newRank}) async {
    final current = List<CanonEntry>.from(canon == CanonType.movie ? state.movies : state.series);
    final from = current.indexWhere((e) => e.id == titleId);
    if (from < 0) return;
    final item = current.removeAt(from);
    current.insert((newRank - 1).clamp(0, current.length), item);

    final total = current.length;
    final rescored = List<CanonEntry>.unmodifiable([
      for (var i = 0; i < total; i++)
        current[i].copyWith(
          rankPosition: i + 1,
          calculatedScore: ScoreCurveCalculator.calculateRoundedScore(i + 1, total),
        ),
    ]);
    state = canon == CanonType.movie ? state.copyWith(movies: rescored) : state.copyWith(series: rescored);

    await ref.read(rankingRepositoryProvider).move(mediaType: canon.dbValue, titleId: titleId, newRank: newRank);
  }
}

final profileCanonProvider = NotifierProvider<ProfileCanonNotifier, ProfileCanonState>(ProfileCanonNotifier.new);
