/// Example `get_explore_candidates` payloads for [FakeDiscoveryRepository]: what tests,
/// previews and the screenshot site rank when no backend is there (#180). Titles and scores
/// are examples; leaving dates count from [now].
library;

Map<String, dynamic> _ranking(int id, double score, int rank, List<String> genres) =>
    {'title_id': id, 'score': score, 'rank': rank, 'genres': genres};

Map<String, dynamic> _seed(int id, String title, double score, int rank) =>
    {'title_id': id, 'title': title, 'poster_path': null, 'score': score, 'rank': rank};

Map<String, dynamic> _c(
  int id,
  String title,
  List<String> genres, {
  int? year,
  String? director,
  String? network,
  double? community,
  int communityCount = 12,
  List<(int, int)> links = const [],
  int? trending,
  List<Map<String, dynamic>> friends = const [],
  List<String> providers = const [],
  bool onMyServices = false,
  DateTime? leaving,
}) =>
    {
      'title_id': id,
      'title': title,
      'genres': genres,
      'release_year': year,
      'director': director,
      'original_network': network,
      'community_score': community,
      'community_count': community == null ? 0 : communityCount,
      'seed_links': [for (final (seed, pos) in links) {'seed_id': seed, 'position': pos}],
      'trending_rank': trending,
      'friends': friends,
      'providers': providers,
      'on_my_services': onMyServices,
      'leaving_until': leaving?.toIso8601String().substring(0, 10),
    };

Map<String, dynamic> _friend(String id, String name, double? score, int? match) =>
    {'user_id': id, 'display_name': name, 'avatar_url': null, 'score': score, 'match_pct': match};

Map<String, dynamic> sampleMoviePayload(DateTime now) => {
      'generated_at': now.toUtc().toIso8601String(),
      'media_type': 'movie',
      'profile': {
        'rankings': [
          _ranking(157336, 9.80, 1, ['Adventure', 'Drama', 'Science Fiction']),
          _ranking(496243, 9.72, 2, ['Comedy', 'Thriller', 'Drama']),
          _ranking(129, 9.45, 3, ['Animation', 'Family', 'Fantasy']),
          _ranking(238, 9.38, 4, ['Drama', 'Crime']),
          _ranking(155, 9.05, 5, ['Drama', 'Action', 'Crime']),
          _ranking(680, 8.90, 6, ['Thriller', 'Crime']),
          _ranking(27205, 8.80, 7, ['Action', 'Science Fiction']),
          _ranking(872585, 8.70, 8, ['Drama', 'History']),
          _ranking(278, 8.60, 9, ['Drama', 'Crime']),
          _ranking(550, 8.40, 10, ['Drama']),
        ],
        'seeds': [
          _seed(157336, 'Interstellar', 9.80, 1),
          _seed(496243, 'Parasite', 9.72, 2),
          _seed(129, 'Spirited Away', 9.45, 3),
          _seed(238, 'The Godfather', 9.38, 4),
          _seed(155, 'The Dark Knight', 9.05, 5),
        ],
        'services': ['netflix', 'max'],
        'missing_related': const [],
      },
      'candidates': [
        _c(705996, 'Decision to Leave', ['Thriller', 'Romance', 'Mystery'],
            year: 2022, director: 'Park Chan-wook', community: 8.91, links: [(496243, 1), (155, 9)], providers: ['mubi']),
        _c(1064213, 'Anora', ['Romance', 'Comedy', 'Drama'], year: 2024, trending: 1),
        _c(549509, 'The Brutalist', ['Drama', 'History'], year: 2024, trending: 2),
        _c(1233413, 'Sinners', ['Horror', 'Thriller'], year: 2025, trending: 3),
        _c(426063, 'Nosferatu', ['Horror', 'Fantasy'], year: 2024, trending: 4),
        for (final (i, (id, title)) in const [(686, 'Contact'), (17431, 'Moon'), (1272, 'Sunshine'), (419704, 'Ad Astra')].indexed)
          _c(id, title, ['Science Fiction', 'Drama'], year: 1997 + i * 7, links: [(157336, i + 1)]),
        for (final (i, (id, title)) in const [
          (11423, 'Memories of Murder'),
          (290098, 'The Handmaiden'),
          (491584, 'Burning'),
          (505192, 'Shoplifters'),
        ].indexed)
          _c(id, title, ['Crime', 'Thriller', 'Drama'], year: 2003 + i * 5, community: 8.6 + i / 20, links: [(496243, i + 2)]),
        _c(974576, 'Conclave', ['Drama', 'Thriller'], year: 2024, friends: [
          _friend('u-maya', 'Maya', 9.1, 81),
          _friend('u-jo', 'Jo', 8.4, 70),
          _friend('u-sam', 'Sam', null, null),
        ]),
        _c(937287, 'Challengers', ['Drama', 'Romance'], year: 2024, friends: [
          _friend('u-alex', 'Alex', 8.1, 64),
          _friend('u-jo', 'Jo', 8.0, 70),
        ]),
        _c(37799, 'The Social Network', ['Drama'],
            year: 2010, providers: ['netflix'], onMyServices: true, leaving: now.add(const Duration(days: 3))),
        _c(949, 'Heat', ['Action', 'Crime', 'Drama'],
            year: 1995, providers: ['max'], onMyServices: true, leaving: now.add(const Duration(days: 5))),
        for (final (id, title) in const [(146233, 'Prisoners'), (273481, 'Sicario'), (965150, 'Aftersun'), (758866, 'Drive My Car')])
          _c(id, title, ['Drama', 'Thriller', 'Crime'], year: 2013, community: 8.7),
        _c(346648, 'Paddington 2', ['Comedy', 'Family'], year: 2017, community: 8.9, communityCount: 20),
        _c(324857, 'Spider-Verse', ['Animation', 'Family'], year: 2018, community: 9.0, communityCount: 20),
        _c(1209290, 'Hundreds of Beavers', ['Comedy', 'Family'], year: 2022, community: 8.2, communityCount: 20),
        _c(10681, 'WALL·E', ['Animation', 'Family'], year: 2008, community: 8.8, communityCount: 20),
      ],
    };

