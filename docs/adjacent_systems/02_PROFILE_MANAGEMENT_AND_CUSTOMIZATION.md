# Adjacent Systems Spec 02: Profile Customization, Showcase & Privacy Controls

## 1. Overview & Identity Customization
A user's profile on **Telly** is their cinematic resume. Users care deeply about curating their digital identity: their all-time Top 3, their signature aesthetic, their hot-take quote, and their network loyalty badges.

This document details the **Edit Profile Studio**, the **Showcase Architecture**, the **Badge System**, and **Granular Privacy Controls**.

---

## 2. The Edit Profile Studio

```
┌────────────────────────────────────────────────────────┐
│ [✕ Cancel]            EDIT PROFILE             [Save ✓]│
├────────────────────────────────────────────────────────┤
│                                                        │
│  AVATAR & BANNER                                       │
│  ┌──────────────────────────────────────────────────┐  │
│  │ [ Optional Panoramic Cinematic Backdrop Header ] │  │
│  │   ( 👤 Avatar ) [ Change Photo / Character Icon ]│  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  DISPLAY NAME                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Jordan Miller                                    │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  HANDLE                                                │
│  ┌──────────────────────────────────────────────────┐  │
│  │ @jordan                                          │  │
│  └──────────────────────────────────────────────────┘  │
│  (Changing handle may break existing referral links)   │
│                                                        │
│  BIO / TV MANIFESTO (Max 160 chars)                    │
│  ┌──────────────────────────────────────────────────┐  │
│  │ HBO loyalist. Severance truther. Don't talk to   │  │
│  │ me about the Game of Thrones finale.             │  │
│  └──────────────────────────────────────────────────┘  │
│                                              (112/160) │
│                                                        │
│  FAVORITE SHOWRUNNER / CREATOR                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Jesse Armstrong (Succession)                     ▾│  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  CURATE TOP 3 PROFILE SHOWCASES                        │
│  Slot 1: [ Succession (HBO)                          ] │
│  Slot 2: [ Severance (Apple TV+)                     ] │
│  Slot 3: [ The Bear (FX / Hulu)                      ] │
│                                                        │
└────────────────────────────────────────────────────────┘
```

### 2.1 Editable Fields & Validation
- **Display Name:** 2 to 40 characters; UTF-8 emoji supported.
- **Bio / Manifesto:** Max 160 characters; markdown hyperlinks allowed for external Letterboxd/Substack handles.
- **Avatar Uploader:**
  - Photo library integration with interactive 1:1 circular crop tool.
  - Or choose from **Telly Iconic Avatars** (vector illustrations of famous TV icons: *Royco Waystar coffee cup, Lumon blue waffle, The Bear chef apron, Heisenberg fedora*).
- **Panoramic Header (Pro Perk):** Custom 16:9 cinematic still from any show in their God Tier.

---

## 3. The Social Badge & Achievement System

> Superseded by [features/10](../features/10_GAMIFICATION_MEDALS_CHALLENGES_AND_LEVELS.md) (epic #50, decision 0005). The sketch below is kept for history; the medal catalogue, pinning and rarity rules live in features/10 §4.

Badges are awarded algorithmically to celebrate dedication to the medium:

```
┌────────────────────────────────────────────────────────┐
│                   ACHIEVEMENT BADGES                   │
├────────────────────────────────────────────────────────┤
│  👑 CENTURION          Logged 100+ Completed Series    │
│  🍷 PRESTIGE PURIST    >60% of Canon rated 8.5+ is HBO │
│  ⚡ BINGE DEMON        Completed an 8-ep show in <24h  │
│  🔪 CONTROVERSIAL      Logged 5+ Spicy Upsets          │
│  🎯 TASTE TWIN         Found a friend with >92% Match  │
│  🏛️ FOUNDING VIEWER    Registered in the first 10,000  │
└────────────────────────────────────────────────────────┘
```

- **Placement:** Up to 3 badges can be pinned directly beneath the user's name on their public profile card.
- **Tapping a Badge:** Opens a contextual bottom sheet showing who else in their friend circle has unlocked it and global unlock percentage (e.g. *"Unlocked by only 4.2% of viewers"*).

---

## 4. Privacy, Social Boundaries & Ghost Mode

Not everyone wants their entire social graph to know every show they binge or abandon. Telly offers three levels of account visibility:

```
┌────────────────────────────────────────────────────────┐
│ [←]               PRIVACY & BOUNDARIES                 │
├────────────────────────────────────────────────────────┤
│                                                        │
│  ACCOUNT VISIBILITY                                    │
│  (•) Public                                            │
│      Anyone can see your Canon, follow, & compare.     │
│  ( ) Friends Only (Private)                            │
│      Requires follow request approval. Only accepted   │
│      friends can see your rankings and taste match.    │
│  ( ) Ghost Mode                                        │
│      Hidden from global search. Only friends with      │
│      your direct referral link can find you.           │
│                                                        │
│  ━ MODULE PRIVACY TOGGLES ━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                        │
│  [✓] Show TV Graveyard (Dropped Shows) on Profile      │
│      (Disable to keep your abandoned shows private)    │
│                                                        │
│  [✓] Allow Friends to Invite Me to "Two-to-Watch"      │
│                                                        │
│  [✓] Blur Potential Spoilers in My Hot Takes           │
│                                                        │
│  [ ] Hide Exact Watch Velocity / Binge Timestamps      │
│      (Hides "Finished in 2 days" from feed cards)      │
│                                                        │
└────────────────────────────────────────────────────────┘
```

---

## 5. Data Model: Profile Customization & Privacy Settings

```sql
-- Extended User Settings & Privacy Table
CREATE TABLE user_profile_settings (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    visibility_mode VARCHAR(20) DEFAULT 'PUBLIC', -- 'PUBLIC', 'FRIENDS_ONLY', 'GHOST'
    show_graveyard_publicly BOOLEAN DEFAULT TRUE,
    allow_co_watch_invites BOOLEAN DEFAULT TRUE,
    hide_binge_velocity BOOLEAN DEFAULT FALSE,
    auto_blur_spoilers BOOLEAN DEFAULT TRUE,
    pinned_badge_ids TEXT[] DEFAULT ARRAY[]::TEXT[],
    pinned_showcase_show_ids INT[] DEFAULT ARRAY[]::INT[],
    header_backdrop_url TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Follow Requests (For Private / Friends-Only Accounts)
CREATE TABLE follow_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id UUID REFERENCES users(id) ON DELETE CASCADE,
    target_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'PENDING', -- 'PENDING', 'APPROVED', 'REJECTED'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(requester_id, target_user_id)
);
```
