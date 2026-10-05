-- Migration 20261010001200_title_recommendations.sql
-- FE-EXPLORE-03: personalised "Recommended for You" titles for SCR-07 (and the SCR-05
-- feed recommendation cards), plus a "Trending Now" list for the search zero-state.
--
-- Recommendations score every title I have not ranked, queued or muted by genre
-- affinity with my loved titles (score >= 7.80, the Great tier and up), weighting each
-- loved title by how far above 7.80 it sits. A shared director (movies) or network
-- (series) adds a bonus. `reason_title` names the loved title the recommendation is
-- most like ("Because you loved …"). Titles with no affinity fall back to what the
-- community is ranking right now, then to the community score, so a new user with an
-- empty canon still gets a full carousel. Dual-canon: a seed only recommends titles of
-- its own media type.

CREATE OR REPLACE FUNCTION public.get_trending_titles(
    p_media_type public.media_type_enum DEFAULT NULL,
    p_limit INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    PERFORM public._require_user();
    RETURN COALESCE((
        SELECT jsonb_agg(row_to_json(x)::jsonb ORDER BY x.recent_rankings DESC, x.global_community_score DESC NULLS LAST, x.title_id)
        FROM (
            SELECT
                t.id AS title_id,
                t.media_type,
                t.title,
                t.poster_path,
                t.original_network,
                t.global_community_score,
                EXTRACT(YEAR FROM t.release_date)::INT AS release_year,
                count(ur.id)::INT AS recent_rankings
            FROM public.titles t
            LEFT JOIN public.user_rankings ur
                ON ur.title_id = t.id AND ur.media_type = t.media_type
               AND ur.created_at > now() - interval '14 days'
               AND EXISTS (SELECT 1 FROM public.users u WHERE u.id = ur.user_id AND NOT u.is_deleted)
            WHERE p_media_type IS NULL OR t.media_type = p_media_type
            GROUP BY t.id, t.media_type
            ORDER BY recent_rankings DESC, t.global_community_score DESC NULLS LAST, t.id
            LIMIT GREATEST(LEAST(p_limit, 50), 0)
        ) x
    ), '[]'::jsonb);
END;
$$;

REVOKE ALL ON FUNCTION public.get_trending_titles(public.media_type_enum, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_trending_titles(public.media_type_enum, INT) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_recommended_titles(
    p_media_type public.media_type_enum DEFAULT NULL,
    p_limit INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
BEGIN
    RETURN COALESCE((
        WITH loved AS (
            SELECT t.id, t.media_type, t.title, t.genres, t.director, t.original_network,
                   (ur.calculated_score - 7.80 + 0.20)::NUMERIC AS weight
            FROM public.user_rankings ur
            JOIN public.titles t ON t.id = ur.title_id AND t.media_type = ur.media_type
            WHERE ur.user_id = v_user
              AND ur.calculated_score >= 7.80
              AND ur.status <> 'DROPPED'
              AND (p_media_type IS NULL OR ur.media_type = p_media_type)
        ),
        candidates AS (
            SELECT t.*
            FROM public.titles t
            WHERE (p_media_type IS NULL OR t.media_type = p_media_type)
              AND NOT EXISTS (SELECT 1 FROM public.user_rankings r
                              WHERE r.user_id = v_user AND r.title_id = t.id AND r.media_type = t.media_type)
              AND NOT EXISTS (SELECT 1 FROM public.user_watchlist w
                              WHERE w.user_id = v_user AND w.title_id = t.id AND w.media_type = t.media_type)
              AND NOT EXISTS (SELECT 1 FROM public.user_muted_titles m
                              WHERE m.user_id = v_user AND m.title_id = t.id AND m.media_type = t.media_type)
        ),
        pair AS (
            -- How much each candidate resembles each loved title of the same canon.
            SELECT c.id AS cid, c.media_type AS cmt, l.title AS reason_title, l.id AS reason_id,
                   l.weight * (
                       cardinality(ARRAY(SELECT unnest(c.genres) INTERSECT SELECT unnest(l.genres)))
                       + CASE WHEN c.media_type = 'movie' AND c.director IS NOT NULL
                                   AND c.director = l.director THEN 2
                              WHEN c.media_type = 'tv' AND c.original_network IS NOT NULL
                                   AND c.original_network = l.original_network THEN 1
                              ELSE 0 END
                   ) AS affinity
            FROM candidates c
            JOIN loved l ON l.media_type = c.media_type
        ),
        scored AS (
            SELECT c.id, c.media_type, c.title, c.poster_path, c.original_network,
                   c.global_community_score,
                   EXTRACT(YEAR FROM c.release_date)::INT AS release_year,
                   COALESCE((SELECT sum(p.affinity) FROM pair p
                             WHERE p.cid = c.id AND p.cmt = c.media_type), 0) AS affinity,
                   (SELECT p.reason_title FROM pair p
                    WHERE p.cid = c.id AND p.cmt = c.media_type AND p.affinity > 0
                    ORDER BY p.affinity DESC, p.reason_id LIMIT 1) AS reason_title,
                   (SELECT count(*) FROM public.user_rankings ur
                    JOIN public.users u ON u.id = ur.user_id AND NOT u.is_deleted
                    WHERE ur.title_id = c.id AND ur.media_type = c.media_type
                      AND ur.created_at > now() - interval '14 days')::INT AS recent_rankings
            FROM candidates c
        )
        SELECT jsonb_agg(jsonb_build_object(
                   'title_id', s.id,
                   'media_type', s.media_type,
                   'title', s.title,
                   'poster_path', s.poster_path,
                   'original_network', s.original_network,
                   'global_community_score', s.global_community_score,
                   'release_year', s.release_year,
                   'reason_kind', CASE WHEN s.reason_title IS NOT NULL THEN 'because_you_loved'
                                       WHEN s.recent_rankings > 0 THEN 'trending'
                                       ELSE 'top_rated' END,
                   'reason_title', s.reason_title)
               ORDER BY s.affinity DESC, s.recent_rankings DESC,
                        s.global_community_score DESC NULLS LAST, s.id)
        FROM (
            SELECT * FROM scored
            ORDER BY affinity DESC, recent_rankings DESC, global_community_score DESC NULLS LAST, id
            LIMIT GREATEST(LEAST(p_limit, 50), 0)
        ) s
    ), '[]'::jsonb);
END;
$$;

REVOKE ALL ON FUNCTION public.get_recommended_titles(public.media_type_enum, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_recommended_titles(public.media_type_enum, INT) TO authenticated;
