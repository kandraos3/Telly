-- ============================================================================
-- pgTAP Test: calculate_taste_match_rpc (QA-404)
-- ============================================================================

BEGIN;
SELECT plan(6);

-- Setup test users
INSERT INTO public.users (id, handle, display_name)
VALUES 
    ('11111111-1111-1111-1111-111111111111', 'user_a', 'Alice'),
    ('22222222-2222-2222-2222-222222222222', 'user_b', 'Bob'),
    ('33333333-3333-3333-3333-333333333333', 'user_c', 'Charlie')
ON CONFLICT (id) DO NOTHING;

-- Seed test shows if not present
INSERT INTO public.tv_shows (id, title, media_type)
VALUES
    (9901, 'Show One', 'TV_SERIES'),
    (9902, 'Show Two', 'TV_SERIES'),
    (9903, 'Show Three', 'TV_SERIES'),
    (9904, 'Movie One', 'MOVIE'),
    (9905, 'Movie Two', 'MOVIE')
ON CONFLICT (id) DO NOTHING;

-- Scenario 1: Alice and Bob have identical rankings for 3 shows
INSERT INTO public.user_rankings (user_id, show_id, rank_order, calculated_score, media_type)
VALUES
    ('11111111-1111-1111-1111-111111111111', 9901, 1, 9.8, 'TV_SERIES'),
    ('11111111-1111-1111-1111-111111111111', 9902, 2, 8.5, 'TV_SERIES'),
    ('11111111-1111-1111-1111-111111111111', 9903, 3, 7.2, 'TV_SERIES'),
    ('22222222-2222-2222-2222-222222222222', 9901, 1, 9.5, 'TV_SERIES'),
    ('22222222-2222-2222-2222-222222222222', 9902, 2, 8.8, 'TV_SERIES'),
    ('22222222-2222-2222-2222-222222222222', 9903, 3, 7.0, 'TV_SERIES')
ON CONFLICT (user_id, show_id) DO UPDATE SET rank_order = EXCLUDED.rank_order;

-- Test 1: Identical rankings should yield positive correlation with shrinkage (k=3 => W=3/8=0.375 => adj_rho=0.375 => 69%)
SELECT is(
    (SELECT match_pct FROM calculate_taste_match_rpc('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'TV_SERIES')),
    69,
    'Identical ranks with k=3 yields 69% after Bayesian shrinkage towards neutral 50%'
);

-- Test 2: Mutual count should be 3
SELECT is(
    (SELECT mutual_count FROM calculate_taste_match_rpc('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'TV_SERIES')),
    3,
    'Mutual count is correctly 3'
);

-- Scenario 2: Charlie has completely inverted rankings
INSERT INTO public.user_rankings (user_id, show_id, rank_order, calculated_score, media_type)
VALUES
    ('33333333-3333-3333-3333-333333333333', 9901, 3, 7.0, 'TV_SERIES'),
    ('33333333-3333-3333-3333-333333333333', 9902, 2, 8.0, 'TV_SERIES'),
    ('33333333-3333-3333-3333-333333333333', 9903, 1, 9.0, 'TV_SERIES')
ON CONFLICT (user_id, show_id) DO UPDATE SET rank_order = EXCLUDED.rank_order;

-- Test 3: Inverted ranks should yield negative correlation (k=3 => raw_rho=-1.0 => adj_rho=-0.375 => 31%)
SELECT is(
    (SELECT match_pct FROM calculate_taste_match_rpc('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'TV_SERIES')),
    31,
    'Inverted ranks with k=3 yields 31% after Bayesian shrinkage towards neutral 50%'
);

-- Scenario 3: Less than 2 mutual items returns 50% neutral prior
-- Test 4: Querying for MOVIE media_type where Alice and Bob have 0 mutual items
SELECT is(
    (SELECT match_pct FROM calculate_taste_match_rpc('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'MOVIE')),
    50,
    'Zero mutual movies returns neutral 50% prior'
);

-- Test 5: Mutual count for MOVIE is 0
SELECT is(
    (SELECT mutual_count FROM calculate_taste_match_rpc('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'MOVIE')),
    0,
    'Mutual count for movies is 0'
);

-- Test 6: Media type null calculates overall blended match
SELECT ok(
    (SELECT match_pct FROM calculate_taste_match_rpc('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', NULL)) IS NOT NULL,
    'Blended match calculation succeeds without error'
);

SELECT * FROM finish();
ROLLBACK;
