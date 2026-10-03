-- =============================================================================
-- TELLY BASELINE SCHEMA (BE-601)
-- Normative contract: docs/technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md §2
-- Replaces the four pre-Sprint-6 migrations (never applied to any environment; decision D5).
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA extensions;

-- -----------------------------------------------------------------------------
-- 1. ENUMERATED TYPES (Spec 02 §2.1)
-- -----------------------------------------------------------------------------
CREATE TYPE public.media_type_enum AS ENUM ('movie', 'tv');
CREATE TYPE public.watch_status_enum AS ENUM ('COMPLETED', 'WATCHING', 'DROPPED');
CREATE TYPE public.finale_impact_enum AS ENUM (
    'FLAWLESS_LANDING', 'SATISFYING_FINISH', 'FUMBLED_BAG', 'CANCELLED_TOO_SOON', 'STILL_AIRING'
);
CREATE TYPE public.viewing_venue_enum AS ENUM ('HOME', 'THEATER', 'IMAX', 'OTHER');
CREATE TYPE public.drop_reason_enum AS ENUM (
    'PACING_SLOWED', 'WRITING_JUMPED_SHARK', 'CAST_DEPARTURE',
    'TOO_DARK_DEPRESSING', 'TIME_COMMITMENT', 'BETTER_OPTIONS'
);
CREATE TYPE public.reaction_type_enum AS ENUM ('FIRE', 'MIND_BLOWN', 'TRASH', 'HEARTBREAK', 'TASTE_TWIN');
CREATE TYPE public.follow_status_enum AS ENUM ('pending', 'accepted', 'rejected');
CREATE TYPE public.visibility_mode_enum AS ENUM ('PUBLIC', 'FRIENDS_ONLY', 'GHOST');
CREATE TYPE public.report_reason_enum AS ENUM ('UNMARKED_SPOILER', 'HARASSMENT', 'SPAM', 'INACCURATE_METADATA');
CREATE TYPE public.report_target_enum AS ENUM ('COMMENT', 'ACTIVITY', 'RANKING', 'USER');

-- -----------------------------------------------------------------------------
-- 2. SHARED TRIGGER FUNCTIONS
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

-- -----------------------------------------------------------------------------
-- 3. USERS
-- -----------------------------------------------------------------------------
CREATE TABLE public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username VARCHAR(20) UNIQUE
        CHECK (username ~ '^[a-z0-9_]{3,20}$' AND username !~ '__'),
    display_name VARCHAR(64) NOT NULL DEFAULT '',
    avatar_url TEXT,
    bio VARCHAR(160),
    visibility_mode public.visibility_mode_enum NOT NULL DEFAULT 'PUBLIC',
    pinned_showcase JSONB NOT NULL DEFAULT '[]'::jsonb
        CHECK (jsonb_typeof(pinned_showcase) = 'array' AND jsonb_array_length(pinned_showcase) <= 3),
    preferences JSONB NOT NULL DEFAULT '{}'::jsonb,
    onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deletion_requested_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Skeleton profile on sign-up (BE-103 / Spec 02 §3.4).
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.users (id, display_name)
    VALUES (
        NEW.id,
        LEFT(COALESCE(NEW.raw_user_meta_data ->> 'full_name', NEW.raw_user_meta_data ->> 'name', ''), 64)
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

-- -----------------------------------------------------------------------------
-- 4. TITLES & METADATA (TMDB cache; composite key per invariant I-2)
-- -----------------------------------------------------------------------------
CREATE TABLE public.titles (
    id INT NOT NULL,
    media_type public.media_type_enum NOT NULL,
    title VARCHAR(255) NOT NULL,
    original_title VARCHAR(255),
    release_date DATE,
    last_air_date DATE,
    status VARCHAR(50),
    poster_path TEXT,
    backdrop_path TEXT,
    overview TEXT,
    genres TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    original_network VARCHAR(100),
    number_of_seasons INT,
    number_of_episodes INT,
    runtime_minutes INT,
    director VARCHAR(100),
    is_anime BOOLEAN NOT NULL DEFAULT FALSE,
    anilist_id INT,
    mal_id INT,
    anime_studio VARCHAR(100),
    source_material VARCHAR(50),
    popularity NUMERIC(10, 3),
    global_community_score NUMERIC(4, 2),
    streaming_services JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, media_type),
    CHECK (media_type = 'tv' OR (number_of_seasons IS NULL AND number_of_episodes IS NULL))
);

