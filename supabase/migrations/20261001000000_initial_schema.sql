-- ==============================================================================
-- TELLY: PRODUCTION DATABASE MIGRATION 01 (INITIAL SCHEMA & STORED PROCEDURES)
-- Run this in your Supabase SQL Editor or via psql database connection.
-- ==============================================================================

-- 1. EXTENSIONS & PREREQUISITES
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- 2. ENUM TYPES
CREATE TYPE public.media_type_enum AS ENUM ('MOVIE', 'TV_SERIES');
CREATE TYPE public.viewing_venue_enum AS ENUM ('HOME', 'THEATER', 'IMAX', 'OTHER');
CREATE TYPE public.watch_status_enum AS ENUM ('COMPLETED', 'WATCHING', 'DROPPED');
CREATE TYPE public.drop_reason_enum AS ENUM (
    'PACING_SLOWED', 'WRITING_JUMPED_SHARK', 'CAST_DEPARTURE',
    'TOO_DARK_DEPRESSING', 'TIME_COMMITMENT', 'BETTER_OPTIONS'
);
CREATE TYPE public.finale_impact_enum AS ENUM (
    'FLAWLESS_LANDING', 'SATISFYING_FINISH', 'FUMBLED_BAG', 
    'CANCELLED_TOO_SOON', 'STILL_AIRING'
);
CREATE TYPE public.reaction_type_enum AS ENUM (
    'FIRE', 'MIND_BLOWN', 'TRASH', 'HEARTBREAK', 'TASTE_TWIN'
);

-- 3. USERS & PROFILES
CREATE TABLE public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username VARCHAR(32) UNIQUE NOT NULL,
    display_name VARCHAR(64) NOT NULL,
    avatar_url TEXT,
    bio VARCHAR(160),
    visibility_mode VARCHAR(20) DEFAULT 'PUBLIC',
    pinned_showcase_ids INT[] DEFAULT ARRAY[]::INT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. TV SHOWS & SEASONS METADATA (TMDB CACHE)
CREATE TABLE public.tv_shows (
    id INT PRIMARY KEY, -- TMDB ID
    title VARCHAR(255) NOT NULL,
    original_network VARCHAR(100),
    first_air_date DATE,
    last_air_date DATE,
    number_of_seasons INT NOT NULL DEFAULT 1,
    number_of_episodes INT NOT NULL DEFAULT 1,
    status VARCHAR(50),
    poster_path TEXT,
    backdrop_path TEXT,
    overview TEXT,
    genres TEXT[],
    anilist_id INT UNIQUE,
    mal_id INT,
    anime_studio VARCHAR(100),
    source_material VARCHAR(50), -- 'MANGA', 'LIGHT_NOVEL', 'ORIGINAL'
    is_anime BOOLEAN DEFAULT FALSE,
    media_type media_type_enum DEFAULT 'TV_SERIES',
    runtime_minutes INT, -- Key duration metric for movies
    director VARCHAR(100),
    theatrical_release_date DATE,
    global_community_score NUMERIC(4, 2) DEFAULT 8.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE public.tv_seasons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    show_id INT REFERENCES public.tv_shows(id) ON DELETE CASCADE,
    season_number INT NOT NULL,
    title VARCHAR(100),
    episode_count INT NOT NULL,
    air_date DATE,
    poster_path TEXT,
    overview TEXT,
    UNIQUE(show_id, season_number)
);

-- 5. STREAMING PLATFORMS & AVAILABILITY
CREATE TABLE public.streaming_platforms (
    id VARCHAR(50) PRIMARY KEY, -- 'netflix', 'max', 'apple_tv_plus', 'hulu'
    display_name VARCHAR(100) NOT NULL,
    logo_url TEXT NOT NULL,
    base_deep_link TEXT,
    is_free_tier BOOLEAN DEFAULT FALSE
);

CREATE TABLE public.show_streaming_availability (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    show_id INT REFERENCES public.tv_shows(id) ON DELETE CASCADE,
    platform_id VARCHAR(50) REFERENCES public.streaming_platforms(id) ON DELETE CASCADE,
    country_code VARCHAR(2) NOT NULL DEFAULT 'US',
    monetization_type VARCHAR(20) NOT NULL,
    deep_link_url TEXT,
    available_until DATE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(show_id, platform_id, country_code, monetization_type)
);

