# Feature Spec 03: Series vs. Seasons Architecture & DNF (Dropped) Tracking

## 1. Overview & TV-Specific Domain Challenges
Unlike restaurants (which maintain relatively stable menus or chefs), television presents unique evaluation challenges:
1. **The "Downfall" Problem:** A series can be a 10/10 masterpiece for four seasons and collapse into an unwatchable disappointment in its final season (*Game of Thrones*, *Killing Eve*, *Bloodline*, *Lost*).
2. **The "Anthology" Problem:** Series like *True Detective*, *Fargo*, *The White Lotus*, and *Black Mirror* feature entirely separate storylines, casts, and qualities per season.
3. **The "Abandoned / DNF" Problem:** A viewer often watches 18 hours of a show before dropping it. Traditional trackers either force them to leave it unrated or falsely mark it as "completed".

**Telly's Solution:** A multi-layered architecture that keeps the primary profile simple and clean (Series Level) while giving cinephiles and power users granular Season-level rankings, Finale Modifiers, and a dedicated "Dropped Graveyard".

---

## 2. The Two-Layer Evaluation Model

```
┌────────────────────────────────────────────────────────┐
│                   PRIMARY LAYER                        │
│            Overall Series Ranking (The Rankings)          │
│            • Evaluates the show holistically           │
│            • Accounts for total emotional impact       │
└───────────────────────────┬────────────────────────────┘
                            │ (Optional Drill-Down)
                            ▼
┌────────────────────────────────────────────────────────┐
│                  SUB-LAYER: SEASONS                    │
│            • Individual Season Duel Leaderboard        │
│            • "True Detective S1" vs "Fargo S2"         │
│            • "Ending Impact" Modifier Rating           │
└────────────────────────────────────────────────────────┘
```

### 2.1 The Holistic Series Rankings (Default View)
On the user’s primary profile and global leaderboards, shows are evaluated as complete entities. 
- When evaluating *Game of Thrones*, the user decides whether the highs of Seasons 1–4 outweigh the lows of Season 8 in their personal pairwise duels.

### 2.2 Season-Level Duels (Power User / Cinephile View)
Users can toggle on a dedicated **"Seasons Leaderboard"** sub-tab:
- Each season is treated as an autonomous unit: `True Detective (Season 1)` can be ranked at #3 all-time God Tier, while `True Detective (Season 2)` sits at #85.
- **Season Duel Mechanic:**
  When a user logs a season of an anthology or multi-year show, the app offers a quick sub-duel:
  *"Where does Season 3 of The Bear rank compared to Season 1 and Season 2?"*

### 2.3 The "Ending Impact" Modifier
Finales hold disproportionate psychological weight in television. Telly introduces an optional **Finale Landing Tag**:

| Tag | Icon | Meaning | Example |
| :--- | :--- | :--- | :--- |
| **Flawless Landing** | 🎯 | The ending elevated the entire series | *Breaking Bad*, *Succession*, *The Americans*, *Six Feet Under* |
| **Satisfying Finish** | ✅ | Tied up loose ends well | *Better Call Saul*, *Fleabag*, *Dark* |
| **Fumbled the Bag** | 📉 | Disappointing conclusion that tainted the run | *Game of Thrones*, *Dexter*, *Killing Eve* |
| **Cancelled Too Soon**| 💔 | Truncated by network/streaming cancellation | *Mindhunter*, *Rome*, *Firefly*, *1899* |
| **Still Airing** | ⏳ | Ongoing show; ending pending | *Severance*, *The White Lotus*, *Yellowjackets* |

### 2.4 The Franchise Rollup Engine (Anime & Multi-Part Sagas)
In anime and complex multi-part sagas (*Attack on Titan*, *Fate*, *Monogatari*, *Demon Slayer*), seasons are often split into separate cours, special broadcast movies (*Mugen Train*), and OVAs:
- **Franchise Rollup Toggle:**
  - `[✓] Roll up multi-part franchises into 1 master canon card`
  - Grouping *Attack on Titan S1, S2, S3 (P1/P2), and Final Season (P1-P3)* into a single top-level entry on the user's main canon.
  - Tapping the master card expands the child season/cour leaderboard with individual ratings.
- **Unbundled Cour View:** Users can toggle this off to let *Season 3 Part 2* compete independently against *Season 1*.

---

## 3. The "Dropped / DNF" Tracking System

### 3.1 Value Proposition
Dropping a TV show is an active cultural decision. Viewers love discussing *why* and *when* they abandoned a popular show (*"I made it to Season 3 of Westworld before giving up"*). 

In Telly, dropped shows are **first-class citizens**, logged into a distinct **"TV Graveyard"** with milestone tracking and reason taxonomies.

