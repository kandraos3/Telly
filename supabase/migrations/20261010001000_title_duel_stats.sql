-- Migration 20261010001000_title_duel_stats.sql
-- FE-DETAIL-02: real community duel record and canon tier distribution for SCR-08,
-- replacing the client-side placeholders. Tier bands follow the style guide §2.2
-- (God 9.20+, Prestige 8.50+, Great 7.80+).

CREATE OR REPLACE FUNCTION public.get_title_duel_stats(
    p_title_id INT,
    p_media_type public.media_type_enum
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_result JSONB;
BEGIN
    PERFORM public._require_user();

    WITH d AS (
        SELECT pd.winner_title_id, pd.loser_title_id
        FROM public.pairwise_duels pd
        JOIN public.users u ON u.id = pd.user_id AND NOT u.is_deleted
        WHERE pd.media_type = p_media_type
          AND (pd.winner_title_id = p_title_id OR pd.loser_title_id = p_title_id)
    ),
    top_win AS (
        SELECT d.loser_title_id AS opponent_id, count(*)::INT AS n
        FROM d WHERE d.winner_title_id = p_title_id
        GROUP BY d.loser_title_id
        ORDER BY n DESC, d.loser_title_id
        LIMIT 1
    ),
    tiers AS (
        SELECT
            count(*) FILTER (WHERE ur.calculated_score >= 9.20)::INT AS god,
            count(*) FILTER (WHERE ur.calculated_score >= 8.50 AND ur.calculated_score < 9.20)::INT AS prestige,
            count(*) FILTER (WHERE ur.calculated_score >= 7.80 AND ur.calculated_score < 8.50)::INT AS great,
            count(*) FILTER (WHERE ur.calculated_score < 7.80)::INT AS other,
            count(*)::INT AS total
        FROM public.user_rankings ur
        JOIN public.users u ON u.id = ur.user_id AND NOT u.is_deleted
        WHERE ur.title_id = p_title_id AND ur.media_type = p_media_type
    )
    SELECT jsonb_build_object(
        'total_duels', (SELECT count(*)::INT FROM d),
        'wins', (SELECT count(*)::INT FROM d WHERE d.winner_title_id = p_title_id),
        'top_defeated', (
            SELECT jsonb_build_object('title_id', t.id, 'title', t.title, 'count', tw.n)
            FROM top_win tw
            JOIN public.titles t ON t.id = tw.opponent_id AND t.media_type = p_media_type),
        'tiers', (
            SELECT jsonb_build_object('god', god, 'prestige', prestige, 'great', great, 'other', other, 'total', total)
            FROM tiers)
    ) INTO v_result;
    RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.get_title_duel_stats(INT, public.media_type_enum) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_title_duel_stats(INT, public.media_type_enum) TO authenticated;
