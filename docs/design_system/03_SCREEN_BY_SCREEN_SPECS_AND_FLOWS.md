# Telly UI/UX Design System: 03 — Screen-by-Screen Specifications & Interaction Details

This document defines every single screen in the Telly application. For each screen, it details the visual layout, exact user inputs, editable elements, action presentations, and state transitions.

---

## Screen Directory & Index

1. **`SCR-01`**: Onboarding Splash & Auth
2. **`SCR-02`**: Streaming Subscriptions Household Setup
3. **`SCR-03`**: Show Recognition Seed Grid
4. **`SCR-04`**: Onboarding Duel Tournament & Canon Unveiling
5. **`SCR-05`**: Social / Activity Feed (Following / Squads / Global)
6. **`SCR-06`**: Post Detail & Spoiler-Safe Comment Thread
7. **`SCR-07`**: Explore & Discover Hub
8. **`SCR-08`**: Show Detail Page (Metadata, Seasons, Friends' Ranks)
9. **`SCR-09`**: The Logging Studio & Sentiment Bracket Selector
10. **`SCR-10`**: The Binary Duel Arena
11. **`SCR-11`**: Editorial Tags, MVP Character & Review Sheet
12. **`SCR-12`**: Canon Slot Reveal & Score Confirmation
13. **`SCR-13`**: Smart Queue (Universal Watchlist)
14. **`SCR-14`**: Canon: The Personal Dual-Canon (Ranked podium, Tiers, 3x3)
15. **`SCR-15`**: Friend Profile & Taste Match Comparison
16. **`SCR-16`**: "Two-to-Watch" Co-Watching Decider
17. **`SCR-17`**: Squads Hub & Consensus Leaderboard
18. **`SCR-18`**: TV Graveyard (Dropped / DNF Tracker)
19. **`SCR-19`**: Telly Wrapped & Shareable Asset Studio
20. **`SCR-20`**: Settings, Account & Data Export
21. **`SCR-21`**: Home
22. **`SCR-22`**: More Hub
23. **`SCR-23`**: Achievements (medals): [features/10](../features/10_GAMIFICATION_MEDALS_CHALLENGES_AND_LEVELS.md) §9.3
24. **`SCR-24`**: Unlock moment: features/10 §9.4
25. **`SCR-25`**: Challenges: features/10 §9.5
26. **`SCR-26`**: Challenge detail: features/10 §9.6
27. **`SCR-27`**: Your level (with Rewards and Friends this week): features/10 §9.7

---

### §0.0 App Shell & Route Map — epic #44

> Tracking: epic #44 · Status: shipped · Decision: [0003](../decisions/0003-five-tab-shell-with-more-hub.md)

Five tabs in the floating bar (component library §2.1), plus the floating Log button (§2.3) on the first four. Signed-in users land on **Home** (`/home`).

| Tab | Root route | Root screen | Pushed from it |
| :--- | :--- | :--- | :--- |
| Home | `/home` | `SCR-21` Home | none |
| Explore | `/explore` | `SCR-07` Explore | `/explore/row/:rowId?canon=movie\|tv` (`SCR-07` See all) |
| Canon | `/canon` | `SCR-14` Canon | none |
| Social | `/social` | `SCR-05` Feed | `/social/activity/:id` (`SCR-06`) |
| More | `/more` | `SCR-22` More hub | `/more/queue` (`SCR-13`), `/more/queue/lists`, `/more/queue/list/:id`, `/more/graveyard` (`SCR-18`), `/more/wrapped` (`SCR-19`), `/more/settings` (`SCR-20`), `/more/edit`, `/more/achievements` (`SCR-23`), `/more/challenges` (`SCR-25`), `/more/challenges/:slug` (`SCR-26`), `/more/level`, `/more/level/rewards`, `/more/level/week` (`SCR-27`) |

Unchanged, pushed over the shell: the `/log` flow (`SCR-09` to `SCR-12`), `/title/:mediaType/:id` (`SCR-08`), `/u/:handle` (`SCR-15`), `/cowatch` and `/u/:handle/two-to-watch` (`SCR-16`), `/squads` and `/squads/:id` (`SCR-17`, opened from Social).

**Redirects** (old links in shares, notifications and password-reset mails keep working): `/feed` → `/social`, `/feed/activity/:id` → `/social/activity/:id`, `/queue` → `/more/queue`, `/queue/list/:id` → `/more/queue/list/:id`, `/canon/{settings,edit,graveyard,wrapped}` → `/more/{…}`.

### §0 Shared Tab Header (Home, Explore, Canon, Social, More) — `FE-HEADER-01`

The five tab screens (`SCR-21`, `SCR-07`, `SCR-14`, `SCR-05`, `SCR-22`) share one header, `TellyScreenHeader`:

```
┌────────────────────────────────────────────────────────┐
│  Title                                 [ a ] [ b ] [ c ]│
└────────────────────────────────────────────────────────┘
```

* **Title:** the tab's name in sentence case, no emoji: Plus Jakarta Sans 24 / ExtraBold (w800) / −0.5 letter spacing, `textPrimary`. Announced as a heading.
* **Row:** 56 dp tall, 16 dp gutters (the last icon glyph sits 16 dp from the edge), canvas background, no divider or elevation.
* **Actions:** up to three 48 dp icon buttons in `textSecondary`, each with a tooltip and a selection-click haptic. They vary per screen:

| Screen | Title | Actions |
| :--- | :--- | :--- |
| `SCR-21` Home | Home | Search (opens Explore with the search field focused) |
| `SCR-07` Explore | Explore | none (the search bar sits directly below) |
| `SCR-14` Canon | Canon | Stats (sheet), View (sheet; icon shows the current view), Share profile |
| `SCR-05` Social | Social | My Squads, Search |
| `SCR-22` More | More | none |

* **Scroll behavior:** the header scrolls away as the content scrolls down, and any upward scroll snaps it back in full, wherever the content is; there is no need to return to the top. Controls under the header (Social filter tabs and Movies / TV Shows tabs) stay in place.

#### §0.2 Pushed Screens — `FE-HEADER-02`

Every screen opened on top of the tabs uses `TellySubpageAppBar`, the same design one step down:

```
┌────────────────────────────────────────────────────────┐
│ [←]  Settings                                          │   drill-in screens
│ [✕]  Edit profile                               Save   │   task / modal screens
│ [←]  The Apartment                         [👤+]  [⋮]  │   optional quiet subtitle
│      5 members                                         │
└────────────────────────────────────────────────────────┘
```

* **Title:** sentence case, no emoji, left-aligned: Plus Jakarta Sans 20 / ExtraBold (w800) / −0.3, `textPrimary`, announced as a heading. Names people typed (squads, lists) are shown as typed, never upper-cased. An optional second line (`labelMedium`, `textSecondary`) carries a count or context ("5 members").
* **Leading:** one back arrow (`arrow_back_rounded`, "Back") for screens you drill into, one close (`close_rounded`, "Close") for tasks you dismiss, in `textPrimary`. Full-screen flows without an app bar (Duel arena, Canon reveal) use the same close button, on the left.
* **Actions:** the same muted 48 dp icons as the tab header. At most one accented action per screen, its primary one (Save on Edit profile, Follow on a friend's profile). Destructive actions (Delete list, Delete / Leave squad) live in a muted ⋮ menu, never as a bare coloured icon.
* **Scroll behavior:** fixed. Only the five tab headers hide on scroll, so Back / Close is always one tap away.
* **Theme default:** `TellyTheme`'s `AppBarTheme` uses the same title style, left alignment and canvas background, so an app bar that sets nothing still matches.
* **Out of scope:** onboarding (`SCR-01` to `SCR-04`) keeps its own step header, and the show detail page (`SCR-08`) keeps its backdrop header with the shared back button. Once its in-page title scrolls under the collapsed bar, the bar fades in the title name in the subpage title style (`FE-HEADER-03`).

| Screen | Leading | Title | Actions |
| :--- | :--- | :--- | :--- |
| `SCR-06` Comments | ✕ | Comments | none |
| `SCR-13` Queue | ← | Queue | Lists (opens the Lists screen). Sort lives in the Filter sheet under the app bar |
| `SCR-13` Lists | ← | Lists | New list (+) |
| `SCR-09` Log a show | ✕ | Log a show | none |
| `SCR-10` Duel arena | ✕ | "Duel 2 of 4", centred (progress) | none |
| `SCR-12` Canon reveal | ✕ | none | none |
| `SCR-15` Friend profile | ← | @handle | Follow (accent) or Edit Profile |
| `SCR-16` Two-to-Watch | ✕ | Two-to-Watch | none |
| `SCR-17` My Squads / Squad | ← | My Squads / squad name + "N members" | My Squads: New squad (+). Squad: Invite, ⋮ (Delete / Leave) |
| `SCR-18` TV Graveyard | ← | TV Graveyard | Log dropped show (+) |
| `SCR-19` Story studio | ✕ | Story studio | Share |
| `SCR-20` Settings | ← | Settings | none |
| Edit profile | ✕ | Edit profile | Save (accent) |
| Custom list | ← | list name | Share, ⋮ (Delete) |
| Legal documents, placeholders | ← | document / screen name | none |

---

### `SCR-01`: Onboarding Splash & Authentication

```
┌────────────────────────────────────────────────────────┐
│                                                        │
│                     [ 📺 TELLY ]                       │
│              Your Personal TV Canon.                   │
│               Ranked, Shared, Settled.                 │
│                                                        │
│  [ Ambient cinematic montage video with dark overlay ] │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │   [] Continue with Apple                        │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │   [G] Continue with Google                       │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │   [💬] Continue with Phone Number                │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  By continuing, you agree to our Terms & Privacy.      │
└────────────────────────────────────────────────────────┘
```

- **Layout & Structure:** Fullscreen ambient background video (prestige television sequences) dimmed by a 70% black vignette. Logo and tagline at top third. Action buttons stacked at bottom with 12px gaps.
- **User Inputs:**
  - Single tap on Apple / Google / Phone buttons.
  - If Phone: Slide-up modal with 10-digit number field and 6-digit SMS OTP code entry.
- **Actions & Presentations:**
  - `Continue with Apple`: Solid white button, black text (`#000000`).
  - `Continue with Google`: `#1A1D27` button with Google multicolor 'G' icon.
  - `Continue with Phone`: Bordered ghost button (`1px solid #3D4259`).
- **State Transitions:** Upon authentication success, transitions to `SCR-02` via horizontal slide transition (300ms ease-in-out).

---

### `SCR-02`: Streaming Subscriptions Household Setup

```
┌────────────────────────────────────────────────────────┐
│ [← Back]              STEP 1 OF 3                      │
│                                                        │
│  Where do you watch?                                   │
│  Select your active subscriptions so we can tailor     │
│  recommendations and co-watch deciders.                │
│                                                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │ Netflix  │  │   Max    │  │Apple TV+ │              │
│  │   [✓]    │  │   [✓]    │  │   [✓]    │              │
│  └──────────┘  └──────────┘  └──────────┘              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │   Hulu   │  │ Disney+  │  │  Prime   │              │
│  │   [ ]    │  │   [✓]    │  │   [ ]    │              │
│  └──────────┘  └──────────┘  └──────────┘              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │Paramount+│  │Crunchyrol│  │Criterion │              │
│  │   [ ]    │  │   [✓]    │  │   [✓]    │              │
│  └──────────┘  └──────────┘  └──────────┘              │
│                                                        │
│  [✓] Include free platforms (Tubi, Pluto, Kanopy)      │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Continue (6 Selected)  →                        │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

- **User Inputs:**
  - Multi-select grid tiles (tap to toggle on/off).
  - Checkbox toggle for free ad-supported streaming services (FAST).
- **What User Can Change:** Any selection at any time; persisted in `user_streaming_subscriptions`.
- **Action Presentation:** Sticky floating bottom button in Phosphor Lime (`#D2FF52`). Displays real-time count: *"Continue (X Selected)"*.
- **Transitions:** Push forward to `SCR-03`.

---

### `SCR-03`: Movie, Series & Anime Recognition Seed Grid

```
┌────────────────────────────────────────────────────────┐
│ [←]                   STEP 2 OF 3             [Search] │
│                                                        │
│  Tap titles you've watched (5/8)                       │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ [ 🎬 1-Click Import from Letterboxd (CSV/User) ] │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │ [ ⚡ 1-Click Import from AniList / MyAnimeList ] │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  Filter: [ All (50) ] [ 🎬 Movies ] [ 📺 Series ] [ ⚡ ]│
│                                                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │ [Poster] │  │ [Poster] │  │ [Poster] │              │
│  │Interstell│  │Severance │  │Parasite  │              │
│  │   [✓]    │  │   [✓]    │  │   [✓]    │              │
│  └──────────┘  └──────────┘  └──────────┘              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │ [Poster] │  │ [Poster] │  │ [Poster] │              │
│  │Spirited A│  │Succession│  │Attack on │              │
│  │   [✓]    │  │   [✓]    │  │ Titan [ ]│              │
│  └──────────┘  └──────────┘  └──────────┘              │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Select 3 more to begin tournament               │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

- **User Inputs:**
  - Tap card: Toggles green checkmark badge overlay on poster and adds to selected array.
  - Media filter pills: Filters grid between All, Movies, Series, and Anime.
  - Search icon in header: Opens instantaneous search sheet to query any movie or show from TMDB or AniList.
  - 1-Click Import Buttons:
    - Letterboxd: Uploads `diary.csv` or imports public profile to pre-seed the Movie Canon.
    - AniList / MyAnimeList: Connects via GraphQL to ingest completed anime lists into the Series & Anime Canon.
- **Dynamic Elements:** Bottom button is disabled (`#242938`) with counter text until 8 titles are selected; upon 8th selection, button flashes in Phosphor Lime with medium haptic pulse and text: *"Start Ranking Duels (5 Battles) →"*.

---

### `SCR-04`: Onboarding Duel Tournament & Starter Canon Reveal

- **Visual Layout:** Fullscreen Duel Arena (see `SCR-10`). Runs 5–7 pairwise binary comparison battles between the selected shows.
- **After Final Duel:** Immediate transition to the **Celebration Screen**:
  - Golden confetti particle burst.
  - Carousel of the newly formed Top 5 Leaderboard with dynamic decimal scores (`9.85`, `9.42`, `9.10`, etc.).
  - Primary Action: `[ Add Friends & Finish ]`.
  - Secondary Action: `[ Share to Instagram Story ]`.

---

### `SCR-05`: Social / Activity Feed (Following / Squads / Global)

The **Social** tab (`/social`). It was the landing tab until epic #44; Home (`SCR-21`) is now.

```
┌────────────────────────────────────────────────────────┐
│  Social                                 [ 👥 ] [ 🔍 ]  │
│  [ Following ]  [ Squads ]  [ Global ]                 │
├────────────────────────────────────────────────────────┤
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ (👤) Jordan Miller @jordan • 3h ago    [🚨 UPSET]│  │
│  │ Ranked SEVERANCE (#2) over SUCCESSION (#4)       │  │
│  │                                                  │  │
│  │ ┌──────┐  "Season 2 finale broke my brain.       │  │
│  │ │ [IMG]│   Elevator sequence was pure genius."   │  │
│  │ └──────┘                                         │  │
│  │ Score: 9.72 • 👑 God Tier                        │  │
│  │                                                  │  │
│  │ [ + Want to Watch ]        [ 🔥 18 ] [ 🤯 9 ] [💬 4]│  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ (👤) Maya Lin @maya • 5h ago          [💀 DROPPED]│  │
│  │ Dropped THE MORNING SHOW at S2:E03               │  │
│  │ Reason: "Writing jumped the shark"               │  │
│  │                                                  │  │
│  │ [ + Want to Watch ]        [ 🤝 12 ] [ 🗑️ 6 ] [💬 2]│  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
└────────────────────────────────────────────────────────┘
```

- **Top Navigation:**
  - Left: Minimalist Telly phosphor neon glyph.
  - Center: Feed Segment Dropdown: `Following (Default)` | `My Squads (Roommates, Cinephiles)` | `Global Community`.
  - Right: Quick Search icon.
- **User Actions Available on Each Card:**
  1. `Tap Poster / Title`: Opens Show Detail (`SCR-08`).
  2. `Tap Friend Avatar / Username`: Opens Friend Profile & Taste Match (`SCR-15`).
  3. `Tap "+ Want to Watch"`: 1-tap instant save to personal Queue. Button changes to `[ ✓ In Queue ]`.
  4. `Tap Reaction Emoji (🔥 / 🤯 / 🗑️)`: Adds reaction; increments counter with spring animation.
  5. `Tap Comment Icon / Bubble`: Opens Spoiler-Safe Comment Bottom Sheet (`SCR-06`).
  6. `Long-press Card`: Context menu: *Share Log, Hide User from Feed, Report Spoiler*.

---

### `SCR-06`: Post Detail & Spoiler-Safe Comment Thread

```
┌────────────────────────────────────────────────────────┐
│ [✕]  Comments                                          │
├────────────────────────────────────────────────────────┤
│  [ Original Post Card summarized ]                     │
├────────────────────────────────────────────────────────┤
│                                                        │
│  (👤) Alex Rivera @alex • 1h ago                       │
│  How could you rank it over Succession though? Logan   │
│  Roy's funeral episode is untouchable.                 │
│                                                        │
│  (👤) Jordan Miller @jordan • 45m ago                  │
│  True, but Severance hasn't had a single wasted scene. │
│  Spoiler: [ ▓▓▓▓ TAP TO REVEAL SPOILER ▓▓▓▓ ]         │
│                                                        │
├────────────────────────────────────────────────────────┤
│  [ 💬 Add your take... (Markdown & spoilers supported) ]│
└────────────────────────────────────────────────────────┘
```

- **User Inputs:**
  - Text input field with keyboard focus.
  - Toggle button: `[ ⚠️ Tag as Spoiler ]`.
  - Send button (active only when text length $> 0$).
- **Spoiler Mask Interaction:** Comments marked as spoilers render with a blurred, frosted glass overlay (`backdrop-filter: blur(8px)`). Tapping reveals the text; tapping again re-blurs it.

---

### `SCR-07`: Explore & Discover Hub

> Tracking: epic #46 · Status: approved · Decision: [0007](../decisions/0007-explore-hero-rows-and-client-ranker.md) · Mockup: [0046](mockups/0046-explore-rows.html) · Rules and scoring: [features/07 §7](../features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md#7-explore-rows--recommendation-engine)

```
┌────────────────────────────────────────────────────────┐
│  Explore                                               │  TellyScreenHeader, no actions
│  [ ⌕ Search titles, people, friends                 ]  │
│  [   Movies 142   |   Series 94   ]                    │  slim TellyCanonSwitcher, sticky
│  ┌──────────────────────────────────────────────────┐  │
│  │  [ backdrop, fades to scrim ]                    │  │  Hero, 252 dp
│  │  TOP PICK FOR YOU · 94% MATCH                    │  │
│  │  Decision to Leave                               │  │
│  │  Like Parasite (9.72) and Memories of Murder…    │  │
│  │  [ + Queue ]  [ Details ]  [ Not for me ]        │  │
│  └──────────────────────────────────────────────────┘  │
│  Trending now                             See all ›    │
│  Top 10 movies this week                               │
│  1▕▔▔▏ 2▕▔▔▏ 3▕▔▔▏                                     │  numbered Top 10
│  Top picks for you · Because you ranked Parasite ·     │
│  Your friends are watching · Leaving your services     │
│  soon · Something different · (Series) Network         │
│  battlegrounds                                         │
└────────────────────────────────────────────────────────┘
```

* **Order**: search bar (44 dp, `color-surface-raised`, 14 dp radius), then 12 dp, then the slim `TellyCanonSwitcher`, which sticks under the status bar once scrolled. Below it come the hero and the rows in the order of features/07 §7.2, 20 dp apart. Curated canons are removed.
* **Row header**: title in Plus Jakarta Sans 16.5 / w800, `textPrimary`, with *Because you ranked* followed by the seed in Playfair Display italic. An optional subtitle sits under it in 12 / `textTertiary`. **See all ›** is 12 / w700, `textTertiary`, a 48 dp touch target. The header is announced as a heading.
* **Poster card** (Top picks, Because, Something different, Leaving soon): 104 × 154 dp poster, 10 dp radius, 10 dp gap, 16 dp gutters. Under the poster: the title (12.5 / w700, one line, ellipsis) and one meta line (11 / `textTertiary`), which for match rows is *"94% match"* in w800 `electricVioletOf`. A provider chip in the poster's bottom-right corner shows when it streams on one of my services.
* **Hero**: 252 dp, 18 dp radius, glass border. Backdrop (`backdrop_path`, else the poster) under a gradient to the canvas colour at 78%. Eyebrow *"TOP PICK FOR YOU · 94% MATCH"* (10.5 / w800, 0.1 em tracking, `electricVioletOf`); title in Playfair Display 26 / w700; reason line 12.5 / `textSecondary` (features/07 §7.4); buttons **+ Queue** (lime primary), **Details**, **Not for me**.
* **Trending now**: 92 × 136 dp posters, each led by its rank as an outlined 92 dp numeral (2 dp `textTertiary` stroke, no fill), overlapping the poster by 14 dp. The numeral is decorative; the card reads *"Number 1 trending, Anora"*.
* **Because you ranked *X***: the first tile is the seed itself, a dashed `strokeSubtleOf` card on `color-surface-raised` reading *YOU RANKED / Parasite / #2 · 9.72*, with the score in `warmAmberOf`. Tapping it opens the seed's title page.
* **Your friends are watching**: 214 × 112 dp cards (`color-surface-raised`, 14 dp radius, 10 dp padding), each with a 56 × 84 poster, the title, friend names (*"Maya, Jo and Sam"*, or *"Maya and 4 others"*), up to 3 overlapping 22 dp avatars, and *"★ 8.6 friends' avg"* in `warmAmberOf`.
* **Leaving your services soon**: poster cards with a countdown badge in the top-left corner: *"3 DAYS"* / *"LAST DAY"*, 9.5 / w800 on `neonCoralOf`, text `TellyColors.backgroundPrimary` (dark) / white (light). White on dark-theme coral is about 3.2 : 1, so it isn't used. The meta line is the service name.
* **Larger text** (#197): the heights above are at 1.0× system text. Each box that holds text is its fixed part plus its text lines, scaled by the system text size, so it equals the size above at 1.0× and grows instead of clipping:
  * hero: 149 dp + 103 dp of text (eyebrow, two title lines, two reason lines);
  * poster rows: 164 dp + 32 dp (title and meta lines);
  * friend cards: 62 dp + 50 dp (title, names and average lines).

  The seed tile keeps the poster's 104 × 154 size, so its text scales down to fit instead. The friends' average stays on one line.
* **New user**: the prompt card (`color-surface-raised`, 18 dp radius), *"Rank 3 movies to unlock your picks"*, with progress dots (lime when filled) and **+ Log a movie**.
* **States**: loading skeleton, offline banner, error with **Try again**, and hidden empty rows, exactly as features/07 §7.5.
* **Screen readers**: each row header is one heading that includes its subtitle (*"Trending now, Top 10 movies this week"*). The hero's eyebrow, title and reason line are read as one heading (*"Top pick for you, 84% match: Decision to Leave. Like Parasite (9.72)…"*), followed by its three buttons. Every card is one button whose label carries its meta line.
* **Pull to refresh** refetches the selected canon. The indicator sits around the floating-header scroll view and also listens to the rows' list inside it, since a pull at the top never reaches an indicator placed inside.
* **User actions**:
  * The search bar opens the instant search (unchanged): TMDB and user results, with recent searches and Trending as the zero state.
  * Tapping a poster opens `SCR-08`. The hero's **+ Queue** and **Not for me** (with Undo) work as described in features/07 §7.5.
  * **See all ›** opens `/explore/row/:rowId?canon=`, a 3-column grid of up to 30 titles (features/07 §7.5): a subpage app bar with the row's title (a Because row's says *Because you ranked <seed>*) and subtitle, then 104:154 poster cards that fill the column, 10 dp apart across and 16 dp down, 16 dp gutters, each with its title and the row's meta line. An unknown row or canon shows *"This list isn't available"*.
  * Network battlegrounds (Series only): **See full network rankings →** (unchanged).

---

### `SCR-08`: Show Detail Page

```
┌────────────────────────────────────────────────────────┐
│ [← Back]                                      [Bookmark]│
├────────────────────────────────────────────────────────┤
│ ┌────────────────────────────────────────────────────┐ │
│ │  [ Full-bleed 16:9 Backdrop with Gradient Fade ]   │ │
│ └────────────────────────────────────────────────────┘ │
│  ┌────┐  SEVERANCE                                     │
│  │Post│  Apple TV+ • 2 Seasons • 2022–                 │
│  │ er │  Creator: Dan Erickson • Star: Adam Scott      │
│  └────┘  Community Score: 9.34 (God Tier)              │
│                                                        │
│  STREAMING NOW:                                        │
│  [ ▶ Watch Season 2 on Apple TV+ (App Launch) ]        │
│                                                        │
│  YOUR STATUS:                                          │
│  [ ⭐ Ranked #2 in Your Canon (Score: 9.72) ]          │
│  [ 🔄 Re-Duel / Change Rank ]                          │
│                                                        │
│  ━ FRIENDS WHO RANKED THIS (14) ━━━━━━━━━━━━━━━━━━━━━  │
│  • Jordan (#2 • 9.72) • Maya (#3 • 9.50) • Chris (#14) │
│                                                        │
│  ━ SEASONS ACCORDION ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  [▼] Season 1 (2022) • 9 Episodes • Avg: 9.45          │
│  [▶] Season 2 (2025) • 10 Episodes • Avg: 9.60         │
│                                                        │
│  ━ COMMUNITY SURVIVAL RATE ━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  92% Completed S1 • 78% Up to Date • Drop point: S1E04 │
└────────────────────────────────────────────────────────┘
```

- **User Actions:**
  - `Watch Button`: Deep-links into the native streaming application installed on the device.
  - `Re-Duel Button`: Opens Duel Arena to recalibrate position in personal canon.
  - `Seasons Accordion`: Expands episode-by-episode breakdown with individual episode synopses and guest stars.

---

### `SCR-09`: The Logging Studio & Sentiment Bracket Selector

```
┌────────────────────────────────────────────────────────┐
│ [✕]  Log a show                                        │
├────────────────────────────────────────────────────────┤
│  Selected: THE BEAR (FX / Hulu)                        │
│                                                        │
│  1. HOW MUCH DID YOU WATCH?                            │
│  (•) Finished Whole Series                             │
│  ( ) Up to Date (Waiting for Next Season)              │
│  ( ) Watched Specific Season (e.g. Season 1 only)      │
│  ( ) Dropped / Stopped Watching                        │
│                                                        │
│  2. INITIAL SENTIMENT BRACKET                          │
│  Where does this roughly belong in your taste canon?   │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 👑 Masterpiece / Top 10%                         │  │
│  │    "Life-changing, flawless television"          │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │ ✨ Loved It / Top 25%                            │  │
│  │    "Outstanding, highly recommended"             │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 👍 Liked It / Middle 40%                         │  │
│  │    "Solid, enjoyable, some flaws"                │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 🤷 Meh / Bottom 25%                              │  │
│  │    "Forgettable, background noise"               │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │  BEGIN PAIRWISE DUELS (3-4 BATTLES)  →           │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

- **User Inputs:**
  - Radio button for watch completion status.
  - Single-select sentiment card. Selected card highlights in glowing Phosphor Lime with checkmark.
- **Action:** Tapping *"Begin Pairwise Duels"* launches the binary search tournament in `SCR-10`.

---

### `SCR-10`: The Binary Duel Arena

*(Detailed layout in Section 4 of Component Library `02_COMPONENT_LIBRARY_AND_PATTERNS.md`)*
- **User Inputs:**
  - Tap Card A: Card A wins battle.
  - Tap Card B: Card B wins battle.
  - Swipe Up: Card A wins.
  - Swipe Down: Card B wins.
  - Tap *"🤷 Equal / Can't Compare"*: Triggers neighbor comparison step.
  - Tap *"✕ Cancel"*: Aborts logging with confirmation dialog (*"Progress will be discarded"*).

---

### `SCR-11`: Editorial Tags, MVP Character & Review Sheet

```
┌────────────────────────────────────────────────────────┐
│ [←]               DETAILS & NOTES             [Skip]   │
├────────────────────────────────────────────────────────┤
│  INTERSTELLAR • Placed at #1 in Your Movie Canon!      │
│                                                        │
│  VIEWING VENUE (Movies Only)                           │
│  [ Theatrical / IMAX [✓] ] [ Home Streaming ] [ Flight ]│
│                                                        │
│  REWATCH STATUS                                        │
│  [ First-Time Watch ]  [ Rewatch (Logged 3 times) [✓] ]│
│                                                        │
│  WHO DID YOU WATCH WITH?                               │
│  [ + Tag Friends (@maya, @alex)                      ] │
│                                                        │
│  TAG THE VIBE (Up to 3)                                │
│  [#CinematographyPeak] [#MindBending] [#GreatScore]    │
│  [#EmotionalWreck] [#PacingPerfection] [#Masterpiece]  │
│                                                        │
│  DIRECTOR & STANDOUT PERFORMANCE                       │
│  • Director: Christopher Nolan (Auto-tagged)           │
│  • MVP: [ Matthew McConaughey as Cooper              ▾]│
│                                                        │
│  HOT TAKE / MICRO-REVIEW (280 chars max)               │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Seeing the 70mm IMAX re-release reminded me that │  │
│  │ Zimmer's organ score and the docking sequence are│  │
│  │ cinema at its highest power.                     │  │
│  └──────────────────────────────────────────────────┘  │
│                                              (148/280) │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │  PUBLISH TO CANON & BROADCAST FEED  →            │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

- **User Inputs:**
  - *Contextual Venue selector (Movies)*: Theatrical/IMAX, Home Streaming, Film Festival, In-Flight.
  - *Rewatch counter*: Increment/decrement stepper if marked as rewatch.
  - *Binge Velocity (Series)*: Weekend Binge, Weekly Airing, Slow Burn.
  - Multi-select vibe tag chips (max 3 selectable; tapping 4th deselects oldest).
  - Character dropdown: Populated dynamically with primary cast members from TMDB credits.
  - Micro-review text area: Character counter with auto-trim at 280 characters.
- **Action:** `Publish to Canon & Broadcast Feed` commits database transaction, triggers celebratory haptics, and routes to `SCR-12`.

---

### `SCR-12`: Canon Slot Reveal & Score Confirmation

```
┌────────────────────────────────────────────────────────┐
│                                                        │
│                 🎉 CANON UPDATED!                      │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ ┌──────────┐  THE BEAR                           │  │
│  │ │ [Poster] │  Rank: #05 of 84 Shows              │  │
│  │ │          │  Calculated Score: 9.41 / 10.0      │  │
│  │ └──────────┘  Tier: 👑 GOD TIER                  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  Beating: Chernobyl (#6), Fleabag (#7)                 │
│  Just behind: Severance (#4), Breaking Bad (#3)        │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │  [📸 Share to Instagram Story]                   │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │  [ View on My Canon Profile ]                    │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

- **Visual Effects:** 3D spring flip animation of the card into the slot. Score counts up from `0.00` to `9.41` in 600ms (`tnum` font animation).
- **Share Action:** Renders a 1080x1920 Instagram Story sticker image showing the duel outcome and sends directly to native OS share sheet.

---

### `SCR-13`: Smart Queue (Universal Watchlist)

> Tracking: epic #47 · Status: shipped · Decision: [0004](../decisions/0004-canon-podium-and-queue-up-next.md) · Mockup: [0047](mockups/0047-canon-queue-layouts.html)

Opened from the More hub (`/more/queue`) as a pushed screen with the subpage app bar (§0.2). It shows your watchlist and leads with one title to watch next. Custom lists live on their own **Lists** screen (`/more/queue/lists`), opened from the app bar.

```
┌────────────────────────────────────────────────────────┐
│ [←]  Queue                                       [ ☷ ] │  ☷ = Lists
│  [   Movies 14   |   TV Shows 24   ]      [ ⚲ Filter ① ]│  one control row
├────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐  │
│  │ [backdrop art, 168 dp]                [↻ Another]│  │
│  │ UP NEXT                                          │  │
│  │ The Bear                                         │  │
│  │ Disney+ · 3 seasons · ★ 8.60 · saved from @maya  │  │
│  ├──────────────────────────────────────────────────┤  │
│  │ [ ▶ Watch on Disney+               ]  [ ✓ Seen ] │  │
│  └──────────────────────────────────────────────────┘  │
│  ━ THEN ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 23   │
│  [img] Slow Horses       Apple TV+ · 4 seasons · ★ 8.94 [▶ Apple TV+]│
│  [img] Station Eleven    Max · 1 season · ★ 8.81        [▶ Max]      │
│  …                                                     │
└────────────────────────────────────────────────────────┘
```

- **App bar:** ← Queue, with one action: **Lists** (`collections_bookmark_outlined`, tooltip "Lists", key `queue_lists_button`), which pushes the Lists screen. Sort and New list no longer sit in this app bar.
- **Control row** (16 dp gutters, 8 dp gap, 12 dp below the app bar):
  - **Switcher:** the compact canon switcher (component library §5.5), expanded to fill the row. Movies on the left, each half with its count. Movies and TV Shows never mix.
  - **Filter chip:** the Filter button chip (component library §5.4), key `queue_filter_button`. It opens the Filter sheet.
- **Filter sheet** (bottom sheet, component library §6):
  - **SORT BY**: *Friends' score* (default), then *Leaving soon*. These are radio rows with a check in the primary accent (keys `queue_sort_option_friends_score`, `queue_sort_option_leaving_soon`). Choosing one closes the sheet.
  - **SHOW**: a switch, *Only on my services*, with the subtitle "Hide titles you can't stream" (key `queue_services_toggle`). Toggling it keeps the sheet open.
  - The chip's badge counts the active filters. Today only *Only on my services* counts; the sort order never does.
- **Up next card**: the first item, key `queue_up_next_card`.
  - **Art:** 16 dp gutters, radius 18, glass border. The art is 168 dp tall: the title's backdrop, or its poster cropped to fill when there is no backdrop. A scrim runs from transparent at 20% to `#08090C` at 92%, in both themes, so the text on it is always light.
  - **Text on the art:** first the eyebrow "UP NEXT" (caption w800, 1.2 letter spacing, `#D2FF52` in both themes because it sits on the scrim). Then the title (`titleLarge` w800, white). Then one meta line in `#C8CAD8`: provider · seasons (or runtime for a movie) · ★ friends' average · "saved from @handle" when known. A coral **LEAVING SOON** tag follows when it applies.
  - **↻ Another** (key `queue_up_next_shuffle`, 48 dp target): a frosted pill in the art's top-right corner. It picks a different title. It's hidden when the pool holds only one title.
  - **Bar:** on Surface, with 12 dp padding. It holds **▶ Watch on <provider>**, the primary button (Phosphor Lime fill, the same deep link as before), and **✓ Seen**, a secondary button on Overlay that does the same as a swipe right.
  - **Tapping the card** anywhere else opens the title page (`SCR-08`).
- **How Up next is chosen:** for now, a uniformly random pick (a smart pick is tracked in #124).
  - The **pool** is the titles the screen shows for the selected canon after the filter.
  - A pick is made when the Queue opens. Each canon keeps its own pick while the screen stays open, so switching Movies ↔ TV Shows and back doesn't re-roll.
  - **↻** picks at random from the pool minus the current pick, so the same title never comes up twice in a row.
  - If the current pick leaves the pool (it's marked seen, removed, or filtered out), a new pick is made at once.
  - The pick isn't repeated in the rows below it.
- **Rows** (*THEN*): first a `TellySectionHeader` "THEN" with the count of rows. Each row:
  - **Layout:** 16 dp gutters, a 40 × 58 poster (radius 6), the title (`bodyLarge` w700, one line), and a meta line in `textTertiary`: seasons or runtime · ★ friends' average in Warm Amber. A coral LEAVING SOON tag follows when it applies. Hairline `strokeSubtle` dividers separate the rows.
  - **Trailing:** one **▶ <provider>** button (Overlay, glass border, `labelMedium` w800, 48 dp target) with the same deep link.
  - **Tap** opens the title page. Rows are sorted by the Filter sheet's choice.
- **Swipe** (rows and the Up next card):
  - **Right:** mark seen. The title leaves the watchlist, and the Log flow opens prefilled with it (`/log`, `SCR-09`). The background is Phosphor Lime with a check.
  - **Left:** remove from the watchlist. The background is Neon Coral with a trash icon, and a snackbar offers **Undo**.
- **States:**
  - **Loading:** a skeleton card in place of Up next, plus 5 skeleton rows (component library §7.1).
  - **Empty watchlist:** the existing `TellyEmptyState`, which leads to Explore, replaces the card and the rows.
  - **Empty after the filter:** `TellyEmptyState`, "Nothing here streams on your services", with a **Show all** button that turns the filter off.
  - **Offline:** the watchlist comes from the local cache and keeps working.
- **Lists screen** (`/more/queue/lists`):
  - **App bar:** ← Lists, with **+ New list** (key `create_new_list_button`).
  - **Body:** a `TellySegmentedControl` *My lists* / *Friends' lists*, above the existing custom-list cards. Tapping a list opens `/more/queue/list/:id`, which is unchanged.
- **Planned, not built:** long-press drag to reorder the queue.

---

### `SCR-14`: Canon (The Personal Dual-Canon)

> Tracking: epic #47 · Status: shipped · Decision: [0004](../decisions/0004-canon-podium-and-queue-up-next.md) · Mockup: [0047](mockups/0047-canon-queue-layouts.html)

The Canon tab opens on your rankings. Your profile card lives in the More hub (`SCR-22`), so it isn't repeated here.

```
┌────────────────────────────────────────────────────────┐
│  Canon                              [ ▥ ] [ ☰ ] [ ⇪ ]  │  Stats · View · Share
│  [   Movies 142   |   TV Shows 94   ]                   │
├────────────────────────────────────────────────────────┤
│  ┌──────────┐ ┌────────┐ ┌────────┐                    │  Ranked view only:
│  │ [poster] │ │[poster]│ │[poster]│                    │  the podium
│  │ #1       │ │ #2     │ │ #3     │                    │
│  │Interstell│ │Parasite│ │Spirited│                    │
│  │ [10.00]  │ │ [9.72] │ │ [9.45] │                    │
│  └──────────┘ └────────┘ └────────┘                    │
│  #04  [img] The Godfather   Paramount · 1972   [9.38]  │
│  #05  [img] Dune: Part Two  Warner Bros · 2024 [9.28]  │
│  …                                                     │
└────────────────────────────────────────────────────────┘
```

- **Header** (§0): Canon, with three actions in this order:
  - **Stats** (`insights_rounded`, tooltip "Stats", key `canon_stats_button`) opens the Stats sheet.
  - **View** (key `canon_view_button`, tooltip "View: Ranked", "View: Tiers" or "View: 3x3") opens the View sheet. Its icon is the current view's icon: `format_list_numbered_rounded` (Ranked), `view_agenda_rounded` (Tiers) or `grid_view_rounded` (3x3).
  - **Share profile** (key `profile_share_button`), unchanged.
- **Switcher:** the compact canon switcher (component library §5.5), full width with 16 dp gutters, Movies on the left and a count on each half (keys `movie_canon_tab`, `series_canon_tab`).
  - It stays in place when the header scrolls away (§0).
  - A horizontal swipe on the content also switches canon, with the selection haptic, as before.
  - The Movie and TV canons never mix. Each has its own podium, tiers, grid and stats.
- **Content** (12 dp under the switcher) depends on the view:
  - **Ranked** (default):
    - **Podium** (key `canon_podium`): ranks #1–#3 as three poster cards in one row, with 16 dp gutters and 10 dp gaps. Columns are 1.25fr / 1fr / 1fr, bottom-aligned.
    - **Card:** Surface, radius 14, glass border. The poster is 170 dp tall for #1 and 132 dp for #2 and #3. A rank tag sits top-left (Phosphor Lime fill `#D2FF52`, `#08090C` text, `labelMedium` w800, radius 6, in both themes). Below the poster, with 8 dp padding, come the title (`labelLarge` w800, one line) and the tier score chip (`CanonTierScoreChip`: an 18% tint of the tier accent, a tier-accent border and `textPrimary` digits, the same chip as Home's friend rows).
    - **Tap and long-press** do what they do on a row: tap opens the title, long-press opens the row actions (re-duel or remove).
    - **Short canons:** with fewer than 3 titles, only the cards that exist are drawn, in the same columns.
    - **Rows:** from #4 on, the existing ranked rows (component library §3.1).
  - **Tiers:** the existing tier groups (God → Dropped, with headers in each tier's accent and score range), starting right under the switcher. There's no podium.
  - **3x3:** the existing poster grid in rank order, starting right under the switcher. There's no podium.
  - **Empty canon:** the existing empty state (component library §7.2), shown in every view.
- **View sheet** (bottom sheet, component library §6):
  - **VIEW**: radio rows Ranked / Tiers / 3x3 grid, each with its icon and a check on the current one (keys `view_mode_ranked_button`, `view_mode_tier_button`, `view_mode_grid_button`). Choosing one closes the sheet, with the selection haptic.
  - **SERIES ONLY**: shown only when TV Shows is selected. It holds the *Anime franchise rollup* switch, with the subtitle "Combine multi-season anime into one entry" (key `franchise_rollup_toggle`). Toggling it keeps the sheet open.
  - The sheet replaces the in-page view switcher and the old ⋮ View options menu.
- **Stats sheet** (bottom sheet, component library §6; key `canon_stats_sheet`):
  - **Title:** "MOVIE STATS" or "TV STATS" for the selected canon.
  - **Tiles:** the existing stats panel's four tiles: titles ranked, hours watched, top genre, and top director (movies) or top network (TV). Detail lines use the primary accent token, so they're readable in light mode.
  - **Top 3:** a `TellySectionHeader` "TOP 3 SHOWCASE", then the showcase row: your pinned picks for this canon first, then your best-ranked titles that aren't pinned. Pins are edited in Edit profile.
  - **Offline:** tiles show "—" except titles ranked, which comes from the local canon (as before).

---

### `SCR-15`: Friend Profile & Taste Match Comparison

```
┌────────────────────────────────────────────────────────┐
│ [← Back]                                      [Follow] │
├────────────────────────────────────────────────────────┤
│  (👤) Maya Lin @maya                                   │
│  "Cinephile. Sci-fi obsessive. Succession truther."    │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 🎯 TASTE MATCH: 88% OVERALL (Taste Twins 🔥)     │  │
│  │ 🎬 Movie Match: 92% • 📺 Series Match: 84%       │  │
│  │ Based on 58 mutually ranked titles               │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  [ Compare Tastes ]      [ View Maya's Canons (210) ]  │
│                                                        │
│  🤝 BIGGEST AGREEMENTS                                 │
│  • Interstellar (You: #1 • Maya: #2)                   │
│  • Succession   (You: #1 • Maya: #2)                   │
│  • Parasite     (You: #2 • Maya: #3)                   │
│                                                        │
│  ⚡ BIGGEST DIVERGENCES                                │
│  • Game of Thrones                                     │
│    You: #8 (9.30) • Maya: #68 (5.20)                   │
│                                                        │
│  💡 UNWATCHED GEMS MAYA LOVES                          │
│  1. Station Eleven (Maya's #4 Series)        [+ Queue] │
│  2. Whiplash       (Maya's #5 Movie)         [+ Queue] │
└────────────────────────────────────────────────────────┘
```

- **Pinned medals** (#138, features/10 §4.4): under the name and bio, the friend's pinned medals (small), or their latest unlocks with a "Recent" label. Hidden when they have none or their profile isn't visible.
- **User Actions:**
  - `Follow / Unfollow Button`: Updates social graph.
  - `Compare Tastes Tab`: Shows interactive head-to-head scatter plot of mutual rankings across Movie and Series Canons.
  - `1-Tap Add Unwatched Gems`: Instantly adds Maya's highest-ranked unwatched titles to viewer's queue.

---

### `SCR-16`: "Two-to-Watch" Co-Watching Decider

*(Detailed layout in Section 3 of Feature Spec `05_TASTE_MATCH_AND_CO_WATCH_DECIDER.md`)*
- **User Inputs:**
  - Tap friend avatars to add to viewing circle (1 to 4 people).
  - Format Toggle: `[ 🎬 Movie Night ]` vs `[ 📺 Start a Series ]`.
  - Runtime Budget (for Movie Night): `[ < 90 min (Breezy) ]`, `[ 90–120 min (Standard) ]`, `[ 120+ min (Epic) ]`.
  - Toggle shared streaming services.
  - Select Vibe chips (*"Quick Comedy"*, *"Prestige Drama"*, *"Mind-Bending Thriller"*, *"Oscar Darling"*).
  - Tap *"Find What to Watch"* $\implies$ Displays top 3 joint recommendations with match percentage score.
  - Tap *"Quick Swipe Mode"* $\implies$ Launches 15-second mutual right/left card swiping game.

---

### `SCR-17a`: My Squads — `FE-SQUADS-03`

```
┌────────────────────────────────────────────────────────┐
│ [←]  My Squads                                    [+]  │
├────────────────────────────────────────────────────────┤
│ ━ MY SQUADS (3) ─────────────────────────────────────  │
│ ┌────────────────────────────────────────────────────┐ │
│ │ ┌──┐ The Apartment                       [OWNER]   │ │
│ │ │TA│ Roommates who argue about Lost                │ │
│ │ └──┘ (J)(M)(A)(C)+1   5 members                 ›  │ │
│ └────────────────────────────────────────────────────┘ │
│ ┌────────────────────────────────────────────────────┐ │
│ │ ┌──┐ Sci-Fi Book Club                    [ADMIN]   │ │
│ │ │BC│ (M)(J)           2 members                 ›  │ │
│ └────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────┘
```

- **Data:** one `get_my_squads()` call: my squads, newest first, with my role, the active member count and up to four member previews (owner first).
- **Squad card:** the Queue list-card surface (Surface, radius 16, glass border, 16 padding). Left: a 48 px monogram, the squad picture when set or up to two initials from the last two words, on an accent picked from the squad id (lime, violet, amber, cyan or coral at 14%, so a squad keeps its colour). Then the name (`titleMedium` w800, as typed), an OWNER (accent) or ADMIN (violet) badge, the description (2 lines), and an avatar stack with "+N" plus "N members" and a chevron. The whole card opens the squad.
- **New squad:** the header's + (as Queue's New list) or the empty state's button opens a frosted bottom sheet (§6): "New squad", one line of guidance, a name field (64 characters) and **Create squad**, enabled once the name isn't blank. Creating opens the new squad.
- **Empty:** the shared empty state (`groups_2` icon, "No squads yet", "Squads rank together…", **Create a squad**).
- **Error:** the shared empty state ("Couldn't load your squads", **Retry**). Pull to refresh on every state.

### `SCR-17b`: Squad Hub & Consensus Leaderboard — `FE-SQUADS-04`

```
┌────────────────────────────────────────────────────────┐
│ [←]  The Apartment                         [👤+]  [⋮]  │
│      5 members                                         │
├────────────────────────────────────────────────────────┤
│ ┌────────────────────────────────────────────────────┐ │
│ │ ┌──┐ The Apartment                                 │ │
│ │ │TA│ Roommates who argue about Lost                │ │
│ │ (J)(M)(A)(C)(S)  Jordan and 4 others            ›  │ │
│ │ ────────────────────────────────────────────────── │ │
│ │      5            42                3              │ │
│ │   Members   Ranked together      Debates           │ │
│ └────────────────────────────────────────────────────┘ │
│ ┌ Consensus ┬ Watchlist ┬ Debates ┐                    │
│ ┌ ████ Movies ████ ┬ TV Shows ┐                        │
│ ━ SQUAD TOP 3 ───────────────────────────────────────  │
│ [#1 poster]   [#2 poster]   [#3 poster]                │
│ ┌ 🔥 BIGGEST DEBATE ─────────────────────────────────┐ │
│ │ [p] Lost                                   64      │ │
│ │     Alex #4  vs  Sam #68              ranks apart  │ │
│ └────────────────────────────────────────────────────┘ │
│ ━ THE RANKING ──────────────────────────── 42 titles   │
│ #4  [p] Succession                         490 pts     │
│         🏆 Jordan #1   ↓ Alex #3                       │
│         Ranked by 4 of 5                               │
└────────────────────────────────────────────────────────┘
```

- **Hero card** (as the Canon's profile card): monogram (56 px, as on SCR-17a), name, description, an avatar stack with "Jordan and 4 others"; tapping it opens a frosted members sheet (avatar, name, @handle, OWNER / ADMIN badge; a row opens the profile). Below a hairline: Members, Ranked together and Debates (coral when any) for the canon shown. Counts only, no derived score.
- **Section tabs:** the shared segmented control (§5.5): Consensus | Watchlist | Debates.
- **Canon switcher:** the shared Movies | TV Shows switcher, Movies first, without counts (a canon's size is known only once loaded). Hidden on Watchlist, which spans both canons.
- **Consensus:** "SQUAD TOP 3" poster cards (the Canon's Top 3 Showcase, #1 in the accent), the biggest debate, then "THE RANKING" from #4 in the Canon's ranked-row style: rank, poster, title, the member who ranks it highest (🏆) and lowest (↓), "Ranked by N of M", Borda points in the accent. Every title opens SCR-08.
- **Watchlist:** "WANT TO WATCH (N)" Queue-style cards: poster, title, type, a progress bar of members who queued it and "N of M want to watch"; an EVERYONE badge and accent border when all members did.
- **Debates:** "DEBATES (N)": coral cards (Feed upset styling) with poster, title as typed, "A #4 vs B #68" and the gap in ranks.
- **Empty states** (shared §7.2): no rankings → "Nothing ranked together yet" with **Rank a title** (SCR-09); no shared picks; no debates.

### `SCR-18`: TV Graveyard (Dropped / DNF Tracker)

```
┌────────────────────────────────────────────────────────┐
│ [←]  TV Graveyard                                [ + ] │
│  Shows you abandoned and why (14 Total)                │
├────────────────────────────────────────────────────────┤
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 💀 WESTWORLD (HBO)                               │  │
│  │ Dropped at: Season 3, Episode 4                  │  │
│  │ Primary Reason: "Writing jumped the shark"       │  │
│  │ Status: 🚪 Dead & Buried (Never revisiting)      │  │
│  │ Note: "Lost the mystery once they left the park."│  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ ⏸️ YELLOWJACKETS (Showtime)                      │  │
│  │ Dropped at: Season 2, Episode 3                  │  │
│  │ Primary Reason: "Pacing slowed down"             │  │
│  │ Status: 🔄 Willing to Revisit if S3 is good      │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
└────────────────────────────────────────────────────────┘
```

- **User Inputs:**
  - Tap card to edit drop milestone, reason, or willingness to revisit.
  - Tap *"Revive Show"* to move back into active "Currently Watching" queue.

---

### `SCR-19`: Telly Wrapped & Shareable Asset Studio

- **Visual Layout:** Vertical carousel of 5 Instagram/TikTok 9:16 story slides:
  - Slide 1: Total TV Hours, Episodes & Finished Series Count.
  - Slide 2: Your Crown Series (All-time #1 of the year with poster art).
  - Slide 3: Your Spiciest Upset Take (Show where your rank deviated most from friends).
  - Slide 4: Streaming Network Loyalty Breakdown (HBO vs Apple TV+ vs Netflix pie chart).
  - Slide 5: Your Taste Twin (Friend with highest mutual correlation).
- **Actions:** Sticky bottom buttons: `[ Save All Images ]` and `[ Share Directly to Instagram Stories ]`.

---

### `SCR-20`: Settings, Account & Data Export

- **Sections:**
  - `Profile:` Avatar, Username, Bio, Connected Accounts (Apple, Google).
  - `Subscriptions:` Manage active streaming services.
  - `Privacy & Social:` Private profile toggle, hide dropped shows from public feed, spoiler protection settings, and **Share achievements in the feed** (default on; features/10 §10, #50).
  - `Notifications:` Upsets from friends, shared finale airings, leaving soon alerts.
  - `Data & Exports:`
    - `Export Canon to CSV / Excel`
    - `Export to Notion Template`
    - `Export to Letterboxd Format`
    - `Delete Account & Purge Data`

---

### `SCR-21`: Home

> Tracking: epic #44 (shell) · content redesign: epic #45 · Status: shipped (interim content)

The landing tab (`/home`). Epic #45 designs its real content (currently-watching tracking). Until then it shows only data the app already has:

```
┌────────────────────────────────────────────────────────┐
│  Home                                          [ 🔍 ]  │
├────────────────────────────────────────────────────────┤
│  ── YOUR CANON ───────────────────────────── See all   │
│  [        Movies        |        TV Shows        ]       │
│  [ #1 poster ] [ #2 poster ] [ #3 poster ]             │
│                                                        │
│  ── FROM YOUR FRIENDS ─────────────────────── See all  │
│  (👤) Maya ranked The Bear #3              [ 8.94 ]    │
│  (👤) Jordan ranked Severance #2           [ 9.40 ]    │
│  (👤) …                                                │
│                                          ┌──────────┐  │
│                                          │  + Log   │  │
│                                          └──────────┘  │
└────────────────────────────────────────────────────────┘
```

- **Your canon:** a section header (`TellySectionHeader`), the shared canon switcher, and the top 3 of the selected canon as the Canon grid's poster tiles (component library §3.4: rank badge and score chip). The switcher shares the Canon tab's selection, and the two canons are never mixed. *See all* opens the Canon tab. Tapping a poster opens the title.
- **From your friends:** the 3 newest items of the Following feed by other people (the same feed state as the Social tab; your own posts are left out) as compact rows: a 36dp avatar, then "<name> ranked <title> #N" ("dropped", "queued" or "commented on" for other activity types), then a score chip in tabular figures on an 18% tint of its tier accent with a tier-accent border (style guide §2.2; no chip for drops). Tapping a row opens the title. *See all* opens the Social tab.
- **Empty states:** with no ranked titles in the selected canon, that section becomes a card reading "Log your first title to start your canon" with a Log button. With no activity from other people, the friends section becomes "Find friends in Social", linking to the Social tab.
- **Loading:** skeleton tiles and rows. **Offline:** the canon comes from Drift. The friends section keeps what it loaded earlier in the session, or hides if nothing has loaded.

### `SCR-22`: More Hub

> Tracking: epic #44 · Status: shipped · Decision: [0003](../decisions/0003-five-tab-shell-with-more-hub.md)

A WHOOP-style hub (`/more`): one place for everything that isn't a daily destination, with room for future features.

```
┌────────────────────────────────────────────────────────┐
│  More                                                  │
├────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐  │
│  │ (Y)  Your name                                 › │  │  profile card
│  │      @handle · View profile                      │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │ [🔖] Queue                                     › │  │  full-width tile
│  │      Your watchlist and custom lists             │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌───────────────────────┐ ┌───────────────────────┐   │
│  │ [🎁]                  │ │ [🪦]                  │   │  2-column tiles
│  │ Wrapped               │ │ Graveyard             │   │
│  │ Your year in rankings │ │ Dropped and DNF       │   │
│  └───────────────────────┘ └───────────────────────┘   │
│  ┌──────────────────────────────────────────────────┐  │
│  │ [⚙] Settings and account                       › │  │  grouped list
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

- **Profile card:** avatar 56dp, display name (Title Medium), `@handle · View profile` (Body Medium, `textTertiary`), then your pinned medals (small, features/10 §4.4) once you have any. Opens the Canon tab, which is your public profile.
- **Queue tile:** first and full width, bookmark icon in the primary accent (`#D2FF52`; light `#4D7800`). Opens `/more/queue`.
- **Feature tiles:** a 2-column grid (12dp gaps; an odd last tile keeps half the width, on the left), 104dp tall, `surface-raised` with a `stroke-subtle` border and radius 16. Icon (24px) top-left in its semantic accent; label (Body Large w600) and a one-line subtitle (Caption, `textTertiary`) bottom-left. Shipped now, in order: **Achievements** (trophy, Warm Amber `#FFA733`; light `#B36200`; "Medals and your streak", #137), **Challenges** (flag, Electric Cyan `#00F0FF`; light `#00838F`; "Race friends to the finish", #144), **Your level** (bolt, primary accent; "XP, quests and rewards", #146), **Wrapped** (lime), **Graveyard** (Neon Coral `#FF4B6E`; light `#D61F4D`).
- **Grouped list:** 52dp rows in one rounded card with dividers. Shipped now: **Settings and account** (opens `/more/settings`).
- **Future entries** are added by their epics, and only once they ship (no "Soon" placeholders in the app): Invite friends (#51, tile, violet), Telly Pro (#52, list row, amber), and Help & feedback (#118, list row, once a support channel exists).
- The floating Log button is hidden on this tab.
- **Offline:** everything works offline except refreshing the avatar. No loading state is needed.
