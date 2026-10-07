-- Migration 20261010002000_medals.sql
-- #136 (epic #50): medals end to end on the server (Spec 10 §4, §10).
--
-- * achievements: the medal catalogue, seeded with the slice-1 launch medals (§4.1).
-- * user_achievements: unlocks, seen_at for the unlock moment, and pinned slots 1–3 (§4.2, §4.4).
-- * evaluate_achievements(user): idempotent; never revokes. Statement-level triggers run it
--   after writes to user_rankings, pairwise_duels, user_dropped_shows, social_follows and
--   taste_matches (drops and follows are direct table writes, so triggers cover every path),
--   and a nightly job sweeps everyone for taste and streak medals.
-- * pin_achievement / unpin_achievement / my_achievements / mark_achievements_seen.
-- * achievement_rarity, refreshed nightly over users signed in during the last 90 days.
-- * activity_logs gains MEDAL_UNLOCKED, written only when users.share_achievements is on.
--
-- Backward compatible: get_activity_feed gains p_include_medals DEFAULT FALSE, so shipped
-- apps (which would render an unknown type as a broken ranking card) never see medal rows.
-- Founding Viewer stays locked until _public_launch_date() returns a date (owner decision).
-- Existing users are backfilled at the end, without feed posts.

-- -----------------------------------------------------------------------------
-- 1. CATALOGUE
-- -----------------------------------------------------------------------------
CREATE TYPE public.achievement_kind_enum AS ENUM ('milestone', 'taste', 'streak', 'collection', 'challenge', 'special');
CREATE TYPE public.achievement_tier_enum AS ENUM ('bronze', 'silver', 'gold', 'special');

CREATE TABLE public.achievements (
    id TEXT PRIMARY KEY CHECK (id ~ '^[a-z0-9_]{2,64}$'),
    kind public.achievement_kind_enum NOT NULL,
    tier public.achievement_tier_enum NOT NULL,
    name VARCHAR(64) NOT NULL,
    description VARCHAR(160) NOT NULL,
    glyph VARCHAR(4) NOT NULL,
    media_type public.media_type_enum,
    threshold INT CHECK (threshold IS NULL OR threshold > 0),
    collection_id INT,
    challenge_id UUID,
    sort INT NOT NULL DEFAULT 0,
    active BOOLEAN NOT NULL DEFAULT TRUE
);

INSERT INTO public.achievements (id, kind, tier, name, description, glyph, media_type, threshold, sort) VALUES
    ('movies_10',        'milestone', 'bronze',  'Ticket Stub',     'Rank 10 films',                                   '10',  'movie', 10,  1),
    ('tv_10',            'milestone', 'bronze',  'Ticket Stub',     'Rank 10 series',                                  '10',  'tv',    10,  2),
    ('movies_50',        'milestone', 'silver',  'Half-Centurion',  'Rank 50 films',                                   '50',  'movie', 50,  3),
    ('tv_50',            'milestone', 'silver',  'Half-Centurion',  'Rank 50 series',                                  '50',  'tv',    50,  4),
    ('movies_100',       'milestone', 'gold',    'Centurion',       'Rank 100 films',                                  '100', 'movie', 100, 5),
    ('tv_100',           'milestone', 'gold',    'Centurion',       'Rank 100 series',                                 '100', 'tv',    100, 6),
    ('upset_artist',     'taste',     'special', 'Upset Artist',    'Call 5 upsets in your duels',                     '↯',   NULL,    5,   1),
    ('taste_twin',       'taste',     'special', 'Taste Twin',      'Follow someone with a 92% taste match',           'TT',  NULL,    92,  2),
    ('decade_hopper',    'taste',     'silver',  'Decade Hopper',   'Rank titles from 5 different decades',            '5D',  NULL,    5,   3),
    ('genre_explorer',   'taste',     'silver',  'Genre Explorer',  'Rank titles across 8 different genres',           '8G',  NULL,    8,   4),
    ('graveyard_keeper', 'taste',     'bronze',  'Graveyard Keeper', 'Bury 5 shows in your TV Graveyard',              'RIP', 'tv',    5,   5),
    ('streak_4',         'streak',    'bronze',  'Regular',         'Keep a 4-week streak',                            '4',   NULL,    4,   1),
    ('streak_12',        'streak',    'silver',  'Devotee',         'Keep a 12-week streak',                           '12',  NULL,    12,  2),
    ('streak_52',        'streak',    'gold',    'Year-Rounder',    'Keep a 52-week streak',                           '52',  NULL,    52,  3),
    ('founding_viewer',  'special',   'special', 'Founding Viewer', 'Joined Telly in its first 90 days',               'F',   NULL,    1,   1);

