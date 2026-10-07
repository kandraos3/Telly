-- #141 (epic #50): collection_still_to_watch — released, unranked films in order, with Queue state.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(4);

INSERT INTO auth.users (id, email) VALUES
    ('a9000000-0000-0000-0000-00000000000a', 'stw-a@test.dev'),
    ('b9000000-0000-0000-0000-00000000000b', 'stw-b@test.dev');

INSERT INTO public.titles (id, media_type, title, release_date, poster_path) VALUES
    (940001, 'movie', 'Part One', '2001-12-19', '/p1.jpg'),
    (940002, 'movie', 'Part Two', '2002-12-18', '/p2.jpg'),
    (940003, 'movie', 'Part Three', '2003-12-17', '/p3.jpg'),
    (940004, 'movie', 'Part Four', NULL, NULL);
INSERT INTO public.title_collections (collection_id, name, part_ids, released_part_ids) VALUES
    (120, 'The Ring Collection', ARRAY[940001, 940002, 940003, 940004], ARRAY[940001, 940002, 940003]);

-- A ranked Part One and queued Part Three; B has nothing.
INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score)
VALUES ('a9000000-0000-0000-0000-00000000000a', 940001, 'movie', 1, 9.00);
INSERT INTO public.user_watchlist (user_id, title_id, media_type)
VALUES ('a9000000-0000-0000-0000-00000000000a', 940003, 'movie');

SET LOCAL ROLE authenticated;

SELECT throws_ok($$ SELECT * FROM public.collection_still_to_watch(120) $$, '42501', NULL,
    'requires a signed-in user');

SELECT set_config('request.jwt.claims', '{"sub":"a9000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
SELECT results_eq(
    $$ SELECT title_id, release_year, in_queue FROM public.collection_still_to_watch(120) $$,
    $$ VALUES (940002, 2002, FALSE), (940003, 2003, TRUE) $$,
    'released films I have not ranked, in release order, with my Queue state; the unreleased one is left out');

SELECT set_config('request.jwt.claims', '{"sub":"b9000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);
SELECT is((SELECT count(*)::INT FROM public.collection_still_to_watch(120)), 3,
    'someone who ranked none sees every released film');
SELECT is((SELECT count(*)::INT FROM public.collection_still_to_watch(999)), 0, 'an unknown collection is empty');

SELECT * FROM finish();
ROLLBACK;
