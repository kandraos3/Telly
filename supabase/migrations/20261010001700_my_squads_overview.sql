-- Migration 20261010001700_my_squads_overview.sql
-- FE-SQUADS-03: one call for the SCR-17a "My Squads" cards.
--
-- The list used to read `squads` straight through RLS, which has no member count, no
-- member faces and no role, so every card looked the same. get_my_squads returns, for
-- each squad I belong to (newest first): the squad row, my role, the number of active
-- members, and up to four member previews in join order (owner first).
--
-- SECURITY DEFINER, like get_squad_members: squad-mates see each other's names and
-- avatars even when a profile is FRIENDS_ONLY (users RLS would hide it). It only ever
-- returns squads the caller is a member of. Soft-deleted users are left out of both the
-- count and the previews. Additive: no existing function or column changes.

CREATE OR REPLACE FUNCTION public.get_my_squads()
RETURNS TABLE (
    id UUID,
    name VARCHAR,
    description VARCHAR,
    avatar_url TEXT,
    created_by UUID,
    created_at TIMESTAMPTZ,
    my_role VARCHAR,
    member_count INT,
    member_previews JSONB
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
BEGIN
    RETURN QUERY
    SELECT
        s.id,
        s.name,
        s.description,
        s.avatar_url,
        s.created_by,
        s.created_at,
        me.role,
        (
            SELECT count(*)::INT
            FROM public.squad_members m
            JOIN public.users u ON u.id = m.user_id AND NOT u.is_deleted
            WHERE m.squad_id = s.id
        ),
        COALESCE((
            SELECT jsonb_agg(
                       jsonb_build_object(
                           'user_id', p.user_id,
                           'username', p.username,
                           'display_name', p.display_name,
                           'avatar_url', p.avatar_url,
                           'role', p.role,
                           'joined_at', p.joined_at
                       )
                       ORDER BY p.joined_at, p.username
                   )
            FROM (
                SELECT m.user_id, u.username, u.display_name, u.avatar_url, m.role, m.joined_at
                FROM public.squad_members m
                JOIN public.users u ON u.id = m.user_id AND NOT u.is_deleted
                WHERE m.squad_id = s.id
                ORDER BY m.joined_at, u.username
                LIMIT 4
            ) p
        ), '[]'::JSONB)
    FROM public.squads s
    JOIN public.squad_members me ON me.squad_id = s.id AND me.user_id = v_user
    ORDER BY s.created_at DESC, s.id;
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_squads() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_squads() TO authenticated;
