-- #145 (epic #50): XP ledger, levels, quests, rewards and the weekly table (Spec 10 §5, §6, §9.8).
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(20);

-- ---------------------------------------------------------------- the curve
SELECT results_eq(
    $$ SELECT xp, public._level_for_xp(xp) FROM unnest(ARRAY[0, 249, 250, 16500, 19499, 19500]) AS t(xp) $$,
    $$ VALUES (0, 1), (249, 1), (250, 2), (16500, 12), (19499, 12), (19500, 13) $$,
    'levels follow 250 × L: level 2 at 250, 12 at 16,500, 13 at 19,500');
SELECT is(public._level_name(1) || ',' || public._level_name(12) || ',' || public._level_name(30),
    'Extra,Cinephile,Legend', 'level names');

-- ---------------------------------------------------------------- fixtures
-- L ranks twelve duelled films in one week (Monday 2026-09-28, UTC) and follows F.
INSERT INTO auth.users (id, email) VALUES
    ('ac000000-0000-0000-0000-00000000000a', 'lv-l@test.dev'),
    ('ad000000-0000-0000-0000-00000000000d', 'lv-f@test.dev'),
    ('ae000000-0000-0000-0000-00000000000e', 'lv-x@test.dev');
UPDATE public.users SET username = 'lv_l', display_name = 'Lou' WHERE id = 'ac000000-0000-0000-0000-00000000000a';
UPDATE public.users SET username = 'lv_f', display_name = 'Fay' WHERE id = 'ad000000-0000-0000-0000-00000000000d';
INSERT INTO public.social_follows (follower_id, following_id, status)
VALUES ('ac000000-0000-0000-0000-00000000000a', 'ad000000-0000-0000-0000-00000000000d', 'accepted');

INSERT INTO public.titles (id, media_type, title, release_date, genres)
SELECT 970000 + k, 'movie', 'Level Film ' || k, '2000-01-01', ARRAY['Drama'] FROM generate_series(1, 20) AS k;

INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score, created_at)
SELECT 'ac000000-0000-0000-0000-00000000000a', 970000 + k, 'movie', k, 5.00,
       TIMESTAMPTZ '2026-09-28 10:00Z' + k * INTERVAL '1 hour'
FROM generate_series(1, 12) AS k;
INSERT INTO public.pairwise_duels (user_id, winner_title_id, loser_title_id, media_type, placed_title_id)
SELECT 'ac000000-0000-0000-0000-00000000000a', 970000 + k, 970000 + CASE WHEN k = 1 THEN 2 ELSE 1 END, 'movie', 970000 + k
FROM generate_series(1, 12) AS k;
SELECT public.evaluate_achievements('ac000000-0000-0000-0000-00000000000a', FALSE);

-- ---------------------------------------------------------------- awarding
SELECT is((SELECT count(*)::INT FROM public.xp_ledger
           WHERE user_id = 'ac000000-0000-0000-0000-00000000000a' AND source = 'ranking'),
    10, 'at most 10 rankings a week earn XP');
SELECT results_eq(
    $$ SELECT source::TEXT, sum(amount)::INT FROM public.xp_ledger
       WHERE user_id = 'ac000000-0000-0000-0000-00000000000a' GROUP BY source ORDER BY source $$,
    $$ VALUES ('medal', 25), ('ranking', 100), ('streak', 25) $$,
    '+10 a ranking, +25 for the counted week, +25 for Ticket Stub');
SELECT is((SELECT week FROM public.xp_ledger
           WHERE user_id = 'ac000000-0000-0000-0000-00000000000a' AND source = 'streak'),
    '2026-W40', 'XP is filed under the week it was earned');
SELECT is(public._award_xp('ac000000-0000-0000-0000-00000000000a'), 0, 'awarding again adds nothing');

-- Re-ranking a title earns nothing; neither does an unduelled (imported) ranking.
DELETE FROM public.user_rankings WHERE user_id = 'ac000000-0000-0000-0000-00000000000a' AND title_id = 970001;
INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score, created_at) VALUES
    ('ac000000-0000-0000-0000-00000000000a', 970001, 'movie', 13, 5.00, '2026-10-06 10:00Z'),
    ('ac000000-0000-0000-0000-00000000000a', 970020, 'movie', 14, 5.00, '2026-10-06 11:00Z');
SELECT public.evaluate_achievements('ac000000-0000-0000-0000-00000000000a', FALSE);
SELECT is((SELECT count(*)::INT FROM public.xp_ledger
           WHERE user_id = 'ac000000-0000-0000-0000-00000000000a' AND ref = 'movie:970001'),
    1, 're-ranking a title earns no new XP');
SELECT ok(NOT EXISTS (SELECT 1 FROM public.xp_ledger
                      WHERE user_id = 'ac000000-0000-0000-0000-00000000000a' AND ref = 'movie:970020'),
    'an imported (unduelled) ranking earns nothing');

-- Collections +100; challenges +150 seasonal and +100 squad.
INSERT INTO public.title_collections (collection_id, name, part_ids, released_part_ids)
VALUES (880, 'Level Saga Collection', ARRAY[970002, 970003], ARRAY[970002, 970003]);
INSERT INTO public.squads (id, name, created_by)
VALUES ('5e000000-0000-0000-0000-000000000001', 'XP Squad', 'ac000000-0000-0000-0000-00000000000a');
INSERT INTO public.challenges (slug, name, starts_at, ends_at, rule, target, status, squad_id) VALUES
    ('season-xp', 'Season', '2026-09-01', '2026-10-01', '{"media_type":"any","filters":[]}', 1, 'live', NULL),
    ('squad-xp', 'Squad', '2026-09-01', '2026-10-01', '{"media_type":"any","filters":[]}', 1, 'live',
     '5e000000-0000-0000-0000-000000000001');
