import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/telemetry_service.dart';
import '../../../achievements/presentation/controllers/achievements_controller.dart';
import '../../data/challenges_repository.dart';
import '../../domain/challenge.dart';

/// The clock challenges are judged by (days left, ended); tests pin it.
final challengeClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// `SCR-25` state (#144): my challenges and the ones to discover, split into sections.
class ChallengesController extends AsyncNotifier<ChallengesOverview> {
  @override
  Future<ChallengesOverview> build() async {
    final repo = ref.watch(challengesRepositoryProvider);
    final (mine, discover) = await (repo.mine(), repo.discover()).wait;
    return ChallengesOverview.of(mine: mine, discover: discover, now: ref.read(challengeClockProvider)());
  }

  /// Joins [challenge]; earlier rankings inside its window count, so it may finish at once
  /// (its medal then shows through the unlock moment).
  Future<void> join(Challenge challenge) async {
    await ref.read(challengesRepositoryProvider).join(challenge.id);
    ref.read(telemetryServiceProvider).trackChallengeJoined(slug: challenge.slug, squad: challenge.isSquad);
    _refreshAround(challenge.slug);
  }

  Future<void> leave(Challenge challenge) async {
    await ref.read(challengesRepositoryProvider).leave(challenge.id);
    _refreshAround(challenge.slug);
  }

  void _refreshAround(String slug) {
    ref.invalidateSelf();
    ref.invalidate(challengeDetailProvider(slug));
    ref.invalidate(achievementsControllerProvider);
  }
}

final challengesControllerProvider =
    AsyncNotifierProvider<ChallengesController, ChallengesOverview>(ChallengesController.new);

/// Thrown when a challenge can't be shown: hidden, a draft, or ended and never joined.
class ChallengeNotFound implements Exception {
  final String slug;
  const ChallengeNotFound(this.slug);

  @override
  String toString() => 'Challenge $slug not found';
}

/// `SCR-26` state (#144): the challenge, who's racing, and picks that would count.
final challengeDetailProvider = FutureProvider.autoDispose.family<ChallengeDetail, String>((ref, slug) async {
  final repo = ref.watch(challengesRepositoryProvider);
  final challenge = await repo.bySlug(slug);
  if (challenge == null) throw ChallengeNotFound(slug);
  final (racers, picks) = await (repo.racers(challenge.id), repo.picks(challenge.id)).wait;
  return ChallengeDetail(challenge: challenge, racers: racers, picks: picks);
});

/// The templates squads create from, for the `SCR-25` "+" sheet.
final challengeTemplatesProvider =
    FutureProvider.autoDispose<List<ChallengeTemplate>>((ref) => ref.watch(challengesRepositoryProvider).templates());
