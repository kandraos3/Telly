-- BE-603: ranking RPCs — contiguity (I-3), dual canon (I-1), auth.uid() (I-4), idempotency (I-5), upsets.
-- Contract: docs/technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md §3.1–§3.3
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(25);

INSERT INTO auth.users (id, email) VALUES
    ('10000000-0000-0000-0000-000000000001', 'u@test.dev'),
    ('20000000-0000-0000-0000-000000000002', 'x@test.dev'),
    ('30000000-0000-0000-0000-000000000003', 'y@test.dev');

-- Canon contiguity helper (as postgres): TRUE when ranks are exactly 1..N.
CREATE FUNCTION pg_temp.is_contiguous(p_user UUID, p_media public.media_type_enum) RETURNS BOOLEAN
LANGUAGE sql AS $$
    SELECT COALESCE(bool_and(rank_position = rn), TRUE)
    FROM (
        SELECT rank_position, row_number() OVER (ORDER BY rank_position) AS rn
        FROM public.user_rankings WHERE user_id = p_user AND media_type = p_media
    ) r;
$$;
CREATE FUNCTION pg_temp.canon(p_user UUID, p_media public.media_type_enum) RETURNS INT[]
LANGUAGE sql AS $$
    SELECT array_agg(title_id ORDER BY rank_position)
    FROM public.user_rankings WHERE user_id = p_user AND media_type = p_media;
$$;
GRANT EXECUTE ON FUNCTION pg_temp.is_contiguous(UUID, public.media_type_enum) TO authenticated;
GRANT EXECUTE ON FUNCTION pg_temp.canon(UUID, public.media_type_enum) TO authenticated;

-- Unauthenticated --------------------------------------------------------------
SET LOCAL ROLE authenticated;
SELECT throws_ok(
    $$ SELECT public.insert_user_ranking_atomic(155, 'movie', 1) $$,
    '42501', NULL, 'RPCs require an authenticated user (I-4)');

-- Act as U ------------------------------------------------------------------------
SELECT set_config('request.jwt.claims', '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}', true);

SELECT is((public.insert_user_ranking_atomic(155, 'movie', 1)).rating_uncertainty, 0.50::NUMERIC(3,2),
    'first title in a canon gets sigma 0.50 (features/02 §7.3)');
SELECT is((public.insert_user_ranking_atomic(238, 'movie', 1)).rating_uncertainty, 1.20::NUMERIC(3,2),
    'later titles start provisional at sigma 1.20');
SELECT public.insert_user_ranking_atomic(680, 'movie', 2);
SELECT public.insert_user_ranking_atomic(129, 'movie', 99);   -- clamps to N+1
SELECT public.insert_user_ranking_atomic(278, 'movie', -5);   -- clamps to 1

SELECT is(pg_temp.canon('10000000-0000-0000-0000-000000000001', 'movie'), ARRAY[278, 238, 680, 155, 129],
    'inserts shift rows below the target; out-of-range targets clamp');
SELECT ok(pg_temp.is_contiguous('10000000-0000-0000-0000-000000000001', 'movie'), 'movie canon is contiguous after inserts');
SELECT is_empty(
    $$ SELECT 1 FROM public.user_rankings ur
       WHERE ur.user_id = '10000000-0000-0000-0000-000000000001' AND ur.media_type = 'movie'
         AND ur.calculated_score <> public.canon_score(ur.rank_position, 5) $$,
    'every score in the canon is recomputed with the shared curve');

-- Dual canon isolation (I-1)
SELECT public.insert_user_ranking_atomic(1396, 'tv', 1);
SELECT is(pg_temp.canon('10000000-0000-0000-0000-000000000001', 'movie'), ARRAY[278, 238, 680, 155, 129],
    'a tv insert never shifts the movie canon');
SELECT is((SELECT calculated_score FROM public.user_rankings
           WHERE user_id = '10000000-0000-0000-0000-000000000001' AND title_id = 1396),
    10.00::NUMERIC(4,2), 'tv canon is scored independently (N=1 → 10.00)');

-- Re-rank through insert (BE-201 corrupt path)
SELECT public.insert_user_ranking_atomic(129, 'movie', 2, p_review => 'grew on me');
SELECT is(pg_temp.canon('10000000-0000-0000-0000-000000000001', 'movie'), ARRAY[278, 129, 238, 680, 155],
    're-inserting a ranked title moves it instead of duplicating');
SELECT ok(pg_temp.is_contiguous('10000000-0000-0000-0000-000000000001', 'movie'), 'still contiguous after re-rank');
SELECT is((SELECT review_short FROM public.user_rankings
           WHERE user_id = '10000000-0000-0000-0000-000000000001' AND title_id = 129),
    'grew on me', 're-rank updates editorial fields');