CREATE TABLE public.user_streaming_subscriptions (
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    platform_id VARCHAR(50) REFERENCES public.streaming_platforms(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, platform_id)
);

-- 6. USER RANKINGS (THE PERSONAL CANON)
CREATE TABLE public.user_rankings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    show_id INT REFERENCES public.tv_shows(id) ON DELETE CASCADE,
    rank_order INT NOT NULL,
    calculated_score NUMERIC(4, 2) NOT NULL,
    status watch_status_enum NOT NULL DEFAULT 'COMPLETED',
    finale_impact finale_impact_enum DEFAULT 'STILL_AIRING',
    favorite_character VARCHAR(100),
    review_short VARCHAR(280),
    tags TEXT[],
    watched_with_user_ids UUID[],
    rating_uncertainty NUMERIC(3, 2) DEFAULT 1.20, -- TrueSkill sigma (uncertainty/confidence)
    audio_language VARCHAR(10) DEFAULT 'SUB',      -- 'SUB', 'DUB'
    is_franchise_rollup BOOLEAN DEFAULT TRUE,
    media_type media_type_enum DEFAULT 'TV_SERIES',
    is_rewatch BOOLEAN DEFAULT FALSE,
    rewatch_count INT DEFAULT 1,
    venue viewing_venue_enum DEFAULT 'HOME',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, show_id)
);

-- External Accounts Sync (Letterboxd / AniList / MyAnimeList)
CREATE TABLE public.user_external_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    service_name VARCHAR(20) NOT NULL, -- 'LETTERBOXD', 'ANILIST', 'MYANIMELIST'
    external_username VARCHAR(100) NOT NULL,
    last_synced_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    imported_count INT DEFAULT 0,
    UNIQUE(user_id, service_name)
);

CREATE TABLE public.pairwise_duels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    winner_show_id INT REFERENCES public.tv_shows(id) ON DELETE CASCADE,
    loser_show_id INT REFERENCES public.tv_shows(id) ON DELETE CASCADE,
    is_upset BOOLEAN DEFAULT FALSE,
    media_type media_type_enum DEFAULT 'TV_SERIES',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE public.user_dropped_shows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    show_id INT REFERENCES public.tv_shows(id) ON DELETE CASCADE,
    dropped_at_season INT NOT NULL,
    dropped_at_episode INT,
    reason drop_reason_enum NOT NULL,
    willing_to_revisit BOOLEAN DEFAULT FALSE,
    notes VARCHAR(280),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, show_id)
);

CREATE TABLE public.user_watchlist (
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    show_id INT REFERENCES public.tv_shows(id) ON DELETE CASCADE,
    priority INT DEFAULT 0,
    recommended_by_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, show_id)
);

-- 7. SOCIAL GRAPH & TASTE MATCHING
CREATE TABLE public.friendships (
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    friend_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'ACCEPTED',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, friend_id)
);

CREATE TABLE public.taste_matches (
    user_a UUID REFERENCES public.users(id) ON DELETE CASCADE,
    user_b UUID REFERENCES public.users(id) ON DELETE CASCADE,
    match_percentage INT NOT NULL,
    mutual_show_count INT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_a, user_b)
);

