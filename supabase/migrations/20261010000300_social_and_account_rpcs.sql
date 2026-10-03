-- =============================================================================
-- TELLY SOCIAL, FEED, SQUAD & ACCOUNT RPCs (BE-604)
-- Contract: docs/technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md §3.3, §3.4
-- Specs: features/04 (feed, squads), features/05 §2 (taste match), adjacent_systems/05 §2, §4.1
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;

-- -----------------------------------------------------------------------------
-- 1. TASTE MATCH (per canon; features/05 §2.1 — mutual titles re-ranked 1..k)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calculate_taste_match_rpc(
    p_other UUID,
    p_media_type public.media_type_enum
)
RETURNS TABLE (match_pct INT, mutual_count INT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_me UUID := public._require_user();
    v_k INT;
    v_sum_d2 NUMERIC;
    v_rho NUMERIC;
    v_pct INT;
BEGIN
    IF p_other = v_me OR NOT public.can_view_user(p_other) THEN
        RAISE EXCEPTION 'taste match not available' USING ERRCODE = '42501';
    END IF;

    WITH mutual AS (
        SELECT a.rank_position AS ra, b.rank_position AS rb
        FROM public.user_rankings a
        JOIN public.user_rankings b ON b.title_id = a.title_id AND b.media_type = a.media_type
        WHERE a.user_id = v_me AND b.user_id = p_other AND a.media_type = p_media_type
    ), reranked AS (
        SELECT row_number() OVER (ORDER BY ra) AS ka, row_number() OVER (ORDER BY rb) AS kb FROM mutual
    )
    SELECT count(*)::INT, COALESCE(SUM(POWER(ka - kb, 2)), 0) INTO v_k, v_sum_d2 FROM reranked;

    IF v_k < 2 THEN
        v_pct := 50;
    ELSE
        v_rho := 1.0 - (6.0 * v_sum_d2) / (v_k * (POWER(v_k, 2) - 1.0));
        v_pct := ROUND((((v_k::NUMERIC / (v_k + 5.0)) * v_rho + 1.0) / 2.0) * 100);
    END IF;

    INSERT INTO public.taste_matches (user_a, user_b, media_type, match_percentage, mutual_count)
    VALUES (LEAST(v_me, p_other), GREATEST(v_me, p_other), p_media_type, v_pct, v_k)
    ON CONFLICT (user_a, user_b, media_type)
    DO UPDATE SET match_percentage = EXCLUDED.match_percentage, mutual_count = EXCLUDED.mutual_count;

    RETURN QUERY SELECT v_pct, v_k;
END;
$$;

-- -----------------------------------------------------------------------------
-- 2. ACTIVITY TRIGGERS (features/04 §2.1 feed item types)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.activity_on_ranking_created()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.activity_logs (user_id, activity_type, title_id, media_type, ranking_id)
    VALUES (NEW.user_id, 'RANKING_CREATED', NEW.title_id, NEW.media_type, NEW.id);
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_user_rankings_activity
    AFTER INSERT ON public.user_rankings
    FOR EACH ROW EXECUTE FUNCTION public.activity_on_ranking_created();

CREATE OR REPLACE FUNCTION public.activity_on_show_dropped()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.activity_logs (user_id, activity_type, title_id, media_type, metadata)
    VALUES (NEW.user_id, 'SHOW_DROPPED', NEW.title_id, NEW.media_type,
            jsonb_build_object('season', NEW.dropped_at_season, 'episode', NEW.dropped_at_episode, 'reason', NEW.reason));
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_user_dropped_shows_activity
    AFTER INSERT ON public.user_dropped_shows
    FOR EACH ROW EXECUTE FUNCTION public.activity_on_show_dropped();

CREATE OR REPLACE FUNCTION public.activity_on_queue_added()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.activity_logs (user_id, activity_type, title_id, media_type, target_user_id)
    VALUES (NEW.user_id, 'QUEUE_ADDED', NEW.title_id, NEW.media_type, NEW.recommended_by_user_id);
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_user_watchlist_activity
    AFTER INSERT ON public.user_watchlist
    FOR EACH ROW EXECUTE FUNCTION public.activity_on_queue_added();

-- -----------------------------------------------------------------------------
-- 3. FEED (SECURITY INVOKER: RLS decides visibility)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_activity_feed(
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
    rank_position INT,
    calculated_score NUMERIC,
    canon_size INT,
    review_short VARCHAR,
    favorite_character VARCHAR,
    is_upset BOOLEAN,
    upset_delta NUMERIC,
    metadata JSONB,
    created_at TIMESTAMPTZ,
    reaction_counts JSONB,
    my_reactions TEXT[],
    comment_count INT
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
        ur.rank_position, ur.calculated_score,
        (SELECT count(*)::INT FROM public.user_rankings c WHERE c.user_id = a.user_id AND c.media_type = a.media_type),
        ur.review_short, ur.favorite_character,
        a.is_upset, a.upset_delta, a.metadata, a.created_at,
        COALESCE((SELECT jsonb_object_agg(rc.reaction_type, rc.n)
                  FROM (SELECT r.reaction_type, count(*) AS n FROM public.feed_reactions r
                        WHERE r.activity_id = a.id GROUP BY r.reaction_type) rc), '{}'::jsonb),
        COALESCE((SELECT array_agg(r.reaction_type::TEXT) FROM public.feed_reactions r
                  WHERE r.activity_id = a.id AND r.user_id = auth.uid()), ARRAY[]::TEXT[]),
        (SELECT count(*)::INT FROM public.comments cm WHERE cm.activity_id = a.id)
    FROM public.activity_logs a
    JOIN public.users u ON u.id = a.user_id
    LEFT JOIN public.titles t ON t.id = a.title_id AND t.media_type = a.media_type
    LEFT JOIN public.user_rankings ur ON ur.id = a.ranking_id
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

-- -----------------------------------------------------------------------------
-- 4. SQUAD CONSENSUS CANON (features/04 §4.2 Borda count; tie-breaks mirror SquadCanonAggregator)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calculate_squad_canon(
    p_squad_id UUID,
    p_media_type public.media_type_enum
)
RETURNS TABLE (
    consensus_rank INT,
    title_id INT,
    title VARCHAR,
    poster_path TEXT,
    total_borda_points BIGINT,
    champion_user_id UUID,
    champion_rank INT,
    lowest_user_id UUID,
    lowest_rank INT,
    members_ranked_count INT,
    rank_variance NUMERIC
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    PERFORM public._require_user();
    IF NOT public.is_squad_member(p_squad_id) THEN
        RAISE EXCEPTION 'not a member of this squad' USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    WITH members AS (
        SELECT m.user_id FROM public.squad_members m WHERE m.squad_id = p_squad_id
    ), sized AS (
        SELECT ur.user_id, ur.title_id, ur.rank_position,
               count(*) OVER (PARTITION BY ur.user_id) AS n_i
        FROM public.user_rankings ur
        JOIN members mb ON mb.user_id = ur.user_id
        WHERE ur.media_type = p_media_type
    ), agg AS (
        SELECT s.title_id,
               SUM(s.n_i - s.rank_position + 1)::BIGINT AS points,
               (ARRAY_AGG(s.user_id ORDER BY s.rank_position ASC, s.user_id))[1] AS champ,
               MIN(s.rank_position)::INT AS champ_rank,
               (ARRAY_AGG(s.user_id ORDER BY s.rank_position DESC, s.user_id))[1] AS low,
               MAX(s.rank_position)::INT AS low_rank,
               count(*)::INT AS cnt,
               AVG(s.rank_position) AS mean_rank,
               COALESCE(ROUND(VAR_SAMP(s.rank_position)::NUMERIC, 2), 0.00) AS variance
        FROM sized s
        GROUP BY s.title_id
    )
    SELECT
        (row_number() OVER (ORDER BY a.points DESC, a.cnt DESC, a.mean_rank ASC, t.title ASC))::INT,
        a.title_id, t.title, t.poster_path, a.points, a.champ, a.champ_rank, a.low, a.low_rank, a.cnt, a.variance
    FROM agg a
    JOIN public.titles t ON t.id = a.title_id AND t.media_type = p_media_type
    ORDER BY 1;
END;
$$;

REVOKE ALL ON FUNCTION public.calculate_squad_canon(UUID, public.media_type_enum) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.calculate_squad_canon(UUID, public.media_type_enum) TO authenticated;

-- -----------------------------------------------------------------------------
-- 5. ACCOUNT DELETION (adjacent_systems/05 §4.1 — 30-day grace, then purge)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.request_account_deletion()
RETURNS TIMESTAMPTZ
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
    v_at TIMESTAMPTZ := NOW();
BEGIN
    UPDATE public.users SET is_deleted = TRUE, deletion_requested_at = v_at WHERE id = v_user;
    -- Revoke every session; the user may sign in again within 30 days to cancel.
    DELETE FROM auth.sessions WHERE user_id = v_user;
    DELETE FROM auth.refresh_tokens WHERE user_id = v_user::TEXT;
    RETURN v_at + INTERVAL '30 days';
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_account_deletion()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
BEGIN
    UPDATE public.users SET is_deleted = FALSE, deletion_requested_at = NULL
    WHERE id = v_user AND is_deleted AND deletion_requested_at > NOW() - INTERVAL '30 days';
    RETURN FOUND;
END;
$$;

-- service_role / pg_cron only. p_now exists so tests can time-travel.
CREATE OR REPLACE FUNCTION public.purge_deleted_accounts(p_now TIMESTAMPTZ DEFAULT NOW())
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_count INT;
BEGIN
    WITH doomed AS (
        SELECT id FROM public.users
        WHERE is_deleted AND deletion_requested_at <= p_now - INTERVAL '30 days'
    )
    DELETE FROM auth.users au USING doomed d WHERE au.id = d.id;  -- cascades to public.users and all data
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.request_account_deletion() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.cancel_account_deletion() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.purge_deleted_accounts(TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.request_account_deletion() TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_account_deletion() TO authenticated;
GRANT EXECUTE ON FUNCTION public.purge_deleted_accounts(TIMESTAMPTZ) TO service_role;

SELECT cron.schedule('purge-deleted-accounts', '17 3 * * *', $$SELECT public.purge_deleted_accounts()$$);

-- -----------------------------------------------------------------------------
-- 6. MODERATION (adjacent_systems/05 §2; Apple Guideline 1.2)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_report(
    p_target_type public.report_target_enum,
    p_target_id TEXT,
    p_reason public.report_reason_enum,
    p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO public.reports (reporter_id, target_type, target_id, reason, notes)
    VALUES (public._require_user(), p_target_type, p_target_id, p_reason, LEFT(p_notes, 500))
    RETURNING id INTO v_id;
    RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.block_user(p_user UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_me UUID := public._require_user();
BEGIN
    IF p_user = v_me THEN
        RAISE EXCEPTION 'cannot block yourself' USING ERRCODE = '22023';
    END IF;
    INSERT INTO public.user_blocks (blocker_id, blocked_id) VALUES (v_me, p_user) ON CONFLICT DO NOTHING;
    DELETE FROM public.social_follows
    WHERE (follower_id = v_me AND following_id = p_user) OR (follower_id = p_user AND following_id = v_me);
END;
$$;

CREATE OR REPLACE FUNCTION public.unblock_user(p_user UUID)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    DELETE FROM public.user_blocks WHERE blocker_id = public._require_user() AND blocked_id = p_user;
$$;

REVOKE ALL ON FUNCTION public.calculate_taste_match_rpc(UUID, public.media_type_enum) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.submit_report(public.report_target_enum, TEXT, public.report_reason_enum, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.block_user(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.unblock_user(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.calculate_taste_match_rpc(UUID, public.media_type_enum) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_report(public.report_target_enum, TEXT, public.report_reason_enum, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.block_user(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unblock_user(UUID) TO authenticated;
