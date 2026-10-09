-- Migration 20261010003300_watch_tracking_reads.sql
-- #226 (epic #168, decision 0010): the read side of watch tracking.
-- Spec: docs/features/11_WATCH_TRACKING_AND_EPISODE_PROGRESS.md §6.3, §7, §8;
--       docs/technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md §3.6.
--
--   * get_my_tracking(): the caller's rows with what the hub, Home, Canon and the title page show.
--   * get_title_watchers(): friends tracking a title, with no place and no state.
--   * get_tracking_stats(): episodes / movies finished for a year, or this ISO week with runtime.
--   * get_activity_feed gains p_include_tracking (default FALSE), like medals and challenges: older
--     apps never receive WATCH_STARTED / WATCH_FINISHED rows (they would only skip them, but the
--     skipped rows still use up page slots). The body is otherwise that of 20261010002500.

-- -----------------------------------------------------------------------------
-- 1. FEED: opt-in tracking rows
-- -----------------------------------------------------------------------------
DROP FUNCTION public.get_activity_feed(TEXT, TIMESTAMPTZ, INT, UUID, BOOLEAN, BOOLEAN);

CREATE OR REPLACE FUNCTION public.get_activity_feed(
    p_filter TEXT DEFAULT 'following',
    p_before TIMESTAMPTZ DEFAULT NULL,
    p_limit INT DEFAULT 20,
    p_before_id UUID DEFAULT NULL,
    p_include_medals BOOLEAN DEFAULT FALSE,
    p_include_challenges BOOLEAN DEFAULT FALSE,
    p_include_tracking BOOLEAN DEFAULT FALSE
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
      -- #226: "started watching" / "finished" cards need an app that knows them (#232).
      AND (p_include_tracking OR a.activity_type NOT IN ('WATCH_STARTED', 'WATCH_FINISHED'))
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

REVOKE ALL ON FUNCTION public.get_activity_feed(TEXT, TIMESTAMPTZ, INT, UUID, BOOLEAN, BOOLEAN, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_activity_feed(TEXT, TIMESTAMPTZ, INT, UUID, BOOLEAN, BOOLEAN, BOOLEAN) TO authenticated;

-- -----------------------------------------------------------------------------
-- 2. get_my_tracking (§6.3)
-- -----------------------------------------------------------------------------
-- Aired episodes of a series (features/11 §3.4 aired_total).
CREATE OR REPLACE FUNCTION public._tracking_aired_total(p_title_id INT, p_today DATE)
RETURNS INT
LANGUAGE sql
STABLE
SET search_path = public
AS $$
    SELECT count(*)::INT
    FROM public.tv_seasons s
    CROSS JOIN LATERAL generate_series(1, s.episode_count) AS e(n)
    WHERE s.title_id = p_title_id AND s.season_number >= 1
      AND public._episode_aired(p_title_id, s.season_number, e.n, p_today);
$$;

-- One JSON document: {"today": date, "items": [...]}, newest progress first. The client derives
-- groups (§2.3) and the progress bar (watched / aired_total, §3.4) from it. Movies carry no
-- place, seasons, next episode or counts.
CREATE OR REPLACE FUNCTION public.get_my_tracking()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
    v_today DATE := public._user_today(v_user);
BEGIN
    RETURN jsonb_build_object(
        'today', v_today,
        'items', COALESCE((
            SELECT jsonb_agg(x.item ORDER BY x.last_progress_at DESC, x.title_id)
            FROM (
                SELECT
                    ut.last_progress_at,
                    ut.title_id,
                    jsonb_build_object(
                        'title_id', ut.title_id,
                        'media_type', ut.media_type,
                        'last_season', ut.last_season,
                        'last_episode', ut.last_episode,
                        'state', ut.state,
                        'is_rewatch', ut.is_rewatch,
                        'new_episodes_since', ut.new_episodes_since,
                        'started_at', ut.started_at,
                        'last_progress_at', ut.last_progress_at,
                        'finished_at', ut.finished_at,
                        'title', t.title,
                        'poster_path', t.poster_path,
                        'backdrop_path', t.backdrop_path,
                        'title_status', t.status,
                        'runtime_minutes', t.runtime_minutes,
                        'number_of_seasons', t.number_of_seasons,
                        'seasons', CASE WHEN ut.media_type = 'tv' THEN COALESCE((
                            SELECT jsonb_agg(jsonb_build_object(
                                       'number', s.season_number, 'episode_count', s.episode_count,
                                       'air_date', s.air_date) ORDER BY s.season_number)
                            FROM public.tv_seasons s
                            WHERE s.title_id = ut.title_id AND s.season_number >= 1), '[]'::jsonb)
                            ELSE NULL END,
                        'watched', CASE WHEN ut.media_type = 'tv'
                            THEN public._tracking_ordinal(ut.title_id, ut.last_season, ut.last_episode) END,
                        'aired_total', CASE WHEN ut.media_type = 'tv'
                            THEN public._tracking_aired_total(ut.title_id, v_today) END,
                        'next_episode', CASE WHEN nx.next_season IS NULL THEN NULL ELSE jsonb_build_object(
                            'season', nx.next_season, 'episode', nx.next_episode,
                            'name', ne.name, 'still_path', ne.still_path,
                            'air_date', ne.air_date, 'runtime_minutes', ne.runtime_minutes) END,
                        'last_aired', CASE WHEN la.la_season IS NULL THEN NULL
                            ELSE jsonb_build_object('season', la.la_season, 'episode', la.la_episode) END,
                        'ranked', r.id IS NOT NULL,
                        'rank_position', r.rank_position,
                        'calculated_score', r.calculated_score
                    ) AS item
                FROM public.user_tracking ut
                JOIN public.titles t ON t.id = ut.title_id AND t.media_type = ut.media_type
                LEFT JOIN public.user_rankings r
                    ON r.user_id = ut.user_id AND r.title_id = ut.title_id AND r.media_type = ut.media_type
                LEFT JOIN LATERAL public._tracking_next(ut.title_id, ut.last_season, ut.last_episode, v_today) nx
                    ON ut.media_type = 'tv'
                LEFT JOIN public.tv_episodes ne
                    ON ne.title_id = ut.title_id AND ne.season_number = nx.next_season
                   AND ne.episode_number = nx.next_episode
                LEFT JOIN LATERAL (
                    SELECT s.season_number AS la_season, e.n AS la_episode
                    FROM public.tv_seasons s
                    CROSS JOIN LATERAL generate_series(1, s.episode_count) AS e(n)
                    WHERE ut.media_type = 'tv' AND s.title_id = ut.title_id AND s.season_number >= 1
                      AND public._episode_aired(ut.title_id, s.season_number, e.n, v_today)
                    ORDER BY s.season_number DESC, e.n DESC
                    LIMIT 1
                ) la ON TRUE
                WHERE ut.user_id = v_user
            ) x
        ), '[]'::jsonb)
    );
END;
$$;

-- -----------------------------------------------------------------------------
-- 3. get_title_watchers (§5.4, §7.1)
-- -----------------------------------------------------------------------------
-- Friends (accepted follows) who are watching the title now. Never a place, a state or a time.
CREATE OR REPLACE FUNCTION public.get_title_watchers(p_title_id INT, p_media_type public.media_type_enum)
RETURNS TABLE (
    watcher_id UUID,
    username VARCHAR,
    display_name VARCHAR,
    avatar_url TEXT,
    total_watchers INT
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
    WITH watchers AS (
        SELECT u.id AS wid, u.username AS wname, u.display_name AS wdisplay, u.avatar_url AS wavatar,
               ut.last_progress_at AS wprogress
        FROM public.user_tracking ut
        JOIN public.users u ON u.id = ut.user_id
        JOIN public.social_follows f
            ON f.following_id = ut.user_id AND f.follower_id = v_user AND f.status = 'accepted'
        WHERE ut.title_id = p_title_id AND ut.media_type = p_media_type AND ut.state = 'WATCHING'
          AND NOT u.is_deleted
          AND u.visibility_mode <> 'GHOST'
          AND public.can_view_user(u.id)
    )
    SELECT w.wid, w.wname, w.wdisplay, w.wavatar, (SELECT count(*)::INT FROM watchers)
    FROM watchers w
    ORDER BY w.wprogress DESC, w.wid
    LIMIT 20;
END;
$$;

-- -----------------------------------------------------------------------------
-- 4. get_tracking_stats (§8)
-- -----------------------------------------------------------------------------
-- p_year: the year in the caller's timezone (TV: {"episodes"}, movie: {"movies_finished"}).
-- p_year NULL: this ISO week, plus "minutes", which is null unless every counted runtime is known.
CREATE OR REPLACE FUNCTION public.get_tracking_stats(p_media_type public.media_type_enum, p_year INT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
    v_tz TEXT;
    v_from TIMESTAMPTZ;
    v_to TIMESTAMPTZ;
    v_n INT;
    v_minutes INT;
    v_unknown INT;
    v_out JSONB;
BEGIN
    SELECT COALESCE(u.timezone, 'UTC') INTO v_tz FROM public.users u WHERE u.id = v_user;
    IF p_year IS NOT NULL THEN
        v_from := make_timestamptz(p_year, 1, 1, 0, 0, 0, v_tz);
        v_to := make_timestamptz(p_year + 1, 1, 1, 0, 0, 0, v_tz);
    ELSE
        v_from := date_trunc('week', NOW() AT TIME ZONE v_tz) AT TIME ZONE v_tz;
        v_to := (date_trunc('week', NOW() AT TIME ZONE v_tz) + INTERVAL '7 days') AT TIME ZONE v_tz;
    END IF;

    IF p_media_type = 'tv' THEN
        SELECT COALESCE(SUM(CASE e.kind WHEN 'UNWATCHED' THEN -1 ELSE 1 END), 0)::INT,
               COALESCE(SUM(CASE e.kind WHEN 'UNWATCHED' THEN -1 ELSE 1 END * COALESCE(x.runtime_minutes, 0)), 0)::INT,
               (count(*) FILTER (WHERE x.runtime_minutes IS NULL))::INT
          INTO v_n, v_minutes, v_unknown
        FROM public.user_tracking_events e
        LEFT JOIN public.tv_episodes x
            ON x.title_id = e.title_id AND x.season_number = e.season_number AND x.episode_number = e.episode_number
        WHERE e.user_id = v_user AND e.media_type = 'tv'
          AND e.kind IN ('WATCHED', 'REWATCHED', 'UNWATCHED')
          AND e.created_at >= v_from AND e.created_at < v_to;
        v_out := jsonb_build_object('episodes', GREATEST(v_n, 0));
    ELSE
        SELECT count(*)::INT,
               COALESCE(SUM(t.runtime_minutes), 0)::INT,
               (count(*) FILTER (WHERE t.runtime_minutes IS NULL))::INT
          INTO v_n, v_minutes, v_unknown
        FROM public.user_tracking_events e
        JOIN public.titles t ON t.id = e.title_id AND t.media_type = e.media_type
        WHERE e.user_id = v_user AND e.media_type = 'movie' AND e.kind = 'FINISHED'
          AND e.created_at >= v_from AND e.created_at < v_to;
        v_out := jsonb_build_object('movies_finished', v_n);
    END IF;

    IF p_year IS NULL THEN
        v_out := v_out || jsonb_build_object(
            'minutes', CASE WHEN v_unknown = 0 THEN GREATEST(v_minutes, 0) ELSE NULL END);
    END IF;
    RETURN v_out;
END;
$$;

-- -----------------------------------------------------------------------------
-- 5. GRANTS
-- -----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public._tracking_aired_total(INT, DATE) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_my_tracking() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_title_watchers(INT, public.media_type_enum) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_tracking_stats(public.media_type_enum, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_tracking() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_title_watchers(INT, public.media_type_enum) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_tracking_stats(public.media_type_enum, INT) TO authenticated;
