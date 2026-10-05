-- FE-DETAIL-02: get_title_duel_stats — live duel record and tier distribution for SCR-08.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(7);

INSERT INTO auth.users (id, email) VALUES
    ('e1000000-0000-0000-0000-000000000001', 'a@test.dev'),
    ('e2000000-0000-0000-0000-000000000002', 'b@test.dev');

SET LOCAL ROLE authenticated;

SELECT throws_ok($$ SELECT public.get_title_duel_stats(1396, 'tv') $$, '42501', NULL,
    'duel stats require an authenticated user');

-- A: Breaking Bad > Succession twice, loses once to The Wire. Ranks BB #1 of 3.
SELECT set_config('request.jwt.claims', '{"sub":"e1000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
SELECT public.insert_user_ranking_atomic(1396, 'tv', 1);
SELECT public.insert_user_ranking_atomic(76331, 'tv', 2);
SELECT public.insert_user_ranking_atomic(8592, 'tv', 1);
SELECT public.record_pairwise_duels(jsonb_build_array(
    jsonb_build_object('client_mutation_id', gen_random_uuid(), 'winner_title_id', 1396, 'loser_title_id', 76331, 'media_type', 'tv'),
    jsonb_build_object('client_mutation_id', gen_random_uuid(), 'winner_title_id', 1396, 'loser_title_id', 76331, 'media_type', 'tv'),
    jsonb_build_object('client_mutation_id', gen_random_uuid(), 'winner_title_id', 8592, 'loser_title_id', 1396, 'media_type', 'tv')));

SELECT is((public.get_title_duel_stats(1396, 'tv') ->> 'total_duels')::INT, 3, 'counts every duel the title fought');
SELECT is((public.get_title_duel_stats(1396, 'tv') ->> 'wins')::INT, 2, 'counts wins');
SELECT is(public.get_title_duel_stats(1396, 'tv') -> 'top_defeated' ->> 'title', 'Succession',
    'reports the most-defeated opponent');
SELECT is((public.get_title_duel_stats(1396, 'tv') -> 'top_defeated' ->> 'count')::INT, 2, 'with its head-to-head count');

-- Tier distribution: A ranks BB 2nd of 3 (score below God), B ranks it 1st (10.00 → God).
SELECT set_config('request.jwt.claims', '{"sub":"e2000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
SELECT public.insert_user_ranking_atomic(1396, 'tv', 1);
SELECT is((public.get_title_duel_stats(1396, 'tv') -> 'tiers' ->> 'total')::INT, 2, 'tier totals count every ranker');

SELECT is((public.get_title_duel_stats(66732, 'tv') ->> 'total_duels')::INT, 0,
    'an unduelled title reports zero rather than a placeholder');

SELECT * FROM finish();
ROLLBACK;
