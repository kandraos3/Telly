// The screens shown on the website (WEB-02), each with fixture data that reads
// like a real user's. Add a Scene here and reference its id from
// site/content.yaml to put a new screen on the site.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/features/cowatch/data/co_watch_repository.dart';
import 'package:telly_app/features/cowatch/domain/two_to_watch_engine.dart';
import 'package:telly_app/features/cowatch/presentation/screens/two_to_watch_screen.dart';
import 'package:telly_app/features/discovery/data/discovery_repository.dart';
import 'package:telly_app/features/discovery/domain/discovery_models.dart';
import 'package:telly_app/features/discovery/presentation/screens/explore_discover_screen.dart';
import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/feed/presentation/screens/activity_feed_screen.dart';
import 'package:telly_app/features/logging/data/title_repository.dart';
import 'package:telly_app/features/logging/domain/watch_status.dart';
import 'package:telly_app/features/profile/data/graveyard_repository.dart';
import 'package:telly_app/features/profile/data/profile_repository.dart';
import 'package:telly_app/features/profile/domain/canon_stats.dart';
import 'package:telly_app/features/profile/domain/dropped_show.dart';
import 'package:telly_app/features/profile/presentation/controllers/profile_controller.dart';
import 'package:telly_app/features/profile/presentation/screens/dual_canon_profile_screen.dart';
import 'package:telly_app/features/profile/presentation/screens/friend_profile_screen.dart';
import 'package:telly_app/features/profile/presentation/screens/tv_graveyard_screen.dart';
import 'package:telly_app/features/queue/data/streaming_availability_repository.dart';
import 'package:telly_app/features/queue/data/watchlist_repository.dart';
import 'package:telly_app/features/queue/domain/streaming_models.dart';
import 'package:telly_app/features/queue/presentation/screens/smart_queue_screen.dart';
import 'package:telly_app/features/ranking/data/ranking_repository.dart';
import 'package:telly_app/features/ranking/domain/franchise_rollup_service.dart';
import 'package:telly_app/features/ranking/domain/score_curve_calculator.dart';
import 'package:telly_app/features/ranking/domain/sentiment_bracket.dart';
import 'package:telly_app/features/ranking/presentation/controllers/duel_controller.dart';
import 'package:telly_app/features/ranking/presentation/screens/duel_arena_screen.dart';
import 'package:telly_app/features/ranking/presentation/screens/slot_reveal_modal.dart';
import 'package:telly_app/features/sharing/data/story_share_service.dart';
import 'package:telly_app/features/sharing/presentation/screens/telly_wrapped_studio_screen.dart';
import 'package:telly_app/features/squads/data/squad_repository.dart';
import 'package:telly_app/features/squads/domain/squad_models.dart';
import 'package:telly_app/features/squads/presentation/screens/squad_hub_screen.dart';
import 'package:telly_app/features/title_detail/domain/title_detail_models.dart';
import 'package:telly_app/features/title_detail/presentation/screens/show_detail_screen.dart';

import '../../../test/fakes/fake_auth_repository.dart';
import '../../../test/fakes/fake_co_watch_repository.dart';
import '../../../test/fakes/fake_graveyard_repository.dart';
import '../../../test/fakes/fake_profile_repository.dart';
import '../../../test/fakes/fake_social_repository.dart';
import '../../../test/fakes/fake_title_repository.dart';
import '../../../test/fakes/fake_watchlist_repository.dart';
import 'poster_art.dart';
import 'scene_harness.dart';

// --- Fixtures -------------------------------------------------------------

const seriesCanon = [
  'Severance',
  'The Bear',
  'Succession',
  'Shogun',
  'Mad Men',
  'Fleabag',
  'Arcane',
  'Slow Horses',
  'Dark',
  'Ted Lasso',
  'The Last of Us',
  'Andor',
];
const seriesScores = [9.86, 9.61, 9.42, 9.18, 8.97, 8.74, 8.52, 8.21, 7.94, 7.61, 7.12, 6.48];