CREATE TABLE public.squads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(64) NOT NULL,
    avatar_url TEXT,
    created_by UUID REFERENCES public.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE public.squad_members (
    squad_id UUID REFERENCES public.squads(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    role VARCHAR(20) DEFAULT 'MEMBER',
    PRIMARY KEY (squad_id, user_id)
);

-- 8. FEED REACTIONS & SPOILER-PROTECTED COMMENTS
CREATE TABLE public.feed_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ranking_id UUID REFERENCES public.user_rankings(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    reaction_type reaction_type_enum NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(ranking_id, user_id, reaction_type)
);

CREATE TABLE public.ranking_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ranking_id UUID REFERENCES public.user_rankings(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    comment_text VARCHAR(500) NOT NULL,
    contains_spoilers BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 9. INDEXES
CREATE INDEX idx_user_rankings_user_media_rank ON public.user_rankings(user_id, media_type, rank_order ASC);
CREATE INDEX idx_user_rankings_show ON public.user_rankings(show_id);
CREATE INDEX idx_tv_shows_title_trgm ON public.tv_shows USING GIN(title gin_trgm_ops);
CREATE INDEX idx_tv_shows_genres ON public.tv_shows USING GIN(genres);
CREATE INDEX idx_friendships_lookup ON public.friendships(user_id, status);

-- 10. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_rankings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_watchlist ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public profiles are viewable by everyone" 
ON public.users FOR SELECT USING (true);

CREATE POLICY "Users can edit own profile" 
ON public.users FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "User rankings viewable by everyone" 
ON public.user_rankings FOR SELECT USING (true);

CREATE POLICY "Users can manage own rankings" 
ON public.user_rankings FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can view and edit own watchlist" 
ON public.user_watchlist FOR ALL USING (auth.uid() = user_id);

-- 11. ATOMIC STORED PROCEDURES
CREATE OR REPLACE FUNCTION insert_user_ranking_atomic(
    p_user_id UUID,
    p_show_id INT,
    p_target_rank INT,
    p_status watch_status_enum,
    p_finale_impact finale_impact_enum,
    p_review VARCHAR,
    p_tags TEXT[],
    p_character VARCHAR,
    p_media_type media_type_enum DEFAULT 'TV_SERIES',
    p_is_rewatch BOOLEAN DEFAULT FALSE,
    p_venue viewing_venue_enum DEFAULT 'HOME'
) RETURNS VOID AS $$
DECLARE
    v_total_items INT;
    r RECORD;
    v_percentile NUMERIC;
    v_score NUMERIC;
BEGIN
    -- 1. Shift existing ranks for the specific media canon
    UPDATE public.user_rankings
    SET rank_order = rank_order + 1
    WHERE user_id = p_user_id 
      AND media_type = p_media_type 
      AND rank_order >= p_target_rank;

    -- 2. Insert new ranking into the designated canon
    INSERT INTO public.user_rankings (
        user_id, show_id, rank_order, calculated_score,
        status, finale_impact, review_short, tags, favorite_character,
        media_type, is_rewatch, venue, updated_at
    ) VALUES (
        p_user_id, p_show_id, p_target_rank, 10.00,
        p_status, p_finale_impact, p_review, p_tags, p_character,
        p_media_type, p_is_rewatch, p_venue, NOW()
    );

    -- 3. Recalculate dynamic scores across this media canon
    SELECT COUNT(*) INTO v_total_items 
    FROM public.user_rankings 
    WHERE user_id = p_user_id AND media_type = p_media_type;

    FOR r IN SELECT id, rank_order FROM public.user_rankings 
             WHERE user_id = p_user_id AND media_type = p_media_type 
             ORDER BY rank_order LOOP
        IF v_total_items = 1 THEN
            v_score := 10.00;
        ELSE
            v_percentile := (v_total_items - r.rank_order)::NUMERIC / (v_total_items - 1)::NUMERIC;
            v_score := ROUND(1.0 + 9.0 * POWER(v_percentile, 0.82), 2);
        END IF;

        UPDATE public.user_rankings
        SET calculated_score = v_score
        WHERE id = r.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION calculate_taste_match_rpc(
    p_user_a UUID,
    p_user_b UUID
) RETURNS TABLE (match_pct INT, mutual_count INT) AS $$
DECLARE
    k INT;
    sum_d_sq NUMERIC := 0;
    raw_rho NUMERIC;
    w NUMERIC;
    adj_rho NUMERIC;
    final_score INT;
BEGIN
    SELECT COUNT(*), COALESCE(SUM(POWER(a.rank_order - b.rank_order, 2)), 0)
    INTO k, sum_d_sq
    FROM public.user_rankings a
    JOIN public.user_rankings b ON a.show_id = b.show_id
    WHERE a.user_id = p_user_a AND b.user_id = p_user_b;

    IF k < 2 THEN
        RETURN QUERY SELECT 50, k;
        RETURN;
    END IF;

    raw_rho := 1.0 - (6.0 * sum_d_sq) / (k * (POWER(k, 2) - 1.0));
    w := k::NUMERIC / (k::NUMERIC + 5.0);
    adj_rho := w * raw_rho;
    final_score := ROUND(((adj_rho + 1.0) / 2.0) * 100);

    RETURN QUERY SELECT final_score, k;
END;
$$ LANGUAGE plpgsql STABLE;