-- The public launch date. NULL until the owner sets it; Founding Viewer stays locked until then.
CREATE OR REPLACE FUNCTION public._public_launch_date()
RETURNS DATE
LANGUAGE sql
IMMUTABLE
AS $$ SELECT NULL::DATE $$;

-- -----------------------------------------------------------------------------
-- 2. UNLOCKS, RARITY, PRIVACY TOGGLE
-- -----------------------------------------------------------------------------
CREATE TABLE public.user_achievements (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    achievement_id TEXT NOT NULL REFERENCES public.achievements(id) ON DELETE CASCADE,
    unlocked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    seen_at TIMESTAMPTZ,
    pinned_slot SMALLINT CHECK (pinned_slot BETWEEN 1 AND 3),
    PRIMARY KEY (user_id, achievement_id),
    CONSTRAINT uq_user_achievements_pinned_slot UNIQUE (user_id, pinned_slot)
);
CREATE INDEX idx_user_achievements_achievement ON public.user_achievements (achievement_id);

CREATE TABLE public.achievement_rarity (
    achievement_id TEXT PRIMARY KEY REFERENCES public.achievements(id) ON DELETE CASCADE,
    holders INT NOT NULL,
    active_users INT NOT NULL,
    percent NUMERIC(5, 2) NOT NULL,
    computed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.users ADD COLUMN share_achievements BOOLEAN NOT NULL DEFAULT TRUE;
GRANT UPDATE (share_achievements) ON public.users TO authenticated;

ALTER TABLE public.activity_logs DROP CONSTRAINT activity_logs_activity_type_check;
ALTER TABLE public.activity_logs ADD CONSTRAINT activity_logs_activity_type_check CHECK (activity_type IN (
    'RANKING_CREATED', 'UPSET_ALERT', 'SHOW_DROPPED', 'QUEUE_ADDED', 'COMMENT_POSTED', 'MEDAL_UNLOCKED'
));

ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.achievement_rarity ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.achievements, public.user_achievements, public.achievement_rarity FROM anon;
CREATE POLICY achievements_read ON public.achievements FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY achievement_rarity_read ON public.achievement_rarity FOR SELECT TO authenticated USING (TRUE);
-- Unlocks and pins are visible wherever the profile is (friend profiles show pinned medals).
CREATE POLICY user_achievements_select ON public.user_achievements FOR SELECT TO authenticated
    USING (public.can_view_user(user_id));
REVOKE INSERT, UPDATE, DELETE ON public.achievements, public.user_achievements, public.achievement_rarity
    FROM authenticated;

-- -----------------------------------------------------------------------------
-- 3. PROGRESS AND EVALUATION
-- -----------------------------------------------------------------------------
-- Progress towards every active slice-1 medal (plus any retired one the user holds). Reads
-- as the definer, so RLS doesn't hide the user's own data; only internal callers use it.
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
                               WHERE ua.user_id = p_user AND ua.achievement_id = a.id));
END;
$$;

-- Unlocks every active medal whose target is met. Idempotent; never revokes. Each new
-- unlock posts MEDAL_UNLOCKED when p_broadcast and the user shares achievements.
CREATE OR REPLACE FUNCTION public.evaluate_achievements(p_user UUID, p_broadcast BOOLEAN DEFAULT TRUE)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_share BOOLEAN;
    v_ids TEXT[];
    v_row RECORD;
