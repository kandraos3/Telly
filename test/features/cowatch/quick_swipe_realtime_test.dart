import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/cowatch/data/co_watch_repository.dart';
import 'package:telly_app/features/cowatch/domain/two_to_watch_engine.dart';
import 'package:telly_app/features/cowatch/presentation/widgets/quick_swipe_deck_modal.dart';

void main() {
  const testCandidates = [
    CoWatchCandidate(
      showId: 101,
      title: 'Parasite',
      mediaType: 'movie',
      runtimeMinutes: 132,
      network: 'Neon',
      availableProviders: ['max'],
      vibeTags: ['thriller'],
      inWatchlistA: true,
      inWatchlistB: true,
      communityScore: 9.7,
      overview: 'Greed and class discrimination.',
    ),
    CoWatchCandidate(
      showId: 102,
      title: 'Past Lives',
      mediaType: 'movie',
      runtimeMinutes: 106,
      network: 'A24',
      availableProviders: ['netflix'],
      communityScore: 9.2,
      overview: 'Deeply connected childhood friends.',
    ),
  ];

  Widget createTestWidget({
    required FakeCoWatchSessionClient sessionClient,
    List<CoWatchCandidate> candidates = testCandidates,
  }) {
    return ProviderScope(
      child: MaterialApp(
        theme: TellyTheme.dark,
        home: Scaffold(
          body: QuickSwipeDeckModal(
            candidates: candidates,
            friendHandle: '@maya',
            friendId: 'maya-id',
            sharedProviders: const {'max', 'netflix'},
            sessionClient: sessionClient,
          ),
        ),
      ),
    );
  }

  group('FE-610: QuickSwipeDeckModal Realtime Two-Player Widget Tests', () {
    testWidgets('one-sided right swipe does NOT trigger match dialog', (tester) async {
      final sessionClient = FakeCoWatchSessionClient(
        sessionId: 'test-session',
        currentUserId: 'my-id',
      );

      await tester.pumpWidget(createTestWidget(sessionClient: sessionClient));
      await tester.pump();

      expect(find.text('QUICK SWIPE DUEL'), findsOneWidget);
      expect(find.text('Parasite'), findsOneWidget);
      expect(find.text('IT\'S A MATCH! 🍿'), findsNothing);

      // Tap the check button (right swipe)
      await tester.tap(find.byIcon(Icons.check));
      // Allow card swipe animation to complete
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // One-sided swipe should NOT show the match dialog
      expect(find.text('IT\'S A MATCH! 🍿'), findsNothing);
      expect(sessionClient.localSwipes[101], SwipeDirection.right);

      sessionClient.dispose();
    });

    testWidgets('partner swiping right on same title triggers IT\'S A MATCH! dialog', (tester) async {
      final sessionClient = FakeCoWatchSessionClient(
        sessionId: 'test-session',
        currentUserId: 'my-id',
      );

      await tester.pumpWidget(createTestWidget(sessionClient: sessionClient));
      await tester.pump();

      // User swipes right on Parasite (101)
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('IT\'S A MATCH! 🍿'), findsNothing);

      // Partner broadcasts right swipe on 101
      sessionClient.simulatePartnerSwipe(
        const CoWatchSwipeEvent(
          userId: 'maya-id',
          titleId: 101,
          direction: SwipeDirection.right,
        ),
      );
      await tester.pump();
      await tester.pump();

      // Mutual match triggered!
      expect(find.text('IT\'S A MATCH! 🍿'), findsOneWidget);
      expect(find.text('You and @maya both swiped right!'), findsOneWidget);
      expect(find.text('▶ Watch on MAX'), findsOneWidget);

      sessionClient.dispose();
    });

    testWidgets('partner swiping right prior to user right swipe immediately triggers match', (tester) async {
      final sessionClient = FakeCoWatchSessionClient(
        sessionId: 'test-session',
        currentUserId: 'my-id',
      );

      // Partner pre-swiped right on Parasite (101)
      sessionClient.simulatePartnerSwipe(
        const CoWatchSwipeEvent(
          userId: 'maya-id',
          titleId: 101,
          direction: SwipeDirection.right,
        ),
      );

      await tester.pumpWidget(createTestWidget(sessionClient: sessionClient));
      await tester.pump();

      expect(find.text('IT\'S A MATCH! 🍿'), findsNothing);

      // User now swipes right on Parasite
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Immediate match!
      expect(find.text('IT\'S A MATCH! 🍿'), findsOneWidget);
      expect(find.text('Parasite'), findsWidgets);

      sessionClient.dispose();
    });

    testWidgets('presence updates status text from Waiting to Connected', (tester) async {
      final sessionClient = FakeCoWatchSessionClient(
        sessionId: 'test-session',
        currentUserId: 'my-id',
      );

      await tester.pumpWidget(createTestWidget(sessionClient: sessionClient));
      await tester.pump();

      // Initially only my-id is present
      expect(find.text('Waiting'), findsOneWidget);

      // Partner joins session
      sessionClient.simulatePartnerPresence({'my-id', 'maya-id'});
      await tester.pump();
      await tester.pump();

      expect(find.text('Connected'), findsOneWidget);

      sessionClient.dispose();
    });
  });
}
