-- Migration 20261010002700_header_art.sql
-- #148 (epic #50): custom canon header art, the level 30 reward (Spec 10 §5.2). You pick a still
-- from your God tier (a title you rank 9.20+); it shows behind your profile header for anyone who
-- can see your profile. Alternate app icons (level 20) are device-side and need no schema.

-- The chosen title rides on the header_art choice row. Titles are keyed (id, media_type).
ALTER TABLE public.user_reward_choices
    ADD COLUMN title_id INT,
    ADD COLUMN media_type public.media_type_enum,
    ADD CONSTRAINT fk_user_reward_choices_title FOREIGN KEY (title_id, media_type)
        REFERENCES public.titles(id, media_type) ON DELETE SET NULL,
    ADD CONSTRAINT chk_user_reward_choices_title CHECK ((title_id IS NULL) = (media_type IS NULL));

-- Sets (or replaces) my header art. The title must be in my God tier and have a backdrop.
CREATE OR REPLACE FUNCTION public.set_header_art(p_title_id INT, p_media_type public.media_type_enum)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := public._require_user();
    v_r public.rewards;
BEGIN
    SELECT * INTO v_r FROM public.rewards WHERE kind = 'header_art' AND active ORDER BY sort LIMIT 1;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'header art is not available' USING ERRCODE = '22023';
    END IF;
    IF public._level_for_xp(public._total_xp(v_user)) < v_r.level_required THEN
        RAISE EXCEPTION 'header art unlocks at level %', v_r.level_required USING ERRCODE = '22023';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.user_rankings ur
        JOIN public.titles t ON t.id = ur.title_id AND t.media_type = ur.media_type
        WHERE ur.user_id = v_user AND ur.title_id = p_title_id AND ur.media_type = p_media_type
          AND ur.calculated_score >= 9.20 AND t.backdrop_path IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'header art must be a title in your God tier' USING ERRCODE = '22023';
    END IF;
    INSERT INTO public.user_reward_choices (user_id, kind, reward_id, title_id, media_type)
    VALUES (v_user, 'header_art', v_r.id, p_title_id, p_media_type)
    ON CONFLICT (user_id, kind) DO UPDATE
        SET reward_id = EXCLUDED.reward_id, title_id = EXCLUDED.title_id, media_type = EXCLUDED.media_type,
            equipped_at = NOW();
END;
$$;

-- The header art on [p_user]'s profile, if they have one and I can see their profile.
CREATE OR REPLACE FUNCTION public.header_art(p_user UUID)
RETURNS TABLE (title_id INT, media_type public.media_type_enum, title VARCHAR, backdrop_path TEXT)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    PERFORM public._require_user();
    IF NOT public.can_view_user(p_user) THEN
        RETURN;
    END IF;
    RETURN QUERY
    SELECT t.id, t.media_type, t.title, t.backdrop_path
    FROM public.user_reward_choices c
    JOIN public.titles t ON t.id = c.title_id AND t.media_type = c.media_type
    JOIN public.users u ON u.id = c.user_id AND NOT u.is_deleted
    WHERE c.user_id = p_user AND c.kind = 'header_art' AND t.backdrop_path IS NOT NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.set_header_art(INT, public.media_type_enum) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.header_art(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_header_art(INT, public.media_type_enum) TO authenticated;
GRANT EXECUTE ON FUNCTION public.header_art(UUID) TO authenticated;
