-- Migration 20261010003400_tracking_refresh.sql
-- #227 (epic #168, decision 0010): the daily new-episodes check.
-- Spec: docs/features/11_WATCH_TRACKING_AND_EPISODE_PROGRESS.md §4.8, §6.5;
--       docs/technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md §3.5, §3.6.
--
--   * tracking_shows_to_refresh: which tracked series the tracking-refresh function refreshes.
--   * tracking_seasons_to_refresh: which of a show's seasons need their episodes fetched.
--   * refresh_tracking_new_episodes: flips CAUGHT_UP / FINISHED series whose next episode now
--     exists and has aired back to WATCHING, with new_episodes_since set.
--   * pg_cron `tracking-refresh` calls the edge function every day at 05:23 UTC.
-- All service-role only.

-- The tracked series to refresh: someone tracks them as CAUGHT_UP or FINISHED. Shows that have
-- ended or been canceled are only included when p_include_ended (the function passes that on
-- Mondays). Least recently refreshed first: tmdb-details touches titles.updated_at.
CREATE OR REPLACE FUNCTION public.tracking_shows_to_refresh(p_include_ended BOOLEAN, p_limit INT)
RETURNS TABLE (title_id INT)
LANGUAGE sql
STABLE
SET search_path = public
AS $$
    SELECT ut.title_id
    FROM public.user_tracking ut
    JOIN public.titles t ON t.id = ut.title_id AND t.media_type = ut.media_type
    WHERE ut.media_type = 'tv'
      AND ut.state IN ('CAUGHT_UP', 'FINISHED')
      AND (p_include_ended OR COALESCE(t.status, '') NOT IN ('Ended', 'Canceled'))
    GROUP BY ut.title_id, t.updated_at
    ORDER BY t.updated_at ASC, ut.title_id
    LIMIT GREATEST(p_limit, 0);
$$;

-- Seasons whose episodes are worth fetching: the latest season (new episodes land there), any
-- season with an unaired or undated cached episode, and any season cached only in part.
CREATE OR REPLACE FUNCTION public.tracking_seasons_to_refresh(p_title_id INT)
RETURNS TABLE (season_number INT)
LANGUAGE sql
STABLE
SET search_path = public
AS $$
    SELECT s.season_number
    FROM public.tv_seasons s
    WHERE s.title_id = p_title_id AND s.season_number >= 1
      AND (
          s.season_number = (SELECT MAX(l.season_number) FROM public.tv_seasons l
                             WHERE l.title_id = p_title_id AND l.season_number >= 1)
          OR EXISTS (SELECT 1 FROM public.tv_episodes e
                     WHERE e.title_id = s.title_id AND e.season_number = s.season_number
                       AND (e.air_date IS NULL OR e.air_date > CURRENT_DATE))
          OR (SELECT count(*) FROM public.tv_episodes e
              WHERE e.title_id = s.title_id AND e.season_number = s.season_number)
             BETWEEN 1 AND s.episode_count - 1
      )
    ORDER BY s.season_number;
$$;

-- §4.8: any CAUGHT_UP / FINISHED series whose next episode now exists and has aired is WATCHING
-- again, flagged as having new episodes. Rank, canon and events are untouched. Returns the number
-- of rows flipped.
CREATE OR REPLACE FUNCTION public.refresh_tracking_new_episodes()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_flipped INT;
BEGIN
    UPDATE public.user_tracking ut SET
        state = 'WATCHING',
        new_episodes_since = NOW(),
        finished_at = NULL
    WHERE ut.media_type = 'tv'
      AND ut.state IN ('CAUGHT_UP', 'FINISHED')
      AND EXISTS (
          SELECT 1 FROM public._tracking_next(
              ut.title_id, ut.last_season, ut.last_episode, public._user_today(ut.user_id))
      );
    GET DIAGNOSTICS v_flipped = ROW_COUNT;
    RETURN v_flipped;
END;
$$;

REVOKE ALL ON FUNCTION public.tracking_shows_to_refresh(BOOLEAN, INT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.tracking_seasons_to_refresh(INT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.refresh_tracking_new_episodes() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tracking_shows_to_refresh(BOOLEAN, INT) TO service_role;
GRANT EXECUTE ON FUNCTION public.tracking_seasons_to_refresh(INT) TO service_role;
GRANT EXECUTE ON FUNCTION public.refresh_tracking_new_episodes() TO service_role;

SELECT cron.schedule('tracking-refresh', '23 5 * * *',
    $$SELECT public._invoke_edge_function('tracking-refresh')$$);
