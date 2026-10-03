-- =============================================================================
-- TELLY ROW-LEVEL SECURITY (BE-602)
-- Contract: docs/technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md §2.4
-- Closes audit C6 (world-readable rankings; forgeable / self-approvable follows).
-- Policies target the `authenticated` role only; `anon` gets no access to user data.
-- Ranking/duel writes are deliberately policy-less: they go through SECURITY DEFINER RPCs.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. VISIBILITY HELPERS (SECURITY DEFINER to avoid RLS recursion)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_blocked_between(p_a UUID, p_b UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.user_blocks b
        WHERE (b.blocker_id = p_a AND b.blocked_id = p_b)
           OR (b.blocker_id = p_b AND b.blocked_id = p_a)
    );
$$;

CREATE OR REPLACE FUNCTION public.can_view_user(p_target UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT CASE
        WHEN p_target IS NULL OR auth.uid() IS NULL THEN FALSE
        WHEN p_target = auth.uid() THEN TRUE
        WHEN public.is_blocked_between(p_target, auth.uid()) THEN FALSE
        ELSE EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = p_target
              AND NOT u.is_deleted
              AND (
                  u.visibility_mode = 'PUBLIC'
                  OR (
                      u.visibility_mode = 'FRIENDS_ONLY'
                      AND EXISTS (
                          SELECT 1 FROM public.social_follows f
                          WHERE f.follower_id = auth.uid()
                            AND f.following_id = p_target
                            AND f.status = 'accepted'
                      )
                  )
              )
        )
    END;
$$;

CREATE OR REPLACE FUNCTION public.is_squad_member(p_squad UUID, p_roles TEXT[] DEFAULT NULL)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.squad_members m
        WHERE m.squad_id = p_squad
          AND m.user_id = auth.uid()
          AND (p_roles IS NULL OR m.role = ANY (p_roles))
    );
$$;

CREATE OR REPLACE FUNCTION public.can_view_activity(p_activity UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.activity_logs a
        WHERE a.id = p_activity AND public.can_view_user(a.user_id)
    );
$$;

