import 'dart:io';

/// Enforces CI Code Coverage Gates (DEV-602 / QA-608):
/// - Overall code coverage >= 80.0% (excluding generated *.g.dart files)
/// - Ranking domain (`lib/features/ranking/domain/`) coverage >= 90.0%
void main(List<String> args) {
  final lcovFile = File('coverage/lcov.info');
  if (!lcovFile.existsSync()) {
    stderr.writeln('❌ Error: coverage/lcov.info not found. Run "flutter test --coverage" first.');
    exit(1);
  }

  final lines = lcovFile.readAsLinesSync();

  var totalLines = 0;
  var hitLines = 0;

  var rankingTotal = 0;
  var rankingHit = 0;

  var currentFile = '';
  var skipCurrentFile = false;

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      currentFile = line.substring(3).trim().replaceAll(r'\', '/');
      // Skip generated code (*.g.dart, *.freezed.dart)
      skipCurrentFile = currentFile.endsWith('.g.dart') || currentFile.endsWith('.freezed.dart');
    } else if (line.startsWith('DA:') && !skipCurrentFile) {
      final parts = line.substring(3).trim().split(',');
      if (parts.length >= 2) {
        final hits = int.tryParse(parts[1]) ?? 0;
        totalLines++;
        if (hits > 0) hitLines++;

        if (currentFile.contains('lib/features/ranking/domain/')) {
          rankingTotal++;
          if (hits > 0) rankingHit++;
        }
      }
    }
  }

  if (totalLines == 0) {
    stderr.writeln('❌ Error: No instrumented lines found in coverage/lcov.info.');
    exit(1);
  }

  final overallPct = (hitLines / totalLines) * 100;
  final rankingPct = rankingTotal > 0 ? (rankingHit / rankingTotal) * 100 : 0.0;

  stdout.writeln('====================================================');
  stdout.writeln('📊 TELLY CODE COVERAGE REPORT (DEV-602)');
  stdout.writeln('====================================================');
  stdout.writeln('Overall Line Coverage:       ${overallPct.toStringAsFixed(2)}% ($hitLines / $totalLines lines)');
  stdout.writeln('Ranking Domain Coverage:     ${rankingPct.toStringAsFixed(2)}% ($rankingHit / $rankingTotal lines)');
  stdout.writeln('----------------------------------------------------');
  stdout.writeln('Overall Threshold Target:    >= 80.00%');
  stdout.writeln('Ranking Domain Target:       >= 90.00%');
  stdout.writeln('====================================================');

  // Allow simulated failure check if requested via argument
  final targetOverall = args.contains('--fail-79') ? 85.0 : 80.0;

  var failed = false;
  if (overallPct < targetOverall) {
    stderr.writeln('❌ FAILED: Overall coverage ${overallPct.toStringAsFixed(2)}% is below ${targetOverall.toStringAsFixed(2)}% target.');
    failed = true;
  } else {
    stdout.writeln('✅ Overall coverage requirement satisfied.');
  }

  if (rankingPct < 90.0) {
    stderr.writeln('❌ FAILED: Ranking domain coverage ${rankingPct.toStringAsFixed(2)}% is below 90.00% target.');
    failed = true;
  } else {
    stdout.writeln('✅ Ranking domain coverage requirement satisfied.');
  }

  if (failed) {
    exit(1);
  }

  stdout.writeln('🎉 All coverage gates passed successfully!');
}
