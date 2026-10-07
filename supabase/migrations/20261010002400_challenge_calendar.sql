-- Migration 20261010002400_challenge_calendar.sql
-- #143 (epic #50): recurring challenges from the launch calendar (Spec 10 §8.4).
--
-- * challenge_calendar: the published copy of content/challenge_calendar.yaml (one row per
--   planned challenge: month, template, params, name, target, featured), written by
--   tool/challenges/publish.py through admin_upsert_calendar_entry.
-- * schedule_calendar_challenges(month): creates that month's challenges from their templates
--   (live from the 1st to the 1st of the next month, UTC). Idempotent: a slug that exists is
--   left alone.
-- * expire_featured_challenges(): clears the featured flag on challenges that have ended.
-- * "Featured" now means featured during the challenge's own window: the global unique index
--   is replaced by admin_upsert_challenge un-featuring only overlapping challenges, so the
--   calendar can feature one challenge per month ahead of time.
-- * The challenge-scheduler edge function calls both; pg_cron runs it on the 25th (next
--   month) and the 1st (safety net) through _invoke_edge_function (Vault secrets, #152).

DROP INDEX public.uq_challenges_featured;

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
    -- Only challenges running at the same time lose the flag (#143): next month's featured
    -- challenge doesn't un-feature this month's.
    IF v_featured THEN
        UPDATE public.challenges SET featured = FALSE
        WHERE featured AND slug <> (p_challenge ->> 'slug')
          AND tstzrange(starts_at, COALESCE(ends_at, 'infinity'))
              && tstzrange((p_challenge ->> 'starts_at')::TIMESTAMPTZ,
                           COALESCE((p_challenge ->> 'ends_at')::TIMESTAMPTZ, 'infinity'));
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

CREATE TABLE public.challenge_calendar (
    slug TEXT PRIMARY KEY CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND length(slug) BETWEEN 3 AND 50),
    month DATE NOT NULL CHECK (date_trunc('month', month)::DATE = month),
    template_key TEXT NOT NULL REFERENCES public.challenge_templates(key),
    name VARCHAR(64) NOT NULL,
    description VARCHAR(200),
    params JSONB NOT NULL DEFAULT '{}'::jsonb,
    target INT CHECK (target IS NULL OR target BETWEEN 1 AND 1000),
    featured BOOLEAN NOT NULL DEFAULT FALSE,
    art TEXT,
    medal_glyph VARCHAR(4)
);
CREATE INDEX idx_challenge_calendar_month ON public.challenge_calendar (month);

ALTER TABLE public.challenge_calendar ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.challenge_calendar FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.admin_upsert_calendar_entry(p_entry JSONB)
RETURNS public.challenge_calendar
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_row public.challenge_calendar;
BEGIN
    INSERT INTO public.challenge_calendar (slug, month, template_key, name, description, params, target, featured,
                                           art, medal_glyph)
    VALUES (
        p_entry ->> 'slug', (p_entry ->> 'month')::DATE, p_entry ->> 'template', p_entry ->> 'name',
        p_entry ->> 'description', COALESCE(p_entry -> 'params', '{}'::jsonb), (p_entry ->> 'target')::INT,
        COALESCE((p_entry ->> 'featured')::BOOLEAN, FALSE), p_entry ->> 'art', p_entry ->> 'medal_glyph'
    )
    ON CONFLICT (slug) DO UPDATE SET
        month = EXCLUDED.month, template_key = EXCLUDED.template_key, name = EXCLUDED.name,
        description = EXCLUDED.description, params = EXCLUDED.params, target = EXCLUDED.target,
        featured = EXCLUDED.featured, art = EXCLUDED.art, medal_glyph = EXCLUDED.medal_glyph
    RETURNING * INTO v_row;
    RETURN v_row;
END;
$$;

-- Creates the month's planned challenges that don't exist yet. Returns how many it created.
CREATE OR REPLACE FUNCTION public.schedule_calendar_challenges(p_month DATE)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_month DATE := date_trunc('month', p_month)::DATE;
    v_e public.challenge_calendar;
    v_t public.challenge_templates;
    v_target INT;
    v_desc TEXT;
    v_key TEXT;
    v_value JSONB;
    v_rule JSONB;
    v_created INT := 0;
BEGIN
    FOR v_e IN
        SELECT * FROM public.challenge_calendar e
        WHERE e.month = v_month AND NOT EXISTS (SELECT 1 FROM public.challenges c WHERE c.slug = e.slug)
        ORDER BY e.featured DESC, e.slug
    LOOP
        SELECT * INTO v_t FROM public.challenge_templates WHERE key = v_e.template_key;
        v_rule := public._fill_template_rule(v_t.rule, v_e.params);
        IF v_rule::TEXT LIKE '%"$%' OR NOT public._valid_challenge_rule(v_rule) THEN
            RAISE WARNING 'calendar entry % skipped: template % needs params %', v_e.slug, v_t.key, v_t.params;
            CONTINUE;
        END IF;
        v_target := COALESCE(v_e.target, v_t.target);
        v_desc := replace(COALESCE(v_e.description, v_t.description), '$target', v_target::TEXT);
        FOR v_key, v_value IN SELECT * FROM jsonb_each(v_e.params) LOOP
            v_desc := replace(v_desc, '$' || v_key, v_value #>> '{}');
        END LOOP;

        PERFORM public.admin_upsert_challenge(jsonb_build_object(
            'slug', v_e.slug, 'name', v_e.name, 'description', left(v_desc, 200),
            'art', COALESCE(v_e.art, v_t.art), 'medal_glyph', COALESCE(v_e.medal_glyph, v_t.medal_glyph),
            'starts_at', v_month::TIMESTAMP AT TIME ZONE 'UTC',
            'ends_at', (v_month + INTERVAL '1 month')::TIMESTAMP AT TIME ZONE 'UTC',
            'rule', v_rule, 'target', v_target, 'featured', v_e.featured,
            'template_key', v_t.key, 'status', 'live'));
        v_created := v_created + 1;
    END LOOP;
    RETURN v_created;
END;
$$;

CREATE OR REPLACE FUNCTION public.expire_featured_challenges()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_n INT;
BEGIN
    UPDATE public.challenges SET featured = FALSE, updated_at = NOW()
    WHERE featured AND ends_at IS NOT NULL AND ends_at <= NOW();
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_upsert_calendar_entry(JSONB) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.schedule_calendar_challenges(DATE) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.expire_featured_challenges() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_calendar_entry(JSONB) TO service_role;
GRANT EXECUTE ON FUNCTION public.schedule_calendar_challenges(DATE) TO service_role;
GRANT EXECUTE ON FUNCTION public.expire_featured_challenges() TO service_role;

-- The 25th prepares next month; the 1st is a safety net (both idempotent).
SELECT cron.schedule('challenge-scheduler-prepare', '0 6 25 * *',
    $$SELECT public._invoke_edge_function('challenge-scheduler')$$);
SELECT cron.schedule('challenge-scheduler-month-start', '5 0 1 * *',
    $$SELECT public._invoke_edge_function('challenge-scheduler')$$);