CREATE TABLE public.tv_seasons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title_id INT NOT NULL,
    media_type public.media_type_enum NOT NULL DEFAULT 'tv' CHECK (media_type = 'tv'),
    season_number INT NOT NULL,
    name VARCHAR(100),
    episode_count INT NOT NULL DEFAULT 0,
    air_date DATE,
    poster_path TEXT,
    overview TEXT,
    UNIQUE (title_id, season_number),
    FOREIGN KEY (title_id, media_type) REFERENCES public.titles(id, media_type) ON DELETE CASCADE
);

-- -----------------------------------------------------------------------------
-- 5. STREAMING
-- -----------------------------------------------------------------------------
CREATE TABLE public.streaming_platforms (
    id VARCHAR(50) PRIMARY KEY,
    display_name VARCHAR(100) NOT NULL,
    logo_url TEXT NOT NULL,
    base_deep_link TEXT,
    is_free_tier BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE public.title_availability (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title_id INT NOT NULL,
    media_type public.media_type_enum NOT NULL,
    platform_id VARCHAR(50) NOT NULL REFERENCES public.streaming_platforms(id) ON DELETE CASCADE,
    country_code VARCHAR(2) NOT NULL DEFAULT 'US',
    monetization_type VARCHAR(20) NOT NULL,
    deep_link_url TEXT,
    available_until DATE,
    is_leaving_soon BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (title_id, media_type, platform_id, country_code, monetization_type),
    FOREIGN KEY (title_id, media_type) REFERENCES public.titles(id, media_type) ON DELETE CASCADE
);

CREATE TABLE public.user_streaming_subscriptions (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    platform_id VARCHAR(50) NOT NULL REFERENCES public.streaming_platforms(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, platform_id)
);

-- -----------------------------------------------------------------------------
-- 6. THE PERSONAL DUAL-CANON
-- -----------------------------------------------------------------------------
CREATE TABLE public.user_rankings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title_id INT NOT NULL,
    media_type public.media_type_enum NOT NULL,
    rank_position INT NOT NULL CHECK (rank_position >= 1),
    calculated_score NUMERIC(4, 2) NOT NULL CHECK (calculated_score BETWEEN 1.00 AND 10.00),
    rating_uncertainty NUMERIC(3, 2) NOT NULL DEFAULT 1.20 CHECK (rating_uncertainty BETWEEN 0.10 AND 3.00),
    status public.watch_status_enum NOT NULL DEFAULT 'COMPLETED',
    finale_impact public.finale_impact_enum,
    favorite_character VARCHAR(100),
    review_short VARCHAR(280),
    tags TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    watched_with_user_ids UUID[] NOT NULL DEFAULT ARRAY[]::UUID[],
    audio_language VARCHAR(10),
    is_rewatch BOOLEAN NOT NULL DEFAULT FALSE,
    rewatch_count INT NOT NULL DEFAULT 1 CHECK (rewatch_count >= 1),
    venue public.viewing_venue_enum,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_rankings_title UNIQUE (user_id, title_id, media_type),
    CONSTRAINT uq_user_rankings_position UNIQUE (user_id, media_type, rank_position)
        DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY (title_id, media_type) REFERENCES public.titles(id, media_type) ON DELETE CASCADE
);

