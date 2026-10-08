import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/features/discovery/data/discovery_repository.dart';
import 'package:telly_app/features/discovery/domain/explore_ranker.dart';
import 'package:telly_app/features/discovery/presentation/controllers/explore_rows_controller.dart';

// Spec: docs/features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md §7.5 (cache, staleness, states)
// and §7.6 (missing_related → title-related, once).

/// A payload with 3 Drama rankings and [ids] as Drama candidates (no seed links, so no hero
/// unless taste qualifies: every candidate here does, so the first is the hero).
Map<String, dynamic> _payload(List<int> ids, {List<int> missing = const []}) => {
      'media_type': 'movie',
      'profile': {
        'rankings': [
          for (var i = 0; i < 3; i++) {'title_id': 9000 + i, 'score': 9.0, 'rank': i + 1, 'genres': ['Drama']},
        ],
        'seeds': const [],
        'services': const [],
        'missing_related': missing,
      },
      'candidates': [
        for (final id in ids) {'title_id': id, 'title': 'T$id', 'genres': ['Drama']},
      ],
    };

List<int> _picks(ExploreRowsState s) =>
    [s.rows.hero!.pick.titleId, ...?s.rows.row(ExploreRowKind.topPicks)?.items.map((i) => i.titleId)];

void main() {
  late AppDatabase db;
  late FakeDiscoveryRepository repo;
  late DateTime now;

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      discoveryRepositoryProvider.overrideWithValue(repo),
      exploreNowProvider.overrideWithValue(() => now),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = FakeDiscoveryRepository();
    now = DateTime(2026, 10, 8, 12);
  });
  tearDown(() => db.close());

  test('with no cache, fetches, ranks and caches the payload', () async {
    repo.exploreCandidates = {'movie': _payload([1, 2, 3, 4, 5])};
    final s = await container().read(exploreRowsProvider('movie').future);

    expect(_picks(s), [1, 2, 3, 4, 5]);
    expect(s.isOffline, isFalse);
    expect(s.savedAt, now);
    final cached = await db.exploreCacheDao.read('movie');
    expect(jsonDecode(cached!.json)['candidates'], hasLength(5));
  });

  test('a fresh cache shows without a fetch', () async {
    await db.exploreCacheDao.write('movie', jsonEncode(_payload([7, 8, 9, 10, 11])), now.subtract(const Duration(hours: 5)));
    final s = await container().read(exploreRowsProvider('movie').future);

    expect(_picks(s), [7, 8, 9, 10, 11]);
    expect(repo.exploreFetches, 0);
  });

  test('a stale cache shows at once, then the refetch replaces it', () async {
    await db.exploreCacheDao.write('movie', jsonEncode(_payload([7, 8, 9, 10, 11])), now.subtract(const Duration(hours: 7)));
    repo.exploreCandidates = {'movie': _payload([1, 2, 3, 4, 5])};
    final c = container();

    final first = await c.read(exploreRowsProvider('movie').future);
    expect(_picks(first), [7, 8, 9, 10, 11]);

    await pumpEventQueue();
    final second = c.read(exploreRowsProvider('movie')).requireValue;
    expect(_picks(second), [1, 2, 3, 4, 5]);
    expect(second.savedAt, now);
    expect(repo.exploreFetches, 1);
  });

  test('offline with a stale cache keeps the cached rows, marked offline', () async {
    final savedAt = now.subtract(const Duration(hours: 8));
    await db.exploreCacheDao.write('movie', jsonEncode(_payload([7, 8, 9, 10, 11])), savedAt);
    repo.exploreOffline = true;
    final c = container();

    await c.read(exploreRowsProvider('movie').future);
    await pumpEventQueue();
    final s = c.read(exploreRowsProvider('movie')).requireValue;
    expect(_picks(s), [7, 8, 9, 10, 11]);
    expect(s.isOffline, isTrue);
    expect(s.savedAt, savedAt); // for "Showing picks from 8 h ago"
  });

  test('offline with no cache is an error', () async {
    repo.exploreOffline = true;
    final c = container();
    await expectLater(c.read(exploreRowsProvider('movie').future), throwsA(isA<StateError>()));
    expect(c.read(exploreRowsProvider('movie')).hasError, isTrue);
  });

  test('missing seeds are sent to title-related once, then refetched once', () async {
    // Both payloads report a missing seed; the controller must not loop.
    repo.exploreCandidates = {'movie': _payload([1, 2, 3, 4], missing: [9000, 9001])};
    final s = await container().read(exploreRowsProvider('movie').future);

    expect(repo.relatedRequests, hasLength(1));
    expect(repo.relatedRequests.single.$1, [9000, 9001]);
    expect(repo.relatedRequests.single.$2, 'movie');
    expect(repo.exploreFetches, 2);
    expect(s.rows.hero, isNotNull);
  });

  test('refresh always refetches, and keeps the rows when it fails', () async {
    await db.exploreCacheDao.write('movie', jsonEncode(_payload([7, 8, 9, 10, 11])), now);
    repo.exploreCandidates = {'movie': _payload([1, 2, 3, 4, 5])};
    final c = container();
    await c.read(exploreRowsProvider('movie').future);

    await c.read(exploreRowsProvider('movie').notifier).refresh();
    expect(_picks(c.read(exploreRowsProvider('movie')).requireValue), [1, 2, 3, 4, 5]);
    expect(repo.exploreFetches, 1);

    repo.exploreOffline = true;
    await c.read(exploreRowsProvider('movie').notifier).refresh();
    final s = c.read(exploreRowsProvider('movie')).requireValue;
    expect(_picks(s), [1, 2, 3, 4, 5]);
    expect(s.isOffline, isTrue);
  });

  test('each canon has its own payload and cache', () async {
    repo.exploreCandidates = {
      'movie': _payload([1, 2, 3, 4, 5]),
      'tv': {..._payload([50, 51, 52, 53, 54]), 'media_type': 'tv'},
    };
    final c = container();
    final tv = await c.read(exploreRowsProvider('tv').future);
    expect(tv.rows.mediaType, 'tv');
    expect(_picks(tv), [50, 51, 52, 53, 54]);
    expect(await db.exploreCacheDao.read('movie'), isNull);
  });

  test('an unreadable cache is treated as no cache', () async {
    await db.exploreCacheDao.write('movie', 'not json', now);
    repo.exploreCandidates = {'movie': _payload([1, 2, 3, 4, 5])};
    final s = await container().read(exploreRowsProvider('movie').future);
    expect(_picks(s), [1, 2, 3, 4, 5]);
  });
}
