-- Migration 20261010000900_private_logging.sql
-- FE-LOG-02: "Broadcast to Feed" opt-out. insert_user_ranking_atomic gains p_broadcast
-- (default TRUE keeps every existing caller unchanged); when FALSE the RANKING_CREATED
-- activity row is not written, so the log stays out of followers' feeds.

DROP FUNCTION public.insert_user_ranking_atomic(INT, public.media_type_enum, INT, public.watch_status_enum,
    public.finale_impact_enum, VARCHAR, TEXT[], VARCHAR, BOOLEAN, public.viewing_venue_enum, VARCHAR, UUID);

CREATE OR REPLACE FUNCTION public.insert_user_ranking_atomic(
    p_title_id INT,
    p_media_type public.media_type_enum,
    p_target_rank INT,
    p_status public.watch_status_enum DEFAULT 'COMPLETED',
    p_finale_impact public.finale_impact_enum DEFAULT NULL,
    p_review VARCHAR DEFAULT NULL,
    p_tags TEXT[] DEFAULT ARRAY[]::TEXT[],
    p_character VARCHAR DEFAULT NULL,
    p_is_rewatch BOOLEAN DEFAULT FALSE,
    p_venue public.viewing_venue_enum DEFAULT NULL,
    p_audio_language VARCHAR DEFAULT NULL,
    p_client_mutation_id UUID DEFAULT NULL,
    p_broadcast BOOLEAN DEFAULT TRUE
)
RETURNS public.user_rankings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
    v_existing public.user_rankings;
    v_n INT;
    v_target INT;
    v_result public.user_rankings;
BEGIN
    PERFORM public._lock_canon(v_user, p_media_type);
    -- Read by activity_on_ranking_created(); reset below so later inserts in the same
    -- transaction broadcast as usual.
    PERFORM set_config('telly.suppress_ranking_activity', CASE WHEN p_broadcast THEN 'off' ELSE 'on' END, true);

    IF public._claim_mutation(p_client_mutation_id, v_user, 'RANKING_UPSERT') THEN
        SELECT * INTO v_existing FROM public.user_rankings
        WHERE user_id = v_user AND title_id = p_title_id AND media_type = p_media_type;

        IF FOUND THEN
            PERFORM public._move_ranking(v_existing, p_target_rank);
            UPDATE public.user_rankings SET
                status = p_status,
                finale_impact = p_finale_impact,
                review_short = p_review,
                tags = COALESCE(p_tags, ARRAY[]::TEXT[]),
                favorite_character = p_character,
                is_rewatch = p_is_rewatch,
                rewatch_count = CASE WHEN p_is_rewatch THEN rewatch_count + 1 ELSE rewatch_count END,
                venue = p_venue,
                audio_language = p_audio_language
            WHERE id = v_existing.id;
        ELSE
            SELECT count(*) INTO v_n FROM public.user_rankings
            WHERE user_id = v_user AND media_type = p_media_type;
            v_target := LEAST(GREATEST(p_target_rank, 1), v_n + 1);

            UPDATE public.user_rankings SET rank_position = rank_position + 1
            WHERE user_id = v_user AND media_type = p_media_type AND rank_position >= v_target;

            INSERT INTO public.user_rankings (
                user_id, title_id, media_type, rank_position, calculated_score, rating_uncertainty,
                status, finale_impact, review_short, tags, favorite_character,
                is_rewatch, venue, audio_language
            ) VALUES (
                v_user, p_title_id, p_media_type, v_target, 10.00,
                CASE WHEN v_n = 0 THEN 0.50 ELSE 1.20 END,  -- features/02 §7.3 / §7.1
                p_status, p_finale_impact, p_review, COALESCE(p_tags, ARRAY[]::TEXT[]), p_character,
                p_is_rewatch, p_venue, p_audio_language
            );
        END IF;

        PERFORM public._recompute_canon_scores(v_user, p_media_type);
    END IF;
    PERFORM set_config('telly.suppress_ranking_activity', 'off', true);

    SELECT * INTO v_result FROM public.user_rankings
    WHERE user_id = v_user AND title_id = p_title_id AND media_type = p_media_type;
    RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.activity_on_ranking_created()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF current_setting('telly.suppress_ranking_activity', true) = 'on' THEN
        RETURN NEW;
    END IF;
    INSERT INTO public.activity_logs (user_id, activity_type, title_id, media_type, ranking_id)
    VALUES (NEW.user_id, 'RANKING_CREATED', NEW.title_id, NEW.media_type, NEW.id);
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.insert_user_ranking_atomic(INT, public.media_type_enum, INT, public.watch_status_enum,
    public.finale_impact_enum, VARCHAR, TEXT[], VARCHAR, BOOLEAN, public.viewing_venue_enum, VARCHAR, UUID, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.insert_user_ranking_atomic(INT, public.media_type_enum, INT, public.watch_status_enum,
    public.finale_impact_enum, VARCHAR, TEXT[], VARCHAR, BOOLEAN, public.viewing_venue_enum, VARCHAR, UUID, BOOLEAN) TO authenticated;
