-- Migration 20261010002500_challenge_feed_context.sql
-- #144 (epic #50): challenge context in the feed, and challenge medals in my_achievements
-- (Spec 10 §8.2, §10).
--
-- * get_activity_feed returns challenge_context for RANKING_CREATED rows made inside a
--   challenge the poster joined: {slug, name, count, target}, shown as "Spooktober 2 of 8".
--   An added column only; older apps ignore it.
-- * _achievement_progress also lists the challenge medals a user holds, so they show in
--   my_achievements (SCR-23, the unlock moment, pinning).

CREATE OR REPLACE FUNCTION public._achievement_progress(p_user UUID)
RETURNS TABLE (achievement_id TEXT, progress INT)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_movies INT;
    v_tv INT;
    v_upsets INT;
    v_twin INT;
    v_decades INT;
    v_genres INT;
    v_graves INT;
    v_best INT;
    v_founder INT;
BEGIN
    SELECT count(*) FILTER (WHERE q.media_type = 'movie'), count(*) FILTER (WHERE q.media_type = 'tv')
    INTO v_movies, v_tv
    FROM public.qualifying_rankings q WHERE q.user_id = p_user;

    SELECT count(*) INTO v_upsets FROM public.pairwise_duels d WHERE d.user_id = p_user AND d.is_upset;

    -- best taste match with someone I follow (either canon)
    SELECT COALESCE(max(tm.match_percentage), 0) INTO v_twin
    FROM public.taste_matches tm
    JOIN public.social_follows f
      ON f.follower_id = p_user AND f.status = 'accepted'
     AND f.following_id = CASE WHEN tm.user_a = p_user THEN tm.user_b ELSE tm.user_a END
    WHERE p_user IN (tm.user_a, tm.user_b);

    SELECT count(DISTINCT (EXTRACT(YEAR FROM t.release_date)::INT / 10)) INTO v_decades
    FROM public.qualifying_rankings q
    JOIN public.titles t ON t.id = q.title_id AND t.media_type = q.media_type
    WHERE q.user_id = p_user AND t.release_date IS NOT NULL;

    SELECT count(DISTINCT g) INTO v_genres
    FROM public.qualifying_rankings q
    JOIN public.titles t ON t.id = q.title_id AND t.media_type = q.media_type
    CROSS JOIN LATERAL unnest(t.genres) AS g
    WHERE q.user_id = p_user;

    SELECT count(*) INTO v_graves FROM public.user_dropped_shows ds WHERE ds.user_id = p_user AND ds.media_type = 'tv';

    SELECT s.best_weeks INTO v_best FROM public.weekly_streak(p_user) s;

    SELECT CASE WHEN public._public_launch_date() IS NOT NULL
                 AND u.created_at < public._public_launch_date() + 90 THEN 1 ELSE 0 END
    INTO v_founder FROM public.users u WHERE u.id = p_user;

    RETURN QUERY
    SELECT a.id,
        CASE
            WHEN a.kind = 'milestone' AND a.media_type = 'movie' THEN v_movies
            WHEN a.kind = 'milestone' AND a.media_type = 'tv' THEN v_tv
            WHEN a.id = 'upset_artist' THEN v_upsets
            WHEN a.id = 'taste_twin' THEN v_twin
            WHEN a.id = 'decade_hopper' THEN v_decades
            WHEN a.id = 'genre_explorer' THEN v_genres
            WHEN a.id = 'graveyard_keeper' THEN v_graves
            WHEN a.kind = 'streak' THEN COALESCE(v_best, 0)
            WHEN a.id = 'founding_viewer' THEN COALESCE(v_founder, 0)
            ELSE 0
        END
    FROM public.achievements a
    WHERE a.kind IN ('milestone', 'taste', 'streak', 'special')
      AND (a.active OR EXISTS (SELECT 1 FROM public.user_achievements ua
                               WHERE ua.user_id = p_user AND ua.achievement_id = a.id))
    UNION ALL
    -- #140: collections the user has started (ranked one of its films), or holds.
    SELECT a.id,
        (SELECT count(*)::INT FROM unnest(tc.released_part_ids) AS rp(id)
         WHERE rp.id IN (SELECT q.title_id FROM public.qualifying_rankings q
                         WHERE q.user_id = p_user AND q.media_type = 'movie'))
    FROM public.achievements a
    JOIN public.title_collections tc ON tc.collection_id = a.collection_id
    WHERE a.kind = 'collection'
      AND (
          (a.active AND EXISTS (SELECT 1 FROM public.qualifying_rankings q
                                WHERE q.user_id = p_user AND q.media_type = 'movie'
                                  AND q.title_id = ANY (tc.part_ids)))
          OR EXISTS (SELECT 1 FROM public.user_achievements ua
                     WHERE ua.user_id = p_user AND ua.achievement_id = a.id)
      )
    UNION ALL
    -- #144: challenge medals the user holds (earned by finishing the challenge, §8.2).
    SELECT a.id, a.threshold
    FROM public.achievements a
    WHERE a.kind = 'challenge'
      AND EXISTS (SELECT 1 FROM public.user_achievements ua
                  WHERE ua.user_id = p_user AND ua.achievement_id = a.id);
