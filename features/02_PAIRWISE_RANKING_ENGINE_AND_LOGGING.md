# Feature Spec 02: Pairwise Ranking Engine & Logging Workflow

## 1. Overview & Conceptual Architecture
The Pairwise Ranking Engine is the intellectual core and primary differentiator of **Telly**. 

Traditional entertainment platforms ask users: *"Rate this show or movie from 1 to 10."* This causes cognitive fatigue, scale drift over years, and extreme rating compression (everything is an 8). Telly never asks for an arbitrary numerical score. Instead, it prompts **binary comparative decisions**:
$$\text{Item } A \succ \text{Item } B \quad \text{or} \quad \text{Item } B \succ \text{Item } A$$

Through binary search insertion, any newly logged film or series can be placed with mathematical precision into a user's existing ranked list of 100+ titles in just **3 to 5 rapid taps** ($\mathcal{O}(\log_2 N)$ complexity).

### 1.1 Segregated Dual-Canon Architecture
To preserve mathematical sorting integrity and prevent the cognitive friction of comparing a 2-hour movie against an 80-hour television epic:
- **Movie Canon**: All feature films, anime films, and documentaries duel exclusively against movies.
- **Series & Anime Canon**: All serialized television, limited series, and anime seasons duel exclusively against series.
- Cross-medium duels are prohibited in core ranking tournaments (available only in optional novelty friend battles).

---

## 2. The Complete Logging Workflow

```
[ Tap "+" / Search Title (TMDB Multi-Search) ]
          │
          ▼
Step 1: Media Type Detection & Progress Selection
        • If Movie: First Time vs Rewatch (increments counter)
        • If Series: Finished Whole Series | Up to Date | Season Only | Dropped
          │
          ▼
Step 2: Initial Sentiment Bracket (Coarse Sort)
        • Masterpiece (Top 10%)
        • Loved It (Top 25%)
        • Liked It (Middle 40%)
        • Meh / Average (Bottom 20%)
        • Disappointed (Bottom 5%)
          │
          ▼
Step 3: Pairwise Duel Tournament (Segregated Fine Sort)
        • 3-5 Binary comparison cards against same-medium titles
        • Tap winner or tap "Can't Compare / Equal"
          │
          ▼
Step 4: Editorial Metadata & Context
        • Movies: Viewing Venue (Theater/IMAX, Home, Festival), Director, Rewatch Count
        • Series: Finale Impact, Binge Velocity, Season Weights
        • Universal: Vibe tags, Who watched with, MVP Character/Actor, 280-char review
          │
          ▼
Step 5: Canon Placement & Dynamic Score Assignment
        • Celebratory slot reveal (e.g., "#7 of 94 Movies • Score: 9.24")
        • Immediate feed broadcast to friends
```

---

## 3. Mathematical Foundations & Algorithms

### 3.1 The Binary Insertion Sort Algorithm
Let $L = [s_1, s_2, \dots, s_n]$ be the user's existing sorted personal canon, where $s_1$ is their all-time favorite and $s_n$ is their least favorite ($s_i \succ s_{i+1}$).

When inserting a new show $X$:
1. **Bracket Boundary Identification:**
   Based on the user's initial sentiment selection (e.g., *"Loved It"*), we narrow the search space to a sub-array indices $[low, high]$:
   - *Masterpiece:* $[0, \lfloor 0.10 \cdot n \rfloor]$
   - *Loved It:* $[\lfloor 0.10 \cdot n \rfloor, \lfloor 0.35 \cdot n \rfloor]$
   - *Liked It:* $[\lfloor 0.35 \cdot n \rfloor, \lfloor 0.75 \cdot n \rfloor]$
   - *Meh:* $[\lfloor 0.75 \cdot n \rfloor, \lfloor 0.95 \cdot n \rfloor]$
   - *Disappointed:* $[\lfloor 0.95 \cdot n \rfloor, n]$
2. **Binary Decision Loop:**
   While $low \le high$:
   $$mid = \lfloor (low + high) / 2 \rfloor$$
   Present duel: **$X$ vs $s_{mid}$**
   - If user chooses $X \succ s_{mid}$:
     Show $X$ is better than $s_{mid} \implies high = mid - 1$
   - If user chooses $s_{mid} \succ X$:
     Show $X$ is worse than $s_{mid} \implies low = mid + 1$
3. **Insertion:**
   Insert $X$ at index $low$. All subsequent elements shift by +1 rank.
4. **Complexity:**
   Total comparisons needed:
   $$K \le \lceil \log_2(high - low + 1) \rceil \le \lceil \log_2(0.40 \cdot N) \rceil \approx 3 \text{ to } 5 \text{ duels}$$

