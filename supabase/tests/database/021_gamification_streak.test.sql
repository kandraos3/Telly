-- #135 (epic #50): qualifying_rankings, users.timezone / set_timezone and weekly_streak
-- (Spec 10 §2–§3). Every streak call pins "now" to Wednesday 2026-10-14 12:00 UTC, so the
-- current week starts Monday 2026-10-12 (2026-W42).
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(17);

INSERT INTO auth.users (id, email) VALUES
    ('a5000000-0000-0000-0000-00000000000a', 'gs-a@test.dev'),
    ('b5000000-0000-0000-0000-00000000000b', 'gs-b@test.dev'),
    ('c5000000-0000-0000-0000-00000000000c', 'gs-c@test.dev'),
    ('d5000000-0000-0000-0000-00000000000d', 'gs-d@test.dev'),
    ('e5000000-0000-0000-0000-00000000000e', 'gs-e@test.dev');
UPDATE public.users SET visibility_mode = 'GHOST' WHERE id = 'b5000000-0000-0000-0000-00000000000b';

-- A title that exists as both a film and a series with the same TMDB id.
INSERT INTO public.titles (id, media_type, title) VALUES
    (900001, 'movie', 'Twin Film'),
    (900001, 'tv', 'Twin Show');

-- A: eight duelled films. Counted weeks (Mondays): Aug 3, 10, 17, 24, 31, Sep 14, 21, Oct 5.
-- Walking back from Oct 12: current (not yet counted) · Oct 5 counted · Sep 28 frozen
-- (September's freeze) · Sep 21, 14 counted · Sep 7 missed, September's freeze is gone, so
-- the streak is 3 · then a 5-week run in August.
INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score, created_at)
SELECT 'a5000000-0000-0000-0000-00000000000a', t.id, 'movie', t.pos, 5.00, t.at
FROM (VALUES
    (157336, 1, TIMESTAMPTZ '2026-08-03 12:00Z'),
    (496243, 2, '2026-08-11 12:00Z'),
    (129,    3, '2026-08-19 12:00Z'),
    (238,    4, '2026-08-27 12:00Z'),
    (680,    5, '2026-09-06 12:00Z'),
    (693134, 6, '2026-09-15 12:00Z'),
    (155,    7, '2026-09-24 12:00Z'),
    (569094, 8, '2026-10-05 12:00Z')
) AS t(id, pos, at);
INSERT INTO public.pairwise_duels (user_id, winner_title_id, loser_title_id, media_type)
SELECT 'a5000000-0000-0000-0000-00000000000a', id, 278, 'movie'
FROM unnest(ARRAY[157336, 496243, 129, 238, 680, 693134, 155, 569094]) AS id;

-- B (a ghost): a two-film import in one transaction (same created_at, no duels), a later
-- unduelled film, the twin film, a first series and a duelled series still being watched.
INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score, status, created_at)
VALUES
    ('b5000000-0000-0000-0000-00000000000b', 550,    'movie', 1, 9.00, 'COMPLETED', '2026-09-01 10:00Z'),
    ('b5000000-0000-0000-0000-00000000000b', 13,     'movie', 2, 8.00, 'COMPLETED', '2026-09-01 10:00Z'),
    ('b5000000-0000-0000-0000-00000000000b', 27205,  'movie', 3, 7.00, 'COMPLETED', '2026-09-03 10:00Z'),
    ('b5000000-0000-0000-0000-00000000000b', 900001, 'movie', 4, 6.00, 'COMPLETED', '2026-09-04 10:00Z'),
    ('b5000000-0000-0000-0000-00000000000b', 1396,   'tv',    1, 9.00, 'COMPLETED', '2026-09-02 10:00Z'),
    ('b5000000-0000-0000-0000-00000000000b', 8592,   'tv',    2, 8.00, 'WATCHING',  '2026-09-05 10:00Z');
INSERT INTO public.pairwise_duels (user_id, winner_title_id, loser_title_id, media_type) VALUES
    ('b5000000-0000-0000-0000-00000000000b', 900001, 8592, 'tv');

-- C: one first-in-canon film at Sunday 2026-10-11 20:00 UTC, which is already Monday in Tokyo.
INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score, created_at)
VALUES ('c5000000-0000-0000-0000-00000000000c', 155, 'movie', 1, 5.00, '2026-10-11 20:00Z');

-- D: counted Oct 12 and Sep 21; Oct 5 (October's freeze) and Sep 28 (September's) bridge them.
-- E: counted Oct 12 and Sep 14; the gap needs two September freezes, so it breaks and the
-- held October freeze falls back to missed.
INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score, created_at)
VALUES
    ('d5000000-0000-0000-0000-00000000000d', 155, 'movie', 1, 5.00, '2026-09-22 12:00Z'),
    ('d5000000-0000-0000-0000-00000000000d', 238, 'movie', 2, 5.00, '2026-10-13 12:00Z'),
    ('e5000000-0000-0000-0000-00000000000e', 155, 'movie', 1, 5.00, '2026-09-15 12:00Z'),
    ('e5000000-0000-0000-0000-00000000000e', 238, 'movie', 2, 5.00, '2026-10-13 12:00Z');
INSERT INTO public.pairwise_duels (user_id, winner_title_id, loser_title_id, media_type) VALUES
    ('d5000000-0000-0000-0000-00000000000d', 238, 155, 'movie'),
    ('e5000000-0000-0000-0000-00000000000e', 238, 155, 'movie');

SET LOCAL ROLE authenticated;

