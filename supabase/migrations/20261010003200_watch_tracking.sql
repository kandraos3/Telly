-- Migration 20261010003200_watch_tracking.sql
-- #225 (epic #168, decision 0010): watch tracking. One place per tracked title ("the last episode
-- you watched"), episode events for stats, a TMDB episode cache, and the write RPCs.
-- Spec: docs/features/11_WATCH_TRACKING_AND_EPISODE_PROGRESS.md §2, §3, §4, §6.1, §6.2, §6.4, §7.2;
--       docs/technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md §2.2, §2.4, §3.6.
--
--   * tracking_state_enum, user_tracking, user_tracking_events, tv_episodes (+ RLS).
--   * activity_logs accepts WATCH_STARTED and WATCH_FINISHED. Shipped apps map unknown activity
--     types to `unknown` and skip them (ActivityType.fromString), so this is backward compatible.
--   * _tracking_state and its helpers implement features/11 §3.1-§3.3 and are checked against
--     test/fixtures/tracking_progress_vectors.json (pgTAP 035).
--   * start_tracking, set_tracking_place, log_episode_rewatch, finish_tracking, stop_tracking and
--     revive_dropped_show. Reads (#226) and the daily refresh (#227) come in later migrations.
-- Dual canon (I-1): every row carries media_type, and a movie never has a place or CAUGHT_UP.

-- -----------------------------------------------------------------------------
-- 1. TABLES
-- -----------------------------------------------------------------------------
CREATE TYPE public.tracking_state_enum AS ENUM ('WATCHING', 'CAUGHT_UP', 'FINISHED');

-- TMDB episode cache; written by the tmdb-season and tracking-refresh functions (#227).
CREATE TABLE public.tv_episodes (
    title_id INT NOT NULL,
    media_type public.media_type_enum NOT NULL DEFAULT 'tv' CHECK (media_type = 'tv'),
    season_number INT NOT NULL CHECK (season_number >= 1),
    episode_number INT NOT NULL CHECK (episode_number >= 1),
    name VARCHAR(200),
    overview TEXT,
    still_path TEXT,
    air_date DATE,
    runtime_minutes INT,
    fetched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (title_id, season_number, episode_number),
    FOREIGN KEY (title_id, media_type) REFERENCES public.titles(id, media_type) ON DELETE CASCADE
);

CREATE TABLE public.user_tracking (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title_id INT NOT NULL,
    media_type public.media_type_enum NOT NULL,
    last_season INT CHECK (last_season >= 1),
    last_episode INT CHECK (last_episode >= 1),
    state public.tracking_state_enum NOT NULL DEFAULT 'WATCHING',
    is_rewatch BOOLEAN NOT NULL DEFAULT FALSE,
    new_episodes_since TIMESTAMPTZ,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_progress_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    finished_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, title_id, media_type),
    FOREIGN KEY (title_id, media_type) REFERENCES public.titles(id, media_type) ON DELETE CASCADE,
    CHECK ((last_season IS NULL) = (last_episode IS NULL)),
    CHECK (media_type = 'tv' OR last_season IS NULL),
    CHECK (media_type = 'tv' OR state <> 'CAUGHT_UP')
);
CREATE INDEX idx_user_tracking_title ON public.user_tracking (title_id, media_type, state);
CREATE TRIGGER trg_user_tracking_updated_at BEFORE UPDATE ON public.user_tracking
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Append-only. Kept when tracking stops, so the year's stats don't shrink (features/11 §4.9).
CREATE TABLE public.user_tracking_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title_id INT NOT NULL,
    media_type public.media_type_enum NOT NULL,
    kind VARCHAR(12) NOT NULL CHECK (kind IN ('WATCHED', 'UNWATCHED', 'REWATCHED', 'FINISHED')),
    season_number INT,
    episode_number INT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    FOREIGN KEY (title_id, media_type) REFERENCES public.titles(id, media_type) ON DELETE CASCADE
);
CREATE INDEX idx_tracking_events_user_time ON public.user_tracking_events (user_id, media_type, created_at);