-- Idempotency log for offline-queue replay (invariant I-5). One row per applied client mutation;
-- a replayed client_mutation_id is a no-op. Server-internal: no client policies.
CREATE TABLE public.applied_mutations (
    client_mutation_id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    kind VARCHAR(30) NOT NULL,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.pairwise_duels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    winner_title_id INT NOT NULL,
    loser_title_id INT NOT NULL,
    media_type public.media_type_enum NOT NULL,
    is_upset BOOLEAN NOT NULL DEFAULT FALSE,
    decision_time_ms INT CHECK (decision_time_ms IS NULL OR decision_time_ms >= 0),
    client_mutation_id UUID UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_pairwise_duels_different_titles CHECK (winner_title_id <> loser_title_id),
    FOREIGN KEY (winner_title_id, media_type) REFERENCES public.titles(id, media_type) ON DELETE CASCADE,
    FOREIGN KEY (loser_title_id, media_type) REFERENCES public.titles(id, media_type) ON DELETE CASCADE
);

CREATE TABLE public.user_external_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    service_name VARCHAR(20) NOT NULL CHECK (service_name IN ('LETTERBOXD', 'ANILIST', 'MYANIMELIST')),
    external_username VARCHAR(100) NOT NULL,
    last_synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    imported_count INT NOT NULL DEFAULT 0,
    UNIQUE (user_id, service_name)
);

CREATE TABLE public.user_dropped_shows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title_id INT NOT NULL,
    media_type public.media_type_enum NOT NULL,
    dropped_at_season INT,
    dropped_at_episode INT,
    reason public.drop_reason_enum NOT NULL,
    willing_to_revisit BOOLEAN NOT NULL DEFAULT FALSE,
    notify_on_acclaim BOOLEAN NOT NULL DEFAULT FALSE,
    notes VARCHAR(280),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, title_id, media_type),
    FOREIGN KEY (title_id, media_type) REFERENCES public.titles(id, media_type) ON DELETE CASCADE
);

CREATE TABLE public.user_watchlist (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title_id INT NOT NULL,
    media_type public.media_type_enum NOT NULL,
    priority INT NOT NULL DEFAULT 0,
    recommended_by_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, title_id, media_type),
    FOREIGN KEY (title_id, media_type) REFERENCES public.titles(id, media_type) ON DELETE CASCADE
);

CREATE TABLE public.user_muted_titles (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title_id INT NOT NULL,
    media_type public.media_type_enum NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, title_id, media_type),
    FOREIGN KEY (title_id, media_type) REFERENCES public.titles(id, media_type) ON DELETE CASCADE
);

-- -----------------------------------------------------------------------------
-- 7. SOCIAL GRAPH (social_follows is the only graph table; friendships removed)
-- -----------------------------------------------------------------------------
CREATE TABLE public.social_follows (
    follower_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    following_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    status public.follow_status_enum NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (follower_id, following_id),
    CONSTRAINT chk_social_follows_not_self CHECK (follower_id <> following_id)
);

CREATE TABLE public.user_blocks (
    blocker_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (blocker_id, blocked_id),
    CHECK (blocker_id <> blocked_id)
);

CREATE TABLE public.taste_matches (
    user_a UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    user_b UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    media_type public.media_type_enum NOT NULL,
    match_percentage INT NOT NULL CHECK (match_percentage BETWEEN 0 AND 100),
    mutual_count INT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_a, user_b, media_type),
    CHECK (user_a < user_b)
);