BEGIN
    SELECT u.share_achievements INTO v_share FROM public.users u WHERE u.id = p_user AND NOT u.is_deleted;
    IF NOT FOUND THEN
        RETURN 0;
    END IF;

    WITH unlocked AS (
        INSERT INTO public.user_achievements (user_id, achievement_id)
        SELECT p_user, a.id
        FROM public._achievement_progress(p_user) p
        JOIN public.achievements a ON a.id = p.achievement_id
        WHERE a.active AND a.threshold IS NOT NULL AND p.progress >= a.threshold
        ON CONFLICT (user_id, achievement_id) DO NOTHING
        RETURNING achievement_id
    )
    SELECT COALESCE(array_agg(achievement_id), ARRAY[]::TEXT[]) INTO v_ids FROM unlocked;

    FOR v_row IN
        SELECT a.id, a.name, a.tier, a.glyph, a.kind
        FROM public.achievements a WHERE a.id = ANY (v_ids)
        ORDER BY a.kind, a.sort
    LOOP
        IF p_broadcast AND v_share THEN
            INSERT INTO public.activity_logs (user_id, activity_type, metadata)
            VALUES (p_user, 'MEDAL_UNLOCKED', jsonb_build_object(
                'achievement_id', v_row.id, 'name', v_row.name, 'tier', v_row.tier,
                'glyph', v_row.glyph, 'kind', v_row.kind));
        END IF;
    END LOOP;
    RETURN cardinality(v_ids);
END;
$$;

-- Nightly sweep (taste and streak medals can change without a write by the user).
CREATE OR REPLACE FUNCTION public.evaluate_all_achievements()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID;
    v_total INT := 0;
BEGIN
    FOR v_user IN SELECT id FROM public.users WHERE NOT is_deleted LOOP
        v_total := v_total + public.evaluate_achievements(v_user);
    END LOOP;
    RETURN v_total;
END;
$$;

-- -----------------------------------------------------------------------------
-- 4. TRIGGERS (statement level: one evaluation per affected user per statement)
--    Duels are evaluated once at the end of record_pairwise_duels (§5) instead: it inserts
--    one statement per duel, so a trigger would evaluate once per duel.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._achievements_after_rankings()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_user UUID;
BEGIN
    FOR v_user IN SELECT DISTINCT n.user_id FROM new_rows n WHERE n.status = 'COMPLETED' LOOP
        PERFORM public.evaluate_achievements(v_user);
    END LOOP;
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public._achievements_after_ranking_status()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_user UUID;
BEGIN
    FOR v_user IN SELECT DISTINCT n.user_id FROM new_rows n JOIN old_rows o ON o.id = n.id
                  WHERE n.status = 'COMPLETED' AND o.status <> 'COMPLETED' LOOP
        PERFORM public.evaluate_achievements(v_user);
    END LOOP;
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public._achievements_after_user_rows()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_user UUID;
BEGIN
    FOR v_user IN SELECT DISTINCT n.user_id FROM new_rows n LOOP
        PERFORM public.evaluate_achievements(v_user);
    END LOOP;
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public._achievements_after_follows()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_user UUID;
BEGIN
    FOR v_user IN SELECT DISTINCT n.follower_id FROM new_rows n WHERE n.status = 'accepted' LOOP
        PERFORM public.evaluate_achievements(v_user);
    END LOOP;
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public._achievements_after_taste_matches()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_user UUID;
BEGIN
    FOR v_user IN SELECT n.user_a FROM new_rows n WHERE n.match_percentage >= 92
                  UNION SELECT n.user_b FROM new_rows n WHERE n.match_percentage >= 92 LOOP
        PERFORM public.evaluate_achievements(v_user);
    END LOOP;
    RETURN NULL;
END;
$$;

-- Transition tables allow one event per trigger, so inserts and updates are separate.
CREATE TRIGGER trg_user_rankings_achievements_ins AFTER INSERT ON public.user_rankings
    REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION public._achievements_after_rankings();
-- Only a status change to COMPLETED matters; rank shifts and editorial edits don't.
CREATE TRIGGER trg_user_rankings_achievements_upd AFTER UPDATE ON public.user_rankings
    REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows
    FOR EACH STATEMENT EXECUTE FUNCTION public._achievements_after_ranking_status();
