-- #150 (epic #50): only the title being placed qualifies from a duel (Spec 10 §2).
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(6);

INSERT INTO auth.users (id, email) VALUES
    ('a6000000-0000-0000-0000-00000000000a', 'dp-a@test.dev');

-- Two imported films (no duels), then three films ranked later.
INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score, created_at)
VALUES
    ('a6000000-0000-0000-0000-00000000000a', 550, 'movie', 1, 9.00, '2026-09-01 10:00Z'),
    ('a6000000-0000-0000-0000-00000000000a', 13,  'movie', 2, 8.00, '2026-09-02 10:00Z'),
    ('a6000000-0000-0000-0000-00000000000a', 238, 'movie', 3, 7.00, '2026-09-03 10:00Z'),
    ('a6000000-0000-0000-0000-00000000000a', 680, 'movie', 4, 6.00, '2026-09-04 10:00Z'),
    ('a6000000-0000-0000-0000-00000000000a', 155, 'movie', 5, 5.00, '2026-09-05 10:00Z');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"a6000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);

-- Placing 238 duels it against the imported 13; a tournament duel (no placed title) pairs
-- two new films, 680 and 155.
SELECT public.record_pairwise_duels(
    '[{"client_mutation_id":"d6000000-0000-0000-0000-000000000001","winner_title_id":238,"loser_title_id":13,"media_type":"movie","placed_title_id":238},
      {"client_mutation_id":"d6000000-0000-0000-0000-000000000002","winner_title_id":680,"loser_title_id":155,"media_type":"movie"}]'::jsonb);

SELECT is(
    (SELECT placed_title_id FROM public.pairwise_duels WHERE client_mutation_id = 'd6000000-0000-0000-0000-000000000001'),
    238, 'record_pairwise_duels stores the placed title');
SELECT ok(
    EXISTS (SELECT 1 FROM public.qualifying_rankings
            WHERE user_id = 'a6000000-0000-0000-0000-00000000000a' AND title_id = 238),
    'the placed title qualifies');
SELECT ok(
    NOT EXISTS (SELECT 1 FROM public.qualifying_rankings
                WHERE user_id = 'a6000000-0000-0000-0000-00000000000a' AND title_id = 13),
    'an imported title used as the opponent does not qualify');
SELECT results_eq(
    $$ SELECT title_id FROM public.qualifying_rankings
       WHERE user_id = 'a6000000-0000-0000-0000-00000000000a' AND title_id IN (680, 155)
       ORDER BY title_id $$,
    $$ VALUES (155), (680) $$,
    'a duel with no placed title (tournament, legacy) qualifies both sides');
SELECT ok(
    EXISTS (SELECT 1 FROM public.qualifying_rankings
            WHERE user_id = 'a6000000-0000-0000-0000-00000000000a' AND title_id = 550),
    'the first title in the canon still qualifies');
SELECT throws_ok(
    $$ SELECT public.record_pairwise_duels(
        '[{"client_mutation_id":"d6000000-0000-0000-0000-000000000003","winner_title_id":238,"loser_title_id":680,"media_type":"movie","placed_title_id":550}]'::jsonb) $$,
    '23514', NULL, 'the placed title must be one of the two duelled titles');

SELECT * FROM finish();
ROLLBACK;
