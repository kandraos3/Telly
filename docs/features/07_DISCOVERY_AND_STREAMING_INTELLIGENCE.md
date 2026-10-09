# Feature Spec 07: Discovery, Smart Queue & Streaming Intelligence

## 1. Overview & Ecosystem Position
Discovery in modern television is broken because users are scattered across fragmented streaming silos. A user might maintain a watchlist inside Netflix, another inside Hulu, and another on Apple TV+, with no centralized view of what they actually want to watch.

**Telly's Discovery & Streaming Architecture:**
1. **The Universal Smart Queue:** A single, consolidated watchlist that automatically tags which of your subscribed streaming services currently hosts each show.
2. **Streaming Intelligence (JustWatch Integration):** Dynamic deep-linking directly into streaming apps (tap *"Watch on Max"* to launch the episode immediately on your phone or smart TV).
3. **Availability & Expiration Alerts:** Notifications when a show on your watchlist is about to leave a service or newly arrives on one of your subscriptions.
4. **Network Battlegrounds:** Fun, competitive community rankings comparing networks.
5. **Explore Rows:** Netflix-style rows ranked against your own canon (§7).

---

## 2. The Smart Queue (Watchlist) Architecture

> Tracking: epic #47 · Status: shipped · Decision: [0004](../decisions/0004-canon-podium-and-queue-up-next.md)

The Queue leads with one title to watch next, and the rest of the watchlist follows as compact rows. Screen spec `SCR-13` has the exact layout and states, and the approved mockup is [0047](../design_system/mockups/0047-canon-queue-layouts.html).

```
┌────────────────────────────────────────────────────────┐
│ [←]  Queue                                       [ ☷ ] │  ☷ = custom lists
│  [   Movies 14   |   TV Shows 24   ]      [ ⚲ Filter ] │  sort + On My Services
├────────────────────────────────────────────────────────┤
│  UP NEXT  The Bear · Disney+ · ★ 8.60   [↻ Another]    │
│  [ ▶ Watch on Disney+ ]                     [ ✓ Seen ] │
│  ━ THEN ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 23   │
│  Slow Horses     Apple TV+ · ★ 8.94      [▶ Apple TV+] │
│  Station Eleven  Max · ★ 8.81                  [▶ Max] │
└────────────────────────────────────────────────────────┘
```

- **Up next pick:** a uniformly random title from the titles the current filter shows for the selected canon. It's re-rolled each time the Queue opens, and ↻ picks a different one. A smart pick (friends' scores, taste match, leaving soon, how long a title has waited) is tracked in #124.
- **Mark seen:** a swipe right on a row, or ✓ Seen on the Up next card. The title leaves the queue, and the Log flow opens to rank it.

### 2.1 Smart Queue Sorting Modes
Users sort their queue from the Filter sheet. *Friends' High Score* and *Leaving Soon* are built; the others are planned:
- **Friends' High Score (Default):** Shows rated highest by their social circle.
- **Taste Match Priority:** Shows loved by friends with the highest Taste Match %.
- **Shortest Time Commitment:** Prioritizes limited miniseries (4–8 episodes) for quick weekend completions.
- **Leaving Soon:** Prioritizes shows about to expire from your active streaming services.

---

## 3. Streaming Intelligence & Deep-Linking

### 3.1 JustWatch API Data Flow
Telly integrates with the JustWatch API to maintain a fresh, geolocation-aware map of streaming availability:

```
[ User in US with Netflix + Max ] 
               │
               ▼
[ Request Show Availability: TMDB ID 87108 (Chernobyl) ]
               │
               ▼
[ JustWatch Lookup: US Region ]
  • Subscription: Max (Available)
  • Buy/Rent: Apple TV ($14.99), Prime ($14.99)
               │
               ▼
[ Client Action: "Watch on Max" button highlighted in neon ]
[ Tap Action: Launches max://deep_link_url or opens web ]
```

### 3.2 Deep-Link URI Schemes
- **Netflix:** `nflx://www.netflix.com/title/{netflix_id}`
- **Max:** `https://play.max.com/show/{max_id}`
- **Apple TV+:** `https://tv.apple.com/us/show/{slug}/{apple_id}`
- **Hulu:** `hulu://series/{hulu_id}`
- **Prime Video:** `primevideo://watch?asin={asin}`

---

## 4. Availability & Expiration Alerts

One of the most valuable utility features is keeping users from missing out on content before licensing agreements expire:
1. **"Leaving Soon" Trigger:**
   *"⚠️ Fargo (Season 1–4) is leaving Hulu in 7 days! It's currently #2 on your Watchlist."*
