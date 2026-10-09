import 'package:telly_app/features/challenges/domain/challenge.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/queue/domain/streaming_models.dart';
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
