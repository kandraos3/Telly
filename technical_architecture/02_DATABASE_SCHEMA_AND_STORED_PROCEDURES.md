# Technical Architecture Spec 02: Database Schemas, Stored Procedures & Caching

## 1. Overview & Data Architecture Principles
The data tier of **Telly** must handle two distinct workloads:
1. **High-Integrity Relational Writes (ACID):** Maintaining strictly ordered user canons where inserting or moving a show at rank #4 requires an atomic shift of all subsequent rows and score recalculations.
2. **Sub-Millisecond Read Latency:** Delivering activity feeds, mutual Taste Match % calculations, and streaming availability at scale without slowing down the mobile interface.

We achieve this using **PostgreSQL 16 (via Supabase)** for persistent relational state and **Redis 7** for ephemeral duel sessions and cached leaderboards.

---

## 2. Complete PostgreSQL 16 Schema Migrations

```sql
-- ============================================================================
-- 1. EXTENSIONS & ENUMS
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- Trigram search for show titles

CREATE TYPE watch_status_enum AS ENUM ('COMPLETED', 'WATCHING', 'DROPPED');
CREATE TYPE drop_reason_enum AS ENUM (
    'PACING_SLOWED', 'WRITING_JUMPED_SHARK', 'CAST_DEPARTURE',
    'TOO_DARK_DEPRESSING', 'TIME_COMMITMENT', 'BETTER_OPTIONS'
);
CREATE TYPE finale_impact_enum AS ENUM (
    'FLAWLESS_LANDING', 'SATISFYING_FINISH', 'FUMBLED_BAG', 
    'CANCELLED_TOO_SOON', 'STILL_AIRING'
);
CREATE TYPE reaction_type_enum AS ENUM (
    'FIRE', 'MIND_BLOWN', 'TRASH', 'HEARTBREAK', 'TASTE_TWIN'
);

-- ============================================================================
-- 2. CORE USERS & PROFILES
-- ============================================================================
CREATE TABLE public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username VARCHAR(32) UNIQUE NOT NULL,
    display_name VARCHAR(64) NOT NULL,
    avatar_url TEXT,
    bio VARCHAR(160),
    visibility_mode VARCHAR(20) DEFAULT 'PUBLIC', -- 'PUBLIC', 'FRIENDS_ONLY', 'GHOST'
    pinned_showcase_ids INT[] DEFAULT ARRAY[]::INT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- 3. TV SHOWS & SEASONS METADATA (CACHED FROM TMDB)
-- ============================================================================
CREATE TABLE public.tv_shows (
    id INT PRIMARY KEY, -- TMDB ID
    title VARCHAR(255) NOT NULL,
    original_network VARCHAR(100),
    first_air_date DATE,
    last_air_date DATE,
    number_of_seasons INT NOT NULL DEFAULT 1,
    number_of_episodes INT NOT NULL DEFAULT 1,
    status VARCHAR(50), -- 'Ended', 'Returning Series', 'Canceled'
    poster_path TEXT,
    backdrop_path TEXT,
    overview TEXT,
    genres TEXT[],
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

-- ============================================================================
-- 4. USER RANKINGS (THE CANON) & DUELS
-- ============================================================================
CREATE TABLE public.user_rankings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    show_id INT REFERENCES public.tv_shows(id) ON DELETE CASCADE,
    media_type media_type_enum NOT NULL DEFAULT 'TV_SERIES',
    rank_order INT NOT NULL, -- 1 = #1 in that designated media canon
    calculated_score NUMERIC(4, 2) NOT NULL, -- e.g. 9.72
    status watch_status_enum NOT NULL DEFAULT 'COMPLETED',
    finale_impact finale_impact_enum DEFAULT 'STILL_AIRING',
    favorite_character VARCHAR(100),
    review_short VARCHAR(280),
    tags TEXT[],
    watched_with_user_ids UUID[],
    rating_uncertainty NUMERIC(3, 2) DEFAULT 1.20,
    audio_language VARCHAR(10) DEFAULT 'SUB',
    is_rewatch BOOLEAN DEFAULT FALSE,
    rewatch_count INT DEFAULT 1,
    venue viewing_venue_enum DEFAULT 'HOME',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, show_id)
);

CREATE TABLE public.pairwise_duels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    winner_show_id INT REFERENCES public.tv_shows(id) ON DELETE CASCADE,
    loser_show_id INT REFERENCES public.tv_shows(id) ON DELETE CASCADE,
    media_type media_type_enum DEFAULT 'TV_SERIES',
    is_upset BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
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

-- ============================================================================
-- 5. SOCIAL GRAPH, FEEDS & SQUADS
-- ============================================================================
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
    match_percentage INT NOT NULL, -- 0 to 100
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

-- ============================================================================
-- 6. INDEXING STRATEGY (FOR ULTRA-FAST QUERIES)
-- ============================================================================
CREATE INDEX idx_user_rankings_user_rank ON public.user_rankings(user_id, rank_order ASC);
CREATE INDEX idx_user_rankings_show_id ON public.user_rankings(show_id);
CREATE INDEX idx_tv_shows_title_trgm ON public.tv_shows USING GIN(title gin_trgm_ops);
CREATE INDEX idx_tv_shows_genres ON public.tv_shows USING GIN(genres);
CREATE INDEX idx_pairwise_duels_winner ON public.pairwise_duels(winner_show_id, loser_show_id);
CREATE INDEX idx_friendships_lookup ON public.friendships(user_id, status);
```

