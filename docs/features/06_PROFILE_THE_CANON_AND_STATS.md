# Feature Spec 06: Profile, "The Canon", Stats & "Telly Wrapped"

> Tracking: epic #47 (Canon layout, §2–§3) · Status: approved · Decision: [0004](../decisions/0004-canon-podium-and-queue-up-next.md)

## 1. Overview & Identity Signaling
On Beli, a user's profile is their culinary identity card. On **Telly**, a user's profile is their **Cultural Identity Across Screen Entertainment**. 

People define themselves by what they cherish—whether they are a cinema purist, an HBO prestige snob, an anime connoisseur, an obscure indie film enthusiast, or a sitcom comfort-watcher.

**Key Components:**
1. **The Dual Canon (Profile Hero):** A seamless segmented switcher toggling between **Movie Canon** and **Series & Anime Canon** (with an optional blended view).
2. **Multi-View System:** Toggle between *Numeric Rank*, *Tier List (S/A/B/C/D)*, and *3x3 Poster Grid*.
3. **Deep Filter Slicers:** Filter by Director, Network/Studio, Streaming Service, Genre, Runtime, and Decade.
4. **Analytics & Radar Charts:** Director affinity, network loyalty, theatrical vs streaming ratio, binge velocity, and genre balance.
5. **"Telly Wrapped" & Social Shareables:** Virally optimized annual and monthly recap cards for Instagram Stories and TikTok.

---

## 2. Canon Tab Layout & Wireframe

The Canon tab (`SCR-14`) opens on your rankings. Your identity (avatar, name, bio, counts) lives on the profile card in the More hub (`SCR-22`). Your stats and Top 3 showcase are one tap away in the header's Stats sheet. The exact layout, sizes and states are in screen spec `SCR-14`; the approved mockup is [0047](../design_system/mockups/0047-canon-queue-layouts.html).

```
┌────────────────────────────────────────────────────────┐
│  Canon                              [ ▥ ] [ ☰ ] [ ⇪ ]  │  Stats · View · Share
│  [   Movies 142   |   TV Shows 94   ]                   │
├────────────────────────────────────────────────────────┤
│  ┌──────────┐ ┌────────┐ ┌────────┐                    │
│  │ #1       │ │ #2     │ │ #3     │   podium (Ranked)   │
│  │Interstell│ │Parasite│ │Spirited│                    │
│  │  10.00   │ │  9.72  │ │  9.45  │                    │
│  └──────────┘ └────────┘ └────────┘                    │
│  #4  The Godfather (Paramount • 1972)           9.38   │
│  #5  Dune: Part Two (Warner Bros • 2024)        9.28   │
└────────────────────────────────────────────────────────┘
```

- **▥ Stats sheet:** the per-canon stats (§5) and the Top 3 showcase (pinned picks first).
- **☰ View sheet:** Ranked / Tiers / 3x3, plus the Series-only franchise rollup toggle (§4).

---

## 3. The Multi-View System

The view is chosen in the header's View sheet. It persists while the app runs, and it's the same for both canons.

### 3.1 View A: The Ranked Canon (Default)
- **Podium:** ranks #1–#3 lead as three large poster cards. The list continues from #4 as rows. The podium appears in this view only.
- Segregated leaderboards:
  - When *Movie Canon* is selected: lists all feature films #1 to #N with runtime, director, venue, and score.
  - When *Series & Anime Canon* is selected: lists all series #1 to #M with season counts, network, and score.
- Displays poster thumbnail, release year, director/network badge, and user's short hot take.
- Supports smooth drag-and-drop re-ordering (with live recalculation of scores).

### 3.2 View B: The Tier List View
Takes the whole page under the switcher (no podium). Transforms the continuous ranking into recognizable culture tiers:
- **👑 God Tier (9.20 – 10.00):** Life-changing, flawless television.
- **✨ Prestige Tier (8.50 – 9.19):** Masterful writing, high rewatch value.
- **👍 Great Tier (7.80 – 8.49):** Highly recommended, few minor flaws.
- **🍿 Good / Comfort (7.00 – 7.79):** Fun, enjoyable, great background/weekend watch.
- **🤷 Mid / Filler (5.50 – 6.99):** Mediocre, forgot it soon after finishing.
- **💀 Graveyard / Dropped (< 5.50):** Shows abandoned or deeply regretted.

