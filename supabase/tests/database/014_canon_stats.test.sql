-- FE-PROFILE-03: get_canon_stats — per-canon hours, top genre and top director / network.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(9);

INSERT INTO auth.users (id, email) VALUES
    ('f1000000-0000-0000-0000-000000000001', 'stats@test.dev');

SET LOCAL ROLE authenticated;

SELECT throws_ok($$ SELECT public.get_canon_stats('movie') $$, '42501', NULL,
    'canon stats require an authenticated user');

SELECT set_config('request.jwt.claims', '{"sub":"f1000000-0000-0000-0000-000000000001","role":"authenticated"}', true);

SELECT is((public.get_canon_stats('movie') ->> 'total_titles')::INT, 0, 'an empty canon reports zero titles');

-- Interstellar (Nolan, 169), The Dark Knight (Nolan, 152), The Godfather (Coppola, 175),
-- Pulp Fiction (Tarantino, 154): 650 min; Crime is in 3 of 4.
SELECT public.insert_user_ranking_atomic(157336, 'movie', 1);
SELECT public.insert_user_ranking_atomic(155, 'movie', 2);
SELECT public.insert_user_ranking_atomic(238, 'movie', 3);
SELECT public.insert_user_ranking_atomic(680, 'movie', 4);
-- One series must not leak into the movie canon's stats.
SELECT public.insert_user_ranking_atomic(1396, 'tv', 1);

SELECT is((public.get_canon_stats('movie') ->> 'total_titles')::INT, 4, 'counts only the movie canon');
SELECT is((public.get_canon_stats('movie') ->> 'total_minutes')::INT, 650, 'sums movie runtimes');
SELECT is(public.get_canon_stats('movie') -> 'top_genre' ->> 'name', 'Crime', 'reports the most common genre');
SELECT is((public.get_canon_stats('movie') -> 'top_genre' ->> 'percent')::INT, 75, 'with its share of the canon');
SELECT is(public.get_canon_stats('movie') -> 'top_creator' ->> 'name', 'Christopher Nolan',
    'reports the most-ranked director');
SELECT is((public.get_canon_stats('movie') -> 'top_creator' ->> 'count')::INT, 2, 'with their title count');

SELECT is(public.get_canon_stats('tv') -> 'top_creator' ->> 'kind', 'network',
    'series report their top network instead of a director');

SELECT * FROM finish();
ROLLBACK;