-- -----------------------------------------------------------------------------
-- 2. RLS: own rows are readable; every write goes through the RPCs below
-- -----------------------------------------------------------------------------
ALTER TABLE public.tv_episodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_tracking_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.tv_episodes, public.user_tracking, public.user_tracking_events FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.tv_episodes, public.user_tracking, public.user_tracking_events FROM authenticated;
CREATE POLICY tv_episodes_read ON public.tv_episodes FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY user_tracking_select_own ON public.user_tracking FOR SELECT TO authenticated
    USING (user_id = auth.uid());
CREATE POLICY user_tracking_events_select_own ON public.user_tracking_events FOR SELECT TO authenticated
    USING (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- 3. ACTIVITY TYPES (features/11 §7.2)
-- -----------------------------------------------------------------------------
ALTER TABLE public.activity_logs DROP CONSTRAINT activity_logs_activity_type_check;
ALTER TABLE public.activity_logs ADD CONSTRAINT activity_logs_activity_type_check CHECK (activity_type IN (
    'RANKING_CREATED', 'UPSET_ALERT', 'SHOW_DROPPED', 'QUEUE_ADDED', 'COMMENT_POSTED', 'MEDAL_UNLOCKED',
    'CHALLENGE_COMPLETED', 'WATCH_STARTED', 'WATCH_FINISHED'
));

-- -----------------------------------------------------------------------------
-- 4. PROGRESS MODEL (features/11 §3), mirrored by Dart TrackingProgress
-- -----------------------------------------------------------------------------
-- The user's local date. p_today parameters below exist so tests can time-travel.
CREATE OR REPLACE FUNCTION public._user_today(p_user UUID)
RETURNS DATE
LANGUAGE sql
STABLE
SET search_path = public
AS $$
    SELECT (NOW() AT TIME ZONE COALESCE((SELECT u.timezone FROM public.users u WHERE u.id = p_user), 'UTC'))::DATE;
$$;

-- §3.2: has this episode aired on p_today?
CREATE OR REPLACE FUNCTION public._episode_aired(p_title_id INT, p_season INT, p_episode INT, p_today DATE)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    v_count INT;
    v_season_air DATE;
    v_air DATE;
    v_status TEXT;
    v_last INT;
BEGIN
    SELECT s.episode_count, s.air_date INTO v_count, v_season_air
    FROM public.tv_seasons s
    WHERE s.title_id = p_title_id AND s.season_number = p_season AND s.season_number >= 1;
    IF NOT FOUND OR p_episode < 1 OR p_episode > v_count THEN
        RETURN FALSE;
    END IF;

    IF EXISTS (SELECT 1 FROM public.tv_episodes e WHERE e.title_id = p_title_id AND e.season_number = p_season) THEN
        SELECT e.air_date INTO v_air
        FROM public.tv_episodes e
        WHERE e.title_id = p_title_id AND e.season_number = p_season AND e.episode_number = p_episode;
        RETURN v_air IS NOT NULL AND v_air <= p_today;
    END IF;

    -- Season fallback: the season has started, and it isn't the latest season of a running show.
    IF v_season_air IS NULL OR v_season_air > p_today THEN
        RETURN FALSE;
    END IF;
    SELECT t.status INTO v_status FROM public.titles t WHERE t.id = p_title_id AND t.media_type = 'tv';
    SELECT MAX(s.season_number) INTO v_last FROM public.tv_seasons s WHERE s.title_id = p_title_id AND s.season_number >= 1;
    RETURN NOT (COALESCE(v_status IN ('Returning Series', 'In Production'), FALSE) AND p_season = v_last);
END;
$$;

-- §3.1: the next episode to watch after the place, or no row when nothing aired follows.
CREATE OR REPLACE FUNCTION public._tracking_next(p_title_id INT, p_season INT, p_episode INT, p_today DATE)
RETURNS TABLE (next_season INT, next_episode INT)
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    v_s INT;
    v_e INT;
    v_count INT;
BEGIN
    IF p_season IS NULL THEN
        SELECT s.season_number, s.episode_count INTO v_s, v_count
        FROM public.tv_seasons s
        WHERE s.title_id = p_title_id AND s.season_number >= 1
        ORDER BY s.season_number LIMIT 1;
        IF NOT FOUND OR v_count < 1 THEN
            RETURN;
        END IF;
        v_e := 1;
    ELSE
        v_count := COALESCE((SELECT s.episode_count FROM public.tv_seasons s
                             WHERE s.title_id = p_title_id AND s.season_number = p_season), 0);
        IF p_episode < v_count THEN
            v_s := p_season;
            v_e := p_episode + 1;
        ELSE
            SELECT s.season_number INTO v_s
            FROM public.tv_seasons s
            WHERE s.title_id = p_title_id AND s.season_number > p_season AND s.episode_count >= 1
            ORDER BY s.season_number LIMIT 1;
            IF v_s IS NULL THEN
                RETURN;
            END IF;
            v_e := 1;
        END IF;
    END IF;

    IF public._episode_aired(p_title_id, v_s, v_e, p_today) THEN
        next_season := v_s;
        next_episode := v_e;
        RETURN NEXT;
    END IF;
END;
$$;

-- §3.3. A movie is WATCHING until it is finished and is never CAUGHT_UP (§2.5).
CREATE OR REPLACE FUNCTION public._tracking_state(
    p_title_id INT, p_media_type public.media_type_enum, p_season INT, p_episode INT,
    p_finished_at TIMESTAMPTZ, p_today DATE
)
RETURNS public.tracking_state_enum
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    v_status TEXT;
BEGIN
    IF p_media_type = 'movie' THEN
        RETURN (CASE WHEN p_finished_at IS NULL THEN 'WATCHING' ELSE 'FINISHED' END)::public.tracking_state_enum;
    END IF;
    IF EXISTS (SELECT 1 FROM public._tracking_next(p_title_id, p_season, p_episode, p_today)) THEN
        RETURN 'WATCHING';
    END IF;
    SELECT t.status INTO v_status FROM public.titles t WHERE t.id = p_title_id AND t.media_type = 'tv';
    IF v_status IN ('Ended', 'Canceled') THEN
        RETURN 'FINISHED';
    END IF;
    RETURN 'CAUGHT_UP';
END;
$$;

-- §3.5: a place past the known episodes moves back to the last known one. NULL stays NULL.
CREATE OR REPLACE FUNCTION public._tracking_clamp(p_title_id INT, p_season INT, p_episode INT)
RETURNS TABLE (clamped_season INT, clamped_episode INT)
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    v_count INT;
    v_last_s INT;
    v_last_c INT;
BEGIN
    clamped_season := p_season;
    clamped_episode := p_episode;
    IF p_season IS NULL
       OR NOT EXISTS (SELECT 1 FROM public.tv_seasons s WHERE s.title_id = p_title_id AND s.season_number >= 1) THEN
        RETURN NEXT;
        RETURN;
    END IF;

    SELECT s.episode_count INTO v_count
    FROM public.tv_seasons s WHERE s.title_id = p_title_id AND s.season_number = p_season;
    IF FOUND THEN
        IF v_count >= 1 AND p_episode > v_count THEN
            clamped_episode := v_count;
        END IF;
        RETURN NEXT;
        RETURN;
    END IF;

    -- The season no longer exists: use the last season that has episodes, else the last season.
    SELECT s.season_number, s.episode_count INTO v_last_s, v_last_c
    FROM public.tv_seasons s
    WHERE s.title_id = p_title_id AND s.season_number >= 1 AND s.episode_count >= 1
    ORDER BY s.season_number DESC LIMIT 1;
    IF NOT FOUND THEN
        SELECT s.season_number, s.episode_count INTO v_last_s, v_last_c
        FROM public.tv_seasons s
        WHERE s.title_id = p_title_id AND s.season_number >= 1
        ORDER BY s.season_number DESC LIMIT 1;
    END IF;
    IF p_season > v_last_s AND v_last_c >= 1 THEN
        clamped_season := v_last_s;
        clamped_episode := v_last_c;
    END IF;
    RETURN NEXT;
END;
$$;

-- 1-based position of an episode across seasons >= 1 (S1 E1 = 1); 0 for no place.
CREATE OR REPLACE FUNCTION public._tracking_ordinal(p_title_id INT, p_season INT, p_episode INT)
RETURNS INT
LANGUAGE sql
STABLE
SET search_path = public
AS $$
    SELECT CASE WHEN p_season IS NULL THEN 0 ELSE COALESCE(SUM(
        CASE WHEN s.season_number < p_season THEN s.episode_count
             WHEN s.season_number = p_season THEN LEAST(GREATEST(p_episode, 0), s.episode_count)
             ELSE 0 END), 0)::INT END
    FROM public.tv_seasons s
    WHERE s.title_id = p_title_id AND s.season_number >= 1;
$$;

-- The episodes at ordinals p_from..p_to, in order.
CREATE OR REPLACE FUNCTION public._tracking_episodes_between(p_title_id INT, p_from INT, p_to INT)
RETURNS TABLE (ep_season INT, ep_episode INT)
LANGUAGE sql
STABLE
SET search_path = public
AS $$
    WITH s AS (
        SELECT t.season_number, t.episode_count,
               COALESCE(SUM(t.episode_count) OVER (
                   ORDER BY t.season_number ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), 0)::INT AS prior_eps
        FROM public.tv_seasons t
        WHERE t.title_id = p_title_id AND t.season_number >= 1
    )
    SELECT s.season_number, (g.i - s.prior_eps)::INT
    FROM generate_series(p_from, p_to) AS g(i)
    JOIN s ON g.i > s.prior_eps AND g.i <= s.prior_eps + s.episode_count
    ORDER BY g.i;
$$;

-- -----------------------------------------------------------------------------
-- 5. INTERNAL WRITE HELPERS (take a user id, so never callable by clients)
-- -----------------------------------------------------------------------------
-- WATCH_STARTED / WATCH_FINISHED, at most once per title per 30 days (§7.2). No episode data.
CREATE OR REPLACE FUNCTION public._tracking_post_activity(
    p_user UUID, p_title_id INT, p_media public.media_type_enum, p_type TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM public.activity_logs a
        WHERE a.user_id = p_user AND a.activity_type = p_type
          AND a.title_id = p_title_id AND a.media_type = p_media
          AND a.created_at > NOW() - INTERVAL '30 days'
    ) THEN
        RETURN;
    END IF;
    INSERT INTO public.activity_logs (user_id, activity_type, title_id, media_type)
    VALUES (p_user, p_type, p_title_id, p_media);
END;
$$;

-- Moves a tracked series' place to an absolute episode (§3.5, §3.6): clamps it, recomputes the
-- state, appends the WATCHED / UNWATCHED events (at most 50) and maintains new_episodes_since and
-- finished_at. A move into FINISHED posts WATCH_FINISHED.
CREATE OR REPLACE FUNCTION public._tracking_move(p_row public.user_tracking, p_season INT, p_episode INT)
RETURNS public.user_tracking
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_today DATE := public._user_today(p_row.user_id);
    v_s INT;
    v_e INT;
    v_a INT;
    v_b INT;
    v_state public.tracking_state_enum;
    v_new public.user_tracking;
BEGIN
    IF p_row.media_type <> 'tv' THEN
        RAISE EXCEPTION 'a movie has no place' USING ERRCODE = '22023';
    END IF;
    IF (p_season IS NULL) <> (p_episode IS NULL) THEN
        RAISE EXCEPTION 'season and episode go together' USING ERRCODE = '22023';
    END IF;

    SELECT c.clamped_season, c.clamped_episode INTO v_s, v_e
    FROM public._tracking_clamp(p_row.title_id, p_season, p_episode) c;
    v_a := public._tracking_ordinal(p_row.title_id, p_row.last_season, p_row.last_episode);
    v_b := public._tracking_ordinal(p_row.title_id, v_s, v_e);
    v_state := public._tracking_state(p_row.title_id, 'tv', v_s, v_e, NULL, v_today);

    UPDATE public.user_tracking SET
        last_season = v_s,
        last_episode = v_e,
        state = v_state,
        last_progress_at = NOW(),
        new_episodes_since = CASE WHEN v_b > v_a THEN NULL ELSE p_row.new_episodes_since END,
        finished_at = CASE WHEN v_state <> 'FINISHED' THEN NULL
                           WHEN p_row.state = 'FINISHED' THEN COALESCE(p_row.finished_at, NOW())
                           ELSE NOW() END
    WHERE user_id = p_row.user_id AND title_id = p_row.title_id AND media_type = p_row.media_type
    RETURNING * INTO v_new;

    IF v_b > v_a THEN
        INSERT INTO public.user_tracking_events (user_id, title_id, media_type, kind, season_number, episode_number)
        SELECT p_row.user_id, p_row.title_id, 'tv'::public.media_type_enum, 'WATCHED', e.ep_season, e.ep_episode
        FROM public._tracking_episodes_between(p_row.title_id, GREATEST(v_a + 1, v_b - 49), v_b) e;
    ELSIF v_b < v_a THEN
        INSERT INTO public.user_tracking_events (user_id, title_id, media_type, kind, season_number, episode_number)
        SELECT p_row.user_id, p_row.title_id, 'tv'::public.media_type_enum, 'UNWATCHED', e.ep_season, e.ep_episode
        FROM public._tracking_episodes_between(p_row.title_id, v_b + 1, LEAST(v_a, v_b + 50)) e;
    END IF;

    IF v_state = 'FINISHED' AND p_row.state <> 'FINISHED' THEN
        PERFORM public._tracking_post_activity(p_row.user_id, p_row.title_id, 'tv', 'WATCH_FINISHED');
    END IF;
    RETURN v_new;
END;
$$;

-- Starts tracking, or (p_is_start = FALSE, used by revive) re-points an existing row.
-- Starting an already-tracked title changes nothing, except "Watch again" on a FINISHED row,
-- which resets the place and sets is_rewatch (§4.1). Starting partway records no events.
CREATE OR REPLACE FUNCTION public._tracking_start(
    p_user UUID, p_title_id INT, p_media public.media_type_enum,
    p_season INT, p_episode INT, p_rewatch BOOLEAN, p_is_start BOOLEAN
)
RETURNS public.user_tracking
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_today DATE := public._user_today(p_user);
    v_s INT;
    v_e INT;
    v_row public.user_tracking;
    v_changed BOOLEAN := FALSE;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.titles t WHERE t.id = p_title_id AND t.media_type = p_media) THEN
        RAISE EXCEPTION 'title not found' USING ERRCODE = 'P0002';
    END IF;
    IF (p_season IS NULL) <> (p_episode IS NULL) THEN
        RAISE EXCEPTION 'season and episode go together' USING ERRCODE = '22023';
    END IF;
    IF p_media = 'movie' AND p_season IS NOT NULL THEN
        RAISE EXCEPTION 'a movie has no place' USING ERRCODE = '22023';
    END IF;

    PERFORM pg_advisory_xact_lock(hashtextextended(p_user::TEXT || ':track:' || p_title_id::TEXT || ':' || p_media::TEXT, 0));

    IF p_media = 'tv' THEN
        SELECT c.clamped_season, c.clamped_episode INTO v_s, v_e
        FROM public._tracking_clamp(p_title_id, p_season, p_episode) c;
    END IF;

    SELECT * INTO v_row FROM public.user_tracking
    WHERE user_id = p_user AND title_id = p_title_id AND media_type = p_media FOR UPDATE;

    IF FOUND THEN
        IF (p_is_start AND p_rewatch AND v_row.state = 'FINISHED') OR NOT p_is_start THEN
            UPDATE public.user_tracking SET
                last_season = v_s,
                last_episode = v_e,
                state = public._tracking_state(p_title_id, p_media, v_s, v_e, NULL, v_today),
                is_rewatch = CASE WHEN p_is_start THEN TRUE ELSE is_rewatch END,
                finished_at = NULL,
                new_episodes_since = NULL,
                started_at = CASE WHEN p_is_start THEN NOW() ELSE started_at END,
                last_progress_at = NOW()
            WHERE user_id = p_user AND title_id = p_title_id AND media_type = p_media
            RETURNING * INTO v_row;
            v_changed := TRUE;
        END IF;
    ELSE
        INSERT INTO public.user_tracking (user_id, title_id, media_type, last_season, last_episode, state, is_rewatch)
        VALUES (p_user, p_title_id, p_media, v_s, v_e,
                public._tracking_state(p_title_id, p_media, v_s, v_e, NULL, v_today), p_rewatch)
        RETURNING * INTO v_row;
        v_changed := TRUE;
    END IF;

    IF p_is_start AND v_changed THEN
        DELETE FROM public.user_watchlist w
        WHERE w.user_id = p_user AND w.title_id = p_title_id AND w.media_type = p_media;
        PERFORM public._tracking_post_activity(p_user, p_title_id, p_media, 'WATCH_STARTED');
    END IF;
    RETURN v_row;
