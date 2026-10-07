-- #142 (epic #50): challenges — every rule filter, the time window, film/TV separation,
-- joining and completing, the share toggle and feed opt-in, squad challenges, RLS and the
-- service-role publishing RPC (Spec 10 §8). Dates are relative to NOW() so the test never ages.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(34);

-- A: plays; B: followed by A, sharing off; O: squad owner; C: squad member; D: joins later;
-- X: outsider.
INSERT INTO auth.users (id, email) VALUES
    ('aa000000-0000-0000-0000-00000000000a', 'ch-a@test.dev'),
    ('bb000000-0000-0000-0000-00000000000b', 'ch-b@test.dev'),
    ('cc000000-0000-0000-0000-00000000000c', 'ch-c@test.dev'),
    ('dd000000-0000-0000-0000-00000000000d', 'ch-d@test.dev'),
    ('ee000000-0000-0000-0000-00000000000e', 'ch-o@test.dev'),
    ('ff000000-0000-0000-0000-00000000000f', 'ch-x@test.dev');
UPDATE public.users SET username = 'ch_a', display_name = 'Avery' WHERE id = 'aa000000-0000-0000-0000-00000000000a';
UPDATE public.users SET username = 'ch_b', display_name = 'Blake', share_achievements = FALSE
    WHERE id = 'bb000000-0000-0000-0000-00000000000b';
INSERT INTO public.social_follows (follower_id, following_id, status)
VALUES ('aa000000-0000-0000-0000-00000000000a', 'bb000000-0000-0000-0000-00000000000b', 'accepted');

INSERT INTO public.titles (id, media_type, title, release_date, genres, original_network, production_companies,
                           tv_type, collection_id) VALUES
    (950001, 'movie', 'Horror One',   '1978-10-25', ARRAY['Horror'],             NULL,  ARRAY['A24'], NULL, 500),
    (950002, 'movie', 'Horror Two',   '1982-06-25', ARRAY['Horror'],             NULL,  ARRAY[]::TEXT[], NULL, NULL),
    (950003, 'movie', 'Horror Three', '2019-07-03', ARRAY['Horror', 'Thriller'], NULL,  ARRAY[]::TEXT[], NULL, NULL),
    (950004, 'movie', 'Comedy One',   '1985-07-03', ARRAY['Comedy'],             NULL,  ARRAY[]::TEXT[], NULL, NULL),
    (950005, 'movie', 'Horror Five',  '2005-01-01', ARRAY['Horror'],             NULL,  ARRAY[]::TEXT[], NULL, NULL),
    (950006, 'movie', 'Friend Horror','1999-01-01', ARRAY['Horror'],             NULL,  ARRAY[]::TEXT[], NULL, NULL),
    (950007, 'movie', 'Queue Horror', '2001-01-01', ARRAY['Horror'],             NULL,  ARRAY[]::TEXT[], NULL, NULL),
    (950001, 'tv',    'Horror Show',  '2020-01-01', ARRAY['Horror'],             'HBO', ARRAY[]::TEXT[], 'Miniseries', NULL);

-- ---------------------------------------------------------------- 1. rules (as the owner)
CREATE FUNCTION pg_temp.matching(p_rule JSONB, p_media public.media_type_enum DEFAULT 'movie') RETURNS INT[]
LANGUAGE sql AS $$
    SELECT COALESCE(array_agg(t.id ORDER BY t.id), ARRAY[]::INT[]) FROM public.titles t
    WHERE t.id BETWEEN 950001 AND 950004 AND t.media_type = p_media AND public._title_matches_rule(p_rule, t);
$$;

SELECT is(pg_temp.matching('{"media_type":"movie","filters":[{"type":"genre","any":["Horror"]}]}'),
    ARRAY[950001, 950002, 950003], 'genre');
SELECT is(pg_temp.matching('{"media_type":"movie","filters":[{"type":"decade","any":[1980]}]}'),
    ARRAY[950002, 950004], 'decade');
SELECT is(pg_temp.matching('{"media_type":"movie","filters":[{"type":"collection","any":[500]}]}'),
    ARRAY[950001], 'collection');
SELECT is(pg_temp.matching('{"media_type":"movie","filters":[{"type":"titles","any":[{"id":950004,"media_type":"movie"}]}]}'),
    ARRAY[950004], 'an explicit title list');