CREATE TRIGGER trg_user_dropped_shows_achievements AFTER INSERT ON public.user_dropped_shows
    REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION public._achievements_after_user_rows();
CREATE TRIGGER trg_social_follows_achievements_ins AFTER INSERT ON public.social_follows
    REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION public._achievements_after_follows();
CREATE TRIGGER trg_social_follows_achievements_upd AFTER UPDATE ON public.social_follows
    REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION public._achievements_after_follows();
CREATE TRIGGER trg_taste_matches_achievements_ins AFTER INSERT ON public.taste_matches
    REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION public._achievements_after_taste_matches();
CREATE TRIGGER trg_taste_matches_achievements_upd AFTER UPDATE ON public.taste_matches
    REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION public._achievements_after_taste_matches();

-- -----------------------------------------------------------------------------
-- 5. CLIENT RPCs
-- -----------------------------------------------------------------------------
-- Duels: record as before (20261010001900), then evaluate medals once for the batch.
CREATE OR REPLACE FUNCTION public.record_pairwise_duels(p_duels JSONB)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
    v_duel JSONB;
    v_winner INT;
    v_loser INT;
    v_media public.media_type_enum;
    v_upset RECORD;
    v_inserted INT := 0;
    v_id UUID;
BEGIN
    IF jsonb_typeof(p_duels) <> 'array' THEN
        RAISE EXCEPTION 'p_duels must be a JSON array' USING ERRCODE = '22023';
    END IF;

    FOR v_duel IN SELECT * FROM jsonb_array_elements(p_duels) LOOP
        v_winner := (v_duel ->> 'winner_title_id')::INT;
        v_loser := (v_duel ->> 'loser_title_id')::INT;
        v_media := (v_duel ->> 'media_type')::public.media_type_enum;

        IF NOT public._claim_mutation((v_duel ->> 'client_mutation_id')::UUID, v_user, 'DUEL') THEN
            CONTINUE;
        END IF;

        SELECT * INTO v_upset FROM public.detect_upset_duel(v_winner, v_loser, v_media);

        INSERT INTO public.pairwise_duels (
            user_id, winner_title_id, loser_title_id, media_type, is_upset, decision_time_ms,
            client_mutation_id, placed_title_id
        ) VALUES (
            v_user, v_winner, v_loser, v_media, v_upset.is_upset,
            (v_duel ->> 'decision_time_ms')::INT, (v_duel ->> 'client_mutation_id')::UUID,
            (v_duel ->> 'placed_title_id')::INT
        )
        RETURNING id INTO v_id;
        v_inserted := v_inserted + 1;

        IF v_upset.is_upset THEN
            INSERT INTO public.activity_logs (
                user_id, activity_type, title_id, media_type, is_upset, upset_delta, metadata
            ) VALUES (
                v_user, 'UPSET_ALERT', v_winner, v_media, TRUE, v_upset.delta,
                jsonb_build_object(
                    'duel_id', v_id,
                    'loser_title_id', v_loser,
                    'winner_consensus', v_upset.winner_consensus,
                    'loser_consensus', v_upset.loser_consensus
                )
            );
        END IF;
    END LOOP;

    -- #136: one medal evaluation per batch
    IF v_inserted > 0 THEN
        PERFORM public.evaluate_achievements(v_user);
    END IF;

    RETURN v_inserted;
END;
$$;

