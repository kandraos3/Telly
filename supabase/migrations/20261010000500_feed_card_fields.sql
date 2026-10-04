-- =============================================================================
-- FE-607: feed card fields (features/04 §2–§3, SCR-05).
--
-- get_activity_feed gains what the client cards render but could not derive:
--   * release_year;
--   * rank/score for UPSET_ALERT rows (they carry no ranking_id): the poster's live ranking
--     of the title;
--   * upset_over_title / upset_over_rank: the duel loser (metadata.loser_title_id) and its
--     current rank in the poster's canon;
--   * in_my_queue: the viewer already has the title queued ([ ✓ In Queue ], §2.2).
-- The return type changes, so the function is dropped and recreated; the contract is
-- otherwise identical (filters, keyset pagination, mutes, RLS as invoker).
-- =============================================================================

DROP FUNCTION IF EXISTS public.get_activity_feed(TEXT, TIMESTAMPTZ, INT, UUID);

CREATE FUNCTION public.get_activity_feed(
    p_filter TEXT DEFAULT 'following',
    p_before TIMESTAMPTZ DEFAULT NULL,
    p_limit INT DEFAULT 20,
    p_before_id UUID DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    username VARCHAR,
    display_name VARCHAR,
    avatar_url TEXT,
    activity_type VARCHAR,
    title_id INT,
    media_type public.media_type_enum,
    title VARCHAR,
    poster_path TEXT,
    release_year INT,
    rank_position INT,
    calculated_score NUMERIC,
    canon_size INT,
    review_short VARCHAR,
    favorite_character VARCHAR,
    tags TEXT[],
    is_upset BOOLEAN,
    upset_delta NUMERIC,
    upset_over_title VARCHAR,
    upset_over_rank INT,
    metadata JSONB,
    created_at TIMESTAMPTZ,
    reaction_counts JSONB,
    my_reactions TEXT[],
    comment_count INT,
    in_my_queue BOOLEAN
)
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
BEGIN
    IF p_filter NOT IN ('following', 'squads', 'global') THEN
        RAISE EXCEPTION 'unknown feed filter %', p_filter USING ERRCODE = '22023';
    END IF;

    RETURN QUERY
    SELECT
        a.id, a.user_id, u.username, u.display_name, u.avatar_url, a.activity_type,
        a.title_id, a.media_type, t.title, t.poster_path,
        EXTRACT(YEAR FROM t.release_date)::INT,
        ur.rank_position, ur.calculated_score,
        (SELECT count(*)::INT FROM public.user_rankings c WHERE c.user_id = a.user_id AND c.media_type = a.media_type),
        ur.review_short, ur.favorite_character, COALESCE(ur.tags, ARRAY[]::TEXT[]),
        a.is_upset, a.upset_delta,
        lt.title, lr.rank_position,
        a.metadata, a.created_at,
        COALESCE((SELECT jsonb_object_agg(rc.reaction_type, rc.n)
                  FROM (SELECT r.reaction_type, count(*) AS n FROM public.feed_reactions r
                        WHERE r.activity_id = a.id GROUP BY r.reaction_type) rc), '{}'::jsonb),
        COALESCE((SELECT array_agg(r.reaction_type::TEXT) FROM public.feed_reactions r
                  WHERE r.activity_id = a.id AND r.user_id = auth.uid()), ARRAY[]::TEXT[]),
        (SELECT count(*)::INT FROM public.comments cm WHERE cm.activity_id = a.id AND NOT cm.is_hidden),
        EXISTS (SELECT 1 FROM public.user_watchlist w
                WHERE w.user_id = auth.uid() AND w.title_id = a.title_id AND w.media_type = a.media_type)
    FROM public.activity_logs a
    JOIN public.users u ON u.id = a.user_id
    LEFT JOIN public.titles t ON t.id = a.title_id AND t.media_type = a.media_type
    -- RANKING_CREATED points at its ranking; other activity types use the poster's live ranking.
    LEFT JOIN LATERAL (
        SELECT r.* FROM public.user_rankings r
        WHERE (a.ranking_id IS NOT NULL AND r.id = a.ranking_id)
           OR (a.ranking_id IS NULL AND r.user_id = a.user_id AND r.title_id = a.title_id
               AND r.media_type = a.media_type)
        LIMIT 1
    ) ur ON TRUE
    LEFT JOIN public.titles lt
        ON a.is_upset AND lt.id = (a.metadata ->> 'loser_title_id')::INT AND lt.media_type = a.media_type
    LEFT JOIN public.user_rankings lr
        ON a.is_upset AND lr.user_id = a.user_id AND lr.title_id = (a.metadata ->> 'loser_title_id')::INT
       AND lr.media_type = a.media_type
    -- Keyset pagination on (created_at, id): pass the last row's created_at and id for the next page.
    WHERE (p_before IS NULL
           OR a.created_at < p_before
           OR (p_before_id IS NOT NULL AND a.created_at = p_before AND a.id < p_before_id))
      AND NOT EXISTS (
          SELECT 1 FROM public.user_muted_titles m
          WHERE m.user_id = auth.uid() AND m.title_id = a.title_id AND m.media_type = a.media_type
      )
      AND (
          p_filter = 'global'
          OR (p_filter = 'following' AND (
                a.user_id = auth.uid()
                OR a.user_id IN (SELECT f.following_id FROM public.social_follows f
                                 WHERE f.follower_id = auth.uid() AND f.status = 'accepted')))
          OR (p_filter = 'squads' AND a.user_id IN (
                SELECT m2.user_id FROM public.squad_members m1
                JOIN public.squad_members m2 ON m2.squad_id = m1.squad_id
                WHERE m1.user_id = auth.uid()))
      )
    ORDER BY a.created_at DESC, a.id DESC
    LIMIT LEAST(GREATEST(p_limit, 1), 100);
END;
$$;

REVOKE ALL ON FUNCTION public.get_activity_feed(TEXT, TIMESTAMPTZ, INT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_activity_feed(TEXT, TIMESTAMPTZ, INT, UUID) TO authenticated;
