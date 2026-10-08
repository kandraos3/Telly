-- #148 (epic #50): custom canon header art, the level 30 reward (Spec 10 §5.2).
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(7);

-- F follows H; X is a stranger. Two God-tier films (one without a
-- backdrop) and one Great one.
INSERT INTO auth.users (id, email) VALUES
    ('a1000000-0000-0000-0000-00000000000a', 'ha-h@test.dev'),
    ('a2000000-0000-0000-0000-00000000000f', 'ha-f@test.dev'),
    ('a3000000-0000-0000-0000-00000000000e', 'ha-x@test.dev');
INSERT INTO public.social_follows (follower_id, following_id, status)
VALUES ('a2000000-0000-0000-0000-00000000000f', 'a1000000-0000-0000-0000-00000000000a', 'accepted');
INSERT INTO public.titles (id, media_type, title, backdrop_path) VALUES
    (980001, 'movie', 'Header God', '/god.jpg'),
    (980002, 'movie', 'Header No Still', NULL),
    (980003, 'movie', 'Header Great', '/great.jpg');
INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score) VALUES
    ('a1000000-0000-0000-0000-00000000000a', 980001, 'movie', 1, 9.60),
    ('a1000000-0000-0000-0000-00000000000a', 980002, 'movie', 2, 9.30),
    ('a1000000-0000-0000-0000-00000000000a', 980003, 'movie', 3, 8.00);

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"a1000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
SELECT throws_ok($$ SELECT public.set_header_art(980001, 'movie') $$, '22023', NULL,
    'header art stays locked below level 30');

RESET ROLE;
INSERT INTO public.xp_ledger (user_id, amount, source, ref, week)
VALUES ('a1000000-0000-0000-0000-00000000000a', 108750, 'correction', 'test boost', '2026-W40');
SET LOCAL ROLE authenticated;

SELECT throws_ok($$ SELECT public.set_header_art(980003, 'movie') $$, '22023', NULL,
    'only a God-tier title can be the header');
SELECT throws_ok($$ SELECT public.set_header_art(980002, 'movie') $$, '22023', NULL,
    'a title without a still cannot be the header');
SELECT lives_ok($$ SELECT public.set_header_art(980001, 'movie') $$, 'at level 30 a God-tier still can be chosen');
SELECT results_eq(
    $$ SELECT id, equipped FROM public.my_rewards() WHERE kind = 'header_art' $$,
    $$ VALUES ('canon_header_art', TRUE) $$,
    'the reward reads as equipped');

SELECT set_config('request.jwt.claims', '{"sub":"a2000000-0000-0000-0000-00000000000f","role":"authenticated"}', true);
SELECT results_eq(
    $$ SELECT title_id, backdrop_path FROM public.header_art('a1000000-0000-0000-0000-00000000000a') $$,
    $$ VALUES (980001, '/god.jpg'::TEXT) $$,
    'a follower sees the header art');

SELECT set_config('request.jwt.claims', '{"sub":"a3000000-0000-0000-0000-00000000000e","role":"authenticated"}', true);
RESET ROLE;
UPDATE public.users SET visibility_mode = 'FRIENDS_ONLY' WHERE id = 'a1000000-0000-0000-0000-00000000000a';
SET LOCAL ROLE authenticated;
SELECT is_empty($$ SELECT * FROM public.header_art('a1000000-0000-0000-0000-00000000000a') $$,
    'someone who cannot see a friends-only profile gets nothing');

SELECT * FROM finish();
ROLLBACK;
