// CUJ-05 gamification journeys (#149, epic #50; features/10 §2, §4, §6, §8). Shared by the device
// suite (integration_test/cuj_05_gamification_test.dart) and the host runner
// (test/integration/gamification_journeys_test.dart), so they also run on every `flutter test`.
//
// The client is real end to end: rankings go through RankingRepository into Drift's offline queue,
// the SyncEngine flushes them, and the screens react. Only the server is faked: [GameServer]
// applies the rules the RPCs implement (and pgTAP 021–030 verify): a ranking qualifies only
// when the title was placed through duels, qualifying rankings unlock medals, earn 10 XP and
// count toward joined challenges.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/app.dart';
import 'package:telly_app/core/config/app_config.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/core/router/app_router.dart';
import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/sync/connectivity_signal.dart';
import 'package:telly_app/core/sync/mutation_transport.dart';
import 'package:telly_app/features/achievements/data/achievements_repository.dart';
import 'package:telly_app/features/achievements/domain/medal.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/features/challenges/data/challenges_repository.dart';
import 'package:telly_app/features/challenges/domain/challenge.dart';
import 'package:telly_app/features/challenges/presentation/controllers/challenges_controller.dart';
import 'package:telly_app/features/discovery/data/discovery_repository.dart';
import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/feed/presentation/widgets/challenge_activity_card.dart';
import 'package:telly_app/features/levels/data/levels_repository.dart';
import 'package:telly_app/features/levels/domain/level_models.dart';
import 'package:telly_app/features/ranking/data/canon_hydration.dart';
import 'package:telly_app/features/ranking/data/ranking_repository.dart';

import '../../test/fakes/fake_auth_repository.dart';
import '../../test/fakes/fake_social_repository.dart';
import '../../test/features/achievements/achievements_fixtures.dart';
import '../../test/features/challenges/challenges_fixtures.dart';
import '../../test/features/levels/levels_fixtures.dart';

const _me = 'usr_cuj05';

class _EmptyRemoteCanon implements RemoteCanonSource {
  @override
  Future<List<RemoteRanking>> fetchMyCanon(String userId) async => const [];
}

/// The server side of the journeys: the sync transport plus what my_achievements, my_level and
/// the challenge RPCs would return.
class GameServer implements MutationTransport, AchievementsRepository {
  GameServer({this.qualifying = 0, this.medalTarget = 10});

  int qualifying;
  final int medalTarget;
  final rankedTitles = <int>{};
  final seen = <String>{};
  final pinned = <String, int>{};
  final unlockedAt = <String, DateTime>{};

  late final challenges = _ServerChallenges(this);
  late final levels = _ServerLevels(this);
  final social = FakeSocialRepository(me: _me);

  int get xp => qualifying * 10;

  @override
  Future<void> apply(PendingMutation m) async {
    if (m.kind != MutationKind.logTitle) return;
    final p = jsonDecode(m.payload) as Map<String, dynamic>;
    final titleId = p['title_id'] as int;
    // Spec 10 §2: only a title placed through duels qualifies, and only the first time.
    final placed = [for (final d in (p['duels'] as List? ?? const [])) (d as Map)['placed_title_id']];
    if (!placed.contains(titleId) || !rankedTitles.add(titleId)) return;
    qualifying++;
    if (qualifying >= medalTarget) unlockedAt.putIfAbsent('movies_10', DateTime.now);
    challenges.onQualifying();
  }

  @override
  Future<AchievementsSnapshot> fetch() async {
    Medal medal(Map<String, dynamic> row) {
      final id = row['id'] as String;
      return Medal.fromJson({
        ...row,
        'unlocked_at': unlockedAt[id]?.toIso8601String(),
        'seen_at': seen.contains(id) ? DateTime.now().toIso8601String() : null,
        'pinned_slot': pinned[id],
      });
    }

    return AchievementsSnapshot(
      medals: [
        medal(medalRow('movies_10', name: 'Ticket Stub', threshold: medalTarget, progress: qualifying)),
        for (final c in challenges.completed)
          medal(medalRow('challenge_${c.slug}', kind: 'challenge', tier: 'special', name: c.name,
              description: c.description, glyph: c.medalGlyph, threshold: c.target, progress: c.target)),
      ],
      streak: const WeeklyStreak(currentWeeks: 1, bestWeeks: 1),
      savedAt: DateTime.now(),
    );
  }

  @override
  Future<void> pin(String achievementId, int slot) async {
    pinned.removeWhere((_, s) => s == slot);
    pinned[achievementId] = slot;
  }

  @override
  Future<void> unpin(int slot) async => pinned.removeWhere((_, s) => s == slot);

  @override
  Future<void> markSeen(List<String> achievementIds) async => seen.addAll(achievementIds);

