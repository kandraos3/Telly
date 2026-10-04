import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/feed/presentation/screens/comment_thread_screen.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_social_repository.dart';

void main() {
  late FakeSocialRepository repo;
  final activity = fakeActivity('act-1', upset: true);

  RankingComment comment(String id, String text, {bool spoiler = false}) => RankingComment(
        id: id,
        rankingId: 'act-1',
        userId: 'u-alex',
        username: 'alex',
        userDisplayName: 'Alex',
        commentText: text,
        containsSpoilers: spoiler,
        createdAt: DateTime(2026, 10, 3),
      );

  setUp(() {
    repo = FakeSocialRepository(feed: [activity]);
    repo.comments['act-1'] = [
      comment('c-safe', 'Logan Roy is untouchable.'),
      comment('c-spoil', 'Kendall takes the blame', spoiler: true),
    ];
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        socialRepositoryProvider.overrideWithValue(repo),
        hapticsEnabledProvider.overrideWith((ref) => false),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(signedInUserId: 'u-me')),
      ],
      child: MaterialApp(theme: TellyTheme.dark, home: CommentThreadScreen(activity: activity)),
    ));
    await tester.pumpAndSettle();
  }

  group('FE-305 / FE-607: SCR-06 spoiler-safe comment thread', () {
    testWidgets('spoilers sit under a frosted BackdropFilter (σ 8); tap reveals, tap again re-blurs', (tester) async {
      await pump(tester);
      expect(find.text('Logan Roy is untouchable.'), findsOneWidget);
      expect(find.byKey(const Key('spoiler_mask_c-safe')), findsNothing);

      final blur = find.byKey(const Key('spoiler_blur_c-spoil'));
      expect(blur, findsOneWidget);
      final filter = tester.widget<BackdropFilter>(blur).filter;
      expect(filter, ImageFilter.blur(sigmaX: 8, sigmaY: 8));
      expect(find.text('TAP TO REVEAL SPOILER'), findsOneWidget);

      await tester.tap(find.byKey(const Key('spoiler_mask_c-spoil')));
      await tester.pumpAndSettle();
      expect(blur, findsNothing);

      await tester.tap(find.byKey(const Key('spoiler_mask_c-spoil')));
      await tester.pumpAndSettle();
      expect(blur, findsOneWidget, reason: 're-blurred');
    });

    testWidgets('the composer tags a spoiler and posts it masked', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('composer_spoiler_toggle')));
      await tester.enterText(find.byKey(const Key('comment_input')), 'The goat dies');
      await tester.tap(find.byKey(const Key('comment_send')));
      await tester.pumpAndSettle();

      final posted = repo.comments['act-1']!.last;
      expect(posted.commentText, 'The goat dies');
      expect(posted.containsSpoilers, isTrue);
      expect(find.byKey(Key('spoiler_blur_${posted.id}')), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('comment_input'))).controller!.text, isEmpty);
    });

    testWidgets('a failed post keeps the draft and explains', (tester) async {
      repo.failWrites = true;
      await pump(tester);
      await tester.enterText(find.byKey(const Key('comment_input')), 'hot take');
      await tester.tap(find.byKey(const Key('comment_send')));
      await tester.pumpAndSettle();
      expect(find.textContaining("Couldn't post your comment"), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('comment_input'))).controller!.text, 'hot take');
    });

    testWidgets('long-press → report a comment hides it', (tester) async {
      await pump(tester);
      await tester.longPress(find.byKey(const Key('comment_row_c-safe')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report_reason_harassment')));
      await tester.pumpAndSettle();
      expect(repo.reports.single, (ReportTarget.comment, 'c-safe', ReportReason.harassment));
      expect(find.text('Logan Roy is untouchable.'), findsNothing);
    });
  });
}
