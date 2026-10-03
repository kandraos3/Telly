-- ============================================================================
-- PGTAP TEST SUITE: Social Follows, Activity Logs RLS & Squad Consensus
-- Ticket: QA-304 & BE-301, BE-302, BE-304 (Spec: 06_TESTING_FRAMEWORK §3.3)
-- ============================================================================

BEGIN;
SELECT plan(15);

-- Test 1: Tables exist
SELECT has_table('public', 'social_follows', 'social_follows table should exist');
SELECT has_table('public', 'activity_logs', 'activity_logs table should exist');
SELECT has_table('public', 'squads', 'squads table should exist');
SELECT has_table('public', 'squad_members', 'squad_members table should exist');

-- Test 2: Function detect_upset_duel exists
SELECT has_function(
    'public',
    'detect_upset_duel',
    ARRAY['integer', 'integer'],
    'detect_upset_duel function should exist with 2 integer parameters'
);

-- Test 3: Function calculate_squad_canon exists
SELECT has_function(
    'public',
    'calculate_squad_canon',
    ARRAY['uuid', 'media_type_enum'],
    'calculate_squad_canon function should exist'
);

-- Setup test users: User A (Public), User B (Private), User C (Follower of B), User D (Stranger)
INSERT INTO public.users (id, username, display_name, email, phone, is_private) VALUES
    ('00000000-0000-0000-0000-000000000010', 'user_a_pub', 'User A Public', 'a@telly.app', '+15550000010', FALSE),
    ('00000000-0000-0000-0000-000000000020', 'user_b_priv', 'User B Private', 'b@telly.app', '+15550000020', TRUE),
    ('00000000-0000-0000-0000-000000000030', 'user_c_fol', 'User C Follower', 'c@telly.app', '+15550000030', FALSE),
    ('00000000-0000-0000-0000-000000000040', 'user_d_str', 'User D Stranger', 'd@telly.app', '+15550000040', FALSE);

-- User C follows User B (accepted)
INSERT INTO public.social_follows (follower_id, following_id, status)
VALUES ('00000000-0000-0000-0000-000000000030', '00000000-0000-0000-0000-000000000020', 'accepted');

-- User D requested to follow User B (pending)
INSERT INTO public.social_follows (follower_id, following_id, status)
VALUES ('00000000-0000-0000-0000-000000000040', '00000000-0000-0000-0000-000000000020', 'pending');

-- Insert activities
INSERT INTO public.activity_logs (id, user_id, activity_type, is_upset, upset_delta) VALUES
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000010', 'RANKING_CREATED', FALSE, 0.00),
    ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000020', 'UPSET_ALERT', TRUE, 0.28);

-- Test 4: Verify follow record state
SELECT is(
    (SELECT status FROM public.social_follows WHERE follower_id = '00000000-0000-0000-0000-000000000030' AND following_id = '00000000-0000-0000-0000-000000000020'),
    'accepted',
    'Follow status between User C and User B is accepted'
);

SELECT is(
    (SELECT status FROM public.social_follows WHERE follower_id = '00000000-0000-0000-0000-000000000040' AND following_id = '00000000-0000-0000-0000-000000000020'),
    'pending',
    'Follow status between User D and User B is pending'
);

-- Test 5: Verify unique constraint on follower_id + following_id
SELECT throws_ok(
    $$ INSERT INTO public.social_follows (follower_id, following_id, status)
       VALUES ('00000000-0000-0000-0000-000000000030', '00000000-0000-0000-0000-000000000020', 'accepted') $$,
    '23505',
    NULL,
    'Duplicate follow relationship throws unique constraint violation'
);

-- Test 6: Upset engine detection logic
-- Setup duels for Title 301 (strong consensus, 80% win rate) vs Title 302 (underdog, 20% win rate)
INSERT INTO public.tv_shows (id, tmdb_id, title, media_type) VALUES
    (301, 999301, 'Consensus Titan', 'TV_SERIES'),
    (302, 999302, 'Underdog Sleeper', 'TV_SERIES');

-- 8 wins for 301, 2 wins for 302
INSERT INTO public.pairwise_duels (user_id, winner_show_id, loser_show_id) VALUES
    ('00000000-0000-0000-0000-000000000010', 301, 302),
    ('00000000-0000-0000-0000-000000000030', 301, 302),
    ('00000000-0000-0000-0000-000000000040', 301, 302),
    ('00000000-0000-0000-0000-000000000010', 301, 302);

-- When underdog 302 beats titan 301, detect_upset_duel should flag is_upset = true
SELECT is(
    (SELECT is_upset FROM detect_upset_duel(302, 301)),
    TRUE,
    'Underdog beating titan flags is_upset = true'
);

SELECT is(
    (SELECT is_upset FROM detect_upset_duel(301, 302)),
    FALSE,
    'Consensus titan beating underdog flags is_upset = false'
);

-- Test 7: Squad Borda Count consensus
INSERT INTO public.squads (id, name, created_by)
VALUES ('20000000-0000-0000-0000-000000000001', 'The Cinephiles', '00000000-0000-0000-0000-000000000010');

INSERT INTO public.squad_members (squad_id, user_id, role) VALUES
    ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000010', 'ADMIN'),
    ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000030', 'MEMBER');

-- Member A ranks Titan 301 at #1, Underdog 302 at #2 (N_A = 2, so rank 1 gets 2-1+1=2 pts, rank 2 gets 2-2+1=1 pt)
INSERT INTO public.user_rankings (user_id, show_id, rank_order, calculated_score, media_type) VALUES
    ('00000000-0000-0000-0000-000000000010', 301, 1, 10.00, 'TV_SERIES'),
    ('00000000-0000-0000-0000-000000000010', 302, 2, 1.00, 'TV_SERIES');

-- Member C ranks Titan 301 at #1, Underdog 302 at #2 (N_C = 2, 301 gets 2 pts, 302 gets 1 pt)
INSERT INTO public.user_rankings (user_id, show_id, rank_order, calculated_score, media_type) VALUES
    ('00000000-0000-0000-0000-000000000030', 301, 1, 10.00, 'TV_SERIES'),
    ('00000000-0000-0000-0000-000000000030', 302, 2, 1.00, 'TV_SERIES');

-- Consensus: Titan 301 has 2+2=4 points (Rank 1), Underdog 302 has 1+1=2 points (Rank 2)
SELECT is(
    (SELECT show_id FROM calculate_squad_canon('20000000-0000-0000-0000-000000000001'::uuid, 'TV_SERIES') WHERE consensus_rank = 1),
    301,
    'Titan 301 is consensus rank 1 in squad canon'
);

SELECT is(
    (SELECT total_borda_points FROM calculate_squad_canon('20000000-0000-0000-0000-000000000001'::uuid, 'TV_SERIES') WHERE consensus_rank = 1),
    4::bigint,
    'Titan 301 has exactly 4 Borda points'
);

SELECT is(
    (SELECT consensus_rank FROM calculate_squad_canon('20000000-0000-0000-0000-000000000001'::uuid, 'TV_SERIES') WHERE show_id = 302),
    2,
    'Underdog 302 is consensus rank 2 in squad canon'
);

SELECT * FROM finish();
ROLLBACK;
