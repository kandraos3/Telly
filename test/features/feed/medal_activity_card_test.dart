import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/achievements/data/achievements_repository.dart';
import 'package:telly_app/features/achievements/domain/medal.dart';
import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/feed/presentation/screens/activity_feed_screen.dart';
import 'package:telly_app/features/feed/presentation/widgets/medal_activity_card.dart';

import '../../fakes/fake_social_repository.dart';
import '../../helpers/router_harness.dart';
import '../achievements/achievements_fixtures.dart';

/// A `MEDAL_UNLOCKED` post as the feed maps it.
ActivityLog medalActivity(String id, {String medalId = 'movies_100', int minutesAgo = 5}) => ActivityLog(
      id: id,
      userId: 'u-maya',
      username: 'maya',
      userDisplayName: 'Maya',
      activityType: ActivityType.medalUnlocked,
      titleId: 0,
      titleName: 'Unknown title',
      medal: FeedMedal(id: medalId, name: 'Centurion', tier: MedalTier.gold, glyph: '100'),
      reactions: {FeedReaction.fire: 3},
      createdAt: DateTime.now().subtract(Duration(minutes: minutesAgo)),
    );

void main() {
  final medals = FakeAchievementsRepository(null)
    ..rarity = {'movies_100': const MedalRarity(percent: 4.2, activeUsers: 950)};

  Future<void> pumpCard(WidgetTester tester, ActivityLog activity, {ThemeData? theme}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        hapticsEnabledProvider.overrideWith((ref) => false),
        achievementsRepositoryProvider.overrideWithValue(medals),
      ],
      child: MaterialApp(
        theme: theme ?? TellyTheme.dark,
        home: Scaffold(body: SingleChildScrollView(child: MedalActivityCard(activity: activity))),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('#139 medal feed card', () {
    testWidgets('shows who unlocked which medal, its tier, rarity and reactions', (tester) async {
      await pumpCard(tester, medalActivity('m1'));
      expect(find.text('Maya unlocked Centurion'), findsOneWidget);
      expect(find.textContaining('Gold medal'), findsOneWidget);
      expect(find.text('Unlocked by 4.2% of Telly viewers'), findsOneWidget);
      expect(find.text('3'), findsWidgets, reason: 'reaction count from the shared action bar');
      expect(find.byKey(const Key('feed_bookmark')), findsNothing, reason: 'no title, so no Queue button');
    });

    testWidgets('a medal without enough viewers reads as New', (tester) async {
      await pumpCard(tester, medalActivity('m2', medalId: 'streak_52'));
      expect(find.text('New: not enough viewers yet'), findsOneWidget);
    });

    testWidgets('light theme uses the light tokens', (tester) async {
      await pumpCard(tester, medalActivity('m1'), theme: TellyTheme.light);
      final rarity = tester.widget<Text>(find.byKey(const Key('medal_card_rarity')));
      expect(rarity.style!.color, TellyColors.lightWarmAmber);
    });

    testWidgets('the Social feed renders MEDAL_UNLOCKED posts as medal cards', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = FakeSocialRepository(feed: [
        medalActivity('medal-1', minutesAgo: 1),
        fakeActivity('act-2', userId: 'u-alex', username: 'alex', minutesAgo: 2),
      ]);
      await tester.pumpWidget(routerHarness(const ActivityFeedScreen(), overrides: [
        socialRepositoryProvider.overrideWithValue(repo),
        hapticsEnabledProvider.overrideWith((ref) => false),
        achievementsRepositoryProvider.overrideWithValue(medals),
      ]));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('medal_card_medal-1')), findsOneWidget);
      expect(find.byKey(const Key('feed_card_act-2')), findsOneWidget);
    });
  });

  group('#139 feed row mapping', () {
    test('MEDAL_UNLOCKED rows carry the medal from their metadata', () {
      final a = activityFromFeedRow({
        'id': 'a1',
        'user_id': 'u1',
        'username': 'maya',
        'display_name': 'Maya',
        'activity_type': 'MEDAL_UNLOCKED',
        'metadata': {'achievement_id': 'streak_12', 'name': 'Devotee', 'tier': 'silver', 'glyph': '12', 'kind': 'streak'},
        'created_at': '2026-10-07T12:00:00Z',
      });
      expect(a.activityType, ActivityType.medalUnlocked);
      expect((a.medal!.id, a.medal!.name, a.medal!.tier, a.medal!.glyph), ('streak_12', 'Devotee', MedalTier.silver, '12'));
    });

    test('other rows have no medal', () {
      expect(ActivityType.fromString('RANKING_CREATED'), ActivityType.rankingCreated);
      expect(FeedMedal.fromMetadata(const {'loser_title_id': 3}), isNull);
    });
  });
}