const movieCanon = [
  'Parasite',
  'Interstellar',
  'Past Lives',
  'Spirited Away',
  'Dune: Part Two',
  'Whiplash',
  'Arrival',
  'Oppenheimer',
];
const movieScores = [9.91, 9.64, 9.33, 9.05, 8.71, 8.36, 7.88, 7.21];

List<CanonEntry> canonEntries(String mediaType, List<String> titles, List<double> scores, {int idOffset = 0}) => [
      for (var i = 0; i < titles.length; i++)
        CanonEntry(
          id: (mediaType == 'tv' ? 1000 : 2000) + idOffset + i,
          title: titles[i],
          mediaType: mediaType,
          rankPosition: i + 1,
          calculatedScore: scores[i],
          posterPath: posterPathFor(titles[i]),
          isAnime: titles[i] == 'Arcane',
        ),
    ];

/// Writes a synced canon to the local database (the duel arena reads it there).
Future<void> seedLocalCanon(AppDatabase db, String mediaType, List<String> titles, {required int baseId}) =>
    db.localRankingDao.updateBatchRanks([
      for (var i = 0; i < titles.length; i++)
        LocalRankingsCompanion.insert(
          showId: baseId + i,
          mediaType: mediaType,
          title: titles[i],
          posterPath: Value(posterPathFor(titles[i])),
          rankPosition: i + 1,
          calculatedScore: ScoreCurveCalculator.calculateRoundedScore(i + 1, titles.length),
          syncStatus: const Value('SYNCED'),
        ),
    ]);

ActivityLog activity(
  String id, {
  required String user,
  required String title,
  required int minutesAgo,
  int rank = 2,
  double score = 9.61,
  bool upset = false,
  String? over,
  int? overRank,
  String? review,
  List<String> tags = const [],
  Map<FeedReaction, int> reactions = const {},
}) =>
    ActivityLog(
      id: id,
      userId: 'u-$user',
      username: user,
      userDisplayName: user[0].toUpperCase() + user.substring(1),
      activityType: upset ? ActivityType.upsetAlert : ActivityType.rankingCreated,
      titleId: 3000 + id.codeUnits.last,
      titleName: title,
      titlePosterUrl: posterPathFor(title),
      mediaType: 'tv',
      rankPosition: rank,
      calculatedScore: score,
      microReview: review,
      vibeTags: tags,
      isUpset: upset,
      upsetDelta: upset ? 0.31 : 0,
      upsetOverTitleName: over,
      upsetOverTitlePoster: over == null ? null : posterPathFor(over),
      upsetOverTitleRank: overRank,
      reactions: reactions,
      createdAt: DateTime(2026, 10, 3, 12).subtract(Duration(minutes: minutesAgo)),
    );

class _SeededProfileCanon extends ProfileCanonNotifier {
  @override
  ProfileCanonState build() => ProfileCanonState(
        movies: canonEntries('movie', movieCanon, movieScores),
        series: canonEntries('tv', seriesCanon, seriesScores),
      );
}

FakeProfileRepository _profiles() {
  final repo = FakeProfileRepository();
  repo.stats['tv'] = const CanonStats(
    mediaType: 'tv',
    totalTitles: 12,
    totalMinutes: 492 * 60,
    hoursEstimated: true,
    topGenre: StatLeader(name: 'Drama', count: 9, percent: 75),
    topCreator: StatLeader(name: 'HBO', count: 4),
  );
  repo.stats['movie'] = const CanonStats(
    mediaType: 'movie',
    totalTitles: 8,
    totalMinutes: 8 * 142,
    topGenre: StatLeader(name: 'Sci-Fi', count: 4, percent: 50),
    topCreator: StatLeader(name: 'Denis Villeneuve', count: 2),
  );
  repo.profiles['jordan'] = const PublicProfile(
    id: 'u-jordan',
    username: 'jordan',
    displayName: 'Jordan Mills',
    bio: 'Prestige TV evangelist. Will defend Mad Men season 4 forever.',
  );
  repo.canons[('u-jordan', 'tv')] = canonEntries(
    'tv',
    const ['Succession', 'Mad Men', 'Severance', 'The Bear', 'Fleabag', 'Andor', 'Dark', 'Shogun'],
    const [9.88, 9.70, 9.52, 9.31, 9.02, 8.66, 8.12, 7.44],
    idOffset: 100,
  );
  repo.canons[('u-jordan', 'movie')] =
      canonEntries('movie', const ['Interstellar', 'Parasite', 'Arrival'], const [9.8, 9.5, 8.9], idOffset: 100);
  repo.matches[('u-jordan', 'tv')] = const CanonMatch(87, 9);
  repo.matches[('u-jordan', 'movie')] = const CanonMatch(72, 3);
  return repo;
}

