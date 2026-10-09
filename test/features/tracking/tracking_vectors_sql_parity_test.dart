import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #225: the pgTAP file is generated from the shared fixture
/// (`python tool/tracking/generate_vectors_sql.py`). It fails here when it stops embedding
/// every vector, so Dart and SQL can't quietly diverge.
void main() {
  final fixture =
      jsonDecode(File('test/fixtures/tracking_progress_vectors.json').readAsStringSync()) as Map<String, dynamic>;
  final sql = File('supabase/tests/database/035_tracking_progress_vectors.test.sql').readAsStringSync();

  String lit(String s) => "'${s.replaceAll("'", "''")}'";

  test('035 declares a plan that matches its assertions', () {
    final vectors = fixture['vectors'] as List;
    final movies = fixture['movie_vectors'] as List;
    final events = fixture['event_vectors'] as List;
    expect(sql, contains('SELECT plan(${1 + movies.length + events.length});'));
    expect(sql, contains('match all ${vectors.length} fixture vectors'));
  });

  test('035 creates every fixture show with its seasons', () {
    for (final entry in (fixture['shows'] as Map<String, dynamic>).entries) {
      final show = entry.value as Map<String, dynamic>;
      expect(sql, contains(lit(entry.key)), reason: 'show ${entry.key}');
      expect(sql, contains(lit(show['status'] as String)), reason: 'status of ${entry.key}');
      for (final s in show['seasons'] as List) {
        final season = s as Map<String, dynamic>;
        expect(sql, contains("${season['number']}, ${season['episode_count']}, "),
            reason: '${entry.key} season ${season['number']}');
      }
    }
  });

  test('035 embeds every state vector with its expected state', () {
    for (final raw in fixture['vectors'] as List) {
      final v = raw as Map<String, dynamic>;
      final row = sql.split('\n').where((l) => l.contains(lit(v['name'] as String))).toList();
      expect(row, isNotEmpty, reason: 'vector ${v['name']}');
      expect(row.first, contains(lit(v['state'] as String)), reason: 'state of ${v['name']}');
    }
  });

  test('035 embeds every movie vector', () {
    for (final raw in fixture['movie_vectors'] as List) {
      final v = raw as Map<String, dynamic>;
      final line = sql.split('\n').firstWhere((l) => l.contains(lit('movie: ${v['name']}')), orElse: () => '');
      expect(line, isNotEmpty, reason: 'movie vector ${v['name']}');
      expect(line, contains(lit(v['state'] as String)));
    }
  });

  test('035 embeds every event vector with its expected events', () {
    for (final raw in fixture['event_vectors'] as List) {
      final v = raw as Map<String, dynamic>;
      final expected = [
        for (final e in v['events'] as List) "${(e as Map)['kind']} S${e['season']}E${e['episode']}",
      ].join(', ');
      final line = sql.split('\n').firstWhere((l) => l.contains(lit('events: ${v['name']}')), orElse: () => '');
      expect(line, isNotEmpty, reason: 'event vector ${v['name']}');
      expect(line, contains(lit(expected)), reason: 'events of ${v['name']}');
    }
  });
}
