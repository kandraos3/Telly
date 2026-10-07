-- Migration 20261010002600_levels.sql
-- #145 (epic #50): XP ledger, levels, weekly quests, rewards and the weekly friends table
-- (Spec 10 §5, §6, §9.8).
--
-- * xp_ledger: append-only (no client writes, no updates), unique (user_id, source, ref), so
--   re-ranking a title or re-running evaluation never earns twice. _award_xp(user) writes
--   ranking (+10, at most 10 a week), medal (+25), collection (+100), challenge (+150, squad
--   +100), streak (+25 a counted week) and quest XP; it runs at the end of
--   evaluate_achievements, so every ranking, duel, join and the nightly job cover it.
-- * my_level(): the 250 × L curve and the level names.
-- * quest_templates / user_quests / my_week(): three quests a week (easy, exploration, Queue),
--   picked deterministically from the user and the week and stored on first read.
-- * rewards / user_reward_choices: cosmetic rewards unlocked by level; equip / unequip.
-- * weekly_xp_table(squad): this week's XP for me and the people I follow, or a squad.
-- Existing users are backfilled at the end.

-- -----------------------------------------------------------------------------
-- 1. WEEKS AND LEVELS
-- -----------------------------------------------------------------------------
-- ISO week label of [p_at] in time zone [p_tz], e.g. "2026-W41" (§3).
CREATE OR REPLACE FUNCTION public._week_label(p_at TIMESTAMPTZ, p_tz TEXT)
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$ SELECT to_char(date_trunc('week', p_at AT TIME ZONE COALESCE(p_tz, 'UTC')), 'IYYY-"W"IW') $$;

-- Level for a total: the largest L with 125·L·(L−1) ≤ xp (§5.1).
CREATE OR REPLACE FUNCTION public._level_for_xp(p_xp INT)
RETURNS INT
LANGUAGE sql
IMMUTABLE
AS $$ SELECT GREATEST(1, floor((1 + sqrt(1 + 4.0 * GREATEST(p_xp, 0) / 125)) / 2)::INT) $$;

CREATE OR REPLACE FUNCTION public._level_floor(p_level INT)
RETURNS INT
LANGUAGE sql
IMMUTABLE
AS $$ SELECT 125 * p_level * (p_level - 1) $$;

