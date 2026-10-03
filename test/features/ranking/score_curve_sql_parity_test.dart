import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// QA-607: the pgTAP parity test must embed exactly the shared fixture vectors,
/// so Dart (`ScoreCurveCalculator`) and SQL (`canon_score`) are checked against the same data.
void main() {
  test('supabase/tests/database/003_score_curve_parity.test.sql embeds every fixture vector', () {
    final fixture = jsonDecode(File('test/fixtures/score_curve_vectors.json').readAsStringSync()) as Map<String, dynamic>;
    final vectors = (fixture['vectors'] as List).cast<Map<String, dynamic>>();
    final sql = File('supabase/tests/database/003_score_curve_parity.test.sql').readAsStringSync();

    final embedded = RegExp(r'^\s+\((\d+), (\d+), (\d+\.\d{2})\)', multiLine: true)
        .allMatches(sql)
        .map((m) => '${m.group(1)}:${m.group(2)}:${m.group(3)}')
        .toSet();
    final expected = vectors
        .map((v) => '${v['n']}:${v['rank']}:${(v['score'] as num).toDouble().toStringAsFixed(2)}')
        .toSet();

    expect(embedded, expected);
  });
}
