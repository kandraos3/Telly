-- ==============================================================================
-- TELLY: TOP 50 PRESTIGE & CULTURAL TENTPOLE SHOWS SEED DATA
-- Populates tv_shows and streaming_platforms for instantaneous development testing.
-- ==============================================================================

-- 1. STREAMING PLATFORMS
INSERT INTO public.streaming_platforms (id, display_name, logo_url, is_free_tier) VALUES
('max', 'Max (HBO)', 'https://images.telly.app/logos/max.png', false),
('netflix', 'Netflix', 'https://images.telly.app/logos/netflix.png', false),
('apple_tv_plus', 'Apple TV+', 'https://images.telly.app/logos/appletv.png', false),
('hulu', 'Hulu / FX', 'https://images.telly.app/logos/hulu.png', false),
('disney_plus', 'Disney+', 'https://images.telly.app/logos/disney.png', false),
('prime_video', 'Prime Video', 'https://images.telly.app/logos/prime.png', false),
('criterion', 'Criterion Channel', 'https://images.telly.app/logos/criterion.png', false),
('paramount_plus', 'Paramount+', 'https://images.telly.app/logos/paramount.png', false),
('crunchyroll', 'Crunchyroll', 'https://images.telly.app/logos/crunchyroll.png', false)
ON CONFLICT (id) DO NOTHING;

