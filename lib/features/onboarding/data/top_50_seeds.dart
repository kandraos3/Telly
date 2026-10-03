class SeedTitle {
  final int id;
  final String title;
  final String mediaType; // 'movie' or 'tv'
  final bool isAnime;
  final String releaseYear;
  final String network;
  final String posterPath;
  final double score;

  const SeedTitle({
    required this.id,
    required this.title,
    required this.mediaType,
    this.isAnime = false,
    required this.releaseYear,
    required this.network,
    required this.posterPath,
    required this.score,
  });
}

const List<SeedTitle> kTop50SeedTitles = [
  // --- PRESTIGE TV ---
  SeedTitle(id: 76331, title: 'Succession', mediaType: 'tv', releaseYear: '2018', network: 'HBO', posterPath: '/7nRkdOEZ9P08sw37i67k91GjE9z.jpg', score: 9.68),
  SeedTitle(id: 110492, title: 'Severance', mediaType: 'tv', releaseYear: '2022', network: 'Apple TV+', posterPath: '/hlLXt2tOPT6RRnjiUmoxyG1LTFi.jpg', score: 9.55),
  SeedTitle(id: 1396, title: 'Breaking Bad', mediaType: 'tv', releaseYear: '2008', network: 'AMC', posterPath: '/ztkUQFLlC19CCMYHW9o1zWhJRNq.jpg', score: 9.75),
  SeedTitle(id: 124834, title: 'The Bear', mediaType: 'tv', releaseYear: '2022', network: 'FX / Hulu', posterPath: '/sH54jA2pfEuEsm8zeFf5kJ9O5d8.jpg', score: 9.38),
  SeedTitle(id: 1399, title: 'Game of Thrones', mediaType: 'tv', releaseYear: '2011', network: 'HBO', posterPath: '/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg', score: 9.10),
  SeedTitle(id: 87108, title: 'Chernobyl', mediaType: 'tv', releaseYear: '2019', network: 'HBO', posterPath: '/hlLXt2tOPT6RRnjiUmoxyG1LTFi.jpg', score: 9.62),
  SeedTitle(id: 8592, title: 'The Wire', mediaType: 'tv', releaseYear: '2002', network: 'HBO', posterPath: '/4lbclFySvugI51fwsyxBTOm4DqK.jpg', score: 9.80),
  SeedTitle(id: 1398, title: 'The Sopranos', mediaType: 'tv', releaseYear: '1999', network: 'HBO', posterPath: '/6KXw0UD5n3k6B8Y8M13j.jpg', score: 9.78),
  SeedTitle(id: 60059, title: 'Better Call Saul', mediaType: 'tv', releaseYear: '2015', network: 'AMC', posterPath: '/fC2HDm5t0kHVR79ywvtvj84oG92.jpg', score: 9.48),
  SeedTitle(id: 67070, title: 'Fleabag', mediaType: 'tv', releaseYear: '2016', network: 'BBC / Prime', posterPath: '/1qWc8WlQ6K0k5m7n9p1q3w5e7.jpg', score: 9.40),
  SeedTitle(id: 94605, title: 'Arcane', mediaType: 'tv', releaseYear: '2021', network: 'Netflix', posterPath: '/fqldfqKmGGF0uHpG92vW9Z.jpg', score: 9.50),
  SeedTitle(id: 93405, title: 'Squid Game', mediaType: 'tv', releaseYear: '2021', network: 'Netflix', posterPath: '/dDlGcaKk5k2n82T1t091.jpg', score: 8.70),
  SeedTitle(id: 66732, title: 'Stranger Things', mediaType: 'tv', releaseYear: '2016', network: 'Netflix', posterPath: '/49WJfeN0moxb9IPfGn8AIqMGskD.jpg', score: 8.85),
  SeedTitle(id: 114479, title: 'The White Lotus', mediaType: 'tv', releaseYear: '2021', network: 'HBO', posterPath: '/gH51Z8B12k0m3n5p7q9w1e3.jpg', score: 9.15),
  SeedTitle(id: 100088, title: 'The Last of Us', mediaType: 'tv', releaseYear: '2023', network: 'HBO', posterPath: '/uKvVjK1925bUF123g.jpg', score: 9.25),
  SeedTitle(id: 126308, title: 'Shogun', mediaType: 'tv', releaseYear: '2024', network: 'FX / Hulu', posterPath: '/7O4iVfOMQmdCSxhOg1WnzG1AgYT.jpg', score: 9.42),
  SeedTitle(id: 97546, title: 'Ted Lasso', mediaType: 'tv', releaseYear: '2020', network: 'Apple TV+', posterPath: '/5NutptAMqdy8op3l7k9m1.jpg', score: 9.05),
  SeedTitle(id: 46648, title: 'True Detective', mediaType: 'tv', releaseYear: '2014', network: 'HBO', posterPath: '/cuV2O5cfvB123k4m5n6.jpg', score: 9.20),
  SeedTitle(id: 70523, title: 'Dark', mediaType: 'tv', releaseYear: '2017', network: 'Netflix', posterPath: '/apbrbWs8M9lyOpJYU5WXrpFbk1Z.jpg', score: 9.35),
  SeedTitle(id: 82856, title: 'The Mandalorian', mediaType: 'tv', releaseYear: '2019', network: 'Disney+', posterPath: '/eU1i6eHXlzMOlEq0ku1R07YQ7Ma.jpg', score: 8.95),

  // --- ANIME CLASSICS ---
  SeedTitle(id: 1429, title: 'Attack on Titan', mediaType: 'tv', isAnime: true, releaseYear: '2013', network: 'Wit / MAPPA', posterPath: '/8C5gDxnQz8zR.jpg', score: 9.69),
  SeedTitle(id: 209867, title: "Frieren: Beyond Journey's End", mediaType: 'tv', isAnime: true, releaseYear: '2023', network: 'Madhouse', posterPath: '/dqZENchTd7lp5zhthtB.jpg', score: 9.74),
  SeedTitle(id: 95479, title: 'Jujutsu Kaisen', mediaType: 'tv', isAnime: true, releaseYear: '2020', network: 'MAPPA', posterPath: '/hCG7q9vL2n.jpg', score: 9.35),
  SeedTitle(id: 31911, title: 'Fullmetal Alchemist: Brotherhood', mediaType: 'tv', isAnime: true, releaseYear: '2009', network: 'Bones', posterPath: '/5ZFVO3mP8rK.jpg', score: 9.76),
  SeedTitle(id: 1535, title: 'Death Note', mediaType: 'tv', isAnime: true, releaseYear: '2006', network: 'Madhouse', posterPath: '/tC783m5K0h.jpg', score: 9.40),
  SeedTitle(id: 85937, title: 'Demon Slayer', mediaType: 'tv', isAnime: true, releaseYear: '2019', network: 'Ufotable', posterPath: '/nTvM4mhqN.jpg', score: 9.22),
  SeedTitle(id: 46298, title: 'Hunter x Hunter', mediaType: 'tv', isAnime: true, releaseYear: '2011', network: 'Madhouse', posterPath: '/ucMpKg2X9.jpg', score: 9.60),
  SeedTitle(id: 86031, title: 'Vinland Saga', mediaType: 'tv', isAnime: true, releaseYear: '2019', network: 'MAPPA', posterPath: '/dflsK89w2.jpg', score: 9.46),
  SeedTitle(id: 98605, title: 'Chainsaw Man', mediaType: 'tv', isAnime: true, releaseYear: '2022', network: 'MAPPA', posterPath: '/npdB6eFz4.jpg', score: 9.15),
  SeedTitle(id: 30984, title: 'Bleach', mediaType: 'tv', isAnime: true, releaseYear: '2004', network: 'Studio Pierrot', posterPath: '/2EewVh2n.jpg', score: 8.75),
  SeedTitle(id: 42009, title: 'Steins;Gate', mediaType: 'tv', isAnime: true, releaseYear: '2011', network: 'White Fox', posterPath: '/5xjK0M9k.jpg', score: 9.58),
  SeedTitle(id: 45, title: 'Neon Genesis Evangelion', mediaType: 'tv', isAnime: true, releaseYear: '1995', network: 'Gainax', posterPath: '/yQ01H49u9.jpg', score: 9.30),
  SeedTitle(id: 121, title: 'Cowboy Bebop', mediaType: 'tv', isAnime: true, releaseYear: '1998', network: 'Sunrise', posterPath: '/d05FfL1z.jpg', score: 9.45),
  SeedTitle(id: 65930, title: 'My Hero Academia', mediaType: 'tv', isAnime: true, releaseYear: '2016', network: 'Bones', posterPath: '/ivOLNs.jpg', score: 8.65),
  SeedTitle(id: 60625, title: 'Mob Psycho 100', mediaType: 'tv', isAnime: true, releaseYear: '2016', network: 'Bones', posterPath: '/e2d19f.jpg', score: 9.28),

  // --- TOP 15 MOVIES ---
  SeedTitle(id: 157336, title: 'Interstellar', mediaType: 'movie', releaseYear: '2014', network: 'Paramount', posterPath: '/gEU2QniE6EwfVDxCzsxPnTeft0b.jpg', score: 9.65),
  SeedTitle(id: 496243, title: 'Parasite', mediaType: 'movie', releaseYear: '2019', network: 'Neon', posterPath: '/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg', score: 9.72),
  SeedTitle(id: 129, title: 'Spirited Away', mediaType: 'movie', releaseYear: '2001', network: 'Studio Ghibli', posterPath: '/39wmItIWsg5sZMyRUHLkWBcuVCM.jpg', score: 9.80),
  SeedTitle(id: 238, title: 'The Godfather', mediaType: 'movie', releaseYear: '1972', network: 'Paramount', posterPath: '/3bhkrj58Vtu7enYsRolD1fZdja1.jpg', score: 9.85),
  SeedTitle(id: 680, title: 'Pulp Fiction', mediaType: 'movie', releaseYear: '1994', network: 'Miramax', posterPath: '/d5iIlFn5s0ImszYzBPb8JPIfbXD.jpg', score: 9.58),
  SeedTitle(id: 693134, title: 'Dune: Part Two', mediaType: 'movie', releaseYear: '2024', network: 'Warner Bros', posterPath: '/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg', score: 9.60),
  SeedTitle(id: 155, title: 'The Dark Knight', mediaType: 'movie', releaseYear: '2008', network: 'Warner Bros', posterPath: '/qJ2tW6WMUDux911r6m7haRef0WH.jpg', score: 9.90),
  SeedTitle(id: 569094, title: 'Spider-Man: Across the Spider-Verse', mediaType: 'movie', releaseYear: '2023', network: 'Sony Pictures', posterPath: '/8Vt6mWEReuy4Of61Lnj5Xj704m8.jpg', score: 9.68),
  SeedTitle(id: 872585, title: 'Oppenheimer', mediaType: 'movie', releaseYear: '2023', network: 'Universal', posterPath: '/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg', score: 9.45),
  SeedTitle(id: 278, title: 'The Shawshank Redemption', mediaType: 'movie', releaseYear: '1994', network: 'Columbia', posterPath: '/9cqNxx0GxF0bflZmeSMuL5tnGzr.jpg', score: 9.88),
  SeedTitle(id: 550, title: 'Fight Club', mediaType: 'movie', releaseYear: '1999', network: 'Fox 2000', posterPath: '/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg', score: 9.32),
  SeedTitle(id: 13, title: 'Forrest Gump', mediaType: 'movie', releaseYear: '1994', network: 'Paramount', posterPath: '/arw2vcBveWOVZr6pxd9XTd1TdQa.jpg', score: 9.20),
  SeedTitle(id: 424, title: "Schindler's List", mediaType: 'movie', releaseYear: '1993', network: 'Universal', posterPath: '/sF1U4EUQS8YHUYjNlvt0xTX3mFq.jpg', score: 9.78),
  SeedTitle(id: 19995, title: 'Avatar', mediaType: 'movie', releaseYear: '2009', network: '20th Century Fox', posterPath: '/kyeqWdyUXW608qlYkRqosgbbJyK.jpg', score: 8.85),
  SeedTitle(id: 27205, title: 'Inception', mediaType: 'movie', releaseYear: '2010', network: 'Warner Bros', posterPath: '/edv5CZvWj09upOsy2Y6IwDhK8bt.jpg', score: 9.55),
];
