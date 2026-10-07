# Telly UI/UX Design System: 02 — Component Library & UI Patterns

## 1. Overview & Component Philosophy
Every component in Telly is designed to feel **cinematic, tactile, and information-dense without feeling crowded**. 

Components prioritize artwork (posters, backdrop stills, network typography) and eliminate extraneous visual noise (no generic star rating bars, no cluttered tables).

---

## 2. Core Navigation Shell Components

### 2.1 The Floating Frosted Bottom Bar

> Tracking: epic #44 · Status: approved · Decision: [0003](../decisions/0003-five-tab-shell-with-more-hub.md)

Rather than a traditional opaque bottom bar anchored to the screen bottom, Telly features a **floating pill navigation bar** suspended 16px above the home indicator:
- **Surface Material:** Frosted dark acrylic (`#11131A` with 75% opacity, `backdrop-filter: blur(24px)`). Light mode: `#FFFFFF` at 90% with the same blur.
- **Border:** 1px stroke (`#242938`; light `#E2E5EC`).
- **Dimensions:** Height: 64px, Margin: 16px horizontal, Border Radius: 32px.
- **Items:** five equal-width destinations, no centre action:
  1. `Home` (house icon): `SCR-21`
  2. `Explore` (compass icon): `SCR-07`
  3. `Canon` (bar-chart / film strip icon): `SCR-14`
  4. `Social` (two-people icon): `SCR-05`
  5. `More` (2×2 grid icon): `SCR-22`
- **Item anatomy:** 22px stroke icon, 11px label (Caption, w600) under it, 4px dot under the label. Each item is at least 48 × 56 dp.
- **Active Tab State:** Icon and label shift to `textPrimary` (`#FFFFFF`; light `#0F1117`) with a 4px Phosphor dot beneath (`#D2FF52`; light `#4D7800`). Inactive items use `textTertiary` (`#7D8198`; light `#696E87`).
- **Re-tap:** tapping the active tab pops it to its root.

```
┌────────────────────────────────────────────────────────┐
│                      APP CONTENT                       │
│                                          ┌──────────┐  │
│                                          │  + Log   │  │  <- §2.3 floating Log button
│                                          └──────────┘  │
│   ┌────────────────────────────────────────────────┐   │
│   │  [⌂]     [◎]      [▥]      [👥]      [▦]      │   │
│   │  Home   Explore   Canon   Social    More      │   │
│   └────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────┘
```

### 2.2 Top Header & Context Bar
- **Height:** 52px (excluding status bar).
- **Left Slot:** Dynamic context (e.g., Telly logomark, active page title, or back arrow with spring bounce).
- **Right Slot:** Search pill (`[ 🔍 Search shows or friends ]`) or Action menu (`[ ⚙️ Settings ]`).
- **Scroll Behavior:** Collapses smoothly into a frosted header on scroll down (`Elevation 2`), expands on scroll to top.

### 2.3 Floating Log Button — epic #44

The single entry point to the Log flow (`SCR-09`) from the tabs. It replaces the old centre hexagon.
- **Shape:** extended pill, 52px tall, horizontal padding 20px, radius `999px`. A `+` glyph (20px, stroke 2.4) followed by the label `Log` (Body Large, w700).
- **Colour:** fill Phosphor Lime `#D2FF52` with Void `#08090C` glyph and label in **both** themes (dark text on lime passes AAA). Halo: `0 0 20px rgba(210, 255, 82, 0.35)` in dark mode, none in light mode.
- **Position:** bottom-right, 20px from the right edge and 16px above the nav bar's top edge. Content scrolls under it. Lists on the four tabs add bottom padding so the last row is never hidden.
- **Visibility:** shown on Home, Explore, Canon and Social. Hidden on More and on every pushed screen (title pages keep their own rank action). It never collapses on scroll.
- **Behaviour:** tap opens `/log` (`SCR-09`) with a medium haptic. Semantics label: "Log a title".

---

## 3. Show Card Patterns

The show card is the fundamental atomic unit of Telly, appearing in 4 distinct visual variants:

### 3.1 Variant A: The Canon List Row (Profile & Leaderboard)
- **Dimensions:** Full screen width minus 32px padding, 84px height.
- **Layout:**
  - `Left:` Numeric Rank Badge (e.g., `#01` in tabular bold).
  - `Center Left:` 2:3 aspect ratio poster thumbnail (54px width x 81px height, rounded 8px).
  - `Middle Content:` Show title in SemiBold, release year & network tag (*"Apple TV+ • 2022"*), and 1-line quote of user's hot take.
  - `Right Slot:` Dynamic Score Pill (e.g., `9.85` in bold tabular digits, colored by tier).
  - `Far Right:` Subtle drag handle grip (3 horizontal lines) for manual reordering.

```
┌────────────────────────────────────────────────────────┐
│ #01  ┌────┐  SUCCESSION (2018–2023)            [ 10.0 ]│
│      │Post│  HBO • 4 Seasons                   God Tier│
│      │ er │  "Kendall Roy tragic perfection"      ≡    │
│      └────┘                                            │
└────────────────────────────────────────────────────────┘
```

