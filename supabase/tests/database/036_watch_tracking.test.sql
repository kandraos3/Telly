-- #225 (epic #168): tracking tables, RLS and the write RPCs (features/11 section 4, 6.1, 6.2).
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(61);

INSERT INTO auth.users (id, email) VALUES
    ('f3600000-0000-0000-0000-00000000000a', 'a@tracking.dev'),
    ('f3600000-0000-0000-0000-00000000000b', 'b@tracking.dev');

-- Season air dates are long past, so the season fallback airs everything of an Ended show, and
-- every season but the last of a Returning Series. Nothing here depends on today's date.
INSERT INTO public.titles (id, media_type, title, status) VALUES
    (9200001, 'tv', 'Ended Show', 'Ended'),
    (9200002, 'tv', 'Running Show', 'Returning Series'),
    (9200003, 'movie', 'A Movie', NULL),
    (9200004, 'tv', 'Long Show', 'Ended'),
    (9200005, 'tv', 'Dropped At Episode', 'Ended'),
    (9200006, 'tv', 'Dropped At Season', 'Ended');
INSERT INTO public.tv_seasons (title_id, season_number, episode_count, air_date) VALUES
    (9200001, 1, 3, '2000-01-01'), (9200001, 2, 4, '2001-01-01'),
    (9200002, 1, 3, '2000-01-01'), (9200002, 2, 3, '2001-01-01'),
    (9200004, 1, 120, '2000-01-01'),
    (9200005, 1, 5, '2000-01-01'), (9200005, 2, 5, '2001-01-01'),
    (9200006, 1, 5, '2000-01-01'), (9200006, 2, 5, '2001-01-01'), (9200006, 3, 5, '2002-01-01');

INSERT INTO public.user_watchlist (user_id, title_id, media_type) VALUES
    ('f3600000-0000-0000-0000-00000000000a', 9200001, 'tv');
INSERT INTO public.user_dropped_shows (user_id, title_id, media_type, dropped_at_season, dropped_at_episode, reason) VALUES
    ('f3600000-0000-0000-0000-00000000000a', 9200005, 'tv', 1, 2, 'PACING_SLOWED'),
    ('f3600000-0000-0000-0000-00000000000a', 9200006, 'tv', 3, NULL, 'PACING_SLOWED');

SET LOCAL ROLE authenticated;

-- 1. Signed in only.
SELECT throws_ok($$ SELECT public.start_tracking(9200001, 'tv') $$, '42501', NULL,
    'start_tracking needs a signed-in user');

SELECT set_config('request.jwt.claims', '{"sub":"f3600000-0000-0000-0000-00000000000a","role":"authenticated"}', true);

-- 2. Start a series from the beginning (§4.1).
SELECT is((SELECT state::TEXT FROM public.start_tracking(9200001, 'tv', NULL, NULL, FALSE,
        'f3610000-0000-0000-0000-000000000001')),
    'WATCHING', 'start_tracking begins in WATCHING');
SELECT is((SELECT count(*)::INT FROM public.user_watchlist WHERE title_id = 9200001), 0,
    'starting removes the title from the Queue');
SELECT is((SELECT count(*)::INT FROM public.activity_logs WHERE activity_type = 'WATCH_STARTED' AND title_id = 9200001), 1,
    'starting posts WATCH_STARTED');
SELECT is((SELECT (metadata = '{}'::jsonb) FROM public.activity_logs
           WHERE activity_type = 'WATCH_STARTED' AND title_id = 9200001), TRUE,
    'the feed event carries no episode data');

-- 3. Replay is a no-op (I-5), and starting an already-tracked title changes nothing.
SELECT lives_ok($$ SELECT public.start_tracking(9200001, 'tv', NULL, NULL, FALSE,
        'f3610000-0000-0000-0000-000000000001') $$, 'replaying a mutation id succeeds');
SELECT lives_ok($$ SELECT public.start_tracking(9200001, 'tv', 2, 3, FALSE,
        'f3610000-0000-0000-0000-000000000002') $$, 'starting a tracked title again succeeds');
SELECT is((SELECT count(*)::INT FROM public.activity_logs WHERE activity_type = 'WATCH_STARTED' AND title_id = 9200001), 1,
    'no second WATCH_STARTED');
SELECT is((SELECT last_season FROM public.user_tracking WHERE title_id = 9200001), NULL::INT,
    'starting again does not move the place');

-- 4. Moving forward appends WATCHED events (§3.6).
SELECT is((SELECT last_episode FROM public.set_tracking_place(9200001, 'tv', 1, 2,
        'f3610000-0000-0000-0000-000000000003')), 2, 'the place moves to S1 E2');
SELECT is((SELECT count(*)::INT FROM public.user_tracking_events WHERE title_id = 9200001 AND kind = 'WATCHED'), 2,
    'two episodes passed, two WATCHED events');

-- 5. The last episode of an Ended show finishes it.
SELECT is((SELECT state::TEXT FROM public.set_tracking_place(9200001, 'tv', 2, 4,
        'f3610000-0000-0000-0000-000000000004')), 'FINISHED', 'the last episode of an ended show is FINISHED');
