-- FE-607: get_activity_feed card fields (release year, upset "over" title, in_my_queue).
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(9);

INSERT INTO auth.users (id, email) VALUES
    ('a1000000-0000-0000-0000-00000000000a', 'feed-a@test.dev'),
    ('b1000000-0000-0000-0000-00000000000b', 'feed-b@test.dev');
UPDATE public.users SET username = 'feed_a' WHERE id = 'a1000000-0000-0000-0000-00000000000a';
UPDATE public.users SET username = 'feed_b' WHERE id = 'b1000000-0000-0000-0000-00000000000b';

SET LOCAL ROLE authenticated;

-- B ranks 238 (#1) over 155 (#2), then tags 238.
SELECT set_config('request.jwt.claims', '{"sub":"b1000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);
SELECT public.insert_user_ranking_atomic(238, 'movie', 1);
SELECT public.insert_user_ranking_atomic(155, 'movie', 2);
UPDATE public.user_rankings SET tags = ARRAY['Mind-Bending'] WHERE title_id = 238 AND media_type = 'movie';

-- An upset alert as record_pairwise_duels writes it (no ranking_id; loser in metadata).
RESET ROLE;
INSERT INTO public.activity_logs (user_id, activity_type, title_id, media_type, is_upset, upset_delta, metadata)
VALUES ('b1000000-0000-0000-0000-00000000000b', 'UPSET_ALERT', 238, 'movie', TRUE, 0.31,
        '{"loser_title_id": 155}'::jsonb);
SET LOCAL ROLE authenticated;

SELECT set_config('request.jwt.claims', '{"sub":"a1000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
CREATE TEMP TABLE upset AS
    SELECT * FROM public.get_activity_feed('global', NULL, 100)
    WHERE activity_type = 'UPSET_ALERT' AND user_id = 'b1000000-0000-0000-0000-00000000000b';

SELECT is((SELECT count(*)::INT FROM upset), 1, 'the upset is in the global feed');
SELECT is((SELECT rank_position FROM upset), 1, 'upset rows carry the poster''s live rank of the winner');
SELECT is((SELECT upset_over_title FROM upset), (SELECT title FROM public.titles WHERE id = 155 AND media_type = 'movie'),
    'upset_over_title names the duel loser');
SELECT is((SELECT upset_over_rank FROM upset), 2, 'upset_over_rank is the loser''s rank in the poster''s canon');
SELECT is((SELECT tags FROM upset), ARRAY['Mind-Bending']::TEXT[], 'ranking tags are returned');
SELECT is((SELECT release_year FROM upset),
    (SELECT EXTRACT(YEAR FROM release_date)::INT FROM public.titles WHERE id = 238 AND media_type = 'movie'),
    'release_year comes from titles');

SELECT is((SELECT bool_or(in_my_queue) FROM public.get_activity_feed('global', NULL, 100) WHERE title_id = 238),
    FALSE, 'not queued yet');
INSERT INTO public.user_watchlist (user_id, title_id, media_type)
    VALUES ('a1000000-0000-0000-0000-00000000000a', 238, 'movie');
SELECT is((SELECT bool_and(in_my_queue) FROM public.get_activity_feed('global', NULL, 100)
           WHERE title_id = 238 AND user_id = 'b1000000-0000-0000-0000-00000000000b'),
    TRUE, 'in_my_queue reflects the viewer''s watchlist');

-- Hidden (moderated) comments do not count.
INSERT INTO public.comments (activity_id, user_id, body)
    SELECT id, 'a1000000-0000-0000-0000-00000000000a', 'visible' FROM upset;
RESET ROLE;
INSERT INTO public.comments (activity_id, user_id, body, is_hidden)
    SELECT id, 'a1000000-0000-0000-0000-00000000000a', 'hidden by moderation', TRUE FROM upset;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"a1000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
SELECT is((SELECT comment_count FROM public.get_activity_feed('global', NULL, 100) WHERE id = (SELECT id FROM upset)),
    1, 'comment_count excludes hidden comments');

SELECT * FROM finish();
ROLLBACK;