FakeSocialRepository _social() => FakeSocialRepository(feed: [
      activity(
        'a1',
        user: 'jordan',
        title: 'Severance',
        minutesAgo: 4,
        rank: 1,
        score: 9.86,
        upset: true,
        over: 'Succession',
        overRank: 2,
        reactions: {FeedReaction.fire: 12, FeedReaction.masterpiece: 5, FeedReaction.stunned: 3},
      ),
      activity(
        'a2',
        user: 'maya',
        title: 'Shogun',
        minutesAgo: 38,
        rank: 3,
        score: 9.18,
        review: 'Every frame a painting. Toranaga is playing chess while everyone else plays checkers.',
        tags: const ['Cinematography Peak', 'Slow Burn'],
        reactions: {FeedReaction.cinema: 7, FeedReaction.kudos: 2},
      ),
      activity('a3', user: 'sam', title: 'Arcane', minutesAgo: 95, rank: 5, score: 8.84),
    ]);

FakeWatchlistRepository _watchlist() {
  final repo = FakeWatchlistRepository();
  for (final (i, title) in const ['Andor', 'Slow Horses', 'The Last of Us', 'Dark', 'Mad Men'].indexed) {
    repo.items.add(WatchlistEntry(
      titleId: 4000 + i,
      mediaType: 'tv',
      title: title,
      posterPath: posterPathFor(title),
      savedAt: DateTime(2026, 10, 1).subtract(Duration(days: i)),
    ));
  }
  return repo;
}

ShowStreamingAvailability _on(String id, String name, {bool leaving = false}) => ShowStreamingAvailability(
      platformId: id,
      platformName: name,
      monetizationType: MonetizationType.flatrate,
      webUrl: 'https://example.com',
      isLeavingSoon: leaving,
      availableUntil: leaving ? DateTime(2026, 10, 31) : null,
    );

/// Smart Queue rows with friends' scores and where to watch.
final queueItems = [
  for (final (i, (title, seasons, episodes, avg, friends, from, provider, leaving)) in [
    ('Andor', 2, 24, 9.12, 7, '@jordan', _on('disney_plus', 'Disney+'), false),
    ('Slow Horses', 4, 24, 8.94, 6, '@maya', _on('apple_tv_plus', 'Apple TV+'), false),
    ('The Leftovers', 3, 28, 9.30, 4, '@sam', _on('max', 'Max', leaving: true), true),
    ('Dark', 3, 26, 8.71, 5, '@maya', _on('netflix', 'Netflix'), false),
  ].indexed)
    WatchlistItem(
      showId: 4000 + i,
      title: title,
      posterPath: posterPathFor(title),
      mediaType: 'tv',
      seasonCount: seasons,
      episodeCount: episodes,
      friendsAvgScore: avg,
      friendsCount: friends,
      savedFromHandle: from,
      availability: [provider],
      isLeavingSoon: leaving,
      addedAt: DateTime(2026, 10, 1).subtract(Duration(days: i)),
    ),
];

class _StreamingFake implements StreamingAvailabilityRepository {
  @override
  Future<List<ShowStreamingAvailability>> getAvailability(
          {required int titleId, required String mediaType, String? country}) async =>
      [
        const ShowStreamingAvailability(
          platformId: 'apple_tv_plus',
          platformName: 'Apple TV+',
          monetizationType: MonetizationType.flatrate,
          webUrl: 'https://tv.apple.com',
        ),
        if (titleId.isEven)
          ShowStreamingAvailability(
            platformId: 'max',
            platformName: 'Max',
            monetizationType: MonetizationType.flatrate,
            webUrl: 'https://max.com',
            availableUntil: DateTime(2026, 10, 31),
            isLeavingSoon: true,
          ),
      ];
}