SELECT isnt((SELECT finished_at FROM public.user_tracking WHERE title_id = 9200001), NULL::TIMESTAMPTZ,
    'finished_at is set');
SELECT is((SELECT count(*)::INT FROM public.activity_logs WHERE activity_type = 'WATCH_FINISHED' AND title_id = 9200001), 1,
    'finishing posts WATCH_FINISHED');
SELECT is((SELECT count(*)::INT FROM public.user_tracking_events WHERE title_id = 9200001 AND kind = 'WATCHED'), 7,
    'seven episodes watched in all');

-- 6. Un-log: the place moves back and the state follows.
SELECT is((SELECT state::TEXT FROM public.set_tracking_place(9200001, 'tv', 2, 3,
        'f3610000-0000-0000-0000-000000000005')), 'WATCHING', 'un-logging the last episode returns to WATCHING');
SELECT is((SELECT finished_at FROM public.user_tracking WHERE title_id = 9200001), NULL::TIMESTAMPTZ,
    'finished_at is cleared');
SELECT is((SELECT count(*)::INT FROM public.user_tracking_events WHERE title_id = 9200001 AND kind = 'UNWATCHED'), 1,
    'one UNWATCHED event');

-- 7. Rewatching an episode keeps the place.
SELECT lives_ok($$ SELECT public.log_episode_rewatch(9200001, 1, 1, 'f3610000-0000-0000-0000-000000000006') $$,
    'log_episode_rewatch succeeds');
SELECT is((SELECT count(*)::INT FROM public.user_tracking_events WHERE title_id = 9200001 AND kind = 'REWATCHED'), 1,
    'one REWATCHED event');
SELECT is((SELECT last_season * 10 + last_episode FROM public.user_tracking WHERE title_id = 9200001), 23,
    'the place is still S2 E3');
SELECT throws_ok($$ SELECT public.log_episode_rewatch(9200001, 2, 9, 'f3610000-0000-0000-0000-000000000007') $$,
    '22023', NULL, 'an episode that does not exist cannot be rewatched');

-- 8. finish_tracking puts a series at its last aired episode; WATCH_FINISHED is throttled to once per 30 days.
SELECT is((SELECT last_season * 10 + last_episode FROM public.finish_tracking(9200001, 'tv',
        'f3610000-0000-0000-0000-000000000008')), 24, 'finish_tracking moves to the last aired episode');
SELECT is((SELECT count(*)::INT FROM public.activity_logs WHERE activity_type = 'WATCH_FINISHED' AND title_id = 9200001), 1,
    'WATCH_FINISHED is throttled to once per title per 30 days');

-- 9. Watch again resets the place on a FINISHED title.
SELECT is((SELECT is_rewatch FROM public.start_tracking(9200001, 'tv', NULL, NULL, TRUE,
        'f3610000-0000-0000-0000-000000000009')), TRUE, 'watch again sets is_rewatch');
SELECT is((SELECT last_season FROM public.user_tracking WHERE title_id = 9200001), NULL::INT,
    'watch again resets the place');
SELECT is((SELECT state::TEXT FROM public.user_tracking WHERE title_id = 9200001), 'WATCHING',
    'watch again is WATCHING');
SELECT is((SELECT count(*)::INT FROM public.activity_logs WHERE activity_type = 'WATCH_STARTED' AND title_id = 9200001), 1,
    'WATCH_STARTED is throttled too');

-- 10. Stopping deletes the row and keeps the events (§4.9).
SELECT lives_ok($$ SELECT public.stop_tracking(9200001, 'tv', 'f3610000-0000-0000-0000-00000000000a') $$,
    'stop_tracking succeeds');
SELECT is((SELECT count(*)::INT FROM public.user_tracking WHERE title_id = 9200001), 0, 'the row is gone');
SELECT cmp_ok((SELECT count(*)::INT FROM public.user_tracking_events WHERE title_id = 9200001), '>', 0,
    'the events stay');

-- 11. Movies: no place, no CAUGHT_UP, one FINISHED event.
SELECT throws_ok($$ SELECT public.start_tracking(9200003, 'movie', 1, 1) $$, '22023', NULL,
    'a movie has no place');
SELECT is((SELECT state::TEXT FROM public.start_tracking(9200003, 'movie', NULL, NULL, FALSE,
        'f3610000-0000-0000-0000-00000000000b')), 'WATCHING', 'a movie starts in WATCHING');
SELECT is((SELECT state::TEXT FROM public.finish_tracking(9200003, 'movie',
        'f3610000-0000-0000-0000-00000000000c')), 'FINISHED', 'finishing a movie');
SELECT is((SELECT count(*)::INT FROM public.user_tracking_events WHERE title_id = 9200003 AND kind = 'FINISHED'), 1,
    'one FINISHED event');
SELECT is((SELECT count(*)::INT FROM public.activity_logs WHERE activity_type = 'WATCH_FINISHED' AND title_id = 9200003), 1,
    'finishing a movie posts WATCH_FINISHED');
