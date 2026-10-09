-- #226 (epic #168): get_my_tracking, get_title_watchers, get_tracking_stats and the feed's
-- opt-in tracking rows (features/11 sections 5.4, 6.3, 7, 8).
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(34);

-- A is me. B is public, C friends-only, D ghost, E blocked me, F is not followed, G has finished.
INSERT INTO auth.users (id, email) VALUES
    ('f3700000-0000-0000-0000-00000000000a', 'a@reads.dev'),
    ('f3700000-0000-0000-0000-00000000000b', 'b@reads.dev'),
    ('f3700000-0000-0000-0000-00000000000c', 'c@reads.dev'),
    ('f3700000-0000-0000-0000-00000000000d', 'd@reads.dev'),
    ('f3700000-0000-0000-0000-00000000000e', 'e@reads.dev'),
    ('f3700000-0000-0000-0000-00000000000f', 'f@reads.dev'),
    ('f3700000-0000-0000-0000-000000000010', 'g@reads.dev');
UPDATE public.users SET visibility_mode = 'FRIENDS_ONLY' WHERE id = 'f3700000-0000-0000-0000-00000000000c';
UPDATE public.users SET visibility_mode = 'GHOST' WHERE id = 'f3700000-0000-0000-0000-00000000000d';
UPDATE public.users SET timezone = 'America/New_York' WHERE id = 'f3700000-0000-0000-0000-00000000000a';

INSERT INTO public.social_follows (follower_id, following_id, status)
SELECT 'f3700000-0000-0000-0000-00000000000a', u, 'accepted'
FROM unnest(ARRAY[
    'f3700000-0000-0000-0000-00000000000b', 'f3700000-0000-0000-0000-00000000000c',
    'f3700000-0000-0000-0000-00000000000d', 'f3700000-0000-0000-0000-00000000000e',
    'f3700000-0000-0000-0000-000000000010']::UUID[]) AS u;
-- The insert trigger sets pending for non-public targets; accept them.
UPDATE public.social_follows SET status = 'accepted'
WHERE follower_id = 'f3700000-0000-0000-0000-00000000000a';
INSERT INTO public.user_blocks (blocker_id, blocked_id)
VALUES ('f3700000-0000-0000-0000-00000000000e', 'f3700000-0000-0000-0000-00000000000a');

-- 9300001: an ended series (S1: 3 cached episodes of 40 min, S2: 3 uncached). 9300002: a film.
INSERT INTO public.titles (id, media_type, title, status, runtime_minutes) VALUES
    (9300001, 'tv', 'Reads Show', 'Ended', NULL),
    (9300002, 'movie', 'Reads Film', NULL, 120);
INSERT INTO public.tv_seasons (title_id, season_number, episode_count, air_date) VALUES
    (9300001, 1, 3, '2000-01-01'), (9300001, 2, 3, '2001-01-01');
INSERT INTO public.tv_episodes (title_id, season_number, episode_number, name, still_path, air_date, runtime_minutes) VALUES
    (9300001, 1, 1, 'First', '/1.jpg', '2000-01-01', 40),
    (9300001, 1, 2, 'Second', '/2.jpg', '2000-01-08', 40),
    (9300001, 1, 3, 'Third', '/3.jpg', '2000-01-15', 40);

-- Who is watching 9300001.
INSERT INTO public.user_tracking (user_id, title_id, media_type, last_season, last_episode, state, finished_at) VALUES
    ('f3700000-0000-0000-0000-00000000000b', 9300001, 'tv', 1, 1, 'WATCHING', NULL),
    ('f3700000-0000-0000-0000-00000000000c', 9300001, 'tv', 1, 2, 'WATCHING', NULL),
    ('f3700000-0000-0000-0000-00000000000d', 9300001, 'tv', 1, 1, 'WATCHING', NULL),
    ('f3700000-0000-0000-0000-00000000000e', 9300001, 'tv', 1, 1, 'WATCHING', NULL),
    ('f3700000-0000-0000-0000-00000000000f', 9300001, 'tv', 1, 1, 'WATCHING', NULL),
    ('f3700000-0000-0000-0000-000000000010', 9300001, 'tv', 2, 3, 'FINISHED', NOW());
