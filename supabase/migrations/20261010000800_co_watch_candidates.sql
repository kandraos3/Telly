-- Migration 20261010000800_co_watch_candidates.sql
-- Candidate pool for Two-to-Watch co-watching decider (FE-610 / Spec 05 §3.1, §5.1).
-- Candidate pool C = Watchlist_A ∪ Watchlist_B ∪ HighRatedNotSeen

CREATE OR REPLACE FUNCTION public.get_co_watch_candidates(
    p_partner_id UUID,
    p_media_type public.media_type_enum DEFAULT 'movie'
)
RETURNS TABLE (
    show_id INT,
    media_type public.media_type_enum,
    title VARCHAR,
    poster_path TEXT,
    runtime_minutes INT,
    network VARCHAR,
    overview TEXT,
    community_score NUMERIC,
    in_watchlist_a BOOLEAN,
    in_watchlist_b BOOLEAN,
    rating_a NUMERIC,
    rating_b NUMERIC,
    available_providers TEXT[],
    vibe_tags TEXT[]
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_me UUID := auth.uid();
BEGIN
    IF v_me IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    RETURN QUERY
    WITH candidate_ids AS (
        -- 1. In User A's watchlist
        SELECT w.title_id
        FROM public.user_watchlist w
        WHERE w.user_id = v_me AND w.media_type = p_media_type

        UNION

        -- 2. In User B's watchlist
        SELECT w.title_id
        FROM public.user_watchlist w
        WHERE w.user_id = p_partner_id AND w.media_type = p_media_type

        UNION

        -- 3. High-rated by user A (>= 8.50) but not ranked by user B
        SELECT r.title_id
        FROM public.user_rankings r
        WHERE r.user_id = v_me
          AND r.media_type = p_media_type
          AND r.calculated_score >= 8.50
          AND NOT EXISTS (
              SELECT 1 FROM public.user_rankings r2
              WHERE r2.user_id = p_partner_id
                AND r2.title_id = r.title_id
                AND r2.media_type = p_media_type
          )

        UNION

        -- 4. High-rated by user B (>= 8.50) but not ranked by user A
        SELECT r.title_id
        FROM public.user_rankings r
        WHERE r.user_id = p_partner_id
          AND r.media_type = p_media_type
          AND r.calculated_score >= 8.50
          AND NOT EXISTS (
              SELECT 1 FROM public.user_rankings r2
              WHERE r2.user_id = v_me
                AND r2.title_id = r.title_id
                AND r2.media_type = p_media_type
          )
    )
    SELECT
        t.id AS show_id,
        t.media_type,
        t.title,
        t.poster_path,
        t.runtime_minutes,
        COALESCE(t.original_network, '') AS network,
        COALESCE(t.overview, '') AS overview,
        COALESCE(t.global_community_score, 8.0) AS community_score,
        EXISTS (
            SELECT 1 FROM public.user_watchlist wa
            WHERE wa.user_id = v_me AND wa.title_id = t.id AND wa.media_type = t.media_type
        ) AS in_watchlist_a,
        EXISTS (
            SELECT 1 FROM public.user_watchlist wb
            WHERE wb.user_id = p_partner_id AND wb.title_id = t.id AND wb.media_type = t.media_type
        ) AS in_watchlist_b,
        (
            SELECT ra.calculated_score FROM public.user_rankings ra
            WHERE ra.user_id = v_me AND ra.title_id = t.id AND ra.media_type = t.media_type
        ) AS rating_a,
        (
            SELECT rb.calculated_score FROM public.user_rankings rb
            WHERE rb.user_id = p_partner_id AND rb.title_id = t.id AND rb.media_type = t.media_type
        ) AS rating_b,
        COALESCE((
            SELECT ARRAY_AGG(DISTINCT ta.platform_id::TEXT)
            FROM public.title_availability ta
            WHERE ta.title_id = t.id AND ta.media_type = t.media_type
        ), ARRAY[]::TEXT[]) AS available_providers,
        COALESCE(t.genres, ARRAY[]::TEXT[]) AS vibe_tags
    FROM candidate_ids c
    JOIN public.titles t ON t.id = c.title_id AND t.media_type = p_media_type;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_co_watch_candidates(UUID, public.media_type_enum) TO authenticated;
