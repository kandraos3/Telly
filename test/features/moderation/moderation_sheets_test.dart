import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/moderation/domain/moderation_models.dart';
import 'package:telly_app/features/moderation/presentation/widgets/report_content_sheet.dart';
import 'package:telly_app/features/moderation/presentation/widgets/spoiler_shield_sheet.dart';

void main() {
  group('Moderation & Spoiler Shield Sheets Tests (FE-508)', () {
    testWidgets('ReportContentSheet renders reasons and submits report', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      ContentReport? submittedReport;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportContentSheet(
              contentId: 'rev_123',
              contentType: 'review',
              authorUsername: 'alex',
              titleName: 'Severance',
              onSubmitted: (report) {
                submittedReport = report;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('REPORT CONTENT'), findsOneWidget);
      expect(find.text('WHAT IS WRONG WITH THIS POST?'), findsOneWidget);
      expect(find.text('Major Unmarked Spoilers'), findsOneWidget);
      expect(find.text('Harassment / Hate Speech'), findsOneWidget);
      expect(find.text('Spam / Commercial Promotion'), findsOneWidget);
      expect(find.text('Inaccurate Metadata'), findsOneWidget);

      // Select Harassment
      await tester.tap(find.text('Harassment / Hate Speech'));
      await tester.pumpAndSettle();

      // Check actions
      await tester.tap(find.text('Block @alex completely'));
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Submit Report to Moderation'));
      await tester.pumpAndSettle();

      expect(submittedReport, isNotNull);
      expect(submittedReport!.reason, equals(ContentReportReason.harassment));
      expect(submittedReport!.blockedAuthor, isTrue);
      expect(submittedReport!.authorUsername, equals('alex'));
    });

    testWidgets('SpoilerShieldSheet mutes and unmutes titles', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      List<MutedTitle>? updatedTitles;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpoilerShieldSheet(
              initialMutedTitles: [
                MutedTitle(
                  tmdbId: 94997,
                  title: 'House of the Dragon',
                  mediaType: 'tv',
                  mutedAt: DateTime.now(),
                ),
              ],
              onMutedListChanged: (titles) {
                updatedTitles = titles;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('🛡️ SPOILER SHIELD'), findsOneWidget);
      expect(find.text('CURRENTLY SHIELDED (1)'), findsOneWidget);
      expect(find.text('House of the Dragon'), findsWidgets);

      // Tap popular suggestion to mute Severance
      await tester.tap(find.text('Severance'));
      await tester.pumpAndSettle();

      expect(find.text('CURRENTLY SHIELDED (2)'), findsOneWidget);
      expect(updatedTitles, isNotNull);
      expect(updatedTitles!.length, equals(2));

      // Tap Unmute All
      await tester.tap(find.text('Unmute All'));
      await tester.pumpAndSettle();

      expect(find.text('CURRENTLY SHIELDED (0)'), findsOneWidget);
      expect(find.text('No titles currently shielded.\nAll feed posts and spoilers are visible.'), findsOneWidget);
    });
  });
}

