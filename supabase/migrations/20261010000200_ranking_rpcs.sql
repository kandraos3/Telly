-- =============================================================================
-- TELLY RANKING RPCs (BE-603)
-- Contract: docs/technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md §3.1, §3.2
-- Fixes BE-201: no locking, a corrupting re-rank path, and a SECURITY DEFINER function that
-- trusted a caller-supplied p_user_id.
-- Invariants: I-1 (dual canon), I-3 (contiguous 1..N), I-4 (auth.uid()), I-5 (idempotent replay).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. SCORE CURVE (§3.1) — must equal Dart ScoreCurveCalculator / score_curve_vectors.json
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.canon_score(p_rank INT, p_total INT)
RETURNS NUMERIC(4, 2)
LANGUAGE plpgsql
IMMUTABLE
STRICT
SET search_path = public
AS $$
DECLARE
    v_raw NUMERIC;
    v_alpha NUMERIC;
    v_prior NUMERIC;
BEGIN
    IF p_total < 1 OR p_rank < 1 OR p_rank > p_total THEN
        RAISE EXCEPTION 'rank % out of range for canon of %', p_rank, p_total USING ERRCODE = '22003';
    END IF;
    IF p_total = 1 THEN
        RETURN 10.00;
    END IF;

    v_raw := 1.0 + 9.0 * POWER((p_total - p_rank)::NUMERIC / (p_total - 1)::NUMERIC, 0.82::NUMERIC);

    IF p_total < 10 THEN
        v_alpha := p_total::NUMERIC / 10.0;
        v_prior := GREATEST(1.0, 10.0 - 0.5 * (p_rank - 1));
        v_raw := v_alpha * v_raw + (1.0 - v_alpha) * v_prior;
    END IF;

    RETURN ROUND(v_raw, 2);
END;
$$;

-- -----------------------------------------------------------------------------
-- 2. INTERNAL HELPERS (not callable by clients)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._require_user()
RETURNS UUID
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    v_user UUID := auth.uid();
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'not authenticated' USING ERRCODE = '42501';
    END IF;
    RETURN v_user;
END;
$$;

CREATE OR REPLACE FUNCTION public._lock_canon(p_user UUID, p_media public.media_type_enum)
RETURNS VOID
LANGUAGE sql
AS $$
    SELECT pg_advisory_xact_lock(hashtextextended(p_user::TEXT || ':' || p_media::TEXT, 0));
$$;

-- TRUE when the mutation is new (and records it); FALSE when it was already applied.
CREATE OR REPLACE FUNCTION public._claim_mutation(p_id UUID, p_user UUID, p_kind TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF p_id IS NULL THEN
        RETURN TRUE;
    END IF;

    INSERT INTO public.applied_mutations (client_mutation_id, user_id, kind)
    VALUES (p_id, p_user, p_kind)
    ON CONFLICT (client_mutation_id) DO NOTHING;
    IF FOUND THEN
        RETURN TRUE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.applied_mutations WHERE client_mutation_id = p_id AND user_id = p_user) THEN
        RAISE EXCEPTION 'mutation id belongs to another user' USING ERRCODE = '42501';
    END IF;
    RETURN FALSE;
END;
$$;

CREATE OR REPLACE FUNCTION public._recompute_canon_scores(p_user UUID, p_media public.media_type_enum)
RETURNS VOID
LANGUAGE sql
SET search_path = public
AS $$
    UPDATE public.user_rankings ur
    SET calculated_score = public.canon_score(ur.rank_position, c.n)
    FROM (
        SELECT count(*)::INT AS n FROM public.user_rankings
        WHERE user_id = p_user AND media_type = p_media
    ) c
    WHERE ur.user_id = p_user
      AND ur.media_type = p_media
      AND ur.calculated_score IS DISTINCT FROM public.canon_score(ur.rank_position, c.n);
$$;

-- Moves an already-ranked row to p_target (clamped to 1..N) keeping ranks contiguous.
CREATE OR REPLACE FUNCTION public._move_ranking(p_row public.user_rankings, p_target INT)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
    v_n INT;
    v_target INT;
BEGIN
    SELECT count(*) INTO v_n FROM public.user_rankings
    WHERE user_id = p_row.user_id AND media_type = p_row.media_type;
    v_target := LEAST(GREATEST(p_target, 1), v_n);

    IF v_target = p_row.rank_position THEN
        RETURN;
    ELSIF v_target < p_row.rank_position THEN
        UPDATE public.user_rankings SET rank_position = rank_position + 1
        WHERE user_id = p_row.user_id AND media_type = p_row.media_type
          AND rank_position >= v_target AND rank_position < p_row.rank_position;
    ELSE
        UPDATE public.user_rankings SET rank_position = rank_position - 1
        WHERE user_id = p_row.user_id AND media_type = p_row.media_type
          AND rank_position > p_row.rank_position AND rank_position <= v_target;
    END IF;

    UPDATE public.user_rankings SET rank_position = v_target WHERE id = p_row.id;
END;
$$;

