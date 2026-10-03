import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/profile/presentation/screens/friend_profile_screen.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        theme: TellyTheme.dark,
        home: child,
      ),
    );
  }

  group('FE-401, FE-402, FE-403: Friend Profile & Taste Comparison Tests (SCR-15)', () {
    testWidgets('renders radial dial displaying 88% and affinity tier', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const FriendProfileScreen(
            userId: 'maya-123',
            handle: 'maya',
            displayName: 'Maya Lin',
            initialMatchPercentage: 88,
            mutualTitleCount: 34,
            movieMatchPercentage: 92,
            seriesMatchPercentage: 84,
          ),
        ),
      );

      // Settle animations
      await tester.pumpAndSettle();

      // Verify friend header
      expect(find.text('@maya'), findsOneWidget);
      expect(find.text('Maya Lin'), findsOneWidget);

      // Verify percentage and mutual titles count
      expect(find.text('88'), findsOneWidget);
      expect(find.text('%'), findsWidgets);
      expect(find.text('Based on 34 mutual titles ranked'), findsOneWidget);
      expect(find.text('Kindred Spirits'), findsOneWidget);
    });

    testWidgets('renders dual taste match breakdown pills (FE-402)', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const FriendProfileScreen(
            userId: 'maya-123',
            handle: 'maya',
            displayName: 'Maya Lin',
            movieMatchPercentage: 92,
            seriesMatchPercentage: 84,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Movie Match and Series Match pills
      expect(find.text('Movie Match'), findsOneWidget);
      expect(find.text('92%'), findsOneWidget);
      expect(find.text('Series Match'), findsOneWidget);
      expect(find.text('84%'), findsOneWidget);
    });

    testWidgets('renders Where You Agree, Spiciest Clashes, and Unwatched Gems (FE-403)', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const FriendProfileScreen(
            userId: 'maya-123',
            handle: 'maya',
            displayName: 'Maya Lin',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Section Headers
      expect(find.text('🤝 WHERE YOU AGREE'), findsOneWidget);
      expect(find.text('⚡ SPICIEST CLASHES'), findsOneWidget);
      expect(find.text('💡 UNWATCHED GEMS @maya LOVES'), findsOneWidget);

      // Verify agreement items
      expect(find.text('Succession'), findsOneWidget);
      expect(find.text('Severance'), findsOneWidget);

      // Verify clash items and delta
      expect(find.text('Game of Thrones'), findsOneWidget);
      expect(find.text('Δ 56'), findsOneWidget);

      // Verify unwatched gems and + Queue button
      expect(find.text('Station Eleven'), findsOneWidget);
      expect(find.text('+ Queue'), findsWidgets);
    });

    testWidgets('tapping Two-to-Watch button navigates to TwoToWatchScreen (SCR-16)', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const FriendProfileScreen(
            userId: 'maya-123',
            handle: 'maya',
            displayName: 'Maya Lin',
          ),
        ),
      );

      await tester.pumpAndSettle();

      final buttonFinder = find.text('🍿 Two-to-Watch with @maya');
      expect(buttonFinder, findsOneWidget);

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      // Verify navigated to TwoToWatchScreen
      expect(find.text('TWO-TO-WATCH'), findsOneWidget);
      expect(find.text('WHO\'S ON THE COUCH?'), findsOneWidget);
    });
  });
}
