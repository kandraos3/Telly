-- #144 (epic #50): challenge context on feed rankings, and challenge medals in my_achievements.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(5);

INSERT INTO auth.users (id, email) VALUES ('ab000000-0000-0000-0000-00000000000a', 'cfc-a@test.dev');
INSERT INTO public.titles (id, media_type, title, release_date, genres) VALUES
    (960001, 'movie', 'Fright One', '1980-01-01', ARRAY['Horror']),
    (960002, 'movie', 'Fright Two', '1981-01-01', ARRAY['Horror']),
    (960003, 'movie', 'Laugh One',  '1982-01-01', ARRAY['Comedy']);
INSERT INTO public.challenges (slug, name, starts_at, ends_at, rule, target, status)
VALUES ('fright-fest', 'Fright Fest', NOW() - INTERVAL '10 days', NOW() + INTERVAL '10 days',
        '{"media_type":"movie","filters":[{"type":"genre","any":["Horror"]}]}', 2, 'live');
INSERT INTO public.challenge_participants (challenge_id, user_id)
SELECT id, 'ab000000-0000-0000-0000-00000000000a' FROM public.challenges WHERE slug = 'fright-fest';

-- Two horror films inside the window (the second completes it) and a comedy.
INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score, created_at) VALUES
    ('ab000000-0000-0000-0000-00000000000a', 960001, 'movie', 1, 9.00, NOW() - INTERVAL '3 days'),
    ('ab000000-0000-0000-0000-00000000000a', 960002, 'movie', 2, 8.00, NOW() - INTERVAL '2 days'),
    ('ab000000-0000-0000-0000-00000000000a', 960003, 'movie', 3, 7.00, NOW() - INTERVAL '1 day');
INSERT INTO public.pairwise_duels (user_id, winner_title_id, loser_title_id, media_type, placed_title_id)
SELECT 'ab000000-0000-0000-0000-00000000000a', t, 960003, 'movie', t FROM unnest(ARRAY[960001, 960002]) t;
SELECT public.evaluate_achievements('ab000000-0000-0000-0000-00000000000a');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"ab000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);

SELECT results_eq(
    $$ SELECT title_id, challenge_context ->> 'name', (challenge_context ->> 'count')::INT, (challenge_context ->> 'target')::INT
       FROM public.get_activity_feed('following', NULL, 50)
       WHERE activity_type = 'RANKING_CREATED' AND title_id IN (960001, 960002) ORDER BY title_id $$,
    $$ VALUES (960001, 'Fright Fest', 1, 2), (960002, 'Fright Fest', 2, 2) $$,
    'rankings inside a joined challenge carry its name and the count as of that ranking');
SELECT is(
    (SELECT challenge_context FROM public.get_activity_feed('following', NULL, 50)
     WHERE activity_type = 'RANKING_CREATED' AND title_id = 960003),
    NULL, 'a ranking that does not match the rule has no context');
SELECT is(
    (SELECT challenge_context FROM public.get_activity_feed('following', NULL, 50)
     WHERE activity_type = 'CHALLENGE_COMPLETED'),
    NULL, 'other rows have no context');

SELECT results_eq(
    $$ SELECT id, kind::TEXT, unlocked_at IS NOT NULL FROM public.my_achievements() WHERE kind = 'challenge' $$,
    $$ VALUES ('challenge_fright_fest', 'challenge', TRUE) $$,
    'a finished challenge''s medal is listed among my medals');
SELECT lives_ok($$ SELECT public.pin_achievement('challenge_fright_fest', 1) $$, 'and can be pinned');

SELECT * FROM finish();
ROLLBACK;
