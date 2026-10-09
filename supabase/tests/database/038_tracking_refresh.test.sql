-- #227 (epic #168): the daily new-episodes check (features/11 section 4.8, 6.5).
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(18);

INSERT INTO auth.users (id, email) VALUES
    ('f3800000-0000-0000-0000-000000000001', 'u1@refresh.dev'),
    ('f3800000-0000-0000-0000-000000000002', 'u2@refresh.dev');

-- 9400001: returning, S2 not cached (the latest season of a running show counts as unaired).
-- 9400002: ended, finished. 9400003: season-selection cases. 9400004: someone is still watching.
-- 9400005: an ended show that is about to gain a season. 9400006: a film.
INSERT INTO public.titles (id, media_type, title, status) VALUES
    (9400001, 'tv', 'Returning Show', 'Returning Series'),
    (9400002, 'tv', 'Ended Show', 'Ended'),
    (9400003, 'tv', 'Seasons Show', 'Returning Series'),
    (9400004, 'tv', 'Watching Show', 'Returning Series'),
    (9400005, 'tv', 'Revived Show', 'Ended'),
    (9400006, 'movie', 'A Film', NULL);
INSERT INTO public.tv_seasons (title_id, season_number, episode_count, air_date) VALUES
    (9400001, 1, 3, '2000-01-01'), (9400001, 2, 3, '2001-01-01'),
    (9400002, 1, 2, '2000-01-01'),
    (9400003, 1, 2, '2000-01-01'), (9400003, 2, 2, '2001-01-01'), (9400003, 3, 3, '2002-01-01'),
    (9400003, 4, 2, '2003-01-01'),
    (9400004, 1, 3, '2000-01-01'),
    (9400005, 1, 2, '2000-01-01');
-- 9400003: S1 fully cached and past; S2 has an undated episode; S3 is cached in part; S4 is the latest.
INSERT INTO public.tv_episodes (title_id, season_number, episode_number, air_date) VALUES
    (9400003, 1, 1, '2000-01-01'), (9400003, 1, 2, '2000-01-08'),
    (9400003, 2, 1, '2001-01-01'), (9400003, 2, 2, NULL),
    (9400003, 3, 1, '2002-01-01'), (9400003, 3, 2, '2002-01-08');

INSERT INTO public.user_tracking (user_id, title_id, media_type, last_season, last_episode, state, finished_at) VALUES
    ('f3800000-0000-0000-0000-000000000001', 9400001, 'tv', 1, 3, 'CAUGHT_UP', NULL),
    ('f3800000-0000-0000-0000-000000000001', 9400002, 'tv', 1, 2, 'FINISHED', NOW()),
    ('f3800000-0000-0000-0000-000000000002', 9400004, 'tv', 1, 1, 'WATCHING', NULL),
    ('f3800000-0000-0000-0000-000000000002', 9400005, 'tv', 1, 2, 'FINISHED', NOW());
INSERT INTO public.user_tracking (user_id, title_id, media_type, state) VALUES
    ('f3800000-0000-0000-0000-000000000002', 9400006, 'movie', 'FINISHED');

-- 1. Which shows to refresh.
SELECT is((SELECT array_agg(title_id ORDER BY title_id) FROM public.tracking_shows_to_refresh(FALSE, 10)),
    ARRAY[9400001]::INT[],
    'weekdays: returning shows someone is caught up on (ended shows wait for Monday)');
SELECT is((SELECT array_agg(title_id ORDER BY title_id) FROM public.tracking_shows_to_refresh(TRUE, 10)),
    ARRAY[9400001, 9400002, 9400005]::INT[],
    'Mondays: ended and canceled shows are included too');
SELECT is((SELECT count(*)::INT FROM public.tracking_shows_to_refresh(TRUE, 1)), 1, 'the limit is respected');
SELECT is((SELECT count(*)::INT FROM public.tracking_shows_to_refresh(TRUE, 0)), 0, 'a zero limit selects nothing');

-- 2. Which seasons to fetch.
SELECT is((SELECT array_agg(season_number ORDER BY season_number) FROM public.tracking_seasons_to_refresh(9400001)),
    ARRAY[2]::INT[], 'with no cache, only the latest season');
SELECT is((SELECT array_agg(season_number ORDER BY season_number) FROM public.tracking_seasons_to_refresh(9400003)),
    ARRAY[2, 3, 4]::INT[],
    'an undated episode, a partly cached season and the latest season; not the settled one');

-- 3. Nothing new yet: the next episode of S2 is unaired.
SELECT is(public.refresh_tracking_new_episodes(), 0, 'nothing new, nothing flipped');
SELECT is((SELECT state::TEXT FROM public.user_tracking WHERE title_id = 9400001), 'CAUGHT_UP',
    'a caught-up show with nothing new stays caught up');

-- 4. S2 of 9400001 gets aired episodes; 9400005 gains a season.
INSERT INTO public.tv_episodes (title_id, season_number, episode_number, air_date) VALUES
    (9400001, 2, 1, '2020-01-01'), (9400001, 2, 2, '2020-01-08'), (9400001, 2, 3, '2020-01-15');
INSERT INTO public.tv_seasons (title_id, season_number, episode_count, air_date) VALUES
    (9400005, 2, 2, '2020-01-01');

SELECT is(public.refresh_tracking_new_episodes(), 2, 'both shows with a new aired episode are flipped');
SELECT is((SELECT state::TEXT FROM public.user_tracking WHERE title_id = 9400001), 'WATCHING',
    'a caught-up show with a new season is WATCHING again');
SELECT isnt((SELECT new_episodes_since FROM public.user_tracking WHERE title_id = 9400001), NULL::TIMESTAMPTZ,
    'and is flagged as having new episodes');
SELECT is((SELECT last_season * 10 + last_episode FROM public.user_tracking WHERE title_id = 9400001), 13,
    'the place is untouched');
SELECT is((SELECT state::TEXT FROM public.user_tracking WHERE title_id = 9400005), 'WATCHING',
    'a finished show that gains a season is WATCHING again');
SELECT is((SELECT finished_at FROM public.user_tracking WHERE title_id = 9400005), NULL::TIMESTAMPTZ,
    'and is no longer finished');
SELECT is((SELECT state::TEXT FROM public.user_tracking WHERE title_id = 9400002), 'FINISHED',
    'an ended show with nothing new stays finished');
SELECT is(public.refresh_tracking_new_episodes(), 0, 'running it again flips nothing');

-- 5. Service role only.
SET LOCAL ROLE authenticated;
SELECT throws_ok($$ SELECT public.refresh_tracking_new_episodes() $$, '42501', NULL,
    'clients cannot run the refresh');
SELECT throws_ok($$ SELECT * FROM public.tracking_shows_to_refresh(TRUE, 10) $$, '42501', NULL,
    'clients cannot list the shows to refresh');

SELECT * FROM finish();
ROLLBACK;
