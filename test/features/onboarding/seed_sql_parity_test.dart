import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/onboarding/data/top_50_seeds.dart';

/// BE-601: `supabase/seed.sql` must seed exactly the onboarding titles the
/// client shows in SCR-03, with matching `(id, media_type)` keys and anime flags.
void main() {
  group('BE-601 seed.sql ↔ kTop50SeedTitles parity', () {
    final sql = File('supabase/seed.sql').readAsStringSync();
    final rowPattern = RegExp(r"^\((\d+), '(movie|tv)', .*, (TRUE|FALSE), '", multiLine: true);
    final sqlRows = {
      for (final m in rowPattern.allMatches(sql))
        '${m.group(1)}:${m.group(2)}': m.group(3) == 'TRUE',
    };

    test('seeds 50 titles split 35 tv / 15 movie', () {
      expect(sqlRows, hasLength(50));
      expect(sqlRows.keys.where((k) => k.endsWith(':tv')), hasLength(35));
      expect(sqlRows.keys.where((k) => k.endsWith(':movie')), hasLength(15));
    });

    test('every client seed title exists in SQL with the same media type and anime flag', () {
      for (final seed in kTop50SeedTitles) {
        final key = '${seed.id}:${seed.mediaType}';
        expect(sqlRows.containsKey(key), isTrue, reason: '$key (${seed.title}) missing from seed.sql');
        expect(sqlRows[key], seed.isAnime, reason: 'is_anime mismatch for ${seed.title}');
      }
    });
  });
}
