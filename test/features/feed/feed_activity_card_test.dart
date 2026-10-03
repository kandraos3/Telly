import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/feed/presentation/widgets/feed_activity_card.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: TellyTheme.darkTheme,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  group('QA-303: FeedActivityCard Component Tests', () {
    final sampleActivity = ActivityLog(
      id: 'act-test-1',
      userId: 'u1',
      username: 'alex',
      userDisplayName: 'Alex Rivera',
      activityType: ActivityType.rankingCreated,
      titleId: 201,
      titleName: 'Dune: Part Two',
      releaseYear: 2024,
      mediaType: 'movie',
      rankPosition: 3,
      calculatedScore: 9.42,
      culturalTier: 'God Tier',
      favoriteCharacter: 'Paul Atreides',
      vibeTags: const ['Masterpiece Acting'],
      microReview: 'Hans Zimmer score vibrating in IMAX was religious.',
      reactions: const {
        FeedReactionType.fire: 24,
      },
      userReactions: const {},
      commentCount: 7,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    );

    testWidgets('renders author, title, score badge, and MVP character', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        FeedActivityCard(activity: sampleActivity),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Alex Rivera'), findsOneWidget);
      expect(find.text('@alex'), findsOneWidget);
      expect(find.text('Dune: Part Two'), findsOneWidget);
      expect(find.text('9.42'), findsOneWidget);
      expect(find.text('God Tier'), findsOneWidget);
      expect(find.text('MVP: Paul Atreides'), findsOneWidget);
      expect(find.text('#Masterpiece Acting'), findsOneWidget);
      expect(find.text('“Hans Zimmer score vibrating in IMAX was religious.”'), findsOneWidget);
    });

    testWidgets('tapping 1-tap queue button toggles state and calls callback', (tester) async {
      bool? toggledState;

      await tester.pumpWidget(buildTestableWidget(
        FeedActivityCard(
          activity: sampleActivity,
          onQueueToggle: (state) => toggledState = state,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('+ Want to Watch'), findsOneWidget);

      await tester.tap(find.text('+ Want to Watch'));
      await tester.pumpAndSettle();

      expect(toggledState, isTrue);
      expect(find.text('In Queue'), findsOneWidget);
      expect(find.text('Added to your Watchlist (available on Netflix)'), findsOneWidget);
    });

    testWidgets('tapping reaction invokes onReactionToggle callback', (tester) async {
      FeedReactionType? selectedReaction;

      await tester.pumpWidget(buildTestableWidget(
        FeedActivityCard(
          activity: sampleActivity,
          onReactionToggle: (reaction) => selectedReaction = reaction,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('🔥'));
      await tester.pumpAndSettle();

      expect(selectedReaction, equals(FeedReactionType.fire));
    });

    testWidgets('tapping comment bubble invokes onCommentTap', (tester) async {
      bool commentTapped = false;

      await tester.pumpWidget(buildTestableWidget(
        FeedActivityCard(
          activity: sampleActivity,
          onCommentTap: () => commentTapped = true,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
      await tester.pumpAndSettle();

      expect(commentTapped, isTrue);
    });
  });
}