REVOKE ALL ON FUNCTION public._require_user() FROM PUBLIC;
REVOKE ALL ON FUNCTION public._lock_canon(UUID, public.media_type_enum) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._claim_mutation(UUID, UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._recompute_canon_scores(UUID, public.media_type_enum) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._move_ranking(public.user_rankings, INT) FROM PUBLIC;

-- -----------------------------------------------------------------------------
-- 3. insert_user_ranking_atomic — insert, or move when already ranked
-- -----------------------------------------------------------------------------
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
    p_client_mutation_id UUID DEFAULT NULL
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

    SELECT * INTO v_result FROM public.user_rankings
    WHERE user_id = v_user AND title_id = p_title_id AND media_type = p_media_type;
    RETURN v_result;
END;
$$;

-- -----------------------------------------------------------------------------
-- 4. move_user_ranking — drag-and-drop re-index (FE-209)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.move_user_ranking(
    p_title_id INT,
    p_media_type public.media_type_enum,
    p_new_rank INT,
    p_client_mutation_id UUID DEFAULT NULL
)
RETURNS public.user_rankings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
    v_existing public.user_rankings;
    v_result public.user_rankings;
BEGIN
    PERFORM public._lock_canon(v_user, p_media_type);

    IF public._claim_mutation(p_client_mutation_id, v_user, 'RANKING_MOVE') THEN
        SELECT * INTO v_existing FROM public.user_rankings
        WHERE user_id = v_user AND title_id = p_title_id AND media_type = p_media_type;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'title % (%) is not in your canon', p_title_id, p_media_type USING ERRCODE = 'P0002';
        END IF;

        PERFORM public._move_ranking(v_existing, p_new_rank);
        PERFORM public._recompute_canon_scores(v_user, p_media_type);
    END IF;

    SELECT * INTO v_result FROM public.user_rankings
    WHERE user_id = v_user AND title_id = p_title_id AND media_type = p_media_type;
    RETURN v_result;
END;
$$;

-- -----------------------------------------------------------------------------
-- 5. delete_user_ranking — removes and closes the gap
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.delete_user_ranking(
    p_title_id INT,
    p_media_type public.media_type_enum,
    p_client_mutation_id UUID DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
    v_position INT;
BEGIN
    PERFORM public._lock_canon(v_user, p_media_type);

    IF NOT public._claim_mutation(p_client_mutation_id, v_user, 'RANKING_DELETE') THEN
        RETURN FALSE;
    END IF;

    DELETE FROM public.user_rankings
    WHERE user_id = v_user AND title_id = p_title_id AND media_type = p_media_type
    RETURNING rank_position INTO v_position;

    IF v_position IS NULL THEN
        RETURN FALSE;
    END IF;

    UPDATE public.user_rankings SET rank_position = rank_position - 1
    WHERE user_id = v_user AND media_type = p_media_type AND rank_position > v_position;

    PERFORM public._recompute_canon_scores(v_user, p_media_type);
    RETURN TRUE;
END;
$$;

-- -----------------------------------------------------------------------------
-- 6. UPSET DETECTION (features/04 §3.2) & DUEL AUDIT LOG (BE-202 / BE-302)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.title_consensus_percentile(
    p_title_id INT,
    p_media_type public.media_type_enum,
    p_exclude_user UUID DEFAULT NULL
)
RETURNS NUMERIC
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COALESCE(AVG(
        CASE WHEN c.n = 1 THEN 1.0
             ELSE (c.n - ur.rank_position)::NUMERIC / (c.n - 1)::NUMERIC END
    ), 0.5)
    FROM public.user_rankings ur
    JOIN LATERAL (
        SELECT count(*)::INT AS n FROM public.user_rankings x
        WHERE x.user_id = ur.user_id AND x.media_type = ur.media_type
    ) c ON TRUE
    WHERE ur.title_id = p_title_id
      AND ur.media_type = p_media_type
      AND ur.user_id IS DISTINCT FROM p_exclude_user;
$$;

CREATE OR REPLACE FUNCTION public.detect_upset_duel(
    p_winner_id INT,
    p_loser_id INT,
    p_media_type public.media_type_enum
)
RETURNS TABLE (is_upset BOOLEAN, winner_consensus NUMERIC, loser_consensus NUMERIC, delta NUMERIC)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    WITH m AS (
        SELECT public.title_consensus_percentile(p_winner_id, p_media_type, auth.uid()) AS w,
               public.title_consensus_percentile(p_loser_id, p_media_type, auth.uid()) AS l
    )
    SELECT (m.l - m.w) >= 0.25, ROUND(m.w, 4), ROUND(m.l, 4), ROUND(m.l - m.w, 4) FROM m;
$$;

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
            user_id, winner_title_id, loser_title_id, media_type, is_upset, decision_time_ms, client_mutation_id
        ) VALUES (
            v_user, v_winner, v_loser, v_media, v_upset.is_upset,
            (v_duel ->> 'decision_time_ms')::INT, (v_duel ->> 'client_mutation_id')::UUID
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

    RETURN v_inserted;
END;
$$;

-- -----------------------------------------------------------------------------
-- 7. GRANTS — only the public RPCs are callable by signed-in users
-- -----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.insert_user_ranking_atomic(INT, public.media_type_enum, INT, public.watch_status_enum,
    public.finale_impact_enum, VARCHAR, TEXT[], VARCHAR, BOOLEAN, public.viewing_venue_enum, VARCHAR, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.move_user_ranking(INT, public.media_type_enum, INT, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.delete_user_ranking(INT, public.media_type_enum, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_pairwise_duels(JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.title_consensus_percentile(INT, public.media_type_enum, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.detect_upset_duel(INT, INT, public.media_type_enum) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.insert_user_ranking_atomic(INT, public.media_type_enum, INT, public.watch_status_enum,
    public.finale_impact_enum, VARCHAR, TEXT[], VARCHAR, BOOLEAN, public.viewing_venue_enum, VARCHAR, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.move_user_ranking(INT, public.media_type_enum, INT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_user_ranking(INT, public.media_type_enum, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_pairwise_duels(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.detect_upset_duel(INT, INT, public.media_type_enum) TO authenticated;
