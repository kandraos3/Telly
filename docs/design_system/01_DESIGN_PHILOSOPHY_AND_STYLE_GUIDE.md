# Telly UI/UX Design System: 01 — Philosophy, Style Guide & Foundations

> **Brand Identity:** *Telly — Your Personal TV Canon. Ranked, Shared, Settled.*  
> **Aesthetic Theme:** *Midnight Cathode & Neon Phosphor (Cinematic Tactility meets Social Playfulness)*

---

## 1. Design Philosophy: "Cinematic Tactility"

Modern streaming apps feel corporate, cold, and cluttered with algorithmic noise. Traditional rating apps (IMDb, Rotten Tomatoes, Trakt) feel like 2012 desktop database spreadsheets.

**Telly’s design philosophy rests on three foundational pillars:**

### Pillar 1: The Dark Cinema Experience (Mood & Atmosphere)
The interface is designed for the living room at night. Surfaces use **deep OLED velvet blacks** (`#08090C` to `#161822`) rather than flat gray, creating an immersive, distraction-free backdrop that makes poster art, TV stills, and network colors leap off the glass.

### Pillar 2: Tactile Physicality (Haptics, Weight & Motion)
Ranking television is an emotional act. When a user selects *Severance* over *Succession*, that decision should feel physical:
- Cards exhibit subtle 3D tilt and spring resistance when dragged.
- Decisions snap into place with distinct, multi-layered haptic ticks (iOS `UIImpactFeedbackGenerator`, Android `HapticFeedbackConstants`).
- Tier placements feel permanent and prestigious—like sliding a vinyl record into an archival sleeve.

### Pillar 3: Editorial Prestige meets Social Wit
Typography pairs an **editorial cinematic serif** (evoking HBO prestige title cards, Criterion Collection covers, and Hollywood scripts) with an ultra-clean **geometric sans-serif** for dense metadata, scores, and friend debates.

---

## 2. Color System & Palette Tokens

The color architecture is built around high-contrast legibility, OLED energy efficiency, and high-energy neon accentuation for wins, duels, and upsets.

```
┌────────────────────────────────────────────────────────────────────────┐
│                              TELLY PALETTE                             │
├────────────────────────────────────────────────────────────────────────┤
│  SURFACES (Dark Mode / OLED)                                           │
│  [ #08090C ] Void Canvas (App background)                              │
│  [ #11131A ] Surface Raised (Cards, sheets, navigation bar)            │
│  [ #1A1D27 ] Surface Overlay (Modals, popovers, nested items)          │
│  [ #242938 ] Surface Highlight / Stroke (Borders, card dividers)       │
│                                                                        │
│  PRIMARY BRAND ACCENTS                                                 │
│  [ #D2FF52 ] Phosphor Lime (Primary CTA, win states, #1 ranks)         │
│  [ #FFA733 ] Warm Amber (God Tier badges, favorite actors, stars)      │
│  [ #FF4B6E ] Neon Coral (Upsets, spicy hot takes, dropped/DNF alerts)  │
│  [ #7C5CFF ] Electric Violet (Taste Match %, AI recommendations)       │
│                                                                        │
│  CONTENT & TYPOGRAPHY                                                  │
│  [ #FFFFFF ] Pure White (Display headings, titles, active icons)       │
│  [ #C8CAD8 ] High-Contrast Body (Subtitles, reviews, readable text)    │
│  [ #7D8198 ] Muted Slate (Timestamps, secondary metadata, unselected)  │
│  [ #3D4259 ] Faint Border / Disabled state                             │
└────────────────────────────────────────────────────────────────────────┘
```

### 2.1 Color Tokens Table

| Token Name | Hex Code | Purpose & Semantic Role | Contrast vs Void Canvas |
| :--- | :--- | :--- | :--- |
| `color-bg-canvas` | `#08090C` | Deepest background; OLED zero-power state | 1.0 : 1 |
| `color-surface-raised` | `#11131A` | Main card background, bottom navigation, top bar | 1.3 : 1 |
| `color-surface-overlay`| `#1A1D27` | Popovers, bottom sheets, duel cards | 1.7 : 1 |
| `color-stroke-subtle` | `#242938` | 1px card borders, list item dividers | 2.4 : 1 |
| `color-stroke-strong` | `#3D435C` | Active text inputs, focused card outlines | 3.8 : 1 |
| `color-brand-primary` | `#D2FF52` | **Phosphor Lime**: Main CTA buttons, winner cards, duel progress | **16.2 : 1 (AAA Pass)** |
| `color-brand-prestige`| `#FFA733` | **Warm Amber**: S-Tier God Tier badges, top 3 crown, gold foil | **11.4 : 1 (AAA Pass)** |
| `color-brand-upset`   | `#FF4B6E` | **Neon Coral**: Upset badge, controversial takes, DNF graveyard | **8.1 : 1 (AAA Pass)** |
| `color-brand-match`   | `#7C5CFF` | **Electric Violet**: Taste Match %, two-to-watch badges | **6.5 : 1 (AA Pass)** |
| `color-text-primary`  | `#FFFFFF` | Primary show titles, section headings, active tab icons | **20.5 : 1 (AAA Pass)** |
| `color-text-secondary`| `#C8CAD8` | Review body text, friend comments, episode titles | **13.8 : 1 (AAA Pass)** |
| `color-text-tertiary` | `#7D8198` | Run times, network metadata, release years, inactive tabs| **5.8 : 1 (AA Pass)** |