END;
$$;

-- -----------------------------------------------------------------------------
-- 6. WRITE RPCs (features/11 §6.2). All idempotent on p_client_mutation_id (I-5).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.start_tracking(
    p_title_id INT,
    p_media_type public.media_type_enum,
    p_last_season INT DEFAULT NULL,
    p_last_episode INT DEFAULT NULL,
    p_rewatch BOOLEAN DEFAULT FALSE,
    p_client_mutation_id UUID DEFAULT NULL
)
RETURNS public.user_tracking
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
    v_row public.user_tracking;
BEGIN
    IF NOT public._claim_mutation(p_client_mutation_id, v_user, 'tracking_start') THEN
        SELECT * INTO v_row FROM public.user_tracking
        WHERE user_id = v_user AND title_id = p_title_id AND media_type = p_media_type;
        RETURN v_row;
    END IF;
    RETURN public._tracking_start(v_user, p_title_id, p_media_type, p_last_season, p_last_episode, p_rewatch, TRUE);
END;
$$;

CREATE OR REPLACE FUNCTION public.set_tracking_place(
    p_title_id INT,
    p_media_type public.media_type_enum,
    p_last_season INT,
    p_last_episode INT,
    p_client_mutation_id UUID DEFAULT NULL
)
RETURNS public.user_tracking
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
    v_row public.user_tracking;
