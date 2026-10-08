import 'dart:math' as math;

import 'explore_candidates.dart';

/// Every tunable of the Explore ranking (#46). Values and formulas:
/// `docs/features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md` §7.4.
abstract final class ExploreWeights {
  static const taste = 0.40;
  static const seeds = 0.20;
  static const friends = 0.15;
  static const quality = 0.15;
  static const services = 0.10;

  /// `matchPct = round(100 · fit / matchScale)`, clamped to 1–99.
  static const matchScale = 0.85;

  /// Rankings below this score add nothing to the genre profile (Mid and below).
  static const profileFloor = 5.50;

  /// Seeds are titles scored at least this (Great tier and up).
  static const seedFloor = 7.80;

  /// TMDB returns 20 recommendations per seed; position 1 counts fully, 20 counts 1/20.
  static const relatedDepth = 20;

  /// Bayesian prior for TMDB ratings: [priorVotes] votes at [priorMean].
  static const priorVotes = 500;
  static const priorMean = 6.8;

  /// Telly's own community score is trusted from this many rankings.
  static const minCommunityCount = 5;

  /// Something different: low genre overlap, high quality.
  static const differentMaxTaste = 0.25;
  static const differentMinQuality = 0.60;
  static const differentQuality = 0.60;
  static const differentFriends = 0.25;
  static const differentServices = 0.15;

  /// The hero needs a seed link or at least this taste.
  static const heroMinTaste = 0.50;

  static const minRankingsForPicks = 3;
  static const minRankingsForDifferent = 10;
  static const maxBecauseRows = 3;
  static const leavingWindowDays = 7;

  /// Carousel length; See all shows up to [seeAllItems].
  static const rowItems = 15;
  static const seeAllItems = 30;
  static const trendingItems = 10;

  /// Rows with fewer items hide (Friends and Leaving soon need only one).
  static const minRowItems = 4;

  /// At most this many titles per collection, and per director (movies), in one row.
  static const maxPerGroup = 2;
}

enum ExploreRowKind { trending, topPicks, topRated, becauseYouRanked, friends, leavingSoon, somethingDifferent }

/// A candidate with its score parts (each in `[0, 1]`).
class ScoredCandidate {
  final ExploreCandidate candidate;
  final double taste;
  final double seeds;
  final double friends;
  final double quality;
  final double services;

  const ScoredCandidate({
    required this.candidate,
    required this.taste,
    required this.seeds,
    required this.friends,
    required this.quality,
    required this.services,
  });

  double get fit =>
      ExploreWeights.taste * taste +
      ExploreWeights.seeds * seeds +
      ExploreWeights.friends * friends +
      ExploreWeights.quality * quality +
      ExploreWeights.services * services;

  /// Shown as "94% match".
  int get matchPct => ExploreRanker.matchPct(fit);

  bool get isDifferent => taste < ExploreWeights.differentMaxTaste && quality >= ExploreWeights.differentMinQuality;

  double get different =>
      ExploreWeights.differentQuality * quality +
      ExploreWeights.differentFriends * friends +
      ExploreWeights.differentServices * services;

  int get titleId => candidate.titleId;
}

class ExploreRow {
  final ExploreRowKind kind;

  /// Up to [ExploreWeights.seeAllItems]; the carousel shows the first [ExploreWeights.rowItems].
  final List<ScoredCandidate> items;

  /// The title a Because-you-ranked row is built from.
  final ExploreSeed? seed;

  /// Something different: my two biggest genres ("Outside your usual …").
  final List<String> usualGenres;

  const ExploreRow({required this.kind, required this.items, this.seed, this.usualGenres = const []});

  List<ScoredCandidate> get visible => items.take(ExploreWeights.rowItems).toList();

  /// The `:rowId` of its See all route (#181): the kind's name, plus the seed id for a
  /// Because row (`becauseYouRanked-496243`), since a canon can have several.
  String get id => seed == null ? kind.name : '${kind.name}-${seed!.titleId}';
}

class ExploreHero {
  final ScoredCandidate pick;

