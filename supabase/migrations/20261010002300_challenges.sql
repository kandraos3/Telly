-- Migration 20261010002300_challenges.sql
-- #142 (epic #50): challenges, rules, progress, participants and squad challenges (Spec 10 §8).
--
-- * challenges / challenge_participants, with the §8.2 rule JSON validated by a CHECK and
--   evaluated in SQL for every filter type (genre, decade, collection, titles, network,
--   company, tv_type). Progress counts the user's qualifying rankings of matching titles
--   created inside [starts_at, ends_at).
-- * Each challenge keeps a gold medal `challenge_<slug>` (trigger). Completing a challenge
--   (from evaluate_achievements, so every ranking path and the nightly job cover it) sets
--   completed_at, unlocks the medal and posts CHALLENGE_COMPLETED when the user shares
--   achievements.
-- * challenge_templates hold the parameterised rules squads create from; #143 publishes the
--   repo's template files into it. A few are seeded so squads can start now.
-- * RPCs: discover_challenges, my_challenges, get_challenge, join_challenge,
--   leave_challenge, challenge_progress, challenge_picks, create_squad_challenge and the
--   service-role admin_upsert_challenge / admin_upsert_challenge_template.
--
-- Backward compatible: get_activity_feed gains p_include_challenges DEFAULT FALSE, so apps
-- without the challenge card never receive CHALLENGE_COMPLETED rows.

-- -----------------------------------------------------------------------------
-- 1. RULES
-- -----------------------------------------------------------------------------
-- A rule: {"media_type": "movie"|"tv"|"any", "filters": [{"type": <filter>, "any": [...]}, ...]}.
CREATE OR REPLACE FUNCTION public._valid_challenge_rule(p_rule JSONB)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT jsonb_typeof(p_rule) = 'object'
       AND p_rule ->> 'media_type' IN ('movie', 'tv', 'any')
       AND jsonb_typeof(COALESCE(p_rule -> 'filters', '[]'::jsonb)) = 'array'
       AND NOT EXISTS (
           SELECT 1 FROM jsonb_array_elements(COALESCE(p_rule -> 'filters', '[]'::jsonb)) f
           WHERE jsonb_typeof(f) <> 'object'
              OR f ->> 'type' IS NULL
              OR f ->> 'type' NOT IN ('genre', 'decade', 'collection', 'titles', 'network', 'company', 'tv_type')
              OR jsonb_typeof(f -> 'any') <> 'array'
              OR jsonb_array_length(f -> 'any') = 0
       );
$$;

CREATE OR REPLACE FUNCTION public._title_matches_filter(p_filter JSONB, p_title public.titles)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT CASE p_filter ->> 'type'
        WHEN 'genre' THEN p_title.genres && ARRAY(SELECT jsonb_array_elements_text(p_filter -> 'any'))
        WHEN 'decade' THEN p_title.release_date IS NOT NULL
            AND (EXTRACT(YEAR FROM p_title.release_date)::INT / 10 * 10)
                = ANY (ARRAY(SELECT jsonb_array_elements_text(p_filter -> 'any')::INT))
        WHEN 'collection' THEN p_title.collection_id
            = ANY (ARRAY(SELECT jsonb_array_elements_text(p_filter -> 'any')::INT))
        WHEN 'titles' THEN (p_filter -> 'any')
            @> jsonb_build_array(jsonb_build_object('id', p_title.id, 'media_type', p_title.media_type))
        WHEN 'network' THEN p_title.original_network = ANY (ARRAY(SELECT jsonb_array_elements_text(p_filter -> 'any')))
        WHEN 'company' THEN p_title.production_companies && ARRAY(SELECT jsonb_array_elements_text(p_filter -> 'any'))
        WHEN 'tv_type' THEN p_title.tv_type = ANY (ARRAY(SELECT jsonb_array_elements_text(p_filter -> 'any')))
        ELSE FALSE
    END;
$$;

CREATE OR REPLACE FUNCTION public._title_matches_rule(p_rule JSONB, p_title public.titles)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT (p_rule ->> 'media_type' = 'any' OR p_rule ->> 'media_type' = p_title.media_type::TEXT)
       AND COALESCE((SELECT bool_and(COALESCE(public._title_matches_filter(f, p_title), FALSE))
                     FROM jsonb_array_elements(COALESCE(p_rule -> 'filters', '[]'::jsonb)) f), TRUE);
