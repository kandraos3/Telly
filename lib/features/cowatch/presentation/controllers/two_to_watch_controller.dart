import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/data/profile_repository.dart';
import '../../../queue/data/watchlist_repository.dart';
import '../../../title_detail/data/title_detail_repository.dart';
import '../../data/co_watch_repository.dart';
import '../../domain/two_to_watch_engine.dart';

/// How SCR-16 was opened: from a friend's profile (id known), from a link with only a
/// handle, or from a title's Co-Watch button (maybe no friend at all).
typedef TwoToWatchArgs = ({
  String? friendId,
  String? friendHandle,
  String? friendDisplayName,
  int? titleId,
  String? titleMediaType,
});

/// SCR-16 state (FE-COWATCH-01): the couch, the filters, and the real candidate pool.
class TwoToWatchState {
  final CoWatchPartner? partner;

  /// True while a handle from the route is being resolved to a user.
  final bool resolvingPartner;

  /// People I follow, for the friend picker; null while loading.
  final List<CoWatchPartner>? partners;

  final CoWatchFormat format;
  final RuntimeBudget? runtimeBudget;
  final Set<String> vibes;

  final SharedStreaming streaming;

  /// Shared services the user has left switched on.
  final Set<String> activeProviders;

  /// Taste match % with the partner per canon; absent until loaded or when refused.
  final Map<String, int> matchByMediaType;

  /// Candidate pools per canon (`get_co_watch_candidates`); a missing key is loading.
  final Map<String, List<CoWatchCandidate>> candidatesByMediaType;
  final bool candidatesFailed;

  /// The title SCR-16 was opened for, as a real candidate (pinned first).
  final CoWatchCandidate? preselected;

  const TwoToWatchState({
    this.partner,
    this.resolvingPartner = false,
    this.partners,
    this.format = CoWatchFormat.movieNight,
    this.runtimeBudget,
    this.vibes = const {},
    this.streaming = SharedStreaming.unknown,
    this.activeProviders = const {},
    this.matchByMediaType = const {},
    this.candidatesByMediaType = const {},
    this.candidatesFailed = false,
    this.preselected,
  });

  int? get matchPercentage => matchByMediaType[format.mediaType];

  /// Top picks stay hidden until both a friend and a vibe are chosen (FE-COWATCH-02).
  bool get readyForPicks => partner != null && vibes.isNotEmpty;

  /// Null while the pool for the selected format is loading.
  List<CoWatchCandidate>? get candidates {
    final pool = candidatesByMediaType[format.mediaType];
    if (pool == null) return null;
    final pinned = preselected;
    if (pinned == null || pinned.mediaType != format.mediaType || pool.any((c) => c.showId == pinned.showId)) {
      return pool;
    }
    return [pinned, ...pool];
  }

  /// Scored picks, best first, with the pre-selected title pinned to the top.
  List<ScoredRecommendation> get recommendations {
    final pool = candidates;
    if (pool == null) return const [];
    final scored = TwoToWatchEngine.scoreCandidates(
      candidates: pool,
      // An unknown overlap must not hide everything: filter only on a known overlap.
      activeSharedProviders: streaming.known ? activeProviders : const {},
      format: format,
      runtimeBudget: runtimeBudget,
      selectedVibes: vibes.toList(),
      tasteMatchPercentage: matchPercentage ?? 50,
      requireVibe: true,
    );
    final pinnedId = preselected?.showId;
    if (pinnedId != null) {
      final i = scored.indexWhere((r) => r.candidate.showId == pinnedId);
      if (i > 0) scored.insert(0, scored.removeAt(i));
    }
    return scored;
  }