### 2.2 Tier Badge Color Palette

To give users instant visual hierarchy when scanning leaderboards:

```
👑 God Tier      (9.20 – 10.00) : Glow Gradient [ #FFE066 → #FFA733 ] with Gold Border
✨ Prestige Tier (8.50 –  9.19) : Electric Violet Glow [ #A78BFA → #7C5CFF ]
👍 Great Tier    (7.80 –  8.49) : Phosphor Emerald [ #34D399 → #059669 ]
🍿 Good / Fun    (7.00 –  7.79) : Cinema Cyan [ #38BDF8 → #0284C7 ]
🤷 Mid / Filler  (5.50 –  6.99) : Slate Muted [ #94A3B8 → #64748B ]
💀 Dropped / DNF (< 5.50)       : Blood Ash [ #F87171 → #DC2626 ]
```

---

## 3. Typography Hierarchy & Font Pairings

Telly uses a deliberate 2-font system:
1. **Display / Titles:** **GT Super Display** (Alternative: *New York* / *Playfair Display* / *Cinzel*).
   - Used for show titles on detail pages, Tier headers ("God Tier"), and "Telly Wrapped" shareable cards.
   - Gives the app an editorial, prestige cinephile magazine aesthetic.
2. **UI & Data:** **Plus Jakarta Sans** (Alternative: *Inter* / *SF Pro*).
   - Used for buttons, navigation, scores, micro-reviews, tags, and numbers.
   - Open aperture, crisp geometry, highly readable at 11pt–14pt.
3. **Numeric Tabular Figures:** All decimal scores (e.g., `9.85`, `7.40`) use monospaced tabular figures (`tnum`) to eliminate layout jitter during live calculations.

```
Type Scale Hierarchy:
─────────────────────────────────────────────────────────────────────────
Level            Font Family          Size/Line-Height    Weight    Tracking
─────────────────────────────────────────────────────────────────────────
Display XXL      GT Super Serif       38px / 44px         Bold      -0.03em
Display XL       GT Super Serif       28px / 34px         SemiBold  -0.02em
Title Large      Plus Jakarta Sans    22px / 28px         Bold      -0.01em
Title Medium     Plus Jakarta Sans    18px / 24px         SemiBold   0.00em
Body Large       Plus Jakarta Sans    15px / 22px         Regular    0.00em
Body Medium      Plus Jakarta Sans    13px / 18px         Regular    0.00em
Caption / Tag    Plus Jakarta Sans    11px / 15px         Medium    +0.02em
Score Hero       Plus Jakarta (tnum)  32px / 32px         ExtraBold -0.04em
Score Chip       Plus Jakarta (tnum)  14px / 14px         Bold      -0.02em
```

---

## 4. Spatial Grid, Border Radii & Elevation

### 4.1 Spacing Scale (8pt Baseline Grid with 4pt Half-Steps)
```
$space-xxs: 4px   // Micro gaps, badge inner padding
$space-xs:  8px   // Tag gaps, icon-to-label spacing
$space-sm:  12px  // Card internal padding (compact)
$space-md:  16px  // Standard screen horizontal edge margin, card padding
$space-lg:  24px  // Section vertical margins, header-to-content gap
$space-xl:  32px  // Large component separations, modal sheet tops
$space-xxl: 48px  // Screen bottom floating action offsets
```

### 4.2 Border Radius Scale
```
$radius-xs:   6px   // Small tags, streaming network chips
$radius-sm:  10px   // Buttons, poster corners, score chips
$radius-md:  16px   // Standard show cards, feed cards
$radius-lg:  24px   // Duel cards, preview dialogs
$radius-xl:  32px   // Bottom sheet headers, modal dialogs
$radius-full: 999px // Avatars, pill filter toggles
```

### 4.3 Elevation, Shadows & Neon Glows
Because Telly uses an OLED dark canvas, traditional black drop-shadows are invisible. Instead, elevation is expressed via **subtle outer glowing strokes** and **surface lightness shifts**:

- **Elevation 0 (Background):** `#08090C`, no border.
- **Elevation 1 (Cards, Feed Items):** `#11131A`, border: `1px solid #242938`.
- **Elevation 2 (Floating Navigation / Bottom Sheets):** `#1A1D27`, border: `1px solid #32384D`, shadow: `0 8px 32px rgba(0, 0, 0, 0.7)`.
- **Active / Selected State (Neon Glow):**
  - Phosphor Lime: `box-shadow: 0 0 20px rgba(210, 255, 82, 0.25), inset 0 0 0 1px #D2FF52;`
  - Prestige Amber: `box-shadow: 0 0 20px rgba(255, 167, 51, 0.25), inset 0 0 0 1px #FFA733;`

