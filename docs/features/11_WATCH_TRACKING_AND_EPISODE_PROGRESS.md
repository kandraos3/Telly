# Feature Spec 11: Watch Tracking & Episode Progress

> Tracking: epic #168 · Status: approved · Decision: [0010](../decisions/0010-watch-tracking-episode-pointer.md) · Mockup: [0168](../design_system/mockups/0168-watch-tracking.html) · Tasks: #224–#233

## 1. Overview & Scope
Tracking lets people follow what they are **watching now**, before they rank it. A series keeps **one place**: the last episode you watched. One tap moves it on. Finishing a title leads into the Log and duel flow (features/02). Tracking is separate from the canon: it never changes a rank or a score.

**In scope:** start, progress, un-log, rewatch, finish, drop and revive; new episodes of shows you're caught up on; the Watching hub; tracking on the title page, Home, More, Queue, Canon and Graveyard; offline use; a friends-only "watching now" signal and two feed events.

**Out of scope:**
- Episode reactions, takes and season duels: epic #216. This spec reserves their hooks (§5.3, §9.4).
- Push notifications for new episodes: #222.
- A per-episode checklist (decision 0010, option B).

## 2. Concepts

### 2.1 The place
- A tracked **series** stores its place as `(last_season, last_episode)`: the last episode you watched. `NULL, NULL` means you haven't watched an episode yet.
- Every episode before and including your place counts as watched. Telly doesn't record skipped episodes.
- A tracked **movie** has no place. It is either watching or finished.
- Season 0 (TMDB specials) is never part of the place, the progress or the counts.

### 2.2 States (stored)
| State | Meaning |
| :--- | :--- |
| `WATCHING` | A series with an aired episode after your place, or a movie you haven't finished. |
| `CAUGHT_UP` | A series where no aired episode follows your place and the show is still running or returning. |
| `FINISHED` | A series you're caught up on whose TMDB status is *Ended* or *Canceled*, or a movie marked finished. |

The server sets the state on every write from §3's rules. The client recomputes it from the same rules for optimistic UI.

