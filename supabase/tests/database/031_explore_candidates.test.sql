-- #176: get_explore_candidates, title_related, trending_titles (features/07 §7.3, §7.6).
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(27);

-- me, a followed friend, a followed friend I've blocked, and a stranger.
INSERT INTO auth.users (id, email) VALUES
    ('e7000000-0000-0000-0000-000000000001', 'me@explore.dev'),
    ('e7000000-0000-0000-0000-000000000002', 'friend@explore.dev'),
    ('e7000000-0000-0000-0000-000000000003', 'blocked@explore.dev'),
    ('e7000000-0000-0000-0000-000000000004', 'stranger@explore.dev');

-- Fixture movies: 990001–990070 wide pool (300 TMDB votes), 991xxx related to my seeds,
-- 992001–992002 two more seeds, 993002–993020 trending, 994001–994020 leaving Netflix.
INSERT INTO public.titles (id, media_type, title, genres, tmdb_vote_average, tmdb_vote_count)
SELECT g, 'movie', 'Wide ' || g, ARRAY['Drama'], 7.0, 300 FROM generate_series(990001, 990070) g;
INSERT INTO public.titles (id, media_type, title, genres)
SELECT g, 'movie', 'Fixture ' || g, ARRAY['Drama']
FROM (SELECT generate_series(991001, 991520) g
      UNION ALL SELECT generate_series(992001, 992002)
      UNION ALL SELECT generate_series(993002, 993020)
      UNION ALL SELECT generate_series(994001, 994020)) x
WHERE g NOT BETWEEN 991021 AND 991100 AND g NOT BETWEEN 991121 AND 991200
  AND g NOT BETWEEN 991221 AND 991300 AND g NOT BETWEEN 991321 AND 991400
  AND g NOT BETWEEN 991421 AND 991500;

-- My canon. Seeds (≥ 7.80, best first): Interstellar 9.80, Parasite 9.50, 992001 9.00,
-- 992002 8.50, Spirited Away 8.00. The Godfather is below the floor; Pulp Fiction is DROPPED.
INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score, status) VALUES
    ('e7000000-0000-0000-0000-000000000001', 157336, 'movie', 1, 9.80, 'COMPLETED'),
    ('e7000000-0000-0000-0000-000000000001', 496243, 'movie', 2, 9.50, 'COMPLETED'),
    ('e7000000-0000-0000-0000-000000000001', 992001, 'movie', 3, 9.00, 'COMPLETED'),
    ('e7000000-0000-0000-0000-000000000001', 992002, 'movie', 4, 8.50, 'COMPLETED'),
    ('e7000000-0000-0000-0000-000000000001', 129, 'movie', 5, 8.00, 'COMPLETED'),
    ('e7000000-0000-0000-0000-000000000001', 238, 'movie', 6, 6.00, 'COMPLETED'),
    ('e7000000-0000-0000-0000-000000000001', 680, 'movie', 7, 5.00, 'DROPPED'),
    ('e7000000-0000-0000-0000-000000000001', 1396, 'tv', 1, 9.90, 'COMPLETED');

INSERT INTO public.user_muted_titles (user_id, title_id, media_type)
VALUES ('e7000000-0000-0000-0000-000000000001', 693134, 'movie');
INSERT INTO public.user_watchlist (user_id, title_id, media_type)
VALUES ('e7000000-0000-0000-0000-000000000001', 155, 'movie');

-- Related: 20 fresh titles per seed (positions 1–20), plus four seeded titles for
-- Interstellar. 992002's rows are 15 days old, so it is "missing" but still used.
INSERT INTO public.title_related (seed_id, seed_media_type, related_id, position, fetched_at)
SELECT s.seed, 'movie', 991000 + s.k * 100 + p, p,
       CASE WHEN s.seed = 992002 THEN NOW() - INTERVAL '15 days' ELSE NOW() END
FROM (VALUES (157336, 0), (496243, 1), (992001, 2), (992002, 3), (129, 4)) AS s(seed, k),
     generate_series(1, 20) p;
