import '../../queue/domain/streaming_models.dart';
import '../../tracking/domain/tracking_group.dart';
import '../../tracking/domain/tracking_hub.dart';
import '../../tracking/domain/tracking_item.dart';

/// Which card leads Home (SCR-21 §21.2).
enum HomeHeroMode {
  /// A tracked title's next episode (or a movie being watched).
  watching,

  /// The Queue's Up next pick, when nothing is being watched.
  queue,

  /// No rankings, nothing tracked and an empty Queue.
  newUser,

  /// Everything else: a nudge to Explore.
  explore,
}

/// What the Tonight hero shows, plus the chips under it.
class HomeHero {
  const HomeHero({
    required this.mode,
    this.item,
    this.queuePick,
    this.chips = const [],
    this.totalTracked = 0,
  });

  final HomeHeroMode mode;

  /// The tracked title, in [HomeHeroMode.watching].
  final TrackingItem? item;

  /// The Queue pick, in [HomeHeroMode.queue].
  final WatchlistItem? queuePick;

  /// The other titles being watched, at most [HomeHeroPicker.maxChips], in [HomeHeroMode.watching] only.
  final List<TrackingItem> chips;

  /// Every tracked title in any group: the N of the *All N ›* chip.
  final int totalTracked;
}

/// A Queue title's key in Home's one mixed-canon pick pool. Movie and TV ids can collide on TMDB, so the
/// media type is folded in: movies are even, series odd.
abstract final class HomeQueueKey {
  static int of(WatchlistItem item) => item.showId * 2 + (item.mediaType == 'movie' ? 0 : 1);
}

/// Chooses the Tonight hero (SCR-21 §21.2). Pure Dart: every input is a plain value, `now` included.
abstract final class HomeHeroPicker {
  static const maxChips = 3;

  /// The first mode that applies:
  /// 1. **watching**: a title in *New episodes* or *In progress*. The newest `lastProgressAt` leads, a tie goes
  ///    to *New episodes*, and both canons are eligible.
  /// 2. **queue**: the Queue is not empty. [queuePickKey] (a [HomeQueueKey]) names the session's pick; an unknown
  ///    or missing key falls back to the first Queue title.
  /// 3. **newUser**: no ranking in either canon, nothing tracked at all.
  /// 4. **explore**.
  static HomeHero pick({
    required List<TrackingItem> tracking,
    required List<WatchlistItem> queue,
    required int? queuePickKey,
    required bool hasRankings,
    required DateTime now,
  }) {
    final total = TrackingHub(tracking, now).count(WatchingFilter.all);
    final candidates = <(TrackingItem, TrackingGroup)>[];
    for (final item in tracking) {
      final group = item.group(now);
      if (group == TrackingGroup.newEpisodes || group == TrackingGroup.inProgress) candidates.add((item, group!));
    }
    if (candidates.isNotEmpty) {
      candidates.sort((a, b) {
        final byProgress = b.$1.lastProgressAt.compareTo(a.$1.lastProgressAt);
        if (byProgress != 0) return byProgress;
        final aNew = a.$2 == TrackingGroup.newEpisodes ? 0 : 1;
        final bNew = b.$2 == TrackingGroup.newEpisodes ? 0 : 1;
        if (aNew != bNew) return aNew.compareTo(bNew);
        final byId = a.$1.titleId.compareTo(b.$1.titleId);
        return byId != 0 ? byId : a.$1.mediaType.compareTo(b.$1.mediaType);
      });
      return HomeHero(
        mode: HomeHeroMode.watching,
        item: candidates.first.$1,
        chips: [for (final c in candidates.skip(1).take(maxChips)) c.$1],
        totalTracked: total,
      );
    }
    if (queue.isNotEmpty) {
      final pick = queue.firstWhere((i) => HomeQueueKey.of(i) == queuePickKey, orElse: () => queue.first);
      return HomeHero(mode: HomeHeroMode.queue, queuePick: pick, totalTracked: total);
    }
    if (!hasRankings && total == 0) return HomeHero(mode: HomeHeroMode.newUser, totalTracked: total);
    return HomeHero(mode: HomeHeroMode.explore, totalTracked: total);
  }
}
