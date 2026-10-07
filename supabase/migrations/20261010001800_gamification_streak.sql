-- Migration 20261010001800_gamification_streak.sql
-- #135 (epic #50): the anti-gaming rule and the weekly streak, Spec 10 §2–§3.
--
-- 1. qualifying_rankings: the COMPLETED rankings that every gamification count runs over.
--    A ranking qualifies when the title took part in one of the user's duels in that canon,
--    or when it was the first title in that canon (ties on created_at broken by id, so a
--    bulk import can let at most one title per canon through). security_invoker keeps RLS.
-- 2. users.timezone (IANA, default UTC) plus set_timezone(), which validates the name.
--    The column isn't client-writable; the RPC is the only way in.
-- 3. weekly_streak(user, now): current and best weekly streaks and the last 7 weeks, with at
--    most one freeze per calendar month. Computed, never stored.
--
-- Additive: no existing function, column or policy changes.

-- -----------------------------------------------------------------------------
-- 1. QUALIFYING RANKINGS
-- -----------------------------------------------------------------------------
CREATE INDEX idx_user_rankings_canon_created
    ON public.user_rankings (user_id, media_type, created_at, id);

CREATE VIEW public.qualifying_rankings
WITH (security_invoker = true) AS
SELECT r.user_id, r.title_id, r.media_type, r.created_at
FROM public.user_rankings r
WHERE r.status = 'COMPLETED'
  AND (
      EXISTS (
          SELECT 1 FROM public.pairwise_duels d
          WHERE d.user_id = r.user_id
            AND d.media_type = r.media_type
            AND r.title_id IN (d.winner_title_id, d.loser_title_id)
      )
      OR NOT EXISTS (
          SELECT 1 FROM public.user_rankings e
          WHERE e.user_id = r.user_id
            AND e.media_type = r.media_type
            AND (e.created_at, e.id) < (r.created_at, r.id)
      )
  );

REVOKE ALL ON public.qualifying_rankings FROM PUBLIC, anon;
GRANT SELECT ON public.qualifying_rankings TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 2. TIME ZONE
-- -----------------------------------------------------------------------------
ALTER TABLE public.users
    ADD COLUMN timezone TEXT NOT NULL DEFAULT 'UTC';

