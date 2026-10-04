-- FE-608: get_squad_members / squad_shared_watchlist are member-gated and see past users RLS.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(7);

INSERT INTO auth.users (id, email) VALUES
    ('a3000000-0000-0000-0000-00000000000a', 'sq-a@test.dev'),
    ('b3000000-0000-0000-0000-00000000000b', 'sq-b@test.dev'),
    ('c3000000-0000-0000-0000-00000000000c', 'sq-c@test.dev'),
    ('d3000000-0000-0000-0000-00000000000d', 'sq-outsider@test.dev');
UPDATE public.users SET username = 'sq_a', display_name = 'Avery' WHERE id = 'a3000000-0000-0000-0000-00000000000a';
UPDATE public.users SET username = 'sq_b', display_name = 'Blake', visibility_mode = 'FRIENDS_ONLY'
    WHERE id = 'b3000000-0000-0000-0000-00000000000b';
UPDATE public.users SET username = 'sq_c', display_name = 'Casey' WHERE id = 'c3000000-0000-0000-0000-00000000000c';

INSERT INTO public.squads (id, name, created_by)
    VALUES ('5b000000-0000-0000-0000-000000000001', 'The Apartment', 'a3000000-0000-0000-0000-00000000000a');
INSERT INTO public.squad_members (squad_id, user_id) VALUES
    ('5b000000-0000-0000-0000-000000000001', 'b3000000-0000-0000-0000-00000000000b'),
    ('5b000000-0000-0000-0000-000000000001', 'c3000000-0000-0000-0000-00000000000c');
-- 1396 queued by all three, 1399 by A and B, 1398 by C only; the outsider queues 1396 too.
INSERT INTO public.user_watchlist (user_id, title_id, media_type) VALUES
    ('a3000000-0000-0000-0000-00000000000a', 1396, 'tv'),
    ('b3000000-0000-0000-0000-00000000000b', 1396, 'tv'),
    ('c3000000-0000-0000-0000-00000000000c', 1396, 'tv'),
    ('a3000000-0000-0000-0000-00000000000a', 1399, 'tv'),
    ('b3000000-0000-0000-0000-00000000000b', 1399, 'tv'),
    ('c3000000-0000-0000-0000-00000000000c', 1398, 'tv'),
    ('d3000000-0000-0000-0000-00000000000d', 1396, 'tv');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"c3000000-0000-0000-0000-00000000000c","role":"authenticated"}', true);

SELECT is((SELECT count(*)::INT FROM public.users WHERE id = 'b3000000-0000-0000-0000-00000000000b'), 0,
    'RLS alone hides the friends-only member from C');
SELECT results_eq(
    $$ SELECT display_name, role FROM public.get_squad_members('5b000000-0000-0000-0000-000000000001') $$,
    $$ VALUES ('Avery'::VARCHAR, 'OWNER'::VARCHAR), ('Blake', 'MEMBER'), ('Casey', 'MEMBER') $$,
    'squad-mates see every member, owner first');
SELECT results_eq(
    $$ SELECT title_id, queued_by, member_count FROM public.squad_shared_watchlist('5b000000-0000-0000-0000-000000000001') $$,
    $$ VALUES (1396, 3, 3), (1399, 2, 3) $$,
    'shared watchlist counts members only and drops single-member picks');
SELECT is((SELECT count(*)::INT FROM public.user_watchlist WHERE user_id <> auth.uid()), 0,
    'members still cannot read each other''s raw watchlists');

SELECT set_config('request.jwt.claims', '{"sub":"d3000000-0000-0000-0000-00000000000d","role":"authenticated"}', true);
SELECT throws_ok($$ SELECT * FROM public.get_squad_members('5b000000-0000-0000-0000-000000000001') $$,
    '42501', NULL, 'outsiders cannot list members');
SELECT throws_ok($$ SELECT * FROM public.squad_shared_watchlist('5b000000-0000-0000-0000-000000000001') $$,
    '42501', NULL, 'outsiders cannot read the shared watchlist');

-- A one-person squad shows its only member's queue.
SELECT set_config('request.jwt.claims', '{"sub":"d3000000-0000-0000-0000-00000000000d","role":"authenticated"}', true);
INSERT INTO public.squads (id, name, created_by)
    VALUES ('5b000000-0000-0000-0000-000000000002', 'Solo', 'd3000000-0000-0000-0000-00000000000d');
SELECT is((SELECT count(*)::INT FROM public.squad_shared_watchlist('5b000000-0000-0000-0000-000000000002')), 1,
    'a solo squad lists its member''s queue');

SELECT * FROM finish();
ROLLBACK;
