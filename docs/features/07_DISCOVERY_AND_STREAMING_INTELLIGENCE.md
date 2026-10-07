# Feature Spec 07: Discovery, Smart Queue & Streaming Intelligence

## 1. Overview & Ecosystem Position
Discovery in modern television is broken because users are scattered across fragmented streaming silos. A user might maintain a watchlist inside Netflix, another inside Hulu, and another on Apple TV+, with no centralized view of what they actually want to watch.

**Telly's Discovery & Streaming Architecture:**
1. **The Universal Smart Queue:** A single, consolidated watchlist that automatically tags which of your subscribed streaming services currently hosts each show.
2. **Streaming Intelligence (JustWatch Integration):** Dynamic deep-linking directly into streaming apps (tap *"Watch on Max"* to launch the episode immediately on your phone or smart TV).
3. **Availability & Expiration Alerts:** Notifications when a show on your watchlist is about to leave a service or newly arrives on one of your subscriptions.
4. **Network Battlegrounds & Curated Collections:** Fun, competitive community rankings comparing networks and themes.

---

## 2. The Smart Queue (Watchlist) Architecture

> Tracking: epic #47 · Status: approved · Decision: [0004](../decisions/0004-canon-podium-and-queue-up-next.md)

The Queue leads with one title to watch next, and the rest of the watchlist follows as compact rows. Screen spec `SCR-13` has the exact layout and states, and the approved mockup is [0047](../design_system/mockups/0047-canon-queue-layouts.html).

```
┌────────────────────────────────────────────────────────┐
│ [←]  Queue                                       [ ☷ ] │  ☷ = custom lists
│  [   Movies 14   |   TV Shows 24   ]      [ ⚲ Filter ] │  sort + On My Services
├────────────────────────────────────────────────────────┤
│  UP NEXT  The Bear · Disney+ · ★ 8.60   [↻ Another]    │
│  [ ▶ Watch on Disney+ ]                     [ ✓ Seen ] │
│  ━ THEN ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 23   │
│  Slow Horses     Apple TV+ · ★ 8.94      [▶ Apple TV+] │
│  Station Eleven  Max · ★ 8.81                  [▶ Max] │
└────────────────────────────────────────────────────────┘
```

- **Up next pick:** a uniformly random title from the titles the current filter shows for the selected canon. It's re-rolled each time the Queue opens, and ↻ picks a different one. A smart pick (friends' scores, taste match, leaving soon, how long a title has waited) is tracked in #124.
- **Mark seen:** a swipe right on a row, or ✓ Seen on the Up next card. The title leaves the queue, and the Log flow opens to rank it.

### 2.1 Smart Queue Sorting Modes
Users sort their queue from the Filter sheet. *Friends' High Score* and *Leaving Soon* are built; the others are planned:
- **Friends' High Score (Default):** Shows rated highest by their social circle.
- **Taste Match Priority:** Shows loved by friends with the highest Taste Match %.
- **Shortest Time Commitment:** Prioritizes limited miniseries (4–8 episodes) for quick weekend completions.
- **Leaving Soon:** Prioritizes shows about to expire from your active streaming services.

---

## 3. Streaming Intelligence & Deep-Linking

### 3.1 JustWatch API Data Flow
Telly integrates with the JustWatch API to maintain a fresh, geolocation-aware map of streaming availability:

```
[ User in US with Netflix + Max ] 
               │
               ▼
[ Request Show Availability: TMDB ID 87108 (Chernobyl) ]
               │
               ▼
[ JustWatch Lookup: US Region ]
  • Subscription: Max (Available)
  • Buy/Rent: Apple TV ($14.99), Prime ($14.99)
               │
               ▼
[ Client Action: "Watch on Max" button highlighted in neon ]
[ Tap Action: Launches max://deep_link_url or opens web ]
```

