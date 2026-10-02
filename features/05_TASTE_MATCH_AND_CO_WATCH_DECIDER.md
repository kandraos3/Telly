# Feature Spec 05: Taste Match % & The "Two-to-Watch" Co-Watching Decider

## 1. Overview & Problem Definition
Two of the greatest frustrations in entertainment consumption are:
1. **The Trust Gap:** An aggregate IMDb score of 8.2 tells you nothing about whether *you* will like it. But a 9.2 from a friend whose taste aligns with yours 90% of the time is near-guaranteed satisfaction.
2. **The "Couch Paralysis" Dilemma:** A couple or group of roommates sits on the couch for 25 minutes scrolling through Netflix, Hulu, and Max, unable to agree on a single TV show to watch, eventually giving up or rewatching *The Office*.

**Telly's Two-Pronged Solution:**
1. **Taste Match %:** A mathematically rigorous affinity score between any two users based on rank correlation.
2. **"Two-to-Watch" Decider:** A dedicated collaborative tool that merges shared streaming services, intersecting watchlists, and tastes to instantly pick the perfect series for tonight.

---

## 2. Taste Match %: Mathematical Foundation

```
User A's Canon                 User B's Canon
[ 🎬 Movie Canon ]             [ 🎬 Movie Canon ]
1. Interstellar                 1. Oppenheimer
2. Parasite                     2. Interstellar
3. Spirited Away                3. Parasite
4. The Godfather                4. Pulp Fiction
5. The Dark Knight              5. The Dark Knight
        │                              │
        └──────────────┬───────────────┘
                       │
                       ▼
         Mutual Overlapping Movies ($k=4$)
         • Interstellar:  Rank 1 vs 2
         • Parasite:      Rank 2 vs 3
         • The Dark Knight: Rank 5 vs 5
                       │
                       ▼
       Movie Taste Match: 92% 🔥
       Series Taste Match: 84% ⚡
       Blended Overall Match: 88%
```

### 2.1 The Spearman Rank Correlation Algorithm
Let $K = S_A \cap S_B$ be the set of $k$ mutual titles ranked by both User $A$ and User $B$ within a designated media canon ($K_{\text{movies}}$ or $K_{\text{series}}$).
For each title $i \in K$:
- $R_A(i)$ is the rank of title $i$ in User $A$'s canon.
- $R_B(i)$ is the rank of title $i$ in User $B$'s canon.
- $d_i = R_A(i) - R_B(i)$ is the rank difference.

The raw rank correlation coefficient is:
$$\rho = 1 - \frac{6 \sum_{i=1}^k d_i^2}{k(k^2 - 1)} \quad \in [-1.0, 1.0]$$

### 2.2 Confidence Adjustment & Normalization
If two users only share 2 titles, a raw $\rho = 1.0$ is statistically unreliable. We apply a **Bayesian Confidence Shrinkage Factor**:
$$W(k) = \frac{k}{k + k_0} \quad (\text{where baseline prior } k_0 = 5)$$

$$\rho_{\text{adjusted}} = W(k) \cdot \rho + (1 - W(k)) \cdot \rho_{\text{prior}} \quad (\text{where } \rho_{\text{prior}} = 0.0)$$

We then map $\rho_{\text{adjusted}} \in [-1.0, 1.0]$ to a consumer-facing **0% to 100%** scale:
$$\text{Taste Match \%} = \text{ROUND}\left( \frac{\rho_{\text{adjusted}} + 1.0}{2.0} \times 100 \right)$$

- **Movie Taste Match %**: Derived solely from mutual feature films and anime movies.
- **Series Taste Match %**: Derived solely from mutual television series and anime seasons.
- **Blended Overall Match %**: Weighted average based on number of mutual ratings in each medium.

### 2.3 Taste Match Affinity Tiers
- **90% – 100% (Taste Twins):** Eerily identical canons. Follow their recommendations blindly.
- **75% – 89% (Kindred Spirits):** High overlap in core prestige genres; occasional divergence in comedies or indie films.
- **50% – 74% (Casual Acquaintances):** Enjoy mainstream hits together, divergent niche tastes.
- **< 50% (Opposite Ends of the Couch):** One loves reality TV, the other watches slow-burn foreign cinema.

---

## 3. The "Two-to-Watch" Co-Watching Decider