-- move_user_ranking
SELECT public.move_user_ranking(278, 'movie', 5);
SELECT is(pg_temp.canon('10000000-0000-0000-0000-000000000001', 'movie'), ARRAY[129, 238, 680, 155, 278], 'move down');
SELECT public.move_user_ranking(155, 'movie', 1);
SELECT is(pg_temp.canon('10000000-0000-0000-0000-000000000001', 'movie'), ARRAY[155, 129, 238, 680, 278], 'move up');
SELECT throws_ok($$ SELECT public.move_user_ranking(424, 'movie', 1) $$, 'P0002', NULL, 'moving an unranked title fails');

-- delete_user_ranking
SELECT ok(public.delete_user_ranking(238, 'movie'), 'delete returns TRUE');
SELECT is(pg_temp.canon('10000000-0000-0000-0000-000000000001', 'movie'), ARRAY[155, 129, 680, 278], 'delete closes the gap');
SELECT is((SELECT calculated_score FROM public.user_rankings
           WHERE user_id = '10000000-0000-0000-0000-000000000001' AND title_id = 278),
    public.canon_score(4, 4), 'scores are recomputed after delete');

-- Idempotent replay (I-5)
SELECT public.insert_user_ranking_atomic(424, 'movie', 1, p_client_mutation_id => 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
SELECT public.move_user_ranking(424, 'movie', 5, p_client_mutation_id => 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
SELECT public.insert_user_ranking_atomic(424, 'movie', 1, p_client_mutation_id => 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
SELECT is((SELECT rank_position FROM public.user_rankings
           WHERE user_id = '10000000-0000-0000-0000-000000000001' AND title_id = 424),
    5, 'replaying an already-applied insert does not undo a later move');

-- Duels
SELECT is(public.record_pairwise_duels(
    '[{"client_mutation_id":"cccccccc-cccc-cccc-cccc-cccccccccccc","winner_title_id":155,"loser_title_id":129,"media_type":"movie","decision_time_ms":900}]'::jsonb),
    1, 'duel batch inserted');
SELECT is(public.record_pairwise_duels(
    '[{"client_mutation_id":"cccccccc-cccc-cccc-cccc-cccccccccccc","winner_title_id":155,"loser_title_id":129,"media_type":"movie"}]'::jsonb),
    0, 'replayed duel is a no-op');
SELECT throws_ok(
    $$ SELECT public.record_pairwise_duels('[{"winner_title_id":155,"loser_title_id":1396,"media_type":"movie"}]'::jsonb) $$,
    '23503', NULL, 'a movie can never duel a tv title (composite FK)');

-- Act as X: a mutation id owned by U cannot be hijacked; U's canon is untouched by X's calls
SELECT set_config('request.jwt.claims', '{"sub":"20000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
SELECT throws_ok(
    $$ SELECT public.insert_user_ranking_atomic(155, 'movie', 1, p_client_mutation_id => 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') $$,
    '42501', NULL, 'cannot replay another user''s mutation id');

-- Upset: X and Y both love 155 (#1) and rank 129 last; U's 129-over-155 pick is an upset.
SELECT public.insert_user_ranking_atomic(155, 'movie', 1);
SELECT public.insert_user_ranking_atomic(680, 'movie', 2);
SELECT public.insert_user_ranking_atomic(129, 'movie', 3);
SELECT set_config('request.jwt.claims', '{"sub":"30000000-0000-0000-0000-000000000003","role":"authenticated"}', true);
SELECT public.insert_user_ranking_atomic(155, 'movie', 1);
SELECT public.insert_user_ranking_atomic(129, 'movie', 2);

SELECT set_config('request.jwt.claims', '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
SELECT is((SELECT d.is_upset FROM public.detect_upset_duel(129, 155, 'movie') d), TRUE,
    'picking the consensus-bottom title over the consensus-top title is an upset (features/04 §3.2)');
SELECT public.record_pairwise_duels(
    '[{"client_mutation_id":"dddddddd-dddd-dddd-dddd-dddddddddddd","winner_title_id":129,"loser_title_id":155,"media_type":"movie"}]'::jsonb);

RESET ROLE;
SELECT is((SELECT count(*)::INT FROM public.activity_logs
           WHERE user_id = '10000000-0000-0000-0000-000000000001' AND activity_type = 'UPSET_ALERT' AND title_id = 129),
    1, 'an upset duel emits an UPSET_ALERT activity');
SELECT ok(pg_temp.is_contiguous('20000000-0000-0000-0000-000000000002', 'movie')
          AND pg_temp.is_contiguous('10000000-0000-0000-0000-000000000001', 'movie'),
    'all canons remain contiguous');

SELECT * FROM finish();
ROLLBACK;
