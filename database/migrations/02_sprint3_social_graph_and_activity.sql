-- ============================================================================
-- SPRINT 3 MIGRATION: Social Graph, Activity Feed, Upsets & Squads
-- Tickets: BE-301, BE-302, BE-303, BE-304
-- ============================================================================

-- 1. EXTEND USERS TABLE FOR PRIVACY
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_private BOOLEAN DEFAULT FALSE;

-- 2. SOCIAL FOLLOWS TABLE (BE-301)
CREATE TABLE IF NOT EXISTS public.social_follows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    follower_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    following_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'accepted' CHECK (status IN ('pending', 'accepted', 'rejected', 'blocked')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uq_social_follows UNIQUE (follower_id, following_id)
);

CREATE INDEX IF NOT EXISTS idx_social_follows_follower ON public.social_follows(follower_id, status);
CREATE INDEX IF NOT EXISTS idx_social_follows_following ON public.social_follows(following_id, status);

-- 3. ACTIVITY LOGS TABLE (BE-301, BE-302)
CREATE TABLE IF NOT EXISTS public.activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    activity_type VARCHAR(50) NOT NULL, -- 'RANKING_CREATED', 'UPSET_ALERT', 'SHOW_DROPPED', 'QUEUE_ADDED', 'COMMENT_POSTED'
    media_type VARCHAR(20) DEFAULT 'TV_SERIES',
    title_id INT REFERENCES public.tv_shows(id) ON DELETE CASCADE,
    ranking_id UUID REFERENCES public.user_rankings(id) ON DELETE SET NULL,
    target_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    is_upset BOOLEAN DEFAULT FALSE,
    upset_delta NUMERIC(4, 2) DEFAULT 0.00,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_activity_logs_user ON public.activity_logs(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_logs_created_at ON public.activity_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_logs_upset ON public.activity_logs(is_upset, created_at DESC);

-- 4. RLS POLICIES FOR SOCIAL PRIVACY (BE-301)
ALTER TABLE public.social_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

-- Follows policies
DROP POLICY IF EXISTS "Users can view accepted follows or their own" ON public.social_follows;
CREATE POLICY "Users can view accepted follows or their own"
ON public.social_follows FOR SELECT
USING (
    status = 'accepted'
    OR follower_id = auth.uid()
    OR following_id = auth.uid()
);

DROP POLICY IF EXISTS "Users can manage own follow requests" ON public.social_follows;
CREATE POLICY "Users can manage own follow requests"
ON public.social_follows FOR ALL
USING (follower_id = auth.uid() OR following_id = auth.uid());

-- Activity Logs RLS:
-- 1) Own activity is always visible
-- 2) If target user is public, visible to all authenticated users
-- 3) If target user is private, only visible to followers with 'accepted' status
DROP POLICY IF EXISTS "Activity visibility based on user privacy" ON public.activity_logs;
CREATE POLICY "Activity visibility based on user privacy"
ON public.activity_logs FOR SELECT
USING (
    user_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = activity_logs.user_id AND u.is_private = FALSE
    )
    OR EXISTS (
        SELECT 1 FROM public.social_follows sf
        WHERE sf.following_id = activity_logs.user_id
          AND sf.follower_id = auth.uid()
          AND sf.status = 'accepted'
    )
);

DROP POLICY IF EXISTS "Users can insert own activity" ON public.activity_logs;
CREATE POLICY "Users can insert own activity"
ON public.activity_logs FOR INSERT
WITH CHECK (user_id = auth.uid());

-- 5. UPSET ENGINE DETECTION FUNCTION (BE-302)
-- Condition: WinRate(loser) - WinRate(winner) >= 0.25 (i.e. 25% consensus divergence)
CREATE OR REPLACE FUNCTION detect_upset_duel(
    p_winner_id INT,
    p_loser_id INT
) RETURNS TABLE (
    is_upset BOOLEAN,
    winner_win_rate NUMERIC,
    loser_win_rate NUMERIC,
    delta NUMERIC
) AS $$
DECLARE
    v_winner_wins INT;
    v_winner_total INT;
    v_loser_wins INT;
    v_loser_total INT;
    v_win_rate_winner NUMERIC := 0.50;
    v_win_rate_loser NUMERIC := 0.50;
    v_delta NUMERIC := 0.00;
