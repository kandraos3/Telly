-- BE-605: discovery & catalog RPCs (SCR-07 / SCR-08).
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(12);

INSERT INTO auth.users (id, email) VALUES
    ('d1000000-0000-0000-0000-000000000001', 'me@test.dev'),
    ('d2000000-0000-0000-0000-000000000002', 'friend@test.dev'),
    ('d3000000-0000-0000-0000-000000000003', 'stranger@test.dev');
UPDATE public.users SET username = 'friend_one', display_name = 'Friend' WHERE id = 'd2000000-0000-0000-0000-000000000002';
UPDATE public.users SET visibility_mode = 'FRIENDS_ONLY' WHERE id = 'd3000000-0000-0000-0000-000000000003';

SET LOCAL ROLE authenticated;

SELECT set_config('request.jwt.claims', '{"sub":"d2000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
SELECT public.insert_user_ranking_atomic(1396, 'tv', 1);   -- Breaking Bad (AMC)
SELECT public.insert_user_ranking_atomic(76331, 'tv', 2);  -- Succession (HBO)
SELECT public.insert_user_ranking_atomic(1399, 'tv', 3);   -- Game of Thrones (HBO)
INSERT INTO public.user_dropped_shows (user_id, title_id, media_type, dropped_at_season, dropped_at_episode, reason)
    VALUES ('d2000000-0000-0000-0000-000000000002', 66732, 'tv', 3, 4, 'PACING_SLOWED');

SELECT set_config('request.jwt.claims', '{"sub":"d3000000-0000-0000-0000-000000000003","role":"authenticated"}', true);
SELECT public.insert_user_ranking_atomic(76331, 'tv', 1);
SELECT public.insert_user_ranking_atomic(1399, 'tv', 2);

SELECT set_config('request.jwt.claims', '{"sub":"d1000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
SELECT public.insert_user_ranking_atomic(76331, 'tv', 1);
INSERT INTO public.social_follows (follower_id, following_id)
    VALUES ('d1000000-0000-0000-0000-000000000001', 'd2000000-0000-0000-0000-000000000002');

-- Network battlegrounds: HBO has 4 rankings (Succession x3 + GoT x2 = 5), AMC 1 (below threshold)
SELECT results_eq(
    $$ SELECT network::TEXT, ranking_count FROM public.get_network_battlegrounds('tv', 3) $$,
    $$ VALUES ('HBO', 5) $$,
    'battlegrounds aggregate across all users and apply the minimum-rankings threshold');

-- Friends binging: only accepted followees count; the FRIENDS_ONLY stranger is excluded
SELECT results_eq(
    $$ SELECT title_id, friend_count FROM public.get_friends_binging() ORDER BY title_id $$,
    $$ VALUES (1396, 1), (1399, 1), (76331, 1) $$,
    'friends binging lists titles my accepted followees ranked recently');
SELECT ok((SELECT bool_and(friend_ids = ARRAY['d2000000-0000-0000-0000-000000000002'::UUID]) FROM public.get_friends_binging()),
    'friend avatars only include visible friends');

-- Title social summary
SELECT is((public.get_title_social_summary(76331, 'tv') -> 'my_ranking' ->> 'rank_position')::INT, 1, 'summary includes my rank');
SELECT is((public.get_title_social_summary(76331, 'tv') -> 'my_ranking' ->> 'calculated_score')::NUMERIC, 10.00,
    'summary includes my score');
SELECT is(jsonb_array_length(public.get_title_social_summary(76331, 'tv') -> 'friends'), 1,
    'friends who ranked it: followee only, not the non-followed stranger');
SELECT is((public.get_title_social_summary(76331, 'tv') -> 'community' ->> 'ranking_count')::INT, 3,
    'community count spans all users');
SELECT is((public.get_title_social_summary(66732, 'tv') -> 'survival' ->> 'dropped')::INT, 1, 'survival counts drops');
SELECT is((public.get_title_social_summary(66732, 'tv') -> 'survival' -> 'common_drop_point' ->> 'season')::INT, 3,
    'survival reports the most common drop point');
SELECT is(public.get_title_social_summary(155, 'movie') -> 'my_ranking', 'null'::jsonb, 'unranked title has no my_ranking');

-- Catalog maintenance is service-role only
SELECT throws_ok($$ SELECT public.refresh_leaving_soon_flags() $$, '42501', NULL, 'clients cannot refresh catalog flags');

RESET ROLE;
INSERT INTO public.title_availability (title_id, media_type, platform_id, monetization_type, available_until)
    VALUES (1396, 'tv', 'netflix', 'flatrate', CURRENT_DATE + 3), (76331, 'tv', 'max', 'flatrate', CURRENT_DATE + 30);
SELECT is(public.refresh_leaving_soon_flags(), 1, 'only titles leaving within 7 days are flagged');

SELECT * FROM finish();
ROLLBACK;
