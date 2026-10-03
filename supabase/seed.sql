-- =============================================================================
-- TELLY SEED DATA (BE-601 / BE-102)
-- 50 onboarding recognition titles: 20 prestige TV + 15 anime ('tv', is_anime) + 15 films ('movie').
-- Must stay in sync with lib/features/onboarding/data/top_50_seeds.dart
-- (enforced by test/features/onboarding/seed_sql_parity_test.dart).
-- =============================================================================

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

INSERT INTO public.titles (
    id, media_type, title, release_date, original_network, number_of_seasons,
    runtime_minutes, director, is_anime, poster_path, backdrop_path, genres, global_community_score
) VALUES
(76331, 'tv', 'Succession', '2018-06-03', 'HBO', 4, NULL, NULL, FALSE, '/7nRkdOEZ9P08sw37i67k91GjE9z.jpg', '/etjA69tOQt0ScGj94WlZ2PzE2x.jpg', ARRAY['Drama']::TEXT[], 9.68),
(110492, 'tv', 'Severance', '2022-02-18', 'Apple TV+', 2, NULL, NULL, FALSE, '/hlLXt2tOPT6RRnjiUmoxyG1LTFi.jpg', '/9zcbqSxdsRMZWHYtyCd1Qe236.jpg', ARRAY['Sci-Fi', 'Drama', 'Mystery']::TEXT[], 9.55),
(1396, 'tv', 'Breaking Bad', '2008-01-20', 'AMC', 5, NULL, NULL, FALSE, '/ztkUQFLlC19CCMYHW9o1zWhJRNq.jpg', '/tsRy63Mu5cu8etL1X7ZLyf7UP1M.jpg', ARRAY['Drama', 'Crime']::TEXT[], 9.75),
(124834, 'tv', 'The Bear', '2022-06-23', 'FX / Hulu', 3, NULL, NULL, FALSE, '/sH54jA2pfEuEsm8zeFf5kJ9O5d8.jpg', '/muth43eM0gU4nE0i3K5n5Zk7e5.jpg', ARRAY['Drama', 'Comedy']::TEXT[], 9.38),
(1399, 'tv', 'Game of Thrones', '2011-04-17', 'HBO', 8, NULL, NULL, FALSE, '/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg', '/2OMB0ynKlyIenMJWI2Dy9IWT4c.jpg', ARRAY['Sci-Fi & Fantasy', 'Drama', 'Action']::TEXT[], 9.10),
(87108, 'tv', 'Chernobyl', '2019-05-06', 'HBO', 1, NULL, NULL, FALSE, '/hlLXt2tOPT6RRnjiUmoxyG1LTFi.jpg', '/900tHlUYUkp7Ol041F0Rh0.jpg', ARRAY['Drama', 'History']::TEXT[], 9.62),
(8592, 'tv', 'The Wire', '2002-06-02', 'HBO', 5, NULL, NULL, FALSE, '/4lbclFySvugI51fwsyxBTOm4DqK.jpg', '/OG3L208c90r8KjW98s8k2p.jpg', ARRAY['Crime', 'Drama']::TEXT[], 9.80),
(1398, 'tv', 'The Sopranos', '1999-01-10', 'HBO', 6, NULL, NULL, FALSE, '/6KXw0UD5n3k6B8Y8M13j.jpg', '/9kZ9lG8X0W9h1p3k5m7n9.jpg', ARRAY['Drama', 'Crime']::TEXT[], 9.78),
(60059, 'tv', 'Better Call Saul', '2015-02-08', 'AMC', 6, NULL, NULL, FALSE, '/fC2HDm5t0kHVR79ywvtvj84oG92.jpg', '/hPea3Qy5Gd6z4mgkWj.jpg', ARRAY['Crime', 'Drama']::TEXT[], 9.48),
(67070, 'tv', 'Fleabag', '2016-07-21', 'BBC / Prime', 2, NULL, NULL, FALSE, '/1qWc8WlQ6K0k5m7n9p1q3w5e7.jpg', '/8kZ9lG8X0W9h1p3k5m7n9.jpg', ARRAY['Comedy', 'Drama']::TEXT[], 9.40),
(94605, 'tv', 'Arcane', '2021-11-06', 'Netflix', 2, NULL, NULL, FALSE, '/fqldfqKmGGF0uHpG92vW9Z.jpg', '/muth43eM0gU4nE0i3K5n5Zk7e5.jpg', ARRAY['Animation', 'Sci-Fi & Fantasy', 'Action']::TEXT[], 9.50),
(93405, 'tv', 'Squid Game', '2021-09-17', 'Netflix', 2, NULL, NULL, FALSE, '/dDlGcaKk5k2n82T1t091.jpg', '/2OMB0ynKlyIenMJWI2Dy9IWT4c.jpg', ARRAY['Action & Adventure', 'Mystery', 'Drama']::TEXT[], 8.70),
(66732, 'tv', 'Stranger Things', '2016-07-15', 'Netflix', 5, NULL, NULL, FALSE, '/49WJfeN0moxb9IPfGn8AIqMGskD.jpg', '/56v2KjBlU4XaOv9rVYEQypROD7P.jpg', ARRAY['Sci-Fi & Fantasy', 'Drama', 'Mystery']::TEXT[], 8.85),
(114479, 'tv', 'The White Lotus', '2021-07-11', 'HBO', 3, NULL, NULL, FALSE, '/gH51Z8B12k0m3n5p7q9w1e3.jpg', '/900tHlUYUkp7Ol041F0Rh0.jpg', ARRAY['Comedy', 'Drama', 'Mystery']::TEXT[], 9.15),
(100088, 'tv', 'The Last of Us', '2023-01-15', 'HBO', 2, NULL, NULL, FALSE, '/uKvVjK1925bUF123g.jpg', '/9zcbqSxdsRMZWHYtyCd1Qe236.jpg', ARRAY['Drama', 'Sci-Fi & Fantasy']::TEXT[], 9.25),
(126308, 'tv', 'Shogun', '2024-02-27', 'FX / Hulu', 2, NULL, NULL, FALSE, '/7O4iVfOMQmdCSxhOg1WnzG1AgYT.jpg', '/2OMB0ynKlyIenMJWI2Dy9IWT4c.jpg', ARRAY['Drama', 'War & Politics']::TEXT[], 9.42),
(97546, 'tv', 'Ted Lasso', '2020-08-14', 'Apple TV+', 3, NULL, NULL, FALSE, '/5NutptAMqdy8op3l7k9m1.jpg', '/tsRy63Mu5cu8etL1X7ZLyf7UP1M.jpg', ARRAY['Comedy', 'Drama']::TEXT[], 9.05),
(46648, 'tv', 'True Detective', '2014-01-12', 'HBO', 4, NULL, NULL, FALSE, '/cuV2O5cfvB123k4m5n6.jpg', '/8kZ9lG8X0W9h1p3k5m7n9.jpg', ARRAY['Drama', 'Crime', 'Mystery']::TEXT[], 9.20),
(70523, 'tv', 'Dark', NULL, 'Netflix', NULL, NULL, NULL, FALSE, '/apbrbWs8M9lyOpJYU5WXrpFbk1Z.jpg', NULL, ARRAY[]::TEXT[], 9.35),
(82856, 'tv', 'The Mandalorian', NULL, 'Disney+', NULL, NULL, NULL, FALSE, '/eU1i6eHXlzMOlEq0ku1R07YQ7Ma.jpg', NULL, ARRAY[]::TEXT[], 8.95),
(1429, 'tv', 'Attack on Titan', '2013-04-07', 'Wit / MAPPA', 4, NULL, NULL, TRUE, '/8C5gDxnQz8zR.jpg', '/2OMB0ynKlyIenMJWI2Dy9IWT4c.jpg', ARRAY['Animation', 'Sci-Fi & Fantasy', 'Action']::TEXT[], 9.69),
(209867, 'tv', 'Frieren: Beyond Journey''s End', '2023-09-29', 'Madhouse', 1, NULL, NULL, TRUE, '/dqZENchTd7lp5zhthtB.jpg', '/900tHlUYUkp7Ol041F0Rh0.jpg', ARRAY['Animation', 'Fantasy', 'Adventure']::TEXT[], 9.74),
(95479, 'tv', 'Jujutsu Kaisen', '2020-10-03', 'MAPPA', 2, NULL, NULL, TRUE, '/hCG7q9vL2n.jpg', '/muth43eM0gU4nE0i3K5n5Zk7e5.jpg', ARRAY['Animation', 'Action', 'Supernatural']::TEXT[], 9.35),
(31911, 'tv', 'Fullmetal Alchemist: Brotherhood', '2009-04-05', 'Bones', 1, NULL, NULL, TRUE, '/5ZFVO3mP8rK.jpg', '/tsRy63Mu5cu8etL1X7ZLyf7UP1M.jpg', ARRAY['Animation', 'Action', 'Adventure']::TEXT[], 9.76),
(1535, 'tv', 'Death Note', '2006-10-04', 'Madhouse', 1, NULL, NULL, TRUE, '/tC783m5K0h.jpg', '/9kZ9lG8X0W9h1p3k5m7n9.jpg', ARRAY['Animation', 'Mystery', 'Psychological']::TEXT[], 9.40),
(85937, 'tv', 'Demon Slayer', '2019-04-06', 'Ufotable', 4, NULL, NULL, TRUE, '/nTvM4mhqN.jpg', '/2OMB0ynKlyIenMJWI2Dy9IWT4c.jpg', ARRAY['Animation', 'Action', 'Fantasy']::TEXT[], 9.22),
(46298, 'tv', 'Hunter x Hunter', '2011-10-02', 'Madhouse', 1, NULL, NULL, TRUE, '/ucMpKg2X9.jpg', '/8kZ9lG8X0W9h1p3k5m7n9.jpg', ARRAY['Animation', 'Adventure', 'Fantasy']::TEXT[], 9.60),
(86031, 'tv', 'Vinland Saga', '2019-07-07', 'MAPPA', 2, NULL, NULL, TRUE, '/dflsK89w2.jpg', '/tsRy63Mu5cu8etL1X7ZLyf7UP1M.jpg', ARRAY['Animation', 'Action', 'Adventure', 'Historical']::TEXT[], 9.46),
(98605, 'tv', 'Chainsaw Man', '2022-10-12', 'MAPPA', 1, NULL, NULL, TRUE, '/npdB6eFz4.jpg', '/9zcbqSxdsRMZWHYtyCd1Qe236.jpg', ARRAY['Animation', 'Action', 'Supernatural']::TEXT[], 9.15),
(30984, 'tv', 'Bleach', '2004-10-05', 'Studio Pierrot', 16, NULL, NULL, TRUE, '/2EewVh2n.jpg', '/2OMB0ynKlyIenMJWI2Dy9IWT4c.jpg', ARRAY['Animation', 'Action', 'Adventure']::TEXT[], 8.75),
(42009, 'tv', 'Steins;Gate', '2011-04-06', 'White Fox', 1, NULL, NULL, TRUE, '/5xjK0M9k.jpg', '/tsRy63Mu5cu8etL1X7ZLyf7UP1M.jpg', ARRAY['Animation', 'Sci-Fi', 'Thriller']::TEXT[], 9.58),
(45, 'tv', 'Neon Genesis Evangelion', NULL, 'Gainax', NULL, NULL, NULL, TRUE, '/yQ01H49u9.jpg', NULL, ARRAY[]::TEXT[], 9.30),
(121, 'tv', 'Cowboy Bebop', NULL, 'Sunrise', NULL, NULL, NULL, TRUE, '/d05FfL1z.jpg', NULL, ARRAY[]::TEXT[], 9.45),
(65930, 'tv', 'My Hero Academia', NULL, 'Bones', NULL, NULL, NULL, TRUE, '/ivOLNs.jpg', NULL, ARRAY[]::TEXT[], 8.65),
(60625, 'tv', 'Mob Psycho 100', NULL, 'Bones', NULL, NULL, NULL, TRUE, '/e2d19f.jpg', NULL, ARRAY[]::TEXT[], 9.28),
(157336, 'movie', 'Interstellar', '2014-11-05', 'Paramount', NULL, 169, 'Christopher Nolan', FALSE, '/gEU2QniE6EwfVDxCzsxPnTeft0b.jpg', '/xJHokMbljvjADYdit5fK5VQsXEG.jpg', ARRAY['Adventure', 'Drama', 'Sci-Fi']::TEXT[], 9.65),
(496243, 'movie', 'Parasite', '2019-05-30', 'Neon', NULL, 132, 'Bong Joon-ho', FALSE, '/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg', '/hiKmpZMGZsrkA3cdce8a7Dpos1j.jpg', ARRAY['Comedy', 'Thriller', 'Drama']::TEXT[], 9.72),
(129, 'movie', 'Spirited Away', '2001-07-20', 'Studio Ghibli', NULL, 125, 'Hayao Miyazaki', FALSE, '/39wmItIWsg5sZMyRUHLkWBcuVCM.jpg', '/Ab8mkHmkYADjU7wQiOkia9BzGvS.jpg', ARRAY['Animation', 'Family', 'Fantasy']::TEXT[], 9.80),
(238, 'movie', 'The Godfather', '1972-03-14', 'Paramount', NULL, 175, 'Francis Ford Coppola', FALSE, '/3bhkrj58Vtu7enYsRolD1fZdja1.jpg', '/tmU7GeKVybMWFButWEGl2M4GeiP.jpg', ARRAY['Drama', 'Crime']::TEXT[], 9.85),
(680, 'movie', 'Pulp Fiction', '1994-09-10', 'Miramax', NULL, 154, 'Quentin Tarantino', FALSE, '/d5iIlFn5s0ImszYzBPb8JPIfbXD.jpg', '/suaEOtk1N1sgg2MTM7oZd2cfVp3.jpg', ARRAY['Thriller', 'Crime']::TEXT[], 9.58),
(693134, 'movie', 'Dune: Part Two', '2024-02-27', 'Warner Bros', NULL, 166, 'Denis Villeneuve', FALSE, '/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg', '/xOMo8BRK7PfcJv9JCnx7s5hj0PX.jpg', ARRAY['Sci-Fi', 'Adventure']::TEXT[], 9.60),
(155, 'movie', 'The Dark Knight', '2008-07-16', 'Warner Bros', NULL, 152, 'Christopher Nolan', FALSE, '/qJ2tW6WMUDux911r6m7haRef0WH.jpg', '/nMKdUUepR0i5zn0y1T4CsSB5chy.jpg', ARRAY['Drama', 'Action', 'Crime']::TEXT[], 9.90),
(569094, 'movie', 'Spider-Man: Across the Spider-Verse', '2023-05-31', 'Sony Pictures', NULL, 140, 'Joaquim Dos Santos, Kemp Powers, Justin K. Thompson', FALSE, '/8Vt6mWEReuy4Of61Lnj5Xj704m8.jpg', '/4HodYYKEIsGOdinkGi2Ucz6X9i0.jpg', ARRAY['Animation', 'Action', 'Adventure', 'Sci-Fi']::TEXT[], 9.68),
(872585, 'movie', 'Oppenheimer', '2023-07-19', 'Universal', NULL, 180, 'Christopher Nolan', FALSE, '/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg', '/fm6KqXpk3M2HVveHwCrBSSBaO0V.jpg', ARRAY['Drama', 'History']::TEXT[], 9.45),
(278, 'movie', 'The Shawshank Redemption', '1994-09-23', 'Columbia', NULL, 142, 'Frank Darabont', FALSE, '/9cqNxx0GxF0bflZmeSMuL5tnGzr.jpg', '/kXfqcdQKsToO0OUXHcrrNCHDBzO.jpg', ARRAY['Drama', 'Crime']::TEXT[], 9.88),
(550, 'movie', 'Fight Club', NULL, 'Fox 2000', NULL, NULL, NULL, FALSE, '/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg', NULL, ARRAY[]::TEXT[], 9.32),
(13, 'movie', 'Forrest Gump', NULL, 'Paramount', NULL, NULL, NULL, FALSE, '/arw2vcBveWOVZr6pxd9XTd1TdQa.jpg', NULL, ARRAY[]::TEXT[], 9.20),
(424, 'movie', 'Schindler''s List', '1993-11-30', 'Universal', NULL, 195, 'Steven Spielberg', FALSE, '/sF1U4EUQS8YHUYjNlvt0xTX3mFq.jpg', '/zb6fM1CX41D9r697apdqQ3yTwhzs.jpg', ARRAY['Drama', 'History']::TEXT[], 9.78),
(19995, 'movie', 'Avatar', NULL, '20th Century Fox', NULL, NULL, NULL, FALSE, '/kyeqWdyUXW608qlYkRqosgbbJyK.jpg', NULL, ARRAY[]::TEXT[], 8.85),
(27205, 'movie', 'Inception', NULL, 'Warner Bros', NULL, NULL, NULL, FALSE, '/edv5CZvWj09upOsy2Y6IwDhK8bt.jpg', NULL, ARRAY[]::TEXT[], 9.55)
ON CONFLICT (id, media_type) DO NOTHING;
