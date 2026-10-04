-- =============================================================================
-- FE-608: SCR-17 Squads Hub data that RLS alone cannot serve.
--
-- get_squad_members: squad-mates must see each other's names even when a member's
--   profile is FRIENDS_ONLY (users RLS would hide it). Member-gated.
-- squad_shared_watchlist: "Squad Watchlist" = titles several members want to watch;
--   user_watchlist RLS only exposes one's own rows. Member-gated; returns only titles
--   queued by at least two members (or by the only member of a one-person squad).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_squad_members(p_squad_id UUID)
RETURNS TABLE (
    user_id UUID,
    username VARCHAR,
    display_name VARCHAR,
    avatar_url TEXT,
    role VARCHAR,
    joined_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_squad_member(p_squad_id) THEN
        RAISE EXCEPTION 'not a member of this squad' USING ERRCODE = '42501';
    END IF;
    RETURN QUERY
    SELECT m.user_id, u.username, u.display_name, u.avatar_url, m.role, m.joined_at
    FROM public.squad_members m
    JOIN public.users u ON u.id = m.user_id AND NOT u.is_deleted
    WHERE m.squad_id = p_squad_id
    ORDER BY m.joined_at, u.username;
END;
$$;

CREATE OR REPLACE FUNCTION public.squad_shared_watchlist(p_squad_id UUID)
RETURNS TABLE (
    title_id INT,
    media_type public.media_type_enum,
    title VARCHAR,
    poster_path TEXT,
    queued_by INT,
    member_count INT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_members INT;
BEGIN
    IF NOT public.is_squad_member(p_squad_id) THEN
        RAISE EXCEPTION 'not a member of this squad' USING ERRCODE = '42501';
    END IF;
    SELECT count(*)::INT INTO v_members FROM public.squad_members WHERE squad_id = p_squad_id;

    RETURN QUERY
    SELECT w.title_id, w.media_type, t.title, t.poster_path, count(*)::INT, v_members
    FROM public.user_watchlist w
    JOIN public.squad_members m ON m.user_id = w.user_id AND m.squad_id = p_squad_id
    JOIN public.titles t ON t.id = w.title_id AND t.media_type = w.media_type
    GROUP BY w.title_id, w.media_type, t.title, t.poster_path
    HAVING count(*) >= LEAST(2, v_members)
    ORDER BY count(*) DESC, t.title;
END;
$$;

REVOKE ALL ON FUNCTION public.get_squad_members(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.squad_shared_watchlist(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_squad_members(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.squad_shared_watchlist(UUID) TO authenticated;
