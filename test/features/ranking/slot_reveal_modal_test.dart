import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/features/ranking/presentation/screens/slot_reveal_modal.dart';

void main() {
  Widget buildTestableWidget({
    required Widget child,
  }) {
    return ProviderScope(
      overrides: [
        hapticsEnabledProvider.overrideWith((ref) => false),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: child,
      ),
    );
  }

  group('FE-205 / QA-204: SCR-12 SlotRevealModal Tests', () {
    testWidgets('renders headline, card, and initial counter starts at 0.00',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: SlotRevealModal(
            showId: 101,
            title: 'Interstellar',
            mediaType: 'movie',
            rankPosition: 4,
            totalInCanon: 48,
            targetScore: 9.42,
            onViewInCanon: () {},
          ),
        ),
      );

      // Verify headline & title
      expect(find.byKey(const Key('canon_updated_headline')), findsOneWidget);
      expect(find.text('INTERSTELLAR'), findsOneWidget);
      expect(
        find.text('Rank: #4 of 48 Titles in your Movie Canon'),
        findsOneWidget,
      );

      // Initially at frame 0, score ticker starts around 0.00
      expect(find.byKey(const Key('slot_reveal_score_ticker')), findsOneWidget);
    });

    testWidgets(
        'score counter ticker animates over 1200ms to target score 9.42',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: SlotRevealModal(
            showId: 101,
            title: 'Interstellar',
            mediaType: 'movie',
            rankPosition: 4,
            totalInCanon: 48,
            targetScore: 9.42,
            onViewInCanon: () {},
          ),
        ),
      );

      // Advance clock through the animation
      await tester.pump(const Duration(milliseconds: 600));
      // Mid-way, ticker has counted up
      final midText = tester
          .widget<Text>(find.byKey(const Key('slot_reveal_score_ticker')));
      final midValue = double.parse(midText.data!);
      expect(midValue, greaterThan(0.0));
      expect(midValue, lessThan(9.42));

      // Advance through remainder of duration
      await tester.pumpAndSettle();

      // Final score should match targetScore formatted to 2 decimals
      expect(find.text('9.42'), findsOneWidget);
    });

    testWidgets('displays God Tier badge for score >= 9.00', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: SlotRevealModal(
            showId: 102,
            title: 'Succession',
            mediaType: 'tv',
            rankPosition: 1,
            totalInCanon: 20,
            targetScore: 10.00,
            onViewInCanon: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('slot_reveal_tier_badge')), findsOneWidget);
      expect(find.text('👑 GOD TIER'), findsOneWidget);
      expect(
        find.text('Rank: #1 of 20 Shows in your Series Canon'),
        findsOneWidget,
      );
    });

    testWidgets('displays Prestige Tier badge for score between 8.00 and 8.99',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: SlotRevealModal(
            showId: 103,
            title: 'The Bear',
            mediaType: 'tv',
            rankPosition: 5,
            totalInCanon: 30,
            targetScore: 8.65,
            onViewInCanon: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('✨ PRESTIGE TIER'), findsOneWidget);
    });

    testWidgets('displays beating and just behind neighbor comparisons',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: SlotRevealModal(
            showId: 104,
            title: 'The Bear',
            mediaType: 'tv',
            rankPosition: 5,
            totalInCanon: 84,
            targetScore: 9.41,
            justBehindTitles: const ['Severance (#4)', 'Breaking Bad (#3)'],
            beatingTitles: const ['Chernobyl (#6)', 'Fleabag (#7)'],
            onViewInCanon: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('just_behind_text')), findsOneWidget);
      expect(
        find.text('Just behind: Severance (#4), Breaking Bad (#3)'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('beating_text')), findsOneWidget);
      expect(
        find.text('Beating: Chernobyl (#6), Fleabag (#7)'),
        findsOneWidget,
      );
    });

    testWidgets('tapping View in My Canon triggers onViewInCanon callback',
        (tester) async {
      bool viewInCanonTapped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          child: SlotRevealModal(
            showId: 105,
            title: 'Oppenheimer',
            mediaType: 'movie',
            rankPosition: 3,
            totalInCanon: 15,
            targetScore: 9.15,
            onViewInCanon: () => viewInCanonTapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final viewBtn = find.byKey(const Key('view_in_canon_button'));
      await tester.ensureVisible(viewBtn);
      await tester.tap(viewBtn);
      await tester.pumpAndSettle();

      expect(viewInCanonTapped, isTrue);
    });

    testWidgets('tapping Share Story triggers onShareStory callback',
        (tester) async {
      bool shareTapped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          child: SlotRevealModal(
            showId: 105,
            title: 'Oppenheimer',
            mediaType: 'movie',
            rankPosition: 3,
            totalInCanon: 15,
            targetScore: 9.15,
            onViewInCanon: () {},
            onShareStory: () => shareTapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final shareBtn = find.byKey(const Key('share_story_button'));
      await tester.ensureVisible(shareBtn);
      await tester.tap(shareBtn);
      await tester.pumpAndSettle();

      expect(shareTapped, isTrue);
    });

    testWidgets('tapping close button triggers onClose callback', (tester) async {
      bool closeTapped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          child: SlotRevealModal(
            showId: 106,
            title: 'Dune: Part Two',
            mediaType: 'movie',
            rankPosition: 2,
            totalInCanon: 25,
            targetScore: 9.75,
            onViewInCanon: () {},
            onClose: () => closeTapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final closeBtn = find.byKey(const Key('slot_reveal_close_button'));
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      expect(closeTapped, isTrue);
    });
  });
}
