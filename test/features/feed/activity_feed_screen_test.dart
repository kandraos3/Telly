import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/feed/presentation/screens/activity_feed_screen.dart';

import '../../fakes/fake_social_repository.dart';
import '../../helpers/router_harness.dart';

void main() {
  late FakeSocialRepository repo;

  setUp(() {
    repo = FakeSocialRepository(
      feed: [
        fakeActivity('act-1', upset: true, minutesAgo: 1),
        fakeActivity('act-2', userId: 'u-maya', username: 'maya', titleId: 2, title: 'The Morning Show', minutesAgo: 2),
        fakeActivity('act-3', userId: 'u-alex', username: 'alex', titleId: 3, title: 'Shogun', minutesAgo: 3),
      ],
      tabs: {
        FeedFilter.squads: {'act-1', 'act-3'},
      },
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(routerHarness(const ActivityFeedScreen(), overrides: [
      socialRepositoryProvider.overrideWithValue(repo),
      hapticsEnabledProvider.overrideWith((ref) => false),
    ]));
    await tester.pumpAndSettle();
  }

  group('FE-301 / FE-607: SCR-05 ActivityFeedScreen', () {
    testWidgets('renders the tabs, an upset card and standard cards from the repository', (tester) async {
      await pump(tester);
      expect(find.text('TELLY'), findsOneWidget);
      for (final tab in ['Following', 'Squads', 'Global']) {
        expect(find.text(tab), findsOneWidget);
      }
      expect(find.byKey(const Key('upset_card_act-1')), findsOneWidget);
      expect(find.byKey(const Key('upset_consensus_text')), findsOneWidget);
      expect(find.text('Community consensus favors Succession by 3.1 pts'), findsOneWidget);
      expect(find.byKey(const Key('feed_card_act-2')), findsOneWidget);
      expect(repo.pageRequests.first, (FeedFilter.following, null));
    });

    testWidgets('switching tabs loads that tab', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Squads'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('upset_card_act-1')), findsOneWidget);
      expect(find.byKey(const Key('feed_card_act-3')), findsOneWidget);
      expect(find.byKey(const Key('feed_card_act-2')), findsNothing);
      expect(repo.pageRequests.last, (FeedFilter.squads, null));
    });

    testWidgets('scrolling to the bottom loads the next keyset page', (tester) async {
      repo.feed
        ..clear()
        ..addAll([for (var i = 0; i < 30; i++) fakeActivity('a$i', titleId: 1000 + i, title: 'Show $i', minutesAgo: i)]);
      await pump(tester);
      expect(repo.pageRequests, [(FeedFilter.following, null)]);

      await tester.dragUntilVisible(
        find.byKey(const Key('feed_card_a29')),
        find.byKey(const Key('feed_list')),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(repo.pageRequests.last, (FeedFilter.following, 'a19'), reason: 'cursor = last item of page 1');
      expect(find.byKey(const Key('feed_page_loader')), findsNothing);
    });

    testWidgets('a reaction updates instantly and is sent to the server', (tester) async {
      await pump(tester);
      await tester.tap(find.descendant(of: find.byKey(const Key('feed_card_act-2')), matching: find.textContaining('🤯')).first);
      await tester.pumpAndSettle();
      expect(repo.reactions.single, ('act-2', FeedReactionType.mindBlown, true));
    });

    testWidgets('a rejected reaction rolls back and explains', (tester) async {
      repo.failWrites = true;
      await pump(tester);
      final card = find.byKey(const Key('feed_card_act-2'));
      await tester.tap(find.descendant(of: card, matching: find.textContaining('🔥')).first);
      await tester.pumpAndSettle();
      expect(find.textContaining("Couldn't save that"), findsOneWidget);
      expect(find.descendant(of: card, matching: find.textContaining('3')), findsWidgets, reason: 'count restored');
    });

    testWidgets('+ Want to Watch saves to the queue', (tester) async {
      await pump(tester);
      await tester.tap(find.descendant(of: find.byKey(const Key('feed_card_act-2')), matching: find.text('+ Want to Watch')));
      await tester.pumpAndSettle();
      expect(repo.queued.single, (2, true));
      expect(find.descendant(of: find.byKey(const Key('feed_card_act-2')), matching: find.text('In Queue')), findsOneWidget);
    });

    testWidgets('long-press → report hides the post for me', (tester) async {
      await pump(tester);
      await tester.longPress(find.byKey(const Key('feed_card_act-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report_reason_unmarkedSpoiler')));
      await tester.pumpAndSettle();

      expect(repo.reports.single, (ReportTarget.activity, 'act-2', ReportReason.unmarkedSpoiler));
      expect(find.byKey(const Key('feed_card_act-2')), findsNothing);
      expect(find.text('Thanks. Our moderators will review it.'), findsOneWidget);
    });

    testWidgets('a failed report keeps the post and says so', (tester) async {
      repo.failWrites = true;
      await pump(tester);
      await tester.longPress(find.byKey(const Key('feed_card_act-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report_reason_spam')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('feed_card_act-2')), findsOneWidget);
      expect(find.textContaining("didn't go through"), findsOneWidget);
    });

    testWidgets('block removes every post by that user', (tester) async {
      repo.feed.add(fakeActivity('act-4', userId: 'u-maya', username: 'maya', titleId: 4, title: 'Fleabag', minutesAgo: 4));
      await pump(tester);
      await tester.longPress(find.byKey(const Key('feed_card_act-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('block_user_action')));
      await tester.pumpAndSettle();

      expect(repo.blocked, ['u-maya']);
      expect(find.byKey(const Key('feed_card_act-2')), findsNothing);
      expect(find.byKey(const Key('feed_card_act-4')), findsNothing);
      expect(find.byKey(const Key('upset_card_act-1')), findsOneWidget);
    });
  });
}