INSERT INTO public.title_related (seed_id, seed_media_type, related_id, position) VALUES
    (157336, 'movie', 27205, 1),   -- Inception
    (157336, 'movie', 155, 2),     -- queued
    (157336, 'movie', 693134, 3),  -- muted
    (157336, 'movie', 872585, 4);  -- Oppenheimer

INSERT INTO public.trending_titles (media_type, position, title_id)
SELECT 'movie', p, 993000 + p FROM generate_series(2, 20) p;
INSERT INTO public.trending_titles (media_type, position, title_id) VALUES
    ('movie', 1, 19995),  -- Avatar
    ('tv', 1, 66732);

-- Services: I have Netflix. Shawshank leaves it in 3 days; Forrest Gump leaves Max.
INSERT INTO public.user_streaming_subscriptions (user_id, platform_id)
VALUES ('e7000000-0000-0000-0000-000000000001', 'netflix');
INSERT INTO public.title_availability (title_id, media_type, platform_id, monetization_type, available_until, is_leaving_soon)
SELECT g, 'movie', 'netflix', 'flatrate', CURRENT_DATE + 5, TRUE FROM generate_series(994001, 994020) g;
INSERT INTO public.title_availability (title_id, media_type, platform_id, monetization_type, available_until, is_leaving_soon) VALUES
    (278, 'movie', 'netflix', 'flatrate', CURRENT_DATE + 3, TRUE),
    (13, 'movie', 'max', 'flatrate', CURRENT_DATE + 2, TRUE);

-- Friends: I follow both (public profiles, so accepted); I've blocked the second.
INSERT INTO public.social_follows (follower_id, following_id) VALUES
    ('e7000000-0000-0000-0000-000000000001', 'e7000000-0000-0000-0000-000000000002'),
    ('e7000000-0000-0000-0000-000000000001', 'e7000000-0000-0000-0000-000000000003');
INSERT INTO public.user_blocks (blocker_id, blocked_id)
VALUES ('e7000000-0000-0000-0000-000000000001', 'e7000000-0000-0000-0000-000000000003');
INSERT INTO public.taste_matches (user_a, user_b, media_type, match_percentage, mutual_count)
VALUES ('e7000000-0000-0000-0000-000000000001', 'e7000000-0000-0000-0000-000000000002', 'movie', 81, 12);
INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score) VALUES
    ('e7000000-0000-0000-0000-000000000002', 550, 'movie', 1, 9.00),     -- Fight Club
    ('e7000000-0000-0000-0000-000000000003', 424, 'movie', 1, 9.40),     -- Schindler's List
    ('e7000000-0000-0000-0000-000000000004', 569094, 'movie', 1, 8.80);  -- Spider-Verse

SET LOCAL ROLE authenticated;

SELECT throws_ok($$ SELECT public.get_explore_candidates('movie') $$, '42501', NULL,
    'candidates require an authenticated user');

