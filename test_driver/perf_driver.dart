// Performance profiling driver for measuring 60fps/120fps frame budgets (QA-504)
// Conforms to `docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md` §5.3.

// ignore_for_file: avoid_print
import 'package:flutter_driver/flutter_driver.dart' as driver;

void main() async {
  final d = await driver.FlutterDriver.connect();

  try {
    // Warm up the rendering pipeline
    await d.waitUntilFirstFrameRasterized();

    // Start timeline tracing for raster and build phases
    await d.startTracing(
      streams: [
        driver.TimelineStream.all,
      ],
    );

    // Run scrolling benchmark
    final listFinder = driver.find.byType('ListView');
    await d.scroll(listFinder, 0, -2000, const Duration(seconds: 2));
    await d.scroll(listFinder, 0, 2000, const Duration(seconds: 2));

    // Finish tracing and write timeline summary
    final timeline = await d.stopTracingAndDownloadTimeline();
    final summary = driver.TimelineSummary.summarize(timeline);

    // Save performance timeline
    await summary.writeTimelineToFile('feed_scroll_perf', pretty: true);

    print('Frame rasterization and build budget profile written successfully.');
  } finally {
    await d.close();
  }
}
