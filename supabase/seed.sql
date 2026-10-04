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
(76331, 'tv', 'Succession', '2018-06-03', 'HBO', 4, NULL, NULL, FALSE, '/z0XiwdrCQ9yVIr4O0pxzaAYRxdW.jpg', '/d87JXX3DLkRJMfm5StCmmnmhHuX.jpg', ARRAY['Drama', 'Comedy']::TEXT[], 9.68),
(110492, 'tv', 'Severance', '2022-01-13', 'Apple TV+', 2, NULL, NULL, FALSE, '/yb4F1Oocq8GfQt6iIuAgYEBokhG.jpg', '/aJcUU3LMlqMKBi8L3eaxGfAbd4G.jpg', ARRAY['Action & Adventure', 'Sci-Fi & Fantasy', 'Comedy']::TEXT[], 9.55),
(1396, 'tv', 'Breaking Bad', '2008-01-20', 'AMC', 5, NULL, NULL, FALSE, '/anFx9aTOOYqgS3v7x3R84Kz67ly.jpg', '/tsRy63Mu5cu8etL1X7ZLyf7UP1M.jpg', ARRAY['Drama', 'Crime']::TEXT[], 9.75),
(124834, 'tv', 'The Bear', '2022-04-22', 'FX / Hulu', 3, NULL, NULL, FALSE, '/dQc0QbDiHjGmWxTfKtBgYtS4bj5.jpg', '/8cpXau1LjYMBjiaHUS75JmlgGsU.jpg', ARRAY['Drama']::TEXT[], 9.38),
(1399, 'tv', 'Game of Thrones', '2011-04-17', 'HBO', 8, NULL, NULL, FALSE, '/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg', '/zZqpAXxVSBtxV9qPBcscfXBcL2w.jpg', ARRAY['Sci-Fi & Fantasy', 'Drama', 'Action & Adventure']::TEXT[], 9.1),
(87108, 'tv', 'Chernobyl', '2019-05-06', 'HBO', 1, NULL, NULL, FALSE, '/hlLXt2tOPT6RRnjiUmoxyG1LTFi.jpg', '/900tHlUYUkp7Ol04XFSoAaEIXcT.jpg', ARRAY['Drama']::TEXT[], 9.62),
(8592, 'tv', 'The Wire', '2009-04-09', 'HBO', 7, 22, NULL, FALSE, '/5IOj62y2Eb2ngyYmEn1IJ7bFhzH.jpg', '/frwl2zBNAl5ZbFDJGoJv0mYo0rF.jpg', ARRAY['Comedy']::TEXT[], 9.8),
(1398, 'tv', 'The Sopranos', '1999-01-10', 'HBO', 6, NULL, NULL, FALSE, '/rTc7ZXdroqjkKivFPvCPX0Ru7uw.jpg', '/lNpkvX2s8LGB0mjGODMT4o6Up7j.jpg', ARRAY['Crime', 'Drama']::TEXT[], 9.78),
(60059, 'tv', 'Better Call Saul', '2015-02-08', 'AMC', 6, NULL, NULL, FALSE, '/fC2HDm5t0kHl7mTm7jxMR31b7by.jpg', '/rfxryDIv8huejujg4JueDJx8zCz.jpg', ARRAY['Crime', 'Drama']::TEXT[], 9.48),
(67070, 'tv', 'Fleabag', '2016-07-21', 'BBC / Prime', 2, NULL, NULL, FALSE, '/vFn0nLPcIggPH5LTWWaJ2hcsGlc.jpg', '/hXdQ4MWsEOX6qg6VydKrLb3YJ4g.jpg', ARRAY['Comedy', 'Drama']::TEXT[], 9.4),
(94605, 'tv', 'Arcane', '2021-11-06', 'Netflix', 2, NULL, NULL, FALSE, '/fqldf2t8ztc9aiwn3k6mlX3tvRT.jpg', '/5cvnxEHT3e39DvT6ARw4GNCFrB0.jpg', ARRAY['Animation', 'Action & Adventure', 'Sci-Fi & Fantasy']::TEXT[], 9.5),
(93405, 'tv', 'Squid Game', '2021-09-17', 'Netflix', 3, NULL, NULL, FALSE, '/1QdXdRYfktUSONkl1oD5gc6Be0s.jpg', '/2meX1nMdScFOoV4370rqHWKmXhY.jpg', ARRAY['Action & Adventure', 'Mystery', 'Drama']::TEXT[], 8.7),
(66732, 'tv', 'Stranger Things', '2016-07-15', 'Netflix', 5, NULL, NULL, FALSE, '/uOOtwVbSr4QDjAGIifLDwpb2Pdl.jpg', '/9P4IIMYY3HifqeruZq0ZZ9g7YUi.jpg', ARRAY['Action & Adventure', 'Mystery', 'Sci-Fi & Fantasy']::TEXT[], 8.85),
(114479, 'tv', 'The White Lotus', '2024-06-04', 'HBO', 1, NULL, NULL, FALSE, '/mztdt3y6GBsJR69zHtszFezTCLT.jpg', '/kwronSXO1ogMqHHFvY2eBxfFLdn.jpg', ARRAY['Mystery', 'Sci-Fi & Fantasy', 'Action & Adventure']::TEXT[], 9.15),
(100088, 'tv', 'The Last of Us', '2023-01-15', 'HBO', 2, NULL, NULL, FALSE, '/dmo6TYuuJgaYinXBPjrgG9mB5od.jpg', '/lY2DhbA7Hy44fAKddr06UrXWWaQ.jpg', ARRAY['Drama']::TEXT[], 9.25),
(126308, 'tv', 'Shogun', '2024-02-27', 'FX / Hulu', 1, NULL, NULL, FALSE, '/7O4iVfOMQmdCSxhOg1WnzG1AgYT.jpg', '/bwSmgmd90hCWwqOKQYTEraeOZhJ.jpg', ARRAY['Drama', 'War & Politics']::TEXT[], 9.42),
(97546, 'tv', 'Ted Lasso', '2020-08-14', 'Apple TV+', 4, NULL, NULL, FALSE, '/uRHsiw1wLxPHFXkkv4Ix1s0O6f4.jpg', '/nE94ejEbzNCU48bW1oju0dqBONz.jpg', ARRAY['Drama', 'Comedy']::TEXT[], 9.05),
(46648, 'tv', 'True Detective', '2014-01-12', 'HBO', 4, NULL, NULL, FALSE, '/zYqVTiHK5ZajYcNzAW7qWte5NWS.jpg', '/v8YFr8BbU9qsO8PYIulzTeM6Qk.jpg', ARRAY['Drama', 'Mystery']::TEXT[], 9.2),
(70523, 'tv', 'Dark', '2017-12-01', 'Netflix', 3, NULL, NULL, FALSE, '/apbrbWs8M9lyOpJYU5WXrpFbk1Z.jpg', '/75HgaphatW0PDI3XIHQWZUpbhn6.jpg', ARRAY['Crime', 'Drama', 'Sci-Fi & Fantasy', 'Mystery']::TEXT[], 9.35),
(82856, 'tv', 'The Mandalorian', '2019-11-12', 'Disney+', 3, NULL, NULL, FALSE, '/sWgBv7LV2PRoQgkxwlibdGXKz1S.jpg', '/9zcbqSxdsRMZWHYtyCd1nXPr2xq.jpg', ARRAY['Sci-Fi & Fantasy', 'Action & Adventure']::TEXT[], 8.95),
(1429, 'tv', 'Attack on Titan', '2013-04-07', 'Wit / MAPPA', 4, NULL, NULL, TRUE, '/hTP1DtLGFamjfu8WqjnuQdP1n4i.jpg', '/rqbCbjB19amtOtFQbb3K2lgm2zv.jpg', ARRAY['Animation', 'Sci-Fi & Fantasy', 'Action & Adventure']::TEXT[], 9.69),
(209867, 'tv', 'Frieren: Beyond Journey''s End', '2023-09-29', 'Madhouse', 1, 25, NULL, TRUE, '/dqZENchTd7lp5zht7BdlqM7RBhD.jpg', '/rBOnrVlck7BIlGeWVlzYiZeg4l2.jpg', ARRAY['Animation', 'Action & Adventure', 'Drama', 'Sci-Fi & Fantasy']::TEXT[], 9.74),
(95479, 'tv', 'Jujutsu Kaisen', '2020-10-03', 'MAPPA', 1, 24, NULL, TRUE, '/6qQzMJG27XOJsyAEEIisoJB45j2.jpg', '/j2GvamiUMRpPjmNQSSht0Q7Z7e9.jpg', ARRAY['Animation', 'Sci-Fi & Fantasy', 'Action & Adventure']::TEXT[], 9.35),
(31911, 'tv', 'Fullmetal Alchemist: Brotherhood', '2009-04-05', 'Bones', 1, NULL, NULL, TRUE, '/5ZFUEOULaVml7pQuXxhpR2SmVUw.jpg', '/A6tMQAo6t6eRFCPhsrShmxZLqFB.jpg', ARRAY['Animation', 'Action & Adventure', 'Sci-Fi & Fantasy', 'Drama']::TEXT[], 9.76),
(13916, 'tv', 'Death Note', '2006-10-04', 'Madhouse', 1, 22, NULL, TRUE, '/tCZFfYTIwrR7n94J6G14Y4hAFU6.jpg', '/z8IPicmEKXUO4I2UDdMEqw7RqOE.jpg', ARRAY['Animation', 'Mystery', 'Sci-Fi & Fantasy']::TEXT[], 9.4),
(85937, 'tv', 'Demon Slayer', '2019-04-06', 'Ufotable', 5, NULL, NULL, TRUE, '/xUfRZu2mi8jH6SzQEJGP6tjBuYj.jpg', '/3GQKYh6Trm8pxd2AypovoYQf4Ay.jpg', ARRAY['Animation', 'Action & Adventure', 'Sci-Fi & Fantasy']::TEXT[], 9.22),
(46298, 'tv', 'Hunter x Hunter', '2011-10-02', 'Madhouse', 3, 24, NULL, TRUE, '/i2EEr2uBvRlAwJ8d8zTG2Y19mIa.jpg', '/bFKKyCI89Xq98Gul8cGox8K3sZa.jpg', ARRAY['Animation', 'Action & Adventure', 'Sci-Fi & Fantasy']::TEXT[], 9.6),
(86031, 'tv', 'Vinland Saga', '2019-07-05', 'MAPPA', 4, 24, NULL, TRUE, '/xbZQ3fDl0y5mt0ARwfeyrgQ4JTw.jpg', '/lN13BPAEnc5iXmoxxBQHOZ1ScfZ.jpg', ARRAY['Animation', 'Action & Adventure', 'Comedy', 'Sci-Fi & Fantasy']::TEXT[], 9.46),
(98605, 'tv', 'Chainsaw Man', '2018-12-15', 'MAPPA', 1, 360, NULL, TRUE, '/iT0Pc9iJPL2ywIfs81qthQAjSSx.jpg', '/erPg3DHRz3Kb3gMQMEOVgfrRY20.jpg', ARRAY['Documentary']::TEXT[], 9.15),
(30984, 'tv', 'Bleach', '2004-10-05', 'Studio Pierrot', 2, 24, NULL, TRUE, '/2EewmxXe72ogD0EaWM8gqa0ccIw.jpg', '/o0NsbcIvsllg6CJX0FBFY8wWbsn.jpg', ARRAY['Action & Adventure', 'Animation', 'Sci-Fi & Fantasy']::TEXT[], 8.75),
(42009, 'tv', 'Steins;Gate', '2011-12-04', 'White Fox', 7, NULL, NULL, TRUE, '/seN6rRfN0I6n8iDXjlSMk1QjNcq.jpg', '/dg3OindVAGZBjlT3xYKqIAdukPL.jpg', ARRAY['Sci-Fi & Fantasy', 'Drama', 'Mystery']::TEXT[], 9.58),
(45, 'tv', 'Neon Genesis Evangelion', '2002-10-20', 'Gainax', 33, 60, NULL, TRUE, '/aqM6QnuhSXzjHlKbXyKUqxaGiWu.jpg', '/bJROfBstoARn6vOqqPylYLpGYDH.jpg', ARRAY['Reality', 'Talk']::TEXT[], 9.3),
(121, 'tv', 'Cowboy Bebop', '1963-11-23', 'Sunrise', 26, 25, NULL, TRUE, '/xinqAmYrZ1TEwowcQhgTkZVtVE0.jpg', '/8VWgyQjExeMgeg6Qzv6agduMU1A.jpg', ARRAY['Drama', 'Action & Adventure', 'Sci-Fi & Fantasy']::TEXT[], 9.45),
(65930, 'tv', 'My Hero Academia', '2016-04-03', 'Bones', 8, 24, NULL, TRUE, '/phuYuzqWW9ru8EA3HVjE9W2Rr3M.jpg', '/ol0H2DGp4ifBHA4JDlCpwJWxnY2.jpg', ARRAY['Action & Adventure', 'Animation', 'Sci-Fi & Fantasy']::TEXT[], 8.65),
(60625, 'tv', 'Mob Psycho 100', '2013-12-02', 'Bones', 10, NULL, NULL, TRUE, '/owhkU6KRqdXoUQpjV8uyZGPtX58.jpg', '/5BDNWWHweQL0q1fmTv7gmRXfnl4.jpg', ARRAY['Animation', 'Comedy', 'Sci-Fi & Fantasy', 'Action & Adventure']::TEXT[], 9.28),
(157336, 'movie', 'Interstellar', '2014-11-05', 'Paramount', NULL, 169, 'Christopher Nolan', FALSE, '/yQvGrMoipbRoddT0ZR8tPoR7NfX.jpg', '/8sNiAPPYU14PUepFNeSNGUTiHW.jpg', ARRAY['Adventure', 'Drama', 'Science Fiction']::TEXT[], 9.65),
(496243, 'movie', 'Parasite', '2019-05-30', 'Neon', NULL, 133, 'Bong Joon Ho', FALSE, '/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg', '/TU9NIjwzjoKPwQHoHshkFcQUCG.jpg', ARRAY['Comedy', 'Thriller', 'Drama']::TEXT[], 9.72),
(129, 'movie', 'Spirited Away', '2001-07-20', 'Studio Ghibli', NULL, 125, 'Hayao Miyazaki', FALSE, '/jUo8cNmU400WtZiJss45HNXlQ2e.jpg', '/dyJvKsNs2KP8qQnAXbRwDjblViy.jpg', ARRAY['Animation', 'Family', 'Fantasy']::TEXT[], 9.8),
(238, 'movie', 'The Godfather', '1972-03-14', 'Paramount', NULL, 175, 'Francis Ford Coppola', FALSE, '/3bhkrj58Vtu7enYsRolD1fZdja1.jpg', '/ejdD20cdHNFAYAN2DlqPToXKyzx.jpg', ARRAY['Drama', 'Crime']::TEXT[], 9.85),
(680, 'movie', 'Pulp Fiction', '1994-09-10', 'Miramax', NULL, 154, 'Quentin Tarantino', FALSE, '/vQWk5YBFWF4bZaofAbv0tShwBvQ.jpg', '/suaEOtk1N1sgg2MTM7oZd2cfVp3.jpg', ARRAY['Thriller', 'Crime', 'Comedy']::TEXT[], 9.58),
(693134, 'movie', 'Dune: Part Two', '2024-02-27', 'Warner Bros', NULL, 167, 'Denis Villeneuve', FALSE, '/6izwz7rsy95ARzTR3poZ8H6c5pp.jpg', '/eZ239CUp1d6OryZEBPnO2n87gMG.jpg', ARRAY['Science Fiction', 'Adventure']::TEXT[], 9.6),
(155, 'movie', 'The Dark Knight', '2008-07-16', 'Warner Bros', NULL, 152, 'Christopher Nolan', FALSE, '/qJ2tW6WMUDux911r6m7haRef0WH.jpg', '/9FE5eD92WfVCiivM9Pq9GVSrlWk.jpg', ARRAY['Action', 'Thriller', 'Crime']::TEXT[], 9.9),
(569094, 'movie', 'Spider-Man: Across the Spider-Verse', '2023-05-31', 'Sony Pictures', NULL, 140, 'Kemp Powers', FALSE, '/8Vt6mWEReuy4Of61Lnj5Xj704m8.jpg', '/kVd3a9YeLGkoeR50jGEXM6EqseS.jpg', ARRAY['Animation', 'Action', 'Adventure', 'Science Fiction']::TEXT[], 9.68),
(872585, 'movie', 'Oppenheimer', '2023-07-19', 'Universal', NULL, 181, 'Christopher Nolan', FALSE, '/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg', '/neeNHeXjMF5fXoCJRsOmkNGC7q.jpg', ARRAY['Drama', 'History']::TEXT[], 9.45),
(278, 'movie', 'The Shawshank Redemption', '1994-09-23', 'Columbia', NULL, 142, 'Frank Darabont', FALSE, '/9cqNxx0GxF0bflZmeSMuL5tnGzr.jpg', '/pNjh59JSxChQktamG3LMp9ZoQzp.jpg', ARRAY['Drama', 'Crime']::TEXT[], 9.88),
(550, 'movie', 'Fight Club', '1999-10-15', 'Fox 2000', NULL, 139, 'David Fincher', FALSE, '/jSziioSwPVrOy9Yow3XhWIBDjq1.jpg', '/c6OLXfKAk5BKeR6broC8pYiCquX.jpg', ARRAY['Drama', 'Thriller']::TEXT[], 9.32),
(13, 'movie', 'Forrest Gump', '1994-06-23', 'Paramount', NULL, 142, 'Robert Zemeckis', FALSE, '/Cw4hIUIAmSYfK9QfaUW5igp9La.jpg', '/66Kn4XWhkuPkJxOJyPEx4U2CUfN.jpg', ARRAY['Comedy', 'Drama', 'Romance']::TEXT[], 9.2),
(424, 'movie', 'Schindler''s List', '1993-12-15', 'Universal', NULL, 195, 'Steven Spielberg', FALSE, '/sF1U4EUQS8YHUYjNl3pMGNIQyr0.jpg', '/zb6fM1CX41D9rF9hdgclu0peUmy.jpg', ARRAY['Drama', 'History', 'War']::TEXT[], 9.78),
(19995, 'movie', 'Avatar', '2009-12-16', '20th Century Fox', NULL, 162, 'James Cameron', FALSE, '/gKY6q7SjCkAU6FqvqWybDYgUKIF.jpg', '/vL5LR6WdxWPjLPFRLe133jXWsh5.jpg', ARRAY['Science Fiction', 'Action', 'Adventure']::TEXT[], 8.85),
(27205, 'movie', 'Inception', '2010-07-15', 'Warner Bros', NULL, 148, 'Christopher Nolan', FALSE, '/xlaY2zyzMfkhk0HSC5VUwzoZPU1.jpg', '/8ZTVqvKDQ8emSGUEMjsS4yHAwrp.jpg', ARRAY['Action', 'Science Fiction', 'Adventure']::TEXT[], 9.55)
ON CONFLICT (id, media_type) DO NOTHING;

