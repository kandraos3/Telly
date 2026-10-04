-- =============================================================================
-- FE-608: profile lookup by handle + avatar storage.
--
-- lookup_profile_card: `users` RLS hides FRIENDS_ONLY profiles from non-followers, which
-- also hid the id needed to send them a follow request. The card exposes only what a
-- follow button needs (id, handle, name, avatar, visibility); bio and the pinned showcase
-- are returned only when can_view_user() allows. GHOST, deleted and blocked users stay
-- invisible.
--
-- avatars bucket: public read; each user writes only under `<uid>/` (Edit Profile).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.lookup_profile_card(p_handle TEXT)
RETURNS TABLE (
    id UUID,
    username VARCHAR,
    display_name VARCHAR,
    avatar_url TEXT,
    bio VARCHAR,
    visibility_mode public.visibility_mode_enum,
    pinned_showcase JSONB,
    can_view BOOLEAN
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT u.id, u.username, u.display_name, u.avatar_url,
           CASE WHEN public.can_view_user(u.id) THEN u.bio END,
           u.visibility_mode,
           CASE WHEN public.can_view_user(u.id) THEN u.pinned_showcase ELSE '[]'::jsonb END,
           public.can_view_user(u.id)
    FROM public.users u
    WHERE auth.uid() IS NOT NULL
      AND u.username = lower(p_handle)
      AND NOT u.is_deleted
      AND (u.visibility_mode <> 'GHOST' OR u.id = auth.uid())
      AND NOT public.is_blocked_between(u.id, auth.uid());
$$;

REVOKE ALL ON FUNCTION public.lookup_profile_card(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lookup_profile_card(TEXT) TO authenticated;

-- Avatars ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', TRUE, 2097152, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS avatars_public_read ON storage.objects;
DROP POLICY IF EXISTS avatars_own_insert ON storage.objects;
DROP POLICY IF EXISTS avatars_own_update ON storage.objects;
DROP POLICY IF EXISTS avatars_own_delete ON storage.objects;

CREATE POLICY avatars_public_read ON storage.objects FOR SELECT
    USING (bucket_id = 'avatars');
CREATE POLICY avatars_own_insert ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::TEXT);
CREATE POLICY avatars_own_update ON storage.objects FOR UPDATE TO authenticated
    USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::TEXT)
    WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::TEXT);
CREATE POLICY avatars_own_delete ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::TEXT);