  TwoToWatchState copyWith({
    CoWatchPartner? partner,
    bool? resolvingPartner,
    List<CoWatchPartner>? partners,
    CoWatchFormat? format,
    RuntimeBudget? Function()? runtimeBudget,
    Set<String>? vibes,
    SharedStreaming? streaming,
    Set<String>? activeProviders,
    Map<String, int>? matchByMediaType,
    Map<String, List<CoWatchCandidate>>? candidatesByMediaType,
    bool? candidatesFailed,
    CoWatchCandidate? preselected,
  }) =>
      TwoToWatchState(
        partner: partner ?? this.partner,
        resolvingPartner: resolvingPartner ?? this.resolvingPartner,
        partners: partners ?? this.partners,
        format: format ?? this.format,
        runtimeBudget: runtimeBudget != null ? runtimeBudget() : this.runtimeBudget,
        vibes: vibes ?? this.vibes,
        streaming: streaming ?? this.streaming,
        activeProviders: activeProviders ?? this.activeProviders,
        matchByMediaType: matchByMediaType ?? this.matchByMediaType,
        candidatesByMediaType: candidatesByMediaType ?? this.candidatesByMediaType,
        candidatesFailed: candidatesFailed ?? this.candidatesFailed,
        preselected: preselected ?? this.preselected,
      );
}

class TwoToWatchController extends AutoDisposeFamilyNotifier<TwoToWatchState, TwoToWatchArgs> {
  CoWatchRepository get _repo => ref.read(coWatchRepositoryProvider);

  /// Loads finish after the screen may have closed; never touch state once disposed.
  bool _alive = true;

  @override
  TwoToWatchState build(TwoToWatchArgs arg) {
    final id = arg.friendId;
    final handle = arg.friendHandle;
    final partner = id == null
        ? null
        : CoWatchPartner(userId: id, username: handle ?? '', displayName: arg.friendDisplayName ?? '');
    _alive = true;
    ref.onDispose(() => _alive = false);
    Future.microtask(() => _init(arg));
    return TwoToWatchState(
      partner: partner,
      resolvingPartner: partner == null && handle != null,
      format: arg.titleMediaType == 'tv' ? CoWatchFormat.series : CoWatchFormat.movieNight,
    );
  }

  Future<void> _init(TwoToWatchArgs arg) async {
    if (!_alive) return;
    _loadPartners();
    _loadPreselected(arg);
    var partner = state.partner;
    if (partner == null && arg.friendHandle != null) {
      partner = await _resolveHandle(arg.friendHandle!);
      if (!_alive) return;
      state = state.copyWith(resolvingPartner: false, partner: partner);
    }
    if (partner != null) await _loadForPartner(partner);
  }