END;
$$;

DROP FUNCTION public.get_activity_feed(TEXT, TIMESTAMPTZ, INT, UUID, BOOLEAN, BOOLEAN);

CREATE OR REPLACE FUNCTION public.get_activity_feed(
    p_filter TEXT DEFAULT 'following',
    p_before TIMESTAMPTZ DEFAULT NULL,
    p_limit INT DEFAULT 20,
    p_before_id UUID DEFAULT NULL,
    p_include_medals BOOLEAN DEFAULT FALSE,
    p_include_challenges BOOLEAN DEFAULT FALSE
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
    in_my_queue BOOLEAN,
    challenge_context JSONB
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
        -- Custom emoji reactions are keyed 'EMOJI:<emoji>' (FE-FEED-01).
        COALESCE((SELECT jsonb_object_agg(rc.reaction_key, rc.n)
                  FROM (SELECT public.feed_reaction_key(r.reaction_type, r.emoji) AS reaction_key, count(*) AS n
                        FROM public.feed_reactions r
                        WHERE r.activity_id = a.id
                        GROUP BY 1) rc), '{}'::jsonb),
        COALESCE((SELECT array_agg(public.feed_reaction_key(r.reaction_type, r.emoji)) FROM public.feed_reactions r
                  WHERE r.activity_id = a.id AND r.user_id = auth.uid()), ARRAY[]::TEXT[]),
        (SELECT count(*)::INT FROM public.comments cm WHERE cm.activity_id = a.id AND NOT cm.is_hidden),
        EXISTS (SELECT 1 FROM public.user_watchlist w
                WHERE w.user_id = auth.uid() AND w.title_id = a.title_id AND w.media_type = a.media_type),
        ctx.context
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
    -- #144: "Spooktober 2 of 8" under a ranking made inside a challenge the poster joined (one
    -- the viewer can see; featured first). The count is as of that ranking.
    LEFT JOIN LATERAL (
        SELECT jsonb_build_object(
                   'slug', c.slug, 'name', c.name, 'target', c.target,
                   'count', LEAST(c.target, (SELECT count(*)::INT FROM public._challenge_matches(c, a.user_id) m
                                             WHERE m.created_at <= ur.created_at))) AS context
        FROM public.challenge_participants p
        JOIN public.challenges c ON c.id = p.challenge_id
        WHERE a.activity_type = 'RANKING_CREATED' AND ur.id IS NOT NULL AND t.id IS NOT NULL
          AND p.user_id = a.user_id
          AND c.status = 'live'
          AND (c.squad_id IS NULL OR public.is_squad_member(c.squad_id))
          AND ur.created_at >= c.starts_at AND (c.ends_at IS NULL OR ur.created_at < c.ends_at)
          AND public._title_matches_rule(c.rule, t)
        ORDER BY c.featured DESC, c.ends_at NULLS LAST
        LIMIT 1
    ) ctx ON TRUE
    -- Keyset pagination on (created_at, id): pass the last row's created_at and id for the next page.
    WHERE (p_before IS NULL
           OR a.created_at < p_before
           OR (p_before_id IS NOT NULL AND a.created_at = p_before AND a.id < p_before_id))
      -- #136: medal cards need an app that knows them (#139); older apps never get the rows.
      AND (p_include_medals OR a.activity_type <> 'MEDAL_UNLOCKED')
      -- #142: challenge cards need an app that knows them (#144).
      AND (p_include_challenges OR a.activity_type <> 'CHALLENGE_COMPLETED')
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

REVOKE ALL ON FUNCTION public.get_activity_feed(TEXT, TIMESTAMPTZ, INT, UUID, BOOLEAN, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_activity_feed(TEXT, TIMESTAMPTZ, INT, UUID, BOOLEAN, BOOLEAN) TO authenticated;