### 3.2 Deep-Link URI Schemes
- **Netflix:** `nflx://www.netflix.com/title/{netflix_id}`
- **Max:** `https://play.max.com/show/{max_id}`
- **Apple TV+:** `https://tv.apple.com/us/show/{slug}/{apple_id}`
- **Hulu:** `hulu://series/{hulu_id}`
- **Prime Video:** `primevideo://watch?asin={asin}`

---

## 4. Availability & Expiration Alerts

One of the most valuable utility features is keeping users from missing out on content before licensing agreements expire:
1. **"Leaving Soon" Trigger:**
   *"⚠️ Fargo (Season 1–4) is leaving Hulu in 7 days! It's currently #2 on your Watchlist."*
2. **"Just Arrived on Your Services" Trigger:**
   *"🎉 Severance Season 2 just premiered on Apple TV+!"*
3. **"Price Drop / Free to Stream" Alert:**
   *"The Wire is now available with your Max student plan."*

---

## 5. Network Battlegrounds & Editorial Hubs

```
┌────────────────────────────────────────────────────────┐
│  🧭 DISCOVER: NETWORK BATTLEGROUNDS                    │
├────────────────────────────────────────────────────────┤
│                                                        │
│  👑 HBO vs 🍏 Apple TV+ vs 🔴 Netflix                  │
│                                                        │
│  Which network has the highest average quality?        │
│  Based on 1.2M Community Pairwise Battles:             │
│                                                        │
│  1. HBO / Max       Avg Score: 8.82 / 10.0             │
│     Top 3: The Wire, Succession, Sopranos              │
│                                                        │
│  2. Apple TV+       Avg Score: 8.41 / 10.0             │
│     Top 3: Severance, Slow Horses, Ted Lasso           │
│                                                        │
│  3. FX / Hulu       Avg Score: 8.35 / 10.0             │
│     Top 3: The Bear, Fargo, It's Always Sunny          │
│                                                        │
│  4. Netflix         Avg Score: 7.64 / 10.0             │
│     Top 3: Mindhunter, Dark, Stranger Things           │
│                                                        │
└────────────────────────────────────────────────────────┘
```

### Curated Editorial Collections
- **The "Stuck the Landing" Canon:** Series with unanimous community approval for their finales.
- **The "One-and-Done" Masters:** Greatest single-season miniseries of all time (*Chernobyl*, *Band of Brothers*, *Watchmen*, *Queen's Gambit*).
- **The "Comfort Rewatch" Pantheon:** Shows with highest rewatch velocity (*The Office*, *New Girl*, *Brooklyn Nine-Nine*, *Parks and Rec*).

---

## 6. Data Model & Cache Architecture

> **Schema note:** SQL in this document is illustrative. The normative contract is [Spec 02](../technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md) (table `titles` keyed by `(id, media_type)`, `media_type_enum ('movie','tv')`, `rank_position`), and the executable source is `supabase/migrations/`.

```sql
-- Streaming Providers Master Table
CREATE TABLE streaming_platforms (
    id VARCHAR(50) PRIMARY KEY, -- 'netflix', 'max', 'apple_tv_plus', 'hulu'
    display_name VARCHAR(100) NOT NULL,
    logo_url TEXT NOT NULL,
    base_deep_link TEXT,
    is_free_tier BOOLEAN DEFAULT FALSE
);

-- Show Availability Table (Updated daily via JustWatch webhook / cron)
CREATE TABLE show_streaming_availability (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    show_id INT REFERENCES titles(id) ON DELETE CASCADE,
    platform_id VARCHAR(50) REFERENCES streaming_platforms(id) ON DELETE CASCADE,
    country_code VARCHAR(2) NOT NULL DEFAULT 'US',
    monetization_type VARCHAR(20) NOT NULL, -- 'FLATRATE', 'FREE', 'RENT', 'BUY'
    deep_link_url TEXT,
    available_until DATE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(show_id, platform_id, country_code, monetization_type)
);

-- User Subscription Table
CREATE TABLE user_streaming_subscriptions (
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    platform_id VARCHAR(50) REFERENCES streaming_platforms(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, platform_id)
);
```