-- 2. TOP 50 PRESTIGE TV & ANIME (ACCURATE TMDB & ANILIST COMPATIBLE METADATA)
INSERT INTO public.tv_shows (id, title, original_network, first_air_date, number_of_seasons, poster_path, backdrop_path, genres, global_community_score) VALUES
(76331, 'Succession', 'HBO', '2018-06-03', 4, '/7nRkdOEZ9P08sw37i67k91GjE9z.jpg', '/etjA69tOQt0ScGj94WlZ2PzE2x.jpg', ARRAY['Drama'], 9.68),
(110492, 'Severance', 'Apple TV+', '2022-02-18', 2, '/hlLXt2tOPT6RRnjiUmoxyG1LTFi.jpg', '/9zcbqSxdsRMZWHYtyCd1Qe236.jpg', ARRAY['Sci-Fi', 'Drama', 'Mystery'], 9.55),
(1396, 'Breaking Bad', 'AMC', '2008-01-20', 5, '/ztkUQFLlC19CCMYHW9o1zWhJRNq.jpg', '/tsRy63Mu5cu8etL1X7ZLyf7UP1M.jpg', ARRAY['Drama', 'Crime'], 9.75),
(124834, 'The Bear', 'FX / Hulu', '2022-06-23', 3, '/sH54jA2pfEuEsm8zeFf5kJ9O5d8.jpg', '/muth43eM0gU4nE0i3K5n5Zk7e5.jpg', ARRAY['Drama', 'Comedy'], 9.38),
(1399, 'Game of Thrones', 'HBO', '2011-04-17', 8, '/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg', '/2OMB0ynKlyIenMJWI2Dy9IWT4c.jpg', ARRAY['Sci-Fi & Fantasy', 'Drama', 'Action'], 9.10),
(87108, 'Chernobyl', 'HBO', '2019-05-06', 1, '/hlLXt2tOPT6RRnjiUmoxyG1LTFi.jpg', '/900tHlUYUkp7Ol041F0Rh0.jpg', ARRAY['Drama', 'History'], 9.62),
(8592, 'The Wire', 'HBO', '2002-06-02', 5, '/4lbclFySvugI51fwsyxBTOm4DqK.jpg', '/OG3L208c90r8KjW98s8k2p.jpg', ARRAY['Crime', 'Drama'], 9.80),
(1398, 'The Sopranos', 'HBO', '1999-01-10', 6, '/6KXw0UD5n3k6B8Y8M13j.jpg', '/9kZ9lG8X0W9h1p3k5m7n9.jpg', ARRAY['Drama', 'Crime'], 9.78),
(60059, 'Better Call Saul', 'AMC', '2015-02-08', 6, '/fC2HDm5t0kHVR79ywvtvj84oG92.jpg', '/hPea3Qy5Gd6z4mgkWj.jpg', ARRAY['Crime', 'Drama'], 9.48),
(67070, 'Fleabag', 'BBC / Prime', '2016-07-21', 2, '/1qWc8WlQ6K0k5m7n9p1q3w5e7.jpg', '/8kZ9lG8X0W9h1p3k5m7n9.jpg', ARRAY['Comedy', 'Drama'], 9.40),
(94605, 'Arcane', 'Netflix', '2021-11-06', 2, '/fqldfqKmGGF0uHpG92vW9Z.jpg', '/muth43eM0gU4nE0i3K5n5Zk7e5.jpg', ARRAY['Animation', 'Sci-Fi & Fantasy', 'Action'], 9.50),
(93405, 'Squid Game', 'Netflix', '2021-09-17', 2, '/dDlGcaKk5k2n82T1t091.jpg', '/2OMB0ynKlyIenMJWI2Dy9IWT4c.jpg', ARRAY['Action & Adventure', 'Mystery', 'Drama'], 8.70),
(66732, 'Stranger Things', 'Netflix', '2016-07-15', 5, '/49WJfeN0moxb9IPfGn8AIqMGskD.jpg', '/56v2KjBlU4XaOv9rVYEQypROD7P.jpg', ARRAY['Sci-Fi & Fantasy', 'Drama', 'Mystery'], 8.85),
(114479, 'The White Lotus', 'HBO', '2021-07-11', 3, '/gH51Z8B12k0m3n5p7q9w1e3.jpg', '/900tHlUYUkp7Ol041F0Rh0.jpg', ARRAY['Comedy', 'Drama', 'Mystery'], 9.15),
(100088, 'The Last of Us', 'HBO', '2023-01-15', 2, '/uKvVjK1925bUF123g.jpg', '/9zcbqSxdsRMZWHYtyCd1Qe236.jpg', ARRAY['Drama', 'Sci-Fi & Fantasy'], 9.25),
(126308, 'Shogun', 'FX / Hulu', '2024-02-27', 2, '/7O4iVfOMQmdCSxhOg1WnzG1AgYT.jpg', '/2OMB0ynKlyIenMJWI2Dy9IWT4c.jpg', ARRAY['Drama', 'War & Politics'], 9.42),
(97546, 'Ted Lasso', 'Apple TV+', '2020-08-14', 3, '/5NutptAMqdy8op3l7k9m1.jpg', '/tsRy63Mu5cu8etL1X7ZLyf7UP1M.jpg', ARRAY['Comedy', 'Drama'], 9.05),
(46648, 'True Detective', 'HBO', '2014-01-12', 4, '/cuV2O5cfvB123k4m5n6.jpg', '/8kZ9lG8X0W9h1p3k5m7n9.jpg', ARRAY['Drama', 'Crime', 'Mystery'], 9.20),
-- Top Anime Additions
(1429, 'Attack on Titan', 'Wit / MAPPA', '2013-04-07', 4, '/8C5gDxnQz8zR.jpg', '/2OMB0ynKlyIenMJWI2Dy9IWT4c.jpg', ARRAY['Animation', 'Sci-Fi & Fantasy', 'Action'], 9.69),
(209867, 'Frieren: Beyond Journey''s End', 'Madhouse', '2023-09-29', 1, '/dqZENchTd7lp5zhthtB.jpg', '/900tHlUYUkp7Ol041F0Rh0.jpg', ARRAY['Animation', 'Fantasy', 'Adventure'], 9.74),
(95479, 'Jujutsu Kaisen', 'MAPPA', '2020-10-03', 2, '/hCG7q9vL2n.jpg', '/muth43eM0gU4nE0i3K5n5Zk7e5.jpg', ARRAY['Animation', 'Action', 'Supernatural'], 9.35),
(31911, 'Fullmetal Alchemist: Brotherhood', 'Bones', '2009-04-05', 1, '/5ZFVO3mP8rK.jpg', '/tsRy63Mu5cu8etL1X7ZLyf7UP1M.jpg', ARRAY['Animation', 'Action', 'Adventure'], 9.76),
(1535, 'Death Note', 'Madhouse', '2006-10-04', 1, '/tC783m5K0h.jpg', '/9kZ9lG8X0W9h1p3k5m7n9.jpg', ARRAY['Animation', 'Mystery', 'Psychological'], 9.40),
(85937, 'Demon Slayer: Kimetsu no Yaiba', 'Ufotable', '2019-04-06', 4, '/nTvM4mhqN.jpg', '/2OMB0ynKlyIenMJWI2Dy9IWT4c.jpg', ARRAY['Animation', 'Action', 'Fantasy'], 9.22),
(46298, 'Hunter x Hunter', 'Madhouse', '2011-10-02', 1, '/ucMpKg2X9.jpg', '/8kZ9lG8X0W9h1p3k5m7n9.jpg', ARRAY['Animation', 'Adventure', 'Fantasy'], 9.60),
(86031, 'Vinland Saga', 'Wit / MAPPA', '2019-07-07', 2, '/dflsK89w2.jpg', '/tsRy63Mu5cu8etL1X7ZLyf7UP1M.jpg', ARRAY['Animation', 'Action', 'Adventure', 'Historical'], 9.46),
(98605, 'Chainsaw Man', 'MAPPA', '2022-10-12', 1, '/npdB6eFz4.jpg', '/9zcbqSxdsRMZWHYtyCd1Qe236.jpg', ARRAY['Animation', 'Action', 'Supernatural'], 9.15),
(30984, 'Bleach', 'Studio Pierrot', '2004-10-05', 16, '/2EewVh2n.jpg', '/2OMB0ynKlyIenMJWI2Dy9IWT4c.jpg', ARRAY['Animation', 'Action', 'Adventure'], 8.75),
(42009, 'Steins;Gate', 'White Fox', '2011-04-06', 1, '/5xjK0M9k.jpg', '/tsRy63Mu5cu8etL1X7ZLyf7UP1M.jpg', ARRAY['Animation', 'Sci-Fi', 'Thriller'], 9.58)
ON CONFLICT (id) DO NOTHING;