2. **"Just Arrived on Your Services" Trigger:**
   *"🎉 Severance Season 2 just premiered on Apple TV+!"*
3. **"Price Drop / Free to Stream" Alert:**
   *"The Wire is now available with your Max student plan."*

---

## 5. Network Battlegrounds & Editorial Hubs

```
┌────────────────────────────────────────────────────────┐
│  🧭 DISCOVER: NETWORK BATTLEGROUNDS                    │
├────────────────────────────────────────────────────────┤
│                                                        │
│  👑 HBO vs 🍏 Apple TV+ vs 🔴 Netflix                  │
│                                                        │
│  Which network has the highest average quality?        │
│  Based on 1.2M Community Pairwise Battles:             │
│                                                        │
│  1. HBO / Max       Avg Score: 8.82 / 10.0             │
│     Top 3: The Wire, Succession, Sopranos              │
│                                                        │
│  2. Apple TV+       Avg Score: 8.41 / 10.0             │
│     Top 3: Severance, Slow Horses, Ted Lasso           │
│                                                        │
│  3. FX / Hulu       Avg Score: 8.35 / 10.0             │
│     Top 3: The Bear, Fargo, It's Always Sunny          │
│                                                        │
│  4. Netflix         Avg Score: 7.64 / 10.0             │
│     Top 3: Mindhunter, Dark, Stranger Things           │
│                                                        │
└────────────────────────────────────────────────────────┘
```

