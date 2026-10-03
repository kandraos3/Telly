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
| I-5 | **Idempotent offline replay.** Mutations sent from the client offline queue carry a `client_mutation_id UUID`; replaying an already-applied ID is a no-op. |
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

### 2.2 Tables
Abbreviations: **PK** primary key, **FK** foreign key, **U** unique. All `updated_at` columns are maintained by the shared `set_updated_at()` trigger.

| Table | Key columns & constraints | Purpose |
| :--- | :--- | :--- |
| `users` | **PK** `id` → `auth.users(id)` ON DELETE CASCADE; `username` VARCHAR(20) **U**, nullable until claimed, `CHECK (username ~ '^[a-z0-9_]{3,20}$')`; `display_name`, `avatar_url`, `bio` VARCHAR(160), `visibility_mode` (default `PUBLIC`), `pinned_showcase` JSONB `[{title_id, media_type}]` (max 3), `preferences` JSONB, `onboarding_completed` BOOL, `is_deleted` BOOL, `deletion_requested_at`, `created_at`, `updated_at` | Public profile. A skeleton row is created by the `on_auth_user_created` trigger. |
| `titles` | **PK** `(id, media_type)`; `title`, `original_title`, `release_date`, `last_air_date`, `status`, `poster_path`, `backdrop_path`, `overview`, `genres` TEXT[], `original_network`, `number_of_seasons`, `number_of_episodes`, `runtime_minutes`, `director`, `is_anime`, `anilist_id`, `mal_id`, `anime_studio`, `source_material`, `popularity` NUMERIC, `global_community_score` NUMERIC(4,2), `streaming_services` JSONB, `created_at`, `updated_at` | TMDB metadata cache (written only by `service_role` / edge functions). |
| `tv_seasons` | **PK** `id`; **FK** `(title_id, media_type)` → `titles` with `CHECK (media_type = 'tv')`; **U** `(title_id, season_number)` | Season breakdown for `SCR-08`. |
| `streaming_platforms` | **PK** `id` (`netflix`, `max`, `hulu`, `apple_tv_plus`, `disney_plus`, `prime_video`, `crunchyroll`, `paramount_plus`, `criterion`) | Provider catalog. |
| `title_availability` | **PK** `id`; **FK** `(title_id, media_type)`, `platform_id`; `country_code`, `monetization_type`, `deep_link_url`, `available_until`, `is_leaving_soon`; **U** `(title_id, media_type, platform_id, country_code, monetization_type)` | Streaming availability cache. |
| `user_streaming_subscriptions` | **PK** `(user_id, platform_id)` | Household services (`SCR-02`). |
| `user_rankings` | **PK** `id`; **FK** `(title_id, media_type)`; `user_id`; `rank_position` INT ≥ 1; `calculated_score` NUMERIC(4,2); `rating_uncertainty` NUMERIC(3,2) (σ); `status`, `finale_impact`, `favorite_character`, `review_short` VARCHAR(280), `tags` TEXT[], `watched_with_user_ids` UUID[], `audio_language`, `is_rewatch`, `rewatch_count`, `venue`, `client_mutation_id` UUID **U**; **U** `(user_id, title_id, media_type)`; **U** `(user_id, media_type, rank_position)` DEFERRABLE INITIALLY DEFERRED | The personal Dual-Canon. |
| `pairwise_duels` | **PK** `id`; `user_id`; `winner_title_id`, `loser_title_id`, `media_type` (both FKs share it); `is_upset`, `decision_time_ms`, `client_mutation_id` UUID **U**; `CHECK (winner_title_id <> loser_title_id)` | Audit log powering upsets and win-rates. |
| `user_external_accounts` | **PK** `id`; **U** `(user_id, service_name)` | Letterboxd / AniList / MAL links. |
| `user_dropped_shows` | **PK** `id`; **FK** `(title_id, media_type)`; `dropped_at_season`, `dropped_at_episode`, `reason`, `willing_to_revisit`, `notify_on_acclaim`, `notes`; **U** `(user_id, title_id, media_type)` | TV Graveyard (`SCR-18`). |
| `user_watchlist` | **PK** `(user_id, title_id, media_type)`; `priority`, `recommended_by_user_id`, `added_at` | Smart Queue (`SCR-13`). |
| `user_muted_titles` | **PK** `(user_id, title_id, media_type)` | Spoiler Shield mutes. |
| `social_follows` | **PK** `(follower_id, following_id)`; `status follow_status_enum`; `CHECK (follower_id <> following_id)` | The only social-graph table (`friendships` is removed). |
| `user_blocks` | **PK** `(blocker_id, blocked_id)` | Blocks hide content in both directions. |
| `taste_matches` | **PK** `(user_a, user_b, media_type)`; `CHECK (user_a < user_b)`; `match_percentage`, `mutual_count` | Cached Taste Match per canon. |
| `squads` / `squad_members` | `squads`: **PK** `id`, `name`, `description`, `avatar_url`, `created_by`; `squad_members`: **PK** `(squad_id, user_id)`, `role` (`OWNER`/`ADMIN`/`MEMBER`), `joined_at` | Squads (`SCR-17`). |
| `activity_logs` | **PK** `id`; `user_id`; `activity_type` (`RANKING_CREATED`, `UPSET_ALERT`, `SHOW_DROPPED`, `QUEUE_ADDED`, `COMMENT_POSTED`); `title_id`, `media_type`, `ranking_id`, `target_user_id`, `is_upset`, `upset_delta`, `metadata` JSONB, `created_at` | Feed source. |
| `feed_reactions` | **PK** `id`; **FK** `activity_id`; **U** `(activity_id, user_id, reaction_type)` | Reactions. |
| `comments` | **PK** `id`; **FK** `activity_id`; `user_id`; `body` VARCHAR(500); `contains_spoilers`; `is_hidden` | Spoiler-safe threads (`SCR-06`). |
| `reports` | **PK** `id`; `reporter_id`; `target_type`, `target_id` TEXT, `reason`, `notes`, `status` (`OPEN`/`ACTIONED`/`DISMISSED`), `created_at` | Apple 1.2 moderation queue. |

