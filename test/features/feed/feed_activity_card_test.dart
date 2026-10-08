import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/feed/presentation/widgets/feed_activity_card.dart';

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
      reactions: {
        FeedReaction.fire: 24,
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

    testWidgets('FE-FEED-01: the compact bookmark toggles state and calls back', (tester) async {
      bool? toggledState;

      await tester.pumpWidget(buildTestableWidget(
        FeedActivityCard(
          activity: sampleActivity,
          onQueueToggle: (state) => toggledState = state,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('+ Want to Watch'), findsNothing, reason: 'the big banner button is gone');
      final bookmark = find.byKey(const Key('feed_bookmark'));
      expect(bookmark, findsOneWidget);
      expect(tester.getSize(bookmark).width, lessThanOrEqualTo(48));
      expect(find.byTooltip('Want to Watch'), findsOneWidget);
      // Top-right corner: level with the author, right of the name.
      expect(tester.getCenter(bookmark).dy, closeTo(tester.getCenter(find.text('Alex Rivera')).dy, 24));
      expect(tester.getCenter(bookmark).dx, greaterThan(tester.getCenter(find.text('Alex Rivera')).dx));

      await tester.tap(bookmark);
      await tester.pumpAndSettle();

      expect(toggledState, isTrue);
      expect(find.byTooltip('In your Watchlist'), findsOneWidget);
      expect(find.text('Added to your Watchlist'), findsOneWidget);
      expect(find.textContaining('Netflix'), findsNothing, reason: 'no invented streaming service');
    });

    testWidgets('FE-FEED-01: the bar shows the five presets, the post\'s other reactions and a picker', (tester) async {
      await tester.pumpWidget(buildTestableWidget(FeedActivityCard(activity: sampleActivity)));
      await tester.pumpAndSettle();

      for (final t in FeedReactionType.presets) {
        expect(find.byKey(Key('feed_reaction_${t.dbValue}')), findsOneWidget, reason: t.label);
      }
      // A retired preset the post already has still shows, with its count.
      expect(find.byKey(const Key('feed_reaction_FIRE')), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
      expect(find.byKey(const Key('feed_reaction_MIND_BLOWN')), findsNothing);
      expect(find.byKey(const Key('feed_reaction_more')), findsOneWidget);
    });

    testWidgets('FE-FEED-01: the picker returns a preset or any emoji', (tester) async {
      final picked = <FeedReaction>[];
      await tester.pumpWidget(buildTestableWidget(
        FeedActivityCard(activity: sampleActivity, onReactionToggle: picked.add),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('feed_reaction_more')));
      await tester.pumpAndSettle();
      expect(find.text('Masterpiece'), findsOneWidget);
      await tester.tap(find.byKey(const Key('feed_picker_emoji_🍿')));
      await tester.pumpAndSettle();
      expect(picked, [const FeedReaction.custom('🍿')]);

      await tester.tap(find.byKey(const Key('feed_reaction_more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('feed_picker_KUDOS')));
      await tester.pumpAndSettle();
      expect(picked.last, FeedReaction.kudos);
    });

    testWidgets('tapping reaction invokes onReactionToggle callback', (tester) async {
      FeedReaction? selectedReaction;

      await tester.pumpWidget(buildTestableWidget(
        FeedActivityCard(
          activity: sampleActivity,
          onReactionToggle: (reaction) => selectedReaction = reaction,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('🔥'));
      await tester.pumpAndSettle();

      expect(selectedReaction, equals(FeedReaction.fire));
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
