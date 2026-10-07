-- #136 (epic #50): medal catalogue, evaluation, pinning, seen state, rarity and the feed
-- (Spec 10 §4, §10).
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(29);

-- M earns most medals; T is M's taste twin; S has sharing off; R gets a medal through the
-- duel RPC. M, S and T signed in recently (rarity's active users).
INSERT INTO auth.users (id, email, last_sign_in_at) VALUES
    ('a7000000-0000-0000-0000-00000000000a', 'md-m@test.dev', NOW()),
    ('b7000000-0000-0000-0000-00000000000b', 'md-t@test.dev', NOW()),
    ('c7000000-0000-0000-0000-00000000000c', 'md-s@test.dev', NOW()),
    ('d7000000-0000-0000-0000-00000000000d', 'md-r@test.dev', NULL);
UPDATE public.users SET share_achievements = FALSE WHERE id = 'c7000000-0000-0000-0000-00000000000c';

-- Ten films with one genre each (8 distinct) across 5 decades.
INSERT INTO public.titles (id, media_type, title, release_date, genres)
SELECT 910000 + k, 'movie', 'Medal Film ' || k,
       make_date(CASE WHEN k <= 5 THEN 1940 + 10 * k ELSE 2000 END, 6, 1),
       ARRAY['Genre ' || LEAST(k, 8)]
FROM generate_series(1, 10) AS k;

-- M: the ten films, one a week from Monday 2026-01-05 (a 10-week best streak), each placed
-- through a duel, five of them upsets.
INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score, created_at)
SELECT 'a7000000-0000-0000-0000-00000000000a', 910000 + k, 'movie', k, 5.00,
       TIMESTAMPTZ '2026-01-05 12:00Z' + (k - 1) * INTERVAL '7 days'
FROM generate_series(1, 10) AS k;
INSERT INTO public.pairwise_duels (user_id, winner_title_id, loser_title_id, media_type, is_upset, placed_title_id)
SELECT 'a7000000-0000-0000-0000-00000000000a', 910000 + k, 910000 + CASE WHEN k = 1 THEN 2 ELSE 1 END,
       'movie', k <= 5, 910000 + k
FROM generate_series(1, 10) AS k;

-- Five shows in the Graveyard: the drop trigger evaluates M.
INSERT INTO public.user_dropped_shows (user_id, title_id, media_type, reason)
SELECT 'a7000000-0000-0000-0000-00000000000a', t, 'tv', 'PACING_SLOWED'
FROM unnest(ARRAY[76331, 110492, 1396, 124834, 1399]) AS t;

-- M and T follow each other with a 95% taste match: the follow and taste-match triggers run.
INSERT INTO public.social_follows (follower_id, following_id, status) VALUES
    ('a7000000-0000-0000-0000-00000000000a', 'b7000000-0000-0000-0000-00000000000b', 'accepted'),
    ('b7000000-0000-0000-0000-00000000000b', 'a7000000-0000-0000-0000-00000000000a', 'accepted');
INSERT INTO public.taste_matches (user_a, user_b, media_type, match_percentage, mutual_count)
VALUES ('a7000000-0000-0000-0000-00000000000a', 'b7000000-0000-0000-0000-00000000000b', 'movie', 95, 12);

-- S buries five shows with sharing off.
INSERT INTO public.user_dropped_shows (user_id, title_id, media_type, reason)
SELECT 'c7000000-0000-0000-0000-00000000000c', t, 'tv', 'TIME_COMMITMENT'
FROM unnest(ARRAY[76331, 110492, 1396, 124834, 1399]) AS t;

-- R: ten films, nine already placed; the tenth duel comes through the RPC below.
INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score, created_at)
SELECT 'd7000000-0000-0000-0000-00000000000d', 910000 + k, 'movie', k, 5.00, TIMESTAMPTZ '2026-09-01 12:00Z' + k * INTERVAL '1 hour'
FROM generate_series(1, 10) AS k;
INSERT INTO public.pairwise_duels (user_id, winner_title_id, loser_title_id, media_type, placed_title_id)
SELECT 'd7000000-0000-0000-0000-00000000000d', 910000 + k, 910001, 'movie', 910000 + k
FROM generate_series(2, 9) AS k;