CREATE TABLE public.squads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(64) NOT NULL,
    description VARCHAR(255),
    avatar_url TEXT,
    created_by UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.squad_members (
    squad_id UUID NOT NULL REFERENCES public.squads(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL DEFAULT 'MEMBER' CHECK (role IN ('OWNER', 'ADMIN', 'MEMBER')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (squad_id, user_id)
);

-- -----------------------------------------------------------------------------
-- 8. ACTIVITY FEED, REACTIONS, COMMENTS & MODERATION
-- -----------------------------------------------------------------------------
CREATE TABLE public.activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    activity_type VARCHAR(30) NOT NULL CHECK (activity_type IN (
        'RANKING_CREATED', 'UPSET_ALERT', 'SHOW_DROPPED', 'QUEUE_ADDED', 'COMMENT_POSTED'
    )),
    title_id INT,
    media_type public.media_type_enum,
    ranking_id UUID REFERENCES public.user_rankings(id) ON DELETE SET NULL,
    target_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    is_upset BOOLEAN NOT NULL DEFAULT FALSE,
    upset_delta NUMERIC(5, 4) NOT NULL DEFAULT 0,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    FOREIGN KEY (title_id, media_type) REFERENCES public.titles(id, media_type) ON DELETE CASCADE
);

CREATE TABLE public.feed_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    activity_id UUID NOT NULL REFERENCES public.activity_logs(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    reaction_type public.reaction_type_enum NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (activity_id, user_id, reaction_type)
);

CREATE TABLE public.comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    activity_id UUID NOT NULL REFERENCES public.activity_logs(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    body VARCHAR(500) NOT NULL CHECK (length(btrim(body)) > 0),
    contains_spoilers BOOLEAN NOT NULL DEFAULT FALSE,
    is_hidden BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    target_type public.report_target_enum NOT NULL,
    target_id TEXT NOT NULL,
    reason public.report_reason_enum NOT NULL,
    notes VARCHAR(500),
    status VARCHAR(20) NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'ACTIONED', 'DISMISSED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 9. INDEXES (Spec 02 §2.3)
-- -----------------------------------------------------------------------------
CREATE INDEX idx_user_rankings_canon ON public.user_rankings (user_id, media_type, rank_position);
CREATE INDEX idx_user_rankings_title ON public.user_rankings (title_id, media_type);
CREATE INDEX idx_pairwise_duels_matchup ON public.pairwise_duels (winner_title_id, loser_title_id, media_type);
CREATE INDEX idx_pairwise_duels_loser ON public.pairwise_duels (loser_title_id, media_type);
CREATE INDEX idx_pairwise_duels_user ON public.pairwise_duels (user_id, media_type);
CREATE INDEX idx_titles_title_trgm ON public.titles USING GIN (title extensions.gin_trgm_ops);
CREATE INDEX idx_titles_genres ON public.titles USING GIN (genres);
CREATE INDEX idx_social_follows_following ON public.social_follows (following_id, status);
CREATE INDEX idx_activity_logs_user ON public.activity_logs (user_id, created_at DESC);
CREATE INDEX idx_activity_logs_created ON public.activity_logs (created_at DESC);
CREATE INDEX idx_comments_activity ON public.comments (activity_id, created_at);
CREATE INDEX idx_squad_members_user ON public.squad_members (user_id);

-- -----------------------------------------------------------------------------
-- 10. updated_at TRIGGERS
-- -----------------------------------------------------------------------------
CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_titles_updated_at BEFORE UPDATE ON public.titles
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_title_availability_updated_at BEFORE UPDATE ON public.title_availability
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_user_rankings_updated_at BEFORE UPDATE ON public.user_rankings
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_social_follows_updated_at BEFORE UPDATE ON public.social_follows
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_taste_matches_updated_at BEFORE UPDATE ON public.taste_matches
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_squads_updated_at BEFORE UPDATE ON public.squads
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_comments_updated_at BEFORE UPDATE ON public.comments
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 11. HANDLE AVAILABILITY (FE-107 / Auth spec §3 "Username Validation Rules")
-- Reserved list mirrors kReservedHandles in lib/features/auth/data/auth_repository.dart.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_handle_available(p_handle TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_handle TEXT := lower(btrim(p_handle));
BEGIN
    IF v_handle IS NULL OR v_handle !~ '^[a-z0-9_]{3,20}$' OR v_handle ~ '__' THEN
        RETURN FALSE;
    END IF;

    IF v_handle = ANY (ARRAY[
        'admin', 'telly', 'support', 'explore', 'official', 'hbo', 'netflix',
        'apple', 'max', 'disney', 'hulu', 'criterion', 'prime'
    ]) THEN
        RETURN FALSE;
    END IF;

    RETURN NOT EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.username = v_handle AND u.id IS DISTINCT FROM auth.uid()
    );
END;
$$;

REVOKE ALL ON FUNCTION public.check_handle_available(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_handle_available(TEXT) TO authenticated;
