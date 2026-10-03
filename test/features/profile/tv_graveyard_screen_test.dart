import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/profile/domain/dropped_show.dart';
import 'package:telly_app/features/profile/presentation/screens/tv_graveyard_screen.dart';
import 'package:telly_app/features/profile/presentation/widgets/log_dropped_show_sheet.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: TellyTheme.darkTheme,
      home: child,
    );
  }

  group('FE-307 & FE-308: TV Graveyard & Dropped Show Logging Tests (SCR-18)', () {
    testWidgets('renders dropped show card with milestone, reason chip, and status pill', (tester) async {
      final sampleShows = [
        DroppedShow(
          id: 'drop-test-1',
          userId: 'u1',
          titleId: 501,
          title: 'Westworld',
          releaseYear: 2016,
          droppedAtSeason: 3,
          droppedAtEpisode: 4,
          reason: DropReasonTaxonomy.jumpedShark,
          willingToRevisit: false,
          notes: 'Lost the mystery once they left the park.',
          notifyOnAcclaim: false,
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(buildTestableWidget(
        TvGraveyardScreen(initialDroppedShows: sampleShows),
      ));
      await tester.pumpAndSettle();

      expect(find.text('THE TV GRAVEYARD'), findsOneWidget);
      expect(find.text('WESTWORLD'), findsOneWidget);
      expect(find.text('2016 • Season 3, Episode 4'), findsOneWidget);
      expect(find.text('Reason: “Writing jumped the shark”'), findsOneWidget);
      expect(find.text('Dead & Buried'), findsOneWidget);
      expect(find.text('“Lost the mystery once they left the park.”'), findsOneWidget);
    });

    testWidgets('LogDroppedShowSheet modifies steppers, reason chips, and emits DroppedShow', (tester) async {
      DroppedShow? savedShow;

      await tester.pumpWidget(buildTestableWidget(
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                LogDroppedShowSheet.show(
                  context: context,
                  titleId: 505,
                  title: 'Lost',
                  releaseYear: 2004,
                ).then((show) => savedShow = show);
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('BURY IN TV GRAVEYARD'), findsOneWidget);
      expect(find.text('Lost (2004)'), findsOneWidget);

      // Increment Season
      await tester.tap(find.widgetWithIcon(IconButton, Icons.add).first);
      await tester.pumpAndSettle();
      expect(find.text('Season 3'), findsOneWidget);

      // Select another reason chip: "Pacing slowed down / Boring"
      await tester.tap(find.text('Pacing slowed down / Boring'));
      await tester.pumpAndSettle();

      // Toggle to Willing to Revisit
      await tester.ensureVisible(find.text('🔄 Willing to Revisit'));
      await tester.tap(find.text('🔄 Willing to Revisit'));
      await tester.pumpAndSettle();

      // Enter notes
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(
        find.byType(TextField),
        'Too many filler episodes in middle seasons.',
      );
      await tester.pumpAndSettle();

      // Save
      await tester.ensureVisible(find.text('🪦 Bury in The TV Graveyard'));
      await tester.tap(find.text('🪦 Bury in The TV Graveyard'));
      await tester.pumpAndSettle();

      expect(savedShow, isNotNull);
      expect(savedShow!.title, equals('Lost'));
      expect(savedShow!.droppedAtSeason, equals(3));
      expect(savedShow!.reason, equals(DropReasonTaxonomy.pacingSlowed));
      expect(savedShow!.willingToRevisit, isTrue);
      expect(savedShow!.notes, equals('Too many filler episodes in middle seasons.'));
    });
  });
}
