import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/features/challenges/domain/challenge.dart';
import 'package:telly_app/features/challenges/presentation/controllers/challenges_controller.dart';
import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/home/domain/home_hero.dart';
import 'package:telly_app/features/home/domain/home_moves.dart';
import 'package:telly_app/features/home/presentation/providers/home_providers.dart';
import 'package:telly_app/features/levels/domain/level_models.dart';
import 'package:telly_app/features/levels/presentation/controllers/levels_controller.dart';
import 'package:telly_app/features/profile/presentation/controllers/profile_controller.dart';
import 'package:telly_app/features/queue/domain/streaming_models.dart';
import 'package:telly_app/features/queue/presentation/screens/smart_queue_screen.dart';
import 'package:telly_app/features/ranking/domain/franchise_rollup_service.dart';
import 'package:telly_app/features/tracking/data/tracking_repository.dart';
import 'package:telly_app/features/tracking/domain/tracking_item.dart';
import 'package:telly_app/features/tracking/domain/tracking_models.dart';
import 'package:telly_app/features/tracking/presentation/providers/tracking_providers.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_social_repository.dart';
import '../../fakes/fake_tracking_repository.dart';
import '../levels/levels_fixtures.dart';
import 'home_fixtures.dart';

class _Canon extends ProfileCanonNotifier {
  _Canon(this.seed);
  final ProfileCanonState seed;

  @override
  ProfileCanonState build() => seed;
}

class _Queue extends WatchlistNotifier {
  _Queue(this.items);
  final List<WatchlistItem> items;

  @override
  Future<List<WatchlistItem>> build() async => items;
}

class _Level extends YourLevelController {
  _Level(this.level, {this.fail = false});
  final YourLevel level;
  final bool fail;

  @override
  Future<YourLevel> build() async => fail ? throw Exception('offline') : level;
}

class _Challenges extends ChallengesController {
  _Challenges(this.overview, {this.fail = false});
  final ChallengesOverview overview;
  final bool fail;

  @override
  Future<ChallengesOverview> build() async => fail ? throw Exception('offline') : overview;
}

/// A feed that answers only when [release] is called.
class _SlowSocial extends FakeSocialRepository {
  _SlowSocial(List<ActivityLog> feed) : super(feed: feed);
  final gate = Completer<void>();

  @override
  Future<FeedPage> getFeedPage({required FeedFilter filter, ActivityLog? after, int limit = 20}) async {
    await gate.future;
    return super.getFeedPage(filter: filter, after: after, limit: limit);
  }
}

