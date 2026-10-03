-- ============================================================================
-- PGTAP TEST SUITE: insert_user_ranking_atomic Stored Procedure
-- Ticket: QA-203 (Spec: technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md §3.3)
-- ============================================================================

BEGIN;
SELECT plan(12);

-- Test 1: Function exists and is callable
SELECT has_function(
    'public',
    'insert_user_ranking_atomic',
    ARRAY['uuid', 'integer', 'integer', 'watch_status_enum', 'finale_impact_enum', 'character varying', 'text[]', 'character varying', 'media_type_enum', 'boolean', 'viewing_venue_enum', 'numeric'],
    'insert_user_ranking_atomic function should exist with 12 parameters'
);

-- Setup test user
INSERT INTO public.users (id, username, display_name, email, phone)
VALUES ('00000000-0000-0000-0000-000000000001', 'testcinephile', 'Test Cinephile', 'test@telly.app', '+15550000001');

-- Setup test shows (3 TV shows, 2 Movies)
INSERT INTO public.tv_shows (id, tmdb_id, title, media_type) VALUES
    (101, 76331, 'Succession', 'TV_SERIES'),
    (102, 110492, 'Severance', 'TV_SERIES'),
    (103, 1396, 'Breaking Bad', 'TV_SERIES'),
    (201, 155, 'The Dark Knight', 'MOVIE'),
    (202, 157336, 'Interstellar', 'MOVIE');

-- Test 2: Insert first TV show at rank 1 into empty canon
SELECT lives_ok(
    $$ SELECT insert_user_ranking_atomic('00000000-0000-0000-0000-000000000001'::uuid, 101, 1, 'COMPLETED', 'FLAWLESS', 'Masterpiece', NULL, 'Kendall Roy', 'TV_SERIES') $$,
    'Inserting first TV show at rank 1 succeeds'
);

-- Test 3: First show receives calculated score 10.00
SELECT is(
    (SELECT calculated_score FROM public.user_rankings WHERE user_id = '00000000-0000-0000-0000-000000000001' AND show_id = 101),
    10.00,
    'First title in TV canon receives score 10.00'
);

-- Test 4: Insert second TV show at rank 1 (displacing first show to rank 2)
SELECT lives_ok(
    $$ SELECT insert_user_ranking_atomic('00000000-0000-0000-0000-000000000001'::uuid, 102, 1, 'COMPLETED', 'GREAT', 'Mind-bending', NULL, 'Mark Scout', 'TV_SERIES') $$,
    'Inserting second TV show at rank 1 succeeds and shifts previous rank 1 down'
);

-- Test 5 & 6: Verify ranks shifted cleanly
SELECT is(
    (SELECT rank_order FROM public.user_rankings WHERE user_id = '00000000-0000-0000-0000-000000000001' AND show_id = 102),
    1,
    'Severance is now rank 1'
);

SELECT is(
    (SELECT rank_order FROM public.user_rankings WHERE user_id = '00000000-0000-0000-0000-000000000001' AND show_id = 101),
    2,
    'Succession is shifted to rank 2'
);

-- Test 7: Insert third TV show at rank 2 (inserting between 1 and 2)
SELECT lives_ok(
    $$ SELECT insert_user_ranking_atomic('00000000-0000-0000-0000-000000000001'::uuid, 103, 2, 'COMPLETED', 'FLAWLESS', 'Peak drama', NULL, 'Walter White', 'TV_SERIES') $$,
    'Inserting third TV show at rank 2 succeeds'
);

-- Test 8: Verify sequence continuity (ranks 1, 2, 3)
SELECT set_eq(
    $$ SELECT rank_order FROM public.user_rankings WHERE user_id = '00000000-0000-0000-0000-000000000001' AND media_type = 'TV_SERIES' ORDER BY rank_order $$,
    ARRAY[1, 2, 3],
    'TV canon forms a continuous sequence of ranks 1, 2, 3 without gaps or duplicates'
);

-- Test 9: Insert Movie at rank 1
SELECT lives_ok(
    $$ SELECT insert_user_ranking_atomic('00000000-0000-0000-0000-000000000001'::uuid, 201, 1, 'COMPLETED', 'FLAWLESS', 'Best superhero film', NULL, 'Batman', 'MOVIE') $$,
    'Inserting movie at rank 1 in Movie Canon succeeds'
);

-- Test 10: DUAL-CANON ISOLATION: Movie insertion does NOT shift TV canon ranks
SELECT set_eq(
    $$ SELECT rank_order FROM public.user_rankings WHERE user_id = '00000000-0000-0000-0000-000000000001' AND media_type = 'TV_SERIES' ORDER BY rank_order $$,
    ARRAY[1, 2, 3],
    'Dual-canon segregation: Movie insertion does NOT alter TV rankings'
);

-- Test 11: Movie rank 1 has independent score 10.00
SELECT is(
    (SELECT calculated_score FROM public.user_rankings WHERE user_id = '00000000-0000-0000-0000-000000000001' AND show_id = 201),
    10.00,
    'Rank 1 in Movie Canon has independent score 10.00'
);

-- Test 12: Pairwise duels table constraint checks different show ids
SELECT throws_ok(
    $$ INSERT INTO public.pairwise_duels (user_id, winner_show_id, loser_show_id) 
       VALUES ('00000000-0000-0000-0000-000000000001'::uuid, 101, 101) $$,
    'chk_pairwise_duels_different_shows',
    'Cannot duel a title against itself'
);

SELECT * FROM finish();
ROLLBACK;