BEGIN
    IF NOT public._claim_mutation(p_client_mutation_id, v_user, 'tracking_place') THEN
        SELECT * INTO v_row FROM public.user_tracking
        WHERE user_id = v_user AND title_id = p_title_id AND media_type = p_media_type;
        RETURN v_row;
    END IF;

    SELECT * INTO v_row FROM public.user_tracking
    WHERE user_id = v_user AND title_id = p_title_id AND media_type = p_media_type FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'not tracking this title' USING ERRCODE = 'P0002';
    END IF;
    RETURN public._tracking_move(v_row, p_last_season, p_last_episode);
END;
$$;

CREATE OR REPLACE FUNCTION public.log_episode_rewatch(
    p_title_id INT,
    p_season INT,
    p_episode INT,
    p_client_mutation_id UUID DEFAULT NULL
)
RETURNS public.user_tracking
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
    v_row public.user_tracking;
BEGIN
    IF NOT public._claim_mutation(p_client_mutation_id, v_user, 'tracking_rewatch') THEN
        SELECT * INTO v_row FROM public.user_tracking
        WHERE user_id = v_user AND title_id = p_title_id AND media_type = 'tv';
        RETURN v_row;
    END IF;

    SELECT * INTO v_row FROM public.user_tracking
    WHERE user_id = v_user AND title_id = p_title_id AND media_type = 'tv' FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'not tracking this title' USING ERRCODE = 'P0002';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.tv_seasons s
                   WHERE s.title_id = p_title_id AND s.season_number = p_season AND s.season_number >= 1
                     AND p_episode BETWEEN 1 AND s.episode_count) THEN
        RAISE EXCEPTION 'no such episode' USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.user_tracking_events (user_id, title_id, media_type, kind, season_number, episode_number)
    VALUES (v_user, p_title_id, 'tv'::public.media_type_enum, 'REWATCHED', p_season, p_episode);
    UPDATE public.user_tracking SET last_progress_at = NOW()
    WHERE user_id = v_user AND title_id = p_title_id AND media_type = 'tv'
    RETURNING * INTO v_row;
    RETURN v_row;
