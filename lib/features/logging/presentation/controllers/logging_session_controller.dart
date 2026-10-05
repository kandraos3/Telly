import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ranking/data/ranking_repository.dart';
import '../../../ranking/domain/sentiment_bracket.dart';
import '../../../ranking/presentation/controllers/duel_controller.dart';
import '../../data/title_repository.dart';
import '../../domain/title_search_result.dart';
import '../../domain/watch_status.dart';

/// The in-progress log (title, status, bracket) handed from `SCR-09` to `SCR-10` (FE-603).
class LoggingDraft {
  final String query;

  /// Null while there is nothing to search for.
  final AsyncValue<TitleSearchOutcome>? search;
  final TitleSearchResult? title;
  final WatchStatus? status;
  final int seasonNumber;
  final SentimentBracket? bracket;

  /// 0.5–5.0 in half steps; picks [bracket] via `SentimentBracketExtension.fromStarRating` (FE-LOG-02).
  final double? starRating;

  /// Whether the log posts to followers' feeds; false ranks it privately (FE-LOG-02).
  final bool broadcast;

  /// Set once `SCR-10` commits the placement; read by `SCR-12`.
  final RankingCommit? commit;

  const LoggingDraft({
    this.query = '',
    this.search,
    this.title,
    this.status,
    this.seasonNumber = 1,
    this.bracket,
    this.starRating,
    this.broadcast = true,
    this.commit,
  });

  /// Duels need a title, a ranked status (dropped shows go to the Graveyard) and a bracket.
  bool get canBeginDuels => title != null && status != null && status != WatchStatus.dropped && bracket != null;

  /// The `SCR-10` input for this draft, or null until [canBeginDuels].
  DuelRequest? get duelRequest => canBeginDuels
      ? DuelRequest(
          candidate: CanonCandidate(
            titleId: title!.id,
            mediaType: title!.mediaType,
            title: title!.title,
            posterPath: title!.posterPath,
          ),
          bracket: bracket!,
          status: status!,
          broadcast: broadcast,
        )
      : null;

  LoggingDraft _with({
    String? query,
    AsyncValue<TitleSearchOutcome>? Function()? search,
    TitleSearchResult? Function()? title,
    WatchStatus? Function()? status,
    int? seasonNumber,
    SentimentBracket? Function()? bracket,
    double? Function()? starRating,
    bool? broadcast,
  }) =>
      LoggingDraft(
        query: query ?? this.query,
        search: search != null ? search() : this.search,
        title: title != null ? title() : this.title,
        status: status != null ? status() : this.status,
        seasonNumber: seasonNumber ?? this.seasonNumber,
        bracket: bracket != null ? bracket() : this.bracket,
        starRating: starRating != null ? starRating() : this.starRating,
        broadcast: broadcast ?? this.broadcast,
        commit: commit,
      );
}

/// Auto-disposed: lives exactly as long as the `/log` flow is on screen.
class LoggingSessionController extends AutoDisposeNotifier<LoggingDraft> {
  static const searchDebounce = Duration(milliseconds: 150);
  static const minQueryLength = 2;

  Timer? _debounce;

  @override
  LoggingDraft build() {
    ref.onDispose(() => _debounce?.cancel());
    return const LoggingDraft();
  }

  void updateQuery(String query) {
    _debounce?.cancel();
    final q = query.trim();
    if (q.length < minQueryLength) {
      state = state._with(query: q, search: () => null);
      return;
    }
    state = state._with(query: q);
    _debounce = Timer(searchDebounce, () => _search(q));
  }

  Future<void> _search(String q) async {
    state = state._with(search: () => const AsyncLoading());
    final result = await AsyncValue.guard(() => ref.read(titleRepositoryProvider).search(q));
    if (state.query == q) state = state._with(search: () => result); // drop stale responses
  }

  void selectTitle(TitleSearchResult title) {
    _debounce?.cancel();
    state = LoggingDraft(
      query: state.query,
      search: state.search,
      title: title,
      status: WatchStatus.defaultFor(title.mediaType),
      broadcast: state.broadcast,
    );
  }

  void clearTitle() => state = LoggingDraft(query: state.query, search: state.search, broadcast: state.broadcast);

  void setStatus(WatchStatus status) {
    final title = state.title;
    if (title == null || !WatchStatus.optionsFor(title.mediaType).contains(status)) return;
    state = state._with(status: () => status);
  }

  void setSeasonNumber(int season) {
    if (season >= 1) state = state._with(seasonNumber: season);
  }

  void setBracket(SentimentBracket bracket) => state = state._with(bracket: () => bracket);

  /// Snaps to the nearest half star in 0.5–5.0 and derives the duel search bracket.
  void setStarRating(double stars) {
    final snapped = ((stars * 2).round() / 2).clamp(0.5, 5.0).toDouble();
    state = state._with(
      starRating: () => snapped,
      bracket: () => SentimentBracketExtension.fromStarRating(snapped),
    );
  }

  void setBroadcast(bool broadcast) => state = state._with(broadcast: broadcast);

  void recordCommit(RankingCommit commit) => state = LoggingDraft(
        query: state.query,
        search: state.search,
        title: state.title,
        status: state.status,
        seasonNumber: state.seasonNumber,
        bracket: state.bracket,
        starRating: state.starRating,
        broadcast: state.broadcast,
        commit: commit,
      );
}

final loggingSessionProvider =
    AutoDisposeNotifierProvider<LoggingSessionController, LoggingDraft>(LoggingSessionController.new);