SELECT is(pg_temp.matching('{"media_type":"tv","filters":[{"type":"network","any":["HBO"]}]}', 'tv'),
    ARRAY[950001], 'network');
SELECT is(pg_temp.matching('{"media_type":"movie","filters":[{"type":"company","any":["A24"]},{"type":"genre","any":["Horror"]}]}'),
    ARRAY[950001], 'company, combined with another filter (all must match)');
SELECT is(pg_temp.matching('{"media_type":"tv","filters":[{"type":"tv_type","any":["Miniseries"]}]}', 'tv'),
    ARRAY[950001], 'TV type');
SELECT is(pg_temp.matching('{"media_type":"movie","filters":[{"type":"genre","any":["Horror"]}]}', 'tv'),
    ARRAY[]::INT[], 'a film rule never matches a series with the same id');
SELECT throws_ok(
    $$ INSERT INTO public.challenges (slug, name, starts_at, rule, target, status)
       VALUES ('bad-rule', 'Bad', NOW(), '{"media_type":"movie","filters":[{"type":"mood","any":["cosy"]}]}', 3, 'live') $$,
    '23514', NULL, 'unknown filter types are rejected');

-- ---------------------------------------------------------------- 2. a live challenge
INSERT INTO public.challenges (slug, name, description, starts_at, ends_at, rule, target, status, medal_glyph)
VALUES ('spooky-test', 'Spooky', 'Rank 3 horror films', NOW() - INTERVAL '30 days', NOW() + INTERVAL '30 days',
        '{"media_type":"movie","filters":[{"type":"genre","any":["Horror"]}]}', 3, 'live', '8');

-- A: one horror film before the window, two inside it, a horror series and a comedy inside it.
INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score, created_at) VALUES
    ('aa000000-0000-0000-0000-00000000000a', 950001, 'movie', 1, 9.80, NOW() - INTERVAL '40 days'),
    ('aa000000-0000-0000-0000-00000000000a', 950002, 'movie', 2, 7.00, NOW() - INTERVAL '5 days'),
    ('aa000000-0000-0000-0000-00000000000a', 950003, 'movie', 3, 9.50, NOW() - INTERVAL '4 days'),
    ('aa000000-0000-0000-0000-00000000000a', 950004, 'movie', 4, 5.00, NOW() - INTERVAL '3 days'),
    ('aa000000-0000-0000-0000-00000000000a', 950001, 'tv',    1, 9.00, NOW() - INTERVAL '3 days');
INSERT INTO public.pairwise_duels (user_id, winner_title_id, loser_title_id, media_type, placed_title_id)
SELECT 'aa000000-0000-0000-0000-00000000000a', t, 950004, 'movie', t FROM unnest(ARRAY[950002, 950003]) t;
INSERT INTO public.user_watchlist (user_id, title_id, media_type)
VALUES ('aa000000-0000-0000-0000-00000000000a', 950007, 'movie');

-- B: three horror films inside the window, all placed through duels.
INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score, created_at) VALUES
    ('bb000000-0000-0000-0000-00000000000b', 950006, 'movie', 1, 9.00, NOW() - INTERVAL '6 days'),
    ('bb000000-0000-0000-0000-00000000000b', 950002, 'movie', 2, 8.00, NOW() - INTERVAL '5 days'),
    ('bb000000-0000-0000-0000-00000000000b', 950003, 'movie', 3, 7.00, NOW() - INTERVAL '4 days');
INSERT INTO public.pairwise_duels (user_id, winner_title_id, loser_title_id, media_type, placed_title_id)
SELECT 'bb000000-0000-0000-0000-00000000000b', t, 950001, 'movie', t FROM unnest(ARRAY[950006, 950002, 950003]) t;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"aa000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);

SELECT results_eq($$ SELECT slug FROM public.discover_challenges() $$, $$ VALUES ('spooky-test') $$,
    'discover lists the live challenge');
SELECT is(public.join_challenge((SELECT id FROM public.challenges WHERE slug = 'spooky-test')), 2,
    'joining counts earlier rankings inside the window; not before it, not a series, not a comedy');