$$;

-- -----------------------------------------------------------------------------
-- 2. TABLES
-- -----------------------------------------------------------------------------
CREATE TYPE public.challenge_status_enum AS ENUM ('draft', 'live');

CREATE TABLE public.challenges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND length(slug) BETWEEN 3 AND 50),
    name VARCHAR(64) NOT NULL,
    description VARCHAR(200) NOT NULL DEFAULT '',
    art TEXT NOT NULL DEFAULT 'gold',
    medal_glyph VARCHAR(4) NOT NULL DEFAULT '★',
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ CHECK (ends_at IS NULL OR ends_at > starts_at),
    rule JSONB NOT NULL CHECK (public._valid_challenge_rule(rule)),
    target INT NOT NULL CHECK (target BETWEEN 1 AND 1000),
    squad_id UUID REFERENCES public.squads(id) ON DELETE CASCADE,
    featured BOOLEAN NOT NULL DEFAULT FALSE,
    template_key TEXT,
    status public.challenge_status_enum NOT NULL DEFAULT 'draft',
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_challenges_squad_not_featured CHECK (squad_id IS NULL OR NOT featured)
);
-- At most one featured challenge at a time.
CREATE UNIQUE INDEX uq_challenges_featured ON public.challenges (featured) WHERE featured;
CREATE INDEX idx_challenges_live ON public.challenges (starts_at, ends_at) WHERE status = 'live';
CREATE INDEX idx_challenges_squad ON public.challenges (squad_id) WHERE squad_id IS NOT NULL;

