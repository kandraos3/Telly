-- Migration 20261010002900_explore_refresh.sql
-- #177 (epic #46): what the title-related edge function needs to fill the Explore caches.
--
--   * title_related_fetches logs when each seed's TMDB recommendations were last fetched,
--     and how many came back. Without it, a seed with no recommendations leaves no
--     title_related rows and looks "missing" forever, so it would be refetched on every run
--     and every app open.
--   * store_title_related / store_trending replace a seed's related rows or a canon's trending
--     list atomically (service role only). The function upserts the titles first.
--   * stale_explore_seeds lists the seeds (users' top 5 at ≥ 7.80) never fetched, or fetched
--     more than p_max_age_days ago, most shared first, for the scheduled refresh.
--   * get_explore_candidates now reads missing_related from the fetch log. Same signature
--     and output shape; the body is otherwise that of 20261010002800_explore_candidates.sql.
--   * pg_cron 'explore-refresh' calls title-related every 30 minutes.
-- Spec: docs/features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md §7.6.

CREATE TABLE public.title_related_fetches (
    seed_id INT NOT NULL,
    seed_media_type public.media_type_enum NOT NULL,
    fetched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    result_count SMALLINT NOT NULL DEFAULT 0,
    PRIMARY KEY (seed_id, seed_media_type),
    FOREIGN KEY (seed_id, seed_media_type) REFERENCES public.titles(id, media_type) ON DELETE CASCADE
);
ALTER TABLE public.title_related_fetches ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.title_related_fetches FROM anon, authenticated;

-- Seeds cached before the log existed count as fetched when their newest row was.
INSERT INTO public.title_related_fetches (seed_id, seed_media_type, fetched_at, result_count)
SELECT seed_id, seed_media_type, max(fetched_at), count(*)
FROM public.title_related
GROUP BY seed_id, seed_media_type
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.store_title_related(
    p_seed_id INT,
    p_media_type public.media_type_enum,
    p_related JSONB  -- [{"related_id": 27205, "position": 1}, …]; positions outside 1–20 are dropped
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_count INT;
BEGIN
    DELETE FROM public.title_related WHERE seed_id = p_seed_id AND seed_media_type = p_media_type;

    INSERT INTO public.title_related (seed_id, seed_media_type, related_id, position, fetched_at)
    SELECT p_seed_id, p_media_type, (r ->> 'related_id')::INT, (r ->> 'position')::SMALLINT, NOW()
    FROM jsonb_array_elements(COALESCE(p_related, '[]'::jsonb)) r
    WHERE (r ->> 'position')::INT BETWEEN 1 AND 20
      AND (r ->> 'related_id')::INT <> p_seed_id
    ON CONFLICT (seed_id, seed_media_type, related_id) DO NOTHING;
    GET DIAGNOSTICS v_count = ROW_COUNT;

    INSERT INTO public.title_related_fetches (seed_id, seed_media_type, fetched_at, result_count)
    VALUES (p_seed_id, p_media_type, NOW(), v_count)
    ON CONFLICT (seed_id, seed_media_type)
    DO UPDATE SET fetched_at = EXCLUDED.fetched_at, result_count = EXCLUDED.result_count;

    RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.store_trending(p_media_type public.media_type_enum, p_title_ids INT[])
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_count INT;
BEGIN
    DELETE FROM public.trending_titles WHERE media_type = p_media_type;

    INSERT INTO public.trending_titles (media_type, position, title_id, fetched_at)
    SELECT p_media_type, x.ord::SMALLINT, x.id, NOW()
    FROM unnest(COALESCE(p_title_ids, ARRAY[]::INT[])) WITH ORDINALITY AS x(id, ord)
    WHERE x.ord <= 20;
    GET DIAGNOSTICS v_count = ROW_COUNT;

    RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.stale_explore_seeds(p_max_age_days INT DEFAULT 14, p_limit INT DEFAULT 40)
RETURNS TABLE (seed_id INT, media_type public.media_type_enum)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    WITH top5 AS (
        SELECT ur.title_id, ur.media_type,
               row_number() OVER (PARTITION BY ur.user_id, ur.media_type
                                  ORDER BY ur.calculated_score DESC, ur.rank_position, ur.title_id) AS n
        FROM public.user_rankings ur
        JOIN public.users u ON u.id = ur.user_id AND NOT u.is_deleted
        WHERE ur.calculated_score >= 7.80 AND ur.status <> 'DROPPED'
    ),
    seeds AS (
        SELECT title_id, media_type, count(*) AS users
        FROM top5
        WHERE n <= 5
        GROUP BY title_id, media_type
    )
    SELECT s.title_id, s.media_type
    FROM seeds s
    LEFT JOIN public.title_related_fetches f
           ON f.seed_id = s.title_id AND f.seed_media_type = s.media_type
    WHERE f.fetched_at IS NULL OR f.fetched_at < NOW() - make_interval(days => p_max_age_days)
    ORDER BY f.fetched_at IS NOT NULL, s.users DESC, s.title_id
    LIMIT LEAST(GREATEST(p_limit, 0), 200);
$$;

REVOKE ALL ON FUNCTION public.store_title_related(INT, public.media_type_enum, JSONB) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.store_trending(public.media_type_enum, INT[]) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stale_explore_seeds(INT, INT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.store_title_related(INT, public.media_type_enum, JSONB) TO service_role;
GRANT EXECUTE ON FUNCTION public.store_trending(public.media_type_enum, INT[]) TO service_role;
GRANT EXECUTE ON FUNCTION public.stale_explore_seeds(INT, INT) TO service_role;

CREATE OR REPLACE FUNCTION public.get_explore_candidates(p_media_type public.media_type_enum)
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
    WITH
    mine AS (
        -- My non-DROPPED rankings in this canon: the genre profile and the seeds.
        SELECT ur.title_id, ur.calculated_score AS score, ur.rank_position AS rank, t.genres, t.title, t.poster_path
        FROM public.user_rankings ur
        JOIN public.titles t ON t.id = ur.title_id AND t.media_type = ur.media_type
        WHERE ur.user_id = v_user AND ur.media_type = p_media_type AND ur.status <> 'DROPPED'
    ),
    seeds AS (
        SELECT * FROM mine WHERE score >= 7.80
        ORDER BY score DESC, rank, title_id
        LIMIT 5
    ),
    excluded AS (
        -- Anything I've ranked (any status) or muted never comes back.
        SELECT ur.title_id FROM public.user_rankings ur
        WHERE ur.user_id = v_user AND ur.media_type = p_media_type
        UNION
        SELECT m.title_id FROM public.user_muted_titles m
        WHERE m.user_id = v_user AND m.media_type = p_media_type
    ),
    my_services AS (
        SELECT s.platform_id FROM public.user_streaming_subscriptions s WHERE s.user_id = v_user
    ),
    friends AS (
        -- Accepted followees I can see: can_view_user hides blocked (either way), deleted
        -- and ghost profiles.
        SELECT f.following_id AS id
        FROM public.social_follows f
        WHERE f.follower_id = v_user AND f.status = 'accepted' AND public.can_view_user(f.following_id)
    ),
    friend_activity AS (
        SELECT DISTINCT a.user_id, a.title_id
        FROM public.activity_logs a
        JOIN friends fr ON fr.id = a.user_id
        WHERE a.activity_type IN ('RANKING_CREATED', 'QUEUE_ADDED')
          AND a.media_type = p_media_type
          AND a.title_id IS NOT NULL
          AND a.created_at > NOW() - INTERVAL '30 days'
    ),
    community AS (
        SELECT ur.title_id,
               count(*)::INT AS n,
               count(*) FILTER (WHERE ur.created_at > NOW() - INTERVAL '14 days')::INT AS recent
        FROM public.user_rankings ur
        JOIN public.users u ON u.id = ur.user_id AND NOT u.is_deleted
        WHERE ur.media_type = p_media_type
        GROUP BY ur.title_id
    ),
    -- Sources, each limited after exclusions. A lower priority number wins the 200 cap.
    sources AS (
        (SELECT ta.title_id, 1 AS priority
         FROM public.title_availability ta
         JOIN my_services ms ON ms.platform_id = ta.platform_id
         WHERE ta.media_type = p_media_type AND ta.is_leaving_soon
           AND ta.monetization_type IN ('flatrate', 'free', 'ads')
           AND ta.title_id NOT IN (SELECT title_id FROM excluded)
         GROUP BY ta.title_id
         ORDER BY min(ta.available_until), ta.title_id
         LIMIT 20)
        UNION ALL
        (SELECT x.related_id, 2
         FROM (
             SELECT tr.related_id,
                    row_number() OVER (PARTITION BY tr.seed_id ORDER BY tr.position, tr.related_id) AS n
             FROM public.title_related tr
             JOIN seeds s ON s.title_id = tr.seed_id
             WHERE tr.seed_media_type = p_media_type
               AND tr.related_id NOT IN (SELECT title_id FROM excluded)
         ) x
         WHERE x.n <= 20)
        UNION ALL
        (SELECT fa.title_id, 3
         FROM friend_activity fa
         WHERE fa.title_id NOT IN (SELECT title_id FROM excluded)
         GROUP BY fa.title_id
         ORDER BY count(*) DESC, fa.title_id
         LIMIT 30)
        UNION ALL
        (SELECT tt.title_id, 4
         FROM public.trending_titles tt
         WHERE tt.media_type = p_media_type
           AND tt.title_id NOT IN (SELECT title_id FROM excluded))
        UNION ALL
        (SELECT c.title_id, 5
         FROM community c
         WHERE c.recent > 0 AND c.title_id NOT IN (SELECT title_id FROM excluded)
         ORDER BY c.recent DESC, c.title_id
         LIMIT 10)
        UNION ALL
        (SELECT t.id, 6
         FROM public.titles t
         LEFT JOIN community c ON c.title_id = t.id
         WHERE t.media_type = p_media_type
           AND (COALESCE(t.tmdb_vote_count, 0) >= 200 OR COALESCE(c.n, 0) >= 5)
           AND t.id NOT IN (SELECT title_id FROM excluded)
         ORDER BY COALESCE(t.global_community_score, t.tmdb_vote_average) DESC NULLS LAST, t.id
         LIMIT 60)
    ),
    picked AS (
        SELECT title_id, min(priority) AS priority
        FROM sources
        GROUP BY title_id
        ORDER BY min(priority), title_id
        LIMIT 200
    )
    SELECT jsonb_build_object(
        'generated_at', NOW(),
        'media_type', p_media_type,
        'profile', jsonb_build_object(
            'rankings', COALESCE((
                SELECT jsonb_agg(jsonb_build_object('title_id', m.title_id, 'score', m.score,
                                                    'rank', m.rank, 'genres', to_jsonb(m.genres))
                                 ORDER BY m.rank, m.title_id)
                FROM mine m), '[]'::jsonb),
            'seeds', COALESCE((
                SELECT jsonb_agg(jsonb_build_object('title_id', s.title_id, 'title', s.title,
                                                    'poster_path', s.poster_path, 'score', s.score,
                                                    'rank', s.rank)
                                 ORDER BY s.score DESC, s.rank, s.title_id)
                FROM seeds s), '[]'::jsonb),
            'services', COALESCE((SELECT jsonb_agg(ms.platform_id ORDER BY ms.platform_id) FROM my_services ms),
                                 '[]'::jsonb),
            'missing_related', COALESCE((
                SELECT jsonb_agg(s.title_id ORDER BY s.score DESC, s.rank, s.title_id)
                FROM seeds s
                WHERE NOT EXISTS (
                    -- #177: the fetch log, so a seed with no TMDB recommendations isn't refetched forever.
                    SELECT 1 FROM public.title_related_fetches f
                    WHERE f.seed_id = s.title_id AND f.seed_media_type = p_media_type
                      AND f.fetched_at > NOW() - INTERVAL '14 days')), '[]'::jsonb)
        ),
        'candidates', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'title_id', t.id,
                'media_type', t.media_type,
                'title', t.title,
                'poster_path', t.poster_path,
                'backdrop_path', t.backdrop_path,
                'release_year', EXTRACT(YEAR FROM t.release_date)::INT,
                'genres', to_jsonb(t.genres),
                'director', t.director,
                'original_network', t.original_network,
                'collection_id', t.collection_id,
                'community_score', t.global_community_score,
                'community_count', COALESCE(c.n, 0),
                'tmdb_vote_average', t.tmdb_vote_average,
                'tmdb_vote_count', t.tmdb_vote_count,
                'seed_links', COALESCE((
                    SELECT jsonb_agg(jsonb_build_object('seed_id', tr.seed_id, 'position', tr.position)
                                     ORDER BY tr.position, tr.seed_id)
                    FROM public.title_related tr
                    JOIN seeds s ON s.title_id = tr.seed_id
                    WHERE tr.related_id = t.id AND tr.seed_media_type = p_media_type), '[]'::jsonb),
                'trending_rank', (SELECT min(tt.position) FROM public.trending_titles tt
                                  WHERE tt.media_type = p_media_type AND tt.title_id = t.id),
                'telly_recent_rankings', COALESCE(c.recent, 0),
                'friends', COALESCE((
                    SELECT jsonb_agg(jsonb_build_object(
                               'user_id', u.id,
                               'display_name', COALESCE(NULLIF(u.display_name, ''), u.username),
                               'avatar_url', u.avatar_url,
                               'score', fur.calculated_score,
                               'match_pct', tm.match_percentage)
                           ORDER BY fur.calculated_score DESC NULLS LAST, u.id)
                    FROM friend_activity fa
                    JOIN public.users u ON u.id = fa.user_id
                    LEFT JOIN public.user_rankings fur
                           ON fur.user_id = fa.user_id AND fur.title_id = t.id AND fur.media_type = p_media_type
                    LEFT JOIN public.taste_matches tm
                           ON tm.user_a = LEAST(v_user, fa.user_id) AND tm.user_b = GREATEST(v_user, fa.user_id)
                          AND tm.media_type = p_media_type
                    WHERE fa.title_id = t.id), '[]'::jsonb),
                'providers', COALESCE((
                    SELECT jsonb_agg(DISTINCT ta.platform_id)
                    FROM public.title_availability ta
                    WHERE ta.title_id = t.id AND ta.media_type = p_media_type
                      AND ta.monetization_type IN ('flatrate', 'free', 'ads')), '[]'::jsonb),
                'on_my_services', EXISTS (
                    SELECT 1 FROM public.title_availability ta
                    JOIN my_services ms ON ms.platform_id = ta.platform_id
                    WHERE ta.title_id = t.id AND ta.media_type = p_media_type
                      AND ta.monetization_type IN ('flatrate', 'free', 'ads')),
                'leaving_until', (
                    SELECT min(ta.available_until)
                    FROM public.title_availability ta
                    JOIN my_services ms ON ms.platform_id = ta.platform_id
                    WHERE ta.title_id = t.id AND ta.media_type = p_media_type AND ta.is_leaving_soon
                      AND ta.monetization_type IN ('flatrate', 'free', 'ads')),
                'in_queue', EXISTS (
                    SELECT 1 FROM public.user_watchlist w
                    WHERE w.user_id = v_user AND w.title_id = t.id AND w.media_type = p_media_type))
                ORDER BY p.priority, t.id)
            FROM picked p
            JOIN public.titles t ON t.id = p.title_id AND t.media_type = p_media_type
            LEFT JOIN community c ON c.title_id = t.id), '[]'::jsonb)
    ) INTO v_result;

    RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.get_explore_candidates(public.media_type_enum) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_explore_candidates(public.media_type_enum) TO authenticated;

-- Trending (when older than 6 h) and up to 40 stale seeds every half hour.
SELECT cron.schedule('explore-refresh', '*/30 * * * *',
    $$SELECT public._invoke_edge_function('title-related', '{}'::jsonb)$$);
