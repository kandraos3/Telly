import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/challenges/data/challenges_repository.dart';
import 'package:telly_app/features/challenges/presentation/controllers/challenges_controller.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/feed/presentation/widgets/challenge_activity_card.dart';
import 'package:telly_app/features/feed/presentation/widgets/feed_activity_card.dart';

import '../challenges/challenges_fixtures.dart';

/// A `CHALLENGE_COMPLETED` post as the feed maps it.
ActivityLog challengeActivity(String slug, {String name = 'Spooktober'}) => ActivityLog(
      id: 'cc-$slug',
      userId: 'u-maya',
      username: 'maya',
      userDisplayName: 'Maya',
      activityType: ActivityType.challengeCompleted,
      titleId: 0,
      titleName: 'The Thing',
      challenge: FeedChallenge(
          challengeId: 'id-$slug', slug: slug, name: name, count: 8, medalGlyph: '8',
          bestTitle: 'The Thing', bestRank: 1, bestScore: 9.4),
      reactions: {FeedReaction.fire: 12},
      commentCount: 4,
      // Relative to the real clock: the card's "2h ago" reads from DateTime.now().
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    );

void main() {
  Future<FakeChallengesRepository> pumpCard(WidgetTester tester, Widget card, {FakeChallengesRepository? repo}) async {
    final r = repo ?? FakeChallengesRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        hapticsEnabledProvider.overrideWith((ref) => false),
        challengesRepositoryProvider.overrideWithValue(r),
        challengeClockProvider.overrideWithValue(() => testNow),
      ],
      child: MaterialApp(theme: TellyTheme.dark, home: Scaffold(body: SingleChildScrollView(child: card))),
    ));
    await tester.pumpAndSettle();
    return r;
  }

  group('#144 challenge feed card', () {
    testWidgets('who finished what, the medal and the best of the batch', (tester) async {
      await pumpCard(tester, ChallengeActivityCard(activity: challengeActivity('spooktober')));
      expect(find.text('Maya finished Spooktober'), findsOneWidget);
      expect(find.textContaining('8 of 8'), findsOneWidget);
      expect(find.text('Best of the 8: The Thing (#1, 9.40)'), findsOneWidget);
      expect(find.byKey(const Key('challenge_card_join')), findsNothing, reason: 'I already joined Spooktober');
    });

    testWidgets('Join shows while the challenge is live and I am not in it', (tester) async {
      final repo = await pumpCard(
          tester, ChallengeActivityCard(activity: challengeActivity('miniseries-november', name: 'Miniseries November')));
      await tester.tap(find.byKey(const Key('challenge_card_join')));
      await tester.pumpAndSettle();
      expect(repo.joined, ['id-miniseries-november']);
      expect(find.byKey(const Key('challenge_card_join')), findsNothing);
    });

    testWidgets('a ranking inside a joined challenge shows "Spooktober 2 of 8"', (tester) async {
      final ranked = ActivityLog(
        id: 'r1',
        userId: 'u-maya',
        username: 'maya',
        userDisplayName: 'Maya',
        activityType: ActivityType.rankingCreated,
        titleId: 377,
        titleName: 'Pearl',
        rankPosition: 3,
        challengeContext: const ChallengeContext(slug: 'spooktober', name: 'Spooktober', count: 2, target: 8),
        createdAt: testNow,
      );
      await pumpCard(tester, FeedActivityCard(activity: ranked));
      expect(find.byKey(const Key('feed_card_challenge_context')), findsOneWidget);
      expect(find.text('Spooktober 2 of 8'), findsOneWidget);
    });
  });
}
