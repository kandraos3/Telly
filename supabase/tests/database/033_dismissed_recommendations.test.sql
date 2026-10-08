-- #189: user_dismissed_recommendations and its use in get_explore_candidates (features/07 §7.5).
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(8);

INSERT INTO auth.users (id, email) VALUES
    ('e9000000-0000-0000-0000-000000000001', 'me@dismiss.dev'),
    ('e9000000-0000-0000-0000-000000000002', 'other@dismiss.dev');

-- Inception and Interstellar trend in movies; Severance trends in series.
INSERT INTO public.trending_titles (media_type, position, title_id) VALUES
    ('movie', 1, 27205), ('movie', 2, 157336), ('tv', 1, 110492);

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"e9000000-0000-0000-0000-000000000001","role":"authenticated"}', true);

SELECT ok(public.get_explore_candidates('movie') -> 'candidates' @> '[{"title_id": 27205}]'::jsonb,
    'a trending title is a candidate before it is dismissed');

INSERT INTO public.user_dismissed_recommendations (user_id, title_id, media_type)
VALUES ('e9000000-0000-0000-0000-000000000001', 27205, 'movie');

SELECT ok(NOT (public.get_explore_candidates('movie') -> 'candidates' @> '[{"title_id": 27205}]'::jsonb),
    'a dismissed title never comes back');
SELECT ok(public.get_explore_candidates('movie') -> 'candidates' @> '[{"title_id": 157336}]'::jsonb,
    'other titles still do');
SELECT ok(public.get_explore_candidates('tv') -> 'candidates' @> '[{"title_id": 110492}]'::jsonb,
    'the other canon is untouched');
SELECT is((SELECT count(*)::INT FROM public.user_muted_titles), 0,
    'dismissing is not a Spoiler Shield mute');

DELETE FROM public.user_dismissed_recommendations WHERE title_id = 27205;
SELECT ok(public.get_explore_candidates('movie') -> 'candidates' @> '[{"title_id": 27205}]'::jsonb,
    'Undo (deleting the row) brings it back');

-- RLS: only my own rows.
SELECT throws_ok($$ INSERT INTO public.user_dismissed_recommendations (user_id, title_id, media_type)
                    VALUES ('e9000000-0000-0000-0000-000000000002', 550, 'movie') $$,
    '42501', NULL, 'I cannot dismiss for someone else');

RESET ROLE;
INSERT INTO public.user_dismissed_recommendations (user_id, title_id, media_type)
VALUES ('e9000000-0000-0000-0000-000000000002', 550, 'movie');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"e9000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
SELECT is((SELECT count(*)::INT FROM public.user_dismissed_recommendations), 0,
    'I cannot see anyone else''s dismissals');

SELECT * FROM finish();
ROLLBACK;