Map<String, dynamic> sampleSeriesPayload(DateTime now) => {
      'generated_at': now.toUtc().toIso8601String(),
      'media_type': 'tv',
      'profile': {
        'rankings': [
          _ranking(1396, 9.80, 1, ['Drama', 'Crime']),
          _ranking(110492, 9.70, 2, ['Sci-Fi & Fantasy', 'Drama', 'Mystery']),
          _ranking(76331, 9.40, 3, ['Drama', 'Comedy']),
          _ranking(87108, 9.30, 4, ['Drama']),
        ],
        'seeds': [
          _seed(1396, 'Breaking Bad', 9.80, 1),
          _seed(110492, 'Severance', 9.70, 2),
          _seed(76331, 'Succession', 9.40, 3),
          _seed(87108, 'Chernobyl', 9.30, 4),
        ],
        'services': ['netflix', 'max'],
        'missing_related': const [],
      },
      'candidates': [
        _c(60059, 'Better Call Saul', ['Crime', 'Drama'],
            year: 2015, network: 'AMC', community: 9.48, links: [(1396, 1)], providers: ['netflix'], onMyServices: true),
        _c(126308, 'Shōgun', ['Drama', 'War & Politics'], year: 2024, network: 'FX', trending: 1, friends: [
          _friend('u-jordan', 'Jordan', 9.3, 77),
          _friend('u-maya', 'Maya', 9.1, 81),
        ]),
        _c(136315, 'The Bear', ['Comedy', 'Drama'], year: 2022, network: 'FX', trending: 2),
        _c(83867, 'Andor', ['Sci-Fi & Fantasy', 'Drama'], year: 2022, network: 'Disney+', trending: 3),
        _c(100088, 'The Last of Us', ['Drama'], year: 2023, network: 'HBO', trending: 4),
        for (final (i, (id, title)) in const [(70523, 'Dark'), (86831, 'Pachinko'), (63247, 'Westworld'), (95396, 'Silo')].indexed)
          _c(id, title, ['Sci-Fi & Fantasy', 'Drama', 'Mystery'], year: 2017 + i, links: [(110492, i + 1)]),
        _c(1398, 'The Sopranos', ['Crime', 'Drama'],
            year: 1999, network: 'HBO', providers: ['max'], onMyServices: true, leaving: now.add(const Duration(days: 4))),
        for (final (id, title) in const [(46648, 'True Detective'), (67070, 'Fleabag'), (97546, 'Ted Lasso'), (1408, 'House')])
          _c(id, title, ['Drama', 'Mystery'], year: 2014, community: 9.0),
      ],
    };
