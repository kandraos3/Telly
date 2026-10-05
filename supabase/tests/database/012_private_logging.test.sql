-- FE-LOG-02: "Broadcast to Feed" opt-out on insert_user_ranking_atomic.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(5);

INSERT INTO auth.users (id, email) VALUES ('10000000-0000-0000-0000-000000000001', 'u@test.dev');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}', true);

SELECT public.insert_user_ranking_atomic(155, 'movie', 1);
SELECT public.insert_user_ranking_atomic(238, 'movie', 1, p_broadcast => FALSE);
SELECT public.insert_user_ranking_atomic(680, 'movie', 1);

RESET ROLE;

SELECT is(
    (SELECT count(*)::INT FROM public.user_rankings WHERE user_id = '10000000-0000-0000-0000-000000000001'),
    3, 'private logs are still ranked in the canon');
SELECT ok(
    EXISTS (SELECT 1 FROM public.activity_logs WHERE title_id = 155 AND activity_type = 'RANKING_CREATED'),
    'the default call broadcasts to the feed');
SELECT ok(
    NOT EXISTS (SELECT 1 FROM public.activity_logs WHERE title_id = 238 AND activity_type = 'RANKING_CREATED'),
    'p_broadcast => FALSE writes no RANKING_CREATED activity');
SELECT ok(
    EXISTS (SELECT 1 FROM public.activity_logs WHERE title_id = 680 AND activity_type = 'RANKING_CREATED'),
    'the opt-out does not leak into later inserts in the same transaction');
SELECT is(current_setting('telly.suppress_ranking_activity', true), 'off', 'the suppression flag is reset');

SELECT * FROM finish();
ROLLBACK;
