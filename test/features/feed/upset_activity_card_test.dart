import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/feed/presentation/widgets/upset_activity_card.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    // The cards read the reward frame directory (#147), so they need a ProviderScope.
    return ProviderScope(
      child: MaterialApp(
        theme: TellyTheme.darkTheme,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  group('QA-303: UpsetActivityCard Component Tests', () {
    final sampleUpset = ActivityLog(
      id: 'act-upset-1',
      userId: 'u-jordan',
      username: 'jordan',
      userDisplayName: 'Jordan Miller',
      activityType: ActivityType.upsetAlert,
      titleId: 102,
      titleName: 'Severance',
      releaseYear: 2022,
      mediaType: 'tv',
      rankPosition: 2,
      calculatedScore: 9.72,
      culturalTier: 'God Tier',
      isUpset: true,
      upsetDelta: 0.28,
      upsetOverTitleName: 'Succession',
      upsetOverTitleRank: 4,
      agreementPercentage: 14.0,
      microReview: 'The season 2 finale was the most stressful 60 minutes of television.',
      reactions: {
        FeedReaction.fire: 18,
        FeedReaction.mindBlown: 9,
      },
      userReactions: const {},
      commentCount: 4,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    );

    testWidgets('renders SPICY UPSET ALERT badge, matchup, and consensus percentage', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        UpsetActivityCard(activity: sampleUpset),
      ));
      await tester.pumpAndSettle();

      expect(find.text('SPICY UPSET ALERT'), findsOneWidget);
      expect(find.text('Severance'), findsAtLeastNWidgets(1));
      expect(find.text('Succession'), findsOneWidget);
      expect(find.text('⚡ OVER'), findsOneWidget);
      expect(find.text('Only 14% of Telly users agree with this pick'), findsOneWidget);
      expect(find.text('“The season 2 finale was the most stressful 60 minutes of television.”'),
          findsOneWidget);
    });

    testWidgets('1-tap queue button works on upset alert card', (tester) async {
      bool? inQueue;

      await tester.pumpWidget(buildTestableWidget(
        UpsetActivityCard(
          activity: sampleUpset,
          onQueueToggle: (val) => inQueue = val,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('feed_bookmark')));
      await tester.pumpAndSettle();

      expect(inQueue, isTrue);
      expect(find.byTooltip('In your Watchlist'), findsOneWidget);
    });
  });
}
