import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../discovery/data/discovery_repository.dart';
import '../../../discovery/domain/discovery_models.dart';
import '../../../queue/data/watchlist_repository.dart';
import '../../domain/social_models.dart';

/// One row of the SCR-05 list: a social post or an algorithmic pick (FE-FEED-02).
sealed class FeedEntry {
  const FeedEntry();
}

class ActivityEntry extends FeedEntry {
  const ActivityEntry(this.activity);
  final ActivityLog activity;
}

class RecommendationEntry extends FeedEntry {
  const RecommendationEntry(this.title);
  final RecommendedTitle title;
}

/// Posts between recommendation cards.
const kFeedRecommendationEvery = 6;

/// Slots one pick after every [every] posts, never repeating a pick and never after
/// the last post (a lone pick at the end reads as the feed's last word).
List<FeedEntry> interleaveRecommendations(
  List<ActivityLog> activities,
  List<RecommendedTitle> picks, {
  int every = kFeedRecommendationEvery,
}) {
  final out = <FeedEntry>[];
  var next = 0;
  for (var i = 0; i < activities.length; i++) {
    out.add(ActivityEntry(activities[i]));
    final isSlot = (i + 1) % every == 0 && i + 1 < activities.length;
    if (isSlot && next < picks.length) out.add(RecommendationEntry(picks[next++]));
  }
  return out;
}

class FeedRecommendations {
  const FeedRecommendations({this.picks = const [], this.queued = const {}});

  final List<RecommendedTitle> picks;

  /// `mediaType:titleId` of picks I added to my queue from the feed.
  final Set<String> queued;

  static String keyOf(RecommendedTitle t) => '${t.mediaType}:${t.titleId}';

  bool isQueued(RecommendedTitle t) => queued.contains(keyOf(t));
}

/// Picks for the SCR-05 recommendation cards (`get_recommended_titles`), plus which
/// ones I queued from the feed. A failed load just means no cards.
class FeedRecommendationsController extends AsyncNotifier<FeedRecommendations> {
  @override
  Future<FeedRecommendations> build() async {
    try {
      final picks = await ref.watch(discoveryRepositoryProvider).fetchRecommendedTitles(limit: 12);
      return FeedRecommendations(picks: picks);
    } catch (_) {
      return const FeedRecommendations();
    }
  }

  /// Adds [title] to my queue (offline-first) and marks its card as saved.
  Future<void> queue(RecommendedTitle title) async {
    final current = state.valueOrNull ?? const FeedRecommendations();
    if (current.isQueued(title)) return;
    state = AsyncData(FeedRecommendations(
      picks: current.picks,
      queued: {...current.queued, FeedRecommendations.keyOf(title)},
    ));
    try {
      await ref.read(watchlistRepositoryProvider).add(
            titleId: title.titleId,
            mediaType: title.mediaType,
            title: title.title,
            posterPath: title.posterPath,
          );
    } catch (_) {
      final latest = state.valueOrNull ?? current;
      state = AsyncData(FeedRecommendations(
        picks: latest.picks,
        queued: {...latest.queued}..remove(FeedRecommendations.keyOf(title)),
      ));
      rethrow;
    }
  }
}

final feedRecommendationsProvider =
    AsyncNotifierProvider<FeedRecommendationsController, FeedRecommendations>(FeedRecommendationsController.new);
