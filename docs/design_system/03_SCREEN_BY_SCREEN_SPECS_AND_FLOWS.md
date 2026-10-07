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
14. **`SCR-14`**: Profile: The Personal Canon (Ranked, Tier, Grid Views)
15. **`SCR-15`**: Friend Profile & Taste Match Comparison
16. **`SCR-16`**: "Two-to-Watch" Co-Watching Decider
17. **`SCR-17`**: Squads Hub & Consensus Leaderboard
18. **`SCR-18`**: TV Graveyard (Dropped / DNF Tracker)
19. **`SCR-19`**: Telly Wrapped & Shareable Asset Studio
20. **`SCR-20`**: Settings, Account & Data Export
21. **`SCR-21`**: Home
22. **`SCR-22`**: More Hub

---

### §0.0 App Shell & Route Map — epic #44

> Tracking: epic #44 · Status: approved · Decision: [0003](../decisions/0003-five-tab-shell-with-more-hub.md)

Five tabs in the floating bar (component library §2.1), plus the floating Log button (§2.3) on the first four. Signed-in users land on **Home** (`/home`).

| Tab | Root route | Root screen | Pushed from it |
| :--- | :--- | :--- | :--- |
| Home | `/home` | `SCR-21` Home | none |
| Explore | `/explore` | `SCR-07` Explore | none |
| Canon | `/canon` | `SCR-14` Canon | none |
| Social | `/social` | `SCR-05` Feed | `/social/activity/:id` (`SCR-06`) |
| More | `/more` | `SCR-22` More hub | `/more/queue` (`SCR-13`), `/more/queue/list/:id`, `/more/graveyard` (`SCR-18`), `/more/wrapped` (`SCR-19`), `/more/settings` (`SCR-20`), `/more/edit` |

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
| `SCR-14` Canon | Canon | Share profile |
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
| `SCR-13` Queue | ← | Queue | Watchlist: Sort (sheet: Friends' Score / Leaving Soon). My Lists: New list. Friends' Lists: none |
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

```
┌────────────────────────────────────────────────────────┐
│  Explore                                               │
├────────────────────────────────────────────────────────┤
│                                                        │
│  [ 🔍 Search shows, actors, showrunners, friends...  ] │
│                                                        │
│  ━ NETWORK BATTLEGROUNDS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  👑 HBO (8.82)  vs  🍏 Apple TV+ (8.41)  vs  🔴 Netflix │
│  [ See Full Network Rankings → ]                       │
│                                                        │
│  ━ FRIENDS ARE CURRENTLY BINGING ━━━━━━━━━━━━━━━━━━━━  │
│  [ Horizontal Carousel of Posters with Friend Avatars] │
│  • Shogun (Watched by 8 friends • Avg: 9.31)           │
│  • Slow Horses (Watched by 5 friends • Avg: 8.94)      │
│                                                        │
│  ━ CURATED CANONS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 🎯 The "Stuck the Landing" Canon                 │  │
│  │ Shows with universally revered final episodes    │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │ ⚡ Peak 1-Season Miniseries                      │  │
│  │ Chernobyl, Band of Brothers, Queen's Gambit      │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

- **User Actions:**
  - Search bar input triggers instant autocomplete modal querying TMDB and user database.
  - Tapping a Curated Canon opens a specialized tier leaderboard.
  - Tapping Network Battlegrounds displays global comparative analytics.

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

Opened from the More hub (`/more/queue`) as a pushed screen with the subpage app bar (§0.2). Its Sort and New list actions move from the tab header into that app bar; the hub pills stay under it.

```
┌────────────────────────────────────────────────────────┐
│  Queue                              [ ⇅ Sort | + New ] │
│  [ Watchlist ]  [ My Lists ]  [ Friends' Lists ]       │
│  [  Movies (14)  |  TV Shows (24)  ]  ○ On My Services │
├────────────────────────────────────────────────────────┤
│                                                        │
│  Filter: [ Genre ▾ ]  [ Miniseries ▾ ]  [ Friends Avg ▾]│
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ ┌──────┐  SLOW HORSES                            │  │
│  │ │ [IMG]│  Apple TV+ • 4 Seasons                  │  │
│  │ └──────┘  ⭐ 8.94 Friends Avg • Saved from @maya  │  │
│  │                                                  │  │
│  │  [ ▶ Watch on Apple TV+ ]        [ ✓ Mark Seen ] │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ ┌──────┐  STATION ELEVEN                         │  │
│  │ │ [IMG]│  Max • 1 Season (10 eps)                │  │
│  │ └──────┘  ⭐ 8.81 Friends Avg • Saved from @alex  │  │
│  │                                                  │  │
│  │  [ ▶ Watch on Max ]              [ ✓ Mark Seen ] │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
└────────────────────────────────────────────────────────┘
```

- **User Actions:**
  - `Toggle Tabs:` Switch between *All Shows* and *On My Services* (instantly hides titles not on active user subscriptions).
  - `Swipe Right on Row:` Mark as seen and launch Logging Studio (`SCR-09`).
  - `Swipe Left on Row:` Remove from Watchlist or Move to TV Graveyard.
  - `Long-press Drag:` Custom prioritize queue order.

---

### `SCR-14`: Profile: The Personal Dual-Canon

```
┌────────────────────────────────────────────────────────┐
│  Canon                           [ 👥 ] [ 📤 ] [ ⚙️ ]  │
├────────────────────────────────────────────────────────┤
│  (👤) Jordan Miller • 142 Movies • 94 Series • 88% Match│
│                                                        │
│  ━ DUAL-CANON SELECTOR ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  [  🎬 Movie Canon (142)  ]  [  📺 Series & Anime (94) ]│
│                                                        │
│  [ ≡ Ranked List ]   [ ▥ Tier View ]   [ ▦ 3x3 Grid ]  │
│                                                        │
│  Filter: [ All Directors ▾ ] [ Theatrical Only ] [ 🔍 ] │
│                                                        │
│  👑 GOD TIER (9.20 – 10.00)                            │
│  #01  Interstellar (Paramount • 2014)           10.00  │
│  #02  Parasite (Neon • 2019)                     9.72  │
│  #03  Spirited Away (Ghibli • 2001)              9.45  │
│  #04  The Godfather (Paramount • 1972)           9.38  │
│  #05  Dune: Part Two (Warner Bros • 2024)        9.28  │
│                                                        │
│  ✨ PRESTIGE TIER (8.50 – 9.19)                        │
│  #06  Oppenheimer (Universal • 2023)             9.14  │
│  #07  The Dark Knight (Warner Bros • 2008)       9.05  │
│  #08  Whiplash (Sony Pictures • 2014)            8.88  │
│                                                        │
└────────────────────────────────────────────────────────┘
```

- **User Inputs:**
  - Dual-Canon Selector:
    - `🎬 Movie Canon`: Switches profile to strictly feature films and anime movies.
    - `📺 Series & Anime`: Switches profile to television series and anime seasons.
    - `⚡ Blended (Optional)`: Unified mathematical view for power users.
  - Tab Switcher: Changes view mode instantly:
    - `Ranked List:` 1–N sequential rows with drag handles.
    - `Tier View:` Accordion groups (God Tier, Prestige, Great, etc.).
    - `3x3 Grid:` Borderless poster collage for visual aesthetics.
  - Filter dropdowns: Slice list by Director, Theatrical Venue, Network/Studio, Decade, or Genre.

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
  - `Privacy & Social:` Private profile toggle, hide dropped shows from public feed, spoiler protection settings.
  - `Notifications:` Upsets from friends, shared finale airings, leaving soon alerts.
  - `Data & Exports:`
    - `Export Canon to CSV / Excel`
    - `Export to Notion Template`
    - `Export to Letterboxd Format`
    - `Delete Account & Purge Data`

---

### `SCR-21`: Home

> Tracking: epic #44 (shell) · content redesign: epic #45 · Status: approved (interim content)

The landing tab (`/home`). Epic #45 designs its real content (currently-watching tracking). Until then it shows only data the app already has:

```
┌────────────────────────────────────────────────────────┐
│  Home                                          [ 🔍 ]  │
├────────────────────────────────────────────────────────┤
│  ── YOUR CANON ───────────────────────────── See all   │
│  [      Movies      |      Series & Anime      ]       │
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
- **From your friends:** the 3 newest items of the Following feed (the same feed state as the Social tab) as compact rows: a 36dp avatar, then "<name> ranked <title> #N" ("dropped", "queued" or "commented on" for other activity types), then a score chip in tabular figures on an 18% tint of its tier accent with a tier-accent border (style guide §2.2; no chip for drops). Tapping a row opens the title. *See all* opens the Social tab.
- **Empty states:** with no ranked titles in the selected canon, that section becomes a card reading "Log your first title to start your canon" with a Log button. With no friends' activity, the friends section becomes "Find friends in Social", linking to the Social tab.
- **Loading:** skeleton tiles and rows. **Offline:** the canon comes from Drift. The friends section keeps what it loaded earlier in the session, or hides if nothing has loaded.

### `SCR-22`: More Hub

> Tracking: epic #44 · Status: approved · Decision: [0003](../decisions/0003-five-tab-shell-with-more-hub.md)

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

- **Profile card:** avatar 56dp, display name (Title Medium), `@handle · View profile` (Body Medium, `textTertiary`). Opens the Canon tab, which is your public profile.
- **Queue tile:** first and full width, bookmark icon in the primary accent (`#D2FF52`; light `#4D7800`). Opens `/more/queue`.
- **Feature tiles:** a 2-column grid, 104dp tall, `surface-raised` with a `stroke-subtle` border and radius 16. Icon (24px) top-left in its semantic accent; label (Body Large w600) and a one-line subtitle (Caption, `textTertiary`) bottom-left. Shipped now: **Wrapped** (lime), **Graveyard** (Neon Coral `#FF4B6E`; light `#D61F4D`).
- **Grouped list:** 52dp rows in one rounded card with dividers. Shipped now: **Settings and account** (opens `/more/settings`).
- **Future entries** are added by their epics, and only once they ship (no "Soon" placeholders in the app): Achievements (#50, tile, amber), Invite friends (#51, tile, violet), Telly Pro (#52, list row, amber), and Help & feedback (#118, list row, once a support channel exists).
- The floating Log button is hidden on this tab.
- **Offline:** everything works offline except refreshing the avatar. No loading state is needed.
