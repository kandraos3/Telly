-- FE-FEED-01: reaction presets and one custom emoji per user per post.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(7);

INSERT INTO auth.users (id, email) VALUES
    ('a5000000-0000-0000-0000-00000000000a', 'react-author@test.dev'),
    ('b5000000-0000-0000-0000-00000000000b', 'react-fan@test.dev');
UPDATE public.users SET username = 'react_author' WHERE id = 'a5000000-0000-0000-0000-00000000000a';
UPDATE public.users SET username = 'react_fan' WHERE id = 'b5000000-0000-0000-0000-00000000000b';

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"a5000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
SELECT public.insert_user_ranking_atomic(155, 'movie', 1);

SELECT set_config('request.jwt.claims', '{"sub":"b5000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);

SELECT lives_ok($$
    INSERT INTO public.feed_reactions (activity_id, user_id, reaction_type)
    SELECT id, 'b5000000-0000-0000-0000-00000000000b', 'MASTERPIECE' FROM public.activity_logs WHERE user_id = 'a5000000-0000-0000-0000-00000000000a'
$$, 'the new presets are valid reactions');

SELECT lives_ok($$
    INSERT INTO public.feed_reactions (activity_id, user_id, reaction_type, emoji)
    SELECT id, 'b5000000-0000-0000-0000-00000000000b', 'EMOJI', '🍿' FROM public.activity_logs WHERE user_id = 'a5000000-0000-0000-0000-00000000000a'
$$, 'a custom emoji is stored as an EMOJI reaction');

SELECT throws_ok($$
    INSERT INTO public.feed_reactions (activity_id, user_id, reaction_type, emoji)
    SELECT id, 'b5000000-0000-0000-0000-00000000000b', 'EMOJI', '😂' FROM public.activity_logs WHERE user_id = 'a5000000-0000-0000-0000-00000000000a'
$$, '23505', NULL, 'one custom emoji per user per post');

SELECT throws_ok($$
    INSERT INTO public.feed_reactions (activity_id, user_id, reaction_type, emoji)
    SELECT id, 'b5000000-0000-0000-0000-00000000000b', 'KUDOS', '👏' FROM public.activity_logs WHERE user_id = 'a5000000-0000-0000-0000-00000000000a'
$$, '23514', NULL, 'only EMOJI reactions carry an emoji');

SELECT throws_ok($$
    INSERT INTO public.feed_reactions (activity_id, user_id, reaction_type)
    SELECT id, 'b5000000-0000-0000-0000-00000000000b', 'EMOJI' FROM public.activity_logs WHERE user_id = 'a5000000-0000-0000-0000-00000000000a'
$$, '23514', NULL, 'an EMOJI reaction needs its emoji');

SELECT is(
    (SELECT reaction_counts FROM public.get_activity_feed('global') WHERE id = (SELECT id FROM public.activity_logs WHERE user_id = 'a5000000-0000-0000-0000-00000000000a')),
    '{"MASTERPIECE": 1, "EMOJI:🍿": 1}'::jsonb,
    'the feed counts presets by type and custom emoji by emoji');
SELECT set_eq(
    $$ SELECT unnest(my_reactions) FROM public.get_activity_feed('global') WHERE id = (SELECT id FROM public.activity_logs WHERE user_id = 'a5000000-0000-0000-0000-00000000000a') $$,
    ARRAY['MASTERPIECE', 'EMOJI:🍿'],
    'my_reactions reports my custom emoji too');

SELECT * FROM finish();
ROLLBACK;
