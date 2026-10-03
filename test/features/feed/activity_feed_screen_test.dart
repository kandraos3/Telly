import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/feed/presentation/screens/activity_feed_screen.dart';

void main() {
  Widget buildTestableScreen({SocialRepository? repository}) {
    return ProviderScope(
      overrides: [
        if (repository != null) socialRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: TellyTheme.darkTheme,
        home: const ActivityFeedScreen(),
      ),
    );
  }

  group('FE-301: ActivityFeedScreen Tests', () {
    testWidgets('renders top bar, segmented tabs, upset card, and standard card', (tester) async {
      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      expect(find.text('TELLY'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
      expect(find.text('Squads'), findsOneWidget);
      expect(find.text('Global'), findsOneWidget);

      // Verify Upset Card rendered
      expect(find.byKey(const Key('upset_card_act-1')), findsOneWidget);
      expect(find.text('SPICY UPSET ALERT'), findsOneWidget);

      // Verify Standard Card rendered
      expect(find.byKey(const Key('feed_card_act-2')), findsOneWidget);
    });

    testWidgets('switching tabs updates active filter', (tester) async {
      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Squads'));
      await tester.pumpAndSettle();

      // Only squad items should be displayed (Jordan & Alex)
      expect(find.byKey(const Key('upset_card_act-1')), findsOneWidget);
      expect(find.byKey(const Key('feed_card_act-3')), findsOneWidget);
      // act-2 (Maya) is not in squads filter
      expect(find.byKey(const Key('feed_card_act-2')), findsNothing);
    });
  });
}
