-- #140 (epic #50): TMDB collections and collection medals (Spec 10 §4.1, §7).
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(17);

SELECT has_column('public', 'titles', 'collection_id', 'titles.collection_id exists');
SELECT has_column('public', 'titles', 'production_companies', 'titles.production_companies exists');
SELECT has_column('public', 'titles', 'tv_type', 'titles.tv_type exists');

SELECT is(public._collection_glyph('The Lord of the Rings Collection'), 'LR', 'glyphs skip filler words and the suffix');
SELECT is(public._collection_glyph('Mission: Impossible Collection'), 'MI', 'glyphs split on punctuation too');

INSERT INTO auth.users (id, email) VALUES ('a8000000-0000-0000-0000-00000000000a', 'col-a@test.dev');

-- Three released films and one announced sequel; a single-film collection; parts as titles.
INSERT INTO public.titles (id, media_type, title, release_date, collection_id, metadata_version) VALUES
    (930001, 'movie', 'Knight One', '2005-06-10', 263, 2),
    (930002, 'movie', 'Knight Two', '2008-07-16', 263, 2),
    (930003, 'movie', 'Knight Three', '2012-07-17', 263, 2),
    (930004, 'movie', 'Knight Four', NULL, 263, 2),
    (930010, 'movie', 'Lonely Film', '2001-01-01', 777, 2),
    (930020, 'movie', 'Old Cache Row', '1999-01-01', NULL, 0);
UPDATE public.titles SET popularity = 50 WHERE id = 930020;

INSERT INTO public.title_collections (collection_id, name, part_ids, released_part_ids, fetched_at) VALUES
    (263, 'The Dark Knight Collection', ARRAY[930001, 930002, 930003, 930004], ARRAY[930001, 930002, 930003],
     NOW() - INTERVAL '10 days'),
    (777, 'Lonely Collection', ARRAY[930010], ARRAY[930010], NOW());

SELECT results_eq(
    $$ SELECT name::TEXT, tier::TEXT, glyph::TEXT, threshold, active FROM public.achievements WHERE id = 'collection_263' $$,
    $$ VALUES ('The Dark Knight', 'gold', 'DK', 3, TRUE) $$,
    'caching a collection creates its gold medal; the target counts released films only');
SELECT is((SELECT active FROM public.achievements WHERE id = 'collection_777'), FALSE,
    'a collection with one released film has no medal');

-- A ranks two of the three released films, each placed through a duel.
INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score, created_at) VALUES
    ('a8000000-0000-0000-0000-00000000000a', 930001, 'movie', 1, 9.00, '2026-09-01'),
    ('a8000000-0000-0000-0000-00000000000a', 930002, 'movie', 2, 8.00, '2026-09-02'),
    ('a8000000-0000-0000-0000-00000000000a', 930010, 'movie', 3, 7.00, '2026-09-03');
INSERT INTO public.pairwise_duels (user_id, winner_title_id, loser_title_id, media_type, placed_title_id) VALUES
    ('a8000000-0000-0000-0000-00000000000a', 930002, 930001, 'movie', 930002),
    ('a8000000-0000-0000-0000-00000000000a', 930010, 930001, 'movie', 930010);

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"a8000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);

SELECT results_eq(
    $$ SELECT id, progress, unlocked_at IS NULL FROM public.my_achievements() WHERE kind = 'collection' $$,
    $$ VALUES ('collection_263', 2, TRUE) $$,
    'a started collection lists with its progress; an inactive one never lists');

-- The third released film arrives through the duel RPC, which evaluates medals.
RESET ROLE;
INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score, created_at)
VALUES ('a8000000-0000-0000-0000-00000000000a', 930003, 'movie', 4, 6.00, '2026-09-04');
SET LOCAL ROLE authenticated;
SELECT public.record_pairwise_duels(
    '[{"client_mutation_id":"d8000000-0000-0000-0000-000000000001","winner_title_id":930003,"loser_title_id":930001,"media_type":"movie","placed_title_id":930003}]'::jsonb);

SELECT isnt((SELECT unlocked_at FROM public.my_achievements() WHERE id = 'collection_263'), NULL,
    'every released film ranked unlocks the medal; the announced sequel is not needed');

RESET ROLE;
SELECT is(
    (SELECT metadata ->> 'kind' FROM public.activity_logs
     WHERE user_id = 'a8000000-0000-0000-0000-00000000000a' AND metadata ->> 'achievement_id' = 'collection_263'),
    'collection', 'the unlock posts a MEDAL_UNLOCKED activity');

-- The sequel comes out: the target grows, but the medal stays earned.
UPDATE public.title_collections SET released_part_ids = part_ids WHERE collection_id = 263;
SELECT is((SELECT threshold FROM public.achievements WHERE id = 'collection_263'), 4, 'a new release raises the target');
SELECT is(public.evaluate_achievements('a8000000-0000-0000-0000-00000000000a'), 0, 'evaluating again changes nothing');
SELECT ok(EXISTS (SELECT 1 FROM public.user_achievements
                  WHERE user_id = 'a8000000-0000-0000-0000-00000000000a' AND achievement_id = 'collection_263'),
    'and the medal is never revoked');

-- Maintenance RPCs: service role only.
SELECT is((SELECT id FROM public.titles_needing_details(1)), 930020, 'titles stored before the new fields are backfilled');
SELECT results_eq($$ SELECT collection_id FROM public.stale_title_collections(7, 10) $$, $$ VALUES (263) $$,
    'collections older than a week are refreshed');

SELECT is(public._invoke_edge_function('tmdb-details'), NULL,
    'without the Vault secrets the scheduler call does nothing');

SET LOCAL ROLE authenticated;
SELECT throws_ok($$ SELECT * FROM public.titles_needing_details(1) $$, '42501', NULL,
    'clients cannot call the maintenance RPCs');

SELECT * FROM finish();
ROLLBACK;
