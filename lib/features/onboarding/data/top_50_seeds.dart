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
  SeedTitle(id: 76331, title: 'Succession', mediaType: 'tv', releaseYear: '2018', network: 'HBO', posterPath: '/z0XiwdrCQ9yVIr4O0pxzaAYRxdW.jpg', score: 9.68),
  SeedTitle(id: 110492, title: 'Severance', mediaType: 'tv', releaseYear: '2022', network: 'Apple TV+', posterPath: '/yb4F1Oocq8GfQt6iIuAgYEBokhG.jpg', score: 9.55),
  SeedTitle(id: 1396, title: 'Breaking Bad', mediaType: 'tv', releaseYear: '2008', network: 'AMC', posterPath: '/anFx9aTOOYqgS3v7x3R84Kz67ly.jpg', score: 9.75),
  SeedTitle(id: 124834, title: 'The Bear', mediaType: 'tv', releaseYear: '2022', network: 'FX / Hulu', posterPath: '/dQc0QbDiHjGmWxTfKtBgYtS4bj5.jpg', score: 9.38),
  SeedTitle(id: 1399, title: 'Game of Thrones', mediaType: 'tv', releaseYear: '2011', network: 'HBO', posterPath: '/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg', score: 9.1),
  SeedTitle(id: 87108, title: 'Chernobyl', mediaType: 'tv', releaseYear: '2019', network: 'HBO', posterPath: '/hlLXt2tOPT6RRnjiUmoxyG1LTFi.jpg', score: 9.62),
  SeedTitle(id: 8592, title: 'The Wire', mediaType: 'tv', releaseYear: '2002', network: 'HBO', posterPath: '/5IOj62y2Eb2ngyYmEn1IJ7bFhzH.jpg', score: 9.8),
  SeedTitle(id: 1398, title: 'The Sopranos', mediaType: 'tv', releaseYear: '1999', network: 'HBO', posterPath: '/rTc7ZXdroqjkKivFPvCPX0Ru7uw.jpg', score: 9.78),
  SeedTitle(id: 60059, title: 'Better Call Saul', mediaType: 'tv', releaseYear: '2015', network: 'AMC', posterPath: '/fC2HDm5t0kHl7mTm7jxMR31b7by.jpg', score: 9.48),
  SeedTitle(id: 67070, title: 'Fleabag', mediaType: 'tv', releaseYear: '2016', network: 'BBC / Prime', posterPath: '/vFn0nLPcIggPH5LTWWaJ2hcsGlc.jpg', score: 9.4),
  SeedTitle(id: 94605, title: 'Arcane', mediaType: 'tv', releaseYear: '2021', network: 'Netflix', posterPath: '/fqldf2t8ztc9aiwn3k6mlX3tvRT.jpg', score: 9.5),
  SeedTitle(id: 93405, title: 'Squid Game', mediaType: 'tv', releaseYear: '2021', network: 'Netflix', posterPath: '/1QdXdRYfktUSONkl1oD5gc6Be0s.jpg', score: 8.7),
  SeedTitle(id: 66732, title: 'Stranger Things', mediaType: 'tv', releaseYear: '2016', network: 'Netflix', posterPath: '/uOOtwVbSr4QDjAGIifLDwpb2Pdl.jpg', score: 8.85),
  SeedTitle(id: 114479, title: 'The White Lotus', mediaType: 'tv', releaseYear: '2021', network: 'HBO', posterPath: '/mztdt3y6GBsJR69zHtszFezTCLT.jpg', score: 9.15),
  SeedTitle(id: 100088, title: 'The Last of Us', mediaType: 'tv', releaseYear: '2023', network: 'HBO', posterPath: '/dmo6TYuuJgaYinXBPjrgG9mB5od.jpg', score: 9.25),
  SeedTitle(id: 126308, title: 'Shogun', mediaType: 'tv', releaseYear: '2024', network: 'FX / Hulu', posterPath: '/7O4iVfOMQmdCSxhOg1WnzG1AgYT.jpg', score: 9.42),
  SeedTitle(id: 97546, title: 'Ted Lasso', mediaType: 'tv', releaseYear: '2020', network: 'Apple TV+', posterPath: '/uRHsiw1wLxPHFXkkv4Ix1s0O6f4.jpg', score: 9.05),
  SeedTitle(id: 46648, title: 'True Detective', mediaType: 'tv', releaseYear: '2014', network: 'HBO', posterPath: '/zYqVTiHK5ZajYcNzAW7qWte5NWS.jpg', score: 9.2),
  SeedTitle(id: 70523, title: 'Dark', mediaType: 'tv', releaseYear: '2017', network: 'Netflix', posterPath: '/apbrbWs8M9lyOpJYU5WXrpFbk1Z.jpg', score: 9.35),
  SeedTitle(id: 82856, title: 'The Mandalorian', mediaType: 'tv', releaseYear: '2019', network: 'Disney+', posterPath: '/sWgBv7LV2PRoQgkxwlibdGXKz1S.jpg', score: 8.95),
  SeedTitle(id: 1429, title: 'Attack on Titan', mediaType: 'tv', isAnime: true, releaseYear: '2013', network: 'Wit / MAPPA', posterPath: '/hTP1DtLGFamjfu8WqjnuQdP1n4i.jpg', score: 9.69),
  SeedTitle(id: 209867, title: 'Frieren: Beyond Journey\'s End', mediaType: 'tv', isAnime: true, releaseYear: '2023', network: 'Madhouse', posterPath: '/dqZENchTd7lp5zht7BdlqM7RBhD.jpg', score: 9.74),
  SeedTitle(id: 95479, title: 'Jujutsu Kaisen', mediaType: 'tv', isAnime: true, releaseYear: '2020', network: 'MAPPA', posterPath: '/6qQzMJG27XOJsyAEEIisoJB45j2.jpg', score: 9.35),
  SeedTitle(id: 31911, title: 'Fullmetal Alchemist: Brotherhood', mediaType: 'tv', isAnime: true, releaseYear: '2009', network: 'Bones', posterPath: '/5ZFUEOULaVml7pQuXxhpR2SmVUw.jpg', score: 9.76),
  SeedTitle(id: 13916, title: 'Death Note', mediaType: 'tv', isAnime: true, releaseYear: '2006', network: 'Madhouse', posterPath: '/tCZFfYTIwrR7n94J6G14Y4hAFU6.jpg', score: 9.4),
  SeedTitle(id: 85937, title: 'Demon Slayer', mediaType: 'tv', isAnime: true, releaseYear: '2019', network: 'Ufotable', posterPath: '/xUfRZu2mi8jH6SzQEJGP6tjBuYj.jpg', score: 9.22),
  SeedTitle(id: 46298, title: 'Hunter x Hunter', mediaType: 'tv', isAnime: true, releaseYear: '2011', network: 'Madhouse', posterPath: '/i2EEr2uBvRlAwJ8d8zTG2Y19mIa.jpg', score: 9.6),
  SeedTitle(id: 86031, title: 'Vinland Saga', mediaType: 'tv', isAnime: true, releaseYear: '2019', network: 'MAPPA', posterPath: '/xbZQ3fDl0y5mt0ARwfeyrgQ4JTw.jpg', score: 9.46),
  SeedTitle(id: 98605, title: 'Chainsaw Man', mediaType: 'tv', isAnime: true, releaseYear: '2022', network: 'MAPPA', posterPath: '/iT0Pc9iJPL2ywIfs81qthQAjSSx.jpg', score: 9.15),
  SeedTitle(id: 30984, title: 'Bleach', mediaType: 'tv', isAnime: true, releaseYear: '2004', network: 'Studio Pierrot', posterPath: '/2EewmxXe72ogD0EaWM8gqa0ccIw.jpg', score: 8.75),
  SeedTitle(id: 42009, title: 'Steins;Gate', mediaType: 'tv', isAnime: true, releaseYear: '2011', network: 'White Fox', posterPath: '/seN6rRfN0I6n8iDXjlSMk1QjNcq.jpg', score: 9.58),
  SeedTitle(id: 45, title: 'Neon Genesis Evangelion', mediaType: 'tv', isAnime: true, releaseYear: '1995', network: 'Gainax', posterPath: '/aqM6QnuhSXzjHlKbXyKUqxaGiWu.jpg', score: 9.3),
  SeedTitle(id: 121, title: 'Cowboy Bebop', mediaType: 'tv', isAnime: true, releaseYear: '1998', network: 'Sunrise', posterPath: '/xinqAmYrZ1TEwowcQhgTkZVtVE0.jpg', score: 9.45),
  SeedTitle(id: 65930, title: 'My Hero Academia', mediaType: 'tv', isAnime: true, releaseYear: '2016', network: 'Bones', posterPath: '/phuYuzqWW9ru8EA3HVjE9W2Rr3M.jpg', score: 8.65),
  SeedTitle(id: 60625, title: 'Mob Psycho 100', mediaType: 'tv', isAnime: true, releaseYear: '2016', network: 'Bones', posterPath: '/owhkU6KRqdXoUQpjV8uyZGPtX58.jpg', score: 9.28),
  SeedTitle(id: 157336, title: 'Interstellar', mediaType: 'movie', releaseYear: '2014', network: 'Paramount', posterPath: '/yQvGrMoipbRoddT0ZR8tPoR7NfX.jpg', score: 9.65),
  SeedTitle(id: 496243, title: 'Parasite', mediaType: 'movie', releaseYear: '2019', network: 'Neon', posterPath: '/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg', score: 9.72),
  SeedTitle(id: 129, title: 'Spirited Away', mediaType: 'movie', releaseYear: '2001', network: 'Studio Ghibli', posterPath: '/jUo8cNmU400WtZiJss45HNXlQ2e.jpg', score: 9.8),
  SeedTitle(id: 238, title: 'The Godfather', mediaType: 'movie', releaseYear: '1972', network: 'Paramount', posterPath: '/3bhkrj58Vtu7enYsRolD1fZdja1.jpg', score: 9.85),
  SeedTitle(id: 680, title: 'Pulp Fiction', mediaType: 'movie', releaseYear: '1994', network: 'Miramax', posterPath: '/vQWk5YBFWF4bZaofAbv0tShwBvQ.jpg', score: 9.58),
  SeedTitle(id: 693134, title: 'Dune: Part Two', mediaType: 'movie', releaseYear: '2024', network: 'Warner Bros', posterPath: '/6izwz7rsy95ARzTR3poZ8H6c5pp.jpg', score: 9.6),
  SeedTitle(id: 155, title: 'The Dark Knight', mediaType: 'movie', releaseYear: '2008', network: 'Warner Bros', posterPath: '/qJ2tW6WMUDux911r6m7haRef0WH.jpg', score: 9.9),
  SeedTitle(id: 569094, title: 'Spider-Man: Across the Spider-Verse', mediaType: 'movie', releaseYear: '2023', network: 'Sony Pictures', posterPath: '/8Vt6mWEReuy4Of61Lnj5Xj704m8.jpg', score: 9.68),
  SeedTitle(id: 872585, title: 'Oppenheimer', mediaType: 'movie', releaseYear: '2023', network: 'Universal', posterPath: '/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg', score: 9.45),
  SeedTitle(id: 278, title: 'The Shawshank Redemption', mediaType: 'movie', releaseYear: '1994', network: 'Columbia', posterPath: '/9cqNxx0GxF0bflZmeSMuL5tnGzr.jpg', score: 9.88),
  SeedTitle(id: 550, title: 'Fight Club', mediaType: 'movie', releaseYear: '1999', network: 'Fox 2000', posterPath: '/jSziioSwPVrOy9Yow3XhWIBDjq1.jpg', score: 9.32),
  SeedTitle(id: 13, title: 'Forrest Gump', mediaType: 'movie', releaseYear: '1994', network: 'Paramount', posterPath: '/Cw4hIUIAmSYfK9QfaUW5igp9La.jpg', score: 9.2),
  SeedTitle(id: 424, title: 'Schindler\'s List', mediaType: 'movie', releaseYear: '1993', network: 'Universal', posterPath: '/sF1U4EUQS8YHUYjNl3pMGNIQyr0.jpg', score: 9.78),
  SeedTitle(id: 19995, title: 'Avatar', mediaType: 'movie', releaseYear: '2009', network: '20th Century Fox', posterPath: '/gKY6q7SjCkAU6FqvqWybDYgUKIF.jpg', score: 8.85),
  SeedTitle(id: 27205, title: 'Inception', mediaType: 'movie', releaseYear: '2010', network: 'Warner Bros', posterPath: '/xlaY2zyzMfkhk0HSC5VUwzoZPU1.jpg', score: 9.55),
];

/// Looks up the verified seed poster path for a given [id] and [mediaType].
String? findSeedPoster(int id, String mediaType) {
  for (final s in kTop50SeedTitles) {
    if (s.id == id && s.mediaType == mediaType) {
      return s.posterPath;
    }
  }
  return null;
}