  /// Up to two seeds it is most like, strongest first ("Like Parasite (9.72) and …").
  final List<ExploreSeed> likeSeeds;

  /// When [likeSeeds] is empty: up to two shared genres I rank highest ("Fits your love of …").
  final List<String> sharedGenres;

  /// Where to watch it, preferring one of my services.
  final String? provider;

  const ExploreHero({required this.pick, this.likeSeeds = const [], this.sharedGenres = const [], this.provider});
}

class ExploreRows {
  final String mediaType;
  final int rankingCount;
  final ExploreHero? hero;

  /// In display order (features/07 §7.2): Trending, Top picks or Top rated, Because rows,
  /// Friends, Leaving soon, Something different. Rows below their minimum are left out.
  final List<ExploreRow> rows;

  /// My top seeds (score ≥ 7.80), best first, to explain a pick ("Because you loved X").
  final List<ExploreSeed> seeds;

  const ExploreRows({
    required this.mediaType,
    required this.rankingCount,
    this.hero,
    this.rows = const [],
    this.seeds = const [],
  });

  /// Fewer than 3 rankings: the hero and personal rows give way to the "Rank 3" prompt.
  bool get isNewUser => rankingCount < ExploreWeights.minRankingsForPicks;

  /// The seed [pick] is most like (its strongest seed link), or null.
  ExploreSeed? strongestSeed(ScoredCandidate pick) {
    ExploreSeed? best;
    var bestW = 0.0;
    for (final link in pick.candidate.seedLinks) {
      for (final seed in seeds) {
        if (seed.titleId != link.seedId) continue;
        final w = ExploreRanker.linkContribution(seed, link);
        if (w > bestW) (best, bestW) = (seed, w);
      }
    }
    return best;
  }

  /// The row whose [ExploreRow.id] is [id], or null when today's rows don't have it.
  ExploreRow? rowById(String id) {
    for (final r in rows) {
      if (r.id == id) return r;
    }
    return null;
  }

  ExploreRow? row(ExploreRowKind kind) {
    for (final r in rows) {
      if (r.kind == kind) return r;
    }
    return null;
  }
}

/// Turns a `get_explore_candidates` payload into Explore's hero and rows. Pure and
/// deterministic: the same payload and [today] always give the same result.
class ExploreRanker {
  const ExploreRanker();

  static double _clamp01(double v) => v.isNaN ? 0 : v.clamp(0.0, 1.0).toDouble();

  static int matchPct(double fit) => (100 * fit / ExploreWeights.matchScale).round().clamp(1, 99);

  /// My genre profile: each ranking adds `max(score − 5.50, 0)` split evenly across its
  /// genres, normalised to unit length. Empty when nothing scores above the floor.
  static Map<String, double> genreProfile(List<ProfileRanking> rankings) {
    final g = <String, double>{};
    for (final r in rankings) {
      final genres = r.genres.toSet();
      final w = math.max(r.score - ExploreWeights.profileFloor, 0.0);
      if (genres.isEmpty || w == 0) continue;
      for (final genre in genres) {
        g[genre] = (g[genre] ?? 0) + w / genres.length;
      }
    }
    final norm = math.sqrt(g.values.fold(0.0, (s, v) => s + v * v));
    if (norm == 0) return const {};
    return {for (final e in g.entries) e.key: e.value / norm};
  }

  /// Cosine of [profile] (unit length) and the title's genres (`1/√k` each).
  static double taste(Map<String, double> profile, List<String> genres) {
    final set = genres.toSet();
    if (profile.isEmpty || set.isEmpty) return 0;
    final dot = set.fold(0.0, (s, g) => s + (profile[g] ?? 0));
    return _clamp01(dot / math.sqrt(set.length));
  }

  static double seedWeight(double score) => (score - ExploreWeights.seedFloor + 0.20) / 2.40;

  /// One link's contribution: the seed's weight, discounted by TMDB position.
  static double linkContribution(ExploreSeed seed, SeedLink link) {
    final pos = link.position.clamp(1, ExploreWeights.relatedDepth);
    return seedWeight(seed.score) * (1 - (pos - 1) / ExploreWeights.relatedDepth);
  }

