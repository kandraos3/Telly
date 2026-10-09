-- Ticket #204: user_profile_settings, follow_requests, and search_users
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(13);

-- Setup test users
INSERT INTO auth.users (id, email) VALUES
    ('10000000-0000-0000-0000-000000000001', 'alice@test.dev'),
    ('10000000-0000-0000-0000-000000000002', 'bob@test.dev'),
    ('10000000-0000-0000-0000-000000000003', 'carol_ghost@test.dev'),
    ('10000000-0000-0000-0000-000000000004', 'dave_blocked@test.dev');

UPDATE public.users SET username = 'alice', display_name = 'Alice Archer' WHERE id = '10000000-0000-0000-0000-000000000001';
UPDATE public.users SET username = 'bob', display_name = 'Bob Builder', visibility_mode = 'FRIENDS_ONLY' WHERE id = '10000000-0000-0000-0000-000000000002';
UPDATE public.users SET username = 'carol', display_name = 'Carol Ghost', visibility_mode = 'GHOST' WHERE id = '10000000-0000-0000-0000-000000000003';
UPDATE public.users SET username = 'dave', display_name = 'Dave Danger' WHERE id = '10000000-0000-0000-0000-000000000004';

-- Blocker relationship
INSERT INTO public.user_blocks (blocker_id, blocked_id)
    VALUES ('10000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000001');

SET LOCAL ROLE authenticated;

-- Test 1: Unauthenticated search fails
SELECT throws_ok(
    $$ SELECT * FROM public.search_users('bob') $$,
    '42501',
    NULL,
    'search_users requires an authenticated user'
);

-- Set caller to Alice
SELECT set_config('request.jwt.claims', '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}', true);

-- Test 2: Alice searches 'bob' -> finds Bob Builder with FRIENDS_ONLY visibility and NULL follow status
SELECT results_eq(
    $$ SELECT username, display_name, visibility_mode, follow_status FROM public.search_users('bob') $$,
    $$ VALUES ('bob'::VARCHAR, 'Bob Builder'::VARCHAR, 'FRIENDS_ONLY'::public.visibility_mode_enum, NULL::public.follow_status_enum) $$,
    'finds Bob by username with correct visibility'
);

-- Test 3: Search with leading @ and uppercase matches
SELECT results_eq(
    $$ SELECT username FROM public.search_users('@BOB') $$,
    $$ VALUES ('bob'::VARCHAR) $$,
    'search strips leading @ and is case-insensitive'
);

-- Test 4: Alice cannot find herself
SELECT is(
    (SELECT count(*)::INT FROM public.search_users('alice')),
    0,
    'search_users excludes the caller'
);

-- Test 5: Carol is in GHOST mode -> invisible in search
SELECT is(
    (SELECT count(*)::INT FROM public.search_users('carol')),
    0,
    'ghost mode user is excluded from search results'
);

-- Test 6: Dave blocked Alice -> Dave is invisible
SELECT is(
    (SELECT count(*)::INT FROM public.search_users('dave')),
    0,
    'blocked users are excluded from search results'
);

-- Test 7: Follow requests: Alice follows Bob (who is FRIENDS_ONLY) -> status is pending
INSERT INTO public.social_follows (follower_id, following_id)
VALUES ('10000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002');

SELECT results_eq(
    $$ SELECT follow_status FROM public.search_users('bob') $$,
    $$ VALUES ('pending'::public.follow_status_enum) $$,
    'search reflects pending follow status'
);

-- Test 8: follow_requests view shows the pending request
SELECT results_eq(
    $$ SELECT requester_id, target_user_id, status FROM public.follow_requests WHERE target_user_id = '10000000-0000-0000-0000-000000000002' $$,
    $$ VALUES ('10000000-0000-0000-0000-000000000001'::UUID, '10000000-0000-0000-0000-000000000002'::UUID, 'pending'::public.follow_status_enum) $$,
    'follow_requests view exposes the pending request'
);

-- Switch to Bob to respond
SELECT set_config('request.jwt.claims', '{"sub":"10000000-0000-0000-0000-000000000002","role":"authenticated"}', true);

-- Test 9: Bob approves Alice's request
SELECT is(
    public.respond_to_follow_request('10000000-0000-0000-0000-000000000001', true),
    'accepted'::public.follow_status_enum,
    'respond_to_follow_request approves request'
);

-- Test 10: Status in social_follows is now accepted
SELECT results_eq(
    $$ SELECT status FROM public.social_follows WHERE follower_id = '10000000-0000-0000-0000-000000000001' AND following_id = '10000000-0000-0000-0000-000000000002' $$,
    $$ VALUES ('accepted'::public.follow_status_enum) $$,
    'social_follows row is accepted'
);

-- Test 11: user_profile_settings table exists and was auto-created for Bob
SELECT results_eq(
    $$ SELECT visibility_mode FROM public.user_profile_settings WHERE user_id = '10000000-0000-0000-0000-000000000002' $$,
    $$ VALUES ('FRIENDS_ONLY'::public.visibility_mode_enum) $$,
    'user_profile_settings has synced visibility_mode'
);

-- Test 12: Bob updates user_profile_settings to PUBLIC -> syncs to users table
UPDATE public.user_profile_settings SET visibility_mode = 'PUBLIC' WHERE user_id = '10000000-0000-0000-0000-000000000002';

SELECT results_eq(
    $$ SELECT visibility_mode FROM public.users WHERE id = '10000000-0000-0000-0000-000000000002' $$,
    $$ VALUES ('PUBLIC'::public.visibility_mode_enum) $$,
    'updating user_profile_settings syncs visibility_mode to users table'
);

-- Test 13: Bob cannot modify Alice settings
SELECT throws_ok(
    $$ UPDATE public.user_profile_settings SET hide_binge_velocity = true WHERE user_id = '10000000-0000-0000-0000-000000000001' $$,
    NULL,
    NULL,
    'RLS prevents modifying other users profile settings'
);

SELECT * FROM finish();
ROLLBACK;