-- ---------------------------------------------------------------- rules (as the definer)
SELECT results_eq(
    $$ SELECT achievement_id FROM public.user_achievements
       WHERE user_id = 'a7000000-0000-0000-0000-00000000000a' ORDER BY achievement_id $$,
    $$ VALUES ('decade_hopper'), ('genre_explorer'), ('graveyard_keeper'), ('movies_10'),
              ('streak_4'), ('taste_twin'), ('upset_artist') $$,
    'the triggers unlock milestone, taste and streak medals whose targets are met');
SELECT ok(
    NOT EXISTS (SELECT 1 FROM public.user_achievements
                WHERE user_id = 'a7000000-0000-0000-0000-00000000000a'
                  AND achievement_id IN ('tv_10', 'movies_50', 'streak_12', 'founding_viewer')),
    'unmet targets stay locked, and Founding Viewer waits for a launch date');
SELECT is(
    (SELECT count(*)::INT FROM public.activity_logs
     WHERE user_id = 'a7000000-0000-0000-0000-00000000000a' AND activity_type = 'MEDAL_UNLOCKED'),
    7, 'each unlock posts one MEDAL_UNLOCKED activity');
SELECT is(
    (SELECT metadata FROM public.activity_logs
     WHERE user_id = 'a7000000-0000-0000-0000-00000000000a' AND activity_type = 'MEDAL_UNLOCKED'
       AND metadata ->> 'achievement_id' = 'movies_10'),
    '{"achievement_id":"movies_10","name":"Ticket Stub","tier":"bronze","glyph":"10","kind":"milestone"}'::jsonb,
    'the activity carries the medal''s id, name, tier, glyph and kind');
SELECT is(public.evaluate_achievements('a7000000-0000-0000-0000-00000000000a'), 0,
    'evaluating again unlocks nothing new');
SELECT is(
    (SELECT count(*)::INT FROM public.activity_logs
     WHERE user_id = 'a7000000-0000-0000-0000-00000000000a' AND activity_type = 'MEDAL_UNLOCKED'),
    7, 'and posts nothing new');

SELECT ok(
    EXISTS (SELECT 1 FROM public.user_achievements
            WHERE user_id = 'c7000000-0000-0000-0000-00000000000c' AND achievement_id = 'graveyard_keeper'),
    'with sharing off, medals still unlock');
SELECT ok(
    NOT EXISTS (SELECT 1 FROM public.activity_logs
                WHERE user_id = 'c7000000-0000-0000-0000-00000000000c' AND activity_type = 'MEDAL_UNLOCKED'),
    'but nothing is posted to the feed');

-- ---------------------------------------------------------------- the duel RPC (as R)
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"d7000000-0000-0000-0000-00000000000d","role":"authenticated"}', true);

SELECT ok(
    NOT EXISTS (SELECT 1 FROM public.user_achievements
                WHERE user_id = 'd7000000-0000-0000-0000-00000000000d' AND achievement_id = 'movies_10'),
    'nine qualifying films are not enough');
SELECT public.record_pairwise_duels(
    '[{"client_mutation_id":"d7000000-0000-0000-0000-0000000000e1","winner_title_id":910010,"loser_title_id":910001,"media_type":"movie","placed_title_id":910010}]'::jsonb);
SELECT ok(
    EXISTS (SELECT 1 FROM public.user_achievements
            WHERE user_id = 'd7000000-0000-0000-0000-00000000000d' AND achievement_id = 'movies_10'),
    'record_pairwise_duels evaluates medals: the tenth placed film unlocks Ticket Stub');
SELECT throws_ok($$ SELECT public.evaluate_achievements('d7000000-0000-0000-0000-00000000000d') $$, '42501', NULL,
    'clients cannot run the evaluation directly');

