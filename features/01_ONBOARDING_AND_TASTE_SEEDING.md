# Feature Spec 01: Onboarding, Cold-Start & Taste Seeding

## 1. Overview & Value Proposition
The onboarding flow solves the fundamental "cold-start" friction in entertainment and ranking apps. If a user downloads an app and is immediately faced with an empty list or forced to manually rate 50 shows one by one, drop-off exceeds 70%.

**The Goal:** Guide a new user from app launch to having a **calibrated Top 5–10 Personal Canon**, a calculated Taste Match with invited friends, and their streaming subscriptions synced in **under 90 seconds**.

---

## 2. User Journey & Step-by-Step Flow

```
[ App Launch ] 
      │
      ▼
1. Welcome & Social Auth (Apple / Google / Phone)
      │
      ▼
2. Streaming Subscriptions Selector (Netflix, Max, Apple TV+, etc.)
      │
      ▼
3. Quick-Picks Seed Grid (Select 8-15 shows you've watched)
      │
      ▼
4. The Rapid Onboarding Tournament (5-7 quick pairwise battles)
      │
      ▼
5. Instant Canon Reveal (Your Initial Top 10 + Dynamic Scores)
      │
      ▼
6. Friend Sync & Referral Taste Match Duel (Immediate Social Hook)
      │
      ▼
[ Land on Feed / Profile Ready ]
```

### Detailed Screen Breakdown

#### Screen 1: Welcome & Value Hook
- **Hero Visual:** Looping ambient video reel of iconic prestige TV scenes with subtle phosphor lime accent lines.
- **Copy:** *"Stop asking what to watch. Rank your canon, compare with friends, settle the debate."*
- **Actions:**
  - `Continue with Apple` (Primary on iOS)
  - `Continue with Google` (Primary on Android)
  - `Continue with Phone Number` (SMS OTP via Twilio / Supabase Auth)
  - Micro-copy: *"By continuing, you agree to our Terms and Privacy Policy."*

#### Screen 2: Streaming Subscriptions (Household Setup)
- **Prompt:** *"Where do you watch?"*
- **Subtext:** *"We’ll tailor recommendations and co-watch deciders to your active subscriptions."*
- **UI Element:** 3x4 grid of high-contrast platform logos with toggle checkmarks:
  - Netflix, Max, Apple TV+, Hulu, Disney+, Prime Video, Paramount+, Peacock, Criterion Channel, **Crunchyroll**, AMC+, YouTube TV.
- **Toggle:** *"Include free platforms (Tubi, Pluto, Kanopy)"* (Default: Off).
- **CTA:** Sticky bottom button: `Continue (X selected)`.

#### Screen 3: The Movie, Series & Anime Tap-Grid (Rapid Recognition)
- **Prompt:** *"Tap movies, series & anime you've watched."*
- **Alternative Fast-Track Sync Options:**
  - `[ 🎬 1-Click Import from Letterboxd ]` (Uploads `diary.csv` or imports public profile)
  - `[ ⚡ 1-Click Import from AniList / MyAnimeList ]` (Instant GraphQL sync for anime trackers)
- **Media Filter Pills:** `[ All ] [ 🎬 Movies ] [ 📺 Series ] [ ⚡ Anime ]`
- **Counter:** Floating badge at bottom: *"Select at least 8 titles (7/8 selected)"*.
- **Curation Strategy:** Dynamic grid of 50 universally recognized cultural tentpoles across Movies, Western TV & Anime:
  - *Movies*: Interstellar, Parasite, Spirited Away, The Godfather, Pulp Fiction, Dune: Part Two, Oppenheimer, The Dark Knight, Whiplash, Spider-Man: Into the Spider-Verse, The Shawshank Redemption.
  - *Series*: Succession, Breaking Bad, The Bear, Game of Thrones, Severance, Fleabag, The Sopranos, Stranger Things, The Office, White Lotus, Shogun, Arcane.
  - *Anime*: Attack on Titan, Frieren, Jujutsu Kaisen, Death Note, Fullmetal Alchemist: Brotherhood, Demon Slayer, Hunter x Hunter, Steins;Gate.
- **Search Bar:** Instant search modal if a user wants to find their specific favorite not in the curated grid.
- **CTA:** Activates into glowing Phosphor Lime once $\ge 8$ titles are selected: `Start Ranking Duels →`.

#### Screen 4: The 60-Second Onboarding Tournament (Dual-Canon Calibration)
Instead of dropping the user into a complex sorting flow, the app runs a streamlined **Segregated Tournament Sort**:
- **Segregated Duels by Canon**:
  - If a user selects both movies and TV/anime, onboarding runs short 3-duel mini-brackets for each medium (`Movie vs Movie` and `Series vs Series`), maintaining the fundamental rule that 2-hour films never battle 80-hour television seasons.
- **Duel Screen UI:**
  - Split-screen comparison card:
    - Top Card: Candidate A (Poster art, title, release year, runtime/network badge, media pill).
    - Bottom Card: Candidate B (Poster art, title, release year, runtime/network badge, media pill).
    - Center Divider: Glowing neon VS badge.
  - Progress indicator at top: `Movie Duel 2 of 3 • Calibrating your Movie Canon`.
  - Tap card = Winner. Gentle haptic bump (`HapticFeedback.selectionClick()`).
  - Slide up/down gesture also allowed.
  - Option to tap *"Too different / Hard to say"* (picks an alternate pair without penalizing the sort).