### 3.2 Variant B: The Social Feed Card (Timeline Activity)
- **Surface:** `#11131A` card with 16px rounded corners, 1px `#242938` border.
- **Top Row:** Friend avatar (36px circle), friend display name, username (`@jordan`), relative timestamp (`2h ago`), and right-aligned Upset/Milestone pill.
- **Body Banner:** High-res cinematic 16:9 backdrop still with dark gradient scrim at bottom.
- **Card Content Overlay:**
  - Show poster overlapping the backdrop (48px x 72px).
  - Title, Network logo, Seasons watched (`"Finished Whole Series"`).
  - Dynamic Score chip (`9.72`) and Tier badge (`👑 God Tier`).
  - Short review text: 280-char hot take in high-contrast text (`#C8CAD8`).
  - Tag chips: `#MindBending`, `#PeakDialogue`, `#FlawlessFinale`.
- **Bottom Action Bar:**
  - Left: `[ + Want to Watch ]` 1-tap save button.
  - Right: Horizontal stack of reaction pills (`[ 🔥 24 ]`, `[ 🤯 8 ]`, `[ 💬 12 ]`).

```
┌────────────────────────────────────────────────────────┐
│ (👤) Jordan Miller @jordan • 2h ago       [ 🚨 UPSET ] │
├────────────────────────────────────────────────────────┤
│ ┌────────────────────────────────────────────────────┐ │
│ │ [ Cinematic 16:9 Backdrop with Backdrop Scrim ]    │ │
│ └────────────────────────────────────────────────────┘ │
│  ┌────┐  SEVERANCE                                     │
│  │Post│  Apple TV+ • 2 Seasons • Sci-Fi / Thriller     │
│  │ er │  Score: 9.72 • 👑 God Tier                     │
│  └────┘  Ranked #2 all-time (Over Succession)          │
│                                                        │
│  "The Season 2 finale made my heart palpitate. The     │
│   elevator sequence will be studied for decades."      │
│                                                        │
│  [#MindBending]  [#FlawlessFinale]                     │
│                                                        │
│  [ + Want to Watch ]          [ 🔥 18 ]  [ 🤯 9 ] [💬 7]│
└────────────────────────────────────────────────────────┘
```

### 3.3 Variant C: The Smart Queue Item (Watchlist)
- **Focus:** Where to watch and why it’s in your queue.
- **Layout:**
  - Poster thumbnail with quick-action checkmark overlay (*"Mark as Watched"*).
  - Show title and runtime info (*"1 Season • 8 Episodes • ~45m each"*).
  - **Social Attribution:** *"Saved from @maya's God Tier"* or *"8.94 Friends Avg (6 friends)"*.
  - **Streaming Action Button:** Glowing neon pill: `[ ▶ Watch on Max ]` with native app deep-link.

### 3.4 Variant D: The 3x3 Poster Grid Tile
- **Focus:** Clean, aesthetic, edge-to-edge poster art for Instagram Stories and profile hero.
- **Layout:** High-resolution vertical 2:3 card, subtle corner radius (8px), rank number embossed in the bottom-left corner with glassmorphic backing.

---

## 4. The Duel Arena Components (The Heart of Telly)

The Duel screen is a distraction-free, full-screen battleground.

```
┌────────────────────────────────────────────────────────┐
│ [✕ Cancel]            DUEL 3 OF 5            [Skip ↷]  │
│                   Progress: [██████░░░░]               │
├────────────────────────────────────────────────────────┤
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │  CANDIDATE CARD A                                │  │
│  │  ┌──────┐  SEVERANCE                             │  │
│  │  │ [IMG]│  Apple TV+ • 2 Seasons • 2022          │  │
│  │  └──────┘  "Waffle party peak television"        │  │
│  │                                                  │  │
│  │            [ TAP OR SWIPE UP TO PICK ]           │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│                         ━ VS ━                         │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │  CANDIDATE CARD B                                │  │
│  │  ┌──────┐  THE BEAR                              │  │
│  │  │ [IMG]│  FX / Hulu • 3 Seasons • 2022          │  │
│  │  └──────┘  Currently your #5 All-Time (9.41)     │  │
│  │                                                  │  │
│  │           [ TAP OR SWIPE DOWN TO PICK ]          │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│            [  🤷 Equal / Can't Compare  ]               │
└────────────────────────────────────────────────────────┘
```

### 4.1 Duel Arena States & Motion Physics
1. **Idle State:** Both cards hover with subtle ambient floating animation (1.5px gentle vertical oscillation).
2. **Selection Gesture:**
   - Tap Card A: Card A immediately scales to 1.04x, stroke ignites in **Phosphor Lime** (`#D2FF52`), haptic impact triggers.
   - Card B compresses to 0.96x, dims to 20% opacity, and slides down out of view with a spring dampening curve (`stiffness: 300, damping: 20`).
3. **Card Transition:** The next comparison card slides in from the right edge with a 200ms ease-out curve.
4. **"Can't Compare" Action:** Button located at the bottom in neutral muted slate. Tapping it gently rotates both cards 4 degrees and slides in two alternative comparison titles.