  Future<CoWatchPartner?> _resolveHandle(String handle) async {
    try {
      final profile = await ref.read(profileRepositoryProvider).fetchByHandle(handle.replaceFirst('@', ''));
      if (profile == null) return null;
      return CoWatchPartner(
        userId: profile.id,
        username: profile.username,
        displayName: profile.displayName,
        avatarUrl: profile.avatarUrl,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadPartners() async {
    try {
      final partners = await _repo.fetchPartners();
      if (!_alive) return;
      state = state.copyWith(partners: partners);
    } catch (_) {
      if (_alive) state = state.copyWith(partners: const []);
    }
  }

  Future<void> _loadPreselected(TwoToWatchArgs arg) async {
    final id = arg.titleId;
    if (id == null) return;
    try {
      final detail = await ref
          .read(titleDetailRepositoryProvider)
          .fetchTitleDetail(id: id, mediaType: arg.titleMediaType ?? state.format.mediaType);
      if (detail == null || !_alive) return;
      state = state.copyWith(
        preselected: CoWatchCandidate(
          showId: detail.id,
          title: detail.title,
          mediaType: detail.mediaType,
          runtimeMinutes: detail.runtimeMinutes,
          posterPath: detail.posterPath,
          network: detail.network ?? '',
          availableProviders: [for (final a in detail.availabilities) a.platformId],
          vibeTags: detail.genres,
          communityScore: detail.communityScore ?? 0,
          overview: detail.overview ?? '',
        ),
      );
    } catch (_) {}
  }

  /// Everything that depends on who's on the couch: overlap, taste match, candidates.
  Future<void> _loadForPartner(CoWatchPartner partner) async {
    await Future.wait([
      _loadStreaming(partner),
      _loadMatch(partner, 'movie'),
      _loadMatch(partner, 'tv'),
      _loadCandidates(partner, state.format.mediaType),
    ]);
  }

  Future<void> _loadStreaming(CoWatchPartner partner) async {
    try {
      final streaming = await _repo.fetchSharedStreaming(partner.userId);
      if (!_alive || state.partner?.userId != partner.userId) return;
      state = state.copyWith(streaming: streaming, activeProviders: streaming.shared);
    } catch (_) {}
  }

  Future<void> _loadMatch(CoWatchPartner partner, String mediaType) async {
    try {
      final match = await ref.read(profileRepositoryProvider).tasteMatch(partner.userId, mediaType);
      if (match == null || !_alive || state.partner?.userId != partner.userId) return;
      state = state.copyWith(matchByMediaType: {...state.matchByMediaType, mediaType: match.percentage});
    } catch (_) {}
  }

  Future<void> _loadCandidates(CoWatchPartner partner, String mediaType) async {
    if (state.candidatesByMediaType.containsKey(mediaType)) return;
    try {
      final pool = await _repo.fetchCandidates(partnerId: partner.userId, mediaType: mediaType);
      if (!_alive || state.partner?.userId != partner.userId) return;
      state = state.copyWith(
        candidatesByMediaType: {...state.candidatesByMediaType, mediaType: pool},
        candidatesFailed: false,
      );
    } catch (_) {
      if (!_alive || state.partner?.userId != partner.userId) return;
      state = state.copyWith(
        candidatesByMediaType: {...state.candidatesByMediaType, mediaType: const []},
        candidatesFailed: true,
      );
    }
  }

  /// Puts [partner] on the couch, discarding everything loaded for the previous one.
  Future<void> selectPartner(CoWatchPartner partner) async {
    if (state.partner?.userId == partner.userId) return;
    state = TwoToWatchState(
      partner: partner,
      partners: state.partners,
      format: state.format,
      runtimeBudget: state.runtimeBudget,
      vibes: state.vibes,
      preselected: state.preselected,
    );
    await _loadForPartner(partner);
  }

  Future<void> selectFormat(CoWatchFormat format) async {
    if (state.format == format) return;
    state = state.copyWith(format: format);
    final partner = state.partner;
    if (partner != null) await _loadCandidates(partner, format.mediaType);
  }

  void selectRuntime(RuntimeBudget? budget) => state = state.copyWith(runtimeBudget: () => budget);

  void toggleVibe(String vibe) {
    final vibes = {...state.vibes};
    if (!vibes.remove(vibe)) vibes.add(vibe);
    state = state.copyWith(vibes: vibes);
  }

  /// Adds [candidate] to my watchlist and marks it queued in the pool, so the
  /// "On both of your watchlists" bonus applies straight away (FE-COWATCH-02).
  Future<void> addToWatchlist(CoWatchCandidate candidate) async {
    await ref.read(watchlistRepositoryProvider).add(
          titleId: candidate.showId,
          mediaType: candidate.mediaType,
          title: candidate.title,
          posterPath: candidate.posterPath,
        );
    if (!_alive) return;
    CoWatchCandidate mark(CoWatchCandidate c) =>
        c.showId == candidate.showId && c.mediaType == candidate.mediaType ? c.queuedByMe() : c;
    final pools = {
      for (final e in state.candidatesByMediaType.entries) e.key: [for (final c in e.value) mark(c)],
    };
    final pinned = state.preselected;
    state = state.copyWith(
      candidatesByMediaType: pools,
      preselected: pinned == null ? null : mark(pinned),
    );
  }

  void toggleProvider(String platformId) {
    final active = {...state.activeProviders};
    if (!active.remove(platformId)) active.add(platformId);
    state = state.copyWith(activeProviders: active);
  }
}

final twoToWatchProvider =
    NotifierProvider.autoDispose.family<TwoToWatchController, TwoToWatchState, TwoToWatchArgs>(
  TwoToWatchController.new,
);