  static double seeds(List<SeedLink> links, Map<int, ExploreSeed> seedsById) {
    var sum = 0.0;
    for (final l in links) {
      final seed = seedsById[l.seedId];
      if (seed != null) sum += linkContribution(seed, l);
    }
    return _clamp01(sum);
  }

  /// Noisy-or over friends: each counts `taste match × how much they liked it`.
  static double friends(List<CandidateFriend> friends) {
    var miss = 1.0;
    for (final f in friends) {
      final m = f.matchPct == null ? 0.5 : f.matchPct! / 100;
      final q = f.score == null ? 0.5 : _clamp01((f.score! - ExploreWeights.profileFloor) / 4.5);
      miss *= 1 - _clamp01(m * q);
    }
    return _clamp01(1 - miss);
  }

  static double quality(ExploreCandidate c) {
    final double q;
    if (c.communityScore != null && c.communityCount >= ExploreWeights.minCommunityCount) {
      q = c.communityScore!;
    } else if (c.tmdbVoteAverage != null && c.tmdbVoteCount != null) {
      final n = c.tmdbVoteCount!;
      q = (n * c.tmdbVoteAverage! + ExploreWeights.priorVotes * ExploreWeights.priorMean) /
          (n + ExploreWeights.priorVotes);
    } else {
      return 0.5;
    }
    return _clamp01((q - ExploreWeights.profileFloor) / 4.5);
  }

  static ScoredCandidate score(ExploreCandidate c, Map<String, double> profile, Map<int, ExploreSeed> seedsById) =>
      ScoredCandidate(
        candidate: c,
        taste: taste(profile, c.genres),
        seeds: seeds(c.seedLinks, seedsById),
        friends: friends(c.friends),
        quality: quality(c),
        services: c.onMyServices ? 1 : 0,
      );

  static int daysSinceEpoch(DateTime day) =>
      DateTime.utc(day.year, day.month, day.day).difference(DateTime.utc(1970)).inDays;

  /// Today's Because-you-ranked seeds, in rotation order: sorted by rank, starting at
  /// `daysSinceEpoch(today) mod n` and wrapping. Callers take rows from this until they have 3.
  static List<ExploreSeed> seedRotation(List<ExploreSeed> seeds, DateTime today) {
    final sorted = [...seeds]..sort((a, b) => a.rank != b.rank ? a.rank.compareTo(b.rank) : a.titleId.compareTo(b.titleId));
    if (sorted.isEmpty) return const [];
    final start = daysSinceEpoch(today) % sorted.length;
    return [for (var i = 0; i < sorted.length; i++) sorted[(start + i) % sorted.length]];
  }

  static int _byFit(ScoredCandidate a, ScoredCandidate b) {
    final c = b.fit.compareTo(a.fit);
    return c != 0 ? c : a.titleId.compareTo(b.titleId);
  }

  /// Takes [sorted] in order, skipping [used] titles and any past 2 per collection or
  /// (movies) per director.
  static List<ScoredCandidate> _take(Iterable<ScoredCandidate> sorted, Set<int> used, int limit) {
    final out = <ScoredCandidate>[];
    final collections = <int, int>{};
    final directors = <String, int>{};
    for (final s in sorted) {
      if (out.length == limit) break;
      final c = s.candidate;
      if (used.contains(c.titleId)) continue;
      final col = c.collectionId;
      if (col != null && (collections[col] ?? 0) >= ExploreWeights.maxPerGroup) continue;
      final dir = c.mediaType == 'movie' ? c.director : null;
      if (dir != null && (directors[dir] ?? 0) >= ExploreWeights.maxPerGroup) continue;
      if (col != null) collections[col] = (collections[col] ?? 0) + 1;
      if (dir != null) directors[dir] = (directors[dir] ?? 0) + 1;
      out.add(s);
    }
    return out;
  }