CREATE TABLE public.challenge_participants (
    challenge_id UUID NOT NULL REFERENCES public.challenges(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    PRIMARY KEY (challenge_id, user_id)
);
CREATE INDEX idx_challenge_participants_user ON public.challenge_participants (user_id);

-- Parameterised rules for squad challenges (§8.3–§8.4). "$param" strings in the rule are
-- replaced by the creator's values.
CREATE TABLE public.challenge_templates (
    key TEXT PRIMARY KEY CHECK (key ~ '^[a-z0-9_]{2,40}$'),
    name VARCHAR(64) NOT NULL,
    description VARCHAR(200) NOT NULL DEFAULT '',
    art TEXT NOT NULL DEFAULT 'gold',
    medal_glyph VARCHAR(4) NOT NULL DEFAULT '★',
    rule JSONB NOT NULL,
    params TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    target INT NOT NULL CHECK (target BETWEEN 1 AND 1000),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    sort INT NOT NULL DEFAULT 0
);

INSERT INTO public.challenge_templates (key, name, description, art, medal_glyph, rule, params, target, sort) VALUES
    ('genre_month', 'Genre month', 'Rank $target $genre films', 'gold', 'G',
     '{"media_type": "movie", "filters": [{"type": "genre", "any": ["$genre"]}]}', ARRAY['genre'], 8, 1),
    ('decade', 'Decade dive', 'Rank $target films from the $decade', 'noir', 'D',
     '{"media_type": "movie", "filters": [{"type": "decade", "any": ["$decade"]}]}', ARRAY['decade'], 6, 2),
    ('collection', 'Finish the saga', 'Rank every film in a collection', 'gold', 'S',
     '{"media_type": "movie", "filters": [{"type": "collection", "any": ["$collection"]}]}', ARRAY['collection'], 3, 3),
    ('network', 'Network binge', 'Rank $target $network series', 'cyan', 'N',
     '{"media_type": "tv", "filters": [{"type": "network", "any": ["$network"]}]}', ARRAY['network'], 5, 4),
    ('limited_series', 'Limited series run', 'Rank $target limited series', 'violet', 'LS',
     '{"media_type": "tv", "filters": [{"type": "tv_type", "any": ["Miniseries"]}]}', ARRAY[]::TEXT[], 5, 5);

ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_templates ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.challenges, public.challenge_participants, public.challenge_templates FROM anon;

-- Live challenges are public; squad challenges only to their members. Drafts are hidden.
CREATE OR REPLACE FUNCTION public._can_see_challenge(p_status public.challenge_status_enum, p_squad UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT p_status = 'live' AND (p_squad IS NULL OR public.is_squad_member(p_squad));
$$;

CREATE POLICY challenges_select ON public.challenges FOR SELECT TO authenticated
    USING (public._can_see_challenge(status, squad_id));
CREATE POLICY challenge_participants_select ON public.challenge_participants FOR SELECT TO authenticated
    USING (
        public.can_view_user(user_id)
        AND EXISTS (SELECT 1 FROM public.challenges c
                    WHERE c.id = challenge_id AND public._can_see_challenge(c.status, c.squad_id))
    );
CREATE POLICY challenge_templates_read ON public.challenge_templates FOR SELECT TO authenticated USING (active);
REVOKE INSERT, UPDATE, DELETE ON public.challenges, public.challenge_participants, public.challenge_templates
    FROM authenticated;

-- -----------------------------------------------------------------------------
-- 3. MEDALS AND PROGRESS
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._challenge_medal_id(p_slug TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$ SELECT 'challenge_' || replace(p_slug, '-', '_') $$;

-- One gold medal per challenge, in step with it (§4.1).
CREATE OR REPLACE FUNCTION public._sync_challenge_medal()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.achievements (id, kind, tier, name, description, glyph, threshold, challenge_id, sort, active)
    VALUES (public._challenge_medal_id(NEW.slug), 'challenge', 'gold', NEW.name,
            left(COALESCE(NULLIF(NEW.description, ''), 'Finish the ' || NEW.name || ' challenge'), 160),
            NEW.medal_glyph, NEW.target, NEW.id, 0, NEW.status = 'live')
    ON CONFLICT (id) DO UPDATE
        SET name = EXCLUDED.name, description = EXCLUDED.description, glyph = EXCLUDED.glyph,
            threshold = EXCLUDED.threshold, challenge_id = EXCLUDED.challenge_id, active = EXCLUDED.active;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_challenges_medal
    AFTER INSERT OR UPDATE ON public.challenges
    FOR EACH ROW EXECUTE FUNCTION public._sync_challenge_medal();

-- The user's qualifying rankings that count for [p_challenge].
CREATE OR REPLACE FUNCTION public._challenge_matches(p_challenge public.challenges, p_user UUID)
RETURNS TABLE (title_id INT, media_type public.media_type_enum, created_at TIMESTAMPTZ)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT q.title_id, q.media_type, q.created_at
    FROM public.qualifying_rankings q
    JOIN public.titles t ON t.id = q.title_id AND t.media_type = q.media_type
    WHERE q.user_id = p_user
      AND q.created_at >= p_challenge.starts_at
      AND (p_challenge.ends_at IS NULL OR q.created_at < p_challenge.ends_at)
      AND public._title_matches_rule(p_challenge.rule, t);
$$;

CREATE OR REPLACE FUNCTION public._challenge_progress(p_challenge public.challenges, p_user UUID)
RETURNS INT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$ SELECT LEAST(count(*)::INT, p_challenge.target) FROM public._challenge_matches(p_challenge, p_user) $$;

-- Completes every joined challenge whose target is met: completed_at, the medal, and a
-- CHALLENGE_COMPLETED post when sharing. Returns how many completed.
CREATE OR REPLACE FUNCTION public._evaluate_challenges(p_user UUID, p_broadcast BOOLEAN DEFAULT TRUE)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_share BOOLEAN;
    v_c public.challenges;
    v_best RECORD;
    v_done INT := 0;
BEGIN
    SELECT u.share_achievements INTO v_share FROM public.users u WHERE u.id = p_user AND NOT u.is_deleted;
    IF NOT FOUND THEN
        RETURN 0;
    END IF;

    FOR v_c IN
        SELECT c.* FROM public.challenges c
        JOIN public.challenge_participants p ON p.challenge_id = c.id
        WHERE p.user_id = p_user AND p.completed_at IS NULL AND c.status = 'live'
    LOOP
        CONTINUE WHEN public._challenge_progress(v_c, p_user) < v_c.target;

        UPDATE public.challenge_participants SET completed_at = NOW()
        WHERE challenge_id = v_c.id AND user_id = p_user AND completed_at IS NULL;
        INSERT INTO public.user_achievements (user_id, achievement_id)
        VALUES (p_user, public._challenge_medal_id(v_c.slug))
        ON CONFLICT DO NOTHING;
        v_done := v_done + 1;

        IF p_broadcast AND v_share THEN
            -- "Best of the 8": the highest-ranked title among the ones that counted.
            SELECT r.title_id, r.media_type, r.rank_position, r.calculated_score, t.title
            INTO v_best
            FROM public._challenge_matches(v_c, p_user) m
            JOIN public.user_rankings r ON r.user_id = p_user AND r.title_id = m.title_id AND r.media_type = m.media_type
            JOIN public.titles t ON t.id = r.title_id AND t.media_type = r.media_type
            ORDER BY r.calculated_score DESC, r.rank_position
            LIMIT 1;

            INSERT INTO public.activity_logs (user_id, activity_type, title_id, media_type, metadata)
            VALUES (p_user, 'CHALLENGE_COMPLETED', v_best.title_id, v_best.media_type, jsonb_build_object(
                'challenge_id', v_c.id, 'slug', v_c.slug, 'name', v_c.name, 'count', v_c.target,
                'medal_glyph', v_c.medal_glyph, 'best_title', v_best.title, 'best_rank', v_best.rank_position,
                'best_score', v_best.calculated_score));
        END IF;
    END LOOP;
    RETURN v_done;
END;
$$;

-- -----------------------------------------------------------------------------
-- 4. READ RPCs
-- -----------------------------------------------------------------------------
-- Every challenge the caller can see, as SCR-25 / SCR-26 cards. Ended ones are included only
-- when the caller joined them.
CREATE TYPE public.challenge_card AS (
    id UUID, slug TEXT, name VARCHAR, description VARCHAR, art TEXT, medal_glyph VARCHAR,
    starts_at TIMESTAMPTZ, ends_at TIMESTAMPTZ, target INT, rule JSONB, featured BOOLEAN,
    squad_id UUID, squad_name VARCHAR, participant_count INT, friend_count INT,
    joined BOOLEAN, my_progress INT, completed_at TIMESTAMPTZ
);

CREATE OR REPLACE FUNCTION public._challenge_cards(p_user UUID)
RETURNS SETOF public.challenge_card
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT c.id, c.slug, c.name, c.description, c.art, c.medal_glyph, c.starts_at, c.ends_at, c.target, c.rule,
           c.featured, c.squad_id, s.name,
           (SELECT count(*)::INT FROM public.challenge_participants p
            JOIN public.users u ON u.id = p.user_id AND NOT u.is_deleted
            WHERE p.challenge_id = c.id),
           (SELECT count(*)::INT FROM public.challenge_participants p
            JOIN public.social_follows f ON f.following_id = p.user_id AND f.follower_id = p_user AND f.status = 'accepted'
            WHERE p.challenge_id = c.id),
           me.user_id IS NOT NULL,
           public._challenge_progress(c, p_user),
           me.completed_at
    FROM public.challenges c
    LEFT JOIN public.squads s ON s.id = c.squad_id
    LEFT JOIN public.challenge_participants me ON me.challenge_id = c.id AND me.user_id = p_user
    WHERE c.status = 'live'
      AND c.starts_at <= NOW()
      AND (c.squad_id IS NULL OR EXISTS (SELECT 1 FROM public.squad_members m
                                         WHERE m.squad_id = c.squad_id AND m.user_id = p_user))
      AND (c.ends_at IS NULL OR c.ends_at > NOW() OR me.user_id IS NOT NULL);
$$;

-- SCR-25 "Featured" and "Join next": live challenges I haven't joined; featured first.
CREATE OR REPLACE FUNCTION public.discover_challenges()
RETURNS SETOF public.challenge_card
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
BEGIN
    RETURN QUERY
    SELECT * FROM public._challenge_cards(v_user) c
    WHERE NOT c.joined
    ORDER BY c.featured DESC, c.ends_at NULLS LAST, c.starts_at DESC;
END;
$$;

-- SCR-25 "Yours" and "Ended": everything I joined (live first, then ended, newest first).
CREATE OR REPLACE FUNCTION public.my_challenges()
RETURNS SETOF public.challenge_card
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
BEGIN
    RETURN QUERY
    SELECT * FROM public._challenge_cards(v_user) c
    WHERE c.joined
    ORDER BY (c.ends_at IS NOT NULL AND c.ends_at <= NOW()), c.ends_at NULLS LAST, c.starts_at DESC;
END;
$$;

-- SCR-26: one challenge by slug (empty when hidden, a draft, or ended and not joined).
CREATE OR REPLACE FUNCTION public.get_challenge(p_slug TEXT)
RETURNS SETOF public.challenge_card
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
BEGIN
    RETURN QUERY SELECT * FROM public._challenge_cards(v_user) c WHERE c.slug = p_slug;
END;
$$;

-- SCR-26 "Friends in this challenge": me and the people I follow who joined, by progress.
CREATE OR REPLACE FUNCTION public.challenge_progress(p_challenge_id UUID)
RETURNS TABLE (
    user_id UUID, username VARCHAR, display_name VARCHAR, avatar_url TEXT,
    progress INT, completed_at TIMESTAMPTZ, is_me BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
    v_c public.challenges;
BEGIN
    SELECT * INTO v_c FROM public.challenges c
    WHERE c.id = p_challenge_id AND c.status = 'live'
      AND (c.squad_id IS NULL OR EXISTS (SELECT 1 FROM public.squad_members m
                                         WHERE m.squad_id = c.squad_id AND m.user_id = v_user));
    IF NOT FOUND THEN
        RETURN;
    END IF;
    RETURN QUERY
    SELECT u.id, u.username, u.display_name, u.avatar_url, public._challenge_progress(v_c, u.id),
           p.completed_at, u.id = v_user
    FROM public.challenge_participants p
    JOIN public.users u ON u.id = p.user_id AND NOT u.is_deleted
    WHERE p.challenge_id = v_c.id
      AND (u.id = v_user OR (public.can_view_user(u.id) AND EXISTS (
              SELECT 1 FROM public.social_follows f
              WHERE f.follower_id = v_user AND f.following_id = u.id AND f.status = 'accepted')))
    ORDER BY 5 DESC, p.completed_at NULLS LAST, u.display_name;
END;
$$;

-- SCR-26 "Picks": matching titles from my Queue first, then titles the people I follow rank
-- highest; never anything I've ranked.
CREATE OR REPLACE FUNCTION public.challenge_picks(p_challenge_id UUID, p_limit INT DEFAULT 12)
RETURNS TABLE (
    title_id INT, media_type public.media_type_enum, title VARCHAR, poster_path TEXT, release_year INT,
    source TEXT, friends_score NUMERIC, friend_count INT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
    v_c public.challenges;
BEGIN
    SELECT * INTO v_c FROM public.challenges c
    WHERE c.id = p_challenge_id AND c.status = 'live'
      AND (c.squad_id IS NULL OR EXISTS (SELECT 1 FROM public.squad_members m
                                         WHERE m.squad_id = c.squad_id AND m.user_id = v_user));
    IF NOT FOUND THEN
        RETURN;
    END IF;
    RETURN QUERY
    WITH followed AS (
        SELECT f.following_id AS id FROM public.social_follows f
        JOIN public.users u ON u.id = f.following_id AND NOT u.is_deleted
        WHERE f.follower_id = v_user AND f.status = 'accepted' AND public.can_view_user(f.following_id)
    ), friend_scores AS (
        SELECT r.title_id, r.media_type, ROUND(AVG(r.calculated_score), 2) AS score, count(*)::INT AS n
        FROM public.user_rankings r JOIN followed fo ON fo.id = r.user_id
        GROUP BY r.title_id, r.media_type
    ), candidates AS (
        SELECT t.id, t.media_type, t.title, t.poster_path, EXTRACT(YEAR FROM t.release_date)::INT AS yr,
               CASE WHEN w.user_id IS NOT NULL THEN 'queue' ELSE 'friends' END AS src,
               fs.score, COALESCE(fs.n, 0) AS n
        FROM public.titles t
        LEFT JOIN public.user_watchlist w ON w.user_id = v_user AND w.title_id = t.id AND w.media_type = t.media_type
        LEFT JOIN friend_scores fs ON fs.title_id = t.id AND fs.media_type = t.media_type
        WHERE (w.user_id IS NOT NULL OR fs.title_id IS NOT NULL)
          AND public._title_matches_rule(v_c.rule, t)
          AND NOT EXISTS (SELECT 1 FROM public.user_rankings r
                          WHERE r.user_id = v_user AND r.title_id = t.id AND r.media_type = t.media_type)
    )
    SELECT c.id, c.media_type, c.title, c.poster_path, c.yr, c.src, c.score, c.n
    FROM candidates c
    ORDER BY (c.src = 'queue') DESC, c.score DESC NULLS LAST, c.n DESC, c.title
    LIMIT LEAST(GREATEST(p_limit, 1), 50);
END;
$$;

-- -----------------------------------------------------------------------------
-- 5. WRITE RPCs
-- -----------------------------------------------------------------------------
-- Joins a live, unfinished challenge I can see; rankings made earlier inside its window
-- count, so it may complete at once. Returns my progress.
CREATE OR REPLACE FUNCTION public.join_challenge(p_challenge_id UUID)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
    v_c public.challenges;
BEGIN
    SELECT * INTO v_c FROM public.challenges c
    WHERE c.id = p_challenge_id AND c.status = 'live' AND c.starts_at <= NOW()
      AND (c.ends_at IS NULL OR c.ends_at > NOW())
      AND (c.squad_id IS NULL OR EXISTS (SELECT 1 FROM public.squad_members m
                                         WHERE m.squad_id = c.squad_id AND m.user_id = v_user));
    IF NOT FOUND THEN
        RAISE EXCEPTION 'challenge not open' USING ERRCODE = '22023';
    END IF;
    INSERT INTO public.challenge_participants (challenge_id, user_id) VALUES (v_c.id, v_user)
    ON CONFLICT DO NOTHING;
    PERFORM public._evaluate_challenges(v_user);
    RETURN public._challenge_progress(v_c, v_user);
END;
$$;

-- Leaves a challenge; a finished one stays (its medal is kept either way).
CREATE OR REPLACE FUNCTION public.leave_challenge(p_challenge_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
BEGIN
    DELETE FROM public.challenge_participants
    WHERE challenge_id = p_challenge_id AND user_id = v_user AND completed_at IS NULL;
END;
$$;

-- "$genre" and friends in a template's rule become the creator's values.
CREATE OR REPLACE FUNCTION public._fill_template_rule(p_rule JSONB, p_params JSONB)
RETURNS JSONB
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_text TEXT := p_rule::TEXT;
    v_key TEXT;
    v_value JSONB;
BEGIN
    FOR v_key, v_value IN SELECT * FROM jsonb_each(COALESCE(p_params, '{}'::jsonb)) LOOP
        v_text := replace(v_text, to_jsonb('$' || v_key)::TEXT, v_value::TEXT);
    END LOOP;
    RETURN v_text::JSONB;
END;
$$;

-- §8.3: a squad's owner or admins create a challenge from a template, with their own name,
-- dates and target. It goes live at once, visible to members only, and every member joins.
CREATE OR REPLACE FUNCTION public.create_squad_challenge(
    p_squad_id UUID,
    p_template_key TEXT,
    p_name TEXT,
    p_starts_at TIMESTAMPTZ,
    p_ends_at TIMESTAMPTZ,
    p_params JSONB DEFAULT '{}'::jsonb,
    p_target INT DEFAULT NULL
)
RETURNS public.challenges
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
    v_t public.challenge_templates;
    v_rule JSONB;
    v_target INT;
    v_slug TEXT;
    v_desc TEXT;
    v_key TEXT;
    v_value JSONB;
    v_row public.challenges;
BEGIN
    IF NOT public.is_squad_member(p_squad_id, ARRAY['OWNER', 'ADMIN']) THEN
        RAISE EXCEPTION 'only squad owners and admins create challenges' USING ERRCODE = '42501';
    END IF;
    SELECT * INTO v_t FROM public.challenge_templates WHERE key = p_template_key AND active;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'unknown template %', p_template_key USING ERRCODE = '22023';
    END IF;
    IF length(trim(COALESCE(p_name, ''))) = 0 OR length(trim(p_name)) > 64 THEN
        RAISE EXCEPTION 'name must be 1 to 64 characters' USING ERRCODE = '22023';
    END IF;
    v_rule := public._fill_template_rule(v_t.rule, p_params);
    IF v_rule::TEXT LIKE '%"$%' OR NOT public._valid_challenge_rule(v_rule) THEN
        RAISE EXCEPTION 'template % needs params %', p_template_key, v_t.params USING ERRCODE = '22023';
    END IF;
    v_target := COALESCE(p_target, v_t.target);
    v_desc := replace(v_t.description, '$target', v_target::TEXT);
    FOR v_key, v_value IN SELECT * FROM jsonb_each(COALESCE(p_params, '{}'::jsonb)) LOOP
        v_desc := replace(v_desc, '$' || v_key, v_value #>> '{}');
    END LOOP;

    -- squad-<6 hex>-<name words>, within the 50-character slug limit.
    v_slug := left('squad-' || substr(md5(gen_random_uuid()::TEXT), 1, 6) || '-'
                   || trim(BOTH '-' FROM regexp_replace(lower(p_name), '[^a-z0-9]+', '-', 'g')), 50);
    v_slug := trim(BOTH '-' FROM v_slug);

    INSERT INTO public.challenges (slug, name, description, art, medal_glyph, starts_at, ends_at, rule, target,
                                   squad_id, template_key, status, created_by)
    VALUES (v_slug, trim(p_name), left(v_desc, 200),
            v_t.art, v_t.medal_glyph, COALESCE(p_starts_at, NOW()), p_ends_at, v_rule, v_target,
            p_squad_id, v_t.key, 'live', v_user)
    RETURNING * INTO v_row;

    INSERT INTO public.challenge_participants (challenge_id, user_id)
    SELECT v_row.id, m.user_id FROM public.squad_members m WHERE m.squad_id = p_squad_id
    ON CONFLICT DO NOTHING;
    RETURN v_row;
END;
$$;

-- New squad members join the squad's live challenges automatically (§8.3).
CREATE OR REPLACE FUNCTION public._join_squad_challenges()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.challenge_participants (challenge_id, user_id)
    SELECT c.id, NEW.user_id FROM public.challenges c
    WHERE c.squad_id = NEW.squad_id AND c.status = 'live' AND (c.ends_at IS NULL OR c.ends_at > NOW())
    ON CONFLICT DO NOTHING;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_squad_members_challenges
    AFTER INSERT ON public.squad_members
    FOR EACH ROW EXECUTE FUNCTION public._join_squad_challenges();

-- §8.4: the publishing tool's entry point (service role). Upserts by slug; featuring one
-- challenge un-features the rest.
CREATE OR REPLACE FUNCTION public.admin_upsert_challenge(p_challenge JSONB)
RETURNS public.challenges
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_row public.challenges;
    v_featured BOOLEAN := COALESCE((p_challenge ->> 'featured')::BOOLEAN, FALSE);
BEGIN
    IF v_featured THEN
        UPDATE public.challenges SET featured = FALSE
        WHERE featured AND slug <> (p_challenge ->> 'slug');
    END IF;
    INSERT INTO public.challenges (slug, name, description, art, medal_glyph, starts_at, ends_at, rule, target,
                                   featured, template_key, status)
    VALUES (
        p_challenge ->> 'slug',
        p_challenge ->> 'name',
        COALESCE(p_challenge ->> 'description', ''),
        COALESCE(p_challenge ->> 'art', 'gold'),
        COALESCE(p_challenge ->> 'medal_glyph', '★'),
        (p_challenge ->> 'starts_at')::TIMESTAMPTZ,
        (p_challenge ->> 'ends_at')::TIMESTAMPTZ,
        p_challenge -> 'rule',
        (p_challenge ->> 'target')::INT,
        v_featured,
        p_challenge ->> 'template_key',
        COALESCE((p_challenge ->> 'status')::public.challenge_status_enum, 'live')
    )
    ON CONFLICT (slug) DO UPDATE SET
        name = EXCLUDED.name, description = EXCLUDED.description, art = EXCLUDED.art,
        medal_glyph = EXCLUDED.medal_glyph, starts_at = EXCLUDED.starts_at, ends_at = EXCLUDED.ends_at,
        rule = EXCLUDED.rule, target = EXCLUDED.target, featured = EXCLUDED.featured,
        template_key = EXCLUDED.template_key, status = EXCLUDED.status, updated_at = NOW()
    RETURNING * INTO v_row;
    RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_upsert_challenge_template(p_template JSONB)
RETURNS public.challenge_templates
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_row public.challenge_templates;
BEGIN
    INSERT INTO public.challenge_templates (key, name, description, art, medal_glyph, rule, params, target, active, sort)
    VALUES (
        p_template ->> 'key', p_template ->> 'name', COALESCE(p_template ->> 'description', ''),
        COALESCE(p_template ->> 'art', 'gold'), COALESCE(p_template ->> 'medal_glyph', '★'), p_template -> 'rule',
        ARRAY(SELECT jsonb_array_elements_text(COALESCE(p_template -> 'params', '[]'::jsonb))),
        (p_template ->> 'target')::INT, COALESCE((p_template ->> 'active')::BOOLEAN, TRUE),
        COALESCE((p_template ->> 'sort')::INT, 0)
    )
    ON CONFLICT (key) DO UPDATE SET
        name = EXCLUDED.name, description = EXCLUDED.description, art = EXCLUDED.art,
        medal_glyph = EXCLUDED.medal_glyph, rule = EXCLUDED.rule, params = EXCLUDED.params,
        target = EXCLUDED.target, active = EXCLUDED.active, sort = EXCLUDED.sort
    RETURNING * INTO v_row;
    RETURN v_row;
END;
$$;

-- -----------------------------------------------------------------------------
-- 6. ACTIVITY, EVALUATION AND THE FEED
-- -----------------------------------------------------------------------------
ALTER TABLE public.activity_logs DROP CONSTRAINT activity_logs_activity_type_check;
ALTER TABLE public.activity_logs ADD CONSTRAINT activity_logs_activity_type_check CHECK (activity_type IN (
    'RANKING_CREATED', 'UPSET_ALERT', 'SHOW_DROPPED', 'QUEUE_ADDED', 'COMMENT_POSTED', 'MEDAL_UNLOCKED',
    'CHALLENGE_COMPLETED'
));

-- Unchanged from 20261010002000 except that it also completes challenges.
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
    -- #142: joined challenges whose target is now met.
    RETURN cardinality(v_ids) + public._evaluate_challenges(p_user, p_broadcast);
END;
$$;

DROP FUNCTION public.get_activity_feed(TEXT, TIMESTAMPTZ, INT, UUID, BOOLEAN);

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

-- -----------------------------------------------------------------------------
-- 7. GRANTS
-- -----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public._valid_challenge_rule(JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._title_matches_filter(JSONB, public.titles) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._title_matches_rule(JSONB, public.titles) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._can_see_challenge(public.challenge_status_enum, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._challenge_medal_id(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._sync_challenge_medal() FROM PUBLIC;
REVOKE ALL ON FUNCTION public._challenge_matches(public.challenges, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._challenge_progress(public.challenges, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._evaluate_challenges(UUID, BOOLEAN) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._challenge_cards(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._fill_template_rule(JSONB, JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._join_squad_challenges() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.discover_challenges() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.my_challenges() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_challenge(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.challenge_progress(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.challenge_picks(UUID, INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.join_challenge(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.leave_challenge(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_squad_challenge(UUID, TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, JSONB, INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_upsert_challenge(JSONB) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_upsert_challenge_template(JSONB) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_activity_feed(TEXT, TIMESTAMPTZ, INT, UUID, BOOLEAN, BOOLEAN) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public._can_see_challenge(public.challenge_status_enum, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.discover_challenges() TO authenticated;
GRANT EXECUTE ON FUNCTION public.my_challenges() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_challenge(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.challenge_progress(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.challenge_picks(UUID, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_challenge(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.leave_challenge(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_squad_challenge(UUID, TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, JSONB, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_challenge(JSONB) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_upsert_challenge_template(JSONB) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_activity_feed(TEXT, TIMESTAMPTZ, INT, UUID, BOOLEAN, BOOLEAN) TO authenticated;