-- My own tracking: the series at S1 E2 (ranked #1) and the film.
INSERT INTO public.user_tracking (user_id, title_id, media_type, last_season, last_episode, state) VALUES
    ('f3700000-0000-0000-0000-00000000000a', 9300001, 'tv', 1, 2, 'WATCHING');
INSERT INTO public.user_tracking (user_id, title_id, media_type, state) VALUES
    ('f3700000-0000-0000-0000-00000000000a', 9300002, 'movie', 'WATCHING');
INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score) VALUES
    ('f3700000-0000-0000-0000-00000000000a', 9300001, 'tv', 1, 10.00);

-- A friend's started-watching post for the feed.
INSERT INTO public.activity_logs (user_id, activity_type, title_id, media_type)
VALUES ('f3700000-0000-0000-0000-00000000000b', 'WATCH_STARTED', 9300001, 'tv');

SET LOCAL ROLE authenticated;

-- 1. Signed in only.
SELECT throws_ok($$ SELECT public.get_my_tracking() $$, '42501', NULL, 'get_my_tracking needs a signed-in user');
SELECT throws_ok($$ SELECT * FROM public.get_title_watchers(9300001, 'tv') $$, '42501', NULL,
    'get_title_watchers needs a signed-in user');
SELECT throws_ok($$ SELECT public.get_tracking_stats('tv', 2026) $$, '42501', NULL,
    'get_tracking_stats needs a signed-in user');

SELECT set_config('request.jwt.claims', '{"sub":"f3700000-0000-0000-0000-00000000000a","role":"authenticated"}', true);

-- 2. Watchers: only accepted follows I can see, and still WATCHING (§5.4, §7.1).
SELECT is((SELECT array_agg(watcher_id ORDER BY watcher_id) FROM public.get_title_watchers(9300001, 'tv')),
    ARRAY['f3700000-0000-0000-0000-00000000000b', 'f3700000-0000-0000-0000-00000000000c']::UUID[],
    'watchers: the public and friends-only friends; not ghost, blocked, unfollowed or finished');
SELECT is((SELECT max(total_watchers) FROM public.get_title_watchers(9300001, 'tv')), 2, 'the total counts them');
SELECT is((SELECT jsonb_exists_any(to_jsonb(w), ARRAY['last_season', 'last_episode', 'state', 'finished_at'])
           FROM public.get_title_watchers(9300001, 'tv') w LIMIT 1), FALSE,
    'a watcher row never carries a place or a state');
SELECT is((SELECT count(*)::INT FROM public.get_title_watchers(9300001, 'movie')), 0,
    'watchers are per canon: nobody watches this id as a movie');

-- 3. get_my_tracking.
SELECT is(jsonb_array_length(public.get_my_tracking() -> 'items'), 2, 'two tracked titles');
SELECT is((SELECT (i ->> 'watched')::INT FROM jsonb_array_elements(public.get_my_tracking() -> 'items') i
           WHERE i ->> 'media_type' = 'tv'), 2, 'watched counts every episode up to the place');
SELECT is((SELECT (i ->> 'aired_total')::INT FROM jsonb_array_elements(public.get_my_tracking() -> 'items') i
           WHERE i ->> 'media_type' = 'tv'), 6, 'aired_total counts cached and fallback seasons');
SELECT is((SELECT i -> 'next_episode' ->> 'name' FROM jsonb_array_elements(public.get_my_tracking() -> 'items') i
           WHERE i ->> 'media_type' = 'tv'), 'Third', 'the next episode comes with its cached name');
SELECT is((SELECT i -> 'last_aired' FROM jsonb_array_elements(public.get_my_tracking() -> 'items') i
           WHERE i ->> 'media_type' = 'tv'), '{"season": 2, "episode": 3}'::jsonb, 'the latest aired episode');
