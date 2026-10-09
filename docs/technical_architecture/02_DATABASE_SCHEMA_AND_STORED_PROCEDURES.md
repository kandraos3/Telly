# Technical Architecture Spec 02: Database Schemas, Stored Procedures & Caching

> **Single source of truth.** The *executable* schema lives exclusively in [`supabase/migrations/`](../../supabase/migrations/) and is verified by the pgTAP suite in [`supabase/tests/`](../../supabase/tests/). This document is the normative **contract** for that schema: names, keys, enums, invariants, security rules and RPC signatures. Any change to a migration must keep this document in sync (and vice versa). Older SQL listings in feature specs are illustrative only.

## 1. Overview & Data Architecture Principles
The data tier of **Telly** must handle two distinct workloads:
1. **High-Integrity Relational Writes (ACID):** Maintaining strictly ordered user canons where inserting or moving a title at rank #4 requires an atomic shift of all subsequent rows and score recalculations.
2. **Low Read Latency:** Delivering activity feeds, mutual Taste Match % calculations, and streaming availability at scale without slowing down the mobile interface.

We achieve this using **PostgreSQL (via Supabase)** for persistent relational state. Redis caching (§5) is deferred until feed volume requires it.

### 1.1 Global Invariants
| # | Invariant |
| :---: | :--- |
| I-1 | **Dual-Canon partition.** `media_type_enum` has exactly two values: `'movie'` and `'tv'` (anime series are `'tv'` with `is_anime = TRUE`; anime films are `'movie'`). Every ranking query, RPC and score computation is scoped by `(user_id, media_type)`. A movie never duels a TV title. |
| I-2 | **Composite title key.** TMDB IDs collide across movies and TV, so every title reference is the pair `(title_id, media_type)` referencing `titles(id, media_type)`. |
| I-3 | **Contiguous canon.** For each `(user_id, media_type)`, `rank_position` is exactly the permutation `1..N`. Enforced by RPCs plus `UNIQUE (user_id, media_type, rank_position) DEFERRABLE INITIALLY DEFERRED`. |
| I-4 | **Server derives identity.** Every client-callable RPC derives the acting user from `auth.uid()`; no RPC accepts a caller-supplied user ID for writes. |
| I-5 | **Idempotent offline replay.** Mutations sent from the client offline queue carry a `client_mutation_id UUID`, recorded in `applied_mutations` (duels also store it on `pairwise_duels`); replaying an already-applied ID is a no-op. A per-row column would not work: a later move would overwrite it, so replaying the earlier mutation would undo the move. |
| I-6 | **RLS everywhere.** Row-Level Security is enabled on every table in `public`. |

---

## 2. Canonical Schema Contract

