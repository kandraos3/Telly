import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../cowatch/domain/spearman_taste_match_calculator.dart';
import '../../../feed/data/social_repository.dart';
import '../../../feed/domain/social_models.dart';
import '../../../ranking/data/ranking_repository.dart';
import '../../../ranking/domain/franchise_rollup_service.dart';
import '../../data/profile_repository.dart';

class FriendProfileData {
  final PublicProfile profile;
  final FollowStatus? followStatus;

  /// Per-canon matches; null when the server has none to give (not visible).
  final CanonMatch? movieMatch;
  final CanonMatch? seriesMatch;

  final List<RankedTitleComparison> agreements;
  final List<RankedTitleComparison> clashes;
  final List<UnwatchedGem> gems;

  const FriendProfileData({
    required this.profile,
    this.followStatus,
    this.movieMatch,
    this.seriesMatch,
    this.agreements = const [],
    this.clashes = const [],
    this.gems = const [],
  });

  int get mutualCount => (movieMatch?.mutualCount ?? 0) + (seriesMatch?.mutualCount ?? 0);

  /// Blended by mutual-title counts (features/05 §2); null if neither canon matched.
  int? get blendedMatch => movieMatch == null && seriesMatch == null
      ? null
      : SpearmanTasteMatchCalculator.calculateBlendedMatch(
          movieMatchPct: movieMatch?.percentage ?? 0,
          movieCount: movieMatch?.mutualCount ?? 0,
          seriesMatchPct: seriesMatch?.percentage ?? 0,
          seriesCount: seriesMatch?.mutualCount ?? 0,
        );

  FriendProfileData withFollow(FollowStatus? status) => FriendProfileData(
        profile: profile,
        followStatus: status,
        movieMatch: movieMatch,
        seriesMatch: seriesMatch,
        agreements: agreements,
        clashes: clashes,
        gems: gems,
      );
}

/// Thrown when no visible user has the handle.
class ProfileNotFound implements Exception {
  final String handle;
  const ProfileNotFound(this.handle);
}

/// Agreements / clashes / gems across both canons (FE-403, features/05 §4).
/// "Mine" is rank A, "theirs" is rank B; canons are compared separately, never mixed.
abstract final class TasteComparisons {
  static const listSize = 5;
  static const gemPool = 10;

  static ({List<RankedTitleComparison> agreements, List<RankedTitleComparison> clashes, List<UnwatchedGem> gems})
      build({required Map<String, List<CanonEntry>> mine, required Map<String, List<CanonEntry>> theirs}) {
    final comparisons = <RankedTitleComparison>[];
    final gems = <UnwatchedGem>[];
    for (final mediaType in const ['movie', 'tv']) {
      final myByTitle = {for (final e in mine[mediaType] ?? const <CanonEntry>[]) e.id: e};
      for (final t in theirs[mediaType] ?? const <CanonEntry>[]) {
        final m = myByTitle[t.id];
        if (m != null) {
          comparisons.add(RankedTitleComparison(
            showId: t.id,
            title: t.title,
            posterPath: t.posterPath,
            rankA: m.rankPosition,
            rankB: t.rankPosition,
            scoreA: m.calculatedScore,
            scoreB: t.calculatedScore,
            reviewB: t.shortReview,
            mediaType: mediaType,
          ));
        } else if (t.rankPosition <= gemPool) {
          gems.add(UnwatchedGem(
            showId: t.id,
            title: t.title,
            posterPath: t.posterPath,
            friendRank: t.rankPosition,
            friendScore: t.calculatedScore,
            mediaType: mediaType,
            network: '',
          ));
        }
      }
    }
    // Score gap (not raw rank gap) so canons of different sizes compare fairly.
    double gap(RankedTitleComparison c) => (c.scoreA - c.scoreB).abs();
    final byGap = [...comparisons]..sort((a, b) => gap(a).compareTo(gap(b)));
    final agreements = byGap.take(listSize).toList();
    final clashes = byGap.reversed.where((c) => !agreements.contains(c)).take(listSize).toList();
    gems.sort((a, b) => b.friendScore.compareTo(a.friendScore));
    return (agreements: agreements, clashes: clashes, gems: gems.take(listSize).toList());
  }
}

/// `SCR-15` for one handle (FE-608).
class FriendProfileController extends AutoDisposeFamilyAsyncNotifier<FriendProfileData, String> {
  @override
  Future<FriendProfileData> build(String arg) async {
    final profiles = ref.watch(profileRepositoryProvider);
    final profile = await profiles.fetchByHandle(arg);
    if (profile == null) throw ProfileNotFound(arg);
    final me = ref.watch(authRepositoryProvider).currentUserId;
    final isSelf = me != null && profile.id == me;
    final follow = await ref.watch(socialRepositoryProvider).getFollowStatus(profile.id);
    final canView = profile.canView &&
        (profile.visibility != 'FRIENDS_ONLY' || follow == FollowStatus.accepted || isSelf);
    if (!canView) {
      return FriendProfileData(
        profile: profile.copyWith(canView: false),
        followStatus: follow,
      );
    }

    final rankings = ref.watch(rankingRepositoryProvider);
    final mine = {
      for (final mt in const ['movie', 'tv'])
        mt: [
          for (final r in await rankings.getCanon(mt))
            CanonEntry(
              id: r.showId,
              title: r.title,
              mediaType: r.mediaType,
              rankPosition: r.rankPosition,
              calculatedScore: r.calculatedScore,
            ),
        ],
    };

    final results = isSelf
        ? <CanonMatch?>[
            (mine['movie']?.isNotEmpty ?? false) ? CanonMatch(100, mine['movie']!.length) : null,
            (mine['tv']?.isNotEmpty ?? false) ? CanonMatch(100, mine['tv']!.length) : null,
          ]
        : await Future.wait([
            profiles.tasteMatch(profile.id, 'movie'),
            profiles.tasteMatch(profile.id, 'tv'),
          ]);
    final theirs = isSelf
        ? mine
        : {for (final mt in const ['movie', 'tv']) mt: await profiles.fetchCanon(profile.id, mt)};
    final lists = TasteComparisons.build(mine: mine, theirs: theirs);
    return FriendProfileData(
      profile: profile,
      followStatus: follow,
      movieMatch: results[0],
      seriesMatch: results[1],
      agreements: lists.agreements,
      clashes: lists.clashes,
      gems: lists.gems,
    );
  }

  /// Follow / unfollow (a pending request is cancelled by unfollowing).
  Future<void> toggleFollow() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final me = ref.read(authRepositoryProvider).currentUserId;
    if (me != null && current.profile.id == me) {
      throw StateError('Cannot follow yourself');
    }
    final social = ref.read(socialRepositoryProvider);
    if (current.followStatus == null || current.followStatus == FollowStatus.rejected) {
      final status = await social.follow(current.profile.id);
      state = AsyncData(current.withFollow(status));
      // Following a friends-only profile may unlock their canon once accepted.
      if (status == FollowStatus.accepted && !current.profile.canView) ref.invalidateSelf();
    } else {
      await social.unfollow(current.profile.id);
      state = AsyncData(current.withFollow(null));
    }
  }

  Future<void> queueGem(UnwatchedGem gem) => ref.read(socialRepositoryProvider).queueTitle(
        titleId: gem.showId,
        mediaType: gem.mediaType,
        recommendedBy: state.valueOrNull?.profile.id,
      );
}

final friendProfileProvider =
    AsyncNotifierProvider.autoDispose.family<FriendProfileController, FriendProfileData, String>(
  FriendProfileController.new,
);