### 3.2 The Dropped Logging Flow
```
[ Select Show: "Westworld" ] 
         │
         ▼
[ Status: "Dropped / DNF" ]
         │
         ▼
[ Drop Point Selector: "Season 3, Episode 4" ]
         │
         ▼
[ Primary Drop Reason Taxonomy ]
  ( ) Pacing slowed down / Boring
  ( ) Writing jumped the shark
  ( ) Loved characters died or left
  ( ) Too depressing / grimdark
  ( ) Too many seasons / Time commitment
  ( ) Better options on my watchlist
         │
         ▼
[ Optional Hot Take: "Lost the mystery after park exit" ]
         │
         ▼
[ Save to Personal "Graveyard" (Separate from The Rankings) ]
```

> **Tracking link (epic #168):** dropping a tracked show prefills the drop point from your place, and **Revive** on a dropped show starts tracking again from it. See [features/11](11_WATCH_TRACKING_AND_EPISODE_PROGRESS.md) §4.6–§4.7. Season duels (§2.2) are planned in epic #216.

### 3.3 The "Would You Revisit?" Indicator
Each dropped show has a quick binary state:
- 🚪 **Dead & Buried:** Never going back.
- 🔄 **On Pause / Willing to Revisit:** If friends convince them it gets better or if a new season redeems it.

---

## 4. UI/UX Wireframe: Season Breakdown & Dropped Card

### 4.1 Series Detail with Season Expanders
```
┌────────────────────────────────────────────────────────┐
│ [←]                  SHOW DETAIL                       │
│                                                        │
│  ┌──────────┐  TRUE DETECTIVE                          │
│  │ [Poster] │  HBO • 4 Seasons • Crime / Anthology     │
│  │          │  Your Series Rank: #18 (Score: 8.84)     │
│  └──────────┘  Ending Impact: ⏳ Ongoing               │
│                                                        │
│  ━ SEASONS BREAKDOWN ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                        │
│  [+] Season 1 (2014) • 8 Episodes                      │
│      Your Season Rank: #2 All-Time (Score: 9.92)       │
│      "Rust Cohle monologue perfection"                 │
│                                                        │
│  [+] Season 2 (2015) • 8 Episodes                      │
│      Your Season Rank: #94 (Score: 5.21)               │
│      "Convoluted plot, missed the gothic mood"         │
│                                                        │
│  [+] Season 4: Night Country (2024) • 6 Episodes       │
│      Your Season Rank: #42 (Score: 7.68)               │
│                                                        │
└────────────────────────────────────────────────────────┘
```

### 4.2 The Dropped Feed Card (Social Hook)
```
┌────────────────────────────────────────────────────────┐
│ 💀 DNF ALERT                                           │
│ Marcus dropped THE MORNING SHOW at S2:E03              │
│ Reason: "Writing jumped the shark"                     │
│ Hot take: "Too soapy and overdramatic now."            │
│ [ Agree (24) ]   [ "It gets better!" (6) ]             │
└────────────────────────────────────────────────────────┘
```

---

## 5. Data Model & Database Contracts

> **Schema note:** SQL in this document is illustrative. The normative contract is [Spec 02](../technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md) (table `titles` keyed by `(id, media_type)`, `media_type_enum ('movie','tv')`, `rank_position`), and the executable source is `supabase/migrations/`.

```sql
-- Seasons Table (Cached from TMDB)
CREATE TABLE tv_seasons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    show_id INT REFERENCES titles(id) ON DELETE CASCADE,
    season_number INT NOT NULL,
    title VARCHAR(100),
    episode_count INT NOT NULL,
    air_date DATE,
    poster_path TEXT,
    overview TEXT,
    UNIQUE(show_id, season_number)
);

-- User Season Ranking Table (Sub-layer rankings)
CREATE TABLE user_season_rankings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    season_id UUID REFERENCES tv_seasons(id) ON DELETE CASCADE,
    season_rank INT NOT NULL,
    calculated_score NUMERIC(3, 2) NOT NULL,
    review_short VARCHAR(280),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, season_id)
);

-- User Dropped / DNF Log Table
CREATE TABLE user_dropped_shows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    show_id INT REFERENCES titles(id) ON DELETE CASCADE,
    stopped_at_season INT NOT NULL,
    stopped_at_episode INT,
    drop_reason VARCHAR(64) NOT NULL,
    willing_to_revisit BOOLEAN DEFAULT FALSE,
    notes VARCHAR(280),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, show_id)
);
```

---

## 6. Social Dynamics of Dropped Shows
1. **The "Rescue Prompt":** If user A drops a show at Season 2, but User B (who has a 92% Taste Match with User A) ranked Season 3 as a 9.5 God Tier, Telly sends a friendly prompt:
   *"Maya loved Season 3 of Succession! Want to push through?"*
2. **Global "Drop Rate" Radar:** On the Discover tab for any show, display an aggregate community survival chart:
   - *85% made it past Season 1*
   - *62% completed the series*
   - *Primary drop point: Season 2, Episode 3*
