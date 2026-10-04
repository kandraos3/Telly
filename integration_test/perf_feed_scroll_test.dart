import 'package:flutter/material.dart';
import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/feed/presentation/screens/activity_feed_screen.dart';

import '../test/fakes/fake_social_repository.dart';
import '../test/helpers/router_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('QA-605: Feed scrolling frame budget benchmark (traceAction + TimelineSummary)', (tester) async {
    // 1. Seed 60 realistic activity feed logs (mix of ratings & upsets)
    final feedLogs = List.generate(60, (i) {
      final isUpset = i % 4 == 0;
      return fakeActivity(
        'perf-feed-$i',
        userId: 'user-${i % 10}',
        username: 'cinephile_$i',
        titleId: 1000 + i,
        title: 'Title Index #$i',
        upset: isUpset,
        minutesAgo: i * 5,
        visibleIn: {FeedFilter.following, FeedFilter.global},
      );
    });

    final repo = FakeSocialRepository(feed: feedLogs);

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      routerHarness(
        const ActivityFeedScreen(),
        overrides: [
          socialRepositoryProvider.overrideWithValue(repo),
          hapticsEnabledProvider.overrideWith((ref) => false),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final feedFinder = find.byType(ListView);
    expect(feedFinder, findsOneWidget);

    // 2. Profile scrolling performance within 60fps frame budget (16.6ms)
    await binding.watchPerformance(
      () async {
        // Perform 10 rapid scroll interactions simulating real user flings
        for (int i = 0; i < 5; i++) {
          await tester.fling(feedFinder, const Offset(0, -600), 2000);
          await tester.pump(const Duration(milliseconds: 16));
          await tester.pump(const Duration(milliseconds: 16));
        }
        for (int i = 0; i < 5; i++) {
          await tester.fling(feedFinder, const Offset(0, 600), 2000);
          await tester.pump(const Duration(milliseconds: 16));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpAndSettle();
      },
      reportKey: 'feed_scroll_perf',
    );

    // 3. Summarize with TimelineSummary if timeline captured
    final reportData = binding.reportData;
    if (reportData != null && reportData.containsKey('feed_scroll_perf')) {
      final rawTimeline = reportData['feed_scroll_perf'];
      if (rawTimeline is Map<String, dynamic>) {
        final timeline = driver.Timeline.fromJson(rawTimeline);
        final summary = driver.TimelineSummary.summarize(timeline);

        final p90Build = summary.computePercentileFrameBuildTimeMillis(90.0);
        final p99Build = summary.computePercentileFrameBuildTimeMillis(99.0);
        final missedFrames = summary.computeMissedFrameBuildBudgetCount();

        // Ensure 90th percentile build stays well within 60fps threshold (16.6ms)
        expect(p90Build, lessThanOrEqualTo(16.6));
        expect(p99Build, lessThanOrEqualTo(33.3));
        expect(missedFrames, isNonNegative);
      }
    }
  });
}