END;
$$;

-- Movie: FINISHED now. Series: the place becomes the last aired episode (then as set_tracking_place).
CREATE OR REPLACE FUNCTION public.finish_tracking(
    p_title_id INT,
    p_media_type public.media_type_enum,
    p_client_mutation_id UUID DEFAULT NULL
)
RETURNS public.user_tracking
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
    v_row public.user_tracking;
    v_s INT;
    v_e INT;
    v_today DATE := public._user_today(v_user);
BEGIN
    IF NOT public._claim_mutation(p_client_mutation_id, v_user, 'tracking_finish') THEN
        SELECT * INTO v_row FROM public.user_tracking
        WHERE user_id = v_user AND title_id = p_title_id AND media_type = p_media_type;
        RETURN v_row;
    END IF;

    SELECT * INTO v_row FROM public.user_tracking
    WHERE user_id = v_user AND title_id = p_title_id AND media_type = p_media_type FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'not tracking this title' USING ERRCODE = 'P0002';
    END IF;

    IF p_media_type = 'movie' THEN
        IF v_row.state = 'FINISHED' THEN
            RETURN v_row;
        END IF;
        UPDATE public.user_tracking SET state = 'FINISHED', finished_at = NOW(), last_progress_at = NOW()
        WHERE user_id = v_user AND title_id = p_title_id AND media_type = p_media_type
        RETURNING * INTO v_row;
        INSERT INTO public.user_tracking_events (user_id, title_id, media_type, kind)
        VALUES (v_user, p_title_id, 'movie'::public.media_type_enum, 'FINISHED');
        PERFORM public._tracking_post_activity(v_user, p_title_id, 'movie', 'WATCH_FINISHED');
        RETURN v_row;
    END IF;

    SELECT s.season_number, e.n INTO v_s, v_e
    FROM public.tv_seasons s
    CROSS JOIN LATERAL generate_series(1, s.episode_count) AS e(n)
    WHERE s.title_id = p_title_id AND s.season_number >= 1
      AND public._episode_aired(p_title_id, s.season_number, e.n, v_today)
    ORDER BY s.season_number DESC, e.n DESC
    LIMIT 1;
    IF v_s IS NULL THEN
        RAISE EXCEPTION 'no episode has aired yet' USING ERRCODE = '22023';
    END IF;
    RETURN public._tracking_move(v_row, v_s, v_e);
