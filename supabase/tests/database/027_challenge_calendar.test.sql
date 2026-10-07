-- #143 (epic #50): calendar entries become challenges; featured flags expire (Spec 10 §8.4).
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(9);

SET LOCAL ROLE service_role;
SELECT public.admin_upsert_calendar_entry(
    '{"slug":"horror-month-2031-10","month":"2031-10-01","template":"genre_month","name":"Horror Month",
      "params":{"genre":"Horror"},"featured":true}'::jsonb);
SELECT public.admin_upsert_calendar_entry(
    '{"slug":"limited-run-2031-10","month":"2031-10-01","template":"limited_series","name":"Limited Run","target":4}'::jsonb);
SELECT public.admin_upsert_calendar_entry(
    '{"slug":"broken-2031-10","month":"2031-10-01","template":"decade","name":"Missing params"}'::jsonb);
SELECT public.admin_upsert_calendar_entry(
    '{"slug":"next-month-2031-11","month":"2031-11-01","template":"genre_month","name":"Later","params":{"genre":"Comedy"}}'::jsonb);

SELECT is(public.schedule_calendar_challenges('2031-10-15'), 2,
    'creates the month''s valid entries and skips one missing its params');
SELECT is(public.schedule_calendar_challenges('2031-10-01'), 0, 'running again creates nothing');

RESET ROLE;
SELECT results_eq(
    $$ SELECT slug, description::TEXT, target, featured, status::TEXT FROM public.challenges
       WHERE slug IN ('horror-month-2031-10', 'limited-run-2031-10') ORDER BY slug $$,
    $$ VALUES ('horror-month-2031-10', 'Rank 8 Horror films', 8, TRUE, 'live'),
              ('limited-run-2031-10', 'Rank 4 limited series', 4, FALSE, 'live') $$,
    'challenges take the template''s rule, description and target unless the entry overrides them');
SELECT results_eq(
    $$ SELECT starts_at, ends_at FROM public.challenges WHERE slug = 'horror-month-2031-10' $$,
    $$ VALUES ('2031-10-01 00:00:00+00'::TIMESTAMPTZ, '2031-11-01 00:00:00+00'::TIMESTAMPTZ) $$,
    'a calendar challenge runs for the whole month (UTC)');
SELECT is((SELECT rule FROM public.challenges WHERE slug = 'horror-month-2031-10'),
    '{"media_type":"movie","filters":[{"type":"genre","any":["Horror"]}]}'::jsonb, 'with the params filled in');
SELECT ok(NOT EXISTS (SELECT 1 FROM public.challenges WHERE slug IN ('broken-2031-10', 'next-month-2031-11')),
    'other months and broken entries are left alone');

-- Featuring next month's challenge leaves this month's featured (#143).
SET LOCAL ROLE service_role;
SELECT public.admin_upsert_calendar_entry(
    '{"slug":"featured-2031-11","month":"2031-11-01","template":"genre_month","name":"November Feature",
      "params":{"genre":"Comedy"},"featured":true}'::jsonb);
SELECT public.schedule_calendar_challenges('2031-11-01');
RESET ROLE;
SELECT results_eq($$ SELECT slug FROM public.challenges WHERE featured AND slug LIKE '%2031%' ORDER BY slug $$,
    $$ VALUES ('featured-2031-11'), ('horror-month-2031-10') $$,
    'months that don''t overlap keep their own featured challenge');

-- An ended featured challenge loses the flag.
INSERT INTO public.challenges (slug, name, starts_at, ends_at, rule, target, status, featured)
VALUES ('old-feature', 'Old', NOW() - INTERVAL '40 days', NOW() - INTERVAL '10 days',
        '{"media_type":"any","filters":[]}', 3, 'live', FALSE);
UPDATE public.challenges SET featured = FALSE WHERE featured;
UPDATE public.challenges SET featured = TRUE WHERE slug = 'old-feature';
SET LOCAL ROLE service_role;
SELECT is(public.expire_featured_challenges(), 1, 'expire_featured_challenges clears ended features');

SET LOCAL ROLE authenticated;
SELECT throws_ok($$ SELECT public.schedule_calendar_challenges('2031-10-01') $$, '42501', NULL,
    'clients cannot run the scheduler');

SELECT * FROM finish();
ROLLBACK;