  ExploreRows rank(ExploreCandidates payload, DateTime today) {
    final mediaType = payload.mediaType;
    final profile = payload.profile;
    final g = genreProfile(profile.rankings);
    final seeds = [for (final s in profile.seeds) if (s.score >= ExploreWeights.seedFloor) s];
    final seedsById = {for (final s in seeds) s.titleId: s};
    final ranked = {for (final r in profile.rankings) r.titleId};
    final rankingCount = profile.rankings.length;
    final isNewUser = rankingCount < ExploreWeights.minRankingsForPicks;

    // Dual canon: only this payload's media type, and never a title I've ranked.
    final seen = <int>{};
    final all = <ScoredCandidate>[
      for (final c in payload.candidates)
        if (c.mediaType == mediaType && !ranked.contains(c.titleId) && seen.add(c.titleId)) score(c, g, seedsById),
    ]..sort(_byFit);
    final unqueued = [for (final s in all) if (!s.candidate.inQueue) s];

    // Fill order: hero → Leaving soon → Because rows → Friends → Top picks → Something different.
    // A title shown in one carousel isn't shown in another; Trending is exempt.
    final used = <int>{};
    void claim(ExploreRow row) => used.addAll(row.visible.map((s) => s.titleId));

    ExploreHero? hero;
    if (!isNewUser) {
      for (final s in unqueued) {
        if (s.candidate.seedLinks.any((l) => seedsById.containsKey(l.seedId)) || s.taste >= ExploreWeights.heroMinTaste) {
          hero = _hero(s, g, seedsById, profile.services);
          used.add(s.titleId);
          break;
        }
      }
    }

    final todayDate = DateTime.utc(today.year, today.month, today.day);
    int? daysLeft(ExploreCandidate c) {
      final u = c.leavingUntil;
      if (u == null) return null;
      final d = DateTime.utc(u.year, u.month, u.day).difference(todayDate).inDays;
      return d >= 0 && d <= ExploreWeights.leavingWindowDays ? d : null;
    }

    final leavingSorted = [for (final s in all) if (daysLeft(s.candidate) != null) s]..sort((a, b) {
        final d = daysLeft(a.candidate)!.compareTo(daysLeft(b.candidate)!);
        if (d != 0) return d;
        if (a.candidate.inQueue != b.candidate.inQueue) return a.candidate.inQueue ? -1 : 1;
        return _byFit(a, b);
      });
    final leaving = ExploreRow(kind: ExploreRowKind.leavingSoon, items: _take(leavingSorted, used, ExploreWeights.seeAllItems));
    claim(leaving);

    final because = <ExploreRow>[];
    if (!isNewUser) {
      for (final seed in seedRotation(seeds, today)) {
        if (because.length == ExploreWeights.maxBecauseRows) break;
        final linked = unqueued.where((s) => s.candidate.seedLinks.any((l) => l.seedId == seed.titleId));
        final items = _take(linked, used, ExploreWeights.seeAllItems);
        if (items.length < ExploreWeights.minRowItems) continue;
        final row = ExploreRow(kind: ExploreRowKind.becauseYouRanked, items: items, seed: seed);
        because.add(row);
        claim(row);
      }
    }

    double? friendsMean(ExploreCandidate c) {
      final scores = [for (final f in c.friends) if (f.score != null) f.score!];
      return scores.isEmpty ? null : scores.reduce((a, b) => a + b) / scores.length;
    }

    final friendsSorted = [for (final s in unqueued) if (s.candidate.friends.isNotEmpty) s]..sort((a, b) {
        final n = b.candidate.friends.length.compareTo(a.candidate.friends.length);
        if (n != 0) return n;
        final ma = friendsMean(a.candidate) ?? -1, mb = friendsMean(b.candidate) ?? -1;
        if (ma != mb) return mb.compareTo(ma);
        return _byFit(a, b);
      });
    final friendsRow = ExploreRow(kind: ExploreRowKind.friends, items: _take(friendsSorted, used, ExploreWeights.seeAllItems));
    claim(friendsRow);

    final ExploreRow picks;
    if (isNewUser) {
      final byQuality = [...unqueued]..sort((a, b) {
          final q = b.quality.compareTo(a.quality);
          return q != 0 ? q : a.titleId.compareTo(b.titleId);
        });
      picks = ExploreRow(kind: ExploreRowKind.topRated, items: _take(byQuality, used, ExploreWeights.seeAllItems));
    } else {
      picks = ExploreRow(kind: ExploreRowKind.topPicks, items: _take(unqueued, used, ExploreWeights.seeAllItems));
    }
    claim(picks);

    ExploreRow? different;
    if (rankingCount >= ExploreWeights.minRankingsForDifferent) {
      final eligible = [for (final s in unqueued) if (s.isDifferent) s]..sort((a, b) {
          final d = b.different.compareTo(a.different);
          return d != 0 ? d : a.titleId.compareTo(b.titleId);
        });
      final usual = (g.entries.toList()..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key)))
          .take(2)
          .map((e) => e.key)
          .toList();
      different = ExploreRow(
        kind: ExploreRowKind.somethingDifferent,
        items: _take(eligible, used, ExploreWeights.seeAllItems),
        usualGenres: usual,
      );
      claim(different);
    }

    // Trending: TMDB order, then Telly-only titles by recent rankings. Queued titles stay.
    final tmdb = [for (final s in all) if (s.candidate.trendingRank != null) s]
      ..sort((a, b) {
        final r = a.candidate.trendingRank!.compareTo(b.candidate.trendingRank!);
        return r != 0 ? r : a.titleId.compareTo(b.titleId);
      });
    final telly = [for (final s in all) if (s.candidate.trendingRank == null && s.candidate.tellyRecentRankings > 0) s]
      ..sort((a, b) {
        final r = b.candidate.tellyRecentRankings.compareTo(a.candidate.tellyRecentRankings);
        return r != 0 ? r : a.titleId.compareTo(b.titleId);
      });
    final trending = ExploreRow(kind: ExploreRowKind.trending, items: [...tmdb, ...telly].take(ExploreWeights.trendingItems).toList());

    bool shows(ExploreRow? r, int min) => r != null && r.items.length >= min;
    return ExploreRows(
      mediaType: mediaType,
      rankingCount: rankingCount,
      hero: hero,
      seeds: seeds,
      rows: [
        if (shows(trending, ExploreWeights.minRowItems)) trending,
        if (shows(picks, ExploreWeights.minRowItems)) picks,
        ...because,
        if (shows(friendsRow, 1)) friendsRow,
        if (shows(leaving, 1)) leaving,
        if (shows(different, ExploreWeights.minRowItems)) different!,
      ],
    );
  }

  static ExploreHero _hero(
    ScoredCandidate s,
    Map<String, double> g,
    Map<int, ExploreSeed> seedsById,
    List<String> services,
  ) {
    final links = [
      for (final l in s.candidate.seedLinks)
        if (seedsById[l.seedId] != null) (seed: seedsById[l.seedId]!, w: linkContribution(seedsById[l.seedId]!, l)),
    ]..sort((a, b) => b.w != a.w ? b.w.compareTo(a.w) : a.seed.rank.compareTo(b.seed.rank));
    final likeSeeds = <ExploreSeed>[];
    for (final l in links) {
      if (likeSeeds.length == 2) break;
      if (!likeSeeds.any((x) => x.titleId == l.seed.titleId)) likeSeeds.add(l.seed);
    }
    final shared = likeSeeds.isNotEmpty
        ? const <String>[]
        : ([for (final genre in s.candidate.genres.toSet()) if ((g[genre] ?? 0) > 0) genre]
              ..sort((a, b) => g[b]! != g[a]! ? g[b]!.compareTo(g[a]!) : a.compareTo(b)))
            .take(2)
            .toList();
    final providers = s.candidate.providers;
    final provider = providers.firstWhere(services.contains, orElse: () => providers.isEmpty ? '' : providers.first);
    return ExploreHero(pick: s, likeSeeds: likeSeeds, sharedGenres: shared, provider: provider.isEmpty ? null : provider);
  }
}
