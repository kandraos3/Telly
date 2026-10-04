-- QA-607: Direct SQL Parity Suite on Shared Fixtures
-- Verifies public.calculate_taste_match_rpc, public.calculate_squad_canon, and public.canon_score
-- match the shared fixtures in test/fixtures/*.json
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(7);

-- 1. Setup authenticated test users for taste match and squad fixtures
INSERT INTO auth.users (id, email)
VALUES
    ('a0000000-0000-0000-0000-00000000000a', 'member-a@test.dev'),
    ('b0000000-0000-0000-0000-00000000000b', 'member-b@test.dev'),
    ('c0000000-0000-0000-0000-00000000000c', 'member-c@test.dev')
ON CONFLICT (id) DO NOTHING;

UPDATE public.users SET username = 'fixture_user_a', display_name = 'Member A' WHERE id = 'a0000000-0000-0000-0000-00000000000a';
UPDATE public.users SET username = 'fixture_user_b', display_name = 'Member B' WHERE id = 'b0000000-0000-0000-0000-00000000000b';
UPDATE public.users SET username = 'fixture_user_c', display_name = 'Member C' WHERE id = 'c0000000-0000-0000-0000-00000000000c';

-- 2. Setup titles
INSERT INTO public.titles (id, media_type, title)
VALUES
    (155, 'movie', 'The Dark Knight'),
    (238, 'movie', 'The Godfather'),
    (680, 'movie', 'Pulp Fiction'),
    (129, 'movie', 'Spirited Away'),
    (424, 'movie', 'Schindler''s List'),
    (278, 'movie', 'The Shawshank Redemption'),
    (13, 'movie', 'Forrest Gump')
ON CONFLICT (id, media_type) DO NOTHING;

-- 3. Populate Member A rankings (canon size = 4)
INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score)
VALUES
    ('a0000000-0000-0000-0000-00000000000a', 155, 'movie', 1, 10.00),
    ('a0000000-0000-0000-0000-00000000000a', 238, 'movie', 2, 7.80),
    ('a0000000-0000-0000-0000-00000000000a', 680, 'movie', 3, 5.00),
    ('a0000000-0000-0000-0000-00000000000a', 129, 'movie', 4, 3.00)
ON CONFLICT (user_id, title_id, media_type) DO NOTHING;

-- 4. Populate Member B rankings (canon size = 7)
INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score)
VALUES
    ('b0000000-0000-0000-0000-00000000000b', 424, 'movie', 1, 10.00),
    ('b0000000-0000-0000-0000-00000000000b', 155, 'movie', 2, 8.80),
    ('b0000000-0000-0000-0000-00000000000b', 278, 'movie', 3, 7.55),
    ('b0000000-0000-0000-0000-00000000000b', 238, 'movie', 4, 6.19),
    ('b0000000-0000-0000-0000-00000000000b', 680, 'movie', 5, 4.50),
    ('b0000000-0000-0000-0000-00000000000b', 13, 'movie', 6, 3.00),
    ('b0000000-0000-0000-0000-00000000000b', 129, 'movie', 7, 1.50)
ON CONFLICT (user_id, title_id, media_type) DO NOTHING;

-- Act as Member A
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"a0000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);

-- Parity Test 1: Spearman Taste Match with 4 mutual items (155, 238, 680, 129)
-- In both users' rankings: 155 is above 238, 238 above 680, 680 above 129.
-- Re-ranked relative order: (1,1), (2,2), (3,3), (4,4) -> rho=1.0, k=4 -> 72%
SELECT results_eq(
    $$ SELECT match_pct, mutual_count FROM public.calculate_taste_match_rpc('b0000000-0000-0000-0000-00000000000b', 'movie') $$,
    $$ VALUES (72, 4) $$,
    'Spearman Parity: 4 mutual titles with identical order produce exact 72% match'
);

-- Parity Test 2: Taste Match boundary case k < 2
SELECT results_eq(
    $$ SELECT match_pct, mutual_count FROM public.calculate_taste_match_rpc('c0000000-0000-0000-0000-00000000000c', 'movie') $$,
    $$ VALUES (50, 0) $$,
    'Spearman Parity: 0 mutual titles returns neutral 50% prior'
);

-- Parity Test 3: Setup squad with Member A and B
RESET ROLE;
INSERT INTO public.squads (id, name, created_by)
VALUES ('5a000000-0000-0000-0000-000000000001', 'Parity Test Squad', 'a0000000-0000-0000-0000-00000000000a')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.squad_members (squad_id, user_id)
VALUES
    ('5a000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-00000000000a'),
    ('5a000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-00000000000b')
ON CONFLICT (squad_id, user_id) DO NOTHING;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"a0000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);

-- Parity Test 4: Borda Squad Canon consensus ranks 1, 2, 3
SELECT results_eq(
    $$ SELECT consensus_rank, title_id, total_borda_points, members_ranked_count
       FROM public.calculate_squad_canon('5a000000-0000-0000-0000-000000000001', 'movie')
       WHERE consensus_rank <= 3
       ORDER BY consensus_rank $$,
    $$ VALUES
       (1, 155, 10::BIGINT, 2),
       (2, 238, 7::BIGINT, 2),
       (3, 424, 7::BIGINT, 1) $$,
    'Borda Parity: top 3 titles match borda_squad_canon_vectors.json'
);

-- Parity Test 5: Borda Squad Canon consensus ranks 4, 5
SELECT results_eq(
    $$ SELECT consensus_rank, title_id, total_borda_points, members_ranked_count
       FROM public.calculate_squad_canon('5a000000-0000-0000-0000-000000000001', 'movie')
       WHERE consensus_rank IN (4, 5)
       ORDER BY consensus_rank $$,
    $$ VALUES
       (4, 680, 5::BIGINT, 2),
       (5, 278, 5::BIGINT, 1) $$,
    'Borda Parity: 5-point tie broken by member count (Pulp Fiction beats Shawshank)'
);

-- Parity Test 6: Borda Squad Canon consensus ranks 6, 7
SELECT results_eq(
    $$ SELECT consensus_rank, title_id, total_borda_points, members_ranked_count
       FROM public.calculate_squad_canon('5a000000-0000-0000-0000-000000000001', 'movie')
       WHERE consensus_rank IN (6, 7)
       ORDER BY consensus_rank $$,
    $$ VALUES
       (6, 129, 2::BIGINT, 2),
       (7, 13, 2::BIGINT, 1) $$,
    'Borda Parity: 2-point tie broken by member count (Spirited Away beats Forrest Gump)'
);

-- Parity Test 7: Score Curve canon_score produces exact 10.00 and 1.00 at boundaries
SELECT results_eq(
    $$ SELECT public.canon_score(1, 10), public.canon_score(10, 10) $$,
    $$ VALUES (10.00::NUMERIC, 1.00::NUMERIC) $$,
    'Score Curve Parity: N=10 bounds are exactly 10.00 and 1.00'
);

SELECT * FROM finish();
ROLLBACK;
