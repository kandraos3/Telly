# Feature Spec 04: Social Graph, Activity Feed & The "Upset Engine"

> Tracking: epic #48 · Status: approved · Decision: [0009](../decisions/0009-social-friends-search-and-privacy.md)

## 1. Overview & The Beli Social Hook
The reason Beli became a viral sensation among Gen Z and millennials—surpassing Yelp—is that dining is inherently social and competitive. People care far more about what their 10 close friends think than what 50,000 anonymous reviewers say.

In television, this dynamic is amplified tenfold. Everyone has a strong opinion on whether *The Bear* is better than *Succession*, or whether *Severance* lived up to the hype.

**Telly's Social Architecture:**
1. **The Curated Activity Feed:** Focused on high-signal ranking updates, not mindless status changes.
2. **The "Upset & Controversy Engine":** An algorithmic detector that flags spicy takes and pairwise upsets.
3. **1-Tap Frictionless Queue Saving:** See what a friend watched, save it to your watchlist in one tap.
4. **Squads / Circles:** Private shared leaderboards for roommates, partners, or friend groups.

---

## 2. The Activity Feed Architecture

```
┌────────────────────────────────────────────────────────┐
│  [ Following ]       [ Squads (3) ]       [ Global ]   │
├────────────────────────────────────────────────────────┤
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 👤 Jordan @jordan • 2h ago                       │  │
│  │                                                  │  │
│  │ 🚨 UPSET OF THE WEEK                             │  │
│  │ Ranked SEVERANCE (#2) over SUCCESSION (#4)       │  │
│  │                                                  │  │
│  │ ┌──────────┐  "The season 2 finale was the most  │  │
│  │ │ [Poster] │  stressful 60 minutes of television │  │
│  │ │Severance │  in the last decade. Absolute peak."│  │
│  │ └──────────┘                                     │  │
│  │                                                  │  │
│  │ Tier: 👑 God Tier (Score: 9.72)                  │  │
│  │ Tags: #MindBending #FlawlessFinale               │  │
│  │                                                  │  │
│  │ [ + Want to Watch ]    [ 🔥 18 ]  [ 🤯 9 ]  [ 💬 7 ]│
│  └──────────────────────────────────────────────────┘  │
│                                                        │
└────────────────────────────────────────────────────────┘
```