-- ---------------------------------------------------------------- qualifying rankings (as B)
SELECT set_config('request.jwt.claims', '{"sub":"b5000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);

SELECT is(
    (SELECT count(*)::INT FROM public.qualifying_rankings
     WHERE user_id = 'b5000000-0000-0000-0000-00000000000b' AND title_id IN (550, 13)),
    1, 'a bulk import lets at most one title per canon through, as first in canon');
SELECT ok(
    NOT EXISTS (SELECT 1 FROM public.qualifying_rankings
                WHERE user_id = 'b5000000-0000-0000-0000-00000000000b' AND title_id = 27205),
    'a later ranking with no duel does not qualify');
SELECT ok(
    NOT EXISTS (SELECT 1 FROM public.qualifying_rankings
                WHERE user_id = 'b5000000-0000-0000-0000-00000000000b'
                  AND title_id = 900001 AND media_type = 'movie'),
    'a TV duel does not qualify the film with the same id');
SELECT results_eq(
    $$ SELECT title_id FROM public.qualifying_rankings
       WHERE user_id = 'b5000000-0000-0000-0000-00000000000b' AND media_type = 'tv' $$,
    $$ VALUES (1396) $$,
    'the first series qualifies; a duelled series still being watched does not');

-- ---------------------------------------------------------------- RLS and the streak (as A)
SELECT set_config('request.jwt.claims', '{"sub":"a5000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);

SELECT is(
    (SELECT count(*)::INT FROM public.qualifying_rankings WHERE user_id = 'a5000000-0000-0000-0000-00000000000a'),
    8, 'duelled rankings qualify');
SELECT is(
    (SELECT count(*)::INT FROM public.qualifying_rankings WHERE user_id = 'b5000000-0000-0000-0000-00000000000b'),
    0, 'the view keeps RLS: a ghost''s rankings stay hidden');

SELECT results_eq(
    $$ SELECT current_weeks, best_weeks
       FROM public.weekly_streak('a5000000-0000-0000-0000-00000000000a', '2026-10-14 12:00Z') $$,
    $$ VALUES (3, 5) $$,
    'one freeze a month: the second missed September week ends the streak; August''s run is the best');
SELECT is(
    (SELECT array_agg(w ->> 'status' ORDER BY n)
     FROM public.weekly_streak('a5000000-0000-0000-0000-00000000000a', '2026-10-14 12:00Z') s,
          jsonb_array_elements(s.weeks) WITH ORDINALITY AS e(w, n)),
    ARRAY['counted', 'missed', 'counted', 'counted', 'frozen', 'counted', 'current'],
    'the last 7 weeks, oldest first, with the frozen week and the running week');
SELECT is(
    (SELECT weeks -> 0 ->> 'week' || ' ' || (weeks -> 6 ->> 'week') || ' ' || (weeks -> 6 ->> 'starts_on')
     FROM public.weekly_streak('a5000000-0000-0000-0000-00000000000a', '2026-10-14 12:00Z')),
    '2026-W36 2026-W42 2026-10-12',
    'weeks carry ISO labels and their Monday');
SELECT results_eq(
    $$ SELECT current_weeks, best_weeks
       FROM public.weekly_streak('b5000000-0000-0000-0000-00000000000b', '2026-10-14 12:00Z') $$,
    $$ VALUES (0, 0) $$,
    'a hidden user''s streak reads as zero');

SELECT results_eq(
    $$ SELECT current_weeks, best_weeks
       FROM public.weekly_streak('d5000000-0000-0000-0000-00000000000d', '2026-10-14 12:00Z') $$,
    $$ VALUES (2, 2) $$,
    'freezes from two different months bridge a two-week gap');
SELECT is(
    (SELECT array_agg(w ->> 'status' ORDER BY n)
     FROM public.weekly_streak('e5000000-0000-0000-0000-00000000000e', '2026-10-14 12:00Z') s,
          jsonb_array_elements(s.weeks) WITH ORDINALITY AS e(w, n)),
    ARRAY['missed', 'missed', 'counted', 'missed', 'missed', 'missed', 'counted'],
    'when a gap can''t be bridged, freezes held for it fall back to missed');

-- ---------------------------------------------------------------- time zones (as C)
SELECT set_config('request.jwt.claims', '{"sub":"c5000000-0000-0000-0000-00000000000c","role":"authenticated"}', true);

SELECT throws_ok($$ SELECT public.set_timezone('Mars/Olympus_Mons') $$, '22023', NULL,
    'set_timezone rejects unknown zones');
SELECT throws_ok(
    $$ UPDATE public.users SET timezone = 'Asia/Tokyo' WHERE id = 'c5000000-0000-0000-0000-00000000000c' $$,
    '42501', NULL, 'the time zone column is only writable through set_timezone');

SELECT results_eq(
    $$ SELECT current_weeks, weeks -> 5 ->> 'status', weeks -> 6 ->> 'status'
       FROM public.weekly_streak('c5000000-0000-0000-0000-00000000000c', '2026-10-14 12:00Z') $$,
    $$ VALUES (1, 'counted', 'current') $$,
    'in UTC, Sunday''s ranking counts for last week and the running week does not break it');
SELECT is(public.set_timezone('Asia/Tokyo'), 'Asia/Tokyo', 'set_timezone stores a valid IANA zone');
SELECT results_eq(
    $$ SELECT current_weeks, weeks -> 5 ->> 'status', weeks -> 6 ->> 'status'
       FROM public.weekly_streak('c5000000-0000-0000-0000-00000000000c', '2026-10-14 12:00Z') $$,
    $$ VALUES (1, 'missed', 'counted') $$,
    'in Tokyo the same ranking falls on Monday, so it counts for the current week');

SELECT * FROM finish();
ROLLBACK;
