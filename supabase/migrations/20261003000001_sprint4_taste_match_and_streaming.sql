-- ============================================================================
-- Sprint 4 Migration: Taste Match % RPC & Streaming Availability Enhancements
-- ============================================================================

-- 1. Ensure taste_matches table exists with media_type partitioning
CREATE TABLE IF NOT EXISTS public.taste_matches (
    user_a UUID REFERENCES public.users(id) ON DELETE CASCADE,
    user_b UUID REFERENCES public.users(id) ON DELETE CASCADE,
    media_type media_type_enum,
    match_percentage INT NOT NULL, -- 0 to 100
    mutual_show_count INT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_a, user_b, media_type)
);

CREATE INDEX IF NOT EXISTS idx_taste_matches_lookup 
ON public.taste_matches (user_a, user_b);

-- 2. Add is_leaving_soon flag to show_streaming_availability if not present
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'show_streaming_availability' AND column_name = 'is_leaving_soon'
    ) THEN
        ALTER TABLE public.show_streaming_availability ADD COLUMN is_leaving_soon BOOLEAN DEFAULT FALSE;
    END IF;
END $$;

-- 3. High-Performance PL/pgSQL Function: calculate_taste_match_rpc
-- Implements Spearman Rank Correlation with Bayesian shrinkage prior (k0 = 5, prior = 0.0)
CREATE OR REPLACE FUNCTION calculate_taste_match_rpc(
    p_user_a UUID,
    p_user_b UUID,
    p_media_type media_type_enum DEFAULT NULL
) RETURNS TABLE (match_pct INT, mutual_count INT) AS $$
DECLARE
    k INT;
    sum_d_sq NUMERIC := 0;
    raw_rho NUMERIC;
    w NUMERIC;
    adj_rho NUMERIC;
    final_score INT;
BEGIN
    -- Calculate mutual overlap count (k) and sum of squared rank differences
    SELECT COUNT(*), COALESCE(SUM(POWER(a.rank_order - b.rank_order, 2)), 0)
    INTO k, sum_d_sq
    FROM public.user_rankings a
    JOIN public.user_rankings b ON a.show_id = b.show_id
    WHERE a.user_id = p_user_a 
      AND b.user_id = p_user_b
      AND (p_media_type IS NULL OR (a.media_type = p_media_type AND b.media_type = p_media_type));

    -- If fewer than 2 mutual titles, return neutral 50% prior
    IF k < 2 THEN
        RETURN QUERY SELECT 50, k;
        RETURN;
    END IF;

    -- Raw Spearman Rank Correlation: rho = 1 - (6 * sum(d^2) / (k * (k^2 - 1)))
    raw_rho := 1.0 - (6.0 * sum_d_sq) / (k::NUMERIC * (POWER(k::NUMERIC, 2) - 1.0));

    -- Safeguard floating point bounds [-1.0, 1.0]
    IF raw_rho > 1.0 THEN raw_rho := 1.0; END IF;
    IF raw_rho < -1.0 THEN raw_rho := -1.0; END IF;

    -- Bayesian Confidence Shrinkage Factor: W(k) = k / (k + k0), where k0 = 5 and rho_prior = 0.0
    w := k::NUMERIC / (k::NUMERIC + 5.0);
    adj_rho := w * raw_rho;

    -- Map [-1.0, 1.0] to consumer-facing [0, 100] percentage scale
    final_score := ROUND(((adj_rho + 1.0) / 2.0) * 100.0)::INT;
    
    -- Ensure 0-100 clamping
    IF final_score < 0 THEN final_score := 0; END IF;
    IF final_score > 100 THEN final_score := 100; END IF;

    RETURN QUERY SELECT final_score, k;
END;
$$ LANGUAGE plpgsql STABLE;