BEGIN
    -- Winner win rate
    SELECT 
        COUNT(*) FILTER (WHERE winner_show_id = p_winner_id),
        COUNT(*)
    INTO v_winner_wins, v_winner_total
    FROM public.pairwise_duels
    WHERE winner_show_id = p_winner_id OR loser_show_id = p_winner_id;

    IF v_winner_total > 0 THEN
        v_win_rate_winner := v_winner_wins::NUMERIC / v_winner_total::NUMERIC;
    END IF;

    -- Loser win rate
    SELECT 
        COUNT(*) FILTER (WHERE winner_show_id = p_loser_id),
        COUNT(*)
    INTO v_loser_wins, v_loser_total
    FROM public.pairwise_duels
    WHERE winner_show_id = p_loser_id OR loser_show_id = p_loser_id;

    IF v_loser_total > 0 THEN
        v_win_rate_loser := v_loser_wins::NUMERIC / v_loser_total::NUMERIC;
    END IF;

    v_delta := ROUND(v_win_rate_loser - v_win_rate_winner, 4);

    -- An upset occurs when the loser was expected to win by >= 0.25 win-rate difference
    IF v_delta >= 0.2500 THEN
        RETURN QUERY SELECT TRUE, ROUND(v_win_rate_winner, 4), ROUND(v_win_rate_loser, 4), v_delta;
    ELSE
        RETURN QUERY SELECT FALSE, ROUND(v_win_rate_winner, 4), ROUND(v_win_rate_loser, 4), v_delta;
    END IF;
END;
$$ LANGUAGE plpgsql STABLE;

-- 6. SQUADS SCHEMA & BORDA COUNT RPC (BE-304)
CREATE TABLE IF NOT EXISTS public.squads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(64) NOT NULL,
    description VARCHAR(255),
    avatar_url TEXT,
    created_by UUID REFERENCES public.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.squad_members (
    squad_id UUID REFERENCES public.squads(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    role VARCHAR(20) DEFAULT 'MEMBER',
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (squad_id, user_id)
);

-- Borda Count Aggregation RPC:
-- For member i with Ni ranked items, title s at rank r_{i,s} earns (Ni - r_{i,s} + 1) points.
CREATE OR REPLACE FUNCTION calculate_squad_canon(
    p_squad_id UUID,
    p_media_type media_type_enum DEFAULT 'TV_SERIES'
) RETURNS TABLE (
    consensus_rank INT,
    show_id INT,
    total_borda_points BIGINT,
    champion_user_id UUID,
    lowest_user_id UUID,
    members_ranked_count INT,
    rank_variance NUMERIC
) AS $$
WITH squad_users AS (
    SELECT user_id FROM public.squad_members WHERE squad_id = p_squad_id
),
member_totals AS (
    SELECT 
        ur.user_id,
        COUNT(*)::INT as n_i
    FROM public.user_rankings ur
    JOIN squad_users su ON ur.user_id = su.user_id
    WHERE ur.media_type = p_media_type
    GROUP BY ur.user_id
),
scored_titles AS (
    SELECT 
        ur.show_id,
        ur.user_id,
        ur.rank_order,
        (mt.n_i - ur.rank_order + 1) AS borda_points
    FROM public.user_rankings ur
    JOIN squad_users su ON ur.user_id = su.user_id
    JOIN member_totals mt ON ur.user_id = mt.user_id
    WHERE ur.media_type = p_media_type
),
aggregated AS (
    SELECT
        st.show_id,
        SUM(st.borda_points)::BIGINT AS total_borda_points,
        (ARRAY_AGG(st.user_id ORDER BY st.rank_order ASC))[1] AS champion_user_id,
        (ARRAY_AGG(st.user_id ORDER BY st.rank_order DESC))[1] AS lowest_user_id,
        COUNT(*)::INT AS members_ranked_count,
        COALESCE(ROUND(VARIANCE(st.rank_order)::NUMERIC, 2), 0.00) AS rank_variance
    FROM scored_titles st
    GROUP BY st.show_id
)
SELECT 
    ROW_NUMBER() OVER (ORDER BY a.total_borda_points DESC, a.members_ranked_count DESC, a.show_id ASC)::INT AS consensus_rank,
    a.show_id,
    a.total_borda_points,
    a.champion_user_id,
    a.lowest_user_id,
    a.members_ranked_count,
    a.rank_variance
FROM aggregated a
ORDER BY consensus_rank ASC;
$$ LANGUAGE sql STABLE;