SELECT set_config('request.jwt.claims', '{"sub":"e7000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
CREATE TEMP TABLE r ON COMMIT DROP AS SELECT public.get_explore_candidates('movie') AS j;
CREATE TEMP TABLE c ON COMMIT DROP AS
    SELECT x AS cand, (x ->> 'title_id')::INT AS id FROM r, jsonb_array_elements(r.j -> 'candidates') x;

-- Profile
SELECT is(r.j ->> 'media_type', 'movie', 'the payload names its canon') FROM r;
SELECT is(jsonb_array_length(r.j -> 'profile' -> 'rankings'), 6,
    'profile rankings are my non-DROPPED titles in this canon only') FROM r;
SELECT is(jsonb_path_query_array(r.j, '$.profile.seeds[*].title_id'), '[157336, 496243, 992001, 992002, 129]'::jsonb,
    'seeds are my top 5 scored 7.80 or more, best first') FROM r;
SELECT is(r.j -> 'profile' -> 'missing_related', '[992002]'::jsonb,
    'a seed whose related rows are over 14 days old is reported missing') FROM r;
SELECT is(r.j -> 'profile' -> 'services', '["netflix"]'::jsonb, 'my services are listed') FROM r;

-- Exclusions and canon
SELECT is((SELECT count(*)::INT FROM c WHERE id IN (157336, 496243, 992001, 992002, 129, 238, 680)), 0,
    'titles I have ranked, including dropped ones, never come back');
SELECT is((SELECT count(*)::INT FROM c WHERE id = 693134), 0, 'muted titles never come back');
SELECT is((SELECT (cand ->> 'in_queue')::BOOLEAN FROM c WHERE id = 155), TRUE,
    'queued titles come back flagged in_queue');
SELECT is((SELECT count(*)::INT FROM c WHERE cand ->> 'media_type' <> 'movie'), 0,
    'a movie payload holds movies only');
SELECT is((SELECT count(*)::INT FROM c WHERE id = 66732), 0, 'series trending stays out of the movie canon');

-- Sources
SELECT is((SELECT cand -> 'seed_links' FROM c WHERE id = 27205), '[{"seed_id": 157336, "position": 1}]'::jsonb,
    'a related title carries its seed link');
SELECT is((SELECT count(*)::INT FROM c WHERE cand -> 'seed_links' @> '[{"seed_id": 157336}]'), 20,
    'each seed contributes at most 20 related titles, after exclusions');
SELECT is((SELECT (cand ->> 'trending_rank')::INT FROM c WHERE id = 19995), 1, 'trending titles carry their rank');
SELECT is((SELECT (cand ->> 'telly_recent_rankings')::INT FROM c WHERE id = 569094), 1,
    'titles ranked on Telly in the last 14 days count as trending');
SELECT is((SELECT cand ->> 'leaving_until' FROM c WHERE id = 278), (CURRENT_DATE + 3)::TEXT,
    'a title leaving one of my services carries its date');
SELECT is((SELECT (cand ->> 'on_my_services')::BOOLEAN FROM c WHERE id = 278), TRUE, 'and is on my services');
SELECT is((SELECT count(*)::INT FROM c WHERE id = 13), 0, 'leaving a service I lack is not a source');
SELECT is((SELECT cand -> 'friends' FROM c WHERE id = 550),
    '[{"user_id": "e7000000-0000-0000-0000-000000000002", "display_name": null, "avatar_url": null, "score": 9.00, "match_pct": 81}]'::jsonb,
    'a friend''s ranking brings the title, with their score and taste match');
-- Schindler's List can still trend (the community count is anonymous), but never names the blocked friend.
SELECT is((SELECT count(*)::INT FROM c WHERE id = 424 AND cand -> 'friends' <> '[]'::jsonb), 0,
    'a blocked friend never appears as a friend');

-- The cap: leaving (first priority) all survive; the wide pool (last) is cut.
SELECT is((SELECT count(*)::INT FROM c), 200, 'at most 200 candidates');
SELECT is((SELECT count(*)::INT FROM c WHERE id BETWEEN 994001 AND 994020), 20, 'leaving titles win the cap');
SELECT ok((SELECT count(*) FROM c WHERE id BETWEEN 990001 AND 990070) < 60, 'the quality pool gives way first');

-- Caches are read-only for clients; curated canons are gone.
SELECT ok((SELECT count(*) FROM public.title_related) > 0, 'clients can read title_related');
SELECT throws_ok($$ INSERT INTO public.title_related (seed_id, seed_media_type, related_id, position) VALUES (550, 'movie', 13, 1) $$,
    '42501', NULL, 'clients cannot write title_related');
SELECT throws_ok($$ INSERT INTO public.trending_titles (media_type, position, title_id) VALUES ('movie', 1, 550) $$,
    '42501', NULL, 'clients cannot write trending_titles');
SELECT hasnt_table('public', 'curated_canons', 'curated canons are dropped');

SELECT * FROM finish();
ROLLBACK;
