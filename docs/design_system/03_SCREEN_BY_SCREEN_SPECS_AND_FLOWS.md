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
28. **`SCR-28`**: Search Users (Find Friends): `SCR-28` below; features/04 §8.2
29. **`SCR-29`**: Watching (tracking hub): `SCR-29` below; [features/11](../features/11_WATCH_TRACKING_AND_EPISODE_PROGRESS.md)

---

### §0.0 App Shell & Route Map — epic #44

> Tracking: epic #44 · Status: shipped · Decision: [0003](../decisions/0003-five-tab-shell-with-more-hub.md)

Five tabs in the floating bar (component library §2.1), plus the floating Log button (§2.3) on the first four. Signed-in users land on **Home** (`/home`).

| Tab | Root route | Root screen | Pushed from it |
| :--- | :--- | :--- | :--- |
| Home | `/home` | `SCR-21` Home | none |
| Explore | `/explore` | `SCR-07` Explore | `/explore/row/:rowId?canon=movie\|tv` (`SCR-07` See all) |
| Canon | `/canon` | `SCR-14` Canon | none |
| Social | `/social` | `SCR-05` Feed | `/social/activity/:id` (`SCR-06`), `/social/search` (`SCR-28`) |
| More | `/more` | `SCR-22` More hub | `/more/queue` (`SCR-13`), `/more/queue/lists`, `/more/queue/list/:id`, `/more/graveyard` (`SCR-18`), `/more/wrapped` (`SCR-19`), `/more/settings` (`SCR-20`), `/more/edit`, `/more/achievements` (`SCR-23`), `/more/challenges` (`SCR-25`), `/more/challenges/:slug` (`SCR-26`), `/more/level`, `/more/level/rewards`, `/more/level/week` (`SCR-27`), `/more/watching` (`SCR-29`) |

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
| `SCR-21` Home | Home | Streak chip (opens Your level; hidden at 0 weeks), Search (opens Explore with the search field focused) |
| `SCR-07` Explore | Explore | none (the search bar sits directly below) |
| `SCR-14` Canon | Canon | Stats (sheet), View (sheet; icon shows the current view), Share profile |
| `SCR-05` Social | Social | My Squads (`/squads`), Search (`/social/search`, `SCR-28`) |
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
  - Right: Quick Search icon: opens Search Users (`SCR-28`, `/social/search`).
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

> Tracking: epic #46 · Status: shipped · Decision: [0007](../decisions/0007-explore-hero-rows-and-client-ranker.md) · Mockup: [0046](mockups/0046-explore-rows.html) · Rules and scoring: [features/07 §7](../features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md#7-explore-rows--recommendation-engine)

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
│  ━ SEASONS           ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
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

#### §T Watch tracking — epic #168

> Tracking: epic #168 · Status: approved · Decision: [0010](../decisions/0010-watch-tracking-episode-pointer.md) · Mockup: [0168](mockups/0168-watch-tracking.html) · Behaviour and formulas: [features/11](../features/11_WATCH_TRACKING_AND_EPISODE_PROGRESS.md)

The title page shows where you are in a title you track. Untracked titles look as before, except for the Watch slot (§T.2).

- **§T.1 Header.** While tracked, an eyebrow sits above the title (caption w800, 1.2 letter spacing, uppercase):
  - "● Watching · S2 · E6 next", "● Up to date" or "● Finished" in the primary accent (`#D2FF52`; light `#4D7800`);
  - "● New season" or "● New episode" in Warm Amber (`#FFA733`; light `#B36200`).
  - For a movie it reads "● Watching" or "● Finished".
  - A 3 dp line runs along the backdrop's bottom edge: `strokeSubtle` track, primary-accent fill at the progress fraction (features/11 §3.4). It's hidden when untracked.
