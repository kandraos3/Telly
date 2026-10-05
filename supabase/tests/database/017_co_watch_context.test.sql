-- FE-COWATCH-01: get_co_watch_partners / get_shared_streaming_platforms.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(8);

INSERT INTO auth.users (id, email) VALUES
    ('a4000000-0000-0000-0000-00000000000a', 'couch-me@test.dev'),
    ('b4000000-0000-0000-0000-00000000000b', 'couch-maya@test.dev'),
    ('c4000000-0000-0000-0000-00000000000c', 'couch-pending@test.dev'),
    ('d4000000-0000-0000-0000-00000000000d', 'couch-nosubs@test.dev');
UPDATE public.users SET username = 'couch_me' WHERE id = 'a4000000-0000-0000-0000-00000000000a';
UPDATE public.users SET username = 'couch_maya', display_name = 'Maya' WHERE id = 'b4000000-0000-0000-0000-00000000000b';
UPDATE public.users SET username = 'couch_pending', visibility_mode = 'FRIENDS_ONLY'
    WHERE id = 'c4000000-0000-0000-0000-00000000000c';
UPDATE public.users SET username = 'couch_nosubs' WHERE id = 'd4000000-0000-0000-0000-00000000000d';

-- The status trigger accepts the public profile and leaves the friends-only one pending.
INSERT INTO public.social_follows (follower_id, following_id) VALUES
    ('a4000000-0000-0000-0000-00000000000a', 'b4000000-0000-0000-0000-00000000000b'),
    ('a4000000-0000-0000-0000-00000000000a', 'c4000000-0000-0000-0000-00000000000c');

INSERT INTO public.user_streaming_subscriptions (user_id, platform_id) VALUES
    ('a4000000-0000-0000-0000-00000000000a', 'netflix'),
    ('a4000000-0000-0000-0000-00000000000a', 'max'),
    ('b4000000-0000-0000-0000-00000000000b', 'max'),
    ('b4000000-0000-0000-0000-00000000000b', 'apple_tv_plus'),
    ('c4000000-0000-0000-0000-00000000000c', 'netflix');

SET LOCAL ROLE authenticated;

SELECT throws_ok($$ SELECT * FROM public.get_co_watch_partners() $$, '42501', NULL,
    'partners require an authenticated user');

SELECT set_config('request.jwt.claims', '{"sub":"a4000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);

SELECT results_eq(
    $$ SELECT username FROM public.get_co_watch_partners() $$,
    $$ VALUES ('couch_maya'::VARCHAR) $$,
    'partners are the people I follow with an accepted request');

SELECT is(public.get_shared_streaming_platforms('b4000000-0000-0000-0000-00000000000b') -> 'shared',
    '["max"]'::jsonb, 'shared platforms are the intersection of both subscriptions');
SELECT is((public.get_shared_streaming_platforms('b4000000-0000-0000-0000-00000000000b') ->> 'partner_set')::BOOLEAN,
    TRUE, 'reports that the partner has set up services');
SELECT ok(NOT (public.get_shared_streaming_platforms('b4000000-0000-0000-0000-00000000000b') ? 'partner'),
    'never returns the partner''s full subscription list');

SELECT is((public.get_shared_streaming_platforms('d4000000-0000-0000-0000-00000000000d') ->> 'partner_set')::BOOLEAN,
    FALSE, 'a partner without services is reported as unset');
SELECT is((public.get_shared_streaming_platforms('d4000000-0000-0000-0000-00000000000d') ->> 'mine_set')::BOOLEAN,
    TRUE, 'while my own services are still reported');

SELECT is(public.get_shared_streaming_platforms('c4000000-0000-0000-0000-00000000000c') -> 'shared', '[]'::jsonb,
    'a friends-only profile I cannot view shares nothing');

SELECT * FROM finish();
ROLLBACK;
