import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../challenges/domain/challenge.dart';
import '../../../challenges/presentation/controllers/challenges_controller.dart';
import '../../../feed/data/social_repository.dart';
import '../../../feed/presentation/controllers/feed_controllers.dart';
import '../../../levels/presentation/controllers/levels_controller.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../queue/domain/streaming_models.dart';
import '../../../queue/domain/up_next_picker.dart';
import '../../../queue/presentation/screens/smart_queue_screen.dart';
import '../../../tracking/presentation/providers/tracking_providers.dart';
import '../../domain/friends_line.dart';
import '../../domain/home_hero.dart';
import '../../domain/home_moves.dart';

/// Random source for Home's Queue pick; tests override it with a seeded [Random].
final homeRandomProvider = Provider<Random>((ref) => Random());

/// Home's Queue pick (SCR-21 §21.2): one title from the whole Queue, movies and series together, kept for the
/// app session. It has its own [UpNextPicker] key, so it never shares picks with the Queue screen. The state is a
/// version that [shuffle] bumps so [homeStateProvider] rebuilds.
class HomeQueuePick extends Notifier<int> {
  static const pickerKey = 'home';

  late final UpNextPicker _picker = UpNextPicker(ref.read(homeRandomProvider));

  @override
  int build() => 0;

  /// The [HomeQueueKey] of the current pick from [queue], or null when the Queue is empty.
  int? keyFor(List<WatchlistItem> queue) => _picker.pickFor(pickerKey, [for (final i in queue) HomeQueueKey.of(i)]);

  /// ↻ Another: picks a different title.
  void shuffle(List<WatchlistItem> queue) {
    _picker.shuffle(pickerKey, [for (final i in queue) HomeQueueKey.of(i)]);
    state++;
  }
}

final homeQueuePickProvider = NotifierProvider<HomeQueuePick, int>(HomeQueuePick.new);

/// Everything the Home screen shows (SCR-21).
class HomeState {
  const HomeState({
    required this.hero,
    this.moves = const [],
    this.friends,
    this.streakWeeks = 0,
    this.queueSize = 0,
    this.heroLoading = false,
    this.movesLoading = false,
  });

  final HomeHero hero;
  final List<HomeMove> moves;
  final FriendsLineData? friends;

  /// The streak chip's N; 0 hides the chip.
  final int streakWeeks;

  /// Titles in the Queue; ↻ Another needs at least two.
  final int queueSize;

  /// Tracking or the Queue has not answered yet: the hero shows its skeleton.
  final bool heroLoading;

  /// The local sources (tracking, Queue, canon) have not answered yet: the moves show skeletons.
  final bool movesLoading;
}

/// Derives [HomeState] from the app's existing providers (SCR-21 §21.5). Nothing here writes.
///
/// - A source that is loading or has failed counts as empty, so Home never shows an error.
/// - The hero follows the data at once (✓ Watched re-picks it). The moves are frozen once shown, so they never
///   re-sort under a thumb: they re-derive on [refresh] (Home became visible again, or a move was acted on) and
///   once more whenever a source answers for the first time, so late data (level, challenges, feed) still fills in.
class HomeController extends Notifier<HomeState> {
  List<HomeMove>? _frozen;
  bool _refreshRequested = false;
  int _answered = 0;

  @override
  HomeState build() {
    final now = ref.watch(trackingNowProvider)();
    final tracking = ref.watch(trackingProvider);
    final queueAsync = ref.watch(userWatchlistProvider);
    final canon = ref.watch(profileCanonProvider);
    final level = ref.watch(yourLevelControllerProvider);
    final challenges = ref.watch(challengesControllerProvider);
    final feed = ref.watch(feedControllerProvider(FeedFilter.following));
    final me = ref.watch(authControllerProvider.select((s) => s.user?.id));
    ref.watch(homeQueuePickProvider);

    bool pending(AsyncValue<Object?> v) => v.isLoading && !v.hasValue && !v.hasError;
    final items = tracking.valueOrNull ?? const [];
    final queue = queueAsync.valueOrNull ?? const <WatchlistItem>[];
    final heroLoading = pending(tracking) || pending(queueAsync);
    final movesLoading = heroLoading || canon.isLoading;

    final hasRankings = canon.movies.isNotEmpty || canon.series.isNotEmpty;
    final pickKey = ref.read(homeQueuePickProvider.notifier).keyFor(queue);
    final hero = HomeHeroPicker.pick(
      tracking: items,
      queue: queue,
      queuePickKey: pickKey,
      hasRankings: hasRankings,
      now: now,
    );

    final activity = feed.valueOrNull?.items ?? const [];
    // The app has no follow count, so "follows nobody" is "no friend appears in the Following feed". Until the
    // feed answers, assume somebody does, so the find-friends move doesn't flash in.
    final followsAnyone = feed.hasValue ? activity.any((a) => a.userId != me) : true;
    final queuePick = queue.isEmpty ? null : queue.firstWhere((i) => HomeQueueKey.of(i) == pickKey, orElse: () => queue.first);
    final joined = _joined(challenges.valueOrNull);

    final answered = [tracking, queueAsync, level, challenges, feed]
            .fold<int>(0, (mask, v) => (mask << 1) | (pending(v) ? 0 : 1)) |
        (canon.isLoading ? 0 : 1 << 5);
    if (!movesLoading && (_frozen == null || _refreshRequested || answered != _answered)) {
      _frozen = HomeMovesRanker.rank(
        now: now,
        hero: hero,
        tracking: items,
        queuePick: queuePick,
        streak: level.valueOrNull?.streak,
        challenges: joined,
        friendActivity: activity,
        me: me,
        myRankings: {
          for (final e in [...canon.movies, ...canon.series])
            (e.mediaType, e.id): HomeMyRank(rank: e.rankPosition, score: e.calculatedScore),
        },
        followsAnyone: followsAnyone,
      );
      _refreshRequested = false;
      _answered = answered;
    }

    return HomeState(
      hero: hero,
      moves: _frozen ?? const [],
      friends: FriendsLine.from(feed: activity, me: me, now: now),
      streakWeeks: level.valueOrNull?.streak.currentWeeks ?? 0,
      queueSize: queue.length,
      heroLoading: heroLoading,
      movesLoading: movesLoading,
    );
  }

  /// Challenges you've joined that are still running: yours, plus the featured one when it's joined.
  static List<Challenge> _joined(ChallengesOverview? overview) {
    if (overview == null) return const [];
    final featured = overview.featured;
    return [...overview.yours, if (featured != null && featured.joined) featured];
  }

  /// Re-derives the moves now: Home became visible again, or a move was acted on.
  void refresh() {
    _refreshRequested = true;
    ref.invalidateSelf();
  }

  /// ↻ Another on the hero's Queue pick.
  void shuffleQueuePick() {
    final queue = ref.read(userWatchlistProvider).valueOrNull ?? const <WatchlistItem>[];
    ref.read(homeQueuePickProvider.notifier).shuffle(queue);
  }
}

final homeStateProvider = NotifierProvider<HomeController, HomeState>(HomeController.new);