---

## 5. Buttons, Chips & Interactive Controls

### 5.1 Primary Glow Button (Phosphor Lime CTA)
- **Background:** `#D2FF52`.
- **Text:** `#08090C` (Pure Black), Plus Jakarta Sans Bold, 15px.
- **Border Radius:** 14px.
- **Hover/Tap State:** Brightness 1.1x, neon glow expands (`box-shadow: 0 0 24px rgba(210, 255, 82, 0.45)`).
- **Disabled State:** Background `#242938`, text `#7D8198`, zero glow.

### 5.2 1-Tap Watchlist Save Button
- **Default State:** Background: `rgba(255, 255, 255, 0.08)`, border: `1px solid #3D4259`, icon: `+`, label: `"Want to Watch"`.
- **Saved State (Toggled):** Background: `#D2FF52`, text: `#08090C`, icon: `✓`, label: `"In Watchlist"`, accompanied by a light haptic tick.

### 5.3 Reaction Pill
- **Structure:** Pill shape (height: 32px), surface `#1A1D27`, border: `1px solid #242938`.
- **Elements:** Emoji glyph + numeric count in tabular bold (`[ 🔥 18 ]`).
- **User Reacted State:** Border becomes Neon Coral or Phosphor Lime, count increments with spring text flip.

### 5.4 Filter & Tag Chips
- **Dimensions:** Height 30px, border-radius: 999px (full pill).
- **Unselected:** `#11131A` background, `#7D8198` text.
- **Selected:** Electric Violet (`#7C5CFF`) or Phosphor Lime (`#D2FF52`) solid or outline.

### 5.5 Section Switchers — `FE-UI-01`
Two levels of switcher, each with one look everywhere (`lib/core/widgets/`):
- **Segmented control** (`TellySegmentedControl`): switches a screen's sections. Feed (Following / Squads / Global), Queue (Watchlist / My Lists / Friends' Lists), Squad hub (Consensus / Watchlist / Debates). Surface `#11131A` track, radius 12, 4px inset; the selected segment lifts onto Overlay `#1A1D27` with a glass border and a Phosphor Lime label (`#233B00` on the light theme). Labels are Plus Jakarta Sans `labelMedium` w800; 48dp targets; selection-click haptic.
- **Canon switcher** (`TellyCanonSwitcher`): Movies | TV Shows, Movies always on the left. Canon, Queue, Squad hub. Surface track, radius 16, min height 56; the selected half fills with the primary accent (radius 12, 25% accent glow) and its label turns `#08090C` (white on light). Labels carry a count when the screen knows it ("Movies (12)"); Canon adds "Includes anime" under TV Shows.

### 5.6 Section Header — `FE-UI-01`
`TellySectionHeader`: a 10 × 2 rule, the label in caption w800 caps with 1.5 letter spacing in `textTertiary`, then a hairline glass rule to the edge, with an optional trailing count. Announced as a heading. Used for "TOP 3 SHOWCASE", Queue's list groups and the Squad screens.

### 5.7 Avatars — `FE-UI-01`
`TellyAvatar` shows the person's photo or their initial in the primary accent on Overlay. `TellyAvatarStack` overlaps up to 4 (step = 1.4 × radius, canvas-coloured ring) and ends with a "+N" chip for the rest.

---

## 6. Bottom Sheets & Modal Dialogs

All modal dialogs in Telly use an **iOS-native Pan-Down Bottom Sheet** pattern:
- **Scrim:** `#08090C` with 80% opacity and 16px background blur.
- **Sheet Radius:** 28px top corners.
- **Drag Handle:** 40px width, 4px height pill in `#3D4259` at top center.
- **Dismiss Physics:** Flick down with velocity $> 500\text{px/s}$ or drag past 40% screen height triggers instant dismiss.

---

## 7. State Conventions & System Feedback

### 7.1 Skeleton Loading States
- Content loading displays dark shimmering gradients (`#11131A` to `#242938` wave animation, 1.4s cycle).
- Posters, titles, and score pills maintain exact geometric dimensions to prevent Cumulative Layout Shift (CLS = 0).

### 7.2 Empty States with High-Conversion Action
- **Shared component (`FE-UI-01`):** `TellyEmptyState` — a 72px Surface disc with a 32px muted icon, a `titleMedium` w800 title, one line of `bodyMedium` w600 guidance in `textSecondary`, and an optional 48px Phosphor Lime button (max width 260) that leads somewhere useful. Used by Feed, Queue and Squads.
- **Empty Watchlist:** An illustrated dark TV screen glowing in neon:
  *"Your queue is empty. Explore friends' God Tiers or discover trending shows."*
  `[ Explore Discover Feed → ]`
- **Empty Canon (New User):**
  *"You haven't ranked any shows yet. Complete a 60-second tournament to build your canon."*
  `[ Start Quick Tournament → ]`

### 7.3 Offline & Error State
- Telly operates **Offline-First**. All user rankings, watchlists, and duel choices are cached locally in SQLite.
- If offline, a discreet top banner displays: `⚡ Offline Mode • Changes will sync when reconnected`.
