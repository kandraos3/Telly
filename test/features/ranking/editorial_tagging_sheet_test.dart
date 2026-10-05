import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/widgets/telly_primary_button.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/features/ranking/domain/editorial_tagging.dart';
import 'package:telly_app/features/ranking/presentation/widgets/editorial_tagging_sheet.dart';

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
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('FE-203: SCR-11 Editorial Tagging Sheet Tests', () {
    testWidgets('renders title banner, vibe tags, review input, and publish button',
        (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: EditorialTaggingSheet(
            title: 'Interstellar',
            mediaType: 'movie',
            targetRank: 1,
            totalInCanon: 42,
            director: 'Christopher Nolan',
            castMembers: const [
              'Matthew McConaughey as Cooper',
              'Anne Hathaway as Brand',
            ],
            onPublish: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DETAILS & NOTES'), findsOneWidget);
      expect(find.byKey(const Key('placed_canon_banner')), findsOneWidget);
      expect(find.byKey(const Key('publish_editorial_button')), findsOneWidget);
      expect(find.widgetWithText(TellyPrimaryButton, 'Publish'), findsOneWidget, reason: 'FE-LOG-02 label');
      expect(find.byKey(const Key('micro_review_input')), findsOneWidget);
      expect(find.byKey(const Key('micro_review_counter')), findsOneWidget);
      expect(find.text('(0/280)'), findsOneWidget);
    });

    testWidgets('selecting 2 vibe tags updates tagging selection and counter',
        (tester) async {
      EditorialTaggingData? publishedData;

      await tester.pumpWidget(
        buildTestableWidget(
          child: EditorialTaggingSheet(
            title: 'Interstellar',
            mediaType: 'movie',
            targetRank: 1,
            onPublish: (data) => publishedData = data,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0/3 selected'), findsOneWidget);

      // Tap first tag: Cinematography Peak
      final chip1 = find.byKey(const Key('vibe_chip_Cinematography Peak'));
      await tester.ensureVisible(chip1);
      await tester.tap(chip1);
      await tester.pumpAndSettle();

      // Tap second tag: Mind-Bending
      final chip2 = find.byKey(const Key('vibe_chip_Mind-Bending'));
      await tester.ensureVisible(chip2);
      await tester.tap(chip2);
      await tester.pumpAndSettle();

      expect(find.text('2/3 selected'), findsOneWidget);

      // Publish and verify
      final publishBtn = find.byKey(const Key('publish_editorial_button'));
      await tester.ensureVisible(publishBtn);
      await tester.tap(publishBtn);
      await tester.pumpAndSettle();

      expect(publishedData, isNotNull);
      expect(publishedData!.vibeTags, equals(['Cinematography Peak', 'Mind-Bending']));
    });

    testWidgets('FIFO queue enforces maximum 3 vibe tags (4th deselects oldest)',
        (tester) async {
      EditorialTaggingData? publishedData;

      await tester.pumpWidget(
        buildTestableWidget(
          child: EditorialTaggingSheet(
            title: 'Interstellar',
            mediaType: 'movie',
            targetRank: 1,
            onPublish: (data) => publishedData = data,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select tag 1
      final tag1 = find.byKey(const Key('vibe_chip_Cinematography Peak'));
      await tester.ensureVisible(tag1);
      await tester.tap(tag1);
      await tester.pumpAndSettle();

      // Select tag 2
      final tag2 = find.byKey(const Key('vibe_chip_Mind-Bending'));
      await tester.ensureVisible(tag2);
      await tester.tap(tag2);
      await tester.pumpAndSettle();

      // Select tag 3
      final tag3 = find.byKey(const Key('vibe_chip_Great Score'));
      await tester.ensureVisible(tag3);
      await tester.tap(tag3);
      await tester.pumpAndSettle();

      expect(find.text('3/3 selected'), findsOneWidget);

      // Select tag 4: FIFO drops tag 1 ('Cinematography Peak')
      final tag4 = find.byKey(const Key('vibe_chip_Emotional Wreck'));
      await tester.ensureVisible(tag4);
      await tester.tap(tag4);
      await tester.pumpAndSettle();

      expect(find.text('3/3 selected'), findsOneWidget);

      // Publish and verify tags
      final publishBtn = find.byKey(const Key('publish_editorial_button'));
      await tester.ensureVisible(publishBtn);
      await tester.tap(publishBtn);
      await tester.pumpAndSettle();

      expect(publishedData!.vibeTags, equals(['Mind-Bending', 'Great Score', 'Emotional Wreck']));
    });

    testWidgets('tapping already selected vibe tag deselects it', (tester) async {
      EditorialTaggingData? publishedData;

      await tester.pumpWidget(
        buildTestableWidget(
          child: EditorialTaggingSheet(
            title: 'Interstellar',
            mediaType: 'movie',
            targetRank: 1,
            onPublish: (data) => publishedData = data,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tag = find.byKey(const Key('vibe_chip_Cinematography Peak'));
      await tester.ensureVisible(tag);
      await tester.tap(tag);
      await tester.pumpAndSettle();
      expect(find.text('1/3 selected'), findsOneWidget);

      // Tap again to deselect
      await tester.tap(tag);
      await tester.pumpAndSettle();
      expect(find.text('0/3 selected'), findsOneWidget);

      final publishBtn = find.byKey(const Key('publish_editorial_button'));
      await tester.ensureVisible(publishBtn);
      await tester.tap(publishBtn);
      await tester.pumpAndSettle();

      expect(publishedData!.vibeTags, isEmpty);
    });

    testWidgets('anime audio toggle renders when isAnime=true and defaults to sub',
        (tester) async {
      EditorialTaggingData? publishedData;

      await tester.pumpWidget(
        buildTestableWidget(
          child: EditorialTaggingSheet(
            title: 'Frieren: Beyond Journey\'s End',
            mediaType: 'tv',
            isAnime: true,
            targetRank: 1,
            onPublish: (data) => publishedData = data,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AUDIO MODE'), findsOneWidget);
      expect(find.byKey(const Key('audio_chip_sub')), findsOneWidget);
      expect(find.byKey(const Key('audio_chip_dub')), findsOneWidget);

      // Switch to Dub
      final dubChip = find.byKey(const Key('audio_chip_dub'));
      await tester.ensureVisible(dubChip);
      await tester.tap(dubChip);
      await tester.pumpAndSettle();

      final publishBtn = find.byKey(const Key('publish_editorial_button'));
      await tester.ensureVisible(publishBtn);
      await tester.tap(publishBtn);
      await tester.pumpAndSettle();

      expect(publishedData!.audioMode, equals(AnimeAudioMode.dub));
    });

    testWidgets('anime audio toggle is omitted when isAnime=false', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: EditorialTaggingSheet(
            title: 'Succession',
            mediaType: 'tv',
            isAnime: false,
            targetRank: 1,
            onPublish: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AUDIO MODE'), findsNothing);
      expect(find.byKey(const Key('audio_chip_sub')), findsNothing);
    });

    testWidgets('micro-review character counter updates as text is typed',
        (tester) async {
      EditorialTaggingData? publishedData;

      await tester.pumpWidget(
        buildTestableWidget(
          child: EditorialTaggingSheet(
            title: 'Severance',
            mediaType: 'tv',
            targetRank: 1,
            onPublish: (data) => publishedData = data,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final input = find.byKey(const Key('micro_review_input'));
      await tester.ensureVisible(input);
      await tester.enterText(input, 'Defiant Jazz was pure genius.');
      await tester.pumpAndSettle();

      expect(find.text('(29/280)'), findsOneWidget);

      final publishBtn = find.byKey(const Key('publish_editorial_button'));
      await tester.ensureVisible(publishBtn);
      await tester.tap(publishBtn);
      await tester.pumpAndSettle();

      expect(publishedData!.review, equals('Defiant Jazz was pure genius.'));
    });

    testWidgets('MVP character dropdown allows selecting standout cast member',
        (tester) async {
      EditorialTaggingData? publishedData;

      await tester.pumpWidget(
        buildTestableWidget(
          child: EditorialTaggingSheet(
            title: 'Succession',
            mediaType: 'tv',
            targetRank: 1,
            castMembers: const [
              'Jeremy Strong as Kendall Roy',
              'Brian Cox as Logan Roy',
              'Sarah Snook as Shiv Roy',
            ],
            onPublish: (data) => publishedData = data,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dropdown = find.byKey(const Key('mvp_character_dropdown'));
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      // Tap 'Brian Cox as Logan Roy' in popup menu
      final item = find.text('Brian Cox as Logan Roy').last;
      await tester.tap(item);
      await tester.pumpAndSettle();

      final publishBtn = find.byKey(const Key('publish_editorial_button'));
      await tester.ensureVisible(publishBtn);
      await tester.tap(publishBtn);
      await tester.pumpAndSettle();

      expect(publishedData!.mvpCharacter, equals('Brian Cox as Logan Roy'));
    });
  });

  group('FE-204: Movie-Specific Logging Tags in SCR-11 Tests', () {
    testWidgets('renders Theatrical Venue selector for movies', (tester) async {
      EditorialTaggingData? publishedData;

      await tester.pumpWidget(
        buildTestableWidget(
          child: EditorialTaggingSheet(
            title: 'Dune: Part Two',
            mediaType: 'movie',
            targetRank: 2,
            director: 'Denis Villeneuve',
            onPublish: (data) => publishedData = data,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('VIEWING VENUE (Movies Only)'), findsOneWidget);
      expect(find.byKey(const Key('venue_chip_home')), findsOneWidget);
      expect(find.byKey(const Key('venue_chip_theatrical')), findsOneWidget);
      expect(find.byKey(const Key('venue_chip_imax')), findsOneWidget);
      expect(find.byKey(const Key('venue_chip_festivalFlight')), findsOneWidget);

      // Select IMAX
      final imaxChip = find.byKey(const Key('venue_chip_imax'));
      await tester.ensureVisible(imaxChip);
      await tester.tap(imaxChip);
      await tester.pumpAndSettle();

      final publishBtn = find.byKey(const Key('publish_editorial_button'));
      await tester.ensureVisible(publishBtn);
      await tester.tap(publishBtn);
      await tester.pumpAndSettle();

      expect(publishedData!.viewingVenue, equals(ViewingVenue.imax));
      expect(publishedData!.director, isNull);
    });

    testWidgets('omits Theatrical Venue selector for TV shows', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: EditorialTaggingSheet(
            title: 'The Bear',
            mediaType: 'tv',
            targetRank: 1,
            onPublish: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('VIEWING VENUE (Movies Only)'), findsNothing);
      expect(find.byKey(const Key('venue_chip_home')), findsNothing);
      expect(find.byKey(const Key('venue_chip_theatrical')), findsNothing);

      // Verify Binge Velocity rendered for TV shows
      expect(find.text('BINGE VELOCITY'), findsOneWidget);
      expect(find.byKey(const Key('velocity_chip_weekendBinge')), findsOneWidget);
    });

    testWidgets('omits Binge Velocity for Movies', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: EditorialTaggingSheet(
            title: 'Oppenheimer',
            mediaType: 'movie',
            targetRank: 1,
            onPublish: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BINGE VELOCITY'), findsNothing);
      expect(find.byKey(const Key('velocity_chip_weekendBinge')), findsNothing);
    });

    testWidgets('rewatch status stepper increments and decrements count',
        (tester) async {
      EditorialTaggingData? publishedData;

      await tester.pumpWidget(
        buildTestableWidget(
          child: EditorialTaggingSheet(
            title: 'The Dark Knight',
            mediaType: 'movie',
            targetRank: 1,
            onPublish: (data) => publishedData = data,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default is First-Time Watch
      expect(find.byKey(const Key('rewatch_increment_button')), findsNothing);

      // Select Rewatch
      final rewatchChip = find.byKey(const Key('rewatch_chip_rewatch'));
      await tester.ensureVisible(rewatchChip);
      await tester.tap(rewatchChip);
      await tester.pumpAndSettle();

      expect(find.text('Rewatch (x2)'), findsOneWidget);
      expect(find.byKey(const Key('rewatch_increment_button')), findsOneWidget);

      // Increment to 3
      final incBtn = find.byKey(const Key('rewatch_increment_button'));
      await tester.tap(incBtn);
      await tester.pumpAndSettle();
      expect(find.text('Rewatch (x3)'), findsOneWidget);

      // Increment to 4
      await tester.tap(incBtn);
      await tester.pumpAndSettle();
      expect(find.text('Rewatch (x4)'), findsOneWidget);

      // Decrement back to 3
      final decBtn = find.byKey(const Key('rewatch_decrement_button'));
      await tester.tap(decBtn);
      await tester.pumpAndSettle();
      expect(find.text('Rewatch (x3)'), findsOneWidget);

      // Publish and verify
      final publishBtn = find.byKey(const Key('publish_editorial_button'));
      await tester.ensureVisible(publishBtn);
      await tester.tap(publishBtn);
      await tester.pumpAndSettle();

      expect(publishedData!.isRewatch, isTrue);
      expect(publishedData!.rewatchCount, equals(3));
    });

    testWidgets('director and standout performance are optional and empty by default (FE-LOG-01)', (tester) async {
      EditorialTaggingData? publishedData;
      await tester.pumpWidget(
        buildTestableWidget(
          child: EditorialTaggingSheet(
            title: 'Oppenheimer',
            mediaType: 'movie',
            targetRank: 1,
            director: 'Christopher Nolan',
            castMembers: const ['Cillian Murphy as Oppenheimer', 'Emily Blunt as Kitty'],
            onPublish: (data) => publishedData = data,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No auto-tagged forced label
      expect(find.text('Auto-tagged'), findsNothing);

      // Director chip is present but unselected by default
      final dirChipFinder = find.byKey(const Key('director_toggle_chip'));
      expect(dirChipFinder, findsOneWidget);
      expect(tester.widget<FilterChip>(dirChipFinder).selected, isFalse);

      // Standout performance dropdown defaults to null / hint
      final dropdownFinder = find.byKey(const Key('mvp_character_dropdown'));
      expect(dropdownFinder, findsOneWidget);
      expect(tester.widget<DropdownButton<String?>>(dropdownFinder).value, isNull);

      // Publish without selecting: director and standout are null
      final publishBtn = find.byKey(const Key('publish_editorial_button'));
      await tester.ensureVisible(publishBtn);
      await tester.tap(publishBtn);
      await tester.pumpAndSettle();

      expect(publishedData!.director, isNull);
      expect(publishedData!.mvpCharacter, isNull);

      // Now toggle director chip and select standout performance
      await tester.ensureVisible(dirChipFinder);
      await tester.tap(dirChipFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<FilterChip>(dirChipFinder).selected, isTrue);

      await tester.ensureVisible(dropdownFinder);
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cillian Murphy as Oppenheimer').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(publishBtn);
      await tester.tap(publishBtn);
      await tester.pumpAndSettle();

      expect(publishedData!.director, equals('Christopher Nolan'));
      expect(publishedData!.mvpCharacter, equals('Cillian Murphy as Oppenheimer'));
    });

    testWidgets('tapping Skip calls onSkip callback', (tester) async {
      bool skipped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          child: EditorialTaggingSheet(
            title: 'Interstellar',
            mediaType: 'movie',
            targetRank: 1,
            onPublish: (_) {},
            onSkip: () => skipped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final skipBtn = find.byKey(const Key('editorial_skip_button'));
      await tester.tap(skipBtn);
      await tester.pumpAndSettle();

      expect(skipped, isTrue);
    });
  });
}
