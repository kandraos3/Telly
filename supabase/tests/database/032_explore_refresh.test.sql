-- #177: title_related_fetches, store_title_related, store_trending, stale_explore_seeds,
-- missing_related from the fetch log, and the explore-refresh job (features/07 §7.6).
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(16);

INSERT INTO auth.users (id, email) VALUES
    ('e8000000-0000-0000-0000-000000000001', 'a@refresh.dev'),
    ('e8000000-0000-0000-0000-000000000002', 'b@refresh.dev');

-- Both rank Interstellar 9.80; only A ranks Parasite 9.00; Fight Club 7.00 is below the seed floor.
INSERT INTO public.user_rankings (user_id, title_id, media_type, rank_position, calculated_score) VALUES
    ('e8000000-0000-0000-0000-000000000001', 157336, 'movie', 1, 9.80),
    ('e8000000-0000-0000-0000-000000000001', 496243, 'movie', 2, 9.00),
    ('e8000000-0000-0000-0000-000000000001', 550, 'movie', 3, 7.00),
    ('e8000000-0000-0000-0000-000000000002', 157336, 'movie', 1, 9.80),
    ('e8000000-0000-0000-0000-000000000002', 1396, 'tv', 1, 9.50);

-- Access: clients can't call the writers or read the log.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"e8000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
SELECT throws_ok($$ SELECT public.store_title_related(157336, 'movie', '[]'::jsonb) $$, '42501', NULL,
    'clients cannot write related rows');
SELECT throws_ok($$ SELECT public.store_trending('movie', ARRAY[550]) $$, '42501', NULL,
    'clients cannot write trending');
SELECT throws_ok($$ SELECT * FROM public.stale_explore_seeds() $$, '42501', NULL,
    'clients cannot list stale seeds');
SELECT throws_ok($$ SELECT * FROM public.title_related_fetches $$, '42501', NULL,
    'clients cannot read the fetch log');

-- Nothing fetched yet: every seed is stale, most shared first (Interstellar has two users).
RESET ROLE;
SET LOCAL ROLE service_role;
SELECT results_eq(
    $$ SELECT seed_id, media_type::TEXT FROM public.stale_explore_seeds(14, 10) $$,
    $$ VALUES (157336, 'movie'), (1396, 'tv'), (496243, 'movie') $$,
    'never-fetched seeds are listed, most shared first, and titles under 7.80 are not seeds');

SELECT is(public.store_title_related(157336, 'movie',
    '[{"related_id": 27205, "position": 1}, {"related_id": 155, "position": 2},
      {"related_id": 157336, "position": 3}, {"related_id": 680, "position": 21}]'::jsonb), 2,
    'related rows are stored, skipping the seed itself and positions past 20');
SELECT is((SELECT result_count::INT FROM public.title_related_fetches WHERE seed_id = 157336), 2,
    'the fetch is logged with its result count');

-- A refetch replaces the old rows.
SELECT is(public.store_title_related(157336, 'movie', '[{"related_id": 872585, "position": 1}]'::jsonb), 1,
    'a refetch stores the new list');
SELECT results_eq(
    $$ SELECT related_id FROM public.title_related WHERE seed_id = 157336 $$,
    $$ VALUES (872585) $$,
    'and drops the old one');

-- Parasite has no recommendations: logged with 0 and no longer stale.
SELECT is(public.store_title_related(496243, 'movie', '[]'::jsonb), 0, 'an empty fetch stores nothing');
SELECT results_eq(
    $$ SELECT seed_id FROM public.stale_explore_seeds(14, 10) $$,
    $$ VALUES (1396) $$,
    'logged seeds, even empty ones, are not stale');

UPDATE public.title_related_fetches SET fetched_at = NOW() - INTERVAL '15 days' WHERE seed_id = 496243;
SELECT results_eq(
    $$ SELECT seed_id FROM public.stale_explore_seeds(14, 10) $$,
    $$ VALUES (1396), (496243) $$,
    'a fetch older than 14 days is stale again, after the never-fetched ones');

SELECT is(public.store_trending('movie', ARRAY[550, 155]), 2, 'trending is stored');
SELECT results_eq(
    $$ SELECT position::INT, title_id FROM public.trending_titles WHERE media_type = 'movie' ORDER BY position $$,
    $$ VALUES (1, 550), (2, 155) $$,
    'in the given order');

-- missing_related reads the fetch log: Parasite is stale (15 days), Interstellar is fresh.
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"e8000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
SELECT is(public.get_explore_candidates('movie') -> 'profile' -> 'missing_related', '[496243]'::jsonb,
    'missing_related lists seeds with no fresh fetch, whether or not they have rows');

RESET ROLE;
SELECT is((SELECT count(*)::INT FROM cron.job WHERE jobname = 'explore-refresh' AND schedule = '*/30 * * * *'), 1,
    'explore-refresh runs every 30 minutes');

SELECT * FROM finish();
ROLLBACK;
