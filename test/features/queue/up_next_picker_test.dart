import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/queue/domain/up_next_picker.dart';

/// #134: the Queue's random "Up next" pick (screen spec SCR-13).
void main() {
  group('UpNextPicker', () {
    test('an empty pool has no pick', () {
      expect(UpNextPicker(Random(1)).pickFor('tv', const []), isNull);
    });

    test('picks from the pool and keeps the pick while it stays in the pool', () {
      final picker = UpNextPicker(Random(7));
      final pool = [10, 20, 30, 40];
      final first = picker.pickFor('tv', pool);
      expect(pool, contains(first));
      for (var i = 0; i < 20; i++) {
        expect(picker.pickFor('tv', pool), first);
      }
      // Reordering the pool (a new sort) keeps the pick too.
      expect(picker.pickFor('tv', pool.reversed.toList()), first);
    });

    test('each canon keeps its own pick', () {
      final picker = UpNextPicker(Random(3));
      final tv = picker.pickFor('tv', [1, 2, 3]);
      final movie = picker.pickFor('movie', [101, 102, 103]);
      expect([101, 102, 103], contains(movie));
      expect(picker.pickFor('tv', [1, 2, 3]), tv);
      expect(picker.pickFor('movie', [101, 102, 103]), movie);
    });

    test('re-picks at once when the pick leaves the pool', () {
      final picker = UpNextPicker(Random(11));
      final first = picker.pickFor('tv', [1, 2, 3])!;
      final rest = [1, 2, 3]..remove(first);
      final next = picker.pickFor('tv', rest);
      expect(rest, contains(next));
    });

    test('shuffle never returns the current pick', () {
      final picker = UpNextPicker(Random(5));
      final pool = [1, 2, 3];
      var current = picker.pickFor('tv', pool);
      for (var i = 0; i < 50; i++) {
        final next = picker.shuffle('tv', pool);
        expect(next, isNot(current));
        expect(pool, contains(next));
        expect(picker.pickFor('tv', pool), next, reason: 'the shuffled title becomes the pick');
        current = next;
      }
    });

    test('shuffle with one title keeps it; with none returns null', () {
      final picker = UpNextPicker(Random(2));
      expect(picker.shuffle('tv', [42]), 42);
      expect(picker.shuffle('tv', const []), isNull);
    });

    test('the pick is uniform over the pool', () {
      final counts = <int, int>{};
      for (var seed = 0; seed < 3000; seed++) {
        final id = UpNextPicker(Random(seed)).pickFor('tv', [1, 2, 3])!;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      for (final id in [1, 2, 3]) {
        expect(counts[id]!, inInclusiveRange(850, 1150), reason: 'title $id');
      }
    });
  });
}