CREATE OR REPLACE FUNCTION public._level_name(p_level INT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE
        WHEN p_level >= 30 THEN 'Legend'
        WHEN p_level >= 20 THEN 'Auteur'
        WHEN p_level >= 15 THEN 'Critic'
        WHEN p_level >= 10 THEN 'Cinephile'
        WHEN p_level >= 5 THEN 'Regular'
        ELSE 'Extra'
    END;
$$;

-- -----------------------------------------------------------------------------
-- 2. THE LEDGER
-- -----------------------------------------------------------------------------
CREATE TYPE public.xp_source_enum AS ENUM
    ('ranking', 'quest', 'streak', 'medal', 'collection', 'challenge', 'referral', 'correction');

CREATE TABLE public.xp_ledger (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    amount INT NOT NULL CHECK (amount <> 0),
    source public.xp_source_enum NOT NULL,
    ref TEXT NOT NULL,
    week TEXT NOT NULL CHECK (week ~ '^\d{4}-W\d{2}$'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_xp_ledger_ref UNIQUE (user_id, source, ref),
    CONSTRAINT chk_xp_ledger_positive CHECK (source = 'correction' OR amount > 0)
);
CREATE INDEX idx_xp_ledger_user_week ON public.xp_ledger (user_id, week);

-- Append-only: corrections are new rows (§6).
CREATE OR REPLACE FUNCTION public._xp_ledger_append_only()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'xp_ledger is append-only; add a correction row instead' USING ERRCODE = '42501';
END;
$$;
CREATE TRIGGER trg_xp_ledger_append_only BEFORE UPDATE ON public.xp_ledger
    FOR EACH ROW EXECUTE FUNCTION public._xp_ledger_append_only();

ALTER TABLE public.xp_ledger ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.xp_ledger FROM anon;
CREATE POLICY xp_ledger_select_own ON public.xp_ledger FOR SELECT TO authenticated USING (user_id = auth.uid());
REVOKE INSERT, UPDATE, DELETE ON public.xp_ledger FROM authenticated;
REVOKE USAGE ON SEQUENCE public.xp_ledger_id_seq FROM authenticated, anon;

-- -----------------------------------------------------------------------------
-- 3. QUESTS (§9.8)
-- -----------------------------------------------------------------------------
-- kind: 'rule' (a §8.2 rule, "$param" placeholders filled at assignment) or
-- 'finish_from_queue' (rank titles that were in your Queue).
CREATE TABLE public.quest_templates (
    key TEXT PRIMARY KEY CHECK (key ~ '^[a-z0-9_]{2,40}$'),
    title VARCHAR(80) NOT NULL,
    difficulty TEXT NOT NULL CHECK (difficulty IN ('easy', 'explore', 'queue')),
    kind TEXT NOT NULL DEFAULT 'rule' CHECK (kind IN ('rule', 'finish_from_queue')),
    rule JSONB NOT NULL DEFAULT '{"media_type": "any", "filters": []}'::jsonb,
    param TEXT CHECK (param IS NULL OR param IN ('genre', 'decade')),
    target INT NOT NULL CHECK (target BETWEEN 1 AND 20),
    xp INT NOT NULL CHECK (xp BETWEEN 1 AND 500),
    active BOOLEAN NOT NULL DEFAULT TRUE
);

INSERT INTO public.quest_templates (key, title, difficulty, kind, rule, param, target, xp) VALUES
    ('rank_one',     'Rank a title this week',              'easy',    'rule', '{"media_type": "any", "filters": []}', NULL, 1, 40),
    ('rank_three',   'Rank 3 titles this week',             'easy',    'rule', '{"media_type": "any", "filters": []}', NULL, 3, 40),
    ('rank_film',    'Rank a film this week',               'easy',    'rule', '{"media_type": "movie", "filters": []}', NULL, 1, 40),
    ('explore_genre', 'Rank 2 $genre titles',               'explore', 'rule',
        '{"media_type": "any", "filters": [{"type": "genre", "any": ["$genre"]}]}', 'genre', 2, 50),
    ('explore_decade', 'Rank a film from the $decades',     'explore', 'rule',
        '{"media_type": "movie", "filters": [{"type": "decade", "any": ["$decade"]}]}', 'decade', 1, 50),
    ('queue_one',    'Rank something from your Queue',      'queue',   'finish_from_queue', DEFAULT, NULL, 1, 60),
    ('queue_two',    'Rank 2 titles from your Queue',       'queue',   'finish_from_queue', DEFAULT, NULL, 2, 60);

CREATE TABLE public.user_quests (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    week TEXT NOT NULL CHECK (week ~ '^\d{4}-W\d{2}$'),
    slot SMALLINT NOT NULL CHECK (slot BETWEEN 1 AND 3),
    quest_key TEXT NOT NULL REFERENCES public.quest_templates(key),
    title VARCHAR(80) NOT NULL,
    kind TEXT NOT NULL,
    rule JSONB NOT NULL,
    target INT NOT NULL,
    xp INT NOT NULL,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    PRIMARY KEY (user_id, week, slot)
);

ALTER TABLE public.quest_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_quests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.quest_templates, public.user_quests FROM anon;
CREATE POLICY quest_templates_read ON public.quest_templates FOR SELECT TO authenticated USING (active);
CREATE POLICY user_quests_select_own ON public.user_quests FOR SELECT TO authenticated USING (user_id = auth.uid());
REVOKE INSERT, UPDATE, DELETE ON public.quest_templates, public.user_quests FROM authenticated;

-- Monday 00:00 of [p_week] in [p_tz], and the Monday after.
CREATE OR REPLACE FUNCTION public._week_bounds(p_week TEXT, p_tz TEXT, OUT starts_at TIMESTAMPTZ, OUT ends_at TIMESTAMPTZ)
LANGUAGE sql
STABLE
AS $$
    SELECT (to_date(p_week, 'IYYY-"W"IW')::TIMESTAMP) AT TIME ZONE COALESCE(p_tz, 'UTC'),
           (to_date(p_week, 'IYYY-"W"IW')::TIMESTAMP + INTERVAL '7 days') AT TIME ZONE COALESCE(p_tz, 'UTC');
$$;

-- A deterministic pick among [p_n] options, seeded by user, week and slot.
CREATE OR REPLACE FUNCTION public._seeded_index(p_user UUID, p_week TEXT, p_salt TEXT, p_n INT)
RETURNS INT
LANGUAGE sql
IMMUTABLE
AS $$ SELECT CASE WHEN p_n <= 0 THEN 0 ELSE (abs(hashtextextended(p_user::TEXT || p_week || p_salt, 0)) % p_n)::INT END $$;

-- Progress on one assigned quest: qualifying rankings made that week that match it.
CREATE OR REPLACE FUNCTION public._quest_progress(p_quest public.user_quests, p_tz TEXT)
RETURNS INT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT LEAST(count(*)::INT, p_quest.target)
    FROM public.qualifying_rankings q
    JOIN public.titles t ON t.id = q.title_id AND t.media_type = q.media_type
    CROSS JOIN public._week_bounds(p_quest.week, p_tz) b
    WHERE q.user_id = p_quest.user_id
      AND q.created_at >= b.starts_at AND q.created_at < b.ends_at
      AND CASE p_quest.kind
              WHEN 'finish_from_queue' THEN EXISTS (
                  SELECT 1 FROM public.activity_logs a
                  WHERE a.user_id = q.user_id AND a.activity_type = 'QUEUE_ADDED'
                    AND a.title_id = q.title_id AND a.media_type = q.media_type AND a.created_at <= q.created_at)
              ELSE public._title_matches_rule(p_quest.rule, t)
          END;
$$;

-- The week's three quests, assigned on first call: one easy, one exploration (the genre or
-- decade you rank least), one Queue quest. Stored, so a refresh never reshuffles them.
CREATE OR REPLACE FUNCTION public._assign_quests(p_user UUID, p_week TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_slot INT := 0;
    v_diff TEXT;
    v_t public.quest_templates;
    v_n INT;
    v_value JSONB;
    v_title TEXT;
BEGIN
    IF EXISTS (SELECT 1 FROM public.user_quests WHERE user_id = p_user AND week = p_week) THEN
        RETURN;
    END IF;
    FOREACH v_diff IN ARRAY ARRAY['easy', 'explore', 'queue'] LOOP
        v_slot := v_slot + 1;
        SELECT count(*) INTO v_n FROM public.quest_templates WHERE difficulty = v_diff AND active;
        CONTINUE WHEN v_n = 0;
        SELECT * INTO v_t FROM public.quest_templates
        WHERE difficulty = v_diff AND active
        ORDER BY key
        OFFSET public._seeded_index(p_user, p_week, v_diff, v_n) LIMIT 1;

        v_title := v_t.title;
        v_value := NULL;
        IF v_t.param = 'genre' THEN
            -- the genre you rank least, from a broad list; ties broken by the seed
            SELECT to_jsonb(g.name) INTO v_value
            FROM unnest(ARRAY['Horror', 'Documentary', 'Animation', 'Romance', 'Western', 'Science Fiction',
                              'Mystery', 'War', 'Music', 'History', 'Fantasy', 'Comedy']) AS g(name)
            ORDER BY (SELECT count(*) FROM public.qualifying_rankings q
                      JOIN public.titles t ON t.id = q.title_id AND t.media_type = q.media_type
                      WHERE q.user_id = p_user AND g.name = ANY (t.genres)),
                     public._seeded_index(p_user, p_week, g.name, 1000)
            LIMIT 1;
            v_title := replace(v_title, '$genre', v_value #>> '{}');
        ELSIF v_t.param = 'decade' THEN
            SELECT to_jsonb(d.y) INTO v_value
            FROM generate_series(1950, 2010, 10) AS d(y)
            ORDER BY (SELECT count(*) FROM public.qualifying_rankings q
                      JOIN public.titles t ON t.id = q.title_id AND t.media_type = q.media_type
                      WHERE q.user_id = p_user AND t.release_date IS NOT NULL
                        AND EXTRACT(YEAR FROM t.release_date)::INT / 10 * 10 = d.y),
                     public._seeded_index(p_user, p_week, d.y::TEXT, 1000)
            LIMIT 1;
            v_title := replace(v_title, '$decade', v_value #>> '{}');
        END IF;

        INSERT INTO public.user_quests (user_id, week, slot, quest_key, title, kind, rule, target, xp)
        VALUES (p_user, p_week, v_slot, v_t.key, left(v_title, 80), v_t.kind,
                CASE WHEN v_t.param IS NULL THEN v_t.rule
                     ELSE public._fill_template_rule(v_t.rule, jsonb_build_object(v_t.param, v_value)) END,
                v_t.target, v_t.xp)
        ON CONFLICT DO NOTHING;
    END LOOP;
END;
$$;

-- -----------------------------------------------------------------------------
-- 4. AWARDING XP
-- -----------------------------------------------------------------------------
-- Idempotent: every row has a stable (source, ref), so running again adds nothing.
CREATE OR REPLACE FUNCTION public._award_xp(p_user UUID)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_tz TEXT;
    v_before INT;
    v_r RECORD;
    v_q public.user_quests;
    v_week_count INT;
BEGIN
    SELECT u.timezone INTO v_tz FROM public.users u WHERE u.id = p_user AND NOT u.is_deleted;
    IF NOT FOUND THEN
        RETURN 0;
    END IF;
    SELECT count(*) INTO v_before FROM public.xp_ledger WHERE user_id = p_user;

    -- Rankings: +10 each, at most 10 a week, oldest first (§6).
    FOR v_r IN
        SELECT q.title_id, q.media_type, q.created_at, public._week_label(q.created_at, v_tz) AS wk
        FROM public.qualifying_rankings q
        WHERE q.user_id = p_user
          AND NOT EXISTS (SELECT 1 FROM public.xp_ledger l
                          WHERE l.user_id = p_user AND l.source = 'ranking'
                            AND l.ref = q.media_type::TEXT || ':' || q.title_id)
        ORDER BY q.created_at
    LOOP
        SELECT count(*) INTO v_week_count FROM public.xp_ledger
        WHERE user_id = p_user AND source = 'ranking' AND week = v_r.wk;
        CONTINUE WHEN v_week_count >= 10;
        INSERT INTO public.xp_ledger (user_id, amount, source, ref, week, created_at)
        VALUES (p_user, 10, 'ranking', v_r.media_type::TEXT || ':' || v_r.title_id, v_r.wk, v_r.created_at)
        ON CONFLICT DO NOTHING;
    END LOOP;

    -- Streak: +25 for every counted week.
    INSERT INTO public.xp_ledger (user_id, amount, source, ref, week)
    SELECT DISTINCT p_user, 25, 'streak'::public.xp_source_enum, w.wk, w.wk
    FROM (SELECT public._week_label(q.created_at, v_tz) AS wk
          FROM public.qualifying_rankings q WHERE q.user_id = p_user) w
    ON CONFLICT DO NOTHING;

    -- Medals: milestone, taste and streak +25; collections +100 (once per collection).
    INSERT INTO public.xp_ledger (user_id, amount, source, ref, week, created_at)
    SELECT p_user,
           CASE WHEN a.kind = 'collection' THEN 100 ELSE 25 END,
           CASE WHEN a.kind = 'collection' THEN 'collection'::public.xp_source_enum ELSE 'medal' END,
           CASE WHEN a.kind = 'collection' THEN a.collection_id::TEXT ELSE a.id END,
           public._week_label(ua.unlocked_at, v_tz), ua.unlocked_at
    FROM public.user_achievements ua
    JOIN public.achievements a ON a.id = ua.achievement_id
    WHERE ua.user_id = p_user AND a.kind IN ('milestone', 'taste', 'streak', 'collection')
      AND (a.kind <> 'collection' OR a.collection_id IS NOT NULL)
    ON CONFLICT DO NOTHING;

    -- Challenges: +150 seasonal, +100 squad.
    INSERT INTO public.xp_ledger (user_id, amount, source, ref, week, created_at)
    SELECT p_user, CASE WHEN c.squad_id IS NULL THEN 150 ELSE 100 END, 'challenge', c.id::TEXT,
           public._week_label(p.completed_at, v_tz), p.completed_at
    FROM public.challenge_participants p
    JOIN public.challenges c ON c.id = p.challenge_id
    WHERE p.user_id = p_user AND p.completed_at IS NOT NULL
    ON CONFLICT DO NOTHING;

    -- Quests: complete the ones whose target is met, +xp each.
    FOR v_q IN SELECT * FROM public.user_quests WHERE user_id = p_user AND completed_at IS NULL LOOP
        CONTINUE WHEN public._quest_progress(v_q, v_tz) < v_q.target;
        UPDATE public.user_quests SET completed_at = NOW()
        WHERE user_id = v_q.user_id AND week = v_q.week AND slot = v_q.slot;
        INSERT INTO public.xp_ledger (user_id, amount, source, ref, week)
        VALUES (p_user, v_q.xp, 'quest', v_q.week || ':' || v_q.quest_key, v_q.week)
        ON CONFLICT DO NOTHING;
    END LOOP;

    RETURN (SELECT count(*)::INT FROM public.xp_ledger WHERE user_id = p_user) - v_before;
END;
$$;

-- -----------------------------------------------------------------------------
-- 5. REWARDS (§5.2)
-- -----------------------------------------------------------------------------
CREATE TYPE public.reward_kind_enum AS ENUM ('frame', 'card_style', 'canon_decoration', 'app_icon', 'header_art');

CREATE TABLE public.rewards (
    id TEXT PRIMARY KEY CHECK (id ~ '^[a-z0-9_]{2,40}$'),
    name VARCHAR(64) NOT NULL,
    description VARCHAR(160) NOT NULL DEFAULT '',
    kind public.reward_kind_enum NOT NULL,
    level_required INT NOT NULL CHECK (level_required >= 1),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    sort INT NOT NULL DEFAULT 0
);

INSERT INTO public.rewards (id, name, description, kind, level_required, sort) VALUES
    ('lime_frame',       'Lime profile frame',       'A lime ring around your avatar',                'frame',            5,  1),
    ('noir_card',        '"Noir" card style',        'A black-and-white style for Wrapped and share cards', 'card_style', 10, 2),
    ('gold_podium',      'Gold podium tags',         'Gold rank tags on your Canon podium',           'canon_decoration', 15, 3),
    ('alt_app_icons',    'Alternate app icons',      'Choose a different Telly icon',                 'app_icon',         20, 4),
    ('canon_header_art', 'Custom canon header art',  'A still from your God tier behind your profile', 'header_art',      30, 5);

-- One equipped reward per kind (§5.2). Readable where the profile is, so friends see frames.
CREATE TABLE public.user_reward_choices (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    kind public.reward_kind_enum NOT NULL,
    reward_id TEXT NOT NULL REFERENCES public.rewards(id) ON DELETE CASCADE,
    equipped_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, kind)
);

ALTER TABLE public.rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_reward_choices ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.rewards, public.user_reward_choices FROM anon;
CREATE POLICY rewards_read ON public.rewards FOR SELECT TO authenticated USING (active);
CREATE POLICY user_reward_choices_select ON public.user_reward_choices FOR SELECT TO authenticated
    USING (public.can_view_user(user_id));
REVOKE INSERT, UPDATE, DELETE ON public.rewards, public.user_reward_choices FROM authenticated;

CREATE OR REPLACE FUNCTION public._total_xp(p_user UUID)
RETURNS INT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$ SELECT COALESCE(sum(amount), 0)::INT FROM public.xp_ledger WHERE user_id = p_user $$;

-- -----------------------------------------------------------------------------
-- 6. CLIENT RPCs
-- -----------------------------------------------------------------------------
-- SCR-27 level card: "2,340 / 3,000 XP to Level 13" is (total − floor) / (ceiling − floor).
CREATE OR REPLACE FUNCTION public.my_level()
RETURNS TABLE (level INT, name TEXT, total_xp INT, level_floor INT, level_ceiling INT, week_xp INT)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
    v_total INT := public._total_xp(v_user);
    v_level INT := public._level_for_xp(v_total);
    v_tz TEXT;
BEGIN
    SELECT u.timezone INTO v_tz FROM public.users u WHERE u.id = v_user;
    RETURN QUERY SELECT v_level, public._level_name(v_level), v_total, public._level_floor(v_level),
        public._level_floor(v_level + 1),
        (SELECT COALESCE(sum(l.amount), 0)::INT FROM public.xp_ledger l
         WHERE l.user_id = v_user AND l.week = public._week_label(NOW(), v_tz));
END;
$$;

-- SCR-27 "This week's quests": assigns them on first read, then reports progress.
CREATE OR REPLACE FUNCTION public.my_week()
RETURNS TABLE (slot SMALLINT, quest_key TEXT, title VARCHAR, difficulty TEXT, target INT, progress INT, xp INT,
               completed_at TIMESTAMPTZ, week TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
    v_tz TEXT;
    v_week TEXT;
BEGIN
    SELECT u.timezone INTO v_tz FROM public.users u WHERE u.id = v_user;
    v_week := public._week_label(NOW(), v_tz);
    PERFORM public._assign_quests(v_user, v_week);
    PERFORM public._award_xp(v_user); -- completes quests already met
    RETURN QUERY
    SELECT q.slot, q.quest_key, q.title, t.difficulty, q.target, public._quest_progress(q, v_tz), q.xp,
           q.completed_at, q.week
    FROM public.user_quests q
    JOIN public.quest_templates t ON t.key = q.quest_key
    WHERE q.user_id = v_user AND q.week = v_week
    ORDER BY q.slot;
END;
$$;

-- Rewards with whether each is unlocked (derived from level) and equipped.
CREATE OR REPLACE FUNCTION public.my_rewards()
RETURNS TABLE (id TEXT, name VARCHAR, description VARCHAR, kind public.reward_kind_enum, level_required INT,
               unlocked BOOLEAN, equipped BOOLEAN, xp_to_go INT)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
    v_total INT := public._total_xp(v_user);
    v_level INT := public._level_for_xp(v_total);
BEGIN
    RETURN QUERY
    SELECT r.id, r.name, r.description, r.kind, r.level_required, v_level >= r.level_required,
           EXISTS (SELECT 1 FROM public.user_reward_choices c WHERE c.user_id = v_user AND c.reward_id = r.id),
           GREATEST(public._level_floor(r.level_required) - v_total, 0)
    FROM public.rewards r
    WHERE r.active
    ORDER BY r.level_required, r.sort;
END;
$$;

CREATE OR REPLACE FUNCTION public.equip_reward(p_reward_id TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
    v_r public.rewards;
BEGIN
    SELECT * INTO v_r FROM public.rewards WHERE id = p_reward_id AND active;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'unknown reward %', p_reward_id USING ERRCODE = '22023';
    END IF;
    IF public._level_for_xp(public._total_xp(v_user)) < v_r.level_required THEN
        RAISE EXCEPTION 'reward % unlocks at level %', p_reward_id, v_r.level_required USING ERRCODE = '22023';
    END IF;
    INSERT INTO public.user_reward_choices (user_id, kind, reward_id) VALUES (v_user, v_r.kind, v_r.id)
    ON CONFLICT (user_id, kind) DO UPDATE SET reward_id = EXCLUDED.reward_id, equipped_at = NOW();
END;
$$;

CREATE OR REPLACE FUNCTION public.unequip_reward(p_kind public.reward_kind_enum)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
BEGIN
    DELETE FROM public.user_reward_choices WHERE user_id = v_user AND kind = p_kind;
END;
$$;

-- SCR-27 "Friends this week": me and the visible people I follow, or a squad I'm in, by this
-- week's XP (each person's own week). A weekly table only; never all-time (decision 0005).
CREATE OR REPLACE FUNCTION public.weekly_xp_table(p_squad_id UUID DEFAULT NULL)
RETURNS TABLE (user_id UUID, username VARCHAR, display_name VARCHAR, avatar_url TEXT, level INT,
               streak_weeks INT, week_xp INT, rank INT, is_me BOOLEAN)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
BEGIN
    IF p_squad_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.squad_members m
                                               WHERE m.squad_id = p_squad_id AND m.user_id = v_user) THEN
        RAISE EXCEPTION 'not a member of this squad' USING ERRCODE = '42501';
    END IF;
    RETURN QUERY
    WITH people AS (
        SELECT v_user AS id
        UNION
        SELECT f.following_id FROM public.social_follows f
        WHERE p_squad_id IS NULL AND f.follower_id = v_user AND f.status = 'accepted'
          AND public.can_view_user(f.following_id)
        UNION
        SELECT m.user_id FROM public.squad_members m WHERE m.squad_id = p_squad_id
    ), scored AS (
        SELECT u.id, u.username, u.display_name, u.avatar_url,
               public._level_for_xp(public._total_xp(u.id)) AS lvl,
               (SELECT s.current_weeks FROM public.weekly_streak(u.id) s) AS streak,
               (SELECT COALESCE(sum(l.amount), 0)::INT FROM public.xp_ledger l
                WHERE l.user_id = u.id AND l.week = public._week_label(NOW(), u.timezone)) AS wxp
        FROM people p JOIN public.users u ON u.id = p.id AND NOT u.is_deleted
    )
    SELECT s.id, s.username, s.display_name, s.avatar_url, s.lvl, s.streak, s.wxp,
           (rank() OVER (ORDER BY s.wxp DESC))::INT, s.id = v_user
    FROM scored s
    ORDER BY s.wxp DESC, s.display_name;
END;
$$;

-- -----------------------------------------------------------------------------
-- 7. EVALUATION, GRANTS, BACKFILL
-- -----------------------------------------------------------------------------
-- Unchanged from 20261010002300 except that it also awards XP.
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
    v_challenges INT;
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
    -- #142: joined challenges whose target is now met.
    v_challenges := public._evaluate_challenges(p_user, p_broadcast);
    -- #145: XP for everything above, idempotently.
    PERFORM public._award_xp(p_user);
    RETURN cardinality(v_ids) + v_challenges;
END;
$$;

REVOKE ALL ON FUNCTION public._week_label(TIMESTAMPTZ, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._level_for_xp(INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._level_floor(INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._level_name(INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._xp_ledger_append_only() FROM PUBLIC;
REVOKE ALL ON FUNCTION public._week_bounds(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._seeded_index(UUID, TEXT, TEXT, INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._quest_progress(public.user_quests, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._assign_quests(UUID, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._award_xp(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._total_xp(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.my_level() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.my_week() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.my_rewards() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.equip_reward(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.unequip_reward(public.reward_kind_enum) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.weekly_xp_table(UUID) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public._award_xp(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.my_level() TO authenticated;
GRANT EXECUTE ON FUNCTION public.my_week() TO authenticated;
GRANT EXECUTE ON FUNCTION public.my_rewards() TO authenticated;
GRANT EXECUTE ON FUNCTION public.equip_reward(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unequip_reward(public.reward_kind_enum) TO authenticated;
GRANT EXECUTE ON FUNCTION public.weekly_xp_table(UUID) TO authenticated;
-- Corrections (source 'correction') are written by the service role directly.
GRANT INSERT ON public.xp_ledger TO service_role;
GRANT USAGE ON SEQUENCE public.xp_ledger_id_seq TO service_role;

-- Existing users get the XP they've already earned.
SELECT public._award_xp(id) FROM public.users WHERE NOT is_deleted;
