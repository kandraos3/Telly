// Performance profiling driver for measuring 60fps/120fps frame budgets (QA-605)
// Conforms to `docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md` §5.3.

// ignore_for_file: avoid_print
import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
      responseDataCallback: (data) async {
        if (data != null) {
          for (final entry in data.entries) {
            if (entry.value is Map<String, dynamic>) {
              final timeline = driver.Timeline.fromJson(entry.value as Map<String, dynamic>);
              final summary = driver.TimelineSummary.summarize(timeline);
              await summary.writeTimelineToFile(entry.key, pretty: true);
              print('--- Performance Summary: ${entry.key} ---');
              print('Average frame build time: ${summary.computeAverageFrameBuildTimeMillis()} ms');
              print('90th percentile frame build time: ${summary.computePercentileFrameBuildTimeMillis(90.0)} ms');
              print('99th percentile frame build time: ${summary.computePercentileFrameBuildTimeMillis(99.0)} ms');
              print('90th percentile raster time: ${summary.computePercentileFrameRasterizerTimeMillis(90.0)} ms');
              print('99th percentile raster time: ${summary.computePercentileFrameRasterizerTimeMillis(99.0)} ms');
              print('Missed frame build budget count: ${summary.computeMissedFrameBuildBudgetCount()}');
            }
          }
        }
      },
    );
