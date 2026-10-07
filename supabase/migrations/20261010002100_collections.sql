-- Migration 20261010002100_collections.sql
-- #140 (epic #50): TMDB collections, companies and TV type, plus collection medals
-- (Spec 10 §4.1, §7, §8.2).
--
-- * titles gains collection_id, production_companies and tv_type (written by tmdb-details),
--   and metadata_version so the maintenance run can backfill rows stored before them.
-- * title_collections caches TMDB /collection/{id}: parts and released parts, refreshed weekly.
-- * Each cached collection with at least two released films gets a gold medal
--   `collection_<id>` (trigger), earned when every released film is in the user's qualifying
--   rankings. Collections appear in my_achievements() once the user has ranked one of its films.
-- * Service-role RPCs feed tmdb-details' maintenance mode; _invoke_edge_function (pg_net +
--   Vault secrets `project_url` and `service_role_key`) lets pg_cron call edge functions. Until
--   those secrets exist the job logs a notice and does nothing.
--
-- Additive: new columns have defaults; _achievement_progress keeps its signature.

-- -----------------------------------------------------------------------------
-- 1. TITLE METADATA
-- -----------------------------------------------------------------------------
ALTER TABLE public.titles
    ADD COLUMN collection_id INT,
    ADD COLUMN production_companies TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    ADD COLUMN tv_type VARCHAR(30),
    ADD COLUMN metadata_version SMALLINT NOT NULL DEFAULT 0;

CREATE INDEX idx_titles_collection ON public.titles (collection_id) WHERE collection_id IS NOT NULL;
CREATE INDEX idx_titles_needing_details ON public.titles (popularity DESC NULLS LAST) WHERE metadata_version < 2;

