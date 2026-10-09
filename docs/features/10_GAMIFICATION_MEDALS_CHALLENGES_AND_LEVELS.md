# Feature Spec 10: Gamification: Medals, Challenges and Levels

> Tracking: epic #50 · Status: shipped (alternate app icons: #154; Founding Viewer launch date: #151) · Decision: [0005](../decisions/0005-gamification-medals-challenges-levels.md) · Mockup: [0050](../design_system/mockups/0050-gamification-directions.html)

## 1. Overview

A light game layer that brings people back between watches and gives friends something to compare, without ever rewarding people for ranking things they didn't watch. It has three parts, all reached from the More hub:

| Part | What it is | Screen |
|---|---|---|
| **Medals** (trophy case) | Medals for milestones, finished film collections, taste moments and streaks. Pin three to your profile. | `SCR-23` Achievements |
| **Challenges** | Time-boxed or open-ended goals ("Spooktober: 8 horror films by Oct 31"), seasonal or squad-made, raced with friends. | `SCR-25` Challenges, `SCR-26` Challenge |
| **Levels** | XP from rankings, quests, collections, challenges and streaks; levels unlock cosmetic rewards; a weekly table with friends. | `SCR-27` Your level |

Ground rules (decision 0005):
- **Only qualifying rankings count** (§2).
- **Rewards are cosmetic.**
- **The streak is weekly.**
- **Competition is friends-only, in weekly tables.**
- **Medals and finished challenges post to the feed** unless you turn it off.

It ships in three slices (§12).

---

## 2. Qualifying rankings (the anti-gaming rule)

Every count in this spec is over **qualifying rankings**: rows in `user_rankings` with status `COMPLETED`, where at least one of these holds:
- the user has a `pairwise_duels` row in the same canon whose `placed_title_id` is the title (it was placed through duels). Opponents already in the canon get nothing from the duel. When `placed_title_id` is NULL (onboarding tournament duels, where both titles are new, and duels from older apps), both the winner and the loser qualify; or
- it was the first title in that canon, so no duel was possible. This means no other `user_rankings` row in the same `media_type` has an earlier `created_at` (ties, such as rows from one import transaction, are broken by `id`, so exactly one row is first).

Consequences:
- **Imports never count.** Letterboxd and AniList imports create rankings without duels. At most one imported title per canon can slip through as "first in canon"; that's accepted.
- **Re-ranking can't farm.** Deleting a title and ranking it again yields the same XP reference (§6), so no new XP.
- **Rankings stay separate.** A duel never pairs a film with a show, so qualification is always within one canon.

Exposed as the SQL view `public.qualifying_rankings (user_id, title_id, media_type, created_at)`, which is RLS-safe through `security_invoker`.

---

## 3. Weeks, streaks and time zones

- **Week:** Monday 00:00 to Sunday 23:59:59 in the user's time zone, `users.timezone` (IANA name, default `UTC`). The app sets it on sign-in and when it changes: the app shell reads the device zone (`flutter_timezone`) on start and on every resume and calls `set_timezone` when it differs from the last value sent. Weeks are labelled ISO-style: `2026-W41`.
- **A week counts** when the user has at least one qualifying ranking whose `created_at` falls in it.
- **Weekly streak:** the number of consecutive counted weeks, ending with the most recent *finished* week, plus the current week if it already counts.
  - **The current week never breaks a streak** while it's still running.
  - **Freezes:** walking back through the weeks, a missed week is covered by a **freeze** if none has been used in the calendar month of that week's Monday (at most one per month). A covered week doesn't add to the count, but it doesn't break the streak either. A freeze is only spent when it bridges to an earlier counted week; if the gap can't be bridged, the weeks stay missed.
  - **A missed week with no freeze available ends the streak.**
  - **Best streak:** the longest run over the whole history, under the same rules.
- **Computed, not stored:** `weekly_streak(user_id, now default NOW()) → (current_weeks, best_weeks, weeks jsonb)`. `weeks` holds the last 7 weeks, oldest first, as `{week: "2026-W42", starts_on: "2026-10-12", status}` with status `counted | frozen | missed | current`; the running week is `current` until it counts, then `counted`. Being a SQL function over `qualifying_rankings` with `now` as a parameter, it's deterministic and testable with pgTAP. It runs as the caller, so it respects profile visibility (a hidden user reads as zero).
- **Setting the time zone:** `set_timezone(name)` validates the IANA name (`22023` if unknown). Clients can't write the column directly.