### 3.2 Deadlock & "Can't Compare" Handling
If a user taps *"Too Different / Can't Decide"* (e.g., comparing a comedy like *Fleabag* against a brutal historical drama like *Chernobyl*):
- The algorithm does NOT corrupt the tree.
- It steps by $\pm 1$ neighbor: compares $X$ against $s_{mid-1}$ or $s_{mid+1}$.
- If still tied, $X$ is placed adjacent to $s_{mid}$ with an identical raw percentile weight.

### 3.3 Dynamic Score Mapping Formula
Unlike Beli, where users are often confused about where scores come from, Telly uses a transparent, deterministic **Prestige Percentile Curve**:

Given a list of $N$ ranked shows, for a show ranked at position $r \in [1, N]$:
$$\text{Percentile}(r) = \frac{N - r}{N - 1} \quad (\in [0.0, 1.0] \text{ for } N > 1)$$

We apply a power-curve transformation with exponent $\gamma = 0.82$:
$$\text{Calculated Score}(r) = 1.0 + 9.0 \times \left(\text{Percentile}(r)\right)^\gamma$$

| Rank Position in 100 Shows | Percentile | Score ($\gamma = 0.82$) | Display Tier |
| :--- | :--- | :--- | :--- |
| **#1** (e.g. *Succession*) | 1.000 | **10.00** | God Tier |
| **#5** | 0.959 | **9.69** | God Tier |
| **#15** | 0.858 | **8.93** | Prestige Tier |
| **#35** | 0.656 | **7.41** | Great Tier |
| **#60** | 0.404 | **5.30** | Good / Mid |
| **#90** | 0.101 | **2.38** | Disappointment |

*Note: For users with fewer than 10 shows, an empirical Bayesian prior is blended to prevent a user's 3rd show from unfairly receiving a 1.0 score.*

---

## 4. UI/UX Wireframe & Duel Interaction

```
┌────────────────────────────────────────────────────────┐
│ [✕]                   DUEL 2 OF 4                      │
│                                                        │
│            WHICH DID YOU PREFER OVERALL?               │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ ┌──────────┐  SEVERANCE                          │  │
│  │ │ [Poster] │  Apple TV+ • 2022 • Sci-Fi / Drama  │  │
│  │ │          │  "Defiant Jazz, waffle party peak"  │  │
│  │ └──────────┘                                     │  │
│  │                [ TAP TO SELECT ]                 │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│                         ━ VS ━                         │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ ┌──────────┐  THE BEAR                           │  │
│  │ │ [Poster] │  FX / Hulu • 2022 • Drama / Comedy  │  │
│  │ │          │  Currently your #5 of 64 shows      │  │
│  │ └──────────┘                                     │  │
│  │                [ TAP TO SELECT ]                 │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│            [  🤷 Equal / Can't Compare  ]               │
└────────────────────────────────────────────────────────┘
```

### Micro-Interactions & Sensory Feedback
- **Card Selection:** Card scales up by 1.03x with a crisp spring curve (`Curves.easeOutBack`), triggering a heavy haptic tick (`HapticFeedback.mediumImpact()`).
- **Loser Card:** Gently fades to 40% opacity and slides off-screen downward.
- **Progress Bar:** Subtle glowing phosphor-lime bar fills at the top: `2 of 4 decisions`.

---

## 5. Metadata Tagging & Logging Modal

Once the rank is established, the user is presented with the **Editorial Details Sheet**:
1. **Status Tag:**
   - *Movies*: `First-Time Watch` | `Rewatch` (increments rewatch counter: 2x, 3x).
   - *Series*: `Finished Series` | `Up to Date` | `Watched Season X` | `Dropped`.
2. **Watch Context & Venue:**
   - *Viewing Venue (Movies)*: `Theatrical / IMAX`, `Home Streaming`, `Film Festival`, `In-Flight`.
   - *Director (Movies)*: Auto-populated from TMDB with 1-tap director filmography link (e.g. *Christopher Nolan*).
   - *Who did you watch with?* Tag Telly friends (auto-creates co-watch record).
   - *Binge Velocity (Series):* `Weekend Binge` | `Weekly Watch` | `Slow Burn (Months)`.
3. **Show Attribute Tags (Select up to 3):**
   - *Movies*: `Cinematography Peak`, `Mind-Bending`, `Emotional Wreck`, `Pacing Perfection`, `Original Screenplay`, `Style Over Substance`.
   - *Series*: `Masterpiece Dialogue`, `Emotional Wreck`, `Peak Comedy`, `Mind-Bending`, `Sluggish Pacing`, `Comfort TV`, `Flawless Finale`.
