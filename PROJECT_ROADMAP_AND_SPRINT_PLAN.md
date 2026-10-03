# Telly: Engineering Roadmap & 10-Week Sprint Plan

A structured, chronological execution roadmap breaking the entire development process into five 2-week sprints from Day 1 to App Store launch.

---

```
┌────────────────────────────────────────────────────────────────────────┐
│                        10-WEEK PRODUCTION TIMELINE                     │
├────────────────────────────────────────────────────────────────────────┤
│  Sprint 1 (Weeks 1–2): Infrastructure, Auth & Metadata Ingestion       │
│  Sprint 2 (Weeks 3–4): The Pairwise Duel Engine & The Personal Canon   │
│  Sprint 3 (Weeks 5–6): Social Graph, Feeds, Reactions & Upset Alerts   │
│  Sprint 4 (Weeks 7–8): Taste Match %, "Two-to-Watch" & Streaming Links │
│  Sprint 5 (Weeks 9–10): Viral Story Studio, Offline Sync & Launch      │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Sprint 1: Infrastructure, Auth & Foundation (Weeks 1–2)

### Goals
Establish the backend database, Flutter client shell, authentication pipelines, and TMDB show ingestion.

### Tasks & Tickets
- [ ] **BE-101:** Initialize Supabase PostgreSQL 16 project and execute `01_initial_schema.sql` migration.
- [ ] **BE-102:** Execute `top_50_shows_seed.sql` to populate initial TV shows, anime, top 15 iconic films, and streaming platforms.
- [ ] **BE-103:** Configure Twilio Verify service for SMS OTP authentication and link with Supabase GoTrue.
- [ ] **FE-101:** Initialize Flutter 3.24+ project with feature-first folder architecture.
- [ ] **FE-102:** Configure `core/theme` with *Midnight Cathode* palette, GT Super typography, and native haptics.
- [ ] **FE-103:** Build `SCR-01` (Splash & Auth Screen) with Sign in with Apple, Google, and SMS OTP.
- [ ] **FE-104:** Build `SCR-02` (Streaming Provider Household Setup with Crunchyroll) and persist to local Drift SQLite.
- [ ] **FE-105:** Build `SCR-03` (50-Title Movie, TV & Anime Recognition Seed Grid) with multi-select counter badge.
- [ ] **FE-106:** Implement 1-click AniList & MyAnimeList profile importer (fetches completed anime via public username).
- [ ] **FE-107:** Implement 1-click Letterboxd importer (`diary.csv` upload and public username profile sync).
- [ ] **QA-101:** Test Pyramid Setup & Ingestion Unit Tests: Configure `flutter_test`, `mockito`, and unit tests for Letterboxd CSV / AniList GraphQL parsers and Drift SQLite DAOs.

### Acceptance Criteria
- A new user can sign up with Apple or Phone, select streaming services, tap 8 titles or 1-click import from Letterboxd/AniList, and calibrate their initial dual canons in $< 60\text{ seconds}$.

---

## Sprint 2: The Pairwise Ranking Engine & The Canon (Weeks 3–4)

### Goals
Build the core intellectual property of Telly: the binary insertion duel tournament (segregated by canon), dynamic score curve generator, TrueSkill confidence tracking, and multi-view personal dual canon.

### Tasks & Tickets
- [ ] **ALGO-201:** Implement Riverpod `DuelController` state machine with segregated media-type binary search.
- [ ] **ALGO-202:** Implement TrueSkill Bayesian uncertainty ($\sigma$) tracking, visual confidence badges (`Locked` vs `Provisional`), and calibrate duels.
- [ ] **FE-201:** Build `SCR-10` (The Binary Duel Arena) using `flutter_card_swiper` with 60fps spring animations.
- [ ] **FE-202:** Implement haptic impact and winner/loser visual transitions (1.04x scaling, downward fade).
- [ ] **BE-201:** Test and verify `insert_user_ranking_atomic` stored procedure for shifting rows and recalculating scores segregated by `media_type`.
- [ ] **FE-203:** Build `SCR-11` (Editorial Tagging Sheet): MVP character dropdown, vibe tags, audio mode (`Sub` vs `Dub`), 280-char micro-review.
- [ ] **FE-204:** Implement movie-specific logging tags in `SCR-11` (theatrical/IMAX venue, director auto-tag, rewatch counter).
- [ ] **FE-205:** Build `SCR-12` (Celebration Slot Reveal Modal) with counting score animation.
- [ ] **FE-206:** Build `SCR-14` (Profile: The Personal Dual-Canon) with toggle between `[ 🎬 Movie Canon ]` and `[ 📺 Series & Anime ]`, plus view modes (*Ranked List*, *Tier View*, *3x3 Poster Grid*).
- [ ] **FE-207:** Implement Franchise Rollup toggle (collapsing multi-season anime/shows vs unbundling cours).
- [ ] **FE-208:** Implement smooth drag-and-drop manual re-indexing in the Canon with live score updates.
- [ ] **QA-201:** Ranking Engine Unit & Widget Tests: Unit test Binary Insertion Sort ($\mathcal{O}(\log_2 N)$), dynamic percentile curve, and TrueSkill decay; widget test `SCR-10` (Duel Arena) swipe gestures and cards.

### Acceptance Criteria
- User can finish a 4-duel tournament, insert a movie or series into a 100-title canon in $< 15\text{ seconds}$, and view their updated decimal score on an internally consistent, segregated leaderboard.

---

## Sprint 3: Social Graph, Activity Feeds & The Upset Engine (Weeks 5–6)

### Goals
Transform the personal tracking tool into an addictive, competitive social network with feeds, spicy upset alerts, and 1-tap queue saving.

### Tasks & Tickets
- [ ] **BE-301:** Implement `pairwise_duels` audit logging and Upset Detection logic ($\mu_{\text{diff}} \ge 0.25$).
- [ ] **FE-301:** Build `SCR-05` (Activity Feed) with filter tabs (`Following`, `Squads`, `Global`).
- [ ] **FE-302:** Design and implement the Upset Alert feed card with Neon Coral badge and flame reaction pills.
- [ ] **FE-303:** Implement 1-tap `[ + Want to Watch ]` bookmarking that appends shows directly to `user_watchlist`.
- [ ] **FE-304:** Build `SCR-06` (Spoiler-Safe Comment Thread) with frosted Gaussian blur masks (`BackdropFilter`).
- [ ] **FE-305:** Build `SCR-17` (Squads Hub) with Borda Count consensus leaderboard calculation.
- [ ] **FE-306:** Build `SCR-18` (The TV Graveyard) for logging dropped shows with reason taxonomies and revisit toggles.
- [ ] **QA-301:** Social Graph & Database Stored Proc Tests: Setup `pgTAP` suite on Supabase local container for `insert_user_ranking_atomic` and RLS policies; widget test `SCR-05` (Feed Card) and `SCR-06` (Spoiler mask).

### Acceptance Criteria
- A user ranking *The Bear* over *Succession* automatically broadcasts an Upset card to their friends' feeds, allowing friends to react, argue in spoiler-masked comments, or save it to their queue in 1 tap.

---

## Sprint 4: Taste Match %, "Two-to-Watch" & Streaming Links (Weeks 7–8)

### Goals
Solve couch paralysis with the co-watching decider, calculate friend affinity scores, and link directly into native streaming apps.

### Tasks & Tickets
- [ ] **BE-401:** Deploy `calculate_taste_match_rpc` PostgreSQL procedure (Spearman Rank Correlation supporting Movie, Series, and Blended taste matches).
- [ ] **FE-401:** Build `SCR-15` (Friend Profile & Taste Comparison View) showing Movie Taste Match %, Series Taste Match %, and mutual agreements.
- [ ] **BE-402:** Integrate JustWatch / Watchmode API pipeline and Redis availability caching for both movies and series.
- [ ] **FE-402:** Implement `StreamingDeepLinkFactory` with native URI schemes (`max://`, `nflx://`, `hulu://`).
- [ ] **FE-403:** Build `SCR-16` ("Two-to-Watch" Co-Watching Decider): format selection (`[ 🎬 Movie Night ]` vs `[ 📺 Series ]`), runtime budget pills (`< 90m`, `90-120m`, `120m+`), and joint candidate scoring.
- [ ] **FE-404:** Implement the 15-second "Quick Swipe Mode" mutual card-swiping mini-game.
- [ ] **FE-405:** Build `SCR-13` (Smart Queue) with Dual Watchlists and filter: *"Only Titles on My Subscribed Services"*.
- [ ] **QA-401:** Taste Match & Co-Watch Integration Tests: Unit test Spearman Rank Correlation ($\rho$) with Bayesian shrinkage ($k_0 = 5$); integration test "Two-to-Watch" streaming provider matching and deep-link generation.