Shown as the lime "▲ N weeks" chip (Achievements summary, Your level, friends' rows, the Home header) and as the 7-week strip on `SCR-27` (❄ marks a frozen week).

---

## 4. Medals

### 4.1 Catalogue (`achievements` table)

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT PK | Stable slug, e.g. `movies_100`, `collection_263`, `challenge_spooktober_2026` |
| `kind` | enum `milestone · taste · streak · collection · challenge · special` | Section on `SCR-23` (`special` is Founding Viewer) |
| `tier` | enum `bronze · silver · gold · special` | Medal colour (§9.1) |
| `name`, `description` | TEXT | Description says how to earn it ("Rank 100 films") |
| `glyph` | VARCHAR(4) | 1–4 characters drawn on the medal (`100`, `LR`, `↯`) |
| `media_type` | `media_type_enum` NULL | Set for per-canon medals |
| `threshold` | INT NULL | Target for counted medals |
| `collection_id` / `challenge_id` | INT / UUID NULL | For collection and challenge medals |
| `sort` | INT | Order within its section |
| `active` | BOOL | Retired medals stay for people who hold them but are hidden from those who don't |

**Launch medals** (slice 1, seeded by migration):

| Medal | Kind | Tier | Earned by |
|---|---|---|---|
| Ticket Stub (films / series) | milestone | bronze | 10 qualifying rankings in that canon |
| Half-Centurion (films / series) | milestone | silver | 50 |
| Centurion (films / series) | milestone | gold | 100 |
| Upset Artist | taste | special (violet) | 5 duels marked `is_upset` |
| Taste Twin | taste | special | Following someone with a taste match of 92% or more (`taste_matches`) |
| Decade Hopper | taste | silver | Qualifying rankings from 5 different release decades |
| Genre Explorer | taste | silver | Qualifying rankings across 8 different genres |
| Graveyard Keeper | taste | bronze | 5 shows in the TV Graveyard |
| Regular / Devotee / Year-Rounder | streak | bronze / silver / gold | Best weekly streak of 4 / 12 / 52 weeks |
| Founding Viewer | special | special | Account created before the public launch date + 90 days. The date comes from `_public_launch_date()`, which returns NULL until the owner sets it; until then the medal stays locked. |

Seeded ids: `movies_10`, `tv_10`, `movies_50`, `tv_50`, `movies_100`, `tv_100`, `upset_artist`, `taste_twin`, `decade_hopper`, `genre_explorer`, `graveyard_keeper`, `streak_4`, `streak_12`, `streak_52`, `founding_viewer`. Taste Twin's progress is the best taste match (either canon) with someone you follow, against a target of 92. Graveyard Keeper counts `user_dropped_shows` rows for series.

**Collection medals** (slice 2): one per TMDB collection the user has started (§7). The tier is gold, and it's earned when every *released* film in the collection is in their qualifying rankings.

**Challenge medals** (slice 2): each challenge brings its own medal (§8). The tier is gold.

### 4.2 Unlocks (`user_achievements`)

`(user_id, achievement_id) PK, unlocked_at, seen_at NULL, pinned_slot SMALLINT NULL CHECK 1..3`, with a unique `(user_id, pinned_slot)`.

- **Evaluation:** `evaluate_achievements(user_id, broadcast default true)` runs:
  - at the end of `record_pairwise_duels` (once per batch);
  - from statement-level triggers after inserts into `user_rankings` (and updates that change a status to `COMPLETED`), `user_dropped_shows`, `social_follows` (accepted) and `taste_matches` (92% or more). Drops and follows are direct table writes, so triggers cover every path;
  - nightly for everyone (`evaluate_all_achievements`, pg_cron `evaluate-achievements`) for taste and streak medals.

  Only the service role can call it directly. Inserts are idempotent (`ON CONFLICT DO NOTHING`). Each new unlock:
  1. adds XP (§6, slice 3; until then, nothing);
  2. writes a `MEDAL_UNLOCKED` activity if `users.share_achievements` (§10). The backfill of existing users at deploy passes `broadcast = false`, so it posts nothing.
- **Medals are never revoked**, even if the rankings behind them are deleted.
- **Offline:** rankings sync through the offline duel queue first, so unlocks appear after sync. The app shows the unlock moment (`SCR-24`) for rows where `seen_at IS NULL`, then marks them seen with `mark_achievements_seen(ids default NULL)` (NULL marks them all).
- **Reading:** `my_achievements()` returns the active catalogue (plus retired medals you hold) with `progress` (capped at the target), `unlocked_at`, `seen_at`, `pinned_slot`, `rarity_percent` (NULL while New), `rarity_is_new`, and `friends_count` / `friends` (up to 5 visible people you follow who hold it). Others' unlocks and pins are readable from `user_achievements` wherever their profile is visible.

### 4.3 Rarity

`achievement_rarity (achievement_id PK, holders INT, active_users INT, percent NUMERIC(5,2), computed_at)`. A nightly job (`refresh_achievement_rarity`, pg_cron `refresh-achievement-rarity`) counts holders among users active in the last 90 days, meaning signed in (`auth.users.last_sign_in_at`) and not deleted. Shown as "Unlocked by 4.2% of Telly viewers", or "New: not enough viewers yet" under 200 active users.

### 4.4 Pinning

Up to three medals pinned to slots 1–3 (`pin_achievement(achievement_id, slot)` and `unpin_achievement(slot)`). Only unlocked medals can be pinned (`22023` otherwise). Pinning into a taken slot replaces that medal, and pinning a pinned medal moves it. Pinned medals appear:
- on `SCR-23`;
- under your name on the More profile card (`SCR-22`) and the friend profile (`SCR-15`);
- on the medals share card: a 9:16 story (Template E in the viral sharing spec) in two layouts, one medal ("Achievement unlocked", from the unlock moment and the medal sheet) or the showcase ("My pinned medals" / "My latest medals" with "N of M medals unlocked", from `SCR-23`'s Share).

The pinned row is never empty: when nothing is pinned, it shows your three most recent unlocks, labelled "Recent".

---

## 5. Levels and rewards

### 5.1 Levels

Levels come from total XP, which is earned and never spent.
- Going from level L to L+1 takes **250 × L XP**. The total needed to *reach* level L is **125 × L × (L − 1)**: level 1 at 0 XP, level 2 at 250, level 12 at 16,500, level 13 at 19,500.
- `SCR-27` shows the progress inside the current level, e.g. "2,340 / 3,000 XP to Level 13".

| Levels | Name |
|---|---|
| 1–4 | Extra |
| 5–9 | Regular |
| 10–14 | Cinephile |
| 15–19 | Critic |
| 20–29 | Auteur |
| 30+ | Legend |

### 5.2 Rewards (`rewards` table, slice 3)

`id, name, kind (frame · card_style · canon_decoration · app_icon · header_art), level_required, active, sort`.

**Unlocked** means level ≥ `level_required`; it's derived, not stored. **Equipped** choices live in `user_reward_choices (user_id, kind, reward_id)`.

| Level | Reward | Where it shows |
|---|---|---|
| 5 | Lime profile frame | A 2px primary-accent ring around the avatar on the More card, friend profiles and every feed card (both themes). Others see it too: the app looks up who wears it in batches as avatars appear (`user_reward_choices` is readable through `can_view_user`). |
| 10 | "Noir" card style | Wrapped (`SCR-19`) and the rank-reveal and medal share cards render in greyscale |
| 15 | Gold podium tags | Your Rankings podium's #1–#3 tags use the God-tier gradient instead of lime (`SCR-14`, your own profile only) |
| 20 | Alternate app icons | **Not built yet ([#154](https://github.com/kandraos3/Telly/issues/154)).** The reward stays on the track and unlocks at level 20, but its row reads "Coming soon" and can't be equipped. When built: Settings → App icon (platform alternate icons). |
| 30 | Custom canon header art | A still (TMDB backdrop) from one of your God-tier titles (9.20+), chosen at `/more/level/rewards/header-art`. It shows as a 132 dp banner above your Rankings and at the top of your profile for anyone who can see it. Stored on the `header_art` choice row (`title_id`, `media_type`); `set_header_art` checks level and God tier, `header_art(p_user)` reads it through `can_view_user`. |

Every reward is cosmetic. Nothing that's needed to use Telly is ever locked (decision 0005). A future Telly Pro (#52) must not move these behind a paywall without a new decision.

---

## 6. XP ledger (slice 3)

`xp_ledger (id, user_id, amount INT, source ENUM, ref TEXT, week TEXT, created_at)`, with a **unique `(user_id, source, ref)`**. It's append-only: corrections are new rows with `source = 'correction'`, and no updates or deletes. This keeps every point auditable for a possible later redemption, such as merch (decision 0005).

| Source | XP | `ref` | Limits |
|---|---|---|---|
| `ranking` | +10 | `media_type:title_id` | Qualifying rankings only; **at most 10 a week** (100 XP) |
| `quest` | +40 / +50 / +60 | `week:quest_key` | 3 quests a week |
| `streak` | +25 | `week` | Once per counted week |
| `medal` | +25 | `achievement_id` | Milestone, taste and streak medals |
| `collection` | +100 | `collection_id` | Once per collection |
| `challenge` | +150 seasonal, +100 squad | `challenge_id` | Once per challenge |
| `referral` | reserved for #51 | | |
| `correction` | ± | free text | Written only by the service role |

`my_level() → (level, name, total_xp, level_floor, level_ceiling, week_xp)`.

How it's written (#145): `_award_xp(user)` runs at the end of `evaluate_achievements` (every ranking, duel batch, join, drop and follow, and nightly) and inserts with `ON CONFLICT DO NOTHING`, so it's idempotent. Each row is filed under the week the XP was earned (the ranking's, the unlock's, the completion's), in the user's time zone. Rankings are awarded oldest first, ten per week. Medal XP covers milestone, taste and streak medals only (not Founding Viewer). Clients can read their own rows but never write; rows are never updated; the service role writes `correction` rows. Existing users were backfilled when it shipped.

---

## 7. Collections (slice 2)

- **Data:**
  - `titles.collection_id INT NULL` comes from TMDB `belongs_to_collection`.
  - `title_collections (collection_id PK, name, poster_path, part_ids INT[], released_part_ids INT[], fetched_at)` comes from TMDB `/collection/{id}`, refreshed weekly by `tmdb-details` (when a film in it is opened, and by the half-hourly `tmdb-maintenance` job, which also backfills older titles). Parts are stored as `titles` rows so they can be queued.
  - `titles.production_companies` and `titles.tv_type` come from the same details call (challenge filters, §8.2).
  - Films only: TMDB collections are film collections, so the TV canon has none.
- **Progress:** the number of `released_part_ids` in the user's qualifying rankings, out of the number released.
- **When it appears:**
  - A collection shows on `SCR-23` once the user has ranked one of its films.
  - It's sorted closest-to-done first, with the top 3 shown and the rest under "See all".
  - A finished collection becomes a gold medal (`collection_<id>`) worth +100 XP. The medal row is created by a trigger when the collection is cached: name without "Collection", glyph from initials ("LR", "DK"), target = released films. Collections with fewer than two released films have no medal. A sequel's release raises the target, but a medal already earned stays.

---

## 8. Challenges (slice 2)

### 8.1 Data

`challenges`:

| Column | Notes |
|---|---|
| `id` UUID, `slug` TEXT UNIQUE | e.g. `spooktober-2026` |
| `name`, `description` | "Spooktober", "Rank 8 horror films by Oct 31" |
| `art` | A gradient key (`horror`, `noir`, `gold`…), or a storage path for a hero image |
| `starts_at`, `ends_at` NULL | Open-ended when `ends_at` is NULL |
| `rule` JSONB | §8.2 |
| `target` INT | e.g. 8 |
| `squad_id` UUID NULL | Set for squad challenges |
| `featured` BOOL | At most one featured at a time: featuring a challenge un-features any whose window overlaps it, so each month's featured challenge can be set ahead |
| `template_key` TEXT NULL | Set when generated from a template |
| `status` | `draft · live`. "Ended" is derived from `ends_at`. |
| `created_by` | User, or NULL for official challenges |

`challenge_participants (challenge_id, user_id, joined_at, completed_at NULL) PK (challenge_id, user_id)`.

Also `medal_glyph` (the challenge medal's glyph). Slugs are lowercase words joined by hyphens, at most 50 characters; the medal is `challenge_<slug with underscores>`. `challenge_templates (key, name, description, art, medal_glyph, rule, params, target, active, sort)` holds the templates squads create from; `"$genre"`-style strings in a template's rule, and `$target` / `$genre` in its description, are filled from the creator's values.

### 8.2 Rules

A rule is a media type plus filters that must all match. Rules are data, so a new challenge never needs an app update. Only a new filter *type* does.

```json
{ "media_type": "movie", "filters": [ { "type": "genre", "any": ["Horror"] } ] }
```

| Filter `type` | Matches a title when | Source |
|---|---|---|
| `genre` | Any of its genres is in `any` | `titles.genres` |
| `decade` | Its release year's decade is in `any` (`1970`) | `titles.release_date` |
| `collection` | `titles.collection_id` is in `any` | §7 |
| `titles` | `(id, media_type)` is in `any` (an explicit list, such as Best Picture winners) | |
| `network` | `titles.original_network` is in `any` | |
| `company` | Any of its production companies is in `any` (`A24`) | New `titles.production_companies TEXT[]` from `tmdb-details` |
| `tv_type` | TMDB TV type is in `any` (`Miniseries`) | New `titles.tv_type` from `tmdb-details` |

- `media_type` is `movie`, `tv` or `any`.
- **Progress** is the number of qualifying rankings of matching titles with `created_at` between `starts_at` and `ends_at`. Rankings made before you joined count, as long as they're inside the window.
- **Completing:** reaching `target` sets `completed_at`, unlocks the challenge medal, adds XP and posts `CHALLENGE_COMPLETED` (when sharing; metadata: challenge id, slug, name, count, medal glyph, and the best title by score with its rank and score). It's checked inside `evaluate_achievements`, so it runs after every ranking, duel batch, drop and follow, nightly, and on joining. A finished challenge can't be left. Older apps never receive `CHALLENGE_COMPLETED` rows: `get_activity_feed` needs `p_include_challenges => true`.
- **RPCs:**
  - `challenge_progress(challenge_id) → mine + followed participants`;
  - `join_challenge(id)` and `leave_challenge(id)`;
  - `my_challenges()` and `discover_challenges()`;
  - `challenge_picks(id)` returns matching titles from your Queue first, then titles the people you follow ranked highly, excluding anything already ranked.

### 8.3 Squad challenges

- **Who can create:** a squad's owner or admins, from the templates (§8.4) with their own name and dates.
- **Who sees it:** squad members only.
- **Joining:** members join automatically.
- **Medal:** finishing earns a squad challenge medal; squad challenge XP is +100.

### 8.4 Running challenges after launch (operations)

New and updated challenges reach every installed app on its next open. There are four ways in:
1. **Challenge files in the repo (main path).**
   - One YAML file per challenge in `content/challenges/` (name, dates, art, rule, target, medal glyph).
   - `tool/challenges/publish.py` validates the files and upserts them through the service-role RPC `admin_upsert_challenge`, following the `supabase-deploy` rules. Its `--dry-run` runs in CI on every change.
   - The owner can just ask the agent ("add an Oscars-season challenge for March").
2. **Recurring templates.**
   - `content/challenge_templates/` holds parameterised templates: genre month, decade, collection, network, limited series.
   - `content/challenge_calendar.yaml` maps months to templates and parameters.
   - A monthly scheduled edge function, `challenge-scheduler` (pg_cron), creates the coming month's challenges from the calendar. It also ends the featured flag on expired ones.
   - How it runs (#143): `publish.py` copies the calendar into `challenge_calendar`; `challenge-scheduler` calls `schedule_calendar_challenges(month)` for this month and next (idempotent; each runs from the 1st to the 1st, UTC) and `expire_featured_challenges()`. pg_cron calls it on the 25th and the 1st. Publishing also schedules this month and next at once, so a new calendar entry doesn't wait for the cron. The file schema is in `content/README.md`.
   - **Launch calendar:** six months of challenges are written in slice 2: Spooktober (October 2026, a one-off file), then November 2026 to April 2027 in `content/challenge_calendar.yaml`, with a featured challenge and a second one each month.
3. **The Supabase table editor**, as a manual fallback for urgent fixes (a typo, extending a deadline). Changes made there must be copied back into the repo file the same week.
4. **Squads**, through §8.3.

---

## 9. Screens

All screens use the shared app bars (screen specs §0.2) and the frosted bottom sheet (component library §6), and work in both themes. Routes sit under the More branch.

### 9.1 Medal visual

- **Shape:** a hexagon (54 × 60 dp; small 40 × 45; large 110 × 124) with the glyph centred (Plus Jakarta Sans w800) in `#08090C`.
- **Fills** (fixed in both themes):

| Tier | Fill | Glyph |
|---|---|---|
| Gold | `#FFE066 → #FFA733` (the God-tier gradient, style guide §2.2) | `#08090C` |
| Silver | `#E5E7EB → #94A3B8` | `#08090C` |
| Bronze | `#F5B78A → #B8693A` | `#08090C` |
| Special | `#A78BFA → #7C5CFF` | white |

- **Locked:** an Overlay fill with a dashed `strokeSubtle` outline and the glyph in `textTertiary`.
- **Semantics:** "Gold medal, Middle-earth, unlocked" or "Collection, The Dark Knight Trilogy, 2 of 3".

### 9.2 `SCR-22` More hub additions

- **Tiles:** Achievements (trophy, Warm Amber), Challenges (flag, Electric Cyan `#00F0FF`; light `#00838F`; violet stays reserved for Invite friends, #51) and Your level (bolt, primary accent) join the feature grid after Queue, before Wrapped and Graveyard.
- **Profile card:** shows the pinned medals (small) after the handle.

### 9.3 `SCR-23` Achievements (`/more/achievements`): mockup A1

- **App bar:** ← Achievements, with Share (a card of your pinned medals; added with the share card, #138).
- **Summary card:** "Unlocked N of M" (M counts the listed medals: special medals such as Founding Viewer only once unlocked), and the "▲ N weeks" streak chip, which opens `SCR-27` once Your level ships (#146).
- **Pinned to profile:** three medals with names, in slot order. Tapping one opens its sheet, which has a Pin/Unpin action. Pinning takes the first free slot; when all three are taken, the sheet asks which pinned medal to replace.
- **Sections** in this order:
  - Collections (slice 2, #141): "N in progress", amber progress bars and "2/3", closest to done first with finished ones last; the top three, then "See all N";
  - Milestones;
  - Taste;
  - Streak;
  - Special (only when you hold a special medal).

  Locked medals show with progress ("94/100"; Taste Twin as "78% / 92%"); unlocked ones a check.
- **Medal sheet** (mockup A2): the medal, its name and how it's earned, and a progress bar. For collections ("Collection · Gold when complete", "2 of 3 ranked"), it also lists "Still to watch" (`collection_still_to_watch`: released films you haven't ranked, in release order) with one-tap **+ Queue**, which turns to "✓ In Queue". Then which friends have it (avatar stack) and the rarity line. Unlocked medals add **Pin to profile** and **Share card**.
- **Empty (new user):** every medal is locked with its progress, and the pinned row shows a hint: "Rank titles to earn your first medal".

### 9.4 `SCR-24` Unlock moment: mockup A3

- **What it is:** a full-screen modal over everything, shown on the next app foreground (or right after the ranking) for each unseen unlock, one after another, oldest first. The app shell re-reads medals on resume and when the offline queue finishes syncing; each moment is marked seen when it closes. Offline snapshots never show moments.
- **Layout:**
  - a confetti backdrop (none if reduced motion is on, so nothing sits behind the text);
  - an "Achievement unlocked" chip;
  - the large medal;
  - the name in the display font;
  - one personal line ("The Return of the King came in at #2 in your rankings"). Slice 1 lines come from the medal: "You've ranked 10 films.", "4 weeks in a row with at least one ranking.", "You've called 5 upsets against the crowd.", and so on;
  - rarity and friends;
  - **Pin to profile** (primary; "Pinned to profile" once pinned; when all three slots are taken it opens the medal sheet's replace chooser), **Share card**, and **Done**.
- **Haptics:** a medium impact on show.

### 9.5 `SCR-25` Challenges (`/more/challenges`): mockup C1

- **App bar:** ← Challenges, with **+** for squad owners and admins (#144: a sheet to pick the squad, a template, its params, a name and a length of 7, 14 or 30 days).
- **Featured:** a hero card with art, "FEATURED · N DAYS LEFT", the name, the rule line, joined and friend counts, and your progress if you've joined (a **Join** button if not).
- **Yours:** challenges you've joined that are still live, with progress, and a "Squad" chip for squad challenges.
- **Join next:** live challenges you haven't joined, each with **Join**.
- **Ended:** collapsed. Finished challenges show their medal.
- **Art:** each `art` key maps to a fixed dark gradient (the same in both themes, since the hero text is always light): horror, noir, gold, cyan, violet, coral, lime.
- **Medals:** a challenge's gold medal appears in Yours and Ended (locked until finished); once earned it also shows on `SCR-23` in a "Challenges" section, gets the unlock moment ("You finished the Spooktober challenge.") and can be pinned.

### 9.6 `SCR-26` Challenge (`/more/challenges/:slug`): mockup C2

- **App bar:** ← name, with Share.
- **Progress card:** the rule line, days left (or "Open-ended"), and a large "3 / 8" with a bar.
- **Friends in this challenge:** followed participants and you, sorted by progress, with bars and counts.
- **Picks:** matching titles from your Queue ("Picks from your Queue"), then titles friends ranked ("Friends rate these", with their average score and **+ Queue**).
- **Join / Leave:** an unjoined challenge shows **Join challenge** on the progress card; once joined, **Leave** sits in the app bar's ⋮ menu (finished challenges can't be left). **Share** sends a link with the challenge's line.

### 9.7 `SCR-27` Your level (`/more/level`): mockup B1–B3

- **App bar:** ← Your level, with **?** (a sheet of the XP rules from §6, in plain words).
- **Level card:** a ring (primary-accent progress), the level number, its name, "2,340 / 3,000 XP to Level 13" and a bar.
- **Weekly streak card:** the chip and the 7-week strip (§3), with the freeze line.
- **This week's quests:** three rows with checks, progress and XP chips. They reset on Monday.
- **Streak strip** (#146): counted weeks filled in the primary accent with a check, a used freeze as ❄ on cyan, missed weeks outlined, and the running week labelled "Now"; the others are labelled by ISO week ("W41").
- **Analytics** are detected in the app by comparing a load with what it last saw (kept in `gamification_cache`), and never on the first load: `level_up`, `quest_completed`, `streak_extended`.
- **Fresh on every visit:** Home reads the level from launch (for its streak chip and moves, SCR-21), so opening this screen reads it again. Pull to refresh still works.
- **Offline:** the last snapshot from `gamification_cache`, read-only, with the offline banner.
- **Links:** **Rewards** (`/more/level/rewards`, mockup B2) and **Friends this week** (`/more/level/week`, mockup B3).
  - **Rewards:** the track by level (unlocked rows outlined in lime, locked rows with XP to go and a lock), an Equip / Equipped toggle on unlocked rows (one per kind; tapping Equipped unequips), and the XP rules table. Header art's row says **Choose** (or **Change**) and opens its picker: your God-tier stills, the current one checked, and Remove. The app icon row says **Coming soon** (#154). Equipping sends `reward_equipped`; a failed change shows a snackbar and leaves the row as it was.
  - **Friends this week:** a segmented Friends / each squad. Rank, avatar, name, level, streak and weekly XP, with your row tinted. A footer says it resets Monday.

### 9.8 Weekly quests (slice 3)

- **Templates:** `quest_templates (key, title, rule JSONB (§8.2 filters, or a special kind such as finish_from_queue), target, xp)`.
- **Assignment:** three are assigned per user per week on first read (`my_week()`). The pick is deterministic, seeded by `user_id` and the week, so a refresh never reshuffles them.
- **Mix:** one easy (rank 1–3), one exploration (a genre or decade you rank least), and one Queue quest.
- **Templates** (seeded): easy `rank_one`, `rank_three`, `rank_film` (+40); exploration `explore_genre` ("Rank 2 $genre titles", the least-ranked of a broad genre list) and `explore_decade` ("Rank a film from the $decades", 1950s–2010s) (+50); Queue `queue_one`, `queue_two` (+60), which count rankings of titles you had queued (a `QUEUE_ADDED` activity before the ranking).
- **Progress** is qualifying rankings inside the quest's week (Monday to Monday in your time zone). A met quest completes the next time XP is awarded, which `my_week()` also triggers.

### 9.9 States (all screens)

- **Loading:** skeletons (component library §7.1).
- **Offline:** the last snapshot from a Drift cache (`gamification_cache`, one JSON per screen; Drift schema v3), read-only, with the offline banner ("⚡ Offline Mode • Showing your last saved medals"). Join and Pin wait until you're back online (a snackbar says so).
- **Error:** a retry with the shared empty state.

---

## 10. Feed and privacy

- **Activity types:** `activity_logs.activity_type` gains `MEDAL_UNLOCKED` (slice 1) and `CHALLENGE_COMPLETED` (slice 2), with metadata for the medal (`achievement_id`, `name`, `tier`, `glyph`, `kind`) or the challenge (id, slug, name, count, best title).
- **Older apps:** they would render an unknown activity type as a broken ranking card, so `get_activity_feed` leaves medal rows out unless the caller passes `p_include_medals => true`. Apps that have the medal card (#139) pass it.
- **Feed cards** (Social, `SCR-05`; mockup C3):
  - **Medal card:** the person ("Maya unlocked Centurion", time and tier), the medal, its rarity (read from `achievement_rarity`), and reactions. No poster or Queue button. Opening it shows the comment thread with "Unlocked Centurion" and the medal. Home's Friends line leaves medal posts out.
  - **Challenge card:** the person ("Maya finished Spooktober", "8 of 8"), the medal, "Best of the 8: The Thing (#1, 9.40)", reactions, and **Join** while the challenge is live and you're not in it (looked up with `get_challenge`).
- **Ordinary rankings** made inside a joined challenge show "Spooktober 2 of 8" under the ranking line (`get_activity_feed.challenge_context`: the poster's visible challenge the ranking counted for, featured first, with the count as of that ranking).
- **Unknown types:** the app skips feed rows whose type it doesn't know, rather than drawing them as rankings, so future types never show broken cards.
- **Privacy:** Settings (`SCR-20`) → Privacy → **Share achievements in the feed** (`users.share_achievements`, default on). Off means no medal or challenge posts; unlocks still happen. Quests, level-ups and streaks never post. Private accounts follow the existing visibility rules.

---

## 11. Analytics

PostHog events: `medal_unlocked` (when its unlock moment shows), `medal_pinned` (on a successful pin), `challenge_joined` (on join), `challenge_completed` (when a challenge medal's unlock moment shows), `quest_completed`, `level_up`, `reward_equipped`, and `streak_extended` (weekly).

These measure the goal (people coming back weekly) and catch unhealthy patterns, such as ranking spikes right before a cap resets.

---

## 12. Delivery slices

1. **Slice 1, medals and streak:**
   - qualifying rankings, time zone, weekly streak;
   - medal catalogue, evaluation and rarity;
   - pinning;
   - `SCR-23` (without collections), `SCR-24`;
   - the More tile and profile pins;
   - the medal feed card and the privacy toggle.
2. **Slice 2, collections and challenges:**
   - TMDB collections, companies and TV type;
   - collection medals;
   - challenges, rules and squad challenges;
   - publishing tools and the scheduler, plus the launch calendar;
   - `SCR-25`, `SCR-26`, and the challenge feed card.
3. **Slice 3, levels:**
   - the XP ledger and levels;
   - quests;
   - rewards and cosmetics;
   - the weekly friends table;
   - `SCR-27`.

Each slice ships on its own. The More tiles appear only once their slice ships (SCR-22 "Future entries").