INSERT INTO public.challenge_participants (challenge_id, user_id, completed_at)
SELECT id, 'ac000000-0000-0000-0000-00000000000a', '2026-09-29' FROM public.challenges WHERE slug IN ('season-xp', 'squad-xp')
ON CONFLICT (challenge_id, user_id) DO UPDATE SET completed_at = EXCLUDED.completed_at;
SELECT public.evaluate_achievements('ac000000-0000-0000-0000-00000000000a', FALSE);
SELECT results_eq(
    $$ SELECT source::TEXT, amount FROM public.xp_ledger
       WHERE user_id = 'ac000000-0000-0000-0000-00000000000a' AND source IN ('collection', 'challenge')
       ORDER BY source, amount $$,
    $$ VALUES ('challenge', 100), ('challenge', 150), ('collection', 100) $$,
    'a finished collection +100; challenges +150 seasonal and +100 squad');

-- Quests: one met in the ranked week completes and pays its XP.
INSERT INTO public.user_quests (user_id, week, slot, quest_key, title, kind, rule, target, xp)
VALUES ('ac000000-0000-0000-0000-00000000000a', '2026-W40', 1, 'rank_three', 'Rank 3 titles this week', 'rule',
        '{"media_type":"any","filters":[]}', 3, 40);
SELECT public.evaluate_achievements('ac000000-0000-0000-0000-00000000000a', FALSE);
SELECT results_eq(
    $$ SELECT q.completed_at IS NOT NULL, l.amount FROM public.user_quests q
       JOIN public.xp_ledger l ON l.user_id = q.user_id AND l.source = 'quest' AND l.ref = '2026-W40:rank_three'
       WHERE q.user_id = 'ac000000-0000-0000-0000-00000000000a' AND q.week = '2026-W40' $$,
    $$ VALUES (TRUE, 40) $$, 'a met quest completes and pays its XP');

-- ---------------------------------------------------------------- the ledger is append-only
SELECT throws_ok($$ UPDATE public.xp_ledger SET amount = 999 WHERE user_id = 'ac000000-0000-0000-0000-00000000000a' $$,
    '42501', NULL, 'ledger rows are never updated');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"ac000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
SELECT throws_ok(
    $$ INSERT INTO public.xp_ledger (user_id, amount, source, ref, week)
       VALUES (auth.uid(), 1000, 'correction', 'cheat', '2026-W40') $$,
    '42501', NULL, 'clients cannot write XP');

-- ---------------------------------------------------------------- my_level and quests
SELECT results_eq(
    $$ SELECT level, name, total_xp, level_floor, level_ceiling FROM public.my_level() $$,
    $$ VALUES (2, 'Extra'::TEXT, 565, 250, 750) $$,
    'my_level: 150 + 25 (a second counted week) + 100 + 250 + 40 = 565, level 2 of 250 to 750');
SELECT results_eq(
    $$ SELECT slot::INT, difficulty FROM public.my_week() $$,
    $$ VALUES (1, 'easy'), (2, 'explore'), (3, 'queue') $$,
    'three quests a week: easy, exploration, Queue');
SELECT results_eq(
    $$ SELECT quest_key FROM public.my_week() ORDER BY slot $$,
    $$ SELECT quest_key FROM public.user_quests WHERE user_id = auth.uid() AND week = public._week_label(NOW(), 'UTC') ORDER BY slot $$,
    'they are stored, so asking again gives the same three');
SELECT unalike((SELECT title FROM public.my_week() WHERE slot = 2), '%$%',
    'the exploration quest names a genre or decade');

-- ---------------------------------------------------------------- rewards
SELECT throws_ok($$ SELECT public.equip_reward('lime_frame') $$, '22023', NULL, 'rewards stay locked below their level');
RESET ROLE;
INSERT INTO public.xp_ledger (user_id, amount, source, ref, week)
VALUES ('ac000000-0000-0000-0000-00000000000a', 2500, 'correction', 'test boost', '2026-W40');
SET LOCAL ROLE authenticated;
SELECT public.equip_reward('lime_frame');
SELECT results_eq(
    $$ SELECT id, unlocked, equipped FROM public.my_rewards() WHERE unlocked $$,
    $$ VALUES ('lime_frame', TRUE, TRUE) $$,
    'at level 5 the lime frame unlocks and can be equipped');

-- ---------------------------------------------------------------- the weekly table
SELECT results_eq(
    $$ SELECT username, is_me FROM public.weekly_xp_table() ORDER BY username $$,
    $$ VALUES ('lv_f'::VARCHAR, FALSE), ('lv_l'::VARCHAR, TRUE) $$,
    'friends this week: me and the people I follow');
SELECT set_config('request.jwt.claims', '{"sub":"ae000000-0000-0000-0000-00000000000e","role":"authenticated"}', true);
SELECT throws_ok($$ SELECT * FROM public.weekly_xp_table('5e000000-0000-0000-0000-000000000001') $$, '42501', NULL,
    'a squad table is for its members only');

SELECT * FROM finish();
ROLLBACK;