SELECT results_eq($$ SELECT slug, joined, my_progress, completed_at IS NULL FROM public.my_challenges() $$,
    $$ VALUES ('spooky-test', TRUE, 2, TRUE) $$, 'my_challenges carries my progress');

-- The third horror film arrives through the duel RPC, which completes the challenge.
RESET ROLE;
INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score, created_at)
VALUES ('aa000000-0000-0000-0000-00000000000a', 950005, 'movie', 5, 6.00, NOW() - INTERVAL '1 day');
SET LOCAL ROLE authenticated;
SELECT public.record_pairwise_duels(
    '[{"client_mutation_id":"cd000000-0000-0000-0000-000000000001","winner_title_id":950005,"loser_title_id":950004,"media_type":"movie","placed_title_id":950005}]'::jsonb);

SELECT isnt((SELECT completed_at FROM public.my_challenges() WHERE slug = 'spooky-test'), NULL,
    'reaching the target completes it');
SELECT ok(EXISTS (SELECT 1 FROM public.user_achievements
                  WHERE user_id = auth.uid() AND achievement_id = 'challenge_spooky_test'),
    'and unlocks the challenge medal');
SELECT is(
    (SELECT metadata ->> 'best_title' FROM public.activity_logs
     WHERE user_id = auth.uid() AND activity_type = 'CHALLENGE_COMPLETED'),
    'Horror Three', 'CHALLENGE_COMPLETED names the best of the films that counted');
SELECT is((SELECT count(*)::INT FROM public.get_activity_feed('following', NULL, 100) WHERE activity_type = 'CHALLENGE_COMPLETED'),
    0, 'apps without the challenge card never get those rows');
SELECT is((SELECT count(*)::INT FROM public.get_activity_feed('following', NULL, 100, NULL, TRUE, TRUE)
           WHERE activity_type = 'CHALLENGE_COMPLETED'),
    1, 'apps that ask get them');

SELECT public.leave_challenge((SELECT id FROM public.challenges WHERE slug = 'spooky-test'));
SELECT ok(EXISTS (SELECT 1 FROM public.my_challenges() WHERE slug = 'spooky-test'),
    'a finished challenge cannot be left');

-- B, with sharing off, completes on joining.
SELECT set_config('request.jwt.claims', '{"sub":"bb000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);
SELECT is(public.join_challenge((SELECT id FROM public.challenges WHERE slug = 'spooky-test')), 3,
    'B already has three in the window');
SELECT isnt((SELECT completed_at FROM public.my_challenges() WHERE slug = 'spooky-test'), NULL, 'so B completes at once');
RESET ROLE;
SELECT ok(NOT EXISTS (SELECT 1 FROM public.activity_logs
                      WHERE user_id = 'bb000000-0000-0000-0000-00000000000b' AND activity_type = 'CHALLENGE_COMPLETED'),
    'with sharing off nothing is posted');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"aa000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
SELECT results_eq(
    $$ SELECT username, progress, is_me FROM public.challenge_progress((SELECT id FROM public.challenges WHERE slug = 'spooky-test')) ORDER BY username $$,
    $$ VALUES ('ch_a'::VARCHAR, 3, TRUE), ('ch_b'::VARCHAR, 3, FALSE) $$,
    'challenge_progress lists me and the people I follow');
SELECT results_eq(
    $$ SELECT title_id, source FROM public.challenge_picks((SELECT id FROM public.challenges WHERE slug = 'spooky-test')) $$,
    $$ VALUES (950007, 'queue'), (950006, 'friends') $$,
    'picks: my Queue first, then what friends ranked, never what I ranked');

-- ---------------------------------------------------------------- 3. squad challenges
RESET ROLE;
INSERT INTO public.squads (id, name, created_by) VALUES
    ('5d000000-0000-0000-0000-000000000001', 'Couch Potatoes', 'ee000000-0000-0000-0000-00000000000e');
INSERT INTO public.squad_members (squad_id, user_id, role)
VALUES ('5d000000-0000-0000-0000-000000000001', 'cc000000-0000-0000-0000-00000000000c', 'MEMBER')
ON CONFLICT DO NOTHING;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"cc000000-0000-0000-0000-00000000000c","role":"authenticated"}', true);
SELECT throws_ok(
    $$ SELECT public.create_squad_challenge('5d000000-0000-0000-0000-000000000001', 'genre_month', 'Horror month',
                                            NOW(), NOW() + INTERVAL '30 days', '{"genre":"Horror"}') $$,
    '42501', NULL, 'members cannot create squad challenges');