// SCR-21 §21.5, §21.6: Home's state, derived from the app's existing providers.
void main() {
  ProviderContainer build({
    List<TrackingItem> tracking = const [],
    List<WatchlistItem> queue = const [],
    ProfileCanonState canon = const ProfileCanonState(),
    YourLevel? level,
    bool levelFails = false,
    ChallengesOverview overview = const ChallengesOverview(),
    bool challengesFail = false,
    SocialRepository? social,
    FakeTrackingRepository? repo,
  }) {
    final c = ProviderContainer(overrides: [
      trackingRepositoryProvider.overrideWithValue(repo ?? FakeTrackingRepository(tracking)),
      trackingNowProvider.overrideWithValue(() => homeNow),
      homeRandomProvider.overrideWithValue(Random(4)),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(
        signedInUserId: 'u-me',
        profile: UserProfile(
          id: 'u-me',
          username: 'me',
          displayName: 'Me',
          onboardingCompleted: true,
          createdAt: DateTime(2026),
        ),
      )),
      profileCanonProvider.overrideWith(() => _Canon(canon)),
      userWatchlistProvider.overrideWith(() => _Queue(queue)),
      yourLevelControllerProvider.overrideWith(() => _Level(level ?? sampleLevel(), fail: levelFails)),
      challengesControllerProvider.overrideWith(() => _Challenges(overview, fail: challengesFail)),
      socialRepositoryProvider.overrideWithValue(social ?? FakeSocialRepository()),
    ]);
    addTearDown(c.dispose);
    // Home is watched for as long as the screen is up.
    c.listen(homeStateProvider, (_, __) {}, fireImmediately: true);
    return c;
  }

  Future<HomeState> settled(ProviderContainer c) async {
    await pumpEventQueue(times: 40);
    return c.read(homeStateProvider);
  }

  CanonEntry entry(int id, String type, int rank, double score) =>
      CanonEntry(id: id, title: 'T$id', mediaType: type, rankPosition: rank, calculatedScore: score);

  test('reads loading before the local sources answer', () {
    final c = build(tracking: [tracked('A')]);
    final state = c.read(homeStateProvider);
    expect(state.heroLoading, isTrue);
    expect(state.movesLoading, isTrue);
  });

  test('derives the hero, chips, streak and friends line from the sources', () async {
    final c = build(
      tracking: [tracked('Severance', id: 1, idle: 0), tracked('Slow Horses', id: 2, idle: 2)],
      social: FakeSocialRepository(feed: [fakeActivity('a1', username: 'maya')]),
    );
    final state = await settled(c);
    expect(state.heroLoading, isFalse);
    expect(state.hero.mode, HomeHeroMode.watching);
    expect(state.hero.item!.title, 'Severance');
    expect(state.hero.chips.map((t) => t.title), ['Slow Horses']);
    expect(state.streakWeeks, 6);
    expect(state.friends!.title, 'Maya');
  });

  test('moves come from every source: streak, joined challenge, friend compare, Queue', () async {
    final c = build(
      tracking: [tracked('Lead', id: 1, idle: 0)],
      canon: ProfileCanonState(series: [entry(110492, 'tv', 5, 9.08)]),
      queue: [queued('Dune', id: 3, provider: 'Max')],
      overview: ChallengesOverview(
        yours: [challenge(progress: 7)],
        featured: challenge(slug: 'feat', name: 'Featured', progress: 7, joined: true),
        joinNext: [challenge(slug: 'other', name: 'Other', progress: 7, joined: false)],
      ),
      social: FakeSocialRepository(feed: [fakeActivity('a1', username: 'maya', minutesAgo: 0)]),
    );
    final state = await settled(c);
    final kinds = state.moves.map((m) => m.kind).toList();
    expect(kinds, containsAll([HomeMoveKind.streakAtRisk, HomeMoveKind.challenge, HomeMoveKind.queuePick]));
    expect(state.moves.where((m) => m.kind == HomeMoveKind.challenge).map((m) => m.challengeSlug), ['heist-month', 'feat'],
        reason: 'joined challenges only, the featured one included');
    expect(kinds, isNot(contains(HomeMoveKind.friendCompare)), reason: 'the feed item is older than 3 days');
  });

  test('a failed level and challenges count as empty and never throw', () async {
    final c = build(
      tracking: [tracked('Lead', id: 1, idle: 0)],
      levelFails: true,
      challengesFail: true,
      overview: ChallengesOverview(yours: [challenge(progress: 7)]),
    );
    final state = await settled(c);
    expect(state.streakWeeks, 0);
    expect(state.moves.map((m) => m.kind), isNot(contains(HomeMoveKind.streakAtRisk)));
    expect(state.moves.map((m) => m.kind), isNot(contains(HomeMoveKind.challenge)));
  });

  test('a new user gets the welcome hero and the track and find-friends moves', () async {
    final state = await settled(build(level: sampleLevel(streak: 0), social: FakeSocialRepository()));
    expect(state.hero.mode, HomeHeroMode.newUser);
    expect(state.moves.map((m) => m.kind), [HomeMoveKind.startTracking, HomeMoveKind.findFriends]);
    expect(state.friends, isNull);
  });

  test('the hero follows tracking at once', () async {
    final repo = FakeTrackingRepository([tracked('Lead', id: 1, idle: 0)]);
    final c = build(repo: repo);
    expect((await settled(c)).hero.item!.title, 'Lead');

    repo.items = [tracked('Other', id: 2, idle: 0)];
    expect((await settled(c)).hero.item!.title, 'Other');
  });

  test('moves stay put when data changes, and re-derive on refresh', () async {
    final done = tracked('Done A', id: 10, state: TrackingState.finished, finishedAt: daysAgo(3));
    final repo = FakeTrackingRepository([tracked('Lead', id: 1, idle: 0), done]);
    final c = build(
      repo: repo,
      level: sampleLevel(streak: 0),
      social: FakeSocialRepository(feed: [fakeActivity('a1', username: 'maya')]),
    );
    expect((await settled(c)).moves.map((m) => m.titleId), [10]);

    repo.items = [
      tracked('Lead', id: 1, idle: 0),
      done,
      tracked('Done B', id: 11, state: TrackingState.finished, finishedAt: daysAgo(0)),
    ];
    expect((await settled(c)).moves.map((m) => m.titleId), [10], reason: 'frozen while on screen');

    c.read(homeStateProvider.notifier).refresh();
    expect((await settled(c)).moves.map((m) => m.titleId), [11, 10], reason: 'newest finish leads after a refresh');
  });

  test('↻ Another re-rolls only Home\'s pick, never the Queue screen\'s', () async {
    final queue = [for (var i = 1; i <= 4; i++) queued('Film $i', id: i)];
    final c = build(queue: queue);
    c.listen(queueUpNextProvider, (_, __) {});
    final first = (await settled(c)).hero.queuePick!;
    expect((await settled(c)).hero.queuePick!.title, first.title, reason: 'the pick is kept');

    final queueScreenPick = c.read(queueUpNextProvider.notifier).pickFor('movie', [for (final i in queue) i.showId]);
    c.read(homeStateProvider.notifier).shuffleQueuePick();
    final second = (await settled(c)).hero.queuePick!;
    expect(second.title, isNot(first.title));
    expect(c.read(queueUpNextProvider.notifier).pickFor('movie', [for (final i in queue) i.showId]), queueScreenPick);
  });

  test('a slow feed does not hold Home back, and the find-friends move waits for it', () async {
    final social = _SlowSocial([fakeActivity('a1', username: 'maya', minutesAgo: 0)]);
    final c = build(tracking: [tracked('Lead', id: 1, idle: 0)], social: social);
    var state = await settled(c);
    expect(state.movesLoading, isFalse);
    expect(state.moves.map((m) => m.kind), isNot(contains(HomeMoveKind.findFriends)));
    expect(state.friends, isNull);

    social.gate.complete();
    state = await settled(c);
    expect(state.friends!.title, 'Maya');
    expect(state.moves.map((m) => m.kind), isNot(contains(HomeMoveKind.findFriends)));
  });

  test('the find-friends move shows once the feed answers with nobody else', () async {
    final c = build(
      tracking: [tracked('Lead', id: 1, idle: 0)],
      level: sampleLevel(streak: 0),
      social: FakeSocialRepository(feed: [fakeActivity('mine', userId: 'u-me', username: 'me')]),
    );
    final state = await settled(c);
    expect(state.moves.map((m) => m.kind), [HomeMoveKind.findFriends]);
  });
}
