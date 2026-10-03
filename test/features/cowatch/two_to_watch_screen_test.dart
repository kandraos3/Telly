import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/cowatch/presentation/screens/two_to_watch_screen.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        theme: TellyTheme.dark,
        home: child,
      ),
    );
  }

  group('FE-404, FE-405, FE-406: Two-to-Watch Decider & Quick Swipe Tests (SCR-16)', () {
    testWidgets('renders Who\'s on the Couch, format selection, and shared streaming filters', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const TwoToWatchScreen(
            friendId: 'maya-123',
            friendHandle: 'maya',
            friendDisplayName: 'Maya Lin',
            matchPercentage: 88,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('TWO-TO-WATCH'), findsOneWidget);
      expect(find.text('WHO\'S ON THE COUCH?'), findsOneWidget);
      expect(find.text('Maya Lin'), findsOneWidget);
      expect(find.text('88% MATCH'), findsOneWidget);

      // Verify Format Selection
      expect(find.text('FORMAT SELECTION'), findsOneWidget);
      expect(find.text('Movie Night'), findsOneWidget);
      expect(find.text('TV Series'), findsOneWidget);

      // Verify Shared Streaming Services
      expect(find.text('SHARED STREAMING SERVICES'), findsOneWidget);
      expect(find.text('NETFLIX'), findsOneWidget);
      expect(find.text('MAX'), findsOneWidget);
      expect(find.text('APPLE_TV_PLUS'), findsOneWidget);
    });

    testWidgets('format toggle switches between Movie Night and TV Series candidates (FE-405)', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const TwoToWatchScreen(
            friendId: 'maya-123',
            friendHandle: 'maya',
            friendDisplayName: 'Maya Lin',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Movie Night is default: Parasite should be visible
      expect(find.text('Parasite'), findsOneWidget);

      // Tap TV Series format pill
      final tvSeriesFinder = find.text('TV Series');
      await tester.tap(tvSeriesFinder);
      await tester.pumpAndSettle();

      // TV series candidates should be visible: Chernobyl
      expect(find.text('Chernobyl'), findsOneWidget);
      expect(find.text('Parasite'), findsNothing);
    });

    testWidgets('runtime budget filter constrains movie recommendations (FE-405)', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const TwoToWatchScreen(
            friendId: 'maya-123',
            friendHandle: 'maya',
            friendDisplayName: 'Maya Lin',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Select Breezy (< 90m) chip
      final breezyChip = find.text('< 90m (Breezy)');
      expect(breezyChip, findsOneWidget);

      await tester.tap(breezyChip);
      await tester.pumpAndSettle();

      // Run Lola Run (81m) should be present; Parasite (132m) should be filtered out
      expect(find.text('Run Lola Run'), findsOneWidget);
      expect(find.text('Parasite'), findsNothing);
    });

    testWidgets('tapping quick swipe mode launches 15-second duel deck modal (FE-406)', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const TwoToWatchScreen(
            friendId: 'maya-123',
            friendHandle: 'maya',
            friendDisplayName: 'Maya Lin',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Quick Swipe Mode trigger in AppBar
      final boltIconFinder = find.byIcon(Icons.bolt);
      expect(boltIconFinder, findsOneWidget);

      await tester.tap(boltIconFinder);
      await tester.pump(); // don't pumpAndSettle due to periodic timer

      // Verify modal dialog appeared
      expect(find.text('QUICK SWIPE DUEL'), findsOneWidget);
      expect(find.text('With @maya'), findsOneWidget);
      expect(find.text('15s'), findsOneWidget);
    });
  });
}
