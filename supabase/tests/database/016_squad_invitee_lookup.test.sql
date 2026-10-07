-- FE-SQUADS-02: lookup_squad_invitee resolves a handle or an exact email, never leaking emails.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(9);

INSERT INTO auth.users (id, email) VALUES
    ('a3000000-0000-0000-0000-00000000000a', 'inviter@test.dev'),
    ('b3000000-0000-0000-0000-00000000000b', 'Maya.Lin@Test.dev'),
    ('c3000000-0000-0000-0000-00000000000c', 'ghost@test.dev'),
    ('d3000000-0000-0000-0000-00000000000d', 'blocker@test.dev');
UPDATE public.users SET username = 'inviter' WHERE id = 'a3000000-0000-0000-0000-00000000000a';
UPDATE public.users SET username = 'maya_inv', display_name = 'Maya Lin' WHERE id = 'b3000000-0000-0000-0000-00000000000b';
UPDATE public.users SET username = 'ghost_inv', visibility_mode = 'GHOST' WHERE id = 'c3000000-0000-0000-0000-00000000000c';
UPDATE public.users SET username = 'blocker_inv' WHERE id = 'd3000000-0000-0000-0000-00000000000d';
INSERT INTO public.user_blocks (blocker_id, blocked_id)
    VALUES ('d3000000-0000-0000-0000-00000000000d', 'a3000000-0000-0000-0000-00000000000a');

SET LOCAL ROLE authenticated;

SELECT throws_ok($$ SELECT * FROM public.lookup_squad_invitee('maya_inv') $$, '42501', NULL,
    'the lookup requires an authenticated user');

SELECT set_config('request.jwt.claims', '{"sub":"a3000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);

SELECT results_eq(
    $$ SELECT id, matched_by FROM public.lookup_squad_invitee('@Maya_Inv') $$,
    $$ VALUES ('b3000000-0000-0000-0000-00000000000b'::UUID, 'handle'::TEXT) $$,
    'finds a user by handle, with or without @, case-insensitively');
SELECT results_eq(
    $$ SELECT id, matched_by FROM public.lookup_squad_invitee('  maya.lin@test.DEV ') $$,
    $$ VALUES ('b3000000-0000-0000-0000-00000000000b'::UUID, 'email'::TEXT) $$,
    'finds a user by exact email, case-insensitively');
SELECT is((SELECT count(*)::INT FROM public.lookup_squad_invitee('maya.lin@test')), 0,
    'a partial email matches nobody');
SELECT is((SELECT count(*)::INT FROM public.lookup_squad_invitee('%@test.dev')), 0,
    'wildcards are not patterns');
SELECT is((SELECT count(*)::INT FROM public.lookup_squad_invitee('nobody_here')), 0, 'unknown handles match nobody');
SELECT is((SELECT count(*)::INT FROM public.lookup_squad_invitee('ghost@test.dev')), 0, 'ghosts stay invisible');
SELECT is((SELECT count(*)::INT FROM public.lookup_squad_invitee('blocker_inv')), 0,
    'blocked relationships stay invisible');
SELECT unalike(pg_get_function_result('public.lookup_squad_invitee(text)'::regprocedure), '%email%',
    'no email column is ever exposed');

SELECT * FROM finish();
ROLLBACK;