SquadMember _member(String id, String name, SquadRole role) => SquadMember(
      userId: 'u-$id',
      username: id,
      displayName: name,
      role: role,
      joinedAt: DateTime(2026, 3, 1),
    );

class _SquadFake implements SquadRepository {
  static final squad = Squad(
    id: 'sq-1',
    name: 'Prestige TV Club',
    createdBy: 'u-me',
    description: 'Sunday night dramas, ranked without mercy.',
    members: [
      _member('me', 'Alex Rivera', SquadRole.owner),
      _member('jordan', 'Jordan Mills', SquadRole.admin),
      _member('maya', 'Maya Chen', SquadRole.member),
      _member('sam', 'Sam Okafor', SquadRole.member),
    ],
    memberTotal: 6,
    myRole: SquadRole.owner,
    createdAt: DateTime(2026, 3, 1),
  );

  @override
  Future<List<Squad>> mySquads() async => [squad];

  @override
  Future<Squad> fetchSquad(String squadId) async => squad;

  @override
  Future<List<SquadConsensusItem>> consensus(Squad squad, String mediaType) async => [
        for (final (i, (title, low)) in const [
          ('Succession', 3),
          ('Severance', 4),
          ('The Bear', 2),
          ('Mad Men', 14),
          ('Shogun', 6),
          ('Fleabag', 8),
        ].indexed)
          SquadConsensusItem(
            consensusRank: i + 1,
            titleId: 5000 + i,
            title: title,
            posterUrl: posterPathFor(title),
            releaseYear: 2020,
            mediaType: mediaType,
            totalBordaPoints: 120 - i * 11,
            championUserId: 'u-jordan',
            championDisplayName: 'Jordan',
            championRank: 1,
            lowestUserId: 'u-sam',
            lowestDisplayName: 'Sam',
            lowestRank: low,
            membersRankedCount: 5,
            rankVariance: (low - 1).toDouble(),
          ),
      ];

  @override
  Future<List<SharedWatchlistItem>> sharedWatchlist(String squadId) async => const [];

  @override
  Future<Squad> create({required String name, String? description}) async => squad;

  @override
  Future<void> addMember({required String squadId, required String userId}) async {}

  @override
  Future<SquadInvitee?> findInvitee(String query) async => null;

  @override
  Future<void> deleteSquad(String squadId) async {}

  @override
  Future<void> leaveSquad(String squadId) async {}
}

FakeGraveyardRepository _graveyard() {
  final repo = FakeGraveyardRepository();
  for (final (i, (title, season, episode, reason)) in const [
    ('The Walking Dead', 7, 4, DropReasonTaxonomy.jumpedShark),
    ('Westworld', 3, 2, DropReasonTaxonomy.pacingSlowed),
    ('Lost', 4, 9, DropReasonTaxonomy.timeCommitment),
  ].indexed) {
    repo.shows.add(DroppedShow(
      id: 'd$i',
      userId: 'u-me',
      titleId: 6000 + i,
      title: title,
      posterUrl: posterPathFor(title),
      releaseYear: 2010 + i * 3,
      droppedAtSeason: season,
      droppedAtEpisode: episode,
      reason: reason,
      willingToRevisit: i == 1,
      createdAt: DateTime(2026, 9, 20 - i),
    ));
  }
  return repo;
}