### 2.1 Feed Item Types
1. **The Milestone Entry:** A user finishes a series and places it in their Canon.
2. **The Upset Alert:** A user places a controversial show above a cultural consensus titan.
3. **The DNF (Dropped) Drop:** A user gives up on a show and explains why.
4. **The Finale Reaction:** Immediate hot-take following a season or series finale broadcast.
5. **The Milestone Achievement:** e.g., *"Maya just logged their 100th series!"* Now specified as the medal and finished-challenge cards in [features/10](10_GAMIFICATION_MEDALS_CHALLENGES_AND_LEVELS.md) §10 (#50).

### 2.2 1-Tap Watchlist Ingestion
Every feed card contains a prominent button: `[ + Want to Watch ]`.
- Tapping it instantly saves the series to the viewer's personal Watchlist.
- It automatically attributes the recommendation: *"Recommended by Jordan on Oct 14"*.
- If the viewer already has the show in their Watchlist, the icon displays `[ ✓ In Queue ]`.

---

## 3. The "Upset & Controversy" Engine

### 3.1 What is an "Upset"?
An upset occurs when a user's pairwise ranking decision directly opposes the dominant consensus of their social graph or global community.

### 3.2 The Upset Detection Algorithm
Let $\mu(S_A)$ and $\mu(S_B)$ be the global mean percentiles of Show $A$ and Show $B$.
Let $\sigma(S_A)$ and $\sigma(S_B)$ be their respective standard deviations.

An **Upset Event** is triggered during a user log if:
1. Show $B$ is globally considered superior to Show $A$ by a significant margin:
   $$\mu(S_B) - \mu(S_A) \ge \Delta_{\text{threshold}} \quad (\text{default: } \Delta = 0.25 \text{ or } 2.5 \text{ score points})$$
2. But the user ranks Show $A$ higher than Show $B$:
   $$\text{Rank}(S_A) < \text{Rank}(S_B)$$

### 3.3 Upset Badges & Visual Treatments
- **🔥 Spicy Upset:** Deviation between $2.0$ and $3.5$ score differential.
- **🚨 Taste Crime / Chaos Pick:** Deviation $> 3.5$ score differential (e.g., ranking *Emily in Paris* over *The Wire*).
- Feeds automatically prioritize spicy upsets because they generate **8x higher comment engagement** than agreeable logs.

---

## 4. Squads & Private Circles

### 4.1 Concept
Users often have distinct social sub-cultures:
- *"The Apartment (Roommates)"*
- *"Sci-Fi Book & TV Club"*
- *"Prestige Drama Snobs"*

Users can create **Squads** (up to 30 members) that feature a dedicated **Consensus Squad Leaderboard**.

### 4.2 The Consensus Squad Leaderboard (Borda Count Aggregation)
How do 5 friends determine their collective favorite TV series?
Each member’s personal rank $r_{i, s}$ for show $s$ contributes points via a Borda ranking count:
$$\text{Squad Points}(s) = \sum_{i \in \text{Members}} (N_i - r_{i, s} + 1)$$
*(where $N_i$ is the number of shows ranked by member $i$).*

- The Squad Leaderboard displays:
  - Consensus Rank (#1 to #50)
  - Who ranked it highest (*"Championed by Alex (#1)"*)
  - Who ranked it lowest (*"Hated by Chris (#42)"*)
  - Internal Squad Disagreement Metric (Variance)

---

## 5. Reactions & Micro-Comments

Instead of generic thumbs-up, Telly features TV-specific expressive reactions:

| Reaction | Name | Typical Trigger |
| :--- | :--- | :--- |
| 🔥 | *Facts / Peak* | Agreeing with a high ranking |
| 🤯 | *Mind Blown* | Shocked by an upset or hot take |
| 🗑️ | *Trash Take* | Playful disagreement / controversy |
| 💔 | *Emotional Wreck* | Sad finale or character death empathy |
| 🤝 | *Taste Twin* | Identical favorite episode or character |

### Inline Micro-Threads
- Tapping the comment icon opens a fast-loading bottom sheet.
- Supports tagging specific episodes without spoilers (spoiler tags: `|| Kendall takes the blame ||` automatically blurred).

---

## 6. Social Notifications Engine

High-retention push notification rules:
1. **The Shared Finale Trigger:**
   *"Your friend Maya just finished the Season 2 Finale of Severance! See where she ranked it."*
2. **The Direct Upset Trigger:**
   *"Jordan just ranked The Bear over your #1 favorite show, Succession 👀"*
3. **The Queue Conversion Notification:**
   *"Chris watched Dark from your recommendation and put it in his God Tier!"*
4. **Weekly Squad Digest:**
   *"The Apartment Squad added 6 new shows this week. See the updated leaderboard."*

---

## 7. Data Model: Feeds, Reactions & Squads

```sql
-- Squads Table
CREATE TABLE squads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(64) NOT NULL,
    description VARCHAR(255),
    avatar_url TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE squad_members (
    squad_id UUID REFERENCES squads(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) DEFAULT 'MEMBER', -- 'ADMIN', 'MEMBER'
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (squad_id, user_id)
);

-- Feed Reactions
CREATE TABLE feed_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ranking_id UUID REFERENCES user_rankings(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    reaction_type VARCHAR(20) NOT NULL, -- 'FIRE', 'MIND_BLOWN', 'TRASH', 'HEARTBREAK', 'TASTE_TWIN'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(ranking_id, user_id, reaction_type)
);

-- Comments on Logs
CREATE TABLE ranking_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ranking_id UUID REFERENCES user_rankings(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    comment_text VARCHAR(500) NOT NULL,
    contains_spoilers BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

---

## 8. Friends Outside Squads & Public Profile Exploration — epic #48

> Decision: [0009](../decisions/0009-social-friends-search-and-privacy.md) · Mockup: [0048-social-friends.html](../design_system/mockups/0048-social-friends.html) · Screens: `SCR-05`, `SCR-15`, `SCR-28`

### 8.1 The Social Graph Model
- **Following:** Any user can follow another public user directly. Following displays that user's rankings, upsets, and dropped shows in the follower's `Following` feed.
- **Friends (Mutual Follows):** When two users follow each other, their relationship tier is upgraded to **Friends**.
  - Shows mutual friends indicator badge on profiles and search cards.
  - Enables "Two-to-Watch" co-watching invitations.
  - Friends bypass the private profile barrier on accounts set to `FRIENDS_ONLY`.
- **Follow Requests (Private Accounts):** Following a user with `visibility_mode = 'FRIENDS_ONLY'` creates a pending `follow_request`. The button transitions from `+ Follow` to `Requested`. Once approved by the target user, the relationship status becomes `ACCEPTED` / `Following`.

### 8.2 User Search & Discovery (`SCR-28`)
- **Entry Point:** Search icon (`Icons.search`) in the `SCR-05` Social App Bar routes to `/social/search`.
- **Search Query:** Debounced (300ms) prefix and substring query across `profiles.handle` and `profiles.display_name`.
- **Privacy Filtering:** Users with `visibility_mode = 'GHOST'` are strictly excluded from search results unless the current viewer is already an accepted follower.
- **Card Components:**
  - Avatar with level/reward frame.
  - Display name and `@handle`.
  - Taste match percentage badge (if mutual ratings exist, e.g. `88% Taste Match`).
  - Inline follow button: `+ Follow` (Phosphor Lime outlined), `Requested` (Amber), or `Following` (Stroke Subtle).
  - Tapping the card opens Friend Profile (`SCR-15`, `/u/:handle`).

### 8.3 Public vs Private Profile Navigation
- Tapping any user avatar or username in `SCR-05` (feed card, comment, reaction), `SCR-17` (squad member list), or `SCR-28` (search) opens `/u/:handle`.
- If the account is `PUBLIC`:
  - Full Canon, stats, taste comparisons, and unwatched gems are visible.
- If the account is `FRIENDS_ONLY` and the viewer is not an accepted friend:
  - Header art, avatar, display name, bio, and pinned medals remain visible.
  - The Canon, Taste Match dial, and comparisons are replaced by the Private Account Gate:
    *"This Profile is Friends-Only. @handle shares their Canon and rankings with accepted friends only."*
  - Follow / Request button remains accessible to request access.