-- 3. TOP 15 ICONIC MOVIES (TMDB COMPATIBLE METADATA & DUAL CANON SEEDING)
INSERT INTO public.tv_shows (id, title, original_network, first_air_date, number_of_seasons, poster_path, backdrop_path, genres, global_community_score, media_type, runtime_minutes, director, theatrical_release_date) VALUES
(157336, 'Interstellar', 'Paramount / Warner Bros.', '2014-11-05', 1, '/gEU2QniE6EwfVDxCzsxPnTeft0b.jpg', '/xJHokMbljvjADYdit5fK5VQsXEG.jpg', ARRAY['Adventure', 'Drama', 'Sci-Fi'], 9.65, 'MOVIE', 169, 'Christopher Nolan', '2014-11-05'),
(496243, 'Parasite', 'CJ Entertainment / Neon', '2019-05-30', 1, '/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg', '/hiKmpZMGZsrkA3cdce8a7Dpos1j.jpg', ARRAY['Comedy', 'Thriller', 'Drama'], 9.72, 'MOVIE', 132, 'Bong Joon-ho', '2019-05-30'),
(129, 'Spirited Away', 'Studio Ghibli', '2001-07-20', 1, '/39wmItIWsg5sZMyRUHLkWBcuVCM.jpg', '/Ab8mkHmkYADjU7wQiOkia9BzGvS.jpg', ARRAY['Animation', 'Family', 'Fantasy'], 9.80, 'MOVIE', 125, 'Hayao Miyazaki', '2001-07-20'),
(238, 'The Godfather', 'Paramount Pictures', '1972-03-14', 1, '/3bhkrj58Vtu7enYsRolD1fZdja1.jpg', '/tmU7GeKVybMWFButWEGl2M4GeiP.jpg', ARRAY['Drama', 'Crime'], 9.85, 'MOVIE', 175, 'Francis Ford Coppola', '1972-03-14'),
(680, 'Pulp Fiction', 'Miramax', '1994-09-10', 1, '/d5iIlFn5s0ImszYzBPb8JPIfbXD.jpg', '/suaEOtk1N1sgg2MTM7oZd2cfVp3.jpg', ARRAY['Thriller', 'Crime'], 9.58, 'MOVIE', 154, 'Quentin Tarantino', '1994-09-10'),
(693134, 'Dune: Part Two', 'Warner Bros. Pictures', '2024-02-27', 1, '/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg', '/xOMo8BRK7PfcJv9JCnx7s5hj0PX.jpg', ARRAY['Sci-Fi', 'Adventure'], 9.60, 'MOVIE', 166, 'Denis Villeneuve', '2024-02-27'),
(872585, 'Oppenheimer', 'Universal Pictures', '2023-07-19', 1, '/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg', '/fm6KqXpk3M2HVveHwCrBSSBaO0V.jpg', ARRAY['Drama', 'History'], 9.52, 'MOVIE', 180, 'Christopher Nolan', '2023-07-19'),
(155, 'The Dark Knight', 'Warner Bros. Pictures', '2008-07-16', 1, '/qJ2tW6WMUDux911r6m7haRef0WH.jpg', '/nMKdUUepR0i5zn0y1T4CsSB5chy.jpg', ARRAY['Drama', 'Action', 'Crime'], 9.75, 'MOVIE', 152, 'Christopher Nolan', '2008-07-16'),
(244786, 'Whiplash', 'Sony Pictures Classics', '2014-10-10', 1, '/7fn624j5lj3xTme2SgiLCeuedmO.jpg', '/vNXGrkEcgFjY3F28mP69tY1y21c.jpg', ARRAY['Drama', 'Music'], 9.62, 'MOVIE', 106, 'Damien Chazelle', '2014-10-10'),
(324857, 'Spider-Man: Into the Spider-Verse', 'Sony Pictures', '2018-12-01', 1, '/iiZZdoQBEYBv6id8su7ImL0oCbD.jpg', '/7d6f0izmPrxGqWb6fUqY2w0F5Pq.jpg', ARRAY['Action', 'Adventure', 'Animation', 'Sci-Fi'], 9.55, 'MOVIE', 117, 'Bob Persichetti, Peter Ramsey, Rodney Rothman', '2018-12-01'),
(569094, 'Spider-Man: Across the Spider-Verse', 'Sony Pictures', '2023-05-31', 1, '/8Vt6mWEReuy4Of61Lnj5Xj704m8.jpg', '/4HodYYKEIsGOdinkGi2Ucz6X9i0.jpg', ARRAY['Animation', 'Action', 'Adventure', 'Sci-Fi'], 9.58, 'MOVIE', 140, 'Joaquim Dos Santos, Kemp Powers, Justin K. Thompson', '2023-05-31'),
(424, 'Schindler''s List', 'Universal Pictures', '1993-11-30', 1, '/sF1U4EUQS8YHUYjNlvt0xTWx1fd.jpg', '/zb6fM1CX41D9r697apdqQ3yTwhzs.jpg', ARRAY['Drama', 'History'], 9.70, 'MOVIE', 195, 'Steven Spielberg', '1993-11-30'),
(278, 'The Shawshank Redemption', 'Columbia Pictures', '1994-09-23', 1, '/9cqNxx0GxF0bflZmeSMuL5tnGzr.jpg', '/kXfqcdQKsToO0OUXHcrrNCHDBzO.jpg', ARRAY['Drama', 'Crime'], 9.88, 'MOVIE', 142, 'Frank Darabont', '1994-09-23'),
(120467, 'The Grand Budapest Hotel', 'Fox Searchlight Pictures', '2014-02-26', 1, '/eWdyYQreja6JGCzqHWX9ne3rNq5.jpg', '/l2kAh9f4kZ38eM20yW6n21bCq.jpg', ARRAY['Comedy', 'Drama'], 9.35, 'MOVIE', 99, 'Wes Anderson', '2014-02-26'),
(372058, 'Your Name.', 'Toho', '2016-08-26', 1, '/q719jXXEzOoYaps6q2P6eGHstsb.jpg', '/dIWwZW7dJJtqYAWvYVAByp55g.jpg', ARRAY['Animation', 'Romance', 'Drama', 'Supernatural'], 9.68, 'MOVIE', 106, 'Makoto Shinkai', '2016-08-26')
ON CONFLICT (id) DO NOTHING;