- **Behind the Scenes:** The selected titles are sorted into their respective canons using lightweight Merge Sort / Binary Insertion tournaments requiring only 5 to 7 pairwise decisions total.

#### Screen 5: The "Dual Canons Unveiled" Celebration
- **Animation:** Confetti burst + celebratory card flip showing the user's newly established **Initial Top 5 Leaderboards** with a segmented toggle: `[ 🎬 Top Movies ] [ 📺 Top Series & Anime ]`.
- **Display:**
  - #1 title in each canon highlighted with gold foil border and dynamic score (e.g. `9.85`).
  - #2 - #5 ranked with scores descending naturally (`9.42`, `9.10`, `8.85`, `8.60`).
- **Shareable Action:** *"Share your Starter Canons to Instagram Story"* (Generates 9:16 aesthetic asset).
- **CTA:** `Finish & Find Friends →`.

#### Screen 6: Friend Connect & Referral Duel
- **Address Book Sync:** Optional permission prompt: *"Find friends from your contacts who use Telly"*.
- **If User Arrived via Referral Link (`telly.app/u/jordan`):**
  - **Special Screen:** *"You were invited by Jordan! Let's see your Taste Match."*
  - Shows 3 head-to-head battles on shows both users picked.
  - Calculates immediate Taste Match: *"You and Jordan have an 88% Taste Match 🔥"*.
- **CTA:** `Go to Home Feed`.

---

## 3. Wireframes & Layout Specification

```
┌────────────────────────────────────────────────────────┐
│ [←]               STEP 3 OF 5               [Skip]     │
│                                                        │
│  Tap the shows you've watched                          │
│  Select 8 or more to calibrate your taste profile      │
│                                                        │
│  [ 🔍 Search any TV series...                        ] │
│                                                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │ [Poster] │  │ [Poster] │  │ [Poster] │              │
│  │Severance │  │The Bear  │  │Succession│              │
│  │   [✓]    │  │   [✓]    │  │   [✓]    │              │
│  └──────────┘  └──────────┘  └──────────┘              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │ [Poster] │  │ [Poster] │  │ [Poster] │              │
│  │Euphoria  │  │Shogun    │  │B. Bad    │              │
│  │   [ ]    │  │   [✓]    │  │   [✓]    │              │
│  └──────────┘  └──────────┘  └──────────┘              │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │  8 of 8 Selected! Ready to Rank                  │  │
│  │  [       BUILD MY CANON (5 DUELS)  →          ]  │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

---

## 4. Technical Architecture & Data Contracts

### 4.1 Client-Side Tournament State Machine
```dart
enum OnboardingState {
  auth,
  streamingProviders,
  seedSelection,
  tournamentActive,
  canonReveal,
  socialConnect,
  completed
}

class TournamentDuel {
  final Show candidateA;
  final Show candidateB;
  Show? winner;
  
  TournamentDuel({required this.candidateA, required this.candidateB});
}
```

### 4.2 API Endpoint: Ingest Onboarding Canon
- **Method:** `POST /api/v1/onboarding/complete`
- **Headers:** `Authorization: Bearer <JWT>`
- **Request Payload:**
```json
{
  "streaming_providers": ["netflix", "max", "apple_tv_plus"],
  "referral_code": "jordan_prestige",
  "ranked_items": [
    { "tmdb_id": 157336, "media_type": "MOVIE",     "rank": 1 },  // Interstellar
    { "tmdb_id": 496243, "media_type": "MOVIE",     "rank": 2 },  // Parasite
    { "tmdb_id": 110492, "media_type": "TV_SERIES", "rank": 1 },  // Severance
    { "tmdb_id": 76331,  "media_type": "TV_SERIES", "rank": 2 },  // Succession
    { "tmdb_id": 1429,   "media_type": "TV_SERIES", "rank": 3 }   // Attack on Titan
  ],
  "duel_history": [
    { "winner_id": 157336, "loser_id": 496243, "media_type": "MOVIE" },
    { "winner_id": 110492, "loser_id": 76331,  "media_type": "TV_SERIES" }
  ]
}
```

- **Response Payload:**
```json
{
  "status": "success",
  "user_id": "8c6b755b-f1f3-42bf-9051-f2fbe4fbc112",
  "movie_canon_count": 2,
  "series_canon_count": 3,
  "scores_assigned": {
    "157336": 9.85,
    "496243": 9.20,
    "110492": 9.85,
    "76331": 9.35,
    "1429": 8.90
  },
  "referrer_taste_match": {
    "referrer_username": "jordan",
    "movie_match_pct": 92,
    "series_match_pct": 85,
    "blended_match_pct": 88
  }
}
```

---

## 5. Edge Cases & Fallbacks
1. **User only picks 1–3 shows:** Show a motivational sheet: *"Pick at least 5 shows so we can calibrate your taste! Think of your favorite comedy, comfort watch, or classic drama."*
2. **User skips onboarding:** If a user insists on skipping, seed profile with 0 rankings, but place an unobtrusive persistent pill on the Feed: *"⚡ Calibrate your TV Canon (3 mins)"*.
3. **No network connection during tournament:** Duel queue is kept entirely in local client state (`SharedPreferences` or SQLite); upon network recovery, the final batch is flushed to Supabase.
