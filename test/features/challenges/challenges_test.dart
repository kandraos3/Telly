import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/analytics/telemetry_service.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/achievements/data/achievements_repository.dart';
import 'package:telly_app/features/challenges/data/challenges_repository.dart';
import 'package:telly_app/features/challenges/domain/challenge.dart';
import 'package:telly_app/features/challenges/presentation/controllers/challenges_controller.dart';
import 'package:telly_app/features/challenges/presentation/screens/challenge_screen.dart';
import 'package:telly_app/features/challenges/presentation/screens/challenges_screen.dart';
import 'package:telly_app/features/queue/data/watchlist_repository.dart';
import 'package:telly_app/features/sharing/data/story_share_service.dart';
import 'package:telly_app/features/squads/domain/squad_models.dart';

import '../../fakes/fake_watchlist_repository.dart';
import '../achievements/achievements_fixtures.dart';
import 'challenges_fixtures.dart';

void main() {
  late AppDatabase db;
  setUp(() {
    db = AppDatabase.inMemory();
    TelemetryService().reset();
  });
  tearDown(() => db.close());

  group('#144 challenge model', () {
    test('days left round up; open-ended and ended read plainly', () {
      expect(challenge('a', daysLeft: 24).timeLabel(testNow), '24 days left');
      expect(challenge('b', daysLeft: 1).timeLabel(testNow), 'Last day');
      expect(challenge('c', openEnded: true).timeLabel(testNow), 'Open-ended');
      expect(challenge('d', ended: true).timeLabel(testNow), 'Ended');
    });

    test('overview: the featured one leads and is not repeated; ended ones go last', () {
      final o = ChallengesOverview.of(mine: sampleMine(), discover: sampleDiscover(), now: testNow);
      expect(o.featured!.slug, 'spooktober');
      expect(o.yours.map((c) => c.slug), ['batman-marathon', 'a24-month']);
      expect(o.joinNext.map((c) => c.slug), ['best-picture-decade', 'miniseries-november']);
      expect(o.ended.map((c) => c.slug), ['summer-heat']);
    });

    test('parses a challenge_card row', () {
      final c = Challenge.fromJson({
        'id': 'x', 'slug': 'spooktober-2026', 'name': 'Spooktober', 'description': 'Rank 8', 'art': 'horror',
        'medal_glyph': '8', 'starts_at': '2026-10-01T00:00:00Z', 'ends_at': '2026-11-01T00:00:00Z', 'target': 8,
        'featured': true, 'squad_id': null, 'squad_name': null, 'participant_count': 12, 'friend_count': 2,
        'joined': true, 'my_progress': 3, 'completed_at': null,
      });
      expect((c.slug, c.target, c.myProgress, c.joined, c.featured, c.isSquad), ('spooktober-2026', 8, 3, true, true, false));
    });
  });

  List<Override> overrides(FakeChallengesRepository repo, {FakeStoryShareService? share, List<Squad> squads = const []}) => [
        hapticsEnabledProvider.overrideWith((ref) => false),
        challengeClockProvider.overrideWithValue(() => testNow),
        challengesRepositoryProvider.overrideWithValue(repo),
        manageableSquadsProvider.overrideWith((ref) async => squads),
        databaseProvider.overrideWithValue(db),
        achievementsRepositoryProvider.overrideWithValue(FakeAchievementsRepository(sampleSnapshot())),
        storyShareServiceProvider.overrideWithValue(share ?? FakeStoryShareService()),
        watchlistRepositoryProvider.overrideWithValue(FakeWatchlistRepository()),
      ];

  Future<void> pumpScreen(WidgetTester tester, Widget screen, List<Override> o, {ThemeData? theme}) async {
    tester.view.physicalSize = const Size(393, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // A fresh scope per pump, so a second pump in one test gets its own overrides.
    await tester.pumpWidget(ProviderScope(
        key: UniqueKey(), overrides: o, child: MaterialApp(theme: theme ?? TellyTheme.dark, home: screen)));
    await tester.pumpAndSettle();
  }

  group('#144 SCR-25 Challenges', () {
    testWidgets('featured hero, Yours, Join next, and a collapsed Ended section', (tester) async {
      await pumpScreen(tester, const ChallengesScreen(), overrides(FakeChallengesRepository()));
      expect(find.text('FEATURED · 24 DAYS LEFT'), findsOneWidget);
      expect(find.text('You: 3 of 8'), findsOneWidget);
      expect(find.textContaining('2140 joined · 3 friends'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('challenge_progress_batman-marathon'))).data, '4/8');
      expect(find.text('Squad'), findsOneWidget);
      expect(find.byKey(const Key('challenge_join_best-picture-decade')), findsOneWidget);
      expect(find.byKey(const Key('challenges_section_ended')), findsNothing);

      double top(String k) => tester.getTopLeft(find.byKey(Key(k))).dy;
      expect(top('challenges_featured'), lessThan(top('challenges_section_yours')));
      expect(top('challenges_section_yours'), lessThan(top('challenges_section_join_next')));

      await tester.tap(find.byKey(const Key('challenges_ended_toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('challenge_row_summer-heat')), findsOneWidget);
    });

    testWidgets('Join moves a challenge into Yours and records challenge_joined', (tester) async {
      final repo = FakeChallengesRepository();
      await pumpScreen(tester, const ChallengesScreen(), overrides(repo));
      await tester.tap(find.byKey(const Key('challenge_join_miniseries-november')));
      await tester.pumpAndSettle();
      expect(repo.joined, ['id-miniseries-november']);
      expect(find.byKey(const Key('challenge_progress_miniseries-november')), findsOneWidget);
      expect(TelemetryService().recordedEvents.single.name, 'challenge_joined');
    });

    testWidgets('+ appears only for squad owners and admins, and creates from a template', (tester) async {
      final repo = FakeChallengesRepository();
      await pumpScreen(tester, const ChallengesScreen(), overrides(repo));
      expect(find.byKey(const Key('challenges_create')), findsNothing);

      final squad = Squad(id: 'sq1', name: 'Couch Potatoes', createdBy: 'u1', createdAt: DateTime(2026), myRole: SquadRole.owner);
      await pumpScreen(tester, const ChallengesScreen(), overrides(repo, squads: [squad]));
      await tester.tap(find.byKey(const Key('challenges_create')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('squad_challenge_template_genre_month')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('squad_challenge_param_genre')), 'Horror');
      await tester.tap(find.byKey(const Key('squad_challenge_create')));
      await tester.pumpAndSettle();
      expect(repo.created.single, {
        'squad': 'sq1', 'template': 'genre_month', 'name': 'Genre month', 'params': {'genre': 'Horror'}, 'days': 30,
      });
    });

    testWidgets('empty and error states', (tester) async {
      await pumpScreen(tester, const ChallengesScreen(), overrides(FakeChallengesRepository(mine: [], discover: [])));
      expect(find.byKey(const Key('challenges_empty')), findsOneWidget);
      final failing = FakeChallengesRepository()..error = Exception('down');
      await pumpScreen(tester, const ChallengesScreen(), overrides(failing));
      expect(find.byKey(const Key('challenges_error')), findsOneWidget);
    });
  });

  group('#144 SCR-26 Challenge', () {
    FakeChallengesRepository detailRepo() => FakeChallengesRepository()
      ..racerList = const [
        ChallengeRacer(userId: 'm', displayName: 'Maya', progress: 6),
        ChallengeRacer(userId: 'me', displayName: 'Jordan', progress: 3, isMe: true),
      ]
      ..pickList = const [
        ChallengePick(titleId: 1, mediaType: 'movie', title: 'Hereditary', fromQueue: true),
        ChallengePick(titleId: 2, mediaType: 'movie', title: 'The Thing', releaseYear: 1982, friendsScore: 9.4, friendCount: 2),
      ];

    testWidgets('progress card, friends racing, and picks from the Queue first', (tester) async {
      await pumpScreen(tester, const ChallengeScreen(slug: 'spooktober'), overrides(detailRepo()));
      expect(find.text('3 / 8', findRichText: true), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('challenge_time_left'))).data, '24 days left');
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Maya'), findsOneWidget);
      expect(find.text('In your Queue'), findsOneWidget);
      expect(find.text('1982 · Friends rate it 9.4 (2)'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('challenge_picks_queue'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('challenge_picks_friends'))).dy),
      );
      expect(find.byKey(const Key('challenge_join')), findsNothing, reason: 'already joined');
    });

    testWidgets('+ Queue adds a suggestion; Share and Leave act on the challenge', (tester) async {
      final repo = detailRepo();
      final share = FakeStoryShareService();
      await pumpScreen(tester, const ChallengeScreen(slug: 'spooktober'), overrides(repo, share: share));
      await tester.tap(find.byKey(const Key('challenge_pick_queue_2')));
      await tester.pumpAndSettle();
      expect(find.text('✓ In Queue'), findsOneWidget);

      await tester.tap(find.byKey(const Key('challenge_share')));
      expect(share.sharedChallenges, ['spooktober']);

      await tester.tap(find.byKey(const Key('challenge_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave challenge'));
      await tester.pumpAndSettle();
      expect(repo.left, ['id-spooktober']);
    });

    testWidgets('an unjoined challenge offers Join; a hidden one says not found', (tester) async {
      final repo = detailRepo();
      await pumpScreen(tester, const ChallengeScreen(slug: 'miniseries-november'), overrides(repo));
      await tester.tap(find.byKey(const Key('challenge_join')));
      await tester.pumpAndSettle();
      expect(repo.joined, ['id-miniseries-november']);

      await pumpScreen(tester, const ChallengeScreen(slug: 'nope'), overrides(repo));
      expect(find.text('Challenge not found'), findsOneWidget);
    });
  });
}