### Acceptance Criteria
- Two friends sitting on a couch can launch "Two-to-Watch", toggle "Movie Night (< 2h)", find a mutual high-scoring thriller on their shared Max subscription, and tap to launch the film inside the Max app in $< 30\text{ seconds}$.

---

## Sprint 5: Viral Sharing, Offline Hardening & App Store Submission (Weeks 9–10)

### Goals
Polish offline resilience, build aesthetic Instagram Story generators, configure CI/CD automation, and pass Apple/Google app store review.

### Tasks & Tickets
- [ ] **FE-501:** Implement `StoryCardRenderer` using `screenshot` (`RepaintBoundary`) to paint 1080x1920 9:16 graphics off-screen.
- [ ] **FE-502:** Build `SCR-19` (Telly Wrapped Studio) for Top 9 Movie grids, Top 9 Series grids, spicy upset cards, and annual recaps.
- [ ] **FE-503:** Implement Drift SQLite offline write-ahead log (WAL) for 0ms optimistic UI updates during airplane mode.
- [ ] **FE-504:** Build `SCR-20` (Settings Hub) and add self-service CSV, Notion, and Letterboxd data export tools.
- [ ] **FE-505:** Implement Letterboxd migration celebration card (*"Imported 412 films to Telly — here is my true #1"*).
- [ ] **DEV-501:** Set up GitHub Actions CI/CD with Fastlane for automated TestFlight and Google Play distribution.
- [ ] **DEV-502:** Integrate Sentry crash reporting with user breadcrumbs and PostHog product analytics.
- [ ] **QA-501:** End-to-End (E2E) Acceptance & Quality Gates: Implement `package:integration_test` for 4 CUJs, visual golden tests, WCAG 2.1 AA a11y audit, and 60fps frame rate benchmarks in CI.
- [ ] **LEGAL-501:** Deploy live web endpoints for `legal/PRIVACY_POLICY.md` and `legal/TERMS_OF_SERVICE.md`.
- [ ] **LEGAL-502:** Submit production binary to Apple App Store Connect and Google Play Console.

### Acceptance Criteria
- App passes Apple App Store Guidelines (Guideline 1.2 UGC reporting, Guideline 4.8 Sign in with Apple, Privacy Manifest) and Google Play review on first submission.