### Curated Editorial Collections (removed)
Removed by [decision 0007](../decisions/0007-explore-hero-rows-and-client-ranker.md) (#46). Explore's rows (§7) replace them.

---

## 6. Data Model & Cache Architecture

> **Schema note:** SQL in this document is illustrative. The normative contract is [Spec 02](../technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md) (table `titles` keyed by `(id, media_type)`, `media_type_enum ('movie','tv')`, `rank_position`), and the executable source is `supabase/migrations/`.

```sql
-- Streaming Providers Master Table
CREATE TABLE streaming_platforms (
    id VARCHAR(50) PRIMARY KEY, -- 'netflix', 'max', 'apple_tv_plus', 'hulu'
    display_name VARCHAR(100) NOT NULL,
    logo_url TEXT NOT NULL,
    base_deep_link TEXT,
    is_free_tier BOOLEAN DEFAULT FALSE
);

-- Show Availability Table (Updated daily via JustWatch webhook / cron)
CREATE TABLE show_streaming_availability (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    show_id INT REFERENCES titles(id) ON DELETE CASCADE,
    platform_id VARCHAR(50) REFERENCES streaming_platforms(id) ON DELETE CASCADE,
    country_code VARCHAR(2) NOT NULL DEFAULT 'US',
    monetization_type VARCHAR(20) NOT NULL, -- 'FLATRATE', 'FREE', 'RENT', 'BUY'
    deep_link_url TEXT,
    available_until DATE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(show_id, platform_id, country_code, monetization_type)
);

-- User Subscription Table
CREATE TABLE user_streaming_subscriptions (
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    platform_id VARCHAR(50) REFERENCES streaming_platforms(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, platform_id)
);
```

---

## 7. Explore Rows & Recommendation Engine

> Tracking: epic #46 · Status: shipped · Decisions: [0007](../decisions/0007-explore-hero-rows-and-client-ranker.md), [0008](../decisions/0008-explore-dismissals-own-table.md) · Mockup: [0046](../design_system/mockups/0046-explore-rows.html)

Explore (`SCR-07`) is a stack of rows that each answer one question: *what fits me best, what's popular, what's like the titles I loved, what are my friends watching, what am I about to lose, what haven't I tried?* The server **gathers candidates** (it is the only side that can call TMDB and join friends and services). The app **ranks them** with a pure Dart `ExploreRanker`, so every rule below is unit-testable and Explore opens from a local cache.

The audit of the engine this replaces (`get_recommended_titles`, genre-overlap counting over the local catalogue) is on #92.

### 7.1 Dual canon
Every candidate, profile and row belongs to exactly one canon. `get_explore_candidates` takes one `media_type`, the ranker never mixes two payloads, and the Movies / Series switcher at the top of `SCR-07` chooses which payload is shown. A film never appears in a series row.

### 7.2 Rows
Rows are shown in this order. Each row hides itself when its minimum isn't met; it never pads with filler.

| # | Row | Items | Minimum to show | Order |
| :- | :--- | :--- | :--- | :--- |
| 0 | **Hero: Top pick for you** | 1 | ≥ 3 rankings in the canon, and a candidate with `seed_links` non-empty or `taste ≥ 0.50` | highest `fit` |
| 1 | **Trending now** | 10 | 4 | TMDB weekly trending position, then Telly-only titles by `telly_recent_rankings` desc |
| 2 | **Top picks for you** | 15 (30 in See all) | ≥ 3 rankings; 4 items | `fit` desc |
| 3–5 | **Because you ranked *X*** (up to 3 rows) | 15 (30) | 4 items each | `fit` desc among candidates linked to *X* |
| 6 | **Your friends are watching** | 15 (30) | 1 item | friend count desc, then friends' mean score desc, then `fit` |
| 7 | **Leaving your services soon** | 15 (30) | 1 item | days left asc, then queued first, then `fit` |
| 8 | **Something different** | 15 (30) | ≥ 10 rankings; 4 items | `different` desc (§7.4) |
| 9 | **Network battlegrounds** | today's strip | Series canon only | `get_network_battlegrounds` (§5) |

- **New user** (< 3 rankings in the canon): the hero and rows 2–5 are replaced by a prompt card, *"Rank 3 movies to unlock your picks"* (or *series*), showing progress dots (n of 3) and a **+ Log a movie** button. Row 2 becomes **Top rated on Telly**, which is the same candidates ordered by `quality` desc.
- **Exclusions**: every row except Leaving soon excludes titles I've ranked, queued or muted. Leaving soon excludes only ranked and muted, so a queued title that's about to leave still shows (queued first). Trending excludes ranked and muted.
- **One title, one row**: rows are *filled* in this priority order, and each title is used once: hero → Leaving soon → Because rows (in display order) → Friends → Top picks → Something different. **Trending is exempt**, because it's a list of facts and repeating a title there is expected. Display order (the table above) is separate from fill order. A row claims only the titles its carousel shows (the first 15). Titles 16–30, seen only in See all, may also appear in a later row.
- **Diversity cap**: within one row, at most 2 titles share a `collection_id`, and (movies) at most 2 share a `director`. When the cap is hit the ranker skips to the next candidate.
- **Because you ranked *X***: the seeds are my top 5 titles in the canon by `calculated_score` with score ≥ 7.80 (Great tier and up), not DROPPED. Up to 3 rows are shown, picked by a daily rotation: seeds are sorted by rank, then `start = daysSinceEpoch(localDate) mod n` and the next 3 are taken cyclically. A row whose seed has fewer than 4 unused candidates is skipped, and the next seed in the rotation tries.

### 7.3 Candidate payload (`get_explore_candidates`)
`get_explore_candidates(p_media_type media_type_enum) → JSONB`, SECURITY DEFINER with `_require_user()`, authenticated only:

```jsonc
{
  "generated_at": "2026-10-07T18:00:00Z",
  "media_type": "movie",
  "profile": {
    "rankings": [ { "title_id": 496243, "score": 9.72, "rank": 2, "genres": ["Comedy", "Thriller", "Drama"] } ], // my non-DROPPED rankings in the canon
    "seeds":    [ { "title_id": 496243, "title": "Parasite", "poster_path": "/…", "score": 9.72, "rank": 2 } ],    // top 5, score ≥ 7.80
    "services": ["netflix", "max"],
    "missing_related": [157336]                // seeds with no fresh title_related rows (§7.6)
  },
  "candidates": [ {
    "title_id": 705996, "title": "Decision to Leave", "poster_path": "/…", "backdrop_path": "/…",
    "release_year": 2022, "genres": ["Thriller", "Romance", "Mystery"], "director": "Park Chan-wook",
    "original_network": null, "collection_id": null,
    "community_score": 8.91, "community_count": 37,
    "tmdb_vote_average": 7.3, "tmdb_vote_count": 1840,
    "seed_links": [ { "seed_id": 496243, "position": 3 } ],   // title_related rows from my seeds (1-based TMDB position)
    "trending_rank": null,                                    // 1..20 from trending_titles, or null
    "telly_recent_rankings": 4,                               // Telly rankings in the last 14 days
    "friends": [ { "user_id": "…", "display_name": "Maya", "avatar_url": null, "score": 9.10, "match_pct": 81 } ], // score null = queued only
    "providers": ["mubi"], "on_my_services": false,
    "leaving_until": null,                                    // date, when is_leaving_soon on one of my services
    "in_queue": false
  } ]
}
```

**Sources** (union, deduplicated by title; at most **200** candidates):
1. **Seeds**: `title_related` rows for my seeds, up to 20 per seed.
2. **Trending**: all `trending_titles` rows for the canon (20), plus the top 10 by Telly rankings in the last 14 days.
3. **Friends**: titles accepted followees ranked or queued in the last 30 days (`activity_logs` `RANKING_CREATED` / `QUEUE_ADDED`), top 30 by friend count. `match_pct` comes from `taste_matches` for this canon (null when missing).
4. **Leaving**: `title_availability` rows with `is_leaving_soon` on one of my `user_streaming_subscriptions` (monetization `flatrate`, `free` or `ads`), up to 20.
5. **Wide pool** (for Top picks, Top rated and Something different): the 60 titles in the canon with the highest `COALESCE(global_community_score, tmdb_vote_average)` among those with `tmdb_vote_count ≥ 200` or `community_count ≥ 5`.

Blocked users (either direction) and deleted users never count as friends. Candidates I've ranked, muted or dismissed (`user_dismissed_recommendations`, §7.5) are dropped server-side. Queued titles are kept with `in_queue: true`, because Leaving soon needs them (§7.2). `profile.rankings` lets the ranker build the genre profile without another call.

### 7.4 Scoring (`ExploreRanker`)
`lib/features/discovery/domain/explore_ranker.dart`. All constants live in one `ExploreWeights` class. Every function is pure (its inputs are the payload and `today`) and unit-tested.

**Genre profile.** Each ranking contributes `w = max(score − 5.50, 0)`, so Mid and below count for nothing, split evenly across its genres: `G[g] += w / |genres|`. Then `G` is normalised to unit length.

**Components** (each clamped to `[0, 1]`):

| Component | Formula |
| :--- | :--- |
| `taste` | cosine of `G` and the candidate's genre vector (`1/√k` on each of its `k` genres); 0 if either is empty |
| `seeds` | `min(1, Σ_links seedWeight(s) · (1 − (position − 1)/20))`, where `seedWeight(s) = (score_s − 7.80 + 0.20) / 2.40` |
| `friends` | noisy-or `1 − Π(1 − f_i)`, with `f_i = m_i · q_i`, `m_i = match_pct/100` (0.50 if null), `q_i = (score_i − 5.50)/4.50` (0.50 if queued only) |
| `quality` | `(q − 5.50)/4.50`, where `q` is `community_score` if `community_count ≥ 5`, else the Bayesian mean `(n·v + 500·6.8)/(n + 500)` with `v = tmdb_vote_average`, `n = tmdb_vote_count`; 0.50 if neither exists |
| `services` | 1 if `on_my_services`, else 0 |

**Fit.** `fit = 0.40·taste + 0.20·seeds + 0.15·friends + 0.15·quality + 0.10·services`.

**Match shown to the user.** `matchPct = clamp(round(100 · fit / 0.85), 1, 99)`, shown as "94% match" in `TellyColors.electricVioletOf(context)`. It is shown on the hero, Top picks and Because rows only.

**Something different.** It is eligible when `taste < 0.25` and `quality ≥ 0.60`. `different = 0.60·quality + 0.25·friends + 0.15·services`. The subtitle names my two largest genres in `G`: *"Outside your usual sci-fi and drama"*.

**Hero reason line.** If the hero has seed links, it names the top 2 seeds by contribution with their scores: *"Like **Parasite** (9.72) and **Oldboy** (9.10)"*. Otherwise it names the two shared genres with the largest `G`: *"Fits your love of thriller and mystery"*. Then come the director (movies) or network (series), the year, and *"on {provider}"*, preferring one of my services.

**Determinism.** Ties break by `fit` desc, then `title_id` asc. The same payload and the same `today` always give the same rows.

### 7.5 Client data, cache and states
- **Cache**: a new Drift table `ExploreCache (mediaType PK, json, savedAt)` holds the last payload per canon. Ranking runs on the cached payload, so rows render with no network. The cache is stale after **6 h**: on open, Explore shows the cache straight away and refetches in the background when stale. Pull-to-refresh always refetches.
- **State**: `exploreRowsProvider` is an `AsyncNotifierProvider.family` keyed by media type. It reads the cache, emits ranked rows, fetches, then emits again.
- **States** (drawn in mockup 0046):
  - *Loading* (no cache): a skeleton hero (252 dp) and two skeleton rows. The shimmer stops under reduced motion.
  - *Offline with cache*: a banner under the search bar, *"Offline. Showing picks from 2 h ago."*, then the cached rows.
  - *Error or offline with no cache*: *"Couldn't load Explore. Check your connection and pull to try again."* plus a **Try again** button. Search still works when online.
  - *New user*: the prompt card (§7.2).
  - *Empty row*: hidden.
- **Actions**:
  - Card tap → `SCR-08`.
  - Hero **+ Queue**: adds to the watchlist through the existing offline queue path, and the button becomes **✓ In queue**.
  - Hero **Not for me**: inserts into `user_dismissed_recommendations` ([decision 0008](../decisions/0008-explore-dismissals-own-table.md)), shows the next hero, and a snackbar *"Hidden from your picks: <title>"* with **Undo**, which deletes the row. The snackbar floats 8 dp above the floating Log button (`TellyLogFab.clearance`), which would otherwise cover **Undo**. It is not a Spoiler Shield mute, so the feed is untouched.
  - **See all ›** on a row (#181): opens `/explore/row/:rowId?canon=movie|tv`, a 3-column poster grid of up to 30 titles (`ExploreRow.items`) ranked from the same payload, in the carousel's order.
    - `rowId` is the row kind's name (`trending`, `topPicks`, `topRated`, `friends`, `leavingSoon`, `somethingDifferent`), or `becauseYouRanked-<seed title id>` for a Because row.
    - Each card keeps the row's meta line: match % and year, community score, service and countdown, or genre. In the grid, Trending's line is *#N this week* and Friends' is who is watching. A Because grid has no seed tile; the seed is in the title.
    - A `rowId` today's rows don't have (a seed that has rotated out, a hidden row, a new user), a canon other than `movie` or `tv`, or a canon that can't load shows *"This list isn't available"*.

### 7.6 Server caches and refresh
- `title_related (seed_id, seed_media_type, related_id, position SMALLINT, fetched_at)`, **PK** `(seed_id, seed_media_type, related_id)`. The related title has the seed's media type (TMDB recommendations stay within one type). It holds TMDB `/{movie|tv}/{id}/recommendations` page 1.
- `trending_titles (media_type, position SMALLINT, title_id, fetched_at)`, **PK** `(media_type, position)`. It holds TMDB `/trending/{movie|tv}/week` page 1.
- `title_related_fetches (seed_id, seed_media_type, fetched_at, result_count)` logs every recommendations fetch, including empty ones. `profile.missing_related` and the scheduled refresh read it, so a seed with no TMDB recommendations isn't refetched until its log entry is 14 days old. It is server-only (no client access).
- Writes go through two service-role RPCs, so a list is never half-replaced: `store_title_related(seed, media_type, related JSONB)` (it drops the seed itself and positions past 20, then logs the fetch) and `store_trending(media_type, title_ids INT[])`. `stale_explore_seeds(max_age_days, limit)` lists users' top-5 seeds (≥ 7.80, not DROPPED) that were never fetched or are past the age limit: never-fetched first, then by how many users share the seed.
- `titles` gains `tmdb_vote_average NUMERIC(3,1)` and `tmdb_vote_count INT`. Every title that the related or trending fetch returns is upserted as a minimal `titles` row (id, media_type, title, poster, backdrop, release date, genres, popularity, votes). Genre names come from a static TMDB genre-id map in `supabase/functions/_shared/genres.ts`, because list endpoints return only `genre_ids`.
- The edge function **`title-related`** works in two modes:
  - Authenticated `POST {seed_ids: int[≤5], media_type}`: fetches and caches any seeds older than 14 days or missing. The app calls it when `profile.missing_related` is non-empty, then refetches candidates once.
  - Service-role `POST` (pg_cron `explore-refresh`, every 30 minutes): refreshes `trending_titles` when they're older than 6 h, then up to 40 seeds from `stale_explore_seeds`. It stops at TMDB's rate limit (429) and carries on at the next run.
  - A seed TMDB doesn't know (404) is logged as an empty fetch. Any other TMDB error leaves the seed stale, so it is retried next run.
  - New `titles` rows have `metadata_version` 0, so `tmdb-details` maintenance later fills in their director, network and collection (which the diversity caps in §7.2 use).
- Secrets: `TMDB_ACCESS_TOKEN` (already set for `tmdb-details`).
- **Retirement**: `get_recommended_titles` and `get_trending_titles` are dropped (#191): the app stopped calling them in #182 and no older build is installed anywhere. `curated_canons` and the client's hard-coded canons are removed.
