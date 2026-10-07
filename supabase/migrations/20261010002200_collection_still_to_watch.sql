-- Migration 20261010002200_collection_still_to_watch.sql
-- #141 (epic #50): the medal sheet's "Still to watch" list for a collection (Spec 10 §7, §9.3).
--
-- collection_still_to_watch(collection_id): the collection's released films the caller hasn't
-- ranked, in release order, with whether each is already in their Queue. Additive.

CREATE OR REPLACE FUNCTION public.collection_still_to_watch(p_collection_id INT)
RETURNS TABLE (title_id INT, title VARCHAR, release_year INT, poster_path TEXT, in_queue BOOLEAN)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
BEGIN
    RETURN QUERY
    SELECT t.id, t.title, EXTRACT(YEAR FROM t.release_date)::INT, t.poster_path,
           EXISTS (SELECT 1 FROM public.user_watchlist w
                   WHERE w.user_id = v_user AND w.title_id = t.id AND w.media_type = 'movie')
    FROM public.title_collections c
    CROSS JOIN LATERAL unnest(c.released_part_ids) WITH ORDINALITY AS p(id, n)
    JOIN public.titles t ON t.id = p.id AND t.media_type = 'movie'
    WHERE c.collection_id = p_collection_id
      AND NOT EXISTS (SELECT 1 FROM public.user_rankings r
                      WHERE r.user_id = v_user AND r.title_id = t.id AND r.media_type = 'movie')
    ORDER BY p.n;
END;
$$;

REVOKE ALL ON FUNCTION public.collection_still_to_watch(INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.collection_still_to_watch(INT) TO authenticated;
