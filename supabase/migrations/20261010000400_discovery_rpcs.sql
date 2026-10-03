-- =============================================================================
-- TELLY DISCOVERY & CATALOG RPCs (BE-605)
-- Specs: SCR-07 Explore, SCR-08 Show Detail (design_system/03), features/07 §3–§5
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. CURATED CANONS (SCR-07 "Curated Canons")
-- -----------------------------------------------------------------------------
CREATE TABLE public.curated_canons (
    slug VARCHAR(64) PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    subtitle VARCHAR(200),
    emoji VARCHAR(8),
    media_type public.media_type_enum,
    items JSONB NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(items) = 'array'),  -- [{title_id, media_type}]
    sort_order INT NOT NULL DEFAULT 0
);
ALTER TABLE public.curated_canons ENABLE ROW LEVEL SECURITY;
CREATE POLICY curated_canons_read ON public.curated_canons FOR SELECT TO authenticated USING (TRUE);
REVOKE ALL ON public.curated_canons FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.curated_canons FROM authenticated;

INSERT INTO public.curated_canons (slug, title, subtitle, emoji, media_type, items, sort_order) VALUES
('stuck-the-landing', 'The "Stuck the Landing" Canon', 'Shows with universally revered final episodes', '🎯', 'tv',
 '[{"title_id":1396,"media_type":"tv"},{"title_id":60059,"media_type":"tv"},{"title_id":76331,"media_type":"tv"},{"title_id":67070,"media_type":"tv"},{"title_id":31911,"media_type":"tv"}]', 1),
('peak-miniseries', 'Peak 1-Season Miniseries', 'Chernobyl, Band of Brothers, Queen''s Gambit', '⚡', 'tv',
 '[{"title_id":87108,"media_type":"tv"},{"title_id":4613,"media_type":"tv"},{"title_id":87739,"media_type":"tv"}]', 2);

-- -----------------------------------------------------------------------------
-- 2. NETWORK BATTLEGROUNDS (features/07 §5) — aggregate only, no per-user data exposed
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_network_battlegrounds(
    p_media_type public.media_type_enum DEFAULT 'tv',
    p_min_rankings INT DEFAULT 3,
    p_limit INT DEFAULT 10
)
RETURNS TABLE (network VARCHAR, avg_score NUMERIC, ranking_count INT, title_count INT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT t.original_network, ROUND(AVG(ur.calculated_score), 2), count(*)::INT, count(DISTINCT t.id)::INT
    FROM public.user_rankings ur
    JOIN public.titles t ON t.id = ur.title_id AND t.media_type = ur.media_type
    JOIN public.users u ON u.id = ur.user_id AND NOT u.is_deleted
    WHERE ur.media_type = p_media_type AND t.original_network IS NOT NULL
    GROUP BY t.original_network
    HAVING count(*) >= p_min_rankings
    ORDER BY 2 DESC, 3 DESC
    LIMIT LEAST(GREATEST(p_limit, 1), 50);
$$;

-- -----------------------------------------------------------------------------
-- 3. FRIENDS ARE CURRENTLY BINGING (SCR-07) — SECURITY INVOKER: RLS limits to visible friends
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_friends_binging(p_limit INT DEFAULT 10, p_days INT DEFAULT 30)
RETURNS TABLE (
    title_id INT,
    media_type public.media_type_enum,
    title VARCHAR,
    poster_path TEXT,
    friend_count INT,
    friends_avg_score NUMERIC,
    friend_ids UUID[]
)
LANGUAGE sql
STABLE
SET search_path = public
AS $$
    WITH friends AS (
        SELECT following_id AS id FROM public.social_follows
        WHERE follower_id = auth.uid() AND status = 'accepted'
    ), recent AS (
        SELECT DISTINCT a.user_id, a.title_id, a.media_type
        FROM public.activity_logs a
        JOIN friends f ON f.id = a.user_id
        WHERE a.activity_type IN ('RANKING_CREATED', 'QUEUE_ADDED')
          AND a.title_id IS NOT NULL
          AND a.created_at > NOW() - make_interval(days => p_days)
    )
    SELECT r.title_id, r.media_type, t.title, t.poster_path,
           count(DISTINCT r.user_id)::INT,
           ROUND(AVG(ur.calculated_score), 2),
           (array_agg(DISTINCT r.user_id))[1:5]
    FROM recent r
    JOIN public.titles t ON t.id = r.title_id AND t.media_type = r.media_type
    LEFT JOIN public.user_rankings ur
           ON ur.user_id = r.user_id AND ur.title_id = r.title_id AND ur.media_type = r.media_type
    GROUP BY r.title_id, r.media_type, t.title, t.poster_path
    ORDER BY 5 DESC, 6 DESC NULLS LAST
    LIMIT LEAST(GREATEST(p_limit, 1), 50);
$$;

-- -----------------------------------------------------------------------------
-- 4. TITLE SOCIAL SUMMARY (SCR-08: your status, friends who ranked, community score, survival rate)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_title_social_summary(
    p_title_id INT,
    p_media_type public.media_type_enum
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_me UUID := public._require_user();
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'my_ranking', (
            SELECT jsonb_build_object(
                'rank_position', ur.rank_position,
                'calculated_score', ur.calculated_score,
                'rating_uncertainty', ur.rating_uncertainty,
                'canon_size', (SELECT count(*) FROM public.user_rankings c WHERE c.user_id = v_me AND c.media_type = p_media_type))
            FROM public.user_rankings ur
            WHERE ur.user_id = v_me AND ur.title_id = p_title_id AND ur.media_type = p_media_type),
        'friends', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                       'user_id', u.id, 'username', u.username, 'display_name', u.display_name,
                       'avatar_url', u.avatar_url, 'rank_position', ur.rank_position,
                       'calculated_score', ur.calculated_score)
                   ORDER BY ur.calculated_score DESC)
            FROM public.social_follows f
            JOIN public.user_rankings ur ON ur.user_id = f.following_id
                 AND ur.title_id = p_title_id AND ur.media_type = p_media_type
            JOIN public.users u ON u.id = f.following_id
            WHERE f.follower_id = v_me AND f.status = 'accepted' AND public.can_view_user(f.following_id)), '[]'::jsonb),
        'community', (
            SELECT jsonb_build_object('avg_score', ROUND(AVG(ur.calculated_score), 2), 'ranking_count', count(*))
            FROM public.user_rankings ur JOIN public.users u ON u.id = ur.user_id AND NOT u.is_deleted
            WHERE ur.title_id = p_title_id AND ur.media_type = p_media_type),
        'survival', (
            WITH s AS (
                SELECT
                    (SELECT count(*) FROM public.user_rankings WHERE title_id = p_title_id AND media_type = p_media_type AND status = 'COMPLETED') AS completed,
                    (SELECT count(*) FROM public.user_rankings WHERE title_id = p_title_id AND media_type = p_media_type AND status = 'WATCHING') AS watching,
                    (SELECT count(*) FROM public.user_dropped_shows WHERE title_id = p_title_id AND media_type = p_media_type) AS dropped
            )
            SELECT jsonb_build_object(
                'completed', s.completed, 'watching', s.watching, 'dropped', s.dropped,
                'completed_pct', CASE WHEN s.completed + s.watching + s.dropped = 0 THEN NULL
                                      ELSE ROUND(100.0 * s.completed / (s.completed + s.watching + s.dropped)) END,
                'common_drop_point', (
                    SELECT jsonb_build_object('season', d.dropped_at_season, 'episode', d.dropped_at_episode, 'count', count(*))
                    FROM public.user_dropped_shows d
                    WHERE d.title_id = p_title_id AND d.media_type = p_media_type AND d.dropped_at_season IS NOT NULL
                    GROUP BY d.dropped_at_season, d.dropped_at_episode
                    ORDER BY count(*) DESC, d.dropped_at_season, d.dropped_at_episode
                    LIMIT 1))
            FROM s)
    ) INTO v_result;
    RETURN v_result;
