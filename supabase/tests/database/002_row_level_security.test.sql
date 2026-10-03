-- BE-602: Row-Level Security (audit C6).
-- Contract: docs/technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md §2.4
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(22);

-- Fixtures (as postgres) -------------------------------------------------------
-- A = PUBLIC, B = FRIENDS_ONLY, C = PUBLIC (the "attacker"), D = GHOST, E = FRIENDS_ONLY
INSERT INTO auth.users (id, email) VALUES
    ('aaaaaaaa-0000-0000-0000-000000000000', 'a@test.dev'),
    ('bbbbbbbb-0000-0000-0000-000000000000', 'b@test.dev'),
    ('cccccccc-0000-0000-0000-000000000000', 'c@test.dev'),
    ('dddddddd-0000-0000-0000-000000000000', 'd@test.dev'),
    ('eeeeeeee-0000-0000-0000-000000000000', 'e@test.dev');
UPDATE public.users SET visibility_mode = 'FRIENDS_ONLY'
    WHERE id IN ('bbbbbbbb-0000-0000-0000-000000000000', 'eeeeeeee-0000-0000-0000-000000000000');
UPDATE public.users SET visibility_mode = 'GHOST' WHERE id = 'dddddddd-0000-0000-0000-000000000000';

INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score) VALUES
    ('aaaaaaaa-0000-0000-0000-000000000000', 155, 'movie', 1, 10.00),
    ('bbbbbbbb-0000-0000-0000-000000000000', 155, 'movie', 1, 10.00);

SELECT is(
    (SELECT count(*)::int FROM pg_tables WHERE schemaname = 'public' AND NOT rowsecurity),
    0, 'RLS is enabled on every public table (I-6)'
);

-- Act as C ----------------------------------------------------------------------
SELECT set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-000000000000","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;

SELECT is((SELECT count(*)::int FROM public.user_rankings WHERE user_id = 'aaaaaaaa-0000-0000-0000-000000000000'),
    1, 'public user rankings are visible');
SELECT is((SELECT count(*)::int FROM public.user_rankings WHERE user_id = 'bbbbbbbb-0000-0000-0000-000000000000'),
    0, 'FRIENDS_ONLY rankings hidden from non-followers (audit C6)');
SELECT is((SELECT count(*)::int FROM public.users WHERE id = 'dddddddd-0000-0000-0000-000000000000'),
    0, 'GHOST profiles are invisible to others');
SELECT is((SELECT count(*)::int FROM public.titles), 50, 'catalog is readable when signed in');

-- Forged / self-approved follows
INSERT INTO public.social_follows (follower_id, following_id, status)
    VALUES ('cccccccc-0000-0000-0000-000000000000', 'bbbbbbbb-0000-0000-0000-000000000000', 'accepted');
SELECT is(
    (SELECT status::text FROM public.social_follows
     WHERE follower_id = 'cccccccc-0000-0000-0000-000000000000' AND following_id = 'bbbbbbbb-0000-0000-0000-000000000000'),
    'pending', 'client-supplied accepted status is forced to pending for FRIENDS_ONLY targets');

UPDATE public.social_follows SET status = 'accepted'
    WHERE follower_id = 'cccccccc-0000-0000-0000-000000000000' AND following_id = 'bbbbbbbb-0000-0000-0000-000000000000';
SELECT is(
    (SELECT status::text FROM public.social_follows
     WHERE follower_id = 'cccccccc-0000-0000-0000-000000000000' AND following_id = 'bbbbbbbb-0000-0000-0000-000000000000'),
    'pending', 'follower cannot self-approve a pending follow');

SELECT throws_ok(
    $$ INSERT INTO public.social_follows (follower_id, following_id)
       VALUES ('aaaaaaaa-0000-0000-0000-000000000000', 'eeeeeeee-0000-0000-0000-000000000000') $$,
    '42501', NULL, 'cannot create a follow on behalf of another user');

SELECT is((SELECT count(*)::int FROM public.user_rankings WHERE user_id = 'bbbbbbbb-0000-0000-0000-000000000000'),
    0, 'pending follow does not grant visibility');