  @override
  Future<MedalShowcase> fetchShowcase(String userId) async => MedalShowcase.of((await fetch()).medals);

  @override
  Future<Map<String, MedalRarity>> fetchRarity() async => const {};

  @override
  Future<List<StillToWatch>> fetchStillToWatch(int collectionId) async => const [];
}

/// One challenge, Spooktober with a target of 2, to join and finish.
class _ServerChallenges extends FakeChallengesRepository {
  _ServerChallenges(this.server)
      : super(mine: const [], discover: [challenge('spooktober', name: 'Spooktober', target: 2, glyph: '2')]);

  final GameServer server;
  final completed = <Challenge>[];
  int _progress = 0;

  @override
  Future<int> join(String challengeId) async {
    joined.add(challengeId);
    final c = discoverList.firstWhere((c) => c.id == challengeId);
    discoverList = [for (final d in discoverList) if (d.id != challengeId) d];
    mineList = [...mineList, c.copyWith(joined: true, myProgress: 0)];
    return 0;
  }

  /// Rankings after joining count toward it; reaching the target completes it, grants its
  /// medal and posts the CHALLENGE_COMPLETED card to friends' feeds (features/10 §8.2, §10).
  void onQualifying() {
    if (mineList.isEmpty) return;
    final c = mineList.single;
    if (c.completedAt != null) return;
    _progress++;
    if (_progress < c.target) {
      mineList = [c.copyWith(myProgress: _progress)];
      return;
    }
    mineList = [challenge(c.slug, name: c.name, target: c.target, glyph: c.medalGlyph, joined: true,
        progress: c.target, completed: true)];
    completed.add(c);
    server.unlockedAt['challenge_${c.slug}'] = DateTime.now();
    server.social.feed.insert(
      0,
      ActivityLog(
        id: 'cc-${c.slug}',
        userId: _me,
        username: 'gamer',
        userDisplayName: 'Gamer',
        activityType: ActivityType.challengeCompleted,
        titleId: 0,
        titleName: 'The Thing',
        challenge: FeedChallenge(
            challengeId: c.id, slug: c.slug, name: c.name, count: c.target, medalGlyph: c.medalGlyph,
            bestTitle: 'The Thing', bestRank: 1, bestScore: 9.4),
        createdAt: DateTime.now(),
      ),
    );
  }
}

/// my_level from the server's XP: level L starts at 125 × L × (L − 1) XP (features/10 §5.1).
class _ServerLevels extends FakeLevelsRepository {
  _ServerLevels(this.server);
  final GameServer server;

  @override
  Future<YourLevel> fetch() async {
    final xp = server.xp;
    var level = 1;
    while (125 * (level + 1) * level <= xp) {
      level++;
    }
    final base = sampleLevel(level: level, total: xp, questDone: false);
    return YourLevel(
      level: LevelInfo(
        level: level,
        name: base.level.name,
        totalXp: xp,
        floor: 125 * level * (level - 1),
        ceiling: 125 * (level + 1) * level,
        weekXp: xp,
      ),
      streak: base.streak,
      quests: base.quests,
    );
  }
}

/// Launches the whole app, signed in and onboarded, against [server].
Future<ProviderContainer> launchAgainst(WidgetTester tester, GameServer server) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db = AppDatabase.inMemory();
  addTearDown(db.close);
  final container = ProviderContainer(overrides: [
    databaseProvider.overrideWithValue(db),
    authRepositoryProvider.overrideWithValue(FakeAuthRepository(
      signedInUserId: _me,
      profile: UserProfile(
          id: _me, username: 'gamer', displayName: 'Gamer', onboardingCompleted: true, createdAt: DateTime(2026)),
    )),
    appConfigProvider.overrideWithValue(const AppConfig(
      appEnv: 'test',
      supabaseUrl: 'https://test.supabase.co',
      supabaseAnonKey: 'test-anon-key',
    )),
    hapticsEnabledProvider.overrideWith((ref) => false),
    connectivityProvider.overrideWith((ref) => Stream.value(true)),
    remoteCanonSourceProvider.overrideWithValue(_EmptyRemoteCanon()),
    discoveryRepositoryProvider.overrideWithValue(FakeDiscoveryRepository()),
    socialRepositoryProvider.overrideWithValue(server.social),
    mutationTransportProvider.overrideWithValue(server),
    achievementsRepositoryProvider.overrideWithValue(server),
    challengesRepositoryProvider.overrideWithValue(server.challenges),
    challengeClockProvider.overrideWithValue(() => testNow),
    levelsRepositoryProvider.overrideWithValue(server.levels),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const TellyApp()));
  await _pumpFor(tester);
  return container;
}

