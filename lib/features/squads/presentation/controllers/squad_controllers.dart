import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/auth_repository.dart';
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

  /// Drops a squad I deleted or left from the list without refetching.
  void remove(String squadId) {
    final current = state.valueOrNull;
    if (current != null) state = AsyncData([...current.where((s) => s.id != squadId)]);
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
    this.mediaType = 'movie',
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
    // Movies first, as everywhere else in the app (FE-PROFILE-01 / FE-SQUADS-02).
    final board = await repo.consensus(squad, 'movie');
    return SquadHubState(squad: squad, consensus: {'movie': board});
  }

  /// Whether I may invite (owner/admin).
  bool get canInvite {
    final me = ref.read(authRepositoryProvider).currentUserId;
    final members = state.valueOrNull?.squad.members ?? const <SquadMember>[];
    return members.any((m) => m.userId == me && m.role.canInvite);
  }

  /// Owners delete the squad; everyone else can leave it (FE-SQUADS-01).
  bool get isOwner {
    final me = ref.read(authRepositoryProvider).currentUserId;
    final squad = state.valueOrNull?.squad;
    if (squad == null) return false;
    return squad.createdBy == me || squad.members.any((m) => m.userId == me && m.role == SquadRole.owner);
  }

  /// Deletes the squad (owner) or leaves it (member), then drops it from my list.
  Future<void> deleteOrLeave() async {
    final squad = state.valueOrNull?.squad;
    if (squad == null) return;
    if (isOwner) {
      await _repo.deleteSquad(squad.id);
    } else {
      await _repo.leaveSquad(squad.id);
    }
    if (ref.exists(squadsListProvider)) ref.read(squadsListProvider.notifier).remove(squad.id);
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

  /// Live validation for the invite dialog (FE-SQUADS-02): resolves a handle or email,
  /// or explains why it can't be invited. Never throws.
  Future<InviteCheck> checkInvitee(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const InviteCheck.empty();
    final isEmail = looksLikeEmail(q);
    if (!isEmail && !looksLikeHandle(q)) {
      return InviteCheck.invalid(q.contains('@') && !q.startsWith('@')
          ? 'Enter a full email address.'
          : 'Handles are 3–20 letters, numbers or underscores.');
    }
    final SquadInvitee? invitee;
    try {
      invitee = await _repo.findInvitee(q);
    } catch (_) {
      return const InviteCheck.invalid("Couldn't check that right now.");
    }
    if (invitee == null) {
      return InviteCheck.invalid(isEmail ? 'No Telly account uses that email.' : 'No one found with @${_handle(q)}.');
    }
    final members = state.valueOrNull?.squad.members ?? const <SquadMember>[];
    if (members.any((m) => m.userId == invitee!.userId)) {
      return InviteCheck.invalid('@${invitee.username} is already in this squad.');
    }
    return InviteCheck.found(invitee);
  }

  /// Adds a member by handle or email; throws [InviteFailure] with a user-facing message.
  Future<SquadInvitee> invite(String query) async {
    final check = await checkInvitee(query);
    final invitee = check.invitee;
    if (invitee == null) throw InviteFailure(check.error ?? 'Enter a handle or email.');
    await _repo.addMember(squadId: state.requireValue.squad.id, userId: invitee.userId);
    ref.invalidateSelf();
    await future;
    return invitee;
  }

  static String _handle(String q) => q.toLowerCase().replaceFirst(RegExp('^@'), '');
}

/// Result of [SquadHubController.checkInvitee].
class InviteCheck {
  final SquadInvitee? invitee;
  final String? error;

  const InviteCheck.empty()
      : invitee = null,
        error = null;
  const InviteCheck.found(SquadInvitee this.invitee) : error = null;
  const InviteCheck.invalid(String this.error) : invitee = null;
}

final squadHubProvider =
    AsyncNotifierProvider.autoDispose.family<SquadHubController, SquadHubState, String>(SquadHubController.new);