### 3.3 View C: The Top 9 Poster Grid (3x3)
- Takes the whole page under the switcher (no podium).
- An aesthetic, borderless grid of posters for the user's Top 9 all-time favorites.
- Designed with 1-tap export to Camera Roll or Instagram Stories.

---

## 4. Deep Slicing & Sub-Leaderboards

Users can slice their personal canons with granular instant filters:
- **By Director & Showrunner:** *"What is my #1 Christopher Nolan film? What is my #1 Jesse Armstrong or Tetsuro Araki work?"*
- **By Viewing Venue (Movies):** *All, Theatrical / IMAX Only, Home Streaming, Festivals.*
- **By Runtime:** *Under 90 min (Breezy), 90–120 min (Standard), 120+ min (Epic).*
- **By Network / Studio:** *HBO, A24, Studio Ghibli, MAPPA, Apple TV+, Neon, Criterion.*
- **By Category:** *Movies Only, TV Series Only, Anime Only, Miniseries.*
- **By Genre & Decade:** *"My Top 10 Sci-Fi films of all time; My Favorite 90s cinema vs 2020s."*
- **By Status & Rewatch:** *First-Time Watches vs Rewatches (Top Rewatched Films).*
- **Franchise Rollup Toggle:** Group multi-film franchises or anime cours into master cards or unbundle.

---

## 5. Screen Entertainment Stats Engine

Telly tracks rich metadata across all logged movies and shows to produce deep cultural analytics:

```
┌────────────────────────────────────────────────────────┐
│              SCREEN ENTERTAINMENT ANALYTICS            │
├────────────────────────────────────────────────────────┤
│                                                        │
│  DIRECTOR & AUTEUR AFFINITY                            │
│  • Christopher Nolan : 6 films (Avg: 9.64)             │
│  • Bong Joon-ho      : 4 films (Avg: 9.50)             │
│  • Hayao Miyazaki    : 7 films (Avg: 9.48)             │
│  • Denis Villeneuve  : 5 films (Avg: 9.38)             │
│                                                        │
│  THEATRICAL VS. STREAMING RATIO                        │
│  • Theaters / IMAX   : 44%  [█████████████        ]    │
│  • Home Streaming    : 52%  [███████████████      ]    │
│  • Festivals / Other :  4%  [█                    ]    │
│                                                        │
│  NETWORK & STUDIO AFFINITY (Series)                    │
│  • HBO / Max : 36%  • MAPPA: 18%  • Apple TV+: 16%     │
│                                                        │
│  REWATCH HABITS                                        │
│  • Most Rewatched Movie: Interstellar (4 times)        │
│  • Most Rewatched Series: Fleabag (3 times)            │
│                                                        │
│  ERA BREAKDOWN                                         │
│  • 2020s: 54%  •  2010s: 32%  •  2000s: 10%  • Classic: 4%│
│                                                        │
└────────────────────────────────────────────────────────┘
```

---

## 6. "Telly Wrapped" & Viral Social Shareables

### 6.1 Annual & Monthly Wrapped Engines
Every December (and optionally at the end of each month), Telly generates **"Telly Wrapped"**:
1. **The Numbers:** Total movies logged, theatrical visits, TV seasons completed, total hours watched.
2. **Crown Titles:** Crown Movie of the Year & Crown Series of the Year.
3. **Auteur of the Year:** Your most-watched director or creator.
4. **Theatrical Dedication:** Your cinema attendance percentage and top theatrical experiences.
5. **Your Spiciest Take:** The title where your ranking deviated most from global average.
6. **Taste Twin of the Year:** The friend whose ratings matched yours most frequently.

### 6.2 Asset Export Specifications
- Formats:
  - **9:16 Instagram/TikTok Story:** High-resolution vertical layout with OLED black background, neon phosphor accents, and poster artwork:
    * *Top 9 Movies of All Time*
    * *Top 9 TV & Anime Series*
    * *Letterboxd Migration Card ("Imported my 412 films to Telly — here is my true #1")*
  - **1:1 Square Grid:** Clean 3x3 poster collage for Twitter/X, Threads, and Bluesky.
  - **Notion & CSV Export (Pro):** Clean tabular export with columns for Title, Media Type, TMDB ID, Personal Rank, Calculated Score, Director, Venue, Tags, and Drop Notes.
