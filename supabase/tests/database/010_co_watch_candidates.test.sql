-- FE-610: get_co_watch_candidates candidate pool (Spec 05 §3.1, §5.1)
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(8);

-- Seed users
INSERT INTO auth.users (id, email) VALUES
    ('a4000000-0000-0000-0000-00000000000a', 'cowatch-a@test.dev'),
    ('b4000000-0000-0000-0000-00000000000b', 'cowatch-b@test.dev');
UPDATE public.users SET username = 'cowatch_a', display_name = 'Alex' WHERE id = 'a4000000-0000-0000-0000-00000000000a';
UPDATE public.users SET username = 'cowatch_b', display_name = 'Bailey' WHERE id = 'b4000000-0000-0000-0000-00000000000b';

-- Seed titles (movies and tv)
INSERT INTO public.titles (id, media_type, title, runtime_minutes, global_community_score, genres) VALUES
    (501, 'movie', 'Mutual Movie', 120, 8.5, ARRAY['Sci-Fi', 'Action']),
    (502, 'movie', 'Alex Watchlist Movie', 95, 7.8, ARRAY['Comedy']),
    (503, 'movie', 'Bailey Watchlist Movie', 110, 8.1, ARRAY['Drama']),
    (504, 'movie', 'Alex God-Tier Movie', 140, 9.5, ARRAY['Thriller']),
    (505, 'movie', 'Alex Mid Movie', 100, 6.5, ARRAY['Action']),
    (506, 'tv', 'Mutual TV Show', 45, 8.8, ARRAY['Drama']);

-- Seed streaming platform and availability for title 501
INSERT INTO public.streaming_platforms (id, display_name, logo_url) VALUES
    ('netflix', 'Netflix', 'https://logos.dev/netflix.png')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.title_availability (title_id, media_type, platform_id, country_code, monetization_type) VALUES
    (501, 'movie', 'netflix', 'US', 'flatrate')
ON CONFLICT DO NOTHING;

-- Seed watchlists
-- 501: mutual movie
INSERT INTO public.user_watchlist (user_id, title_id, media_type) VALUES
    ('a4000000-0000-0000-0000-00000000000a', 501, 'movie'),
    ('b4000000-0000-0000-0000-00000000000b', 501, 'movie');
-- 502: in Alex watchlist only
INSERT INTO public.user_watchlist (user_id, title_id, media_type) VALUES
    ('a4000000-0000-0000-0000-00000000000a', 502, 'movie');
-- 503: in Bailey watchlist only
INSERT INTO public.user_watchlist (user_id, title_id, media_type) VALUES
    ('b4000000-0000-0000-0000-00000000000b', 503, 'movie');
-- 506: mutual TV show
INSERT INTO public.user_watchlist (user_id, title_id, media_type) VALUES
    ('a4000000-0000-0000-0000-00000000000a', 506, 'tv'),
    ('b4000000-0000-0000-0000-00000000000b', 506, 'tv');

-- Seed rankings
-- 504: Alex rated 9.40 (High-rated not seen by Bailey)
INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score) VALUES
    ('a4000000-0000-0000-0000-00000000000a', 504, 'movie', 1, 9.40);
-- 505: Alex rated 6.50 (Mid movie, not >= 8.50, not on watchlist -> should NOT appear)
INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score) VALUES
    ('a4000000-0000-0000-0000-00000000000a', 505, 'movie', 2, 6.50);

-- Verify unauthenticated call throws
SELECT throws_ok(
    $$ SELECT * FROM public.get_co_watch_candidates('b4000000-0000-0000-0000-00000000000b', 'movie') $$,
    'P0001', 'Not authenticated', 'unauthenticated call throws'
);

-- Set authenticated session for Alex
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"a4000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);

-- Call get_co_watch_candidates for movies
SELECT is(
    (SELECT count(*)::INT FROM public.get_co_watch_candidates('b4000000-0000-0000-0000-00000000000b', 'movie')),
    4,
    'candidate pool returns exactly 4 movies: 501 (mutual), 502 (Alex), 503 (Bailey), 504 (Alex high-rated)'
);

-- Dual-Canon check: TV shows are not returned when media_type = 'movie'
SELECT is(
    (SELECT count(*)::INT FROM public.get_co_watch_candidates('b4000000-0000-0000-0000-00000000000b', 'movie') WHERE show_id = 506),
    0,
    'tv shows are segregated and not returned in movie canon'
);

-- Mutual watchlist candidate check
SELECT results_eq(
    $$ SELECT show_id, in_watchlist_a, in_watchlist_b, available_providers
       FROM public.get_co_watch_candidates('b4000000-0000-0000-0000-00000000000b', 'movie')
       WHERE show_id = 501 $$,
    $$ VALUES (501, true, true, ARRAY['netflix']::TEXT[]) $$,
    '501 has both watchlists true and netflix in available providers'
);

-- Alex single watchlist candidate check
SELECT results_eq(
    $$ SELECT show_id, in_watchlist_a, in_watchlist_b
       FROM public.get_co_watch_candidates('b4000000-0000-0000-0000-00000000000b', 'movie')
       WHERE show_id = 502 $$,
    $$ VALUES (502, true, false) $$,
    '502 has in_watchlist_a true, in_watchlist_b false'
);

-- Bailey single watchlist candidate check
SELECT results_eq(
    $$ SELECT show_id, in_watchlist_a, in_watchlist_b
       FROM public.get_co_watch_candidates('b4000000-0000-0000-0000-00000000000b', 'movie')
       WHERE show_id = 503 $$,
    $$ VALUES (503, false, true) $$,
    '503 has in_watchlist_a false, in_watchlist_b true'
);

-- High-rated candidate check
SELECT results_eq(
    $$ SELECT show_id, rating_a, rating_b
       FROM public.get_co_watch_candidates('b4000000-0000-0000-0000-00000000000b', 'movie')
       WHERE show_id = 504 $$,
    $$ VALUES (504, 9.40::NUMERIC, NULL::NUMERIC) $$,
    '504 returns Alex rating 9.40 and NULL for Bailey'
);

-- Mid movie (505) excluded check
SELECT is(
    (SELECT count(*)::INT FROM public.get_co_watch_candidates('b4000000-0000-0000-0000-00000000000b', 'movie') WHERE show_id = 505),
    0,
    '505 (< 8.50 and not on watchlist) is excluded'
);

SELECT * FROM finish();
ROLLBACK;