REVOKE ALL ON FUNCTION public.is_blocked_between(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.can_view_user(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_squad_member(UUID, TEXT[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.can_view_activity(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_blocked_between(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_view_user(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_squad_member(UUID, TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_view_activity(UUID) TO authenticated;

-- -----------------------------------------------------------------------------
-- 2. ENABLE RLS ON EVERY TABLE (invariant I-6)
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    t TEXT;
BEGIN
    FOR t IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    END LOOP;
END $$;

-- anon never touches user data; catalog tables are readable by signed-in users only.
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;

-- -----------------------------------------------------------------------------
-- 3. USERS — column-scoped self-update (is_deleted etc. only via RPC)
-- -----------------------------------------------------------------------------
CREATE POLICY users_select ON public.users FOR SELECT TO authenticated
    USING (public.can_view_user(id));
CREATE POLICY users_update_self ON public.users FOR UPDATE TO authenticated
    USING (id = auth.uid()) WITH CHECK (id = auth.uid());

REVOKE INSERT, UPDATE, DELETE ON public.users FROM authenticated;
GRANT UPDATE (username, display_name, avatar_url, bio, visibility_mode, pinned_showcase, preferences, onboarding_completed)
    ON public.users TO authenticated;

-- -----------------------------------------------------------------------------
-- 4. CATALOG TABLES — read-only for clients, written by service_role (edge functions)
-- -----------------------------------------------------------------------------
CREATE POLICY titles_read ON public.titles FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY tv_seasons_read ON public.tv_seasons FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY streaming_platforms_read ON public.streaming_platforms FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY title_availability_read ON public.title_availability FOR SELECT TO authenticated USING (TRUE);
REVOKE INSERT, UPDATE, DELETE ON public.titles, public.tv_seasons, public.streaming_platforms, public.title_availability
    FROM authenticated;

-- -----------------------------------------------------------------------------
-- 5. CANON & DUELS — readable per visibility; writes only through RPCs (BE-603),
--    except editorial columns on one's own rankings.
-- -----------------------------------------------------------------------------
CREATE POLICY user_rankings_select ON public.user_rankings FOR SELECT TO authenticated
    USING (public.can_view_user(user_id));
CREATE POLICY user_rankings_update_editorial ON public.user_rankings FOR UPDATE TO authenticated
    USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
REVOKE INSERT, UPDATE, DELETE ON public.user_rankings FROM authenticated;
GRANT UPDATE (status, finale_impact, favorite_character, review_short, tags, watched_with_user_ids,
              audio_language, is_rewatch, rewatch_count, venue)
    ON public.user_rankings TO authenticated;

CREATE POLICY pairwise_duels_select ON public.pairwise_duels FOR SELECT TO authenticated
    USING (public.can_view_user(user_id));
REVOKE INSERT, UPDATE, DELETE ON public.pairwise_duels FROM authenticated;

CREATE POLICY taste_matches_select ON public.taste_matches FOR SELECT TO authenticated
    USING (auth.uid() IN (user_a, user_b));
REVOKE INSERT, UPDATE, DELETE ON public.taste_matches FROM authenticated;

-- -----------------------------------------------------------------------------
-- 6. OWN-ROW TABLES
-- -----------------------------------------------------------------------------
CREATE POLICY user_dropped_shows_select ON public.user_dropped_shows FOR SELECT TO authenticated
    USING (public.can_view_user(user_id));
CREATE POLICY user_dropped_shows_write ON public.user_dropped_shows FOR ALL TO authenticated
    USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY user_watchlist_own ON public.user_watchlist FOR ALL TO authenticated
    USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY user_streaming_subscriptions_own ON public.user_streaming_subscriptions FOR ALL TO authenticated
    USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY user_muted_titles_own ON public.user_muted_titles FOR ALL TO authenticated
    USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY user_external_accounts_own ON public.user_external_accounts FOR ALL TO authenticated
    USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY user_blocks_own ON public.user_blocks FOR ALL TO authenticated
    USING (blocker_id = auth.uid()) WITH CHECK (blocker_id = auth.uid());

-- -----------------------------------------------------------------------------
-- 7. SOCIAL FOLLOWS — no FOR ALL policy; status is server-controlled
-- -----------------------------------------------------------------------------
CREATE POLICY social_follows_select ON public.social_follows FOR SELECT TO authenticated
    USING (
        follower_id = auth.uid()
        OR following_id = auth.uid()
        OR (status = 'accepted' AND public.can_view_user(follower_id) AND public.can_view_user(following_id))
    );
CREATE POLICY social_follows_insert ON public.social_follows FOR INSERT TO authenticated
    WITH CHECK (follower_id = auth.uid());
CREATE POLICY social_follows_respond ON public.social_follows FOR UPDATE TO authenticated
    USING (following_id = auth.uid()) WITH CHECK (following_id = auth.uid());
CREATE POLICY social_follows_delete ON public.social_follows FOR DELETE TO authenticated
    USING (follower_id = auth.uid() OR following_id = auth.uid());

REVOKE UPDATE ON public.social_follows FROM authenticated;
GRANT UPDATE (status) ON public.social_follows TO authenticated;

-- Status on INSERT is decided by the server, never the client (Spec 02 §2.4).
CREATE OR REPLACE FUNCTION public.social_follows_set_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_mode public.visibility_mode_enum;
BEGIN
    IF public.is_blocked_between(NEW.follower_id, NEW.following_id) THEN
        RAISE EXCEPTION 'follow not permitted' USING ERRCODE = '42501';
    END IF;

    SELECT visibility_mode INTO v_mode FROM public.users WHERE id = NEW.following_id AND NOT is_deleted;
    IF v_mode IS NULL OR v_mode = 'GHOST' THEN
        RAISE EXCEPTION 'user not found' USING ERRCODE = 'P0002';
    END IF;

    NEW.status := CASE WHEN v_mode = 'PUBLIC' THEN 'accepted' ELSE 'pending' END::public.follow_status_enum;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_social_follows_set_status
    BEFORE INSERT ON public.social_follows
    FOR EACH ROW EXECUTE FUNCTION public.social_follows_set_status();

-- -----------------------------------------------------------------------------
-- 8. SQUADS — members only
-- -----------------------------------------------------------------------------
CREATE POLICY squads_select ON public.squads FOR SELECT TO authenticated
    USING (public.is_squad_member(id) OR created_by = auth.uid());
CREATE POLICY squads_insert ON public.squads FOR INSERT TO authenticated
    WITH CHECK (created_by = auth.uid());
CREATE POLICY squads_update ON public.squads FOR UPDATE TO authenticated
    USING (public.is_squad_member(id, ARRAY['OWNER', 'ADMIN'])) WITH CHECK (TRUE);
CREATE POLICY squads_delete ON public.squads FOR DELETE TO authenticated
    USING (public.is_squad_member(id, ARRAY['OWNER']));

CREATE POLICY squad_members_select ON public.squad_members FOR SELECT TO authenticated
    USING (public.is_squad_member(squad_id));
CREATE POLICY squad_members_insert ON public.squad_members FOR INSERT TO authenticated
    WITH CHECK (public.is_squad_member(squad_id, ARRAY['OWNER', 'ADMIN']) AND role <> 'OWNER');
CREATE POLICY squad_members_delete ON public.squad_members FOR DELETE TO authenticated
    USING (user_id = auth.uid() OR public.is_squad_member(squad_id, ARRAY['OWNER', 'ADMIN']));

-- The creator becomes OWNER automatically.
CREATE OR REPLACE FUNCTION public.squads_add_owner()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.squad_members (squad_id, user_id, role) VALUES (NEW.id, NEW.created_by, 'OWNER');
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_squads_add_owner
    AFTER INSERT ON public.squads
    FOR EACH ROW EXECUTE FUNCTION public.squads_add_owner();

-- -----------------------------------------------------------------------------
-- 9. FEED, REACTIONS, COMMENTS, REPORTS
-- -----------------------------------------------------------------------------
CREATE POLICY activity_logs_select ON public.activity_logs FOR SELECT TO authenticated
    USING (public.can_view_user(user_id));
REVOKE INSERT, UPDATE, DELETE ON public.activity_logs FROM authenticated;

CREATE POLICY feed_reactions_select ON public.feed_reactions FOR SELECT TO authenticated
    USING (public.can_view_activity(activity_id) AND public.can_view_user(user_id));
CREATE POLICY feed_reactions_insert ON public.feed_reactions FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid() AND public.can_view_activity(activity_id));
CREATE POLICY feed_reactions_delete ON public.feed_reactions FOR DELETE TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY comments_select ON public.comments FOR SELECT TO authenticated
    USING (NOT is_hidden AND public.can_view_activity(activity_id) AND public.can_view_user(user_id));
CREATE POLICY comments_insert ON public.comments FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid() AND public.can_view_activity(activity_id));
CREATE POLICY comments_update ON public.comments FOR UPDATE TO authenticated
    USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY comments_delete ON public.comments FOR DELETE TO authenticated
    USING (user_id = auth.uid());
REVOKE UPDATE ON public.comments FROM authenticated;
GRANT UPDATE (body, contains_spoilers) ON public.comments TO authenticated;

CREATE POLICY reports_insert ON public.reports FOR INSERT TO authenticated
    WITH CHECK (reporter_id = auth.uid());
REVOKE SELECT, UPDATE, DELETE ON public.reports FROM authenticated;
