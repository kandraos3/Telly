-- FE-EXPLORE-03: get_recommended_titles / get_trending_titles.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(10);

INSERT INTO auth.users (id, email) VALUES
    ('f2000000-0000-0000-0000-000000000001', 'recs@test.dev'),
    ('f2000000-0000-0000-0000-000000000002', 'trend@test.dev');

SET LOCAL ROLE authenticated;

SELECT throws_ok($$ SELECT public.get_recommended_titles() $$, '42501', NULL,
    'recommendations require an authenticated user');
SELECT throws_ok($$ SELECT public.get_trending_titles() $$, '42501', NULL,
    'trending requires an authenticated user');

-- A second user ranks Fight Club, making it the only title trending this fortnight.
SELECT set_config('request.jwt.claims', '{"sub":"f2000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
SELECT public.insert_user_ranking_atomic(550, 'movie', 1);

SELECT set_config('request.jwt.claims', '{"sub":"f2000000-0000-0000-0000-000000000001","role":"authenticated"}', true);

SELECT is((public.get_trending_titles('movie', 5) -> 0 ->> 'title_id')::INT, 550,
    'trending leads with what the community ranked recently');

SELECT is(jsonb_array_length(public.get_recommended_titles('movie', 5)), 5,
    'an empty canon still gets a full carousel');
SELECT is(public.get_recommended_titles('movie', 5) -> 0 ->> 'reason_kind', 'trending',
    'with no loved titles the carousel falls back to trending');

-- Loving The Dark Knight (Nolan; Action, Thriller, Crime) should surface Nolan's Inception.
SELECT public.insert_user_ranking_atomic(155, 'movie', 1);
SELECT public.insert_user_ranking_atomic(238, 'movie', 2);

SELECT ok(NOT (public.get_recommended_titles('movie', 50) @> '[{"title_id": 155}]'::jsonb),
    'never recommends a title already in my canon');
SELECT is(public.get_recommended_titles('movie', 5) -> 0 ->> 'reason_kind', 'because_you_loved',
    'the top pick is explained by a loved title');
SELECT ok(public.get_recommended_titles('movie', 5) @> '[{"title_id": 27205, "reason_title": "The Dark Knight"}]'::jsonb,
    'a shared director and genres earn a "Because you loved" pick');

INSERT INTO public.user_watchlist (user_id, title_id, media_type)
VALUES ('f2000000-0000-0000-0000-000000000001', 27205, 'movie');
SELECT ok(NOT (public.get_recommended_titles('movie', 50) @> '[{"title_id": 27205}]'::jsonb),
    'never recommends a title already in my queue');

SELECT ok(NOT (public.get_recommended_titles('tv', 50) @> '[{"media_type": "movie"}]'::jsonb),
    'a series carousel never contains movies');

SELECT * FROM finish();
ROLLBACK;