```
┌────────────────────────────────────────────────────────┐
│ [✕]                 TWO-TO-WATCH                       │
│                                                        │
│  WHO'S ON THE COUCH?                                   │
│  (👤 You)   +   (👤 Maya @maya)   [+ Add Friend]       │
│  Movie Match: 92% • Series Match: 84%                  │
│                                                        │
│  FORMAT SELECTION                                      │
│  [  🎬 Movie Night (Single Sitting)  ] [ 📺 Series ]   │
│                                                        │
│  RUNTIME BUDGET (For Movies)                           │
│  [ < 90m (Breezy) ] [ 90–120m (Standard) ] [ 120m+ ]   │
│                                                        │
│  SHARED STREAMING SERVICES (Auto-Detected)             │
│  [✓] Netflix   [✓] Max   [✓] Apple TV+   [ ] Hulu      │
│                                                        │
│  WHAT'S THE VIBE?                                      │
│  [ Thriller / Mystery ]   [ Mind-Bending Sci-Fi ]      │
│  [ Laugh-Out-Loud     ]   [ Oscar / Festival Darling ] │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │     [ 🎲 FIND WHAT TO WATCH TONIGHT ]            │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

### 3.1 The Recommendation Engine Algorithm
When the user taps *"Find What to Watch"*, the engine scores candidate titles from a candidate pool $C$ filtered by the selected format:
$$C = \text{Watchlist}_A \cup \text{Watchlist}_B \cup \text{HighRatedNotSeen}$$

For each candidate title $s \in C$:
1. **Media & Runtime Filter:**
   - If *Movie Night* selected: $s$ must be `media_type = 'MOVIE'` and match the selected runtime budget (e.g., $< 90$ min).
   - If *Series* selected: $s$ must be `media_type = 'TV_SERIES'`.
2. **Streaming Filter:** Must be available on at least one shared service between all participants.
3. **Scoring Function:**
   $$\text{Score}(s) = w_1 \cdot \text{InBothWatchlists}(s) + w_2 \cdot \text{TasteMatch}(A, B) \cdot \text{UserRating}(s) + w_3 \cdot \text{PopularityFactor}(s)$$
   - Both users saved it to their Watchlist $\implies$ **+50 bonus points**.
   - User A ranked it God Tier ($>9.0$) and User B hasn't seen it $\implies$ **+35 points**.
   - Title matches selected vibe/genre tag $\implies$ **+20 points**.

### 3.2 The 15-Second "Rapid Swipe" Duel Mode
If the group still can't pick from the top 3 recommendations, they launch **"Quick Swipe Mode"**:
1. Host generates a session code or starts via nearby Bluetooth / link.
2. Both phones display the same 5 candidate cards simultaneously.
3. Users swipe Right (Yes) or Left (No).
4. **Instant Match Screen:** As soon as both users swipe right on the same title, both screens flash green with confetti:
   *"Tonight's Winner: PARASITE (Max / Criterion)"*
   *"Available on your shared Max subscription • 2h 12m • Directed by Bong Joon-ho"*

---

## 4. Friend Taste Comparison Profile View

Tapping on any friend's profile header displays the **Taste Compatibility Breakdown**:

```
┌────────────────────────────────────────────────────────┐
│ [←]               TASTE COMPARISON                     │
│  You & @maya • 88% Taste Match (34 Mutual Shows)       │
├────────────────────────────────────────────────────────┤
│                                                        │
│  🤝 WHERE YOU AGREE                                    │
│  • Succession (You: #1 • Maya: #2)                     │
│  • Severance  (You: #3 • Maya: #3)                     │
│  • The Bear   (You: #5 • Maya: #6)                     │
│                                                        │
│  ⚡ BIGGEST DIVERGENCES                                │
│  • Game of Thrones                                     │
│    You: #8 (Score: 9.3) • Maya: #64 (Score: 5.1)       │
│    Maya's note: "Season 8 ruined the entire franchise" │
│                                                        │
│  💡 SHOWS MAYA LOVES THAT YOU HAVEN'T WATCHED         │
│  1. Station Eleven (Maya's #4 • HBO/Max)  [+ Queue]    │
│  2. Slow Horses    (Maya's #8 • Apple TV+) [+ Queue]   │
│                                                        │
└────────────────────────────────────────────────────────┘
```

---

## 5. Technical Contracts & Supabase Edge Function

### 5.1 Edge Function: Calculate Real-Time Co-Watch Recommendations
- **Endpoint:** `POST /functions/v1/co-watch-decider`
- **Request Payload:**
```json
{
  "user_ids": [
    "8c6b755b-f1f3-42bf-9051-f2fbe4fbc112",
    "3f7a212c-0e82-411a-912b-7c48f21919a3"
  ],
  "streaming_filter": ["netflix", "max", "apple_tv_plus"],
  "vibe_tags": ["gripping_thriller", "miniseries"],
  "max_runtime_minutes": 60
}
```

- **Response Payload:**
```json
{
  "session_id": "c0-watch-8921",
  "taste_match": 88,
  "top_recommendations": [
    {
      "tmdb_id": 87108,
      "title": "Chernobyl",
      "network": "HBO",
      "available_on": ["max"],
      "match_reason": "On both watchlists & matches miniseries tag",
      "match_score": 98.4,
      "poster_url": "https://image.tmdb.org/t/p/w500/hlLXt2tOPT6RRnjiUmoxyG1LTFi.jpg",
      "overview": "In April 1986, an explosion at the Chernobyl nuclear power plant..."
    },
    {
      "tmdb_id": 93405,
      "title": "Squid Game",
      "network": "Netflix",
      "available_on": ["netflix"],
      "match_reason": "Maya ranked 9.4 (God Tier), You haven't seen",
      "match_score": 92.1,
      "poster_url": "https://image.tmdb.org/t/p/w500/dDlGcaKk5k2n82T1t091.jpg"
    }
  ]
}
```

---

## 6. Performance & Caching Strategy
- Computing Spearman Rank Correlation on 100 shows takes $< 1.2\text{ms}$ in Postgres.
- Precomputed `taste_matches` table is updated asynchronously via background worker whenever either user logs or adjusts a ranking.
- Edge functions cache shared streaming catalogs in Redis with a 24-hour TTL.
