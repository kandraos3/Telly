import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/discovery/domain/explore_candidates.dart';
import 'package:telly_app/features/discovery/domain/explore_ranker.dart';

// Spec: docs/features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md §7.2 (rows) and §7.4 (scoring).

const _ranker = ExploreRanker();
final _today = DateTime(2026, 10, 7);

ExploreCandidate _c(
  int id, {
  String mediaType = 'movie',
  List<String> genres = const ['Drama'],
  List<SeedLink> links = const [],
  int? trendingRank,
  int tellyRecent = 0,
  List<CandidateFriend> friends = const [],
  List<String> providers = const [],
  bool onMyServices = false,
  DateTime? leavingUntil,
  bool inQueue = false,
  double? community,
  int communityCount = 0,
  int? collectionId,
  String? director,
}) =>
    ExploreCandidate(
      titleId: id,
      mediaType: mediaType,
      title: 'T$id',
      genres: genres,
      seedLinks: links,
      trendingRank: trendingRank,
      tellyRecentRankings: tellyRecent,
      friends: friends,
      providers: providers,
      onMyServices: onMyServices,
      leavingUntil: leavingUntil,
      inQueue: inQueue,
      communityScore: community,
      communityCount: communityCount,
      collectionId: collectionId,
      director: director,
    );

/// [n] Drama rankings scored 9.0 (ids 9000…), so the genre profile is pure Drama.
List<ProfileRanking> _rankings(int n, {List<String> genres = const ['Drama']}) =>
    [for (var i = 0; i < n; i++) ProfileRanking(titleId: 9000 + i, score: 9.0, rank: i + 1, genres: genres)];

ExploreSeed _seed(int rank, {double score = 9.5}) =>
    ExploreSeed(titleId: 9000 + rank - 1, title: 'Seed $rank', score: score, rank: rank);

ExploreCandidates _p(
  List<ExploreCandidate> candidates, {
  int rankings = 5,
  List<ExploreSeed> seeds = const [],
  List<String> services = const [],
  String mediaType = 'movie',
  List<ProfileRanking>? profile,
}) =>
    ExploreCandidates(
      mediaType: mediaType,
      profile: ExploreProfile(rankings: profile ?? _rankings(rankings), seeds: seeds, services: services),
      candidates: candidates,
    );

List<int> _ids(ExploreRow? row) => [for (final s in row?.visible ?? const <ScoredCandidate>[]) s.titleId];

