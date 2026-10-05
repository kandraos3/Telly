-- Migration 20261010001100_canon_stats.sql
-- FE-PROFILE-03: per-canon viewing stats for the SCR-14 stats header (hours watched,
-- top genre with share, top director / network with title count, total titles).
--
-- Movies sum `titles.runtime_minutes`. TV runtime is not stored per episode
-- (`tmdb-details` keeps it NULL for series), so series hours are estimated from
-- `number_of_episodes` at 45 min per episode, 24 min for anime; titles without an
-- episode count add no hours. `hours_estimated` tells the client to label it "≈".
-- Series have no director, so the top "creator" is the original network.

CREATE OR REPLACE FUNCTION public.get_canon_stats(
    p_media_type public.media_type_enum
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
    v_result JSONB;
BEGIN
    WITH mine AS (
        SELECT t.*
        FROM public.user_rankings ur
        JOIN public.titles t ON t.id = ur.title_id AND t.media_type = ur.media_type
        WHERE ur.user_id = v_user AND ur.media_type = p_media_type
    ),
    totals AS (
        SELECT
            count(*)::INT AS total_titles,
            COALESCE(sum(CASE
                WHEN p_media_type = 'movie' THEN runtime_minutes
                ELSE number_of_episodes * CASE WHEN is_anime THEN 24 ELSE 45 END
            END), 0)::INT AS total_minutes
        FROM mine
    ),
    genre AS (
        SELECT g AS name, count(*)::INT AS n
        FROM mine, unnest(mine.genres) AS g
        GROUP BY g
        ORDER BY n DESC, g
        LIMIT 1
    ),
    creator AS (
        SELECT c AS name, count(*)::INT AS n
        FROM (
            SELECT CASE WHEN p_media_type = 'movie' THEN director ELSE original_network END AS c
            FROM mine
        ) x
        WHERE c IS NOT NULL AND c <> ''
        GROUP BY c
        ORDER BY n DESC, c
        LIMIT 1
    )
    SELECT jsonb_build_object(
        'media_type', p_media_type,
        'total_titles', tt.total_titles,
        'total_minutes', tt.total_minutes,
        'hours_estimated', p_media_type = 'tv',
        'top_genre', (
            SELECT jsonb_build_object('name', g.name, 'count', g.n,
                'percent', round(100.0 * g.n / NULLIF(tt.total_titles, 0))::INT)
            FROM genre g),
        'top_creator', (
            SELECT jsonb_build_object('name', c.name, 'count', c.n,
                'kind', CASE WHEN p_media_type = 'movie' THEN 'director' ELSE 'network' END)
            FROM creator c)
    ) INTO v_result
    FROM totals tt;
    RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.get_canon_stats(public.media_type_enum) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_canon_stats(public.media_type_enum) TO authenticated;