### 2.3 Groups (derived, for the hub and Home)
Each tracked title falls into exactly one group, checked in this order:
1. **New episodes**: `new_episodes_since` is set (§4.8).
2. **In progress**: `WATCHING`, with `last_progress_at` within the pause window (30 days for a series, 7 days for a movie).
3. **Finished, not ranked**: `CAUGHT_UP` or `FINISHED`, and the title isn't in your canon for its media type.
4. **Caught up**: series only. `CAUGHT_UP` and ranked, or `FINISHED` and ranked for 14 days after `finished_at`. After that the title leaves the hub (it stays visible in the hub's *Finished* filter, §9.5).
5. **Paused**: `WATCHING`, with no progress for the pause window or longer.

**Movies** (§2.5) never reach *New episodes* or *Caught up*. A finished movie that's ranked leaves the hub at once, and stays in the *Finished* filter.

### 2.4 Dual canon
- Tracking rows carry `media_type` like every other per-title row.
- Every list, count and stat that shows tracking filters by one media type, except the hub's *All* chip and Home's summary. Those show both, labelled per row ("Movie" in the meta line).
- Nothing in tracking compares a movie with a series.

### 2.5 Movies
A movie is tracked with the same row and RPCs as a series, without a place (decision 0010; option A of the movie follow-up on #168, 2026-10-09).
- **States:** `WATCHING` until you tap **✓ Finished**, then `FINISHED`. There's no `CAUGHT_UP` and no new-episodes check.
- **Start:** no sheet; tracking starts at once with Undo (§4.1).
- **Title page:** the *Watching* card (§5.2b) replaces *Streaming now*. There's no seasons section, spoiler guard or drop-off line.
- **Finish:** **✓ Finished** calls `finish_tracking` and opens the finish sheet with *First-time watch* or *Rewatch* preselected from `is_rewatch` (§4.5).
- **Paused** after 7 days without finishing (§2.3). A paused movie keeps its **✓ Finished** action.
- **Rewatch:** *Watch again* on a finished movie sets `is_rewatch`. A ranked movie you're watching again shows **▶ Rewatching** on its Canon row; an unranked one shows **▶ Watching**.
- **Drop:** movies can't be dropped (features/03); the action is **Stop tracking**.
- **Stats:** *Movies finished in <year>* on the Canon Stats sheet, and the hub's Movies *This week* strip (§8).
- **Feed:** `WATCH_STARTED` and `WATCH_FINISHED` work as for series.

## 3. Progress Model & Formulas
These are pure functions in Dart (`lib/features/tracking/domain/tracking_progress.dart`), mirrored in SQL where the server needs them (§6.4). Inputs:
- `seasons`: season number → episode count, from `tv_seasons`, without season 0;
- `aired(s, e)`: whether an episode has aired (§3.2);
- the place, and today's date in the user's timezone.

### 3.1 Next episode
```
next(place):
  if place is NULL:                      candidate = (first season ≥ 1, 1)
  elif last_episode < count(last_season): candidate = (last_season, last_episode + 1)
  else:                                  candidate = (next season number > last_season, 1)
  return candidate if it exists and aired(candidate) else NONE
```

### 3.2 Aired
- `aired(s, e)` is true when the `tv_episodes` row exists and its `air_date` is today or earlier.
- When `tv_episodes` has no rows for season `s`, it falls back to the season: `tv_seasons.air_date ≤ today`, and season `s` is not the highest-numbered season of a show whose TMDB status is *Returning Series* or *In Production*. That season's episodes count as unknown, so they're not aired.
- Unknown air dates count as not aired.

### 3.3 State
```
series: next(place) ≠ NONE → WATCHING
        else if titles.status ∈ {'Ended', 'Canceled'} → FINISHED
        else → CAUGHT_UP
movie:  finished_at IS NULL → WATCHING, else FINISHED
```

### 3.4 Progress fraction
`watched = Σ count(s) for 1 ≤ s < last_season + last_episode` (0 when the place is NULL).
`aired_total = number of aired episodes (§3.2) across all seasons ≥ 1`.
`progress = watched / aired_total`, clamped to 0–1. The bar is full when `aired_total = 0` and the state is `CAUGHT_UP` or `FINISHED`.
Shown as "14 of 19". The hub's "N left" is `aired_total − watched`, and "N left this season" counts within `last_season`.

### 3.5 Moving the place
- Every write sends the **new absolute place**, never a delta. Replays are then idempotent, and the last write wins per title.
- **Forward by one** (✓ Watched E6): the place becomes `next(place)`.
- **Jump**: tapping an episode on the title page sets the place to that episode. Earlier jumps confirm (§4.4).
- **Clamp**: if TMDB later lowers an episode count below the place, the place is clamped to the last episode of that season on the next write or refresh.

### 3.6 Episode events (for stats)
Each write also appends **episode events**, which stats count (§8):
- Forward by one or a forward jump records one `WATCHED` event per episode passed, capped at 50 per write.
- A backward move records one `UNWATCHED` event per episode passed.
- *Rewatched it* records one `REWATCHED` event and doesn't move the place.
- Finishing a movie records `FINISHED`.
- Starting with "I'm partway through" records **no** events (that's history before Telly).

**Episodes in year Y** = `WATCHED + REWATCHED − UNWATCHED` with `created_at` in Y in the user's timezone, floored at 0. TV only. **Movies finished in Y** = `FINISHED` events in Y for movies.

## 4. Flows

### 4.1 Start watching
- **Entry points:**
  - the title page's Watch slot (SCR-08 §T.2);
  - a Queue row's **▶ Start** (SCR-13);
  - the hub's empty state, which leads to Explore;
  - Graveyard's **Revive** (§4.7).
- **Series:** the **Where are you?** sheet asks *Starting from the beginning* or *I'm partway through*. Partway shows two wheels: season (the show's seasons ≥ 1) and *the last episode you watched* (1…count). The default is S1 E1, and a preview line shows the episode's name when cached. **Start tracking** saves it.
- **Movie:** no sheet. Tracking starts at once, with a snackbar "Watching Dune: Part Two · Undo".
- **Effects:**
  - The title leaves the Queue (Undo restores both).
  - A `WATCH_STARTED` activity is posted (§7.2).
  - The title page moves to state *Watching*, or *Caught up* if nothing aired follows.
- **Already tracked:** the slot shows the current state instead (SCR-08 §T.2).
- **Finished title:** starting again offers **Watch again**, which resets the place to NULL and sets `is_rewatch = true`. Events count as normal.

### 4.2 Mark the next episode watched
- The button reads **✓ Watched E6**. Home rows, hub rows and Canon row actions use the short form **✓ E6**.
- If the next episode is in another season than your place, it reads **✓ Watched S3 · E1** (short form **✓ S3E1**).
- Tapping it:
  - moves the place forward (§3.5) with the light impact haptic;
  - updates the UI at once from the local cache;
  - shows an **Undo** toast for 6 seconds (`TellySnackBar`): "S2 · E6 watched · Undo".
- Undo sends the previous absolute place, so the net events are zero.
- **Reserved for #216:** the toast is built as a tray, so #216 can add a reaction row without changing this flow.
- If that write leaves nothing aired after your place, the **finish sheet** opens (§4.5).

### 4.3 Un-log
- On the title page, tapping a ticked episode opens its episode sheet:
  - its still, name, and "Watched" plus when, if a `WATCHED` event exists for it;
  - **↩ Mark as not watched**;
  - **Rewatched it**.
- **Mark as not watched** on episode X sets the place to the episode before X, or NULL if X is S1 E1. If that moves the place back more than one episode, it confirms first: "S2 · E3 to S2 · E6 will count as not watched." with **Move back** and **Cancel**.
- **Rewatched it** records `REWATCHED` (§3.6) and shows "Rewatch logged".
- **Long-press** on a ✓ E6 button (Home, hub) offers *Un-log S2 · E5* for the last watched episode only.
- If un-logging takes a `CAUGHT_UP` or `FINISHED` title back to `WATCHING`, its state follows §3.3. A finish sheet that was already shown doesn't reopen.

### 4.4 Jump
- Tapping an **unticked** episode X in the seasons accordion opens the same sheet with **✓ Watched up to here**. This sets the place to X. When that passes more than one episode, the sheet lists the count: "Marks 3 episodes watched."
- A jump never opens the Log flow on its own. If it ends the show, the finish sheet opens (§4.5).

### 4.5 Finish
The **finish sheet** opens when a write takes a series to `CAUGHT_UP` or `FINISHED`, or when a movie is marked ✓ Finished. It shows once per transition.
- **Title:** "You finished <title>" (`FINISHED`) or "You're up to date on <title>" (`CAUGHT_UP`).
- **Not ranked:** radio rows for the watch status, preselected:
  - *Finished whole series* when `FINISHED`;
  - *Up to date (waiting for next season)* when `CAUGHT_UP`;
  - *First-time watch* or *Rewatch* for a movie, from `is_rewatch`.
- Then **Log and duel →**, which opens `/log` with the title and the status prefilled (§9.6), and **Later**, which leaves the title in *Finished, not ranked*.
- **Already ranked:** "Your rank: #4 · 9.31", **Re-duel →** (opens the duel for the title, as the title page's Re-duel does), and **Keep my rank**.
- The flow never opens without the user tapping a button.

### 4.6 Drop
- The title page's ⋯ menu and the hub row's swipe-left offer **Drop it**.
- It opens the existing drop flow (features/03 §3.2) with the drop point prefilled from your place, or from `next(place)` if you haven't watched an episode in the current season.
- Saving the drop stops tracking (§4.9). Cancel changes nothing.
- Movies can't be dropped (features/03): for movies the action is **Stop tracking**.

### 4.7 Revive
- On SCR-18, **Revive** on a dropped show starts tracking with the place set to the drop point. A drop that recorded a season but no episode resumes at the start of that season, so the place is the last episode of the season before (nothing for season 1).
- It deletes the `user_dropped_shows` row in the same server call, and posts no activity.

### 4.8 New episodes
- A daily job (§6.5) refreshes seasons and episodes for every series that someone tracks in `CAUGHT_UP` or `FINISHED`. Shows with status *Ended* or *Canceled* are checked weekly; others daily.
- After the refresh, any such row whose `next(place)` now exists and has aired:
  - goes back to `WATCHING`;
  - gets `new_episodes_since = now()`.
- `new_episodes_since` is cleared by the next forward write on that title.
- **UI:**
  - The hub's *New episodes* group comes first.
  - Home's summary puts these titles first.
  - The title page shows the *New season* state (SCR-08 §T.6): "Season 3 is out" when `next(place).episode = 1`, otherwise "E4 is out".
  - Rows carry an amber pill with the same text.
- **Ranked series:** if the title is ranked with status `WATCHING` (Up to date), its rank is kept. The next finish sheet offers **Re-duel** (§4.5).

### 4.9 Stop tracking
- The ⋯ menu offers **Stop tracking**, which deletes the tracking row after a confirm ("Your progress is removed. Your rank, if any, stays.").
- Events are kept for stats.
- It never touches `user_rankings`, `user_watchlist` or `user_dropped_shows`.

### 4.10 Queue interplay
- Starting removes the title from `user_watchlist` in the same server call.
- Stopping doesn't put it back.
- Queue's swipe right (*Seen it*) is unchanged and doesn't start tracking.

## 5. Title Page Integration
Screen-level detail is in SCR-08 §T (screen specs). Summary:

### 5.1 Header and action row
- **Header:** an eyebrow over the title shows the state:
  - "● Watching · S2 · E6 next" (primary accent);
  - "● Up to date" (primary accent);
  - "● Finished" (primary accent);
  - "● New season" or "● New episode" (Warm Amber).
- **Backdrop:** a 3 dp progress line along its bottom edge, in the primary accent on `strokeSubtle`.
- **Action row:** the first slot becomes **Watch** (the Queue toggle remains in the app bar bookmark).

### 5.2 Next episode card
While `WATCHING`, it replaces *Streaming now*. It holds:
- the episode's still, name, air date and runtime;
- "14 of 19";
- **▶ <provider>** (the same deep link as *Streaming now*);
- **✓ Watched E6**.

### 5.2b Movie Watching card
While a movie is `WATCHING`, it replaces *Streaming now*. It holds:
- the label "WATCHING" and "Started yesterday" (relative date of `started_at`);
- the poster thumbnail, the title, and "2 h 46 · on Max" (runtime from `titles.runtime_minutes`, then the provider);
- **▶ <provider>** (the same deep link as *Streaming now*) and **✓ Finished**.

When the movie is `FINISHED`, the card reads "You finished it · Oct 6". It offers **Rank <title> →** if the movie isn't ranked, and shows its rank and score if it is. *Streaming now* comes back below it.

### 5.3 Seasons as progress
- The *Seasons* section shows, per season:
  - a 26 dp progress ring;
  - the season name;
  - "watched", "5 of 10", "Not started" or "Airing · next episode Fri, Oct 17".
- Expanding a season lists its episodes:
  - **ticked** (✓, primary accent) up to your place;
  - **You're here** on the next one;
  - **blurred names and synopses** after it (Spoiler guard, §5.5).
- Each row opens the episode sheet (§4.3, §4.4).
- **Reserved for #216:** the route `/title/tv/:id/episode/:season/:episode` (episode page). This epic doesn't build it.

### 5.4 Friends and community
- **Watching now:** friends currently tracking the title, from `get_title_watchers` (§6.3). The row reads "Watching now: Maya, Jordan" (up to 3 names, then "and N others"), with stacked 24 dp avatars. It never shows their episode.
- **Drop-off line:** shown when your place is after the community's most common drop point from the existing survival summary: "You're past S1 · E4, where 18% of viewers drop it." The percentage is that drop point's count divided by everyone who tracked, finished, watched or dropped the show, rounded.

### 5.5 Spoiler guard
- Episode names and synopses after `next(place)` are blurred (sigma 4), with the caption "Hidden until you get there. Tap to reveal."
- Revealing one doesn't reveal the others and isn't remembered after you leave the page.
- Untracked titles show everything.

## 6. Data Contract
The normative SQL lives in `supabase/migrations/`. The table and RPC summaries are added to [TA-02](../technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md).

### 6.1 Tables
```sql
CREATE TYPE public.tracking_state_enum AS ENUM ('WATCHING', 'CAUGHT_UP', 'FINISHED');

CREATE TABLE public.user_tracking (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title_id INT NOT NULL,
    media_type public.media_type_enum NOT NULL,
    last_season INT CHECK (last_season >= 1),
    last_episode INT CHECK (last_episode >= 1),
    state public.tracking_state_enum NOT NULL DEFAULT 'WATCHING',
    is_rewatch BOOLEAN NOT NULL DEFAULT FALSE,
    new_episodes_since TIMESTAMPTZ,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_progress_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    finished_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, title_id, media_type),
    FOREIGN KEY (title_id, media_type) REFERENCES public.titles(id, media_type) ON DELETE CASCADE,
    CHECK ((last_season IS NULL) = (last_episode IS NULL)),
    CHECK (media_type = 'tv' OR last_season IS NULL)
);
CREATE INDEX idx_user_tracking_title ON public.user_tracking (title_id, media_type, state);

CREATE TABLE public.user_tracking_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title_id INT NOT NULL,
    media_type public.media_type_enum NOT NULL,
    kind VARCHAR(12) NOT NULL CHECK (kind IN ('WATCHED', 'UNWATCHED', 'REWATCHED', 'FINISHED')),
    season_number INT,
    episode_number INT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    FOREIGN KEY (title_id, media_type) REFERENCES public.titles(id, media_type) ON DELETE CASCADE
);
CREATE INDEX idx_tracking_events_user_time ON public.user_tracking_events (user_id, media_type, created_at);

-- TMDB episode cache (written by the tmdb-season edge function, service role only)
CREATE TABLE public.tv_episodes (
    title_id INT NOT NULL,
    media_type public.media_type_enum NOT NULL DEFAULT 'tv' CHECK (media_type = 'tv'),
    season_number INT NOT NULL CHECK (season_number >= 1),
    episode_number INT NOT NULL CHECK (episode_number >= 1),
    name VARCHAR(200),
    overview TEXT,
    still_path TEXT,
    air_date DATE,
    runtime_minutes INT,
    fetched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (title_id, season_number, episode_number),
    FOREIGN KEY (title_id, media_type) REFERENCES public.titles(id, media_type) ON DELETE CASCADE
);
```
- **Other schema changes:**
  - `activity_logs.activity_type` gains `WATCH_STARTED` and `WATCH_FINISHED`.
  - `MutationKind` gains the kinds in §9.2.
- **RLS:**
  - `user_tracking` and `user_tracking_events`: own rows for SELECT. Writes go only through the RPCs below (no client INSERT, UPDATE or DELETE policies).
  - `tv_episodes`: SELECT for any authenticated user; writes by `service_role` only.

### 6.2 Write RPCs
All of these are `SECURITY DEFINER`, `SET search_path = public`. They take `p_client_mutation_id` and are no-ops on replay (I-5, `applied_mutations`). They recompute `state` (§3.3), set `last_progress_at`, and return the row (`stop_tracking` returns nothing, because the row is gone).

| RPC | Behaviour |
| :--- | :--- |
| `start_tracking(p_title_id, p_media_type, p_last_season, p_last_episode, p_rewatch, p_client_mutation_id)` | Upserts the row. Deletes the `user_watchlist` row. Posts `WATCH_STARTED` (§7.2). On a `FINISHED` row with `p_rewatch` true, resets the place and sets `is_rewatch`. |
| `set_tracking_place(p_title_id, p_media_type, p_last_season, p_last_episode, p_client_mutation_id)` | Sets the absolute place (NULLs allowed), clamped (§3.5). Appends events (§3.6). Clears `new_episodes_since` on a forward move. Sets `finished_at` and posts `WATCH_FINISHED` on a move into `FINISHED`; clears `finished_at` on a move out of it. Raises `P0002` when not tracked. |
| `log_episode_rewatch(p_title_id, p_season, p_episode, p_client_mutation_id)` | Appends `REWATCHED`. |
| `finish_tracking(p_title_id, p_media_type, p_client_mutation_id)` | Movie: sets `FINISHED` and `finished_at`, appends `FINISHED`, posts `WATCH_FINISHED`. Series: sets the place to the last aired episode, then behaves like `set_tracking_place`. |
| `stop_tracking(p_title_id, p_media_type, p_client_mutation_id)` | Deletes the row. Keeps events. |
| `revive_dropped_show(p_title_id, p_client_mutation_id)` | Deletes the caller's `user_dropped_shows` row and starts tracking at its drop point (NULL if none). |

### 6.3 Read RPCs
| RPC | Behaviour |
| :--- | :--- |
| `get_my_tracking()` | The caller's rows joined with `titles` (title, poster, backdrop, status, number of seasons), `tv_seasons` counts, the next episode's `tv_episodes` row when cached, whether the title is in the caller's canon (with rank and score), and the latest aired episode. The client derives groups (§2.3) and progress (§3.4) from it. |
| `get_title_watchers(p_title_id, p_media_type)` | Up to 20 users the caller has an `accepted` follow of, where `can_view_user` holds, the user isn't `GHOST`, and who track the title in `WATCHING`. Ordered by `last_progress_at` desc. Returns `user_id`, `username`, `display_name`, `avatar_url` and the total count. **No place or state.** |
| `get_tracking_stats(p_media_type, p_year)` | The caller's §3.6 totals for the year: `episodes` (TV) or `movies_finished` (movie). The hub's *This week* uses `p_year` NULL with the ISO week instead: for TV, `episodes` and `minutes` summed from `tv_episodes.runtime_minutes` where known; for movies, `movies_finished` and `minutes` summed from `titles.runtime_minutes`. |

### 6.4 Server state recompute
`_tracking_state(p_user_id, p_title_id, p_media_type)` implements §3.1–§3.3 in SQL and is shared by the RPCs and the job. pgTAP mirrors the Dart vectors in `test/fixtures/tracking_progress_vectors.json`, which both sides must pass.

### 6.5 Daily refresh job
- **Edge function `tracking-refresh`** (service role, called by pg_cron through `_invoke_edge_function` at `23 5 * * *`):
  1. It selects distinct `(title_id)` from `user_tracking` where `media_type = 'tv'` and `state IN ('CAUGHT_UP', 'FINISHED')`. Ended or Canceled shows are included only on Mondays.
  2. For each title (at most 500 per run, oldest `titles.updated_at` first), it refreshes `titles` and `tv_seasons` through the `tmdb-details` code path. Then it fetches `/tv/{id}/season/{n}` for the season after the place and any season with unaired episodes, and upserts `tv_episodes`.
  3. It calls `refresh_tracking_new_episodes()` (SQL, service role), which applies §4.8 and returns the count.
- **Edge function `tmdb-season`** (authenticated, rate-limited like `tmdb-details`): it fetches and caches one season's episodes on demand. The client calls it when a tracked title's page opens and that season's episodes are missing or older than 7 days.

## 7. Social & Privacy

### 7.1 What friends see
- Friends see only that you're watching a title (§5.4 *Watching now*) and the two feed events. Never your place, episode numbers or progress.
- `GHOST` users appear nowhere.
- `FRIENDS_ONLY` and `PUBLIC` follow `can_view_user`.

### 7.2 Feed events
- `WATCH_STARTED`: "Maya started watching Severance". Posted at most once per title per 30 days per user.
- `WATCH_FINISHED`: "Maya finished Shōgun". Posted at most once per title per 30 days.
- Both use the existing feed card layout with no score chip, and respect the account's visibility mode like every activity.
- **Home's friend strip (SCR-21):** "started watching" and "finished" join the existing verbs.

## 8. Stats
- **Canon Stats sheet (SCR-14):**
  - TV adds **Episodes in <year>**.
  - Movies add **Movies finished in <year>**.
  - Values come from `get_tracking_stats`; offline shows "—".
- **Hub This week strip:**
  - Movies chip: movies finished this ISO week and their total runtime ("2 movies · 5 h 12").
  - All and Series chips: episodes this ISO week;
  - time, as "7 h 50", shown only when every counted episode has a cached runtime, else hidden.
- **Reserved for later:** Wrapped (SCR-19) can read the same events. No change here.

## 9. Client Architecture

### 9.1 Feature folder
`lib/features/tracking/`, organised as:
- `domain/`: `tracking_progress.dart` (§3, pure), `tracking_models.dart`, `tracking_group.dart`;
- `data/`: `tracking_repository.dart`;
- `presentation/`: `providers/`, `screens/watching_hub_screen.dart`, `widgets/` (`next_episode_card`, `where_are_you_sheet`, `episode_sheet`, `finish_sheet`, `tracking_summary_card`, `watched_episode_button`).

### 9.2 Offline
- **Drift `TrackingCache`:** PK `(titleId, mediaType)`. It mirrors §6.1's row plus the display fields from `get_my_tracking`, and `syncStatus`.
- **Drift `EpisodeCache`:** PK `(titleId, seasonNumber)`, one JSON document per season, with `fetchedAt`.
- **Writes:**
  - update `TrackingCache` first (0 ms UI);
  - then append `PendingMutations` with the new kinds `tracking_start`, `tracking_place`, `tracking_rewatch`, `tracking_finish`, `tracking_stop` and `tracking_revive`;
  - replay in FIFO order through §6.2.
- **Payloads carry absolute places,** so replays converge to the last write.
- **On reconnect,** `get_my_tracking` replaces the cache for rows with no pending mutations.
- **Offline limits:**
  - `get_title_watchers` and stats show nothing (no error).
  - The new-episodes flip waits for the next sync.

### 9.3 State
- `trackingProvider`: an `AsyncNotifierProvider` that streams `TrackingCache`. It exposes `start`, `markNext`, `setPlace`, `undo`, `rewatch`, `finish`, `stop` and `revive`.
- `titleTrackingProvider(titleId, mediaType)` selects one row.
- No `StateNotifier`.

### 9.4 Reserved hooks for #216
- The Undo toast is a `TrackingUndoTray` with an empty `trailing` slot.
- The episode sheet has a footer slot.
- The episode route constant `Routes.episode(...)` is declared but not registered.

### 9.5 Routes
| Route | Screen |
| :--- | :--- |
| `/more/watching` | SCR-29 Watching hub. |
| `/more/watching?filter=tv\|movie\|finished` | The same, opened with a filter chip selected (from Canon's strip). |

### 9.6 Log prefill
- `/log` accepts a `LogRequest` extra: a `TitleSearchResult` plus an optional `WatchStatus`.
- SCR-09 preselects that status when it's valid for the media type.
- Existing callers that pass only a `TitleSearchResult` keep working.

## 10. Edge Cases
- **No seasons cached:** the title page shows *Start watching*. The sheet first calls `tmdb-details`. If TMDB has no seasons, the series is tracked without a place, like a movie, with **✓ Finished**.
- **Anime with absolute numbering:** tracked by TMDB seasons like any series. Franchise rollup (features/08) doesn't merge tracking rows.
- **Episode count changes:** the place is clamped (§3.5).
- **Title deleted from `titles`:** the rows cascade away.
- **Ranked "Up to date" with no tracking row:** the title page shows *Start watching*. The sheet's partway default is the last season's last aired episode, so the place is preset to where the ranking implies.
- **Clock and timezone:** "today" is the user's `users.timezone` on the server and the device's local date on the client. A one-day disagreement at midnight is acceptable. The server recomputes on write.

## 11. Testing
- **Unit (Dart):**
  - `tracking_progress.dart` against `test/fixtures/tracking_progress_vectors.json`: next, aired fallback, state, progress, clamp, events;
  - group derivation;
  - `TrackingRepository` mutation payloads;
  - `TrackingCache` and `EpisodeCache` DAOs.
- **Widget:**
  - the Watch slot in each state;
  - the Where are you? sheet;
  - the Next episode card;
  - the seasons accordion with ticks, You're here and blur;
  - the episode sheet (un-log, rewatch, jump confirm);
  - the finish sheet (unranked and ranked);
  - the hub groups and empty and offline states;
  - the Home summary, More tile and Canon strip and row tag;
  - both themes.
- **Provider:** optimistic update then replay; undo nets zero; offline queue order.
- **pgTAP:**
  - each RPC, including idempotency, the watchlist removal, event counts and the activity throttle;
  - RLS (no cross-user reads, watchers hide GHOST and blocked users, no place leaked);
  - `refresh_tracking_new_episodes`;
  - the shared vectors.
- **Deno:** `tracking-refresh` selection and batching; `tmdb-season` mapping (season 0 skipped).
- **E2E:** a new **CUJ-06 Track a series**: start partway → ✓ twice → undo once → finish sheet → Log and duel prefilled → ranked.