REVOKE ALL ON FUNCTION public.record_pairwise_duels(JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_pairwise_duels(JSONB) TO authenticated;

-- SCR-23: the catalogue with my progress, unlocks, pins, rarity and followed holders.
-- Retired medals appear only for people who hold them.
CREATE OR REPLACE FUNCTION public.my_achievements()
RETURNS TABLE (
    id TEXT,
    kind public.achievement_kind_enum,
    tier public.achievement_tier_enum,
    name VARCHAR,
    description VARCHAR,
    glyph VARCHAR,
    media_type public.media_type_enum,
    threshold INT,
    sort INT,
    progress INT,
    unlocked_at TIMESTAMPTZ,
    seen_at TIMESTAMPTZ,
    pinned_slot SMALLINT,
    rarity_percent NUMERIC,
    rarity_is_new BOOLEAN,
    friends_count INT,
    friends JSONB
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
    WITH followed AS (
        SELECT f.following_id AS uid FROM public.social_follows f
        JOIN public.users u ON u.id = f.following_id AND NOT u.is_deleted
        WHERE f.follower_id = v_user AND f.status = 'accepted'
          AND public.can_view_user(f.following_id)
    )
    SELECT a.id, a.kind, a.tier, a.name, a.description, a.glyph, a.media_type, a.threshold, a.sort,
        LEAST(p.progress, COALESCE(a.threshold, p.progress)),
        ua.unlocked_at, ua.seen_at, ua.pinned_slot,
        CASE WHEN r.active_users >= 200 THEN r.percent END,
        COALESCE(r.active_users, 0) < 200,
        (SELECT count(*)::INT FROM public.user_achievements fa JOIN followed fo ON fo.uid = fa.user_id
         WHERE fa.achievement_id = a.id),
        COALESCE((
            SELECT jsonb_agg(jsonb_build_object('user_id', x.id, 'username', x.username,
                                                'display_name', x.display_name, 'avatar_url', x.avatar_url))
            FROM (SELECT u.id, u.username, u.display_name, u.avatar_url
                  FROM public.user_achievements fa
                  JOIN followed fo ON fo.uid = fa.user_id
                  JOIN public.users u ON u.id = fa.user_id
                  WHERE fa.achievement_id = a.id
                  ORDER BY fa.unlocked_at DESC
                  LIMIT 5) x), '[]'::jsonb)
    FROM public._achievement_progress(v_user) p
    JOIN public.achievements a ON a.id = p.achievement_id
    LEFT JOIN public.user_achievements ua ON ua.user_id = v_user AND ua.achievement_id = a.id
    LEFT JOIN public.achievement_rarity r ON r.achievement_id = a.id
    ORDER BY a.kind, a.sort;
END;
$$;

CREATE OR REPLACE FUNCTION public.pin_achievement(p_achievement_id TEXT, p_slot INT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
BEGIN
    IF p_slot IS NULL OR p_slot NOT BETWEEN 1 AND 3 THEN
        RAISE EXCEPTION 'pin slot must be 1, 2 or 3' USING ERRCODE = '22023';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.user_achievements
                   WHERE user_id = v_user AND achievement_id = p_achievement_id) THEN
        RAISE EXCEPTION 'medal % is not unlocked', p_achievement_id USING ERRCODE = '22023';
    END IF;
    -- free the slot, then move the medal into it (from another slot, if it was pinned)
    UPDATE public.user_achievements SET pinned_slot = NULL
    WHERE user_id = v_user AND pinned_slot = p_slot AND achievement_id <> p_achievement_id;
    UPDATE public.user_achievements SET pinned_slot = p_slot
    WHERE user_id = v_user AND achievement_id = p_achievement_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.unpin_achievement(p_slot INT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
BEGIN
    UPDATE public.user_achievements SET pinned_slot = NULL WHERE user_id = v_user AND pinned_slot = p_slot;
END;
$$;

-- Marks unlocks as seen after the unlock moment (SCR-24). NULL marks every unseen unlock.
CREATE OR REPLACE FUNCTION public.mark_achievements_seen(p_achievement_ids TEXT[] DEFAULT NULL)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
    v_n INT;
BEGIN
    UPDATE public.user_achievements SET seen_at = NOW()
    WHERE user_id = v_user AND seen_at IS NULL
      AND (p_achievement_ids IS NULL OR achievement_id = ANY (p_achievement_ids));
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END;
$$;

-- -----------------------------------------------------------------------------
-- 6. RARITY (nightly)
-- -----------------------------------------------------------------------------
-- Holders among users signed in during the last 90 days. Under 200 such users the app
-- shows "New: not enough viewers yet" (my_achievements.rarity_is_new).
CREATE OR REPLACE FUNCTION public.refresh_achievement_rarity(p_now TIMESTAMPTZ DEFAULT NOW())
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_active INT;
    v_n INT;
BEGIN
    SELECT count(*) INTO v_active
    FROM public.users u JOIN auth.users au ON au.id = u.id
    WHERE NOT u.is_deleted AND au.last_sign_in_at >= p_now - INTERVAL '90 days';

    INSERT INTO public.achievement_rarity (achievement_id, holders, active_users, percent, computed_at)
    SELECT a.id, h.n, v_active,
           CASE WHEN v_active = 0 THEN 0 ELSE ROUND(h.n * 100.0 / v_active, 2) END, p_now
    FROM public.achievements a
    CROSS JOIN LATERAL (
        SELECT count(*)::INT AS n
        FROM public.user_achievements ua
        JOIN public.users u ON u.id = ua.user_id AND NOT u.is_deleted
        JOIN auth.users au ON au.id = ua.user_id
        WHERE ua.achievement_id = a.id AND au.last_sign_in_at >= p_now - INTERVAL '90 days'
    ) h
    ON CONFLICT (achievement_id) DO UPDATE
        SET holders = EXCLUDED.holders, active_users = EXCLUDED.active_users,
            percent = EXCLUDED.percent, computed_at = EXCLUDED.computed_at;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END;
$$;

-- -----------------------------------------------------------------------------
-- 7. FEED: medal rows only for apps that ask for them
-- -----------------------------------------------------------------------------
DROP FUNCTION public.get_activity_feed(TEXT, TIMESTAMPTZ, INT, UUID);

CREATE OR REPLACE FUNCTION public.get_activity_feed(
    p_filter TEXT DEFAULT 'following',
    p_before TIMESTAMPTZ DEFAULT NULL,
    p_limit INT DEFAULT 20,
    p_before_id UUID DEFAULT NULL,
    p_include_medals BOOLEAN DEFAULT FALSE
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
      -- #136: medal cards need an app that knows them (#139); older apps never get the rows.
      AND (p_include_medals OR a.activity_type <> 'MEDAL_UNLOCKED')
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

-- -----------------------------------------------------------------------------
-- 8. GRANTS, SCHEDULES, BACKFILL
-- -----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public._public_launch_date() FROM PUBLIC;
REVOKE ALL ON FUNCTION public._achievement_progress(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.evaluate_achievements(UUID, BOOLEAN) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.evaluate_all_achievements() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.refresh_achievement_rarity(TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._achievements_after_rankings() FROM PUBLIC;
REVOKE ALL ON FUNCTION public._achievements_after_ranking_status() FROM PUBLIC;
REVOKE ALL ON FUNCTION public._achievements_after_user_rows() FROM PUBLIC;
REVOKE ALL ON FUNCTION public._achievements_after_follows() FROM PUBLIC;
REVOKE ALL ON FUNCTION public._achievements_after_taste_matches() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.my_achievements() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pin_achievement(TEXT, INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.unpin_achievement(INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mark_achievements_seen(TEXT[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_activity_feed(TEXT, TIMESTAMPTZ, INT, UUID, BOOLEAN) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.evaluate_achievements(UUID, BOOLEAN) TO service_role;
GRANT EXECUTE ON FUNCTION public.evaluate_all_achievements() TO service_role;
GRANT EXECUTE ON FUNCTION public.refresh_achievement_rarity(TIMESTAMPTZ) TO service_role;
GRANT EXECUTE ON FUNCTION public.my_achievements() TO authenticated;
GRANT EXECUTE ON FUNCTION public.pin_achievement(TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unpin_achievement(INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_achievements_seen(TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_activity_feed(TEXT, TIMESTAMPTZ, INT, UUID, BOOLEAN) TO authenticated;

SELECT cron.schedule('evaluate-achievements', '37 2 * * *', $$SELECT public.evaluate_all_achievements()$$);
SELECT cron.schedule('refresh-achievement-rarity', '57 2 * * *', $$SELECT public.refresh_achievement_rarity()$$);

-- Existing users get the medals they've already earned, without feed posts.
SELECT public.evaluate_achievements(id, FALSE) FROM public.users WHERE NOT is_deleted;
SELECT public.refresh_achievement_rarity();