-- -----------------------------------------------------------------------------
-- 2. COLLECTIONS
-- -----------------------------------------------------------------------------
CREATE TABLE public.title_collections (
    collection_id INT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    poster_path TEXT,
    part_ids INT[] NOT NULL DEFAULT ARRAY[]::INT[],
    released_part_ids INT[] NOT NULL DEFAULT ARRAY[]::INT[],
    fetched_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_title_collections_fetched ON public.title_collections (fetched_at);

ALTER TABLE public.title_collections ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.title_collections FROM anon;
CREATE POLICY title_collections_read ON public.title_collections FOR SELECT TO authenticated USING (TRUE);
REVOKE INSERT, UPDATE, DELETE ON public.title_collections FROM authenticated;

-- "The Lord of the Rings Collection" → "LR": initials of the first two significant words.
CREATE OR REPLACE FUNCTION public._collection_glyph(p_name TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT COALESCE(NULLIF(upper(string_agg(left(x.w, 1), '' ORDER BY x.n)), ''), 'C')
    FROM (
        SELECT t.w, t.n
        FROM regexp_split_to_table(
                 regexp_replace(COALESCE(p_name, ''), '\s*(collection|saga|trilogy)\s*$', '', 'i'), '[\s:\-]+'
             ) WITH ORDINALITY AS t(w, n)
        WHERE t.w <> '' AND lower(t.w) NOT IN ('the', 'a', 'an', 'of', 'and', '&')
        ORDER BY t.n
        LIMIT 2
    ) x;
$$;

-- "The Dark Knight Collection" → "The Dark Knight".
CREATE OR REPLACE FUNCTION public._collection_display_name(p_name TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$ SELECT left(regexp_replace(COALESCE(p_name, ''), '\s*collection\s*$', '', 'i'), 64) $$;

-- Keeps one gold medal per collection in step with its cache row. Two or more released films
-- make it a medal; the target is the number released (it grows as sequels come out, but a
-- medal already earned is never taken away).
CREATE OR REPLACE FUNCTION public._sync_collection_medal()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_name TEXT := public._collection_display_name(NEW.name);
    v_released INT := cardinality(NEW.released_part_ids);
BEGIN
    INSERT INTO public.achievements (id, kind, tier, name, description, glyph, threshold, collection_id, sort, active)
    VALUES (
        'collection_' || NEW.collection_id, 'collection', 'gold', v_name,
        left('Rank every released film in ' || v_name, 160), public._collection_glyph(NEW.name),
        GREATEST(v_released, 1), NEW.collection_id, 0, v_released >= 2
    )
    ON CONFLICT (id) DO UPDATE
        SET name = EXCLUDED.name,
            description = EXCLUDED.description,
            glyph = EXCLUDED.glyph,
            threshold = EXCLUDED.threshold,
            active = EXCLUDED.active;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_title_collections_medal
    AFTER INSERT OR UPDATE ON public.title_collections
    FOR EACH ROW EXECUTE FUNCTION public._sync_collection_medal();

-- -----------------------------------------------------------------------------
-- 3. PROGRESS (adds collections; everything else unchanged from 20261010002000)
-- -----------------------------------------------------------------------------
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
      );
END;
$$;

-- -----------------------------------------------------------------------------
-- 4. MAINTENANCE RPCs (service role; used by tmdb-details' maintenance mode)
-- -----------------------------------------------------------------------------
-- Titles stored before the #140 fields, ranked titles first, then by popularity.
CREATE OR REPLACE FUNCTION public.titles_needing_details(p_limit INT DEFAULT 30)
RETURNS TABLE (id INT, media_type public.media_type_enum)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT t.id, t.media_type
    FROM public.titles t
    WHERE t.metadata_version < 2
    ORDER BY EXISTS (SELECT 1 FROM public.user_rankings r WHERE r.title_id = t.id AND r.media_type = t.media_type) DESC,
             t.popularity DESC NULLS LAST, t.id
    LIMIT LEAST(GREATEST(p_limit, 1), 500);
$$;

CREATE OR REPLACE FUNCTION public.stale_title_collections(p_max_age_days INT DEFAULT 7, p_limit INT DEFAULT 30)
RETURNS TABLE (collection_id INT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT c.collection_id
    FROM public.title_collections c
    WHERE c.fetched_at < NOW() - make_interval(days => p_max_age_days)
    ORDER BY c.fetched_at
    LIMIT LEAST(GREATEST(p_limit, 1), 500);
$$;

-- -----------------------------------------------------------------------------
-- 5. SCHEDULING EDGE FUNCTIONS FROM pg_cron
-- -----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- POSTs [p_body] to the edge function [p_name] with the service-role key. Reads the Vault
-- secrets `project_url` and `service_role_key`; returns the pg_net request id, or NULL (with
-- a notice) while they're missing. Internal: only pg_cron jobs call it.
CREATE OR REPLACE FUNCTION public._invoke_edge_function(p_name TEXT, p_body JSONB DEFAULT '{}'::jsonb)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_url TEXT;
    v_key TEXT;
BEGIN
    SELECT decrypted_secret INTO v_url FROM vault.decrypted_secrets WHERE name = 'project_url';
    SELECT decrypted_secret INTO v_key FROM vault.decrypted_secrets WHERE name = 'service_role_key';
    IF v_url IS NULL OR v_key IS NULL THEN
        RAISE NOTICE 'edge function % not invoked: Vault secrets project_url / service_role_key are missing', p_name;
        RETURN NULL;
    END IF;
    RETURN net.http_post(
        url := rtrim(v_url, '/') || '/functions/v1/' || p_name,
        headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_key),
        body := p_body,
        timeout_milliseconds := 120000
    );
END;
$$;

REVOKE ALL ON FUNCTION public._collection_glyph(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._collection_display_name(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._sync_collection_medal() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.titles_needing_details(INT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stale_title_collections(INT, INT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._invoke_edge_function(TEXT, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.titles_needing_details(INT) TO service_role;
GRANT EXECUTE ON FUNCTION public.stale_title_collections(INT, INT) TO service_role;

-- Backfill and weekly collection refresh: 30 titles and 30 collections every half hour, which
-- drains the backlog and then costs almost nothing.
SELECT cron.schedule('tmdb-maintenance', '*/30 * * * *',
    $$SELECT public._invoke_edge_function('tmdb-details', '{"limit": 30}'::jsonb)$$);
