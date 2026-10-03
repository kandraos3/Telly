import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/feed/presentation/screens/comment_thread_screen.dart';

void main() {
  Widget buildTestableScreen({
    required ActivityLog activity,
    required SocialRepository repository,
  }) {
    return ProviderScope(
      overrides: [
        socialRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: TellyTheme.darkTheme,
        home: CommentThreadScreen(activity: activity),
      ),
    );
  }

  group('QA-303: Spoiler Masking & Tap-to-Reveal Tests (SCR-06, FE-305)', () {
    late InMemorySocialRepository repo;
    late ActivityLog sampleActivity;

    setUp(() {
      repo = InMemorySocialRepository();
      sampleActivity = ActivityLog(
        id: 'act-1',
        userId: 'u-jordan',
        username: 'jordan',
        userDisplayName: 'Jordan Miller',
        activityType: ActivityType.rankingCreated,
        titleId: 102,
        titleName: 'Severance',
        releaseYear: 2022,
        rankPosition: 2,
        calculatedScore: 9.72,
        commentCount: 2,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
    });

    testWidgets('comments with containsSpoilers render TAP TO REVEAL SPOILER mask', (tester) async {
      await tester.pumpWidget(buildTestableScreen(
        activity: sampleActivity,
        repository: repo,
      ));
      await tester.pumpAndSettle();

      // Comment 1 is non-spoiler
      expect(
        find.textContaining('How could you rank it over Succession though?'),
        findsOneWidget,
      );

      // Comment 2 is a spoiler - should show mask
      expect(find.text('TAP TO REVEAL SPOILER'), findsOneWidget);
      expect(find.text('SPOILER'), findsOneWidget);

      // Tap spoiler mask to reveal
      await tester.tap(find.byKey(const Key('spoiler_mask_comm-2')));
      await tester.pumpAndSettle();

      // Mask banner should now be gone, and revealed text readable
      expect(find.text('TAP TO REVEAL SPOILER'), findsNothing);
      expect(find.textContaining('In the finale when Helly steps onto the stage'), findsOneWidget);

      // Tap again to re-mask
      await tester.tap(find.textContaining('In the finale when Helly steps onto the stage'));
      await tester.pumpAndSettle();

      expect(find.text('TAP TO REVEAL SPOILER'), findsOneWidget);
    });

    testWidgets('comment composer can toggle spoiler flag and submit comment', (tester) async {
      await tester.pumpWidget(buildTestableScreen(
        activity: sampleActivity,
        repository: repo,
      ));
      await tester.pumpAndSettle();

      // Type comment
      await tester.enterText(
        find.byType(TextField),
        'Mind blowing ending! The cliffhanger was insane.',
      );
      await tester.pumpAndSettle();

      // Toggle spoiler tag
      await tester.tap(find.text('Contains Spoilers'));
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      // The new comment should appear with a spoiler mask
      expect(find.text('TAP TO REVEAL SPOILER'), findsNWidgets(2));
    });
  });
}