FakeDiscoveryRepository _discovery() => FakeDiscoveryRepository(
      recommended: [
        RecommendedTitle(
          titleId: 7001,
          mediaType: 'tv',
          title: 'Better Call Saul',
          posterPath: posterPathFor('Better Call Saul'),
          network: 'AMC',
          communityScore: 9.48,
          reason: RecommendationReason.becauseYouLoved,
          reasonTitle: 'Succession',
        ),
        RecommendedTitle(
          titleId: 7002,
          mediaType: 'tv',
          title: 'The Leftovers',
          posterPath: posterPathFor('The Leftovers'),
          network: 'HBO',
          communityScore: 9.12,
          reason: RecommendationReason.becauseYouLoved,
          reasonTitle: 'Severance',
        ),
      ],
      trending: [
        for (final (i, title) in const ['Pluribus', 'Slow Horses', 'Blue Eye Samurai', 'Hacks'].indexed)
          RecommendedTitle(
            titleId: 7100 + i,
            mediaType: 'tv',
            title: title,
            posterPath: posterPathFor(title),
            releaseYear: 2025,
            reason: RecommendationReason.trending,
          ),
      ],
      friendsBinging: [
        FriendBingingItem(
          titleId: 7201,
          mediaType: 'tv',
          title: 'Shogun',
          posterPath: posterPathFor('Shogun'),
          network: 'FX / Hulu',
          communityScore: 9.31,
          activeFriendCount: 8,
          avgFriendScore: 9.31,
          friendAvatars: const [
            FriendAvatarInfo(id: 'u1', username: 'jordan', displayName: 'Jordan'),
            FriendAvatarInfo(id: 'u2', username: 'maya', displayName: 'Maya'),
          ],
        ),
      ],
    );

FakeCoWatchRepository _coWatch() => FakeCoWatchRepository(
      partners: const [CoWatchPartner(userId: 'u-jordan', username: 'jordan', displayName: 'Jordan Mills')],
      streaming: const SharedStreaming(shared: {'max', 'apple_tv_plus'}, mineSet: true, partnerSet: true),
      pools: {
        'movie': [
          for (final (i, (title, runtime, genre)) in const [
            ('Past Lives', 106, 'drama'),
            ('Arrival', 116, 'science_fiction'),
            ('Aftersun', 101, 'drama'),
            ('Heat', 170, 'crime'),
          ].indexed)
            CoWatchCandidate(
              showId: 8000 + i,
              title: title,
              mediaType: 'movie',
              runtimeMinutes: runtime,
              posterPath: posterPathFor(title),
              network: 'A24',
              availableProviders: const ['max'],
              vibeTags: [genre],
              inWatchlistA: i == 0,
              inWatchlistB: i < 2,
              ratingB: i == 1 ? 9.4 : null,
              communityScore: 8.9 - i * 0.2,
            ),
        ],
      },
    );

/// Providers every scene shares: fakes for the network, generated posters.
List<Override> baseOverrides(AppDatabase db) => [
      databaseProvider.overrideWithValue(db),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(
        signedInUserId: 'u-me',
        profile: UserProfile(id: 'u-me', username: 'alexr', displayName: 'Alex Rivera', createdAt: DateTime(2026)),
      )),
      titleRepositoryProvider.overrideWithValue(FakeTitleRepository()),
      socialRepositoryProvider.overrideWithValue(_social()),
      profileRepositoryProvider.overrideWithValue(_profiles()),
      profileCanonProvider.overrideWith(_SeededProfileCanon.new),
      watchlistRepositoryProvider.overrideWithValue(_watchlist()),
      streamingAvailabilityRepositoryProvider.overrideWithValue(_StreamingFake()),
      squadRepositoryProvider.overrideWithValue(_SquadFake()),
      graveyardRepositoryProvider.overrideWithValue(_graveyard()),
      discoveryRepositoryProvider.overrideWithValue(_discovery()),
      coWatchRepositoryProvider.overrideWithValue(_coWatch()),
      storyShareServiceProvider.overrideWithValue(FakeStoryShareService()),
      posterNetworkImagesProvider.overrideWithValue(false),
      posterArtProvider.overrideWithValue(posterArtFor),
      hapticsEnabledProvider.overrideWith((ref) => false),
    ];

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

Future<void> scrollBy(WidgetTester tester, double dy) async {
  await tester.drag(find.byType(Scrollable).first, Offset(0, -dy));
  await tester.pumpAndSettle();
}

// --- Scenes ---------------------------------------------------------------

