# Telly UI/UX Design System: 03 — Screen-by-Screen Specifications & Interaction Details

This document defines every single screen in the Telly application. For each screen, it details the visual layout, exact user inputs, editable elements, action presentations, and state transitions.

---

## Screen Directory & Index

1. **`SCR-01`**: Onboarding Splash & Auth
2. **`SCR-02`**: Streaming Subscriptions Household Setup
3. **`SCR-03`**: Show Recognition Seed Grid
4. **`SCR-04`**: Onboarding Duel Tournament & Canon Unveiling
5. **`SCR-05`**: Home / Activity Feed (Following / Squads / Global)
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

### `SCR-05`: Home / Activity Feed (Following / Squads / Global)

```
┌────────────────────────────────────────────────────────┐
│  [ 📺 TELLY ]       [ Following ▾ ]           [ 🔍 ]   │
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
│ [✕ Close]             CONVERSATION                     │
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
│  🧭 DISCOVER                                  [ Filter]│
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
│ [✕ Cancel]            LOG A SHOW                       │
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

```
┌────────────────────────────────────────────────────────┐
│  📑 QUEUE (38)    [ All (38) ]   [ On My Services (24)]│
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
│  [⚙️]                     @jordan             [Share 📤]│
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

### `SCR-17`: Squads Hub & Consensus Leaderboard

```
┌────────────────────────────────────────────────────────┐
│ [←]               THE APARTMENT (5)           [Invite] │
├────────────────────────────────────────────────────────┤
│  Members: Jordan, Maya, Alex, Chris, Sam               │
│                                                        │
│  [ Consensus Canon ]   [ Squad Watchlist ]   [ Chat ]  │
│                                                        │
│  CONSENSUS TOP 5 SHOWS (Borda Count Aggregated)        │
│  #1  SUCCESSION (490 pts)                              │
│      Champion: Jordan (#1) • Lowest: Alex (#3)         │
│                                                        │
│  #2  SEVERANCE (472 pts)                               │
│      Champion: Maya (#2) • Lowest: Sam (#5)            │
│                                                        │
│  #3  THE BEAR (440 pts)                                │
│      Champion: Alex (#1) • Lowest: Chris (#9)          │
│                                                        │
│  🔥 SQUAD'S BIGGEST DEBATE: LOST                       │
│  Variance: 64 ranks between Alex (#4) and Sam (#68)    │
│  [ View Debate Thread (18 comments) → ]                │
└────────────────────────────────────────────────────────┘
```

- **User Actions:**
  - Tapping any consensus show reveals which squad member ranked it where.
  - Tapping "Squad Watchlist" filters titles all 5 members want to watch.

---

### `SCR-18`: TV Graveyard (Dropped / DNF Tracker)

```
┌────────────────────────────────────────────────────────┐
│ [←]                 THE TV GRAVEYARD                   │
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
