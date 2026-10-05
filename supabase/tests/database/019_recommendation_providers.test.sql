-- FE-FEED-02: get_recommended_titles reports where each pick streams.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(3);

INSERT INTO auth.users (id, email) VALUES ('a6000000-0000-0000-0000-00000000000a', 'recs-providers@test.dev');

-- Inception streams on Max and is rentable on Prime Video; rentals are not "streaming on".
INSERT INTO public.title_availability (title_id, media_type, platform_id, monetization_type) VALUES
    (27205, 'movie', 'max', 'flatrate'),
    (27205, 'movie', 'netflix', 'rent');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"a6000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
SELECT public.insert_user_ranking_atomic(155, 'movie', 1);

SELECT is(
    (SELECT r -> 'providers' FROM jsonb_array_elements(public.get_recommended_titles('movie', 50)) r
     WHERE (r ->> 'title_id')::INT = 27205),
    '["max"]'::jsonb,
    'providers lists subscription platforms, not rentals');
SELECT ok(
    (SELECT bool_and(jsonb_typeof(r -> 'providers') = 'array')
     FROM jsonb_array_elements(public.get_recommended_titles('movie', 50)) r),
    'every pick carries a providers array');
SELECT is(
    (SELECT r ->> 'reason_title' FROM jsonb_array_elements(public.get_recommended_titles('movie', 50)) r
     WHERE (r ->> 'title_id')::INT = 27205),
    'The Dark Knight',
    'the FE-EXPLORE-03 fields are unchanged');

SELECT * FROM finish();
ROLLBACK;