final siteScenes = <Scene>[
  Scene(
    id: 'duel',
    seed: (db) => seedLocalCanon(db, 'tv', seriesCanon.skip(2).toList(), baseId: 1002),
    build: () => DuelArenaScreen(
      request: DuelRequest(
        candidate: CanonCandidate(
          titleId: 1001,
          mediaType: 'tv',
          title: 'The Bear',
          posterPath: posterPathFor('The Bear'),
        ),
        bracket: SentimentBracket.masterpiece,
        status: WatchStatus.finished,
      ),
      onDuelComplete: (_) {},
    ),
    overrides: baseOverrides,
  ),
  Scene(
    id: 'reveal',
    build: () => SlotRevealModal(
      showId: 1001,
      title: 'The Bear',
      mediaType: 'tv',
      posterPath: posterPathFor('The Bear'),
      rankPosition: 2,
      totalInCanon: 48,
      targetScore: 9.61,
      justBehindTitles: const ['Severance (#1)'],
      beatingTitles: const ['Succession (#3)', 'Shogun (#4)'],
      leaderboard: [
        for (var i = 0; i < 5; i++)
          RevealLeaderboardEntry(
            rank: i + 1,
            title: seriesCanon[i],
            posterPath: posterPathFor(seriesCanon[i]),
            score: seriesScores[i],
            isNew: i == 1,
          ),
      ],
      onViewInCanon: () {},
    ),
    overrides: baseOverrides,
  ),
  Scene(
    id: 'canon',
    tab: 2,
    build: () => const DualCanonProfileScreen(),
    overrides: baseOverrides,
    interact: (tester) => tapText(tester, 'TV Shows (12)'),
  ),
  Scene(
    id: 'tiers',
    tab: 2,
    build: () => const DualCanonProfileScreen(),
    overrides: baseOverrides,
    interact: (tester) async {
      await tapText(tester, 'TV Shows (12)');
      await tapText(tester, 'Tiers');
      await scrollBy(tester, 560);
    },
  ),
  Scene(id: 'feed', tab: 3, build: () => const ActivityFeedScreen(), overrides: baseOverrides),
  Scene(id: 'explore', tab: 1, build: () => const ExploreDiscoverScreen(), overrides: baseOverrides),
  Scene(
    id: 'queue',
    build: () => SmartQueueScreen(testItems: queueItems),
    overrides: baseOverrides,
    interact: (tester) => tapText(tester, 'TV Shows (${queueItems.length})'),
  ),
  Scene(
    id: 'taste-match',
    build: () => const FriendProfileScreen(handle: 'jordan'),
    overrides: baseOverrides,
  ),
  Scene(
    id: 'two-to-watch',
    build: () => const TwoToWatchScreen(
      friendId: 'u-jordan',
      friendHandle: 'jordan',
      friendDisplayName: 'Jordan Mills',
    ),
    overrides: baseOverrides,
    interact: (tester) async {
      await tapText(tester, 'Anything good');
      await scrollBy(tester, 520);
    },
  ),
  Scene(
    id: 'squad',
    build: () => const SquadHubScreen(squadId: 'sq-1'),
    overrides: baseOverrides,
    interact: (tester) => tapText(tester, 'TV Shows'),
  ),
  Scene(
    id: 'title',
    build: () => ShowDetailScreen(
      titleId: 1000,
      mediaType: 'tv',
      initialTitle: TitleDetail(
        id: 1000,
        mediaType: 'tv',
        title: 'Severance',
        overview: 'Mark leads a team of office workers whose memories have been surgically divided '
            'between their work and personal lives.',
        posterPath: posterPathFor('Severance'),
        network: 'Apple TV+',
        communityScore: 9.34,
        numberOfSeasons: 2,
        numberOfEpisodes: 19,
        genres: const ['Drama', 'Mystery', 'Sci-Fi'],
        releaseDate: DateTime(2022, 2, 18),
        seasons: const [
          TitleSeasonDetail(seasonNumber: 1, name: 'Season 1', episodeCount: 9, airDate: '2022-02-18'),
          TitleSeasonDetail(seasonNumber: 2, name: 'Season 2', episodeCount: 10, airDate: '2025-01-17'),
        ],
      ),
    ),
    overrides: baseOverrides,
    interact: (tester) => scrollBy(tester, 200),
  ),
  Scene(id: 'graveyard', build: () => const TvGraveyardScreen(), overrides: baseOverrides),
  Scene(id: 'wrapped', build: () => const TellyWrappedStudioScreen(), overrides: baseOverrides),
];