SELECT lives_ok($$ SELECT public.finish_tracking(9200003, 'movie', 'f3610000-0000-0000-0000-00000000000d') $$,
    'finishing a finished movie succeeds');
SELECT is((SELECT count(*)::INT FROM public.user_tracking_events WHERE title_id = 9200003 AND kind = 'FINISHED'), 1,
    'finishing again records nothing');
SELECT throws_ok($$ SELECT public.set_tracking_place(9200003, 'movie', 1, 1) $$, '22023', NULL,
    'a movie cannot be moved');
SELECT is((SELECT is_rewatch FROM public.start_tracking(9200003, 'movie', NULL, NULL, TRUE,
        'f3610000-0000-0000-0000-00000000000e')), TRUE, 'watching a movie again sets is_rewatch');
SELECT is((SELECT state::TEXT FROM public.user_tracking WHERE title_id = 9200003), 'WATCHING',
    'a rewatched movie is WATCHING again');

-- 12. A running show is CAUGHT_UP when only the unaired latest season follows.
SELECT is((SELECT state::TEXT FROM public.start_tracking(9200002, 'tv', 1, 3, FALSE,
        'f3610000-0000-0000-0000-00000000000f')), 'CAUGHT_UP', 'caught up on a running show');

-- 13. Not tracked.
SELECT throws_ok($$ SELECT public.set_tracking_place(9200004, 'tv', 1, 2) $$, 'P0002', NULL,
    'set_tracking_place needs a tracked title');
SELECT throws_ok($$ SELECT public.finish_tracking(9200004, 'tv') $$, 'P0002', NULL,
    'finish_tracking needs a tracked title');

-- 14. At most 50 events per write, the ones nearest the new place.
SELECT lives_ok($$ SELECT public.start_tracking(9200004, 'tv') $$, 'start the long show');
SELECT lives_ok($$ SELECT public.set_tracking_place(9200004, 'tv', 1, 100) $$, 'jump to E100');
SELECT is((SELECT count(*)::INT FROM public.user_tracking_events WHERE title_id = 9200004 AND kind = 'WATCHED'), 50,
    'a long jump records 50 events');
SELECT is((SELECT min(episode_number) FROM public.user_tracking_events WHERE title_id = 9200004 AND kind = 'WATCHED'), 51,
    'the events are the 50 nearest the new place');
SELECT lives_ok($$ SELECT public.set_tracking_place(9200004, 'tv', 1, 10) $$, 'un-log back to E10');
SELECT is((SELECT count(*)::INT FROM public.user_tracking_events WHERE title_id = 9200004 AND kind = 'UNWATCHED'), 50,
    'a long un-log records 50 events');

-- 15. Revive from the Graveyard (§4.7).
SELECT is((SELECT last_season * 10 + last_episode FROM public.revive_dropped_show(9200005,
        'f3610000-0000-0000-0000-000000000010')), 12, 'revive resumes at the drop point');
SELECT is((SELECT count(*)::INT FROM public.user_dropped_shows WHERE title_id = 9200005), 0,
    'revive removes the graveyard entry');
SELECT is((SELECT count(*)::INT FROM public.activity_logs WHERE activity_type = 'WATCH_STARTED' AND title_id = 9200005), 0,
    'revive posts no activity');
SELECT is((SELECT last_season * 10 + last_episode FROM public.revive_dropped_show(9200006,
        'f3610000-0000-0000-0000-000000000011')), 25, 'a season-only drop resumes at the end of the season before');
SELECT throws_ok($$ SELECT public.revive_dropped_show(9200001) $$, 'P0002', NULL,
    'only a dropped show can be revived');

-- 16. RLS and privileges.
SELECT throws_ok($$ INSERT INTO public.user_tracking (user_id, title_id, media_type)
                    VALUES ('f3600000-0000-0000-0000-00000000000a', 9200001, 'tv') $$,
    '42501', NULL, 'clients cannot write user_tracking directly');
SELECT throws_ok($$ SELECT public._user_today('f3600000-0000-0000-0000-00000000000a') $$,
    '42501', NULL, 'internal helpers are not callable by clients');
SELECT throws_ok($$ INSERT INTO public.tv_episodes (title_id, season_number, episode_number)
                    VALUES (9200001, 1, 1) $$,
    '42501', NULL, 'clients cannot write the episode cache');

SELECT set_config('request.jwt.claims', '{"sub":"f3600000-0000-0000-0000-00000000000b","role":"authenticated"}', true);
SELECT is((SELECT count(*)::INT FROM public.user_tracking), 0, 'another user sees none of my tracking');
SELECT is((SELECT count(*)::INT FROM public.user_tracking_events), 0, 'or my events');

-- 17. A movie can never be CAUGHT_UP, and its place stays empty.
RESET ROLE;
SELECT throws_ok($$ INSERT INTO public.user_tracking (user_id, title_id, media_type, state)
                    VALUES ('f3600000-0000-0000-0000-00000000000b', 9200003, 'movie', 'CAUGHT_UP') $$,
    '23514', NULL, 'a movie cannot be CAUGHT_UP');

SELECT * FROM finish();
ROLLBACK;
