-- FE-608: lookup_profile_card visibility rules + avatar storage policies.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(10);

INSERT INTO auth.users (id, email) VALUES
    ('a2000000-0000-0000-0000-00000000000a', 'look-a@test.dev'),
    ('b2000000-0000-0000-0000-00000000000b', 'look-b@test.dev'),
    ('c2000000-0000-0000-0000-00000000000c', 'look-c@test.dev'),
    ('d2000000-0000-0000-0000-00000000000d', 'look-d@test.dev');
UPDATE public.users SET username = 'look_a' WHERE id = 'a2000000-0000-0000-0000-00000000000a';
UPDATE public.users SET username = 'look_friends', visibility_mode = 'FRIENDS_ONLY', bio = 'secret bio'
    WHERE id = 'b2000000-0000-0000-0000-00000000000b';
UPDATE public.users SET username = 'look_ghost', visibility_mode = 'GHOST' WHERE id = 'c2000000-0000-0000-0000-00000000000c';
UPDATE public.users SET username = 'look_blocker' WHERE id = 'd2000000-0000-0000-0000-00000000000d';
INSERT INTO public.user_blocks (blocker_id, blocked_id)
    VALUES ('d2000000-0000-0000-0000-00000000000d', 'a2000000-0000-0000-0000-00000000000a');

-- storage.buckets has its own RLS, so check the bucket as the migration owner.
SELECT is((SELECT public FROM storage.buckets WHERE id = 'avatars'), TRUE, 'avatars bucket is public-read');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"a2000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);

SELECT is((SELECT count(*)::INT FROM public.users WHERE username = 'look_friends'), 0,
    'RLS hides the friends-only profile row itself');
SELECT results_eq(
    $$ SELECT id, bio, can_view FROM public.lookup_profile_card('LOOK_FRIENDS') $$,
    $$ VALUES ('b2000000-0000-0000-0000-00000000000b'::UUID, NULL::VARCHAR, FALSE) $$,
    'the card still exposes the id for a follow request, but not the bio (case-insensitive handle)');
SELECT is((SELECT count(*)::INT FROM public.lookup_profile_card('look_ghost')), 0, 'ghosts stay invisible');
SELECT is((SELECT count(*)::INT FROM public.lookup_profile_card('look_blocker')), 0, 'blocked relationships stay invisible');

INSERT INTO public.social_follows (follower_id, following_id)
    VALUES ('a2000000-0000-0000-0000-00000000000a', 'b2000000-0000-0000-0000-00000000000b');
RESET ROLE;
UPDATE public.social_follows SET status = 'accepted'
    WHERE follower_id = 'a2000000-0000-0000-0000-00000000000a' AND following_id = 'b2000000-0000-0000-0000-00000000000b';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"a2000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
SELECT results_eq(
    $$ SELECT bio, can_view FROM public.lookup_profile_card('look_friends') $$,
    $$ VALUES ('secret bio'::VARCHAR, TRUE) $$,
    'an accepted follower sees the bio');

-- Avatars: own folder only.
SELECT lives_ok(
    $$ INSERT INTO storage.objects (bucket_id, name, owner) VALUES ('avatars', 'a2000000-0000-0000-0000-00000000000a/avatar.jpg', auth.uid()) $$,
    'a user can write their own avatar');
SELECT throws_ok(
    $$ INSERT INTO storage.objects (bucket_id, name, owner) VALUES ('avatars', 'b2000000-0000-0000-0000-00000000000b/avatar.jpg', auth.uid()) $$,
    '42501', NULL, 'but not someone else''s');
SELECT is((SELECT count(*)::INT FROM storage.objects WHERE bucket_id = 'avatars'), 1, 'avatars are readable');

SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims', '{"role":"anon"}', true);
SELECT is((SELECT count(*)::INT FROM public.lookup_profile_card('look_a')), 0, 'anonymous callers get nothing');

SELECT * FROM finish();
ROLLBACK;