-- ---------------------------------------------------------------- my_achievements (as M)
SELECT set_config('request.jwt.claims', '{"sub":"a7000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);

SELECT is((SELECT count(*)::INT FROM public.my_achievements()), 15, 'the whole active catalogue is listed');
SELECT results_eq(
    $$ SELECT id, progress, unlocked_at IS NOT NULL FROM public.my_achievements()
       WHERE id IN ('movies_10', 'movies_50', 'streak_12', 'taste_twin', 'founding_viewer') ORDER BY id $$,
    $$ VALUES ('founding_viewer', 0, FALSE), ('movies_10', 10, TRUE), ('movies_50', 10, FALSE),
              ('streak_12', 10, FALSE), ('taste_twin', 92, TRUE) $$,
    'progress counts towards each target (capped at it) with the unlock state');
SELECT is(
    (SELECT friends_count FROM public.my_achievements() WHERE id = 'movies_10'), 0,
    'no one I follow holds Ticket Stub yet');

-- ---------------------------------------------------------------- pinning (as M)
SELECT public.pin_achievement('movies_10', 1);
SELECT public.pin_achievement('upset_artist', 1);
SELECT results_eq(
    $$ SELECT achievement_id, pinned_slot FROM public.user_achievements
       WHERE user_id = auth.uid() AND pinned_slot IS NOT NULL $$,
    $$ VALUES ('upset_artist', 1::SMALLINT) $$,
    'pinning into a taken slot replaces its medal');
SELECT public.pin_achievement('movies_10', 2);
SELECT public.pin_achievement('upset_artist', 3);
SELECT results_eq(
    $$ SELECT achievement_id, pinned_slot FROM public.user_achievements
       WHERE user_id = auth.uid() AND pinned_slot IS NOT NULL ORDER BY pinned_slot $$,
    $$ VALUES ('movies_10', 2::SMALLINT), ('upset_artist', 3::SMALLINT) $$,
    'pinning a pinned medal moves it to the new slot');
SELECT throws_ok($$ SELECT public.pin_achievement('movies_50', 1) $$, '22023', NULL,
    'a locked medal cannot be pinned');
SELECT throws_ok($$ SELECT public.pin_achievement('movies_10', 4) $$, '22023', NULL,
    'there are only three slots');
SELECT public.unpin_achievement(3);
SELECT is(
    (SELECT count(*)::INT FROM public.user_achievements WHERE user_id = auth.uid() AND pinned_slot IS NOT NULL),
    1, 'unpin_achievement frees a slot');

-- ---------------------------------------------------------------- seen state (as M)
SELECT is(public.mark_achievements_seen(ARRAY['movies_10']), 1, 'marks the listed unlocks seen');
SELECT is(public.mark_achievements_seen(), 6, 'NULL marks every remaining unseen unlock');
SELECT is(public.mark_achievements_seen(), 0, 'and is a no-op once everything is seen');

-- ---------------------------------------------------------------- RLS and the feed
SELECT throws_ok(
    $$ INSERT INTO public.user_achievements (user_id, achievement_id) VALUES (auth.uid(), 'tv_100') $$,
    '42501', NULL, 'clients cannot grant themselves medals');
SELECT is(
    (SELECT count(*)::INT FROM public.activity_logs a
     JOIN public.get_activity_feed('global') f ON f.id = a.id
     WHERE a.activity_type = 'MEDAL_UNLOCKED'),
    0, 'the feed leaves medal posts out for apps that don''t ask for them');
SELECT is(
    (SELECT count(*)::INT FROM public.get_activity_feed('following', NULL, 100, NULL, TRUE)
     WHERE activity_type = 'MEDAL_UNLOCKED'),
    8, 'apps that ask get them: my seven, and Taste Twin from T, whom I follow');

SELECT set_config('request.jwt.claims', '{"sub":"b7000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);
SELECT is(
    (SELECT count(*)::INT FROM public.user_achievements WHERE user_id = 'a7000000-0000-0000-0000-00000000000a'),
    7, 'a follower can see a public profile''s medals');
SELECT results_eq(
    $$ SELECT friends_count, friends -> 0 ->> 'user_id' FROM public.my_achievements() WHERE id = 'movies_10' $$,
    $$ VALUES (1, 'a7000000-0000-0000-0000-00000000000a') $$,
    'the medal sheet lists followed holders');

-- ---------------------------------------------------------------- rarity
RESET ROLE;
SELECT public.refresh_achievement_rarity();
SELECT results_eq(
    $$ SELECT holders, active_users, percent FROM public.achievement_rarity WHERE achievement_id = 'movies_10' $$,
    $$ VALUES (1, 3, 33.33::NUMERIC) $$,
    'rarity counts holders among users who signed in during the last 90 days');

SET LOCAL ROLE authenticated;
SELECT results_eq(
    $$ SELECT rarity_percent, rarity_is_new FROM public.my_achievements() WHERE id = 'movies_10' $$,
    $$ VALUES (NULL::NUMERIC, TRUE) $$,
    'under 200 active users the medal reads as New');

SELECT * FROM finish();
ROLLBACK;
