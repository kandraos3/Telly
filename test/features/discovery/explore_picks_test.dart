import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/features/discovery/data/discovery_repository.dart';
import 'package:telly_app/features/discovery/domain/discovery_models.dart';
import 'package:telly_app/features/discovery/presentation/controllers/explore_picks.dart';
import 'package:telly_app/features/discovery/presentation/controllers/explore_rows_controller.dart';

// #182: the Home feed's picks and the search zero state come from Explore's ranked rows.

/// One canon: 3 Drama rankings, seed 9000 ("Seed tv"/"Seed movie") at 9.8, and Drama candidates
/// [ids]; [linked] ones come from the seed, [trending] ones carry a TMDB trending rank.
Map<String, dynamic> _payload(String mediaType, List<int> ids, {Set<int> linked = const {}, Set<int> trending = const {}}) => {
      'media_type': mediaType,
      'profile': {
        'rankings': [
          for (var i = 0; i < 3; i++) {'title_id': 9000 + i, 'score': 9.8 - i, 'rank': i + 1, 'genres': ['Drama']},
        ],
        'seeds': [
          {'title_id': 9000, 'title': 'Seed $mediaType', 'score': 9.8, 'rank': 1},
        ],
        'services': ['netflix'],
        'missing_related': const [],
      },
      'candidates': [
        for (final id in ids)
          {
            'title_id': id,
            'title': 'T$id',
            'genres': ['Drama'],
            'providers': ['netflix'],
            if (linked.contains(id)) 'seed_links': [{'seed_id': 9000, 'position': 1}],
            if (trending.contains(id)) 'trending_rank': trending.toList().indexOf(id) + 1,
          },
      ],
    };

void main() {
  late AppDatabase db;
  late FakeDiscoveryRepository repo;

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      discoveryRepositoryProvider.overrideWithValue(repo),
      exploreNowProvider.overrideWithValue(() => DateTime(2026, 10, 8, 12)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = FakeDiscoveryRepository();
  });
  tearDown(() => db.close());

  test('picks alternate movie and series, hero first, with their reasons', () async {
    repo.exploreCandidates = {
      'movie': _payload('movie', [1, 2, 3, 4, 5], linked: {1}),
      'tv': _payload('tv', [50, 51, 52, 53, 54], trending: {50}),
    };
    final picks = await container().read(explorePicksProvider.future);

    expect(picks.map((p) => p.titleId).take(4), [1, 50, 2, 51]);
    expect(picks.first.reason, RecommendationReason.becauseYouLoved);
    expect(picks.first.reasonLabel, 'Because you loved Seed movie');
    expect(picks.first.providers, ['netflix']);
    expect(picks[1].mediaType, 'tv');
    expect(picks[1].reason, RecommendationReason.trending);
    expect(picks[2].reason, RecommendationReason.topRated);
  });

  test('stops at 12 and never repeats a title', () async {
    repo.exploreCandidates = {
      'movie': _payload('movie', [for (var i = 1; i <= 20; i++) i]),
      'tv': _payload('tv', [for (var i = 100; i <= 120; i++) i]),
    };
    final picks = await container().read(explorePicksProvider.future);
    expect(picks, hasLength(12));
    expect(picks.map((p) => '${p.mediaType}:${p.titleId}').toSet(), hasLength(12));
  });

  test('a canon that cannot load contributes nothing', () async {
    repo.exploreCandidates = {'movie': _payload('movie', [1, 2, 3, 4, 5])}; // series offline, no cache
    final picks = await container().read(explorePicksProvider.future);
    expect(picks.map((p) => p.mediaType).toSet(), {'movie'});
    expect(picks, hasLength(5));
  });

  test('trending alternates canons in TMDB order, up to 8', () async {
    repo.exploreCandidates = {
      'movie': _payload('movie', [1, 2, 3, 4, 5, 6], trending: {3, 1, 2, 4, 5, 6}),
      'tv': _payload('tv', [50, 51, 52, 53, 54], trending: {54, 53, 52, 51, 50}),
    };
    final trending = await container().read(exploreTrendingProvider.future);
    expect(trending.map((t) => t.titleId), [3, 54, 1, 53, 2, 52, 4, 51]);
  });
}