- **§T.2 Watch slot.** The first quick action (it was *Add to Queue*; the Queue stays in the app bar's bookmark) becomes **Watch**, key `title_watch_action`:

  | State | Icon | Label | Tap |
  | :--- | :--- | :--- | :--- |
  | Untracked | `play_circle_outline_rounded` | Start watching | Series: the Where are you? sheet. Movie: start at once, with Undo. |
  | Watching | `play_circle_filled_rounded` on a lime fill | Watching | Scrolls to the Next episode card. |
  | Up to date | `check_circle_rounded` on a lime fill | Up to date | Scrolls to the Seasons section. |
  | Finished | `check_circle_rounded` on a lime fill | Finished | Opens a menu: *Watch again*, *Stop tracking*. |

  - The app bar's ⋯ menu holds *Drop it* (series) and *Stop tracking* while tracked (features/11 §4.6, §4.9).
- **§T.3 Where are you? sheet** (bottom sheet, component library §6; key `where_are_you_sheet`):
  - Radio rows *Starting from the beginning* (default) and *I'm partway through*.
  - Partway shows two wheel pickers, Season and "the last episode you watched", plus a caption line with that episode's name ("S2 · E5 'Trojan's Horse'", or "Season 2 · Episode 5" when not cached).
  - **Start tracking** is the primary button.
  - A ranked series preselects partway at its last aired episode (features/11 §10). The title page doesn't know the ranking's watch status, so every ranked series gets the preset; the user can switch to the beginning.
- **§T.4 Next episode card** (key `next_episode_card`). While `WATCHING`, it replaces *Streaming now*. Layout:
  - Surface, radius 14, a border at 45% primary accent over `strokeSubtle`, 12 dp padding.
  - Row 1: the "NEXT EPISODE" label (caption w800, `textTertiary`), then "14 of 19" on the right.
  - Row 2: an 84 × 48 still (radius 8, runtime badge bottom-right), the name "S2 · E6 · Attila" (`labelLarge` w700, one line) and "Aired Feb 21, 2025" (caption, `textTertiary`).
  - Row 3: **▶ <provider>** (secondary, the same deep link as *Streaming now*) and **✓ Watched E6** (primary, lime fill), equal widths, 48 dp tall. The key `watched_episode_button` is shared with every ✓ E6 button.
  - No still cached: a `surfaceOverlay` box with the episode number.
  - Up to date or finished: the card reads "You're caught up". It shows the next season's air date when known ("Season 3 · Mar 2027"), or "No new season announced". It offers **Rank <title> →** when the title isn't ranked.
- **§T.4b Movie Watching card** (key `movie_watching_card`; features/11 §2.5, §5.2b). While a movie is `WATCHING`, it replaces *Streaming now*. Layout:
  - The same container as §T.4.
  - Row 1: "WATCHING" label, then "Started yesterday" on the right (caption, `textTertiary`).
  - Row 2: a 34 × 50 poster (radius 6), the title (`labelLarge` w700) and "2 h 46 · on Max".
  - Row 3: **▶ <provider>** (secondary) and **✓ Finished** (primary, lime fill, key `movie_finished_button`), equal widths, 48 dp.
  - Finished: "You finished it · Oct 6" with **Rank <title> →** when unranked, or the rank and score chip when ranked. *Streaming now* returns below it.
  - Movies never show §T.5, the spoiler guard or the drop-off line. *Watching now* (§T.7) does apply.
- **§T.5 Seasons section.** The header is renamed *Seasons* (it read "SEASONS ACCORDION"). While tracked:
  - **Season rows** add a 26 dp progress ring to the left: a lime fill, or a lime disc with ✓ when the season is watched. The trailing text is "watched", "5 of 10", "Not started" or "Airing · next Fri, Oct 17".
  - **Episode rows**, when a season is expanded, are 44 dp tall. Each has a 14 dp tick column (✓ in the primary accent up to your place, ● on the next episode), the number "E6" (`textTertiary`, tabular), and the name.
    - The next episode's row has a 14% lime tint, radius 8, and a "You're here" caption in the primary accent.
    - Rows after it blur the name and synopsis (sigma 4), and the first of them carries the caption "Hidden until you get there. Tap to reveal."
  - **Tap** a row to open the episode sheet (features/11 §4.3, §4.4): still, name, air date, then *↩ Mark as not watched* and *Rewatched it* (watched episodes), or *✓ Watched up to here* (later ones).
  - Untracked, the section looks as before.
- **§T.6 New season state.** When `new_episodes_since` is set:
  - The eyebrow turns amber.
  - The Next episode card's label row starts with an amber **NEW** pill and reads "Season 3 is out" or "E4 is out".
  - *Your status* adds "When you catch up we'll offer a re-duel" for ranked titles.
- **§T.7 Friends and community.**
  - **Watching now:** under the quick actions while any friend tracks the title in `WATCHING`. It shows stacked 24 dp avatars and "Watching now: Maya, Jordan", up to 3 names, then "and N others". Tap opens a sheet listing them; each opens `/u/:handle`. It never shows episodes.
  - **Drop-off line:** in *Community survival rate*, "You're past S1 · E4, where 18% of viewers drop it", once your place is after that drop point (features/11 §5.4).
- **§T.8 Finish sheet** (key `finish_sheet`): features/11 §4.5. Unranked titles get status radios plus **Log and duel →** and **Later**. Ranked titles get **Re-duel →** and **Keep my rank**.
- **§T.9 Feedback.**
  - ✓ actions use the light impact haptic and show the Undo toast "S2 · E6 watched · Undo" for 6 seconds.
  - Starting and finishing use the medium impact haptic.
- **§T.10 States.**
  - **Loading:** the Watch slot shows the untracked look until the tracking cache answers, which is local, so less than a frame.
  - **Offline:** everything works from Drift except *Watching now*, which hides, and episode names that were never cached, which fall back to "Episode 6".

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
- **Long-press** (rows and the Up next card; epic #168): a menu with **Start watching** (features/11 §4.1: series open the Where are you? sheet; the title leaves the Queue with Undo), **Mark seen** (the same as a swipe right) and **Remove**. This supersedes the mockup's ▶ Start pill, so the trailing provider button stays as it is.
- **Planned, not built:** long-press drag to reorder the queue (now behind a drag handle, because long-press opens the menu).

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
- **Watching strip** (epic #168; features/11; key `canon_watching_strip`): 12 dp under the switcher, in every view.
  - **Layout:** a 48 dp row on Surface, radius 12, a border at 45% primary accent over `strokeSubtle`, 16 dp gutters.
  - **Content:** a ▶ icon (primary accent), "Watching 4 series" (or "Watching 1 movie"; `labelLarge` w700), a second line "2 finished, waiting to be ranked" when there are any (caption, `textTertiary`), then a chevron.
  - **Scope:** it counts only the selected canon's tracked titles in *New episodes*, *In progress* or *Paused*, and the second line counts *Finished, not ranked*.
  - **Tap** opens `/more/watching?filter=tv` (or `movie`).
  - **Hidden** when the canon has no tracked titles. Offline it reads from Drift.
- **Row progress tag** (Ranked view rows, Tiers rows and the podium's meta line): a ranked title you're tracking in `WATCHING` gets a lime outline pill "▶ S2 · E6" (`labelSmall` w800), or an amber "▶ New" when it has new episodes, after its meta. A movie shows "▶ Rewatching" (or "▶ Watching" if `is_rewatch` is false). It isn't shown in 3x3.
- **Content** (12 dp under the switcher, or the strip) depends on the view:
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
  - **Tracking tile** (epic #168): a fifth, full-width tile under the four, *Episodes in 2026* (TV) or *Movies finished in 2026* (Movies), from `get_tracking_stats` (features/11 §8). It shows 0 rather than hiding.
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
- **Privacy Gate (Private / Friends-Only Profiles):** If `visibility_mode = 'FRIENDS_ONLY'` and `follow_status != 'ACCEPTED'`, the Canon, Taste Match dial, breakdown, and unwatched gems are replaced by the Private Profile card (`key: Key('friend_profile_private')`):
  - Lock icon in Warm Amber.
  - Heading: "This Profile is Friends-Only".
  - Subtitle: "@handle shares their Canon and rankings with accepted friends only." (or "Follow request sent. Their canon appears once @handle accepts." when `FollowStatus.pending`).
  - Follow action button: `+ Follow` (sends follow request) or `Requested` (pending approval).
- **User Actions:**
  - `Follow / Requested / Following Button`: Outlined pill button in header. Transitions `+ Follow` → `Requested` (if target is private) or `Following` (if target is public). Tapping `Following` unfollows after confirmation.
  - `Compare Tastes`: Shows interactive head-to-head comparisons across Movie and Series Canons (only if profile is viewable).
  - `Two-to-Watch Decider`: Opens `/cowatch?friend=@handle` (`SCR-16`) to find shared titles to watch.
  - `1-Tap Add Unwatched Gems`: Instantly adds friend's highest-ranked unwatched titles to viewer's queue.

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
  - Tap **Revive** to start tracking the show again from its drop point. This deletes the Graveyard entry and opens the title page in the Watching state (features/11 §4.7, epic #168).

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
  - `Privacy & Social:` Account visibility mode picker (`Public` [default], `Friends Only`, `Ghost Mode`), hide dropped shows from public feed, spoiler protection settings, and **Share achievements in the feed** (default on; features/10 §10, #50).
  - `Notifications:` Upsets from friends, shared finale airings, leaving soon alerts.
  - `Data & Exports:`
    - `Export Canon to CSV / Excel`
    - `Export to Notion Template`
    - `Export to Letterboxd Format`
    - `Delete Account & Purge Data`

---

### `SCR-21`: Home

> Tracking: epic #45 · Status: approved · Decision [0011](../decisions/0011-home-tonight-hero-and-moves.md) · Mockup [0045-home-tonight-moves.html](mockups/0045-home-tonight-moves.html)

The landing tab (`/home`). Its first job is to answer "what do I watch now?", and its second is to offer a few things worth doing. It has three parts, always in this order: the **Tonight** hero, **Your moves** and the **Friends line**. Nothing else is on Home. Your canon lives in the Canon tab and the full feed in Social.

```
┌────────────────────────────────────────────────────────┐
│  Home                             [ ▲ 6 weeks ]  [ 🔍 ] │
├────────────────────────────────────────────────────────┤
│ ┌────────────────────────────────────────────────────┐ │
│ │ (backdrop art under a dark scrim)                  │ │
│ │ UP NEXT · SEVERANCE                                │ │
│ │ S2 · E6 "Attila"                                   │ │
│ │ 52 min · Apple TV+ · 4 left this season            │ │
│ │ [ ✓ Watched E6            ] [ Details ]            │ │
│ │ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━───────────────        │ │
│ └────────────────────────────────────────────────────┘ │
│  (▮ Slow Horses · E2) (▮ Shōgun · S2 new) (All 5 ›)    │
│                                                        │
│  ── YOUR MOVES ──────────────────────────────────────  │
│  [★] RANK IT · You finished The Bear    [Log and duel] │
│  [◆] CHALLENGE · Heist Month: 4 of 8           [Open]  │
│  [≈] COMPARE · Maya ranked Andor #2             [See]  │
│  [▶] UP NEXT IN YOUR QUEUE · Dune: Part Two   [Watch]  │
│                                                        │
│  ── FRIENDS ──────────────────────────────── Social ›  │
│  (M)(J)(S)  Maya, Jordan and 4 others                  │
│             ranked 9 titles today                      │
│                                          ┌──────────┐  │
│                                          │  + Log   │  │
│                                          └──────────┘  │
└────────────────────────────────────────────────────────┘
```

#### 21.1 Header
- The shared tab header (§0) titled **Home**, with Search as before.
- **Streak chip** (key `home_streak_chip`): the lime "▲ 6 weeks" chip from features/10 §3 (`WeeklyStreak.chipLabel`), placed before Search. Tapping it opens Your level (`SCR-27`, `/more/level`). It's hidden while `currentWeeks` is 0, and when level data has never loaded.

#### 21.2 Tonight hero (key `home_hero`)
One card with 16 dp side margins, radius 18 and a minimum height of 236 dp. The art (the backdrop, or the poster when there's none) sits under a dark scrim that runs from transparent at 20% to `#08090C` at 92% at the bottom. The text colours are therefore fixed in both themes:
- eyebrow: Phosphor Lime `#D2FF52`, 9.5 sp, uppercase;
- title: white, display face, 23 sp;
- meta: `#C8CAD8`, 11 sp.

The primary button is lime `#D2FF52` with `#08090C` text. The secondary button is glass: white at 12% with a white-at-20% border. Tapping the card outside its buttons opens the title.

The hero shows the first mode that applies (`HomeHeroPicker`, §21.5):

| Mode | When | Eyebrow · title · meta | Buttons |
|---|---|---|---|
| **Watching** | a tracked title is in *New episodes* or *In progress* (features/11 §2.3) | "UP NEXT · SEVERANCE" · `S2 · E6 "Attila"` (`S2 · E6` without a cached name) · runtime ("52 min") and "N left this season", when known | **✓ Watched E6** · **Details** |
| **Queue** | none of the above, and the Queue isn't empty | "UP NEXT FROM YOUR QUEUE" · title · "Movie · 2 h 46 · on Max" or "Series · 3 seasons · on Max" (the provider only when known) | **▶ Start watching** · **↻ Another** (hidden with one title) |
| **New user** | no ranking in either canon, nothing tracked, and an empty Queue | "WELCOME TO TELLY" · "Start your canon" · "Log one movie or show you love. Telly ranks everything after it head to head." | **+ Log a title** |
| **Explore** | everything else (you have rankings, nothing is tracked, the Queue is empty) | "NOTHING ON TONIGHT" · "Find your next watch" · "Explore has picks from your canon" | **Open Explore** |

- **Watching mode:**
  - **Which title:** the newest `last_progress_at` across both groups, with ties going to *New episodes*. Both canons are eligible.
  - **New episodes:** the eyebrow reads "SEVERANCE · SEASON 3 IS OUT" or "SEVERANCE · E4 IS OUT" (features/11 §4.8) in amber `#FFA733`. It names the show because the title line is the episode.
  - **Movie:** the eyebrow reads "WATCHING · MOVIE", the meta reads "Started yesterday", and the primary button is **✓ Finished**.
  - **Progress line:** 3 dp along the bottom, lime on white at 18%. It shows the share of released episodes before your place (features/11 §3.4). Movies have none.
  - **✓ Watched E6** runs the same action as the title page (features/11 §4.2): the Undo toast, the finish sheet after the last episode (§4.5), and a long press that offers *Un-log S2 · E5* (§4.3). **✓ Finished** runs the movie finish (§2.5).
  - The hero then picks again, so it can move on to the next episode or another title.
  - **Details** opens the title. So does a tap anywhere else on the card: the text lets taps through to the art.
- **Queue mode:**
  - **The pool** is the whole Queue: movies and series together, ignoring the Queue's filters.
  - **The pick** is random and kept for the app session. ↻ re-rolls it. It uses `UpNextPicker` under its own key, `home`, so it's separate from the Queue screen's picks.
  - **▶ Start watching** starts tracking (features/11 §4.1): the *Where are you?* sheet for a series, straight to watching for a movie. The title leaves the Queue as it does from the title page (§4.10).
- **Chips under the hero** (key `home_hero_chips`), in Watching mode only:
  - The other titles in *New episodes* and *In progress*, at most 3, newest progress first.
  - Each chip is a pill with a 14 × 20 poster and "Slow Horses · E2", an amber "Shōgun · S2 new", or "Dune · Movie".
  - Tapping a chip **opens that title**. It doesn't change the hero.
  - The last chip is **All N ›**, where N counts every tracked title in any group. It opens the Watching hub (`SCR-29`).
  - The row is hidden when there's nothing else to show. It scrolls sideways if it overflows.

#### 21.3 Your moves (key `home_moves`)
A `TellySectionHeader` reading "YOUR MOVES", then **at most 4** move cards. The section is hidden when there are none.
- **Card:** Surface, 1 dp stroke, radius 14, 10 dp padding.
- **Contents:** a 34 dp icon tile (radius 10, the move's accent at 16% with the glyph in that accent), then a kicker (9 sp, uppercase, accent), a title (12.5 sp, bold, one line) and a meta line (up to two lines), then one small trailing button.
- Tapping anywhere on the card does what its button does.

| Move | Shows when | Kicker · title · meta | Button | Accent |
|---|---|---|---|---|
| `rankFinished` | a tracked title in *Finished, not ranked* that was finished in the last 14 days | RANK IT · "You finished The Bear" · "Series · yesterday" ("You're caught up on <title>" for a series you're caught up on) | **Log and duel** (lime): opens Log with the watch status prefilled, as the finish sheet does (features/11 §4.5) | lime |
| `newEpisodes` | a *New episodes* title other than the hero's | NEW EPISODES · "Shōgun: Season 2 is out" · "You're caught up on S1" | **Resume**: opens the title | amber |
| `streakAtRisk` | `currentWeeks ≥ 1`, the running week is still `current` (not counted), and it's Thursday or later | KEEP YOUR STREAK · "Rank 1 title by Sunday" · "Your 6-week streak needs one ranking this week" | **+ Log** (lime) | amber Thursday and Friday; coral `#FF4B6E` Saturday and Sunday |
| `challenge` | a joined, unfinished challenge that ends within 3 days or is at least 75% done | CHALLENGE · "Heist Month: 4 of 8" · "9 days left" ("Ends tomorrow", "Ends today") | **Open**: opens the challenge | amber |
| `friendCompare` | in the last 3 days, a friend ranked (`rankingCreated` or `upsetAlert` in the Following feed) a title you've ranked in the same canon | COMPARE · "Maya ranked Andor #2" · "You have it at #5 · 9.40 vs 9.08" | **See**: opens the title | violet |
| `queuePick` | the hero isn't in Queue mode and the Queue isn't empty | UP NEXT IN YOUR QUEUE · title · "Movie · on Max" | **Watch**: opens the title | lime |
| `startTracking` | you've never tracked anything | TRACK · "Watching a show right now?" · "Track it and log episodes from here" | **Find it**: opens Explore with search focused | lime |
| `findFriends` | you follow nobody | FRIENDS · "Find friends in Social" · "See what they rank" | **Search**: opens Search Users (`SCR-28`) | violet |

**Ranking** (`HomeMovesRanker`, §21.5). Each candidate has a fixed priority. The list sorts by priority, then by recency (newest first), then by title id, so the order is stable.

| Priority | Move |
|---|---|
| 100 | `streakAtRisk` on Saturday or Sunday |
| 90 | `rankFinished` |
| 85 | `challenge` ending within 3 days |
| 80 | `newEpisodes` |
| 75 | `challenge` at 75% or more |
| 70 | `streakAtRisk` on Thursday or Friday |
| 60 | `friendCompare` |
| 50 | `startTracking` |
| 45 | `findFriends` |
| 40 | `queuePick` |

- At most **2** moves of one kind and **4** in total. One move per title, so the highest priority wins.
- Days use the device's local time, and a week runs Monday to Sunday (features/10 §3).
- `friendCompare` stays within one canon. Your ranking must have the friend's `mediaType`, so a movie never compares with a series. Your rank and score come from the canon state (`profileCanonProvider`). One move per title, from the most recent friend.
- `queuePick` uses the same `home` pick as the hero's Queue mode.

#### 21.4 Friends line (key `home_friends_line`)
A `TellySectionHeader` reading "FRIENDS" with **Social ›**, then one Surface card:
- up to 3 overlapping 26 dp avatars, for the most recent distinct friends;
- a title: "Maya, Jordan and 4 others", "Maya and Jordan", or "Maya";
- a meta line: "ranked 9 titles today", counting today's `rankingCreated` and `upsetAlert` items from friends in the loaded Following feed. With none today, the line shows only the newest friend, and the meta is the rest of their sentence ("started watching Severance · 2h"), using the verbs Home uses today (features/04, features/11 §7.2).

Your own posts, medal posts and challenge posts are left out. Tapping the card opens Social. The line is hidden when you follow nobody (the `findFriends` move covers that) or when the feed has nothing from friends.

#### 21.5 Data and logic
- **Sources.** All of them already exist and are only read:
  - `trackingProvider` (backed by Drift);
  - the Queue (`userWatchlistProvider`, both media types);
  - `profileCanonProvider`, for whether you have rankings and for your rank and score in comparisons;
  - `yourLevelControllerProvider`, for the streak;
  - `challengesControllerProvider`;
  - `feedControllerProvider(FeedFilter.following)`. The app has no follow count, so "you follow nobody" means no one but you appears in that feed. Until the feed answers, Home assumes you follow someone, so the find-friends move doesn't flash in.

  There's no backend change.
- **Pure Dart**, in `lib/features/home/domain/`, with plain inputs and `now` passed in so the weekday rules can be tested:
  - `HomeHeroPicker.pick(...) → HomeHero`: the mode, plus the tracked item or the Queue pick;
  - `HomeMovesRanker.rank(...) → List<HomeMove>`: the tables in §21.3;
  - `FriendsLine.from(feed, me, now)`.
- **`homeStateProvider`** (`lib/features/home/presentation/providers/home_providers.dart`) derives one `HomeState` from the sources, so widgets hold no logic. A source that's loading or has failed counts as empty. The hero follows the data at once. The moves are frozen once shown and re-derive on `refresh()` and whenever a source answers for the first time, so late data (level, challenges, feed) still fills in without re-sorting what's on screen.
- **The Queue pick** is `homeQueuePickProvider`: an `UpNextPicker` under the key `home`, over the whole Queue (movie and series ids are folded into one key, `HomeQueueKey`), kept for the app session.
- **Removed:**
  - `HomeCurrentlyWatching`;
  - Home's `_CanonSection` and `_FriendsSection`;
  - `TrackingHub.homeRows` and `homeCountLine`, if nothing else uses them.

#### 21.6 States
- **Loading:** before tracking and the Queue are first known, Home shows a hero skeleton (236 dp, the `card` colour, radius 18) and two 56 dp move skeletons. Each part swaps in as its data arrives.
- **Stable order:** moves never re-sort while they're on screen. The list refreshes when Home becomes visible again or after you act on a move. The hero re-picks after its own button.
- **Offline:**
  - Tracking, the Queue and the canon come from Drift, so the hero and most moves still work.
  - The streak chip uses the cached level snapshot.
  - Challenge and friend moves and the Friends line use what loaded earlier in the session, or are left out.
  - ✓ Watched goes through the offline queue (features/11).
- **Errors:** Home never shows an error. A failed source just drops its parts.
- **Empty:** there's no empty page. The hero always has a mode, and a new user gets the New user hero with `startTracking` and `findFriends` moves.
- **Both themes:** the hero is fixed dark art in both themes. Move cards, chips and the Friends line use the theme tokens (Surface, stroke, text). Accents use each theme's values: in light, lime text and glyphs are `#4D7800`, while `#D2FF52` fills keep their `onLime` text.
- **Dual canon:** the hero, chips and moves may show movies and series side by side, each labelled, but every comparison and ranking stays within one canon.
- **Accessibility:**
  - The hero is one semantics group ("Up next, Severance, season 2 episode 6, Attila"), with its buttons as separate actions.
  - A move card reads as kicker, title, meta and button.
  - Every tap target is at least 48 dp.

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
- **Watching tile** (epic #168; key `more_watching_tile`): second, full width, the same layout as Queue, with a ▶ icon in the primary accent.
  - **Subtitle:** live, e.g. "4 in progress · Severance S2 · E6 next", "2 new episodes", or "Track what you're watching" when empty.
  - **Progress bars:** below the subtitle, one 6 dp bar per in-progress title (at most 6, equal widths, 3 dp gaps).
  - **Tap** opens `/more/watching` (`SCR-29`).
- **Feature tiles:** a 2-column grid (12dp gaps; an odd last tile keeps half the width, on the left), 104dp tall, `surface-raised` with a `stroke-subtle` border and radius 16. Icon (24px) top-left in its semantic accent; label (Body Large w600) and a one-line subtitle (Caption, `textTertiary`) bottom-left. Shipped now, in order: **Achievements** (trophy, Warm Amber `#FFA733`; light `#B36200`; "Medals and your streak", #137), **Challenges** (flag, Electric Cyan `#00F0FF`; light `#00838F`; "Race friends to the finish", #144), **Your level** (bolt, primary accent; "XP, quests and rewards", #146), **Wrapped** (lime), **Graveyard** (Neon Coral `#FF4B6E`; light `#D61F4D`).
- **Grouped list:** 52dp rows in one rounded card with dividers. Shipped now: **Settings and account** (opens `/more/settings`).
- **Future entries** are added by their epics, and only once they ship (no "Soon" placeholders in the app): Invite friends (#51, tile, violet), Telly Pro (#52, list row, amber), and Help & feedback (#118, list row, once a support channel exists).
- The floating Log button is hidden on this tab.
- **Offline:** everything works offline except refreshing the avatar. No loading state is needed.

---

### `SCR-28`: Search Users (Find Friends) — epic #48

> Tracking: epic #48 · Status: approved · Decision: [0009](../decisions/0009-social-friends-search-and-privacy.md) · Mockup: [0048-social-friends.html](../design_system/mockups/0048-social-friends.html)

Pushed over the shell from the Social tab header (`/social/search`), using `TellySubpageAppBar` with title "Find Friends".

```
┌────────────────────────────────────────────────────────┐
│ [← Back]              Find Friends                     │
├────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐  │
│  │ 🔍 Search by name or @handle...             [✕]  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  MATCHES                                               │
│  ┌──────────────────────────────────────────────────┐  │
│  │ (👤) Alex Morgan @alexm         [ + Follow ]     │  │
│  │      🎯 88% Taste Match                          │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │ (👤) Alexander Ross @aross       [ Requested ]   │  │
│  │      🎯 74% Taste Match                          │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │ (👤) Alex Chen @alexchen          [ Following ]  │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

- **Search field:** autofocus input with clear button `[✕]`. Debounced (300ms) query against `profiles.handle` and `profiles.display_name`.
- **Ghost filtering:** users with `visibility_mode = 'GHOST'` are excluded from search results unless the active user already follows them.
- **Card layout:**
  - Avatar with level/reward frame.
  - Display name (Title Small, `textPrimary`) and `@handle` (Caption, `textTertiary`).
  - Taste match percentage pill (Electric Violet `#7C5CFF`) if mutual scored titles exist.
  - Inline follow button (`TellyOutlinedButton`):
    - `+ Follow` (Phosphor Lime outline): sends follow request or accepts instantly depending on target's visibility mode.
    - `Requested` (Warm Amber outline): pending follow request approval.
    - `Following` (Stroke Subtle outline, `textPrimary`): active follow.
- **Navigation:** tapping the user card anywhere outside the follow button pushes `/u/:handle` (`SCR-15`).
- **States:**
  - Empty query: "Search for friends by name or @handle to see what they're watching."
  - Loading: skeleton user rows.
  - No results: "No users found matching '{query}'."
  - Offline: "User search requires an internet connection." with Retry button.

---

### `SCR-29`: Watching (tracking hub) — epic #168

> Tracking: epic #168 · Status: approved · Decision: [0010](../decisions/0010-watch-tracking-episode-pointer.md) · Mockup: [0168](mockups/0168-watch-tracking.html) · Behaviour: [features/11](../features/11_WATCH_TRACKING_AND_EPISODE_PROGRESS.md)

Everything you're tracking. Pushed at `/more/watching` with the subpage app bar (§0.2), opened from More's Watching tile, Home's *See all* and Canon's Watching strip.

```
┌────────────────────────────────────────────────────────┐
│ [←]  Watching                                    [ ⇅ ] │
│  ( All 8 ) ( Series 6 ) ( Movies 2 ) ( Finished )       │
├────────────────────────────────────────────────────────┤
│  THIS WEEK    9 episodes                    7 h 50     │
│  ━ NEW EPISODES · 2 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│  [img] Severance   [Season 3 is out]          [✓ E1]   │
│  ━ IN PROGRESS · 3 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│  [img] Shōgun      S1 · E9 · 2 left ▬▬▬▬▬▬▬▬░  [✓ E9]   │
│  [img] Dune: Part Two  Movie · yesterday   [✓ Finished]│
│  ━ FINISHED, NOT RANKED · 2 ━━━━━━━━━━━━━━━━━━━━━━━━   │
│  [img] The Bear    Up to date · Oct 4         [Rank →] │
│  ━ CAUGHT UP · 1 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│  ━ PAUSED · 1 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│  Graveyard: 14 dropped shows                        ›  │
└────────────────────────────────────────────────────────┘
```

- **App bar:** ← Watching. **Sort** (`swap_vert_rounded`, key `watching_sort_button`) opens a sheet with *Recent* (default) and *Fewest left*, which apply within each group.
- **Filter chips** (16 dp gutters, 8 dp gaps; keys `watching_filter_all`, `watching_filter_tv`, `watching_filter_movie`, `watching_filter_finished`):
  - *All N*, *Series N* and *Movies N* filter by media type and never mix within their counts.
  - *Finished* lists `FINISHED` titles by `finished_at`, newest first (the history).
  - A `?filter=` query selects one chip on open.
- **This week strip:** a Surface card with two figures in `headlineSmall` w800 tabular: *episodes* this ISO week (All and Series chips) or *movies* finished this week (Movies chip), and *time*. Time only shows when known (features/11 §8).
- **Groups** in features/11 §2.3 order. Each has a `TellySectionHeader` with a count, and empty groups are omitted.
- **Row:** 16 dp gutters, a 36 × 52 poster (radius 6), the title (`bodyLarge` w700, one line), and a meta line:
  - "S2 · E6 'Attila' · 5 left";
  - "Up to date · Oct 4";
  - "Ranked #6 · no new season announced";
  - "Started yesterday · 2 h 46" for a movie in progress or paused, "Finished Oct 6" for a finished movie (*All* chip rows add "Movie ·" first);
  - in *New episodes*, an amber pill instead ("Season 3 is out", "E4 is out").
  - **Progress bar:** 6 dp, under the meta line, for series in *New episodes*, *In progress* and *Paused*.
  - **Trailing:**
    - **✓ E6** (lime fill) in *New episodes*, *In progress* and *Paused*;
    - **✓ Finished** for movies;
    - **Rank →** (lime fill) in *Finished, not ranked*;
    - a "Caught up" outline pill in *Caught up*.
  - **Tap** opens the title. **Long-press ✓** un-logs the last episode (features/11 §4.3).
  - **Swipe left:** *Drop it* (series, coral) or *Stop tracking* (movies), each with a confirm.
- **Footer row:** "Graveyard: N dropped shows ›" opens `/more/graveyard`. It's hidden when N = 0.
- **States:**
  - **Loading:** the strip skeleton and 5 skeleton rows (component library §7.1).
  - **Empty:** `TellyEmptyState`, "Track what you're watching. Start a show from its page or your Queue.", with **Open Queue** and **Explore** buttons.
  - **Empty filter:** "No movies in progress", with **Show all**.
  - **Offline:** the list comes from Drift and every action queues. The This week strip shows "—".