/// Pumps frames (not pumpAndSettle: the unlock moment's confetti never settles).
Future<void> _pumpFor(WidgetTester tester, [int frames = 20]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps until [finder] shows, or fails after ~10 s of frames.
Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await _pumpFor(tester, 10);
}

/// Ranks a film the way SCR-10/11 does: placed through a duel, so it qualifies.
Future<void> rankThroughDuels(ProviderContainer c, int titleId, String title) =>
    c.read(rankingRepositoryProvider).commitPlacement(
          candidate: CanonCandidate(titleId: titleId, mediaType: 'movie', title: title),
          targetRank: 1,
          duels: [LoggedDuel(winnerTitleId: titleId, loserTitleId: 1)],
        );

/// Adds a film the way the Letterboxd importer does: no duels, so it doesn't qualify.
Future<void> importTitle(ProviderContainer c, int titleId, String title) =>
    c.read(rankingRepositoryProvider).appendCanon(
      mediaType: 'movie',
      ordered: [CanonCandidate(titleId: titleId, mediaType: 'movie', title: title)],
    );

/// Waits for the offline queue to drain to the server.
Future<void> _synced(WidgetTester tester, ProviderContainer c) async {
  final db = c.read(databaseProvider);
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (await tester.runAsync(() => db.pendingMutationDao.count()) == 0) return;
  }
  fail('the offline queue never drained');
}

void gamificationJourneys() {
  testWidgets('CUJ-05a: rank a title, see the unlock moment, pin the medal, see it on the profile', (tester) async {
    final server = GameServer(qualifying: 9); // nine films in: the tenth earns Ticket Stub
    final c = await launchAgainst(tester, server);

    await rankThroughDuels(c, 501, 'Alien');
    await _synced(tester, c);
    await _waitFor(tester, find.byKey(const Key('unlock_moment')));
    expect(find.text('Ticket Stub'), findsWidgets);

    await _tap(tester, find.byKey(const Key('unlock_moment_pin')));
    expect(server.pinned, {'movies_10': 1});
    await _tap(tester, find.byKey(const Key('unlock_moment_done')));
    expect(find.byKey(const Key('unlock_moment')), findsNothing);
    expect(server.seen, contains('movies_10'));

    await _tap(tester, find.byKey(const Key('nav_tab_more')));
    await _waitFor(tester, find.byKey(const Key('more_profile_medals')));
  });

  testWidgets('CUJ-05b: join a challenge, rank matching titles, see it complete, its medal and feed card',
      (tester) async {
    final server = GameServer();
    final c = await launchAgainst(tester, server);

    await _tap(tester, find.byKey(const Key('nav_tab_more')));
    await _tap(tester, find.byKey(const Key('more_tile_challenges')));
    await _tap(tester, find.byKey(const Key('challenge_row_spooktober')));
    await _tap(tester, find.byKey(const Key('challenge_join')));
    expect(server.challenges.joined, ['id-spooktober']);

    await rankThroughDuels(c, 601, 'The Thing');
    await rankThroughDuels(c, 602, 'Halloween');
    await _synced(tester, c);

    await _waitFor(tester, find.byKey(const Key('unlock_moment')));
    expect(find.text('Spooktober'), findsWidgets);
    await _tap(tester, find.byKey(const Key('unlock_moment_done')));

    // Back to the tabs (the challenge screen sits above them), then Social.
    c.read(appRouterProvider).go(Routes.more);
    await _tap(tester, find.byKey(const Key('nav_tab_social')));
    // The feed loaded at launch, before the challenge finished: pull to refresh, as a person would.
    await _waitFor(tester, find.text('No Activity Yet'));
    await tester.fling(find.text('No Activity Yet'), const Offset(0, 400), 1200);
    await _pumpFor(tester, 30);
    await _waitFor(tester, find.byType(ChallengeActivityCard));
    expect(find.descendant(of: find.byType(ChallengeActivityCard), matching: find.textContaining('Spooktober')),
        findsWidgets);
  });

  testWidgets('CUJ-05c: XP and level move after a qualifying ranking; an imported title earns nothing',
      (tester) async {
    final server = GameServer();
    final c = await launchAgainst(tester, server);

    await importTitle(c, 701, 'Imported Film');
    await _synced(tester, c);
    expect(server.xp, 0);
    await rankThroughDuels(c, 702, 'Duelled Film');
    await _synced(tester, c);

    await _tap(tester, find.byKey(const Key('nav_tab_more')));
    await _tap(tester, find.byKey(const Key('more_tile_level')));
    await _waitFor(tester, find.byKey(const Key('level_progress_label')));
    expect(find.text('10 / 250 XP to Level 2'), findsOneWidget);
  });
}
