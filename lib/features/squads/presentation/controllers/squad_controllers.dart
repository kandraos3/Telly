import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../profile/data/profile_repository.dart';
import '../../data/squad_repository.dart';
import '../../domain/squad_models.dart';

/// My squads (`SCR-17` entry list, FE-608).
class SquadsListController extends AsyncNotifier<List<Squad>> {
  @override
  Future<List<Squad>> build() => ref.watch(squadRepositoryProvider).mySquads();

  Future<Squad> create(String name) async {
    final squad = await ref.read(squadRepositoryProvider).create(name: name.trim());
    state = AsyncData([squad, ...?state.valueOrNull]);
    return squad;
  }
}

final squadsListProvider = AsyncNotifierProvider<SquadsListController, List<Squad>>(SquadsListController.new);

enum SquadTab { consensus, watchlist, debates }

class SquadHubState {
  final Squad squad;
  final SquadTab tab;
  final String mediaType;

  /// Leaderboards loaded so far, per canon.
  final Map<String, List<SquadConsensusItem>> consensus;
  final List<SharedWatchlistItem>? watchlist;
  final bool loadingCanon;

  const SquadHubState({
    required this.squad,
    this.tab = SquadTab.consensus,
    this.mediaType = 'tv',
    this.consensus = const {},
    this.watchlist,
    this.loadingCanon = false,
  });

  List<SquadConsensusItem> get leaderboard => consensus[mediaType] ?? const [];

  /// Highest-disagreement titles (features/04 §4.2 "Internal Squad Disagreement").
  List<SquadConsensusItem> get debates =>
      [...leaderboard.where((i) => i.isHotDebate)]..sort((a, b) => b.rankVariance.compareTo(a.rankVariance));

  SquadHubState copyWith({
    Squad? squad,
    SquadTab? tab,
    String? mediaType,
    Map<String, List<SquadConsensusItem>>? consensus,
    List<SharedWatchlistItem>? watchlist,
    bool? loadingCanon,
  }) =>
      SquadHubState(
        squad: squad ?? this.squad,
        tab: tab ?? this.tab,
        mediaType: mediaType ?? this.mediaType,
        consensus: consensus ?? this.consensus,
        watchlist: watchlist ?? this.watchlist,
        loadingCanon: loadingCanon ?? this.loadingCanon,
      );
}

class InviteFailure implements Exception {
  final String message;
  const InviteFailure(this.message);
  @override
  String toString() => message;
}

/// One squad's hub (FE-608): members, per-canon Borda leaderboard, shared watchlist.
class SquadHubController extends AutoDisposeFamilyAsyncNotifier<SquadHubState, String> {
  SquadRepository get _repo => ref.read(squadRepositoryProvider);

  @override
  Future<SquadHubState> build(String arg) async {
    final repo = ref.watch(squadRepositoryProvider);
    final squad = await repo.fetchSquad(arg);
    final board = await repo.consensus(squad, 'tv');
    return SquadHubState(squad: squad, consensus: {'tv': board});
  }

  /// Whether I may invite (owner/admin).
  bool get canInvite {
    final me = ref.read(authRepositoryProvider).currentUserId;
    final members = state.valueOrNull?.squad.members ?? const <SquadMember>[];
    return members.any((m) => m.userId == me && m.role.canInvite);
  }

  Future<void> selectCanon(String mediaType) async {
    final current = state.valueOrNull;
    if (current == null || current.mediaType == mediaType) return;
    if (current.consensus.containsKey(mediaType)) {
      state = AsyncData(current.copyWith(mediaType: mediaType));
      return;
    }
    state = AsyncData(current.copyWith(mediaType: mediaType, loadingCanon: true));
    try {
      final board = await _repo.consensus(current.squad, mediaType);
      final latest = state.valueOrNull ?? current;
      state = AsyncData(latest.copyWith(consensus: {...latest.consensus, mediaType: board}, loadingCanon: false));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> selectTab(SquadTab tab) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(tab: tab));
    if (tab == SquadTab.watchlist && current.watchlist == null) {
      final list = await _repo.sharedWatchlist(current.squad.id);
      state = AsyncData((state.valueOrNull ?? current).copyWith(watchlist: list));
    }
  }

  /// Adds a member by handle; throws [InviteFailure] with a user-facing message.
  Future<void> invite(String handle) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final profile = await ref.read(profileRepositoryProvider).fetchByHandle(handle.trim().replaceFirst('@', ''));
    if (profile == null) throw InviteFailure('No one found with @${handle.trim()}.');
    if (current.squad.members.any((m) => m.userId == profile.id)) {
      throw InviteFailure('@${profile.username} is already in this squad.');
    }
    await _repo.addMember(squadId: current.squad.id, userId: profile.id);
    ref.invalidateSelf();
    await future;
  }
}

final squadHubProvider =
    AsyncNotifierProvider.autoDispose.family<SquadHubController, SquadHubState, String>(SquadHubController.new);
