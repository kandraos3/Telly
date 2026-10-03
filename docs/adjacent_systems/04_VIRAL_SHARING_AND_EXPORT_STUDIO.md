# Adjacent Systems Spec 04: Viral Sharing Studio, Deep-Linking & Data Export

## 1. Overview & Growth Thesis
Beli’s viral explosion was driven by frictionless, aesthetic social sharing. People love broadcasting their tastes on Instagram Stories, TikTok, and group chats—provided the graphics look like prestige magazine covers rather than ugly app screenshots.

**Telly’s Sharing Architecture provides:**
1. **Dynamic High-Res Story Cards:** Native rendering of 1080x1920 9:16 vertical graphics optimized for Instagram and TikTok.
2. **Universal Smart Deep-Links (`telly.app/...`):** Links that open directly inside the app, or gracefully unfurl rich OpenGraph media on the web for unregistered users.
3. **Open Data Portability:** 1-tap export to CSV, Notion databases, and Letterboxd-compatible formatting.

---

## 2. Share Card Templates & Specifications

All share cards are rendered off-screen at **1080 x 1920 px (3x Retina)** with true OLED black canvas (`#08090C`) and Phosphor Lime / Warm Amber accents:

```
┌────────────────────────────────────────────────────────┐
│                   SHARE CARD TEMPLATES                 │
├────────────────────────────────────────────────────────┤
│  TEMPLATE A: THE TOP 9 CANON (3x3 Grid)                │
│  • Edge-to-edge 3x3 grid of posters                    │
│  • User handle @jordan & dynamic average score         │
│  • Tagline: "My All-Time TV Canon on Telly"            │
│                                                        │
│  TEMPLATE B: THE CONTROVERSIAL UPSET CARD              │
│  • Split poster duel: Severance vs Succession          │
│  • Spicy callout: "I ranked Severance over Succession" │
│  • Interactive sticker prompt: "Am I crazy? Yes / No"  │
│                                                        │
│  TEMPLATE C: THE TASTE MATCH CARD                      │
│  • Jordan @jordan  ⚡  Maya @maya                       │
│  • Large 88% Taste Match badge with glowing aura       │
│  • Top 3 Shared Favorites listed beneath               │
│                                                        │
│  TEMPLATE D: THE TIER LIST POSTER                      │
│  • S/A/B/C horizontal rows of mini-posters             │
│  • Perfect for end-of-year recap sharing               │
└────────────────────────────────────────────────────────┘
```

---

## 3. Client-Side Image Rendering Engine

### 3.1 Architecture: Flutter `RepaintBoundary` / React Native `react-native-view-shot`
To ensure instant, offline-capable sharing without waiting for server render queues:
1. The app renders a dedicated off-screen widget tree at fixed dimensions (1080x1920).
2. Uses high-resolution cached network images (bypassing compressed thumbnails).
3. Converts widget pixel raster to PNG via native byte buffer (`toImage(pixelRatio: 3.0)`).
4. Pipes byte stream directly to the platform share bridge:
   - **iOS:** `UIActivityViewController` with `instagram-stories` pasteboard scheme.
   - **Android:** `Intent(Intent.ACTION_SEND)` targeting `com.instagram.share.ADD_TO_STORY`.

---

## 4. Universal Deep-Linking & Web Unfurl (`telly.app`)

When a user shares a link into WhatsApp, iMessage, Twitter/X, or Slack, Telly serves high-fidelity OpenGraph metadata:

### 4.1 URL Route Taxonomy
- **User Profile:** `https://telly.app/u/{username}`
- **Specific Ranking Log:** `https://telly.app/log/{log_uuid}`
- **Show Detail:** `https://telly.app/show/{tmdb_id}`
- **Two-to-Watch Invite:** `https://telly.app/duel/join/{session_code}`

### 4.2 Web Fallback (Unregistered Users)
If a user taps `https://telly.app/u/jordan` on desktop or without the app installed:
- Loads a lightweight, mobile-responsive web view.
- Displays Jordan's Top 10 Canon in high resolution.
- Prompts an interactive hook: *"See your Taste Match with Jordan (Takes 60 seconds)"*.
- Persistent banner: `[ Download Telly on App Store / Google Play ]`.

---

## 5. Comprehensive Data Export Suite

Telly respects data ownership. Users can export their complete entertainment history in 3 formats:

### 5.1 Format 1: Clean CSV Export
Includes every show, personal rank, dynamic score, status, drop milestone, review, and tags:
```csv
title,tmdb_id,rank,score,status,tier,review,mvp_actor,tags,date_logged
"Succession",76331,1,10.00,"COMPLETED","God Tier","Flawless finale","Jeremy Strong","FlawlessFinale;PeakDialogue","2024-05-12"
"Severance",110492,2,9.72,"COMPLETED","God Tier","Elevator sequence peak","Adam Scott","MindBending","2024-06-20"
"Westworld",63247,null,null,"DROPPED","Graveyard","Lost mystery in S3","Jeffrey Wright","PacingSlowedDown","2023-11-04"
```

### 5.2 Format 2: Notion Database Format
- Exports a pre-formatted JSON / Markdown schema optimized for 1-click import into Notion databases with multi-select tags, tier status pills, and poster image URLs.

### 5.3 Format 3: Letterboxd Compatible Mapper
- Formats TV miniseries and series entries into Letterboxd's standard import format (`Title, Year, Rating10, WatchedDate`), allowing cinephiles to synchronize their accounts effortlessly.

### 5.4 Format 4: MyAnimeList & AniList XML/JSON Export
- Exports user's ranked anime into standard MyAnimeList XML or AniList JSON export format (`anime_id, my_score, my_status, my_watched_episodes`), allowing two-way data portability between Telly and dedicated anime trackers.