END;
$$;

-- -----------------------------------------------------------------------------
-- 5. CATALOG MAINTENANCE (service_role only; used by streaming-catalog-sync)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.stale_watchlist_titles(p_older_than_hours INT DEFAULT 24, p_limit INT DEFAULT 50)
RETURNS TABLE (title_id INT, media_type public.media_type_enum)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT DISTINCT w.title_id, w.media_type
    FROM public.user_watchlist w
    WHERE NOT EXISTS (
        SELECT 1 FROM public.title_availability a
        WHERE a.title_id = w.title_id AND a.media_type = w.media_type
          AND a.updated_at > NOW() - make_interval(hours => p_older_than_hours)
    )
    LIMIT p_limit;
$$;

CREATE OR REPLACE FUNCTION public.refresh_leaving_soon_flags(p_today DATE DEFAULT CURRENT_DATE)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_flagged INT;
BEGIN
    UPDATE public.title_availability
    SET is_leaving_soon = (available_until IS NOT NULL AND available_until BETWEEN p_today AND p_today + 7)
    WHERE is_leaving_soon IS DISTINCT FROM (available_until IS NOT NULL AND available_until BETWEEN p_today AND p_today + 7);

    SELECT count(*) INTO v_flagged FROM public.title_availability WHERE is_leaving_soon;
    RETURN v_flagged;
END;
$$;

SELECT cron.schedule('refresh-leaving-soon-flags', '7 4 * * *', $$SELECT public.refresh_leaving_soon_flags()$$);

-- -----------------------------------------------------------------------------
-- 6. GRANTS
-- -----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.get_network_battlegrounds(public.media_type_enum, INT, INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_friends_binging(INT, INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_title_social_summary(INT, public.media_type_enum) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.stale_watchlist_titles(INT, INT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.refresh_leaving_soon_flags(DATE) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.get_network_battlegrounds(public.media_type_enum, INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_friends_binging(INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_title_social_summary(INT, public.media_type_enum) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stale_watchlist_titles(INT, INT) TO service_role;
GRANT EXECUTE ON FUNCTION public.refresh_leaving_soon_flags(DATE) TO service_role;
