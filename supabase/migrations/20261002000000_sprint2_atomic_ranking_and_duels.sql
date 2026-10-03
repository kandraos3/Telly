-- ============================================================================
-- SPRINT 2 MIGRATION: ATOMIC CANON REBALANCING & PAIRWISE DUEL AUDIT LOGGING
-- Tickets: BE-201, BE-202
-- Conforms to:
-- - docs/technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md §2.3, §3.1
-- - docs/features/02_PAIRWISE_RANKING_ENGINE_AND_LOGGING.md §6.1
-- ============================================================================

-- 1. PAIRWISE DUELS AUDIT LOGGING ENHANCEMENTS (BE-202)
ALTER TABLE public.pairwise_duels
    ADD COLUMN IF NOT EXISTS decision_time_ms INT;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_pairwise_duels_different_shows'
    ) THEN
        ALTER TABLE public.pairwise_duels
            ADD CONSTRAINT chk_pairwise_duels_different_shows
            CHECK (winner_show_id != loser_show_id);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_pairwise_duels_winner_loser 
    ON public.pairwise_duels(winner_show_id, loser_show_id);

CREATE INDEX IF NOT EXISTS idx_pairwise_duels_user_media 
    ON public.pairwise_duels(user_id, media_type);

-- 2. ATOMIC USER RANKING INSERTION & CANON REBALANCING (BE-201)
CREATE OR REPLACE FUNCTION insert_user_ranking_atomic(
    p_user_id UUID,
    p_show_id INT,
    p_target_rank INT,
    p_status watch_status_enum DEFAULT 'COMPLETED',
    p_finale_impact finale_impact_enum DEFAULT 'STILL_AIRING',
    p_review VARCHAR DEFAULT NULL,
    p_tags TEXT[] DEFAULT NULL,
    p_character VARCHAR DEFAULT NULL,
    p_media_type media_type_enum DEFAULT 'TV_SERIES',
    p_is_rewatch BOOLEAN DEFAULT FALSE,
    p_venue viewing_venue_enum DEFAULT 'HOME',
    p_rating_uncertainty NUMERIC(3, 2) DEFAULT 1.20
) RETURNS public.user_rankings AS $$
DECLARE
    v_total_items INT;
    r RECORD;
    v_percentile NUMERIC;
    v_raw_score NUMERIC;
    v_final_score NUMERIC;
    v_alpha NUMERIC;
    v_prior_score NUMERIC;
    v_inserted_record public.user_rankings;
    v_is_movie BOOLEAN;
BEGIN
    -- Determine dual-canon partition
    v_is_movie := (p_media_type = 'MOVIE');

    -- 1. Shift existing items at or below target_rank down by 1 in the segregated canon
    UPDATE public.user_rankings
    SET rank_order = rank_order + 1
    WHERE user_id = p_user_id
      AND (
          (v_is_movie AND media_type = 'MOVIE') OR
          (NOT v_is_movie AND media_type != 'MOVIE')
      )
      AND rank_order >= p_target_rank;

    -- 2. Insert or update the new record at target_rank
    INSERT INTO public.user_rankings (
        user_id, show_id, rank_order, calculated_score,
        status, finale_impact, review_short, tags, favorite_character,
        media_type, is_rewatch, venue, rating_uncertainty, updated_at
    ) VALUES (
        p_user_id, p_show_id, p_target_rank, 10.00,
        p_status, p_finale_impact, p_review, p_tags, p_character,
        p_media_type, p_is_rewatch, p_venue, p_rating_uncertainty, NOW()
    )
    ON CONFLICT (user_id, show_id) DO UPDATE SET
        rank_order = EXCLUDED.rank_order,
        status = EXCLUDED.status,
        finale_impact = EXCLUDED.finale_impact,
        review_short = EXCLUDED.review_short,
        tags = EXCLUDED.tags,
        favorite_character = EXCLUDED.favorite_character,
        is_rewatch = EXCLUDED.is_rewatch,
        venue = EXCLUDED.venue,
        rating_uncertainty = EXCLUDED.rating_uncertainty,
        updated_at = NOW()
    RETURNING * INTO v_inserted_record;

    -- 3. Calculate total count in this segregated canon
    SELECT COUNT(*) INTO v_total_items
    FROM public.user_rankings
    WHERE user_id = p_user_id
      AND (
          (v_is_movie AND media_type = 'MOVIE') OR
          (NOT v_is_movie AND media_type != 'MOVIE')
      );

    -- 4. Recalibrate dynamic percentile curve for all items in the segregated canon
    FOR r IN 
        SELECT id, rank_order 
        FROM public.user_rankings
        WHERE user_id = p_user_id
          AND (
              (v_is_movie AND media_type = 'MOVIE') OR
              (NOT v_is_movie AND media_type != 'MOVIE')
          )
        ORDER BY rank_order ASC
    LOOP
        IF v_total_items = 1 THEN
            v_final_score := 10.00;
        ELSE
            v_percentile := (v_total_items - r.rank_order)::NUMERIC / (v_total_items - 1)::NUMERIC;
            -- Dynamic power curve: 1.0 + 9.0 * (percentile ^ 1.15)
            v_raw_score := 1.00 + 9.00 * POWER(v_percentile, 1.15);

            -- Apply Bayesian prior blending for N < 10
            IF v_total_items < 10 THEN
                v_alpha := v_total_items::NUMERIC / 10.0;
                v_prior_score := GREATEST(1.00, 10.00 - (r.rank_order - 1) * 0.50);
                v_final_score := ROUND((v_alpha * v_raw_score) + ((1.0 - v_alpha) * v_prior_score), 2);
            ELSE
                v_final_score := ROUND(v_raw_score, 2);
            END IF;
        END IF;

        UPDATE public.user_rankings
        SET calculated_score = v_final_score
        WHERE id = r.id;

        -- Update returned record score if this was the newly inserted record
        IF r.id = v_inserted_record.id THEN
            v_inserted_record.calculated_score := v_final_score;
        END IF;
    END LOOP;

    RETURN v_inserted_record;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. HELPER FUNCTION: TITLE WIN-RATE AGGREGATION (BE-202)
CREATE OR REPLACE FUNCTION get_title_win_rate(p_show_id INT)
RETURNS TABLE (
    total_duels BIGINT,
    wins BIGINT,
    losses BIGINT,
    win_rate_percent NUMERIC(5, 2)
) AS $$
BEGIN
    RETURN QUERY
    WITH duel_stats AS (
        SELECT 
            COUNT(*) FILTER (WHERE winner_show_id = p_show_id) AS w,
            COUNT(*) FILTER (WHERE loser_show_id = p_show_id) AS l
        FROM public.pairwise_duels
        WHERE winner_show_id = p_show_id OR loser_show_id = p_show_id
    )
    SELECT 
        (w + l) AS total_duels,
        w AS wins,
        l AS losses,
        CASE 
            WHEN (w + l) = 0 THEN 0.00
            ELSE ROUND((w::NUMERIC / (w + l)::NUMERIC) * 100.0, 2)
        END AS win_rate_percent
    FROM duel_stats;
END;
$$ LANGUAGE plpgsql STABLE;
