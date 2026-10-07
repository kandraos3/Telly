-- FE-SQUADS-03: get_my_squads returns only my squads, newest first, with my role, an
-- active-member count and up to four member previews (owner first, deleted users left out).
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(9);

INSERT INTO auth.users (id, email) VALUES
    ('a4000000-0000-0000-0000-00000000000a', 'ms-a@test.dev'),
    ('b4000000-0000-0000-0000-00000000000b', 'ms-b@test.dev'),
    ('c4000000-0000-0000-0000-00000000000c', 'ms-c@test.dev'),
    ('e4000000-0000-0000-0000-00000000000e', 'ms-e@test.dev'),
    ('f4000000-0000-0000-0000-00000000000f', 'ms-f@test.dev'),
    ('94000000-0000-0000-0000-000000000009', 'ms-gone@test.dev'),
    ('d4000000-0000-0000-0000-00000000000d', 'ms-outsider@test.dev');
UPDATE public.users SET username = 'ms_a', display_name = 'Avery' WHERE id = 'a4000000-0000-0000-0000-00000000000a';
UPDATE public.users SET username = 'ms_b', display_name = 'Blake', visibility_mode = 'FRIENDS_ONLY'
    WHERE id = 'b4000000-0000-0000-0000-00000000000b';
UPDATE public.users SET username = 'ms_c', display_name = 'Casey' WHERE id = 'c4000000-0000-0000-0000-00000000000c';
UPDATE public.users SET username = 'ms_e', display_name = 'Eden' WHERE id = 'e4000000-0000-0000-0000-00000000000e';
UPDATE public.users SET username = 'ms_f', display_name = 'Frankie' WHERE id = 'f4000000-0000-0000-0000-00000000000f';
UPDATE public.users SET username = 'ms_gone', display_name = 'Gone', is_deleted = TRUE
    WHERE id = '94000000-0000-0000-0000-000000000009';
UPDATE public.users SET username = 'ms_d', display_name = 'Dana' WHERE id = 'd4000000-0000-0000-0000-00000000000d';

-- The owner joins at NOW() through the squads trigger; everyone else joins later, in order.
INSERT INTO public.squads (id, name, created_by, created_at) VALUES
    ('5c000000-0000-0000-0000-000000000001', 'The Apartment', 'a4000000-0000-0000-0000-00000000000a', '2026-01-01'),
    ('5c000000-0000-0000-0000-000000000002', 'Book Club', 'c4000000-0000-0000-0000-00000000000c', '2026-02-01'),
    ('5c000000-0000-0000-0000-000000000003', 'Solo', 'd4000000-0000-0000-0000-00000000000d', '2026-03-01');
INSERT INTO public.squad_members (squad_id, user_id, role, joined_at) VALUES
    ('5c000000-0000-0000-0000-000000000001', '94000000-0000-0000-0000-000000000009', 'MEMBER', NOW() + INTERVAL '30 seconds'),
    ('5c000000-0000-0000-0000-000000000001', 'b4000000-0000-0000-0000-00000000000b', 'MEMBER', NOW() + INTERVAL '1 minute'),
    ('5c000000-0000-0000-0000-000000000001', 'c4000000-0000-0000-0000-00000000000c', 'MEMBER', NOW() + INTERVAL '2 minutes'),
    ('5c000000-0000-0000-0000-000000000001', 'e4000000-0000-0000-0000-00000000000e', 'MEMBER', NOW() + INTERVAL '3 minutes'),
    ('5c000000-0000-0000-0000-000000000001', 'f4000000-0000-0000-0000-00000000000f', 'MEMBER', NOW() + INTERVAL '4 minutes'),
    ('5c000000-0000-0000-0000-000000000002', 'a4000000-0000-0000-0000-00000000000a', 'ADMIN', NOW() + INTERVAL '1 minute');

SET LOCAL ROLE authenticated;

SELECT throws_ok($$ SELECT * FROM public.get_my_squads() $$, '42501', NULL,
    'the list requires an authenticated user');

SELECT set_config('request.jwt.claims', '{"sub":"a4000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);

SELECT results_eq(
    $$ SELECT name FROM public.get_my_squads() $$,
    $$ VALUES ('Book Club'::VARCHAR), ('The Apartment') $$,
    'only my squads, newest first');
SELECT results_eq(
    $$ SELECT name, my_role FROM public.get_my_squads() $$,
    $$ VALUES ('Book Club'::VARCHAR, 'ADMIN'::VARCHAR), ('The Apartment', 'OWNER') $$,
    'each squad carries my role in it');
SELECT results_eq(
    $$ SELECT name, member_count FROM public.get_my_squads() $$,
    $$ VALUES ('Book Club'::VARCHAR, 2), ('The Apartment', 5) $$,
    'member counts leave out deleted users');
SELECT is(
    (SELECT jsonb_array_length(member_previews) FROM public.get_my_squads() WHERE name = 'The Apartment'),
    4,
    'previews stop at four members');
SELECT is(
    (SELECT array_agg(e.value->>'display_name' ORDER BY e.ordinality)
       FROM public.get_my_squads() s, jsonb_array_elements(s.member_previews) WITH ORDINALITY e
      WHERE s.name = 'The Apartment'),
    ARRAY['Avery', 'Blake', 'Casey', 'Eden'],
    'previews follow join order, owner first, and include friends-only members but not deleted ones');
SELECT ok(
    (SELECT member_previews->0 ?& ARRAY['user_id', 'username', 'display_name', 'avatar_url', 'role', 'joined_at']
       FROM public.get_my_squads() WHERE name = 'Book Club'),
    'each preview has id, handle, name, avatar, role and join time');

SELECT set_config('request.jwt.claims', '{"sub":"d4000000-0000-0000-0000-00000000000d","role":"authenticated"}', true);
SELECT results_eq(
    $$ SELECT name, my_role, member_count FROM public.get_my_squads() $$,
    $$ VALUES ('Solo'::VARCHAR, 'OWNER'::VARCHAR, 1) $$,
    'an outsider sees only their own squad');

SELECT unalike(pg_get_function_result('public.get_my_squads()'::regprocedure), '%email%',
    'no email column is ever exposed');

SELECT * FROM finish();
ROLLBACK;