void main() {
  group('genre profile', () {
    test('weights each ranking by score above 5.50, split across its genres, unit length', () {
      final g = ExploreRanker.genreProfile(const [
        ProfileRanking(titleId: 1, score: 9.5, genres: ['Drama', 'Crime']), // 4.0 → 2 + 2
        ProfileRanking(titleId: 2, score: 7.5, genres: ['Drama']), // 2.0 → Drama
        ProfileRanking(titleId: 3, score: 5.0, genres: ['Comedy']), // below the floor
      ]);
      // Drama 4, Crime 2, norm √20.
      expect(g['Drama'], closeTo(0.894427, 1e-6));
      expect(g['Crime'], closeTo(0.447214, 1e-6));
      expect(g.containsKey('Comedy'), isFalse);
    });

    test('is empty when nothing scores above the floor or no genres', () {
      expect(ExploreRanker.genreProfile(const [ProfileRanking(titleId: 1, score: 5.5, genres: ['Drama'])]), isEmpty);
      expect(ExploreRanker.genreProfile(const [ProfileRanking(titleId: 1, score: 9.0)]), isEmpty);
    });
  });

  group('components', () {
    final g = {'Drama': 0.894427, 'Crime': 0.447214};

    test('taste is the cosine with the title genres', () {
      expect(ExploreRanker.taste(g, ['Drama']), closeTo(0.894427, 1e-6));
      expect(ExploreRanker.taste(g, ['Drama', 'Crime']), closeTo(0.948683, 1e-6));
      expect(ExploreRanker.taste(g, ['Drama', 'Drama']), closeTo(0.894427, 1e-6));
      expect(ExploreRanker.taste(g, ['Comedy']), 0);
      expect(ExploreRanker.taste(g, const []), 0);
      expect(ExploreRanker.taste(const {}, ['Drama']), 0);
    });

    test('seeds weighs each link by seed score and TMDB position, capped at 1', () {
      expect(ExploreRanker.seedWeight(10.0), closeTo(1.0, 1e-9));
      expect(ExploreRanker.seedWeight(7.8), closeTo(0.083333, 1e-6));
      final s10 = _seed(1, score: 10.0), s9 = _seed(2, score: 9.0);
      final byId = {s10.titleId: s10, s9.titleId: s9};
      expect(ExploreRanker.linkContribution(s10, SeedLink(seedId: s10.titleId, position: 11)), closeTo(0.5, 1e-9));
      expect(ExploreRanker.linkContribution(s10, SeedLink(seedId: s10.titleId, position: 20)), closeTo(0.05, 1e-9));
      expect(ExploreRanker.seeds([SeedLink(seedId: s9.titleId, position: 11)], byId), closeTo(0.291667, 1e-6));
      expect(
        ExploreRanker.seeds([SeedLink(seedId: s10.titleId, position: 1), SeedLink(seedId: s9.titleId, position: 1)], byId),
        1.0,
      );
      expect(ExploreRanker.seeds(const [SeedLink(seedId: 42, position: 1)], byId), 0);
    });

    test('friends is a noisy-or of taste match × liking, with 0.5 defaults', () {
      expect(ExploreRanker.friends(const []), 0);
      const fan = CandidateFriend(userId: 'a', displayName: 'A', score: 10, matchPct: 80);
      const queuedOnly = CandidateFriend(userId: 'b', displayName: 'B');
      expect(ExploreRanker.friends(const [fan]), closeTo(0.8, 1e-9));
      expect(ExploreRanker.friends(const [fan, queuedOnly]), closeTo(0.85, 1e-9));
      expect(ExploreRanker.friends(const [CandidateFriend(userId: 'c', displayName: 'C', score: 5.0, matchPct: 90)]), 0);
    });

    test('quality trusts Telly from 5 rankings, else shrinks TMDB toward 6.8', () {
      expect(ExploreRanker.quality(_c(1, community: 9.0, communityCount: 5)), closeTo(0.777778, 1e-6));
      const tmdb = ExploreCandidate(
          titleId: 2, mediaType: 'movie', title: 'x', communityScore: 9.0, communityCount: 4, tmdbVoteAverage: 8.0, tmdbVoteCount: 500);
      expect(ExploreRanker.quality(tmdb), closeTo(0.422222, 1e-6)); // (500·8 + 500·6.8)/1000 = 7.4
      expect(ExploreRanker.quality(_c(3)), 0.5);
      expect(ExploreRanker.quality(_c(4, community: 4.0, communityCount: 9)), 0);
      expect(ExploreRanker.quality(_c(5, community: 10.0, communityCount: 9)), 1);
    });

    test('fit, matchPct and different combine the parts', () {
      final s = ScoredCandidate(candidate: _c(1), taste: 0.5, seeds: 0.5, friends: 0, quality: 1, services: 1);
      expect(s.fit, closeTo(0.55, 1e-9));
      expect(s.matchPct, 65); // 100 · 0.55 / 0.85 = 64.7
      expect(ExploreRanker.matchPct(0), 1);
      expect(ExploreRanker.matchPct(1), 99);

      final d = ScoredCandidate(candidate: _c(2), taste: 0.1, seeds: 0, friends: 0.4, quality: 0.8, services: 1);
      expect(d.different, closeTo(0.73, 1e-9));
      expect(d.isDifferent, isTrue);
      expect(ScoredCandidate(candidate: _c(3), taste: 0.3, seeds: 0, friends: 0, quality: 0.9, services: 0).isDifferent, isFalse);
      expect(ScoredCandidate(candidate: _c(4), taste: 0.1, seeds: 0, friends: 0, quality: 0.5, services: 0).isDifferent, isFalse);
    });
  });

  group('seed rotation', () {
    test('starts at daysSinceEpoch mod n, sorted by rank, wrapping', () {
      final seeds = [_seed(5), _seed(1), _seed(3), _seed(2), _seed(4)];
      final day2 = DateTime(1970, 1, 3); // 2 days since epoch → start at index 2
      expect(ExploreRanker.daysSinceEpoch(day2), 2);
      expect([for (final s in ExploreRanker.seedRotation(seeds, day2)) s.rank], [3, 4, 5, 1, 2]);
      expect(ExploreRanker.seedRotation(const [], day2), isEmpty);
    });

    test('takes 3 rows and skips a seed with fewer than 4 unused picks', () {
      final seeds = [for (var r = 1; r <= 5; r++) _seed(r)];
      // Seed 3 has only 3 linked titles; the others have 4 each.
      final candidates = <ExploreCandidate>[
        // The hero: linked to seed 1 too, but far ahead on fit, so seed 1 still has 4 picks.
        _c(1, links: const [SeedLink(seedId: 9000, position: 1)], onMyServices: true, community: 10, communityCount: 9),
        for (var r = 1; r <= 5; r++)
          for (var k = 0; k < (r == 3 ? 3 : 4); k++) _c(r * 100 + k, links: [SeedLink(seedId: 9000 + r - 1, position: k + 1)]),
      ];
      final rows = _ranker.rank(_p(candidates, seeds: seeds), DateTime(1970, 1, 3));
      final because = rows.rows.where((r) => r.kind == ExploreRowKind.becauseYouRanked).toList();
      expect(rows.hero!.pick.titleId, 1);
      expect([for (final r in because) r.seed!.rank], [4, 5, 1]);
      expect(because.every((r) => r.items.length >= 4), isTrue);
    });
  });

  group('rows', () {
    test('new user gets Top rated by quality and no hero or personal rows', () {
      final candidates = [
        for (var i = 1; i <= 5; i++)
          _c(i, community: 6.0 + i * 0.5, communityCount: 9, links: [SeedLink(seedId: 9000, position: i)]),
      ];
      final rows = _ranker.rank(_p(candidates, rankings: 2, seeds: [_seed(1)]), _today);
      expect(rows.isNewUser, isTrue);
      expect(rows.hero, isNull);
      expect(rows.row(ExploreRowKind.topPicks), isNull);
      expect(rows.row(ExploreRowKind.becauseYouRanked), isNull);
      expect(_ids(rows.row(ExploreRowKind.topRated)), [5, 4, 3, 2, 1]);
    });

    test('hero is the best-fitting unqueued title with a seed link or strong taste', () {
      final s1 = _seed(1, score: 9.72), s2 = _seed(2, score: 9.10);
      final rows = _ranker.rank(
        _p([
          _c(1, inQueue: true, onMyServices: true, links: [SeedLink(seedId: s1.titleId, position: 1)]), // queued: skipped
          _c(2, genres: ['Comedy'], community: 9.9, communityCount: 9, onMyServices: true), // no link, taste 0
          _c(3,
              links: [SeedLink(seedId: s2.titleId, position: 1), SeedLink(seedId: s1.titleId, position: 2)],
              providers: ['mubi', 'max'],
              community: 9.0,
              communityCount: 9),
        ], seeds: [s1, s2], services: ['max']),
        _today,
      );
      final hero = rows.hero!;
      expect(hero.pick.titleId, 3);
      // s1 (9.72) at position 2 outweighs s2 (9.10) at position 1.
      expect([for (final s in hero.likeSeeds) s.title], ['Seed 1', 'Seed 2']);
      expect(hero.sharedGenres, isEmpty);
      expect(hero.provider, 'max'); // one of my services first
    });

    test('hero without seed links names the shared genres I rank highest', () {
      final profile = [
        const ProfileRanking(titleId: 9000, score: 9.5, genres: ['Thriller']),
        const ProfileRanking(titleId: 9001, score: 8.5, genres: ['Mystery']),
        const ProfileRanking(titleId: 9002, score: 7.5, genres: ['Romance']),
      ];
      final rows = _ranker.rank(
        _p([_c(1, genres: ['Romance', 'Mystery', 'Thriller'], providers: ['mubi'])], profile: profile),
        _today,
      );
      expect(rows.hero!.pick.titleId, 1);
      expect(rows.hero!.likeSeeds, isEmpty);
      expect(rows.hero!.sharedGenres, ['Thriller', 'Mystery']);
      expect(rows.hero!.provider, 'mubi');
    });

    test('no hero when nothing has a seed link or taste ≥ 0.50', () {
      final rows = _ranker.rank(_p([for (var i = 1; i <= 4; i++) _c(i, genres: ['Comedy'])]), _today);
      expect(rows.hero, isNull);
      expect(_ids(rows.row(ExploreRowKind.topPicks)), hasLength(4));
    });

    test('fill order: a title goes to the first row that claims it, and only there', () {
      final seed = _seed(1);
      link(int pos) => [SeedLink(seedId: seed.titleId, position: pos)];
      final rows = _ranker.rank(
        _p([
          _c(1, links: link(1), onMyServices: true, community: 9.5, communityCount: 9, trendingRank: 1), // hero
          _c(2, links: link(10), leavingUntil: _today.add(const Duration(days: 3))), // leaving beats because
          for (var i = 3; i <= 6; i++) _c(i, links: link(i)),
          _c(7, friends: const [CandidateFriend(userId: 'a', displayName: 'A', score: 9)]),
          for (var i = 8; i <= 11; i++) _c(i),
        ], seeds: [seed]),
        _today,
      );
      expect(rows.hero!.pick.titleId, 1);
      expect(_ids(rows.row(ExploreRowKind.leavingSoon)), [2]);
      expect(_ids(rows.row(ExploreRowKind.becauseYouRanked)), [3, 4, 5, 6]);
      expect(_ids(rows.row(ExploreRowKind.friends)), [7]);
      expect(_ids(rows.row(ExploreRowKind.topPicks)), [8, 9, 10, 11]);
      // Trending is exempt and may repeat the hero.
      expect(_ids(rows.row(ExploreRowKind.trending)), isEmpty); // only one trending title: below the minimum of 4

      final shown = [
        rows.hero!.pick.titleId,
        for (final r in rows.rows)
          if (r.kind != ExploreRowKind.trending) ..._ids(r),
      ];
      expect(shown.toSet().length, shown.length);
    });

    test('rows are listed in display order', () {
      final seed = _seed(1);
      final rows = _ranker.rank(
        _p([
          for (var i = 1; i <= 4; i++) _c(i, trendingRank: i, inQueue: true),
          for (var i = 10; i <= 14; i++) _c(i, links: [SeedLink(seedId: seed.titleId, position: i - 9)]),
          for (var i = 100; i <= 114; i++) _c(i), // fills Top picks' 15
          _c(30, friends: const [CandidateFriend(userId: 'a', displayName: 'A')]),
          _c(40, leavingUntil: _today),
          for (var i = 50; i <= 53; i++) _c(i, genres: ['Horror'], community: 9.5, communityCount: 9),
        ], rankings: 10, seeds: [seed]),
        _today,
      );
      expect([for (final r in rows.rows) r.kind], [
        ExploreRowKind.trending,
        ExploreRowKind.topPicks,
        ExploreRowKind.becauseYouRanked,
        ExploreRowKind.friends,
        ExploreRowKind.leavingSoon,
        ExploreRowKind.somethingDifferent,
      ]);
    });

    test('queued titles are left out everywhere except Leaving soon and Trending', () {
      final rows = _ranker.rank(
        _p([
          // Comedy against a Drama profile: no taste, no seed links, so there's no hero.
          _c(1, genres: ['Comedy'], inQueue: true, leavingUntil: _today.add(const Duration(days: 2)), trendingRank: 1),
          _c(2, genres: ['Comedy'], leavingUntil: _today.add(const Duration(days: 2))),
          _c(3, genres: ['Comedy'], inQueue: true, friends: const [CandidateFriend(userId: 'a', displayName: 'A', score: 9)]),
          for (var i = 4; i <= 6; i++) _c(i, genres: ['Comedy'], trendingRank: i),
          for (var i = 7; i <= 10; i++) _c(i, genres: ['Comedy'], inQueue: true),
        ]),
        _today,
      );
      expect(_ids(rows.row(ExploreRowKind.leavingSoon)), [1, 2]); // same day: queued first
      expect(_ids(rows.row(ExploreRowKind.trending)), [1, 4, 5, 6]);
      expect(rows.row(ExploreRowKind.friends), isNull);
      expect(rows.hero, isNull);
      expect(rows.row(ExploreRowKind.topPicks), isNull); // only 4, 5, 6 are left unqueued: below 4
    });

    test('Leaving soon keeps 0–7 days left, soonest first', () {
      final rows = _ranker.rank(
        _p([
          _c(1, leavingUntil: _today.add(const Duration(days: 7))),
          _c(2, leavingUntil: _today),
          _c(3, leavingUntil: _today.add(const Duration(days: 8))),
          _c(4, leavingUntil: _today.subtract(const Duration(days: 1))),
          _c(5, leavingUntil: _today.add(const Duration(days: 3))),
        ], rankings: 0),
        _today,
      );
      expect(_ids(rows.row(ExploreRowKind.leavingSoon)), [2, 5, 1]);
    });

    test('friends are ordered by count, then their mean score', () {
      const a = CandidateFriend(userId: 'a', displayName: 'A', score: 8.0);
      const b = CandidateFriend(userId: 'b', displayName: 'B', score: 9.0);
      const q = CandidateFriend(userId: 'q', displayName: 'Q');
      final rows = _ranker.rank(
        _p([
          _c(1, friends: const [a]),
          _c(2, friends: const [a, b]),
          _c(3, friends: const [b]),
          _c(4, friends: const [q]),
        ], rankings: 0),
        _today,
      );
      expect(_ids(rows.row(ExploreRowKind.friends)), [2, 3, 1, 4]);
    });

    test('Trending lists TMDB order, then Telly-only titles, up to 10', () {
      final rows = _ranker.rank(
        _p([
          for (var i = 1; i <= 8; i++) _c(i, trendingRank: 9 - i),
          _c(20, tellyRecent: 2),
          _c(21, tellyRecent: 7),
          _c(22, tellyRecent: 5),
        ], rankings: 0),
        _today,
      );
      expect(_ids(rows.row(ExploreRowKind.trending)), [8, 7, 6, 5, 4, 3, 2, 1, 21, 22]);
    });

    test('at most 2 per collection, and per director for movies only', () {
      final movies = _ranker.rank(
        _p([
          for (var i = 1; i <= 3; i++) _c(i, collectionId: 7, community: 9.9 - i / 10, communityCount: 9),
          for (var i = 4; i <= 6; i++) _c(i, director: 'Park', community: 9.0 - i / 10, communityCount: 9),
          for (var i = 7; i <= 8; i++) _c(i),
        ]),
        _today,
      );
      expect(movies.hero!.pick.titleId, 1); // the hero isn't a row, so it doesn't count toward a cap
      final picks = _ids(movies.row(ExploreRowKind.topPicks));
      expect(picks.where((id) => id <= 3), [2, 3]);
      expect(picks.where((id) => id >= 4 && id <= 6), hasLength(2));

      final tv = _ranker.rank(
        _p([for (var i = 1; i <= 5; i++) _c(i, mediaType: 'tv', director: 'Gilligan')], mediaType: 'tv'),
        _today,
      );
      expect(_ids(tv.row(ExploreRowKind.topPicks)), hasLength(4)); // 5 minus the hero, no director cap
    });

    test('Something different needs 10 rankings and names my usual genres', () {
      final candidates = [
        for (var i = 1; i <= 4; i++) _c(i, genres: ['Horror'], community: 9.0, communityCount: 9),
        _c(5, genres: ['Horror'], community: 7.0, communityCount: 9), // quality 0.33: not different
        for (var i = 100; i <= 115; i++) _c(i), // Drama: the hero and Top picks' 15 fill first
      ];
      final profile = [
        for (var i = 0; i < 6; i++) ProfileRanking(titleId: 9000 + i, score: 9.0, genres: const ['Drama']),
        for (var i = 6; i < 10; i++) ProfileRanking(titleId: 9000 + i, score: 9.0, genres: const ['Science Fiction']),
      ];
      final rows = _ranker.rank(_p(candidates, profile: profile), _today);
      final diff = rows.row(ExploreRowKind.somethingDifferent)!;
      expect(_ids(diff), [1, 2, 3, 4]);
      expect(diff.usualGenres, ['Drama', 'Science Fiction']);

      final nine = _ranker.rank(_p(candidates, profile: profile.take(9).toList()), _today);
      expect(nine.row(ExploreRowKind.somethingDifferent), isNull);
    });

    test('rows keep up to 30 for See all and show 15', () {
      final rows = _ranker.rank(_p([for (var i = 1; i <= 40; i++) _c(i)]), _today);
      final picks = rows.row(ExploreRowKind.topPicks)!;
      expect(picks.items, hasLength(30));
      expect(picks.visible, hasLength(15));
    });

    test('a movie payload never yields a series, and ranked titles never come back', () {
      final rows = _ranker.rank(
        _p([
          for (var i = 1; i <= 5; i++) _c(i, trendingRank: i),
          _c(100, mediaType: 'tv', trendingRank: 1),
          _c(9000, trendingRank: 1), // one of my rankings
        ]),
        _today,
      );
      final all = [rows.hero?.pick.titleId, for (final r in rows.rows) ...r.items.map((s) => s.titleId)];
      expect(all, isNot(contains(100)));
      expect(all, isNot(contains(9000)));
      expect(rows.rows.expand((r) => r.items).every((s) => s.candidate.mediaType == 'movie'), isTrue);
    });

    test('is deterministic: same payload and day, same rows, whatever the input order', () {
      final seed = _seed(1);
      final candidates = [
        for (var i = 1; i <= 25; i++)
          _c(i,
              links: i.isEven ? [SeedLink(seedId: seed.titleId, position: i % 20 + 1)] : const [],
              trendingRank: i <= 12 ? 13 - i : null,
              friends: i % 5 == 0 ? const [CandidateFriend(userId: 'a', displayName: 'A', score: 8.5)] : const []),
      ];
      List<List<int>> shape(ExploreRows r) => [
            [r.hero?.pick.titleId ?? -1],
            for (final row in r.rows) [row.kind.index, ...row.items.map((s) => s.titleId)],
          ];
      final a = _ranker.rank(_p(candidates, seeds: [seed]), _today);
      final b = _ranker.rank(_p(candidates.reversed.toList(), seeds: [seed]), _today);
      expect(shape(b), shape(a));
    });

    test('row ids are unique, carry a Because row\'s seed, and find their row (#181)', () {
      final s1 = _seed(1), s2 = _seed(2, score: 9.2);
      final candidates = [
        for (var i = 1; i <= 12; i++)
          _c(i,
              links: [SeedLink(seedId: (i.isEven ? s1 : s2).titleId, position: i)],
              trendingRank: i <= 5 ? i : null),
      ];
      final rows = _ranker.rank(_p(candidates, seeds: [s1, s2]), _today);
      final ids = [for (final r in rows.rows) r.id];
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, containsAll(['trending', 'becauseYouRanked-${s1.titleId}', 'becauseYouRanked-${s2.titleId}']));
      for (final r in rows.rows) {
        expect(rows.rowById(r.id), same(r));
      }
      expect(rows.rowById('becauseYouRanked-1'), isNull);
      expect(rows.rowById('friends'), isNull, reason: 'no friends row today');
    });
  });

  group('payload parsing', () {
    test('reads the §7.3 example', () {
      final p = ExploreCandidates.fromJson({
        'generated_at': '2026-10-07T18:00:00Z',
        'media_type': 'movie',
        'profile': {
          'rankings': [
            {'title_id': 496243, 'score': 9.72, 'rank': 2, 'genres': ['Comedy', 'Thriller', 'Drama']},
          ],
          'seeds': [
            {'title_id': 496243, 'title': 'Parasite', 'poster_path': '/p.jpg', 'score': 9.72, 'rank': 2},
          ],
          'services': ['netflix', 'max'],
          'missing_related': [157336],
        },
        'candidates': [
          {
            'title_id': 705996,
            'title': 'Decision to Leave',
            'release_year': 2022,
            'genres': ['Thriller', 'Romance', 'Mystery'],
            'director': 'Park Chan-wook',
            'community_score': 8.91,
            'community_count': 37,
            'tmdb_vote_average': 7.3,
            'tmdb_vote_count': 1840,
            'seed_links': [
              {'seed_id': 496243, 'position': 3},
            ],
            'trending_rank': null,
            'telly_recent_rankings': 4,
            'friends': [
              {'user_id': 'u1', 'display_name': 'Maya', 'avatar_url': null, 'score': 9.10, 'match_pct': 81},
            ],
            'providers': ['mubi'],
            'on_my_services': false,
            'leaving_until': '2026-10-10',
            'in_queue': true,
          },
        ],
      });
      expect(p.generatedAt, DateTime.utc(2026, 10, 7, 18));
      expect(p.profile.seeds.single.title, 'Parasite');
      expect(p.profile.services, ['netflix', 'max']);
      expect(p.profile.missingRelated, [157336]);
      expect(p.profile.rankings.single.genres, hasLength(3));
      final c = p.candidates.single;
      expect(c.mediaType, 'movie'); // filled from the payload
      expect(c.seedLinks.single.position, 3);
      expect(c.friends.single.matchPct, 81);
      expect(c.trendingRank, isNull);
      expect(c.leavingUntil, DateTime(2026, 10, 10));
      expect(c.inQueue, isTrue);
      expect(c.tmdbVoteCount, 1840);
    });

    test('tolerates an empty payload', () {
      final p = ExploreCandidates.fromJson(const {});
      expect(p.mediaType, 'movie');
      expect(p.candidates, isEmpty);
      expect(_ranker.rank(p, _today).rows, isEmpty);
    });
  });
}
