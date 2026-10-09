import 'package:telly_app/features/challenges/domain/challenge.dart';
import 'package:telly_app/features/challenges/presentation/controllers/challenges_controller.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/levels/domain/level_models.dart';
import 'package:telly_app/features/levels/presentation/controllers/levels_controller.dart';
import 'package:telly_app/features/profile/presentation/controllers/profile_controller.dart';
import 'package:telly_app/features/queue/domain/streaming_models.dart';
import 'package:telly_app/features/queue/presentation/screens/smart_queue_screen.dart';
import 'package:telly_app/features/tracking/domain/tracking_item.dart';
import 'package:telly_app/features/tracking/domain/tracking_models.dart';

/// A Friday: the weekday rules in SCR-21 §21.3 start on Thursday.
final homeNow = DateTime(2026, 10, 9, 12);

DateTime daysAgo(int days, {DateTime? from}) => (from ?? homeNow).subtract(Duration(days: days));

TrackingItem tracked(
  String title, {
  int? id,
  String mediaType = 'tv',
  TrackingState state = TrackingState.watching,
  int idle = 1,
  DateTime? newSince,
  DateTime? finishedAt,
  bool ranked = false,
  EpisodeRef? next = const EpisodeRef(1, 2),
}) =>
    TrackingItem(
      titleId: id ?? title.hashCode,
      mediaType: mediaType,
      title: title,
      state: state,
      startedAt: daysAgo(100),
      lastProgressAt: daysAgo(idle),
      newEpisodesSince: newSince,
      finishedAt: finishedAt,
      isRanked: ranked,
      place: mediaType == 'movie' ? null : const EpisodeRef(1, 1),
      nextEpisode: next == null ? null : NextEpisode(ref: next),
    );

WatchlistItem queued(String title, {int id = 1, String mediaType = 'movie', String? provider}) => WatchlistItem(
      showId: id,
      title: title,
      mediaType: mediaType,
      addedAt: daysAgo(5),
      availability: [
        if (provider != null)
          ShowStreamingAvailability(
            platformId: provider.toLowerCase(),
            platformName: provider,
            monetizationType: MonetizationType.flatrate,
            webUrl: 'https://example.com',
          ),
      ],
    );

ActivityLog friendActivity(
  String name, {
  String userId = 'u1',
  ActivityType type = ActivityType.rankingCreated,
  String title = 'Andor',
  int titleId = 10,
  String mediaType = 'tv',
  int? rank = 2,
  double? score = 9.4,
  Duration age = const Duration(hours: 2),
}) =>
    ActivityLog(
      id: '$userId-$titleId-${age.inMinutes}',
      userId: userId,
      username: name.toLowerCase(),
      userDisplayName: name,
      activityType: type,
      titleId: titleId,
      titleName: title,
      mediaType: mediaType,
      rankPosition: rank,
      calculatedScore: score,
      createdAt: homeNow.subtract(age),
    );

Challenge challenge({
  String slug = 'heist-month',
  String name = 'Heist Month',
  int target = 8,
  int progress = 4,
  bool joined = true,
  DateTime? endsAt,
  DateTime? completedAt,
}) =>
    Challenge(
      id: slug,
      slug: slug,
      name: name,
      startsAt: daysAgo(20),
      endsAt: endsAt,
      target: target,
      joined: joined,
      myProgress: progress,
      completedAt: completedAt,
    );

/// Fixed canon state for Home tests.
class SeededCanon extends ProfileCanonNotifier {
  SeededCanon(this.seed);
  final ProfileCanonState seed;

  @override
  ProfileCanonState build() => seed;
}

/// A fixed Queue for Home tests.
class SeededQueue extends WatchlistNotifier {
  SeededQueue(this.items);
  final List<WatchlistItem> items;

  @override
  Future<List<WatchlistItem>> build() async => items;
}

/// A fixed level (or a failing one) for Home tests.
class SeededLevel extends YourLevelController {
  SeededLevel(this.level, {this.fail = false});
  final YourLevel level;
  final bool fail;

  @override
  Future<YourLevel> build() async => fail ? throw Exception('offline') : level;
}

/// Fixed challenges (or failing ones) for Home tests.
class SeededChallenges extends ChallengesController {
  SeededChallenges(this.overview, {this.fail = false});
  final ChallengesOverview overview;
  final bool fail;

  @override
  Future<ChallengesOverview> build() async => fail ? throw Exception('offline') : overview;
}

/// A level that can change between reads: whatever [holder] holds when the provider builds.
class SwitchableLevel extends YourLevelController {
  SwitchableLevel(this.holder);
  final List<YourLevel> holder;

  @override
  Future<YourLevel> build() async => holder.single;
}