### 2.3 Indexes
- `user_rankings (user_id, media_type, rank_position)` — canon reads.
- `user_rankings (title_id, media_type)` — friends-who-ranked, taste match joins.
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
| `titles`, `tv_seasons`, `streaming_platforms`, `title_availability`, `curated_canons` | any `authenticated` | `service_role` only |
| `user_rankings`, `user_dropped_shows`, `activity_logs`, `pairwise_duels` | `can_view_user(user_id)` | own rows only (rankings via RPC) |
| `user_watchlist`, `user_streaming_subscriptions`, `user_muted_titles`, `user_blocks`, `user_external_accounts` | own rows | own rows |
| `social_follows` | either party, or `accepted` rows where `can_view_user` holds for both | INSERT only as `follower_id = auth.uid()` (status forced by trigger: `pending` for non-`PUBLIC` targets, else `accepted`); UPDATE status only by `following_id`; DELETE by either party |
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
| `record_pairwise_duels(p_duels JSONB)` | Batch insert of `{client_mutation_id, winner_title_id, loser_title_id, media_type, decision_time_ms}`; sets `is_upset` via `detect_upset_duel`; emits `UPSET_ALERT` activity for upsets. |

### 3.3 Read & Social RPCs
| RPC | Behaviour |
| :--- | :--- |
| `check_handle_available(p_handle TEXT) → BOOLEAN` | Format regex + reserved list + uniqueness (case-insensitive). |
| `calculate_taste_match_rpc(p_other UUID, p_media_type) → (match_pct INT, mutual_count INT)` | Spearman ρ over mutual titles **within one canon**: re-rank both users' mutual titles $1..k$, $\rho = 1 - \frac{6\sum d^2}{k(k^2-1)}$, shrink $w = k/(k+5)$, $\text{match} = \text{round}(\frac{w\rho + 1}{2}\cdot 100)$; $k < 2 \Rightarrow 50$. Requires `can_view_user(p_other)`. |
| `detect_upset_duel(p_winner, p_loser, p_media_type) → (is_upset, winner_win_rate, loser_win_rate, delta)` | Upset iff $\text{WinRate}(\text{loser}) - \text{WinRate}(\text{winner}) \ge 0.25$. |
| `get_activity_feed(p_filter TEXT, p_before TIMESTAMPTZ, p_limit INT)` | `following` / `squads` / `global`, keyset-paginated, RLS-filtered. |
| `calculate_squad_canon(p_squad_id, p_media_type)` | Borda count: member $i$ with $N_i$ titles awards $N_i - r + 1$ points. Members only. |
| `request_account_deletion()` / `cancel_account_deletion()` / `purge_deleted_accounts()` | 30-day grace period (Trust & Safety §4.1); purge is scheduled with `pg_cron` and only executable by `service_role`. |
| `submit_report(p_target_type, p_target_id, p_reason, p_notes)` / `block_user(p_user)` | Moderation. |

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
