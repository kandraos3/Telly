-- Migration 20261010001400_co_watch_context.sql
-- FE-COWATCH-01: real context for SCR-16 Two-to-Watch, replacing the hardcoded friend
-- and streaming-service fixtures.
--
-- get_co_watch_partners: the people I follow (accepted), for the "Who's watching?" step
-- when SCR-16 opens without a friend (e.g. from a title's Co-Watch button).
--
-- get_shared_streaming_platforms: the platforms both of us subscribe to. Only the
-- intersection is returned, never the partner's full list, and only when I can view the
-- partner. `mine_set` / `partner_set` tell the client whether either side has set up any
-- services at all; when one hasn't, the client skips the streaming filter rather than
-- hiding every title.

CREATE OR REPLACE FUNCTION public.get_co_watch_partners()
RETURNS TABLE (
    id UUID,
    username VARCHAR,
    display_name VARCHAR,
    avatar_url TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_me UUID := public._require_user();
BEGIN
    RETURN QUERY
    SELECT u.id, u.username, u.display_name, u.avatar_url
    FROM public.social_follows f
    JOIN public.users u ON u.id = f.following_id
    WHERE f.follower_id = v_me
      AND f.status = 'accepted'
      AND NOT u.is_deleted
      AND u.username IS NOT NULL
      AND NOT public.is_blocked_between(u.id, v_me)
    ORDER BY lower(COALESCE(NULLIF(u.display_name, ''), u.username));
END;
$$;

REVOKE ALL ON FUNCTION public.get_co_watch_partners() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_co_watch_partners() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_shared_streaming_platforms(p_partner_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_me UUID := public._require_user();
    v_visible BOOLEAN := public.can_view_user(p_partner_id);
BEGIN
    RETURN jsonb_build_object(
        'shared', COALESCE((
            SELECT jsonb_agg(m.platform_id ORDER BY m.platform_id)
            FROM public.user_streaming_subscriptions m
            JOIN public.user_streaming_subscriptions p
              ON p.platform_id = m.platform_id AND p.user_id = p_partner_id
            WHERE m.user_id = v_me AND v_visible
        ), '[]'::jsonb),
        'mine_set', EXISTS (SELECT 1 FROM public.user_streaming_subscriptions WHERE user_id = v_me),
        'partner_set', v_visible AND EXISTS (
            SELECT 1 FROM public.user_streaming_subscriptions WHERE user_id = p_partner_id)
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_shared_streaming_platforms(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_shared_streaming_platforms(UUID) TO authenticated;