CREATE OR REPLACE FUNCTION public.set_timezone(p_timezone TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
BEGIN
    IF p_timezone IS NULL OR NOT EXISTS (SELECT 1 FROM pg_timezone_names WHERE name = p_timezone) THEN
        RAISE EXCEPTION 'unknown time zone: %', p_timezone USING ERRCODE = '22023';
    END IF;
    UPDATE public.users SET timezone = p_timezone, updated_at = NOW()
    WHERE id = v_user AND timezone IS DISTINCT FROM p_timezone;
    RETURN p_timezone;
END;
$$;

REVOKE ALL ON FUNCTION public.set_timezone(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_timezone(TEXT) TO authenticated;

-- -----------------------------------------------------------------------------
-- 3. WEEKLY STREAK
-- -----------------------------------------------------------------------------
-- Weeks run Monday to Sunday in the user's time zone. Walking back from the current week:
--   * a counted week (≥ 1 qualifying ranking) adds 1;
--   * the current week, if not yet counted, is 'current' and never breaks anything;
--   * a missed week inside a run is held as a freeze if no freeze is used in the calendar
--     month of its Monday; it becomes 'frozen' once an earlier counted week confirms the
--     bridge, and reverts to 'missed' if the run ends first;
--   * a missed week with no freeze ends the run. The first run is the current streak.
-- SECURITY INVOKER: the caller sees only what RLS lets them see (their own and visible
-- friends' rankings), so a hidden user reads as zero.
CREATE OR REPLACE FUNCTION public.weekly_streak(p_user UUID, p_now TIMESTAMPTZ DEFAULT NOW())
RETURNS TABLE (current_weeks INT, best_weeks INT, weeks JSONB)
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    v_tz TEXT;
    v_cur DATE;
    v_counted DATE[];
    v_first DATE;
    v_stop DATE;
    v_week DATE;
    v_month DATE;
    v_held DATE;
    v_run INT := 0;
    v_in_run BOOLEAN := TRUE;   -- the live run starts at the current week
    v_live BOOLEAN := TRUE;     -- still inside the first (current) run
    v_current INT := 0;
    v_best INT := 0;
    v_pending DATE[] := ARRAY[]::DATE[];
    v_pending_months DATE[] := ARRAY[]::DATE[];
    v_used_months DATE[] := ARRAY[]::DATE[];
    v_status JSONB := '{}'::JSONB;   -- week (date text) → status
    v_out JSONB := '[]'::JSONB;
    i INT;
BEGIN
    SELECT COALESCE(u.timezone, 'UTC') INTO v_tz FROM public.users u WHERE u.id = p_user;
    v_tz := COALESCE(v_tz, 'UTC');
    v_cur := date_trunc('week', p_now AT TIME ZONE v_tz)::DATE;

    SELECT array_agg(DISTINCT date_trunc('week', q.created_at AT TIME ZONE v_tz)::DATE)
    INTO v_counted
    FROM public.qualifying_rankings q
    WHERE q.user_id = p_user AND q.created_at <= p_now;
    v_counted := COALESCE(v_counted, ARRAY[]::DATE[]);

    SELECT min(c) INTO v_first FROM unnest(v_counted) c;
    v_stop := LEAST(COALESCE(v_first, v_cur), v_cur - 42);

    v_week := v_cur;
    WHILE v_week >= v_stop LOOP
        v_month := date_trunc('month', v_week)::DATE;
        IF v_week = ANY (v_counted) THEN
            IF v_in_run THEN
                -- the pending freezes bridged to this counted week: they stand
                FOREACH v_held IN ARRAY v_pending LOOP
                    v_status := v_status || jsonb_build_object(v_held::TEXT, 'frozen');
                END LOOP;
                v_used_months := v_used_months || v_pending_months;
            END IF;
            v_pending := ARRAY[]::DATE[];
            v_pending_months := ARRAY[]::DATE[];
            v_in_run := TRUE;
            v_run := v_run + 1;
            v_status := v_status || jsonb_build_object(v_week::TEXT, 'counted');
        ELSIF v_week = v_cur THEN
            v_status := v_status || jsonb_build_object(v_week::TEXT, 'current');
        ELSIF v_in_run
              AND v_week >= COALESCE(v_first, v_cur)
              AND NOT (v_month = ANY (v_used_months))
              AND NOT (v_month = ANY (v_pending_months)) THEN
            v_pending := v_pending || v_week;
            v_pending_months := v_pending_months || v_month;
        ELSE
            -- the run ends here; unconfirmed freezes fall back to missed
            IF v_in_run THEN
                v_best := GREATEST(v_best, v_run);
                IF v_live THEN v_current := v_run; v_live := FALSE; END IF;
            END IF;
            FOREACH v_held IN ARRAY v_pending LOOP
                v_status := v_status || jsonb_build_object(v_held::TEXT, 'missed');
            END LOOP;
            v_pending := ARRAY[]::DATE[];
            v_pending_months := ARRAY[]::DATE[];
            v_run := 0;
            v_in_run := FALSE;
            v_status := v_status || jsonb_build_object(v_week::TEXT, 'missed');
        END IF;
        v_week := v_week - 7;
    END LOOP;

    IF v_in_run THEN
        v_best := GREATEST(v_best, v_run);
        IF v_live THEN v_current := v_run; END IF;
    END IF;
    FOREACH v_held IN ARRAY v_pending LOOP
        v_status := v_status || jsonb_build_object(v_held::TEXT, 'missed');
    END LOOP;

    -- the last 7 weeks, oldest first
    FOR i IN REVERSE 6..0 LOOP
        v_week := v_cur - 7 * i;
        v_out := v_out || jsonb_build_array(jsonb_build_object(
            'week', to_char(v_week, 'IYYY-"W"IW'),
            'starts_on', v_week,
            'status', COALESCE(v_status ->> v_week::TEXT, 'missed')));
    END LOOP;

    current_weeks := v_current;
    best_weeks := v_best;
    weeks := v_out;
    RETURN NEXT;
END;
$$;

REVOKE ALL ON FUNCTION public.weekly_streak(UUID, TIMESTAMPTZ) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.weekly_streak(UUID, TIMESTAMPTZ) TO authenticated, service_role;
