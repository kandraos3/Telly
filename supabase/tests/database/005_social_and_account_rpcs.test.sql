-- BE-604: taste match (per canon), feed, squad canon, account deletion, moderation.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(21);

INSERT INTO auth.users (id, email) VALUES
    ('a0000000-0000-0000-0000-00000000000a', 'a@test.dev'),
    ('b0000000-0000-0000-0000-00000000000b', 'b@test.dev'),
    ('c0000000-0000-0000-0000-00000000000c', 'c@test.dev');
UPDATE public.users SET username = 'user_a' WHERE id = 'a0000000-0000-0000-0000-00000000000a';
UPDATE public.users SET username = 'user_b' WHERE id = 'b0000000-0000-0000-0000-00000000000b';

SET LOCAL ROLE authenticated;

-- A: movies 155 > 238 > 680 > 129 ; tv 1396
SELECT set_config('request.jwt.claims', '{"sub":"a0000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
SELECT public.insert_user_ranking_atomic(155, 'movie', 1);
SELECT public.insert_user_ranking_atomic(238, 'movie', 2);
SELECT public.insert_user_ranking_atomic(680, 'movie', 3);
SELECT public.insert_user_ranking_atomic(129, 'movie', 4);
SELECT public.insert_user_ranking_atomic(1396, 'tv', 1);

-- B: same movie order but with extra titles interleaved (raw positions differ, relative order identical);
--    B also ranks 1396 as tv. Cross-canon overlap must never count.
SELECT set_config('request.jwt.claims', '{"sub":"b0000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);
SELECT public.insert_user_ranking_atomic(424, 'movie', 1);
SELECT public.insert_user_ranking_atomic(155, 'movie', 2);
SELECT public.insert_user_ranking_atomic(278, 'movie', 3);
SELECT public.insert_user_ranking_atomic(238, 'movie', 4);
SELECT public.insert_user_ranking_atomic(680, 'movie', 5);
SELECT public.insert_user_ranking_atomic(13, 'movie', 6);
SELECT public.insert_user_ranking_atomic(129, 'movie', 7);
SELECT public.insert_user_ranking_atomic(1396, 'tv', 1);

-- Taste match ---------------------------------------------------------------------
SELECT set_config('request.jwt.claims', '{"sub":"a0000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
SELECT results_eq(
    $$ SELECT match_pct, mutual_count FROM public.calculate_taste_match_rpc('b0000000-0000-0000-0000-00000000000b', 'movie') $$,
    $$ VALUES (72, 4) $$,
    'identical relative order over 4 mutual movies: rho=1 re-ranked, w=4/9 → 72%');
SELECT results_eq(
    $$ SELECT match_pct, mutual_count FROM public.calculate_taste_match_rpc('b0000000-0000-0000-0000-00000000000b', 'tv') $$,
    $$ VALUES (50, 1) $$,
    'tv canon is computed separately (k<2 → neutral 50)');
SELECT is((SELECT count(*)::INT FROM public.taste_matches), 2, 'taste match cached per canon');

-- Feed --------------------------------------------------------------------------------
SELECT is((SELECT count(*)::INT FROM public.get_activity_feed('following')
           WHERE user_id = 'b0000000-0000-0000-0000-00000000000b'), 0,
    'following feed excludes users I do not follow');
INSERT INTO public.social_follows (follower_id, following_id)
    VALUES ('a0000000-0000-0000-0000-00000000000a', 'b0000000-0000-0000-0000-00000000000b');
SELECT is((SELECT count(*)::INT FROM public.get_activity_feed('following', NULL, 100)
           WHERE user_id = 'b0000000-0000-0000-0000-00000000000b' AND activity_type = 'RANKING_CREATED'), 8,
    'ranking inserts emit RANKING_CREATED activity visible to accepted followers');
SELECT is((SELECT rank_position FROM public.get_activity_feed('following', NULL, 100)
           WHERE user_id = 'b0000000-0000-0000-0000-00000000000b' AND title_id = 155),
    2, 'feed shows the current rank (joined live), not a stale snapshot');
SELECT is((SELECT count(*)::INT FROM public.get_activity_feed('following', NULL, 3)), 3, 'limit is respected');
CREATE TEMP TABLE page1 AS SELECT * FROM public.get_activity_feed('global', NULL, 5);
SELECT is(
    (SELECT count(*)::INT FROM (
        SELECT id FROM page1
        UNION ALL
        SELECT f.id FROM public.get_activity_feed('global',
            (SELECT created_at FROM page1 ORDER BY created_at, id LIMIT 1), 100,
            (SELECT id FROM page1 ORDER BY created_at, id LIMIT 1)) f
     ) all_pages),
    (SELECT count(*)::INT FROM public.get_activity_feed('global', NULL, 100)),
    'keyset pagination on (created_at, id) returns every row exactly once');
SELECT throws_ok($$ SELECT * FROM public.get_activity_feed('bogus') $$, '22023', NULL, 'unknown filter rejected');

INSERT INTO public.user_muted_titles (user_id, title_id, media_type)
    VALUES ('a0000000-0000-0000-0000-00000000000a', 155, 'movie');
SELECT is((SELECT count(*)::INT FROM public.get_activity_feed('global', NULL, 100) WHERE title_id = 155 AND media_type = 'movie'),
    0, 'muted titles never appear in the feed (spoiler shield)');

-- Squad canon (Borda) ----------------------------------------------------------------------
INSERT INTO public.squads (id, name, created_by)
    VALUES ('5a000000-0000-0000-0000-000000000001', 'Couch Crew', 'a0000000-0000-0000-0000-00000000000a');
INSERT INTO public.squad_members (squad_id, user_id)
    VALUES ('5a000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-00000000000b');
-- A: 155=4pts, 238=3, 680=2, 129=1 ; B (N=7): 424=7, 155=6, 278=5, 238=4, 680=3, 13=2, 129=1
SELECT results_eq(
    $$ SELECT title_id, total_borda_points FROM public.calculate_squad_canon('5a000000-0000-0000-0000-000000000001', 'movie')
       WHERE consensus_rank <= 3 ORDER BY consensus_rank $$,
    $$ VALUES (155, 10::BIGINT), (238, 7::BIGINT), (424, 7::BIGINT) $$,
    'Borda points N_i - r + 1; ties broken by member count then mean rank');

SELECT set_config('request.jwt.claims', '{"sub":"c0000000-0000-0000-0000-00000000000c","role":"authenticated"}', true);
SELECT throws_ok($$ SELECT * FROM public.calculate_squad_canon('5a000000-0000-0000-0000-000000000001', 'movie') $$,
    '42501', NULL, 'non-members cannot read a squad canon');

-- Moderation -------------------------------------------------------------------------------
SELECT isnt(public.submit_report('USER', 'a0000000-0000-0000-0000-00000000000a', 'SPAM', 'bot'), NULL,
    'submit_report returns the report id');
SELECT public.block_user('a0000000-0000-0000-0000-00000000000a');
SELECT is((SELECT count(*)::INT FROM public.get_activity_feed('global', NULL, 100)
           WHERE user_id = 'a0000000-0000-0000-0000-00000000000a'), 0, 'blocked users disappear from my feed');
SELECT throws_ok($$ SELECT public.block_user('c0000000-0000-0000-0000-00000000000c') $$, '22023', NULL, 'cannot block yourself');

-- Account deletion ----------------------------------------------------------------------
SELECT set_config('request.jwt.claims', '{"sub":"b0000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);
SELECT ok(public.request_account_deletion() > NOW() + INTERVAL '29 days', 'deletion scheduled 30 days out');

SELECT set_config('request.jwt.claims', '{"sub":"a0000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
SELECT is((SELECT count(*)::INT FROM public.users WHERE id = 'b0000000-0000-0000-0000-00000000000b'), 0,
    'a profile pending deletion is immediately invisible');

SELECT throws_ok($$ SELECT public.purge_deleted_accounts() $$, '42501', NULL, 'clients cannot run the purge');

RESET ROLE;
SELECT is(public.purge_deleted_accounts(NOW() + INTERVAL '29 days'), 0, 'nothing purged inside the grace period');
SELECT is(public.purge_deleted_accounts(NOW() + INTERVAL '31 days'), 1, 'purged after 30 days');
SELECT is((SELECT count(*)::INT FROM public.user_rankings WHERE user_id = 'b0000000-0000-0000-0000-00000000000b'), 0,
    'purge cascades to all user data');

SELECT * FROM finish();
ROLLBACK;