---

## 5. Sensory Feedback: Haptics & Sound Architecture

Every primary interaction is wired to native sensory feedback engines:

| User Action | iOS Haptic Pattern | Android Haptic Pattern | Sensory Meaning |
| :--- | :--- | :--- | :--- |
| **Tap Winner in Duel** | `UIImpactFeedbackGenerator(style: .medium)` | `CLOCK_TICK` | Solid, tactile physical confirmation |
| **Complete Duel & Canon Reveal**| `UINotificationFeedbackGenerator(.success)` | `CONFIRM` | Celebratory double-pulse |
| **Trigger Upset Alert** | `UIImpactFeedbackGenerator(style: .heavy)` | `LONG_PRESS` | High-impact alert / spicy take |
| **1-Tap Save to Watchlist** | `UIImpactFeedbackGenerator(style: .light)` | `KEYBOARD_TAP` | Effortless, frictionless bookmark |
| **Drag & Drop Rank Adjust** | `UISelectionFeedbackGenerator()` | `TICK` on each slot crossed | Precision spatial adjustment |
| **Taste Match Reveal** | Consecutive 3-tick crescendo | `VIBRATION_EFFECT_WAVEFORM` | Excitement / synchronization |

---

## 6. Iconography Conventions

- **Icon Set:** Clean, 1.75px stroked geometric icons with rounded joins (Lucide / Phosphor Icons equivalent).
- **Core Semantic Glyphs:**
  - 🏠 **Home / Feed:** Dual-layer house silhouette.
  - 🧭 **Explore / Discover:** Precision compass icon.
  - ➕ **Duel / Log:** Plus icon housed inside a glowing phosphor-lime rounded hexagon.
  - 📑 **Queue / Watchlist:** Staggered bookmark deck.
  - 👤 **The Canon / Profile:** Film reel layered over user silhouette.
  - ⚡ **Upsets:** Jagged lightning bolt in Neon Coral (`#FF4B6E`).
  - 🎯 **Taste Match:** Intersecting concentric circles in Electric Violet (`#7C5CFF`).
  - 👑 **God Tier:** Crown icon in Warm Amber (`#FFA733`).

---

## 7. Brand Mark & App Icon

The Telly mark is the lowercase word **telly** in Phosphor Lime on a slate tile. The same mark is the app icon on every platform and the logo inside the app. It was chosen in the icon review of 2026-10-05 as concept **F8**.

### 7.1 Construction

All measurements are fractions of the tile's side `S` (a 1024 px master is `S = 1024`).

| Element | Spec |
| :--- | :--- |
| Tile fill | Radial gradient `#242938` (Stroke Subtle) → `#11131A` (Surface Raised); center at 50% x / 20% y, radius 0.90 `S` |
| Wordmark | `telly`, all lowercase, Plus Jakarta Sans ExtraBold (800), Phosphor Lime `#D2FF52` |
| Type size | 300 / 1024 `S` (≈ 0.293 `S`) |
| Tracking | −14 / 1024 `S` (≈ −0.047 em) |
| Baseline | 600 / 1024 `S` from the top, centered horizontally |
| Corner radius (in-app tile) | 0.224 `S` (iOS-style squircle approximation); platform icons are exported square and masked by the OS |

The single source of truth is `TellyLogoPainter` in `lib/core/widgets/telly_logo.dart`. Every PNG in `assets/brand/` is rendered from it by `tool/brand/generate_brand_assets_test.dart`.

### 7.2 Usage

- **`TellyLogo`** (the tile): app icon, splash screen, sign-in hero. Keep it at 48 dp or larger in the UI; below that the wordmark gets too thin.
- **`TellyWordmark`** (lime text with no tile): on surfaces that are already dark, such as share story cards. Never place it on a light background, because lime on white fails contrast.
- Don't recolor, outline, stretch or re-letter the mark, and don't put "TELLY" in capitals next to it.

### 7.3 Platform Exports

| Target | File | Notes |
| :--- | :--- | :--- |
| iOS / store master | `assets/brand/icon_1024.png` | Full-bleed square, no alpha |
| Android adaptive foreground | `assets/brand/icon_android_foreground.png` | Transparent. The mark sits in the central 72 / 108 so it matches the master once the launcher masks it, well inside the 66 dp safe zone |
| Android adaptive background | `assets/brand/icon_android_background.png` | Gradient laid out for the same 72 / 108 visible area |
| Android 13+ themed icon | `assets/brand/icon_android_monochrome.png` | White wordmark on transparent; the launcher tints it |
| Splash (Android < 12, iOS, web) | `assets/brand/splash_logo.png` | Rounded tile, 480 px (120 dp at @4x), on Void Canvas `#08090C` |
| Android 12+ splash | the foreground image | Shown on an `#1A1D27` icon disc over `#08090C` |

The platform files are generated by `flutter_launcher_icons` and `flutter_native_splash` (configs in `flutter_launcher_icons.yaml` and `flutter_native_splash.yaml`). To change the mark, edit the painter, then run:

```bash
flutter test tool/brand/generate_brand_assets_test.dart
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```
