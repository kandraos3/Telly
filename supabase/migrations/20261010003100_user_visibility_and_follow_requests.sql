-- Migration 20261010003100_user_visibility_and_follow_requests.sql
-- Ticket: #204 (Social: user_profile_settings visibility_mode and follow_requests schema & policies)
-- Spec: docs/adjacent_systems/02_PROFILE_MANAGEMENT_AND_CUSTOMIZATION.md §5
-- Spec: docs/features/04_SOCIAL_GRAPH_FEED_AND_UPSETS.md §8
-- Decision: docs/decisions/0009-social-friends-search-and-privacy.md

-- 1. Extended User Settings & Privacy Table -----------------------------------
CREATE TABLE IF NOT EXISTS public.user_profile_settings (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    visibility_mode public.visibility_mode_enum NOT NULL DEFAULT 'PUBLIC',
    show_graveyard_publicly BOOLEAN NOT NULL DEFAULT TRUE,
    allow_co_watch_invites BOOLEAN NOT NULL DEFAULT TRUE,
    hide_binge_velocity BOOLEAN NOT NULL DEFAULT FALSE,
    auto_blur_spoilers BOOLEAN NOT NULL DEFAULT TRUE,
    pinned_badge_ids TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    header_backdrop_url TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.user_profile_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_profile_settings_select ON public.user_profile_settings
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR public.can_view_user(user_id));

CREATE POLICY user_profile_settings_modify ON public.user_profile_settings
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- 2. Synchronize visibility_mode between users and user_profile_settings -------
CREATE OR REPLACE FUNCTION public.sync_profile_settings_visibility()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.users
    SET visibility_mode = NEW.visibility_mode, updated_at = NOW()
    WHERE id = NEW.user_id AND visibility_mode <> NEW.visibility_mode;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profile_settings_sync_visibility ON public.user_profile_settings;
CREATE TRIGGER trg_profile_settings_sync_visibility
    AFTER INSERT OR UPDATE OF visibility_mode ON public.user_profile_settings
    FOR EACH ROW EXECUTE FUNCTION public.sync_profile_settings_visibility();

CREATE OR REPLACE FUNCTION public.sync_users_to_profile_settings()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.user_profile_settings (user_id, visibility_mode)
    VALUES (NEW.id, NEW.visibility_mode)
    ON CONFLICT (user_id) DO UPDATE
    SET visibility_mode = EXCLUDED.visibility_mode, updated_at = NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_sync_to_profile_settings ON public.users;
CREATE TRIGGER trg_users_sync_to_profile_settings
    AFTER INSERT OR UPDATE OF visibility_mode ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.sync_users_to_profile_settings();

-- Backfill profile settings for all existing users
INSERT INTO public.user_profile_settings (user_id, visibility_mode)
SELECT id, visibility_mode FROM public.users
ON CONFLICT (user_id) DO NOTHING;

-- 3. Follow Requests View -----------------------------------------------------
CREATE OR REPLACE VIEW public.follow_requests AS
SELECT
    follower_id AS requester_id,
    following_id AS target_user_id,
    status,
    created_at,
    updated_at
FROM public.social_follows;

-- 4. Respond to Follow Request RPC --------------------------------------------
CREATE OR REPLACE FUNCTION public.respond_to_follow_request(
    p_requester_id UUID,
    p_approve BOOLEAN
)
RETURNS public.follow_status_enum
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
    v_new_status public.follow_status_enum;
BEGIN
    IF p_approve THEN
        v_new_status := 'accepted';
    ELSE
        v_new_status := 'rejected';
    END IF;

    UPDATE public.social_follows
    SET status = v_new_status, updated_at = NOW()
    WHERE follower_id = p_requester_id AND following_id = v_user;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'follow request not found' USING ERRCODE = 'P0002';
    END IF;

    RETURN v_new_status;
END;
$$;

REVOKE ALL ON FUNCTION public.respond_to_follow_request(UUID, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.respond_to_follow_request(UUID, BOOLEAN) TO authenticated;

-- 5. User Search RPC with Privacy Boundaries (SCR-28) -------------------------
CREATE OR REPLACE FUNCTION public.search_users(
    p_query TEXT,
    p_limit INT DEFAULT 20
)
RETURNS TABLE (
    id UUID,
    username VARCHAR,
    display_name VARCHAR,
    avatar_url TEXT,
    visibility_mode public.visibility_mode_enum,
    follow_status public.follow_status_enum,
    taste_match INT,
    mutual_count INT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
    v_clean TEXT := lower(btrim(ltrim(COALESCE(p_query, ''), '@')));
BEGIN
    IF length(v_clean) = 0 THEN
        RETURN;
    END IF;

    RETURN QUERY
    WITH matches AS (
        SELECT
            u.id,
            u.username,
            u.display_name,
            u.avatar_url,
            u.visibility_mode,
            sf.status AS follow_status,
            tm.blended_match AS taste_match,
            tm.total_mutual AS mutual_count,
            CASE
                WHEN lower(u.username) = v_clean THEN 0
                WHEN lower(u.username) LIKE v_clean || '%' THEN 1
                WHEN lower(u.display_name) LIKE v_clean || '%' THEN 2
                ELSE 3
            END AS match_priority
        FROM public.users u
        LEFT JOIN public.social_follows sf
               ON sf.follower_id = v_user AND sf.following_id = u.id
        LEFT JOIN LATERAL (
            SELECT
                ROUND(AVG(t.match_percentage))::INT AS blended_match,
                SUM(t.mutual_count)::INT AS total_mutual
            FROM public.taste_matches t
            WHERE t.user_a = LEAST(v_user, u.id)
              AND t.user_b = GREATEST(v_user, u.id)
        ) tm ON TRUE
        WHERE NOT u.is_deleted
          AND u.id <> v_user
          AND u.username IS NOT NULL
          AND NOT public.is_blocked_between(u.id, v_user)
          AND (u.visibility_mode <> 'GHOST' OR sf.status = 'accepted')
          AND (
              lower(u.username) LIKE '%' || v_clean || '%'
              OR lower(u.display_name) LIKE '%' || v_clean || '%'
          )
    )
    SELECT
        m.id,
        m.username,
        m.display_name,
        m.avatar_url,
        m.visibility_mode,
        m.follow_status,
        m.taste_match,
        m.mutual_count
    FROM matches m
    ORDER BY
        m.match_priority ASC,
        m.taste_match DESC NULLS LAST,
        m.username ASC
    LIMIT LEAST(GREATEST(COALESCE(p_limit, 20), 1), 50);
END;
$$;

REVOKE ALL ON FUNCTION public.search_users(TEXT, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.search_users(TEXT, INT) TO authenticated;
