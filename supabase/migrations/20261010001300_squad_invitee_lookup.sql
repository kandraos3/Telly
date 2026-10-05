-- Migration 20261010001300_squad_invitee_lookup.sql
-- FE-SQUADS-02: resolve a squad invite typed as a handle (`maya`, `@maya`) or an email
-- address to a user, for the SCR-17b invite dialog's live validation.
--
-- Emails live in auth.users, which clients cannot read, so this is a SECURITY DEFINER
-- lookup. Email matching is exact (case-insensitive) and the email is never returned, so
-- the RPC cannot be used to list or harvest addresses. Deleted, GHOST and blocked users
-- stay invisible, as in lookup_profile_card.

CREATE OR REPLACE FUNCTION public.lookup_squad_invitee(p_query TEXT)
RETURNS TABLE (
    id UUID,
    username VARCHAR,
    display_name VARCHAR,
    avatar_url TEXT,
    matched_by TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
    v_query TEXT := lower(btrim(COALESCE(p_query, '')));
    v_is_email BOOLEAN := v_query ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$';
BEGIN
    IF v_query = '' THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT u.id, u.username, u.display_name, u.avatar_url,
           CASE WHEN v_is_email THEN 'email' ELSE 'handle' END
    FROM public.users u
    WHERE NOT u.is_deleted
      AND u.username IS NOT NULL
      AND (u.visibility_mode <> 'GHOST' OR u.id = v_user)
      AND NOT public.is_blocked_between(u.id, v_user)
      AND CASE
              WHEN v_is_email THEN EXISTS (
                  SELECT 1 FROM auth.users au WHERE au.id = u.id AND lower(au.email) = v_query)
              ELSE u.username = ltrim(v_query, '@')
          END
    LIMIT 1;
END;
$$;

REVOKE ALL ON FUNCTION public.lookup_squad_invitee(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lookup_squad_invitee(TEXT) TO authenticated;