SELECT is((SELECT jsonb_array_length(i -> 'seasons') FROM jsonb_array_elements(public.get_my_tracking() -> 'items') i
           WHERE i ->> 'media_type' = 'tv'), 2, 'the seasons are included');
SELECT is((SELECT (i ->> 'ranked')::BOOLEAN FROM jsonb_array_elements(public.get_my_tracking() -> 'items') i
           WHERE i ->> 'media_type' = 'tv'), TRUE, 'a ranked series says so');
SELECT is((SELECT (i ->> 'rank_position')::INT FROM jsonb_array_elements(public.get_my_tracking() -> 'items') i
           WHERE i ->> 'media_type' = 'tv'), 1, 'and its rank');
SELECT is((SELECT i ->> 'ranked' FROM jsonb_array_elements(public.get_my_tracking() -> 'items') i
           WHERE i ->> 'media_type' = 'movie'), 'false', 'the film is not ranked');
SELECT is((SELECT i -> 'seasons' FROM jsonb_array_elements(public.get_my_tracking() -> 'items') i
           WHERE i ->> 'media_type' = 'movie'), 'null'::jsonb, 'a movie has no seasons');
SELECT is((SELECT i -> 'next_episode' FROM jsonb_array_elements(public.get_my_tracking() -> 'items') i
           WHERE i ->> 'media_type' = 'movie'), 'null'::jsonb, 'a movie has no next episode');
SELECT is((SELECT i -> 'watched' FROM jsonb_array_elements(public.get_my_tracking() -> 'items') i
           WHERE i ->> 'media_type' = 'movie'), 'null'::jsonb, 'a movie has no episode counts');

-- 4. Stats by year, in the caller's timezone (America/New_York): the year boundary moves.
RESET ROLE;
INSERT INTO public.user_tracking_events (user_id, title_id, media_type, kind, season_number, episode_number, created_at) VALUES
    ('f3700000-0000-0000-0000-00000000000a', 9300001, 'tv', 'WATCHED', 1, 1, '2025-12-31 23:30:00+00'),
    ('f3700000-0000-0000-0000-00000000000a', 9300001, 'tv', 'WATCHED', 1, 2, '2026-01-01 03:00:00+00'),
    ('f3700000-0000-0000-0000-00000000000a', 9300001, 'tv', 'REWATCHED', 1, 1, '2025-06-01 12:00:00+00'),
    ('f3700000-0000-0000-0000-00000000000a', 9300001, 'tv', 'WATCHED', 1, 3, '2026-01-01 06:00:00+00'),
    ('f3700000-0000-0000-0000-00000000000a', 9300001, 'tv', 'WATCHED', 2, 1, '2026-02-01 12:00:00+00'),
    ('f3700000-0000-0000-0000-00000000000a', 9300001, 'tv', 'UNWATCHED', 2, 1, '2026-02-02 12:00:00+00'),
    ('f3700000-0000-0000-0000-00000000000a', 9300001, 'tv', 'UNWATCHED', 1, 3, '2024-05-01 12:00:00+00'),
    ('f3700000-0000-0000-0000-00000000000a', 9300001, 'tv', 'WATCHED', 2, 2, '2026-03-01 12:00:00+00');
INSERT INTO public.user_tracking_events (user_id, title_id, media_type, kind, created_at) VALUES
    ('f3700000-0000-0000-0000-00000000000a', 9300002, 'movie', 'FINISHED', '2025-12-31 23:30:00+00'),
    ('f3700000-0000-0000-0000-00000000000a', 9300002, 'movie', 'FINISHED', '2026-01-01 06:00:00+00'),
    ('f3700000-0000-0000-0000-00000000000a', 9300002, 'movie', 'FINISHED', '2026-03-01 12:00:00+00');
SET LOCAL ROLE authenticated;