END;
$$;

-- Deletes the row. The events stay, so the year's stats don't shrink (§4.9).
CREATE OR REPLACE FUNCTION public.stop_tracking(
    p_title_id INT,
    p_media_type public.media_type_enum,
    p_client_mutation_id UUID DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
BEGIN
    IF NOT public._claim_mutation(p_client_mutation_id, v_user, 'tracking_stop') THEN
        RETURN;
    END IF;
    DELETE FROM public.user_tracking
    WHERE user_id = v_user AND title_id = p_title_id AND media_type = p_media_type;
END;
$$;

-- Graveyard "Revive": deletes the drop entry and tracks from its drop point (§4.7). A drop with a
-- season but no episode resumes at the start of that season, so the place is the end of the one
-- before (NULL for season 1). Posts no activity.
CREATE OR REPLACE FUNCTION public.revive_dropped_show(
    p_title_id INT,
    p_client_mutation_id UUID DEFAULT NULL
)
RETURNS public.user_tracking
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
    v_drop public.user_dropped_shows;
    v_row public.user_tracking;
    v_s INT;
    v_e INT;
BEGIN
    IF NOT public._claim_mutation(p_client_mutation_id, v_user, 'tracking_revive') THEN
        SELECT * INTO v_row FROM public.user_tracking
        WHERE user_id = v_user AND title_id = p_title_id AND media_type = 'tv';
        RETURN v_row;
    END IF;

    SELECT * INTO v_drop FROM public.user_dropped_shows d
    WHERE d.user_id = v_user AND d.title_id = p_title_id AND d.media_type = 'tv' FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'show is not in the graveyard' USING ERRCODE = 'P0002';
    END IF;

    IF v_drop.dropped_at_season IS NOT NULL AND v_drop.dropped_at_episode IS NOT NULL THEN
        v_s := v_drop.dropped_at_season;
        v_e := v_drop.dropped_at_episode;
    ELSIF v_drop.dropped_at_season IS NOT NULL AND v_drop.dropped_at_season > 1 THEN
        SELECT s.season_number, s.episode_count INTO v_s, v_e
        FROM public.tv_seasons s
        WHERE s.title_id = p_title_id AND s.season_number < v_drop.dropped_at_season
          AND s.season_number >= 1 AND s.episode_count >= 1
        ORDER BY s.season_number DESC LIMIT 1;
    END IF;

    DELETE FROM public.user_dropped_shows d
    WHERE d.user_id = v_user AND d.title_id = p_title_id AND d.media_type = 'tv';
    RETURN public._tracking_start(v_user, p_title_id, 'tv', v_s, v_e, FALSE, FALSE);
END;
$$;

-- -----------------------------------------------------------------------------
-- 7. GRANTS: only the RPCs are callable by signed-in users
-- -----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public._user_today(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._episode_aired(INT, INT, INT, DATE) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._tracking_next(INT, INT, INT, DATE) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._tracking_state(INT, public.media_type_enum, INT, INT, TIMESTAMPTZ, DATE)
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._tracking_clamp(INT, INT, INT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._tracking_ordinal(INT, INT, INT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._tracking_episodes_between(INT, INT, INT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._tracking_post_activity(UUID, INT, public.media_type_enum, TEXT)
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._tracking_move(public.user_tracking, INT, INT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._tracking_start(UUID, INT, public.media_type_enum, INT, INT, BOOLEAN, BOOLEAN)
    FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.start_tracking(INT, public.media_type_enum, INT, INT, BOOLEAN, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.set_tracking_place(INT, public.media_type_enum, INT, INT, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.log_episode_rewatch(INT, INT, INT, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.finish_tracking(INT, public.media_type_enum, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.stop_tracking(INT, public.media_type_enum, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.revive_dropped_show(INT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.start_tracking(INT, public.media_type_enum, INT, INT, BOOLEAN, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_tracking_place(INT, public.media_type_enum, INT, INT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_episode_rewatch(INT, INT, INT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.finish_tracking(INT, public.media_type_enum, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stop_tracking(INT, public.media_type_enum, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.revive_dropped_show(INT, UUID) TO authenticated;
