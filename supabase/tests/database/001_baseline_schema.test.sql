-- BE-601: baseline schema, seed, triggers and handle RPC.
-- Contract: docs/technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md §2, §3.3, §3.4
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(45);

-- 1. Every contract table exists ---------------------------------------------
SELECT has_table('public', t, format('table %s exists', t))
FROM unnest(ARRAY[
    'users', 'titles', 'tv_seasons', 'streaming_platforms', 'title_availability',
    'user_streaming_subscriptions', 'user_rankings', 'pairwise_duels', 'user_external_accounts',
    'user_dropped_shows', 'user_watchlist', 'user_muted_titles', 'social_follows', 'user_blocks',
    'taste_matches', 'squads', 'squad_members', 'activity_logs', 'feed_reactions', 'comments', 'reports'
]) AS t;

SELECT hasnt_table('public', 'friendships', 'duplicate friendships table is gone');
SELECT hasnt_table('public', 'tv_shows', 'legacy tv_shows table is gone');

-- 2. Dual-Canon types & keys (I-1, I-2) -----------------------------------------
SELECT enum_has_labels('public', 'media_type_enum', ARRAY['movie', 'tv'], 'media_type_enum is exactly movie/tv');
SELECT col_is_pk('public', 'titles', ARRAY['id', 'media_type'], 'titles keyed by (id, media_type)');
SELECT col_type_is('public', 'user_rankings', 'media_type', 'media_type_enum', 'user_rankings.media_type uses the enum');
SELECT has_column('public', 'user_rankings', 'rank_position', 'user_rankings.rank_position exists');
SELECT has_column('public', 'user_rankings', 'client_mutation_id', 'user_rankings.client_mutation_id exists (I-5)');

-- 3. Seed (BE-102 counts) ------------------------------------------------------
SELECT is((SELECT count(*)::int FROM public.titles WHERE media_type = 'movie'), 15, '15 movies seeded');
SELECT is((SELECT count(*)::int FROM public.titles WHERE media_type = 'tv'), 35, '35 tv titles seeded');
SELECT is((SELECT count(*)::int FROM public.titles WHERE is_anime), 15, '15 anime seeded as tv + is_anime');
SELECT is((SELECT count(*)::int FROM public.streaming_platforms), 9, '9 streaming platforms seeded');

-- 4. on_auth_user_created trigger ----------------------------------------------
INSERT INTO auth.users (id, email, raw_user_meta_data)
VALUES ('11111111-1111-1111-1111-111111111111', 'a@test.dev', '{"full_name": "Ada Test"}');

SELECT is(
    (SELECT display_name FROM public.users WHERE id = '11111111-1111-1111-1111-111111111111'),
    'Ada Test',
    'auth sign-up creates a skeleton public.users row'
);
SELECT is(
    (SELECT username FROM public.users WHERE id = '11111111-1111-1111-1111-111111111111'),
    NULL,
    'skeleton row has no handle until reserved'
);

-- 5. Handle rules -------------------------------------------------------------
UPDATE public.users SET username = 'ada_test' WHERE id = '11111111-1111-1111-1111-111111111111';

SELECT ok(NOT public.check_handle_available('admin'), 'reserved handle rejected');
SELECT ok(NOT public.check_handle_available('ab'), 'too-short handle rejected');
SELECT ok(NOT public.check_handle_available('a__b'), 'double underscore rejected');
SELECT ok(NOT public.check_handle_available('with-hyphen'), 'hyphen rejected');
SELECT ok(NOT public.check_handle_available('Ada_Test'), 'taken handle rejected case-insensitively');
SELECT ok(public.check_handle_available('fresh_handle'), 'free handle accepted');
SELECT throws_ok(
    $$ UPDATE public.users SET username = 'UPPER' WHERE id = '11111111-1111-1111-1111-111111111111' $$,
    '23514', NULL, 'username CHECK rejects uppercase'
);

-- 6. updated_at trigger ---------------------------------------------------------
UPDATE public.users SET updated_at = '2000-01-01' WHERE id = '11111111-1111-1111-1111-111111111111';
UPDATE public.users SET bio = 'hello' WHERE id = '11111111-1111-1111-1111-111111111111';
SELECT ok(
    (SELECT updated_at > '2000-01-02'::timestamptz FROM public.users WHERE id = '11111111-1111-1111-1111-111111111111'),
    'set_updated_at refreshes updated_at'
);

-- 7. Integrity constraints --------------------------------------------------------
SELECT throws_ok(
    $$ INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score)
       VALUES ('11111111-1111-1111-1111-111111111111', 157336, 'tv', 1, 10) $$,
    '23503', NULL, 'ranking a movie id as tv violates the composite title FK'
);
SELECT throws_ok(
    $$ INSERT INTO public.pairwise_duels (user_id, winner_title_id, loser_title_id, media_type)
       VALUES ('11111111-1111-1111-1111-111111111111', 155, 155, 'movie') $$,
    '23514', NULL, 'a title cannot duel itself'
);
SELECT throws_ok(
    $$ INSERT INTO public.social_follows (follower_id, following_id)
       VALUES ('11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111') $$,
    '23514', NULL, 'users cannot follow themselves'
);

SELECT * FROM finish();
ROLLBACK;
