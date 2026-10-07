-- Migration 20261010001900_duel_placed_title.sql
-- #150 (epic #50): only the title being placed qualifies from a duel (Spec 10 §2).
--
-- Binary insertion duels the new title against titles already in the canon. Under the
-- either-side rule from 20261010001800, an imported title qualified as soon as it was used
-- as an opponent, so imports could feed medal counts. pairwise_duels gains placed_title_id:
-- the title whose placement produced the duel. qualifying_rankings now credits only that
-- title. NULL keeps the either-side rule: legacy rows, older apps, and onboarding
-- tournament duels, where both titles are new and both are being placed.
--
-- Backward compatible: record_pairwise_duels keeps its signature (JSONB) and the new
-- `placed_title_id` key is optional; the view keeps its columns.

ALTER TABLE public.pairwise_duels
    ADD COLUMN placed_title_id INT,
    ADD CONSTRAINT chk_pairwise_duels_placed_title
        CHECK (placed_title_id IS NULL OR placed_title_id IN (winner_title_id, loser_title_id));

CREATE OR REPLACE VIEW public.qualifying_rankings
WITH (security_invoker = true) AS
SELECT r.user_id, r.title_id, r.media_type, r.created_at
FROM public.user_rankings r
WHERE r.status = 'COMPLETED'
  AND (
      EXISTS (
          SELECT 1 FROM public.pairwise_duels d
          WHERE d.user_id = r.user_id
            AND d.media_type = r.media_type
            AND (
                d.placed_title_id = r.title_id
                OR (d.placed_title_id IS NULL AND r.title_id IN (d.winner_title_id, d.loser_title_id))
            )
      )
      OR NOT EXISTS (
          SELECT 1 FROM public.user_rankings e
          WHERE e.user_id = r.user_id
            AND e.media_type = r.media_type
            AND (e.created_at, e.id) < (r.created_at, r.id)
      )
  );

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
            user_id, winner_title_id, loser_title_id, media_type, is_upset, decision_time_ms,
            client_mutation_id, placed_title_id
        ) VALUES (
            v_user, v_winner, v_loser, v_media, v_upset.is_upset,
            (v_duel ->> 'decision_time_ms')::INT, (v_duel ->> 'client_mutation_id')::UUID,
            (v_duel ->> 'placed_title_id')::INT
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

REVOKE ALL ON FUNCTION public.record_pairwise_duels(JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_pairwise_duels(JSONB) TO authenticated;