---

## 3. High-Performance PL/pgSQL Stored Procedures

### 3.1 Procedure 1: Atomic Ranking Insertion & Canon Re-Balancing
This procedure shifts subsequent rows, inserts the new entry, and recalibrates all dynamic decimal scores ($0.0 - 10.0$) using the power-curve formula:

```sql
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
    -- 1. Shift existing items in the designated media canon at or below target_rank down by 1
    UPDATE public.user_rankings
    SET rank_order = rank_order + 1
    WHERE user_id = p_user_id 
      AND media_type = p_media_type 
      AND rank_order >= p_target_rank;

    -- 2. Insert new record into the designated media canon
    INSERT INTO public.user_rankings (
        user_id, show_id, rank_order, calculated_score,
        status, finale_impact, review_short, tags, favorite_character,
        media_type, is_rewatch, venue, updated_at
    ) VALUES (
        p_user_id, p_show_id, p_target_rank, 10.00,
        p_status, p_finale_impact, p_review, p_tags, p_character,
        p_media_type, p_is_rewatch, p_venue, NOW()
    );

    -- 3. Calculate dynamic curve for all user's items in this media canon
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
            -- Curve formula: 1.0 + 9.0 * (percentile ^ 0.82)
            v_score := ROUND(1.0 + 9.0 * POWER(v_percentile, 0.82), 2);
        END IF;

        UPDATE public.user_rankings
        SET calculated_score = v_score
        WHERE id = r.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

### 3.2 Procedure 2: Real-Time Spearman Taste Match % Calculation
Computes rank correlation between any two users directly inside the PostgreSQL query engine in $< 2\text{ms}$:

```sql
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
    -- Count mutual overlapping shows
    SELECT COUNT(*), COALESCE(SUM(POWER(a.rank_order - b.rank_order, 2)), 0)
    INTO k, sum_d_sq
    FROM public.user_rankings a
    JOIN public.user_rankings b ON a.show_id = b.show_id
    WHERE a.user_id = p_user_a AND b.user_id = p_user_b;

    IF k < 2 THEN
        RETURN QUERY SELECT 50, k; -- Neutral 50% prior when overlap < 2
        RETURN;
    END IF;

    -- Spearman formula: 1 - (6 * sum(d^2) / (k * (k^2 - 1)))
    raw_rho := 1.0 - (6.0 * sum_d_sq) / (k * (POWER(k, 2) - 1.0));

    -- Bayesian shrinkage towards prior 0.0: W = k / (k + 5)
    w := k::NUMERIC / (k::NUMERIC + 5.0);
    adj_rho := w * raw_rho;

    -- Map [-1, 1] to [0, 100]
    final_score := ROUND(((adj_rho + 1.0) / 2.0) * 100);

    RETURN QUERY SELECT final_score, k;
END;
$$ LANGUAGE plpgsql STABLE;
```

---

## 4. Redis 7 Caching Architecture

Redis is utilized for ephemeral, high-throughput operations that do not require transactional disk logging:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        REDIS DATA STRUCTURES                           │
├────────────────────────────────────────────────────────────────────────┤
│  1. Active Duel Tournament Session                                     │
│     Key: `duel_session:{user_id}:{show_id}`                            │
│     Type: HASH (stores low_bound, high_bound, current_mid, history)    │
│     TTL: 3600 seconds (1 hour auto-expiry if abandoned)                │
│                                                                        │
│  2. Global & Network Leaderboards                                      │
│     Key: `leaderboard:global` / `leaderboard:network:hbo`              │
│     Type: ZSET (Sorted Set)                                            │
│     Member: show_id, Score: Global Elo / Community Average Score       │
│                                                                        │
│  3. Precomputed Taste Match Fast-Lookup                                │
│     Key: `taste_cache:{min_user_id}:{max_user_id}`                     │
│     Type: STRING (JSON: {"match": 88, "overlap": 34})                  │
│     TTL: 86400 seconds (24 hours)                                      │
│                                                                        │
│  4. User Streaming Availability Cache                                  │
│     Key: `stream_avail:{country}:{tmdb_id}`                            │
│     Type: STRING (JSON array of provider IDs)                          │
│     TTL: 604800 seconds (7 days)                                       │
└────────────────────────────────────────────────────────────────────────┘
```