### 2.1 Enumerated Types
| Type | Values |
| :--- | :--- |
| `media_type_enum` | `movie`, `tv` |
| `watch_status_enum` | `COMPLETED`, `WATCHING`, `DROPPED` |
| `finale_impact_enum` | `FLAWLESS_LANDING`, `SATISFYING_FINISH`, `FUMBLED_BAG`, `CANCELLED_TOO_SOON`, `STILL_AIRING` |
| `viewing_venue_enum` | `HOME`, `THEATER`, `IMAX`, `OTHER` (Dart `ViewingVenue.dbValue`) |
| `drop_reason_enum` | `PACING_SLOWED`, `WRITING_JUMPED_SHARK`, `CAST_DEPARTURE`, `TOO_DARK_DEPRESSING`, `TIME_COMMITMENT`, `BETTER_OPTIONS` |
| `reaction_type_enum` | `FIRE`, `MIND_BLOWN`, `TRASH`, `HEARTBREAK`, `TASTE_TWIN` |
| `follow_status_enum` | `pending`, `accepted`, `rejected` |
| `visibility_mode_enum` | `PUBLIC`, `FRIENDS_ONLY`, `GHOST` |
| `report_reason_enum` | `UNMARKED_SPOILER`, `HARASSMENT`, `SPAM`, `INACCURATE_METADATA` |
| `report_target_enum` | `COMMENT`, `ACTIVITY`, `RANKING`, `USER` |
| `tracking_state_enum` | `WATCHING`, `CAUGHT_UP`, `FINISHED` (epic #168, [features/11](../features/11_WATCH_TRACKING_AND_EPISODE_PROGRESS.md) §2.2) |

### 2.2 Tables
Abbreviations: **PK** primary key, **FK** foreign key, **U** unique. All `updated_at` columns are maintained by the shared `set_updated_at()` trigger.

| Table | Key columns & constraints | Purpose |
| :--- | :--- | :--- |
| `users` | **PK** `id` → `auth.users(id)` ON DELETE CASCADE; `username` VARCHAR(20) **U**, nullable until claimed, `CHECK (username ~ '^[a-z0-9_]{3,20}$')`; `display_name`, `avatar_url`, `bio` VARCHAR(160), `visibility_mode` (default `PUBLIC`), `pinned_showcase` JSONB `[{title_id, media_type}]` (max 3), `preferences` JSONB, `onboarding_completed` BOOL, `is_deleted` BOOL, `deletion_requested_at`, `timezone` TEXT (IANA, default `UTC`; written only by `set_timezone`), `share_achievements` BOOL (default true; client-writable), `created_at`, `updated_at` | Public profile. A skeleton row is created by the `on_auth_user_created` trigger. |
| `titles` | **PK** `(id, media_type)`; `title`, `original_title`, `release_date`, `last_air_date`, `status`, `poster_path`, `backdrop_path`, `overview`, `genres` TEXT[], `original_network`, `number_of_seasons`, `number_of_episodes`, `runtime_minutes`, `director`, `is_anime`, `anilist_id`, `mal_id`, `anime_studio`, `source_material`, `popularity` NUMERIC, `global_community_score` NUMERIC(4,2), `streaming_services` JSONB, `collection_id` INT, `production_companies` TEXT[], `tv_type` VARCHAR(30), `metadata_version` SMALLINT (2 once stored with the #140 fields), `tmdb_vote_average` NUMERIC(3,1), `tmdb_vote_count` INT (#46), `created_at`, `updated_at` | TMDB metadata cache (written only by `service_role` / edge functions). |
| `title_collections` | **PK** `collection_id`; `name`, `poster_path`, `part_ids` INT[], `released_part_ids` INT[], `fetched_at` | TMDB `/collection/{id}` cache, refreshed weekly by `tmdb-details` (#140). A trigger keeps a gold `collection_<id>` medal in `achievements` (active with two or more released films). Read-only for clients. |
| `title_related` | **PK** `(seed_id, seed_media_type, related_id)`; **FK** both sides → `titles` (same media type); `position` SMALLINT 1–20, `fetched_at` | TMDB `/recommendations` page 1 per seed title (#46, features/07 §7.6); written by `title-related`; read-only for clients. |
| `title_related_fetches` | **PK** `(seed_id, seed_media_type)`; **FK** → `titles`; `fetched_at`, `result_count` | When each seed's recommendations were last fetched, including empty results (#177); server-only. |
| `trending_titles` | **PK** `(media_type, position)`; **FK** `(title_id, media_type)` → `titles`; `fetched_at` | TMDB `/trending/{type}/week` page 1 (#46); written by `title-related`; read-only for clients. |
| `tv_seasons` | **PK** `id`; **FK** `(title_id, media_type)` → `titles` with `CHECK (media_type = 'tv')`; **U** `(title_id, season_number)` | Season breakdown for `SCR-08`. |
| `tv_episodes` | **PK** `(title_id, season_number, episode_number)`; **FK** `(title_id, media_type)` → `titles` with `CHECK (media_type = 'tv')`; `name`, `overview`, `still_path`, `air_date`, `runtime_minutes`, `fetched_at`; season and episode ≥ 1 | TMDB episode cache for tracking (#168); written by `tmdb-season` and `tracking-refresh`; read-only for clients. |
| `streaming_platforms` | **PK** `id` (`netflix`, `max`, `hulu`, `apple_tv_plus`, `disney_plus`, `prime_video`, `crunchyroll`, `paramount_plus`, `criterion`) | Provider catalog. |
| `title_availability` | **PK** `id`; **FK** `(title_id, media_type)`, `platform_id`; `country_code`, `monetization_type`, `deep_link_url`, `available_until`, `is_leaving_soon`; **U** `(title_id, media_type, platform_id, country_code, monetization_type)` | Streaming availability cache. |
| `user_streaming_subscriptions` | **PK** `(user_id, platform_id)` | Household services (`SCR-02`). |
| `user_rankings` | **PK** `id`; **FK** `(title_id, media_type)`; `user_id`; `rank_position` INT ≥ 1; `calculated_score` NUMERIC(4,2); `rating_uncertainty` NUMERIC(3,2) (σ); `status`, `finale_impact`, `favorite_character`, `review_short` VARCHAR(280), `tags` TEXT[], `watched_with_user_ids` UUID[], `audio_language`, `is_rewatch`, `rewatch_count`, `venue`; **U** `(user_id, title_id, media_type)`; **U** `(user_id, media_type, rank_position)` DEFERRABLE INITIALLY DEFERRED | The personal Dual-Canon. |
| `applied_mutations` | **PK** `client_mutation_id`; `user_id`, `kind`, `applied_at` | Idempotency log for offline replay (I-5); server-internal, no client access. |
| `pairwise_duels` | **PK** `id`; `user_id`; `winner_title_id`, `loser_title_id`, `media_type` (both FKs share it); `is_upset`, `decision_time_ms`, `client_mutation_id` UUID **U**, `placed_title_id` INT NULL (the title whose placement produced the duel; `CHECK` it is the winner or the loser; NULL for tournament and legacy duels); `CHECK (winner_title_id <> loser_title_id)` | Audit log powering upsets and win-rates. |
| `user_external_accounts` | **PK** `id`; **U** `(user_id, service_name)` | Letterboxd / AniList / MAL links. |
| `user_dropped_shows` | **PK** `id`; **FK** `(title_id, media_type)`; `dropped_at_season`, `dropped_at_episode`, `reason`, `willing_to_revisit`, `notify_on_acclaim`, `notes`; **U** `(user_id, title_id, media_type)` | TV Graveyard (`SCR-18`). |
| `user_watchlist` | **PK** `(user_id, title_id, media_type)`; `priority`, `recommended_by_user_id`, `added_at` | Smart Queue (`SCR-13`). |
| `user_tracking` | **PK** `(user_id, title_id, media_type)`; **FK** → `titles`; `last_season`, `last_episode` (both NULL or both ≥ 1; NULL for movies), `state tracking_state_enum`, `is_rewatch`, `new_episodes_since`, `started_at`, `last_progress_at`, `finished_at`, `updated_at` | Watch tracking: one place per title (#168, features/11 §6.1). Own rows readable; written only by the tracking RPCs. |
| `user_tracking_events` | **PK** `id`; **FK** `(title_id, media_type)` → `titles`; `user_id`, `kind` (`WATCHED`, `UNWATCHED`, `REWATCHED`, `FINISHED`), `season_number`, `episode_number`, `created_at` | Append-only episode events for tracking stats (features/11 §3.6). Own rows readable; written only by the tracking RPCs. |
| `user_muted_titles` | **PK** `(user_id, title_id, media_type)` | Spoiler Shield mutes. |
| `user_dismissed_recommendations` | **PK** `(user_id, title_id, media_type)`; **FK** → `titles`; `dismissed_at`; own rows only | Explore's "Not for me" (#189, decision 0008); excluded by `get_explore_candidates`, not by the feed. |
| `social_follows` | **PK** `(follower_id, following_id)`; `status follow_status_enum`; `CHECK (follower_id <> following_id)` | The only social-graph table (`friendships` is removed). |
| `user_blocks` | **PK** `(blocker_id, blocked_id)` | Blocks hide content in both directions. |
| `taste_matches` | **PK** `(user_a, user_b, media_type)`; `CHECK (user_a < user_b)`; `match_percentage`, `mutual_count` | Cached Taste Match per canon. |
| `squads` / `squad_members` | `squads`: **PK** `id`, `name`, `description`, `avatar_url`, `created_by`; `squad_members`: **PK** `(squad_id, user_id)`, `role` (`OWNER`/`ADMIN`/`MEMBER`), `joined_at` | Squads (`SCR-17`). |
| `activity_logs` | **PK** `id`; `user_id`; `activity_type` (`RANKING_CREATED`, `UPSET_ALERT`, `SHOW_DROPPED`, `QUEUE_ADDED`, `COMMENT_POSTED`, `MEDAL_UNLOCKED`, `CHALLENGE_COMPLETED`, `WATCH_STARTED`, `WATCH_FINISHED` (#168; no episode in `metadata`)); `title_id`, `media_type`, `ranking_id`, `target_user_id`, `is_upset`, `upset_delta`, `metadata` JSONB, `created_at` | Feed source. |
| `feed_reactions` | **PK** `id`; **FK** `activity_id`; **U** `(activity_id, user_id, reaction_type)` | Reactions. |
| `comments` | **PK** `id`; **FK** `activity_id`; `user_id`; `body` VARCHAR(500); `contains_spoilers`; `is_hidden` | Spoiler-safe threads (`SCR-06`). |
| `curated_canons` | *Dropped (#46, decision 0007).* | Editorial collections replaced by Explore's rows. |
| `qualifying_rankings` (view) | `(user_id, title_id, media_type, created_at)`; `security_invoker` | Gamification's anti-gaming rule (features/10 §2): `COMPLETED` rankings that were placed through a duel in their canon (`placed_title_id`, or either side when it is NULL), or were first in it. |
| `achievements` | **PK** `id` TEXT slug; `kind`, `tier` (enums), `name`, `description`, `glyph` VARCHAR(4), `media_type`, `threshold`, `collection_id`, `challenge_id`, `sort`, `active` | Medal catalogue (features/10 §4.1); read-only for clients. |
| `user_achievements` | **PK** `(user_id, achievement_id)`; `unlocked_at`, `seen_at`, `pinned_slot` 1–3 with **U** `(user_id, pinned_slot)` | Unlocks and pins; readable where the profile is visible; written only by RPCs and triggers. |
| `achievement_rarity` | **PK** `achievement_id`; `holders`, `active_users`, `percent`, `computed_at` | Nightly rarity (features/10 §4.3). |
| `challenges` | **PK** `id`; `slug` **U** (`^[a-z0-9-]+$`, ≤ 50), `name`, `description`, `art`, `medal_glyph`, `starts_at`, `ends_at` (NULL = open-ended), `rule` JSONB (`CHECK _valid_challenge_rule`), `target`, `squad_id` (squad challenges), `featured` (one at a time: overlapping windows are un-featured), `template_key`, `status` (`draft`/`live`), `created_by` | Challenges (features/10 §8, #142). Readable when live and public, or to the squad's members. A trigger keeps a gold `challenge_<slug>` medal. |
| `challenge_participants` | **PK** `(challenge_id, user_id)`; `joined_at`, `completed_at` | Readable where both the profile and the challenge are visible; written by RPCs and triggers (squad members join automatically). |
| `challenge_calendar` | **PK** `slug`; `month` (1st of month), `template_key` → `challenge_templates`, `name`, `description`, `params` JSONB, `target`, `featured`, `art`, `medal_glyph` | Published copy of `content/challenge_calendar.yaml` (#143); server-only. |
| `challenge_templates` | **PK** `key`; `name`, `description` (`$target`, `$<param>` placeholders), `art`, `medal_glyph`, `rule` (`"$<param>"` placeholders), `params` TEXT[], `target`, `active`, `sort` | Templates for squad challenges; published from `content/challenge_templates/` (#143). |
| `xp_ledger` | **PK** `id`; `user_id`, `amount` (> 0 except corrections), `source` (`ranking`, `quest`, `streak`, `medal`, `collection`, `challenge`, `referral`, `correction`), `ref`, `week` (`2026-W41`), `created_at`; **U** `(user_id, source, ref)` | Append-only XP (features/10 §6, #145): own rows readable; written only by `_award_xp` and service-role corrections; updates raise. |
| `quest_templates` / `user_quests` | templates: **PK** `key`; `title`, `difficulty` (`easy`/`explore`/`queue`), `kind` (`rule`/`finish_from_queue`), `rule`, `param`, `target`, `xp`. Assigned: **PK** `(user_id, week, slot)`; resolved `title`, `rule`, `target`, `xp`, `completed_at` | Weekly quests (§9.8); own rows readable. |
| `rewards` / `user_reward_choices` | rewards: **PK** `id`; `name`, `kind` (`frame`, `card_style`, `canon_decoration`, `app_icon`, `header_art`), `level_required`. Choices: **PK** `(user_id, kind)`, `reward_id`, `title_id` + `media_type` (header art only, **FK** titles) | Cosmetic rewards (§5.2); choices readable where the profile is. |
| `reports` | **PK** `id`; `reporter_id`; `target_type`, `target_id` TEXT, `reason`, `notes`, `status` (`OPEN`/`ACTIONED`/`DISMISSED`), `created_at` | Apple 1.2 moderation queue. |

### 2.3 Indexes
- `user_rankings (user_id, media_type, rank_position)` — canon reads.
- `user_rankings (title_id, media_type)` — friends-who-ranked, taste match joins.
- `user_rankings (user_id, media_type, created_at, id)` — first-in-canon check for `qualifying_rankings`.
- `pairwise_duels (winner_title_id, loser_title_id, media_type)`, `pairwise_duels (user_id, media_type)`.
- `titles USING GIN (title gin_trgm_ops)`, `titles USING GIN (genres)`.
- `social_follows (following_id, status)`, `activity_logs (user_id, created_at DESC)`, `activity_logs (created_at DESC)`.

### 2.4 Row-Level Security Model
`can_view_user(target UUID) → BOOLEAN` (SECURITY DEFINER, STABLE) is TRUE when **any** holds and no `user_blocks` row exists in either direction:
1. `target = auth.uid()`;
2. target is `PUBLIC` and not deleted;
3. target is `FRIENDS_ONLY` and the caller has an `accepted` follow of the target.

`GHOST` users are visible only to themselves.

| Table | SELECT | INSERT / UPDATE / DELETE |
| :--- | :--- | :--- |
| `users` | `can_view_user(id)` | UPDATE own row only |
| `titles`, `tv_seasons`, `tv_episodes`, `streaming_platforms`, `title_availability`, `curated_canons` | any `authenticated` | `service_role` only |
| `user_rankings`, `user_dropped_shows`, `activity_logs`, `pairwise_duels` | `can_view_user(user_id)` | own rows only (rankings via RPC) |
| `user_watchlist`, `user_streaming_subscriptions`, `user_muted_titles`, `user_blocks`, `user_external_accounts` | own rows | own rows |
| `social_follows` | either party, or `accepted` rows where `can_view_user` holds for both | INSERT only as `follower_id = auth.uid()` (status forced by trigger: `pending` for non-`PUBLIC` targets, else `accepted`); UPDATE status only by `following_id`; DELETE by either party |
| `user_tracking`, `user_tracking_events` | own rows | none for clients: tracking RPCs only (§3.6) |
| `comments`, `feed_reactions` | visible when the parent activity is visible | own rows |
| `squads`, `squad_members` | members only | owner/admin manage membership; users may leave |
| `reports` | none (back-office only) | INSERT own |

---

## 3. Stored Procedures (RPC Contracts)

### 3.1 Dynamic Score Curve (shared with Dart `ScoreCurveCalculator`)
For a canon of size $N$ and rank $r$:
- $N = 1 \Rightarrow 10.00$.
- Otherwise $p = \frac{N - r}{N - 1}$, $\text{raw} = 1 + 9p^{0.82}$.
- If $N < 10$: $\alpha = N/10$, $\text{prior} = \max(1, 10 - 0.5(r-1))$, $\text{score} = \alpha\cdot\text{raw} + (1-\alpha)\cdot\text{prior}$.
- Round to 2 decimals. Dart and SQL must match the shared fixture `test/fixtures/score_curve_vectors.json`.

### 3.2 Ranking Mutations
All of the following are `SECURITY DEFINER`, `SET search_path = public`. They take `pg_advisory_xact_lock` on `(auth.uid(), media_type)`, preserve **I-3**, recompute every score in the affected canon (§3.1), and honour **I-5**.

| RPC | Behaviour |
| :--- | :--- |
| `insert_user_ranking_atomic(p_title_id, p_media_type, p_target_rank, p_status, p_finale_impact, p_review, p_tags, p_character, p_is_rewatch, p_venue, p_audio_language, p_client_mutation_id) → user_rankings` | Inserts at `p_target_rank` (clamped to `1..N+1`) and shifts the rows below it. If the title is already ranked, it **moves** it: closes the old gap, then opens the new one. First title in a canon gets σ = 0.50 (features/02 §7.3), otherwise σ = 1.20. |
| `move_user_ranking(p_title_id, p_media_type, p_new_rank, p_client_mutation_id)` | Drag-and-drop re-index. |
| `delete_user_ranking(p_title_id, p_media_type, p_client_mutation_id)` | Removes the row and closes the gap. |
| `record_pairwise_duels(p_duels JSONB)` | Batch insert of `{client_mutation_id, winner_title_id, loser_title_id, media_type, decision_time_ms, placed_title_id?}` (`placed_title_id` optional, #150); sets `is_upset` via `detect_upset_duel`; emits `UPSET_ALERT` activity for upsets. |

### 3.3 Read & Social RPCs
| RPC | Behaviour |
| :--- | :--- |
| `check_handle_available(p_handle TEXT) → BOOLEAN` | Format regex + reserved list + uniqueness (case-insensitive). |
| `calculate_taste_match_rpc(p_other UUID, p_media_type) → (match_pct INT, mutual_count INT)` | Spearman ρ over mutual titles **within one canon**: re-rank both users' mutual titles $1..k$, $\rho = 1 - \frac{6\sum d^2}{k(k^2-1)}$, shrink $w = k/(k+5)$, $\text{match} = \text{round}(\frac{w\rho + 1}{2}\cdot 100)$; $k < 2 \Rightarrow 50$. Requires `can_view_user(p_other)`. |
| `detect_upset_duel(p_winner, p_loser, p_media_type) → (is_upset, winner_consensus, loser_consensus, delta)` | Features/04 §3.2: $\mu$ = mean global percentile $\frac{N-r}{N-1}$ of the title across **other** users' canons (0.5 with no data; a one-title canon counts as 1.0). Upset iff $\mu(\text{loser}) - \mu(\text{winner}) \ge 0.25$. |
| `get_activity_feed(p_filter TEXT, p_before TIMESTAMPTZ, p_limit INT, p_before_id UUID, p_include_medals BOOLEAN DEFAULT FALSE, p_include_challenges BOOLEAN DEFAULT FALSE, p_include_tracking BOOLEAN DEFAULT FALSE)` | `following` / `squads` / `global`; `MEDAL_UNLOCKED` rows only when `p_include_medals` (#136), `CHALLENGE_COMPLETED` only when `p_include_challenges` (#142), `WATCH_STARTED` / `WATCH_FINISHED` only when `p_include_tracking` (#226); `challenge_context` JSONB `{slug, name, count, target}` on rankings made inside a challenge the poster joined (#144); keyset-paginated on `(created_at, id)`; SECURITY INVOKER so RLS filters rows; excludes the caller's muted titles; joins the current rank/score live (for rows without `ranking_id`, the poster's ranking of the title). Card fields: `release_year`, `tags`, `upset_over_title` / `upset_over_rank` (duel loser from `metadata.loser_title_id`), `reaction_counts`, `my_reactions`, `comment_count` (non-hidden), `in_my_queue` (FE-607). |
| `calculate_squad_canon(p_squad_id, p_media_type)` | Borda count: member $i$ with $N_i$ titles awards $N_i - r + 1$ points. Members only. |
| `request_account_deletion()` / `cancel_account_deletion()` / `purge_deleted_accounts()` | 30-day grace period (Trust & Safety §4.1); purge is scheduled with `pg_cron` and only executable by `service_role`. |
| `submit_report(p_target_type, p_target_id, p_reason, p_notes)` / `block_user(p_user)` | Moderation. |
| `get_network_battlegrounds(p_media_type, p_min_rankings, p_limit)` | Average score per `original_network` across all non-deleted users (aggregate only). |
| `get_explore_candidates(p_media_type) → JSONB` | #46, features/07 §7.3. One canon's ranking profile (rankings with genres, top-5 seeds ≥ 7.80, my services, seeds missing related rows) and up to 200 candidates from my seeds' `title_related`, `trending_titles`, Telly's 14-day rankings, followees' last 30 days, leaving-soon on my services, and a quality pool; each with genres, seed links, trending rank, friends (score, taste match), providers, leaving date and `in_queue`. Excludes my ranked, muted and dismissed titles. Ranking happens in the app (`ExploreRanker`). |
| `store_title_related(p_seed_id, p_media_type, p_related JSONB) → INT` / `store_trending(p_media_type, p_title_ids INT[]) → INT` / `stale_explore_seeds(p_max_age_days, p_limit)` | #177, features/07 §7.6. `service_role` only: atomic replace of a seed's related rows (logging the fetch) or a canon's trending list, and the seeds due for a refetch for pg_cron `explore-refresh`. |
| `get_recommended_titles(p_media_type, p_limit)` / `get_trending_titles(p_media_type, p_limit)` | FE-EXPLORE-03; **dropped** in #191, replaced by `get_explore_candidates`. |
| `get_friends_binging(p_limit, p_days)` | Titles accepted followees ranked or queued recently; SECURITY INVOKER (RLS applies). |
| `get_title_social_summary(p_title_id, p_media_type) → JSONB` | `SCR-08`: my rank/score/σ, visible followees who ranked it, community average, survival rate (completed / watching / dropped, most common drop point). |
| `stale_watchlist_titles(p_older_than_hours, p_limit)` / `refresh_leaving_soon_flags(p_today)` | `service_role` only; used by the `streaming-catalog-sync` edge function and a daily `pg_cron` job. |
| `set_timezone(p_timezone TEXT) → TEXT` | #135. Stores the caller's IANA time zone in `users.timezone`; unknown names raise `22023`. |
| `weekly_streak(p_user UUID, p_now TIMESTAMPTZ DEFAULT NOW()) → (current_weeks, best_weeks, weeks JSONB)` | #135, features/10 §3. Monday-to-Sunday weeks in the user's time zone over `qualifying_rankings`; at most one freeze per calendar month; `weeks` is the last 7 as `[{week, starts_on, status}]`, oldest first. SECURITY INVOKER, so a hidden user reads as zero. |
| `collection_still_to_watch(p_collection_id) → (title_id, title, release_year, poster_path, in_queue)` | #141, features/10 §9.3. The collection's released films the caller hasn't ranked, in release order, with whether each is in their Queue. Authenticated only. |
| `discover_challenges()` / `my_challenges()` / `get_challenge(p_slug)` → `challenge_card` rows | #142. Card: challenge fields, `squad_name`, `participant_count`, `friend_count`, `joined`, `my_progress`, `completed_at`. Discover: live, unjoined, featured first then ending soonest. Mine: joined, live first. Ended challenges appear only to participants. |
| `join_challenge(p_challenge_id) → INT` / `leave_challenge(p_challenge_id)` | Join an open challenge (earlier rankings inside the window count, so it may complete at once; `22023` if not open); leaving keeps finished ones. |
| `challenge_progress(p_challenge_id)` / `challenge_picks(p_challenge_id, p_limit)` | Me and visible followed participants by progress; matching titles from my Queue first, then titles followees rank highest, excluding my rankings. |
| `create_squad_challenge(p_squad_id, p_template_key, p_name, p_starts_at, p_ends_at, p_params, p_target)` | Squad owners/admins only (`42501`); fills template placeholders (`22023` if any are missing); live at once; every member joins. |
| `admin_upsert_challenge(p_challenge JSONB)` / `admin_upsert_challenge_template(p_template JSONB)` | `service_role` only; upsert by slug / key; featuring one challenge un-features the rest. |
| `admin_upsert_calendar_entry(p_entry)` / `schedule_calendar_challenges(p_month DATE) → INT` / `expire_featured_challenges() → INT` | `service_role` only (#143). Publish a calendar entry; create a month's planned challenges from their templates (idempotent); clear the flag on ended featured challenges. |
| `my_level()` / `my_week()` / `my_rewards()` / `equip_reward(p_reward_id)` / `unequip_reward(p_kind)` | #145, features/10 §5–§6, §9.8. Level and XP; the week's three quests (assigned on first read) with progress; rewards with unlocked/equipped/XP to go; equipping a locked reward raises `22023`. |
| `set_header_art(p_title_id, p_media_type)` / `header_art(p_user)` | #148, features/10 §5.2. Sets my level 30 header art (a God-tier title with a backdrop, else `22023`); reads someone's header art when `can_view_user` allows. |
| `weekly_xp_table(p_squad_id DEFAULT NULL)` | This week's XP for me and the visible people I follow, or a squad's members (`42501` if not a member), with level, current streak and rank. |
| `titles_needing_details(p_limit)` / `stale_title_collections(p_max_age_days, p_limit)` | `service_role` only; feed `tmdb-details` maintenance (#140). |
| `_invoke_edge_function(p_name, p_body)` | Internal (pg_cron). POSTs to `<project_url>/functions/v1/<name>` through `pg_net` with the service-role key, both read from Vault secrets `project_url` and `service_role_key`; returns NULL with a notice while they're missing. |
| `my_achievements()` / `pin_achievement(p_achievement_id, p_slot)` / `unpin_achievement(p_slot)` / `mark_achievements_seen(p_achievement_ids TEXT[] DEFAULT NULL)` | #136, features/10 §4. The catalogue with progress, unlocks, pins, rarity and followed holders; pin slots 1–3 (locked medals `22023`). |
| `evaluate_achievements(p_user, p_broadcast DEFAULT TRUE)` / `evaluate_all_achievements()` / `refresh_achievement_rarity(p_now)` | `service_role` only. Idempotent medal unlocks (also run by `record_pairwise_duels` and statement-level triggers on rankings, drops, follows and taste matches); nightly pg_cron jobs `evaluate-achievements` and `refresh-achievement-rarity`. |
| `lookup_profile_card(p_handle TEXT) → (id, username, display_name, avatar_url, bio, visibility_mode, pinned_showcase, can_view)` | FE-608, `SCR-15`. Finds a non-deleted, non-`GHOST`, non-blocked user by handle even when `users` RLS hides them (`FRIENDS_ONLY` non-follower), so a follow request can be sent. `bio` and `pinned_showcase` are returned only when `can_view_user` holds (`'[]'` otherwise). Authenticated only. |
| `get_squad_members(p_squad_id) → (user_id, username, display_name, avatar_url, role, joined_at)` | FE-608, `SCR-17`. Members only (`42501` otherwise); shows squad-mates whose profiles RLS would hide. |
| `squad_shared_watchlist(p_squad_id) → (title_id, media_type, title, poster_path, queued_by, member_count)` | FE-608, `SCR-17`. Members only. Titles queued by at least `LEAST(2, member_count)` members, most-queued first. |

**Storage.** Bucket `avatars` (public read, ≤ 2 MB, JPEG/PNG/WebP): authenticated users may insert/update/delete only objects under `<auth.uid()>/`. Edit Profile uploads a 1:1 crop to `<uid>/avatar.jpg` (upsert) and stores its public URL in `users.avatar_url`. The Top 3 showcase is `users.pinned_showcase`: a JSON array of at most 3 `{title_id, media_type}` objects.

### 3.5 Edge Functions (Deno, `supabase/functions/`)
Each function keeps its logic in `handler.ts` (dependencies injected) with a thin `index.ts`; tests live in `supabase/functions/tests/`.

| Function | Behaviour |
| :--- | :--- |
| `tmdb-search?query=` | TMDB `/search/multi`, movie/tv only, `is_anime` heuristic (Animation + JP); upserts results into `titles` so they can be ranked immediately. |
| `tmdb-details?id=&media_type=` | TMDB details + credits; upserts `titles` + `tv_seasons` (season 0 specials skipped); returns cast, creators, director, seasons. #140: also stores `collection_id`, `production_companies`, `tv_type`, and refreshes the film's `title_collections` row when it is a week old (parts are stored as minimal `titles` rows). A POST with the service-role bearer runs maintenance: backfills titles below `metadata_version` 2 (`titles_needing_details`), then refreshes stale collections (`stale_title_collections`); pg_cron `tmdb-maintenance` calls it every 30 minutes through `_invoke_edge_function`. |
| `streaming-availability?tmdb_id=&media_type=&country=` | `title_availability` cache (< 24 h) → Watchmode (native `ios_url`/`android_url`, when `WATCHMODE_API_KEY` is set) → TMDB watch providers (JustWatch data). Provider names/ids map to `streaming_platforms.id`. |
| `challenge-scheduler` (POST, service-role bearer) | #143. `schedule_calendar_challenges` for this month and next, then `expire_featured_challenges`; pg_cron `challenge-scheduler-prepare` (25th) and `challenge-scheduler-month-start` (1st) call it through `_invoke_edge_function`. |
| `title-related` (POST) | #46, features/07 §7.6. Authenticated `{seed_ids ≤ 5, media_type}`: caches TMDB recommendations for seeds missing or older than 14 days. Service-role: refreshes `trending_titles` (older than 6 h) and up to 40 stale seeds from all users' top 5; pg_cron `explore-refresh` every 30 minutes. Upserts minimal `titles` rows with genre names from `_shared/genres.ts`, then writes through `store_title_related` / `store_trending`. Stops at a TMDB 429; logs a 404 seed as an empty fetch. |
| `streaming-catalog-sync` (POST, service-role bearer) | Refreshes stale availability for watchlisted titles, then `refresh_leaving_soon_flags()`. |
| `tmdb-season?id=&season=` | #168. Authenticated, rate-limited like `tmdb-details`. TMDB `/tv/{id}/season/{n}` → upserts `tv_episodes` (season 0 refused). |
| `tracking-refresh` (POST, service-role bearer) | #168, features/11 §6.5. Refreshes `titles`, `tv_seasons` and `tv_episodes` for up to 500 series tracked as `CAUGHT_UP` or `FINISHED` (ended shows only on Mondays), stopping at a TMDB 429 or a 100 s time budget, and always ends with `refresh_tracking_new_episodes()`. Selection comes from `tracking_shows_to_refresh` and `tracking_seasons_to_refresh` (service role only). pg_cron `tracking-refresh` at `23 5 * * *` through `_invoke_edge_function`. |

### 3.6 Watch Tracking RPCs (epic #168, [features/11](../features/11_WATCH_TRACKING_AND_EPISODE_PROGRESS.md) §6)
All write RPCs are `SECURITY DEFINER`, `SET search_path = public`. They take `p_client_mutation_id` (I-5), recompute `state` with `_tracking_state` (§3.1–§3.3 of features/11, shared vectors `test/fixtures/tracking_progress_vectors.json`), set `last_progress_at`, and return the `user_tracking` row (`stop_tracking` returns nothing). Internal helpers (`_tracking_move`, `_tracking_start`, `_episode_aired`, …) are not granted to clients.

| RPC | Behaviour |
| :--- | :--- |
| `start_tracking(p_title_id, p_media_type, p_last_season, p_last_episode, p_rewatch, p_client_mutation_id)` | Upsert; deletes the caller's `user_watchlist` row; posts `WATCH_STARTED` at most once per title per 30 days. `p_rewatch` on a `FINISHED` row resets the place and sets `is_rewatch`. |
| `set_tracking_place(p_title_id, p_media_type, p_last_season, p_last_episode, p_client_mutation_id)` | Absolute place (clamped to known episode counts); appends `WATCHED`/`UNWATCHED` events per episode passed (≤ 50); clears `new_episodes_since` on a forward move; entering `FINISHED` sets `finished_at` and posts `WATCH_FINISHED` (30-day throttle); leaving it clears `finished_at`. `P0002` when not tracked. |
| `log_episode_rewatch(p_title_id, p_season, p_episode, p_client_mutation_id)` | Appends `REWATCHED`. |
| `finish_tracking(p_title_id, p_media_type, p_client_mutation_id)` | Movie → `FINISHED` + `FINISHED` event + `WATCH_FINISHED`. Series → place = last aired episode, then as `set_tracking_place`. |
| `stop_tracking(p_title_id, p_media_type, p_client_mutation_id)` | Deletes the row; events are kept. |
| `revive_dropped_show(p_title_id, p_client_mutation_id)` | Deletes the caller's `user_dropped_shows` row and starts tracking at its drop point. |
| `get_my_tracking() → JSONB` | `{today, items[]}`, newest progress first. Each item: the `user_tracking` columns, title fields (`title`, `poster_path`, `backdrop_path`, `title_status`, `runtime_minutes`, `number_of_seasons`), and for series `seasons[]`, `watched`, `aired_total`, `next_episode` (with its cached name, still, air date and runtime) and `last_aired`; for every item `ranked`, `rank_position`, `calculated_score`. Movies carry null for the series-only fields. |
| `get_title_watchers(p_title_id, p_media_type) → (watcher_id, username, display_name, avatar_url, total_watchers)` | Up to 20 accepted-follow users visible through `can_view_user`, not `GHOST`, tracking the title in `WATCHING`. Never returns a place or state. |
| `get_tracking_stats(p_media_type, p_year)` | `episodes` (`WATCHED + REWATCHED − UNWATCHED`, ≥ 0) or `movies_finished` for the year in `users.timezone`; `p_year` NULL → this ISO week with `minutes` from cached runtimes (`tv_episodes` for TV, `titles.runtime_minutes` for movies). |
| `refresh_tracking_new_episodes() → INT` | Service role / pg_cron only. `CAUGHT_UP`/`FINISHED` series whose next episode now exists and has aired → `WATCHING`, `new_episodes_since = now()`. |

### 3.4 Triggers
- `on_auth_user_created` (AFTER INSERT ON `auth.users`) → inserts the skeleton `public.users` row.
- `set_updated_at` (BEFORE UPDATE) on every table with `updated_at`.
- `social_follows_set_status` (BEFORE INSERT) → forces `pending` / `accepted` per §2.4.
- `user_rankings_activity` (AFTER INSERT) → `RANKING_CREATED` activity row.

---

## 4. Testing Contract
Every invariant in §1.1 and every row of §2.4 has at least one pgTAP assertion in `supabase/tests/`, executed in CI with `supabase test db` (Testing Spec 06 §3.3).

---

## 5. Redis Caching Architecture (Deferred)

> **Status:** deferred to a later sprint. The feed is served directly from Postgres via `get_activity_feed` until measured latency requires caching. The key design below is retained for that work.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        REDIS DATA STRUCTURES                           │
├────────────────────────────────────────────────────────────────────────┤
│  1. Active Duel Tournament Session                                     │
│     Key: `duel_session:{user_id}:{media_type}:{title_id}`              │
│     Type: HASH (stores low_bound, high_bound, current_mid, history)    │
│     TTL: 3600 seconds (1 hour auto-expiry if abandoned)                │
│                                                                        │
│  2. Global & Network Leaderboards                                      │
│     Key: `leaderboard:{media_type}:global` / `...:network:hbo`         │
│     Type: ZSET (Sorted Set)                                            │
│                                                                        │
│  3. Precomputed Taste Match Fast-Lookup                                │
│     Key: `taste_cache:{media_type}:{min_user_id}:{max_user_id}`        │
│     Type: STRING (JSON: {"match": 88, "overlap": 34})                  │
│     TTL: 86400 seconds (24 hours)                                      │
│                                                                        │
│  4. User Streaming Availability Cache                                  │
│     Key: `stream_avail:{country}:{media_type}:{tmdb_id}`               │
│     Type: STRING (JSON array of provider IDs)                          │
│     TTL: 604800 seconds (7 days)                                       │
└────────────────────────────────────────────────────────────────────────┘
```