SELECT set_config('request.jwt.claims', '{"sub":"ee000000-0000-0000-0000-00000000000e","role":"authenticated"}', true);
SELECT throws_ok(
    $$ SELECT public.create_squad_challenge('5d000000-0000-0000-0000-000000000001', 'genre_month', 'Horror month',
                                            NOW(), NOW() + INTERVAL '30 days') $$,
    '22023', NULL, 'a template missing its params is rejected');
SELECT is(
    (SELECT description FROM public.create_squad_challenge('5d000000-0000-0000-0000-000000000001', 'genre_month',
        'Horror month', NOW() - INTERVAL '1 minute', NOW() + INTERVAL '30 days', '{"genre":"Horror"}')),
    'Rank 8 Horror films'::VARCHAR, 'owners create from a template, with its params filled in');

RESET ROLE;
SELECT is(
    (SELECT count(*)::INT FROM public.challenge_participants p JOIN public.challenges c ON c.id = p.challenge_id
     WHERE c.squad_id = '5d000000-0000-0000-0000-000000000001'),
    2, 'every member joins automatically');
INSERT INTO public.squad_members (squad_id, user_id, role)
VALUES ('5d000000-0000-0000-0000-000000000001', 'dd000000-0000-0000-0000-00000000000d', 'MEMBER');
SELECT ok(EXISTS (SELECT 1 FROM public.challenge_participants p JOIN public.challenges c ON c.id = p.challenge_id
                  WHERE c.squad_id = '5d000000-0000-0000-0000-000000000001'
                    AND p.user_id = 'dd000000-0000-0000-0000-00000000000d'),
    'and so do members who join later');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"cc000000-0000-0000-0000-00000000000c","role":"authenticated"}', true);
SELECT ok(EXISTS (SELECT 1 FROM public.my_challenges() WHERE squad_name = 'Couch Potatoes'),
    'members see the squad challenge');
SELECT set_config('request.jwt.claims', '{"sub":"ff000000-0000-0000-0000-00000000000f","role":"authenticated"}', true);
SELECT ok(NOT EXISTS (SELECT 1 FROM public.discover_challenges() WHERE squad_id IS NOT NULL),
    'outsiders never see it in discover');
SELECT is((SELECT count(*)::INT FROM public.challenges WHERE squad_id IS NOT NULL), 0, 'nor through RLS');

-- ---------------------------------------------------------------- 4. publishing
SELECT throws_ok($$ SELECT public.admin_upsert_challenge('{}'::jsonb) $$, '42501', NULL,
    'clients cannot publish challenges');

RESET ROLE;
SET LOCAL ROLE service_role;
SELECT public.admin_upsert_challenge(jsonb_build_object(
    'slug', 'first-feature', 'name', 'First', 'starts_at', NOW() - INTERVAL '1 day', 'target', 3, 'featured', TRUE,
    'rule', '{"media_type":"any","filters":[]}'::jsonb));
SELECT public.admin_upsert_challenge(jsonb_build_object(
    'slug', 'second-feature', 'name', 'Second', 'starts_at', NOW() - INTERVAL '1 day', 'target', 3, 'featured', TRUE,
    'rule', '{"media_type":"any","filters":[]}'::jsonb));
SELECT public.admin_upsert_challenge(jsonb_build_object(
    'slug', 'still-a-draft', 'name', 'Draft', 'starts_at', NOW() - INTERVAL '1 day', 'target', 3, 'status', 'draft',
    'rule', '{"media_type":"any","filters":[]}'::jsonb));
RESET ROLE;
SELECT results_eq($$ SELECT slug FROM public.challenges WHERE featured $$, $$ VALUES ('second-feature') $$,
    'featuring a challenge un-features the previous one');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"ff000000-0000-0000-0000-00000000000f","role":"authenticated"}', true);
SELECT results_eq($$ SELECT slug FROM public.discover_challenges() $$,
    $$ VALUES ('second-feature'), ('spooky-test'), ('first-feature') $$,
    'drafts stay hidden; the featured challenge leads, then the ones ending soonest');

SELECT * FROM finish();
ROLLBACK;