4. **MVP Character / Actor:**
   - Autocomplete dropdown pulling cast members from TMDB (e.g., *"Jeremy Strong as Kendall Roy"* or *"Cillian Murphy as J. Robert Oppenheimer"*).
5. **Micro-Review (Hot Take):**
   - Max 280 characters. Kept concise to prevent rambling blog posts and maintain high feed readability.

---

## 6. Database Contracts & PostgreSQL RPC

### 6.1 RPC: Insert Title and Rebalance Specific Media Canon
To ensure ACID compliance and instantaneous re-indexing, ranking insertion is executed via a PostgreSQL stored procedure isolated by `media_type`:

```sql
CREATE OR REPLACE FUNCTION insert_user_ranking_atomic(
    p_user_id UUID,
    p_show_id INT,
    p_target_rank INT,
    p_status watch_status_enum,
    p_finale_impact finale_impact_enum,
    p_review VARCHAR,
    p_tags TEXT[],
    p_character VARCHAR,
    p_media_type media_type_enum DEFAULT 'TV_SERIES',
    p_is_rewatch BOOLEAN DEFAULT FALSE,
    p_venue viewing_venue_enum DEFAULT 'HOME'
) RETURNS VOID AS $$
DECLARE
    v_total_items INT;
    r RECORD;
    v_percentile NUMERIC;
    v_score NUMERIC;
BEGIN
    -- 1. Shift existing ranks for this specific media canon
    UPDATE public.user_rankings
    SET rank_order = rank_order + 1
    WHERE user_id = p_user_id 
      AND media_type = p_media_type 
      AND rank_order >= p_target_rank;

    -- 2. Insert new ranking into designated canon
    INSERT INTO public.user_rankings (
        user_id, show_id, rank_order, calculated_score,
        status, finale_impact, review_short, tags, favorite_character,
        media_type, is_rewatch, venue, updated_at
    ) VALUES (
        p_user_id, p_show_id, p_target_rank, 10.00,
        p_status, p_finale_impact, p_review, p_tags, p_character,
        p_media_type, p_is_rewatch, p_venue, NOW()
    );

    -- 3. Recalculate dynamic scores across this media canon
    SELECT COUNT(*) INTO v_total_items 
    FROM public.user_rankings 
    WHERE user_id = p_user_id AND media_type = p_media_type;

    FOR r IN SELECT id, rank_order FROM public.user_rankings 
             WHERE user_id = p_user_id AND media_type = p_media_type 
             ORDER BY rank_order LOOP
        IF v_total_items = 1 THEN
            v_score := 10.00;
        ELSE
            v_percentile := (v_total_items - r.rank_order)::NUMERIC / (v_total_items - 1)::NUMERIC;
            v_score := ROUND(1.0 + 9.0 * POWER(v_percentile, 0.82), 2);
        END IF;

        UPDATE public.user_rankings
        SET calculated_score = v_score
        WHERE id = r.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 7. Edge Cases, Re-Ranking & Bayesian Confidence

### 7.1 TrueSkill Ranking Uncertainty ($\sigma$) & Confidence Tracking
Every show holds an internal variance rating ($\sigma \in [0.1, 1.5]$):
- **Initial Placement:** When inserted, $\sigma = 1.20$ (**Provisional**).
- **Decay with Duels:** Each consecutive head-to-head battle won or lost against adjacent neighbors reduces $\sigma$ by $0.25$:
  $$\sigma_{\text{new}} = \max\left(0.15, \sigma_{\text{old}} \times 0.75\right)$$
- **Locked State:** When $\sigma < 0.50$, the ranking is marked **🔒 Locked (High Confidence)**.
- **Provisional State:** When $\sigma \ge 0.50$, the show displays a `[ ⚡ Calibrate ]` pill in the user's Canon. Tapping it initiates 2 targeted duels against immediate rank neighbors to solidify its place.

### 7.2 Per-Show Duel Reset ("Start Fresh on This Show")
If a user rewatches a series years later and realizes their opinion has fundamentally shifted:
- A user can tap the context menu on any show $\rightarrow$ `[ 🔄 Reset Duels for This Show ]`.
- This removes the show from the sorted tree and restarts the pairwise tournament from scratch, without wiping the user's notes, tags, or watch history.

### 7.3 Boundary Cases
- **Very First Show Logged ($N=0$):** Automatically assigned Rank #1, Score 10.00, and $\sigma = 0.50$ without any duels.
- **Second Show Logged ($N=1$):** Exactly 1 duel: *"Do you like Show B more or less than Show A?"*
- **"I changed my mind later":** A user can drag-and-drop any show in their Canon list to manually adjust position with real-time score updates.