SELECT is((public.get_tracking_stats('tv', 2025) ->> 'episodes')::INT, 3,
    'episodes in 2025: the two late-December watches (one is 22:00 New York time) and a rewatch');
SELECT is((public.get_tracking_stats('tv', 2026) ->> 'episodes')::INT, 2,
    'episodes in 2026: 3 watched, 1 un-logged');
SELECT is((public.get_tracking_stats('tv', 2024) ->> 'episodes')::INT, 0, 'un-logs never take a year below zero');
SELECT is((public.get_tracking_stats('tv', 2027) ->> 'episodes')::INT, 0, 'an empty year is 0');
SELECT is((public.get_tracking_stats('movie', 2025) ->> 'movies_finished')::INT, 1, 'movies finished in 2025');
SELECT is((public.get_tracking_stats('movie', 2026) ->> 'movies_finished')::INT, 2, 'movies finished in 2026');
SELECT is(jsonb_exists(public.get_tracking_stats('tv', 2026), 'minutes'), FALSE, 'a year has no minutes');

-- 5. This ISO week: episodes and runtime, with minutes null unless every runtime is known.
RESET ROLE;
INSERT INTO public.user_tracking_events (user_id, title_id, media_type, kind, season_number, episode_number, created_at) VALUES
    ('f3700000-0000-0000-0000-00000000000a', 9300001, 'tv', 'WATCHED', 1, 1, NOW()),
    ('f3700000-0000-0000-0000-00000000000a', 9300001, 'tv', 'WATCHED', 1, 2, NOW()),
    ('f3700000-0000-0000-0000-00000000000a', 9300001, 'tv', 'WATCHED', 1, 3, NOW() - INTERVAL '20 days');
INSERT INTO public.user_tracking_events (user_id, title_id, media_type, kind, created_at)
VALUES ('f3700000-0000-0000-0000-00000000000a', 9300002, 'movie', 'FINISHED', NOW());
SET LOCAL ROLE authenticated;

SELECT is(public.get_tracking_stats('tv') -> 'episodes', '2'::jsonb, 'this week: two episodes (the one from 20 days ago is out)');
SELECT is(public.get_tracking_stats('tv') -> 'minutes', '80'::jsonb, 'this week: 2 x 40 minutes');
SELECT is(public.get_tracking_stats('movie') -> 'movies_finished', '1'::jsonb, 'this week: one film finished');

RESET ROLE;
INSERT INTO public.user_tracking_events (user_id, title_id, media_type, kind, season_number, episode_number, created_at)
VALUES ('f3700000-0000-0000-0000-00000000000a', 9300001, 'tv', 'WATCHED', 2, 1, NOW());
SET LOCAL ROLE authenticated;
SELECT is(public.get_tracking_stats('tv') -> 'minutes', 'null'::jsonb,
    'minutes is null once an episode with an unknown runtime is counted');

-- 6. get_my_tracking shows only my own rows.
SELECT set_config('request.jwt.claims', '{"sub":"f3700000-0000-0000-0000-00000000000b","role":"authenticated"}', true);
SELECT is(jsonb_array_length(public.get_my_tracking() -> 'items'), 1, 'B sees only their own tracked title');

-- 7. Feed: tracking rows only for apps that ask for them (§7.2).
SELECT set_config('request.jwt.claims', '{"sub":"f3700000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
SELECT is((SELECT count(*)::INT FROM public.get_activity_feed('following') WHERE activity_type = 'WATCH_STARTED'), 0,
    'older apps never get WATCH_STARTED rows');
SELECT is((SELECT count(*)::INT FROM public.get_activity_feed('following', p_include_tracking => TRUE)
           WHERE activity_type = 'WATCH_STARTED'), 1, 'apps that ask get the row');
SELECT is((SELECT metadata FROM public.get_activity_feed('following', p_include_tracking => TRUE)
           WHERE activity_type = 'WATCH_STARTED'), '{}'::jsonb, 'and it carries no episode data');

SELECT * FROM finish();
ROLLBACK;