INSERT INTO public.social_follows (follower_id, following_id)
    VALUES ('cccccccc-0000-0000-0000-000000000000', 'aaaaaaaa-0000-0000-0000-000000000000');
SELECT is(
    (SELECT status::text FROM public.social_follows
     WHERE follower_id = 'cccccccc-0000-0000-0000-000000000000' AND following_id = 'aaaaaaaa-0000-0000-0000-000000000000'),
    'accepted', 'following a PUBLIC user is auto-accepted');

SELECT throws_ok(
    $$ INSERT INTO public.social_follows (follower_id, following_id)
       VALUES ('cccccccc-0000-0000-0000-000000000000', 'dddddddd-0000-0000-0000-000000000000') $$,
    'P0002', NULL, 'cannot follow a GHOST user');

-- Direct writes that must go through RPCs / are not the caller's
SELECT throws_ok(
    $$ INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score)
       VALUES ('cccccccc-0000-0000-0000-000000000000', 238, 'movie', 1, 10.00) $$,
    '42501', NULL, 'rankings cannot be inserted directly (RPC only)');

UPDATE public.user_rankings SET review_short = 'pwned' WHERE user_id = 'aaaaaaaa-0000-0000-0000-000000000000';
SELECT is(
    (SELECT review_short FROM public.user_rankings WHERE user_id = 'aaaaaaaa-0000-0000-0000-000000000000'),
    NULL, 'cannot edit another user''s ranking');

SELECT throws_ok(
    $$ UPDATE public.users SET is_deleted = TRUE WHERE id = 'cccccccc-0000-0000-0000-000000000000' $$,
    '42501', NULL, 'is_deleted is not client-writable');

SELECT throws_ok($$ SELECT * FROM public.reports $$, '42501', NULL, 'reports are not client-readable');
SELECT throws_ok(
    $$ INSERT INTO public.titles (id, media_type, title) VALUES (1, 'movie', 'x') $$,
    '42501', NULL, 'catalog is not client-writable');

-- Squads are members-only
INSERT INTO public.squads (name, created_by) VALUES ('C Squad', 'cccccccc-0000-0000-0000-000000000000');
SELECT is(
    (SELECT role FROM public.squad_members m JOIN public.squads s ON s.id = m.squad_id
     WHERE s.name = 'C Squad' AND m.user_id = 'cccccccc-0000-0000-0000-000000000000'),
    'OWNER', 'squad creator becomes OWNER');

-- Act as B: approve C, then block C ----------------------------------------------
SELECT set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000000","role":"authenticated"}', true);

SELECT is((SELECT count(*)::int FROM public.squads WHERE name = 'C Squad'), 0, 'non-members cannot see a squad');

UPDATE public.social_follows SET status = 'accepted'
    WHERE follower_id = 'cccccccc-0000-0000-0000-000000000000' AND following_id = 'bbbbbbbb-0000-0000-0000-000000000000';

SELECT set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-000000000000","role":"authenticated"}', true);
SELECT is((SELECT count(*)::int FROM public.user_rankings WHERE user_id = 'bbbbbbbb-0000-0000-0000-000000000000'),
    1, 'approved follower can see FRIENDS_ONLY rankings');

SELECT set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000000","role":"authenticated"}', true);
INSERT INTO public.user_blocks (blocker_id, blocked_id)
    VALUES ('bbbbbbbb-0000-0000-0000-000000000000', 'cccccccc-0000-0000-0000-000000000000');

SELECT set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-000000000000","role":"authenticated"}', true);
SELECT is((SELECT count(*)::int FROM public.user_rankings WHERE user_id = 'bbbbbbbb-0000-0000-0000-000000000000'),
    0, 'a block hides content even with an accepted follow');
SELECT is((SELECT count(*)::int FROM public.user_blocks), 0, 'the blocked user cannot see the block row');

-- anon -----------------------------------------------------------------------------
RESET ROLE;
SET LOCAL ROLE anon;
SELECT throws_ok($$ SELECT * FROM public.users $$, '42501', NULL, 'anon cannot read user profiles');

SELECT * FROM finish();
ROLLBACK;
