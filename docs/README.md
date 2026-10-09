# 📺 Telly — The Beli for Movies, TV & Anime

> **"Your personal screen rankings. Ranked, shared, settled."**

**Telly** is a modern, social screen entertainment ranking and discovery mobile application designed to bring the viral, pairwise ranking mechanics of **Beli** to movies, television series, and anime.

By eliminating arbitrary, inflated 1–10 star ratings in favor of **head-to-head pairwise duels**, Telly builds an unshakeable personal set of **Rankings** (segregating the **Movie Rankings** from the **Series & Anime Rankings** to avoid apples-to-oranges comparisons), calculates real-time friend **Taste Match %**, and eliminates couch paralysis with the **"Two-to-Watch"** co-watching decider.

---

## 📚 Complete Feature Specifications & Architecture Docs

Each feature of the product is specified in an end-to-end, production-ready engineering and design document:

| Spec # | Feature Specification | Core Focus & Highlights |
| :---: | :--- | :--- |
| **01** | [**`Onboarding & Taste Seeding`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/01_ONBOARDING_AND_TASTE_SEEDING.md) | 90-second cold-start flow, streaming provider setup, 50-title recognition grid, 5-duel starter tournament, 1-click Letterboxd & AniList sync, referral taste match. |
| **02** | [**`Pairwise Ranking Engine & Logging`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/02_PAIRWISE_RANKING_ENGINE_AND_LOGGING.md) | The Beli duel mechanic: binary insertion sort algorithm ($\mathcal{O}(\log N)$), segregated duel tournaments, dynamic percentile curve ($0.0 - 10.0$ scale), tags & MVP character. |
| **03** | [**`Series vs. Seasons & DNF Tracking`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/03_SERIES_VS_SEASONS_AND_DROPPED_TRACKING.md) | The *Game of Thrones* & *True Detective* solution: holistic series layer vs season sub-duels, "Ending Impact" modifiers, and the TV Graveyard (drop milestones & reasons). |
| **04** | [**`Social Graph, Feeds & The Upset Engine`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/04_SOCIAL_GRAPH_FEED_AND_UPSETS.md) | Friends activity feed, algorithmic detection of spicy upsets and controversial takes, 1-tap queue saving, Squad consensus leaderboards, and reactions. |
| **05** | [**`Taste Match % & Co-Watch Decider`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/05_TASTE_MATCH_AND_CO_WATCH_DECIDER.md) | Spearman Rank Correlation math with Bayesian shrinkage, "Two-to-Watch" group recommendation engine (shared streaming filters + mutual watchlist scoring), and 15-second mutual swipe mini-game. |
| **06** | [**`Profile, The Rankings & Stats Engine`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/06_PROFILE_THE_CANON_AND_STATS.md) | The personal rankings profile, Multi-View (Ranked list, Tier view S/A/B/C/D, 3x3 poster grid), deep director/genre slicers, director affinity radar, and "Telly Wrapped". |
| **07** | [**`Discovery & Streaming Intelligence`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md) | Universal Smart Watchlist, JustWatch streaming availability & app deep-linking, "Leaving Soon" expiration alerts, and Network Battlegrounds (HBO vs Apple TV+ vs Netflix). |
| **08** | [**`Anime Integration & Hybrid Rankings`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/08_ANIME_INTEGRATION_AND_HYBRID_CANON.md) | 1-click AniList / MAL profile import, Franchise Rollup (seasons/cours/movies), TrueSkill ranking confidence ($\sigma$), Studio affinity (MAPPA, Ufotable), and seasonal anime charts. |
| **09** | [**`Movie Integration & Dual Canon`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/09_MOVIE_INTEGRATION_AND_DUAL_CANON.md) | First-class movie integration, Dual-Canon segregation architecture (Movie Rankings vs Series Rankings), 1-click Letterboxd `diary.csv` import, theatrical venue tracking, and "Movie Night" decider. |
| **10** | [**`Gamification: Medals, Challenges & Levels`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/10_GAMIFICATION_MEDALS_CHALLENGES_AND_LEVELS.md) | Medals (milestones, TMDB collections, taste, weekly streak), time-boxed and squad challenges run as server data, XP levels with cosmetic rewards, weekly friends tables; only duelled rankings count. |
| **11** | [**`Watch Tracking & Episode Progress`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/11_WATCH_TRACKING_AND_EPISODE_PROGRESS.md) | Currently-watching tracking with one episode place per title, ✓ Watched E6 and Undo, un-logging, new-season detection, the Watching hub, title-page progress and spoiler guard, and the finish → log and duel hand-off. |

---

## 🎨 UI/UX Design System & Experience Architecture

The full visual, interaction, and screen specifications are codified in dedicated design guides:

| Design Doc | Module | Scope & Highlights |
| :---: | :--- | :--- |
| **DS-01** | [**`Design Philosophy & Style Guide`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/01_DESIGN_PHILOSOPHY_AND_STYLE_GUIDE.md) | *Midnight Cathode & Neon Phosphor* aesthetic, OLED surfaces, Phosphor Lime/Warm Amber color tokens, typography (GT Super Serif + Plus Jakarta Sans), and sensory haptics. |
| **DS-02** | [**`Component Library & Patterns`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/02_COMPONENT_LIBRARY_AND_PATTERNS.md) | Floating frosted bottom nav, 4 Show Card variants (Rankings row, Feed card, Queue item, 3x3 poster), Duel Arena card physics, reaction chips, and modal sheets. |
| **DS-03** | [**`Screen-by-Screen Specifications`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md) | Exhaustive layout wireframes, inputs, editable elements, action presentations, and transitions across all 20 screens (`SCR-01` through `SCR-20`). |
| **DS-04** | [**`User Interaction Flows & Gestures`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/04_USER_INTERACTION_FLOWS_AND_GESTURES.md) | Master gesture conventions, end-to-end Mermaid state machines & sequence diagrams for Logging, Co-Watching, Drag-and-Drop Rankings editing, and TV Graveyard DNF logging. |
| **DS-05** | [**`Public Website`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/05_WEBSITE.md) | The public site built from the app: five-chapter landing page (Track, Rank, Discover, Friends, Play), playable hero duel, screenshot scenes, `site/content.yaml` structure and build checks. |

---

## 🛠️ Admin, Identity & Adjacent Systems Architecture

Production-grade specifications for authentication, user profiles, settings, viral sharing, and content moderation:

| Doc # | Module | Scope & Highlights |
| :---: | :--- | :--- |
| **AD-01** | [**`Auth, Registration & Login Flows`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/adjacent_systems/01_AUTH_REGISTER_AND_LOGIN_FLOWS.md) | Social auth (Apple, Google), SMS OTP verification, handle reservation with debouncing, biometric FaceID unlock, and multi-device session management. |
| **AD-02** | [**`Profile Customization & Privacy`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/adjacent_systems/02_PROFILE_MANAGEMENT_AND_CUSTOMIZATION.md) | Edit profile studio, avatar cropping, Top 3 Showcase curation, social achievement badges (Centurion, Prestige Purist), and Public/Friends-Only/Ghost mode. |
| **AD-03** | [**`Settings & Preferences Architecture`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/adjacent_systems/03_SETTINGS_AND_PREFERENCES_ARCHITECTURE.md) | Central settings hierarchy, streaming provider management with JustWatch region selection, granular notification matrix with Quiet Hours, and offline storage hygiene. |
| **AD-04** | [**`Viral Sharing Studio & Data Export`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/adjacent_systems/04_VIRAL_SHARING_AND_EXPORT_STUDIO.md) | High-res 1080x1920 Instagram/TikTok story card generator, universal deep links (`telly.app/u/...`), and 1-tap data exports to CSV, Notion databases, and Letterboxd format. |
| **AD-05** | [**`Trust, Safety & Back-Office Admin`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/adjacent_systems/05_TRUST_SAFETY_MODERATION_AND_ADMIN.md) | In-app spoiler reporting, proactive show-muting shields, `admin.telly.app` back-office moderation queue, TMDB metadata dispute tools, and GDPR 30-day account deletion. |

---

## ⚙️ Technical Architecture & Engineering Specifications

Complete engineering specifications for mobile development, database schemas, external pipelines, and DevOps:

| Doc # | Module | Scope & Highlights |
| :---: | :--- | :--- |
| **TA-01** | [**`Tech Stack, Dependencies & Manifest`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/01_TECH_STACK_AND_LIBRARIES.md) | Flutter 3.24+ (Dart 3.5+) client manifest, Riverpod 2.5+, Drift SQLite ORM, Supabase Postgres 16 backend, Redis 7, and component-by-component library mapping. |
| **TA-02** | [**`Database Schema & Stored Procedures`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md) | Complete PostgreSQL 16 schema, atomic PL/pgSQL procedures (`insert_user_ranking_atomic`, `calculate_taste_match_rpc`), and Redis hash/ZSET caching keys. |
| **TA-03** | [**`External APIs & Data Pipelines`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/03_EXTERNAL_APIS_AND_DATA_PIPELINES.md) | TMDB API v3/v4 integration with Cloudflare edge caching, JustWatch availability scraping, native streaming app deep-linking (`max://`, `nflx://`), and Twilio Verify. |
| **TA-04** | [**`Client Architecture & Offline Sync`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/04_CLIENT_ARCHITECTURE_AND_OFFLINE_SYNC.md) | Feature-first folder structure, Riverpod duel state machine, Drift SQLite offline write-ahead log (WAL), and off-screen 1080x1920 Story Card renderer. |
| **TA-05** | [**`DevOps, CI/CD & Launch Checklist`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/05_DEPLOYMENT_DEVOPS_AND_LAUNCH_CHECKLIST.md) | GitHub Actions + Fastlane iOS TestFlight / Google Play deployment pipelines, Sentry crash observability, PostHog telemetry, and App Store review guidelines. |
| **TA-06** | [**`Testing Framework & Test Pyramid`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) | Quality strategy, classical test pyramid (70% Unit, 20% Integration/Widget, 10% E2E), algorithmic tests (Binary Sort, Spearman Rank, TrueSkill), pgTAP database procedures, and CI/CD quality gates. |

---

## 🏛️ System Architecture Overview

```
                               ┌────────────────────────────────┐
                               │     Flutter / React Native     │
                               │        iOS & Android App       │
                               └───────────────┬────────────────┘
                                               │ (REST / WebSocket)
                                               ▼
                               ┌────────────────────────────────┐
                               │   Supabase API Gateway / Auth  │
                               └───────┬──────────────┬─────────┘
                                       │              │
                   ┌───────────────────┴──────┐       │
                   ▼                          ▼       ▼
      ┌─────────────────────────┐    ┌─────────────────────────┐
      │   PostgreSQL Database   │    │       Redis Cache       │
      │ • user_rankings         │    │ • Active duel sessions  │
      │ • pairwise_duels        │    │ • Real-time social feed │
      │ • taste_matches         │    │ • JustWatch cache (24h) │
      │ • friendships & squads  │    └─────────────────────────┘
      └─────────────────────────┘
                   │
                   ▼
      ┌─────────────────────────┐    ┌─────────────────────────┐
      │        TMDB API         │    │      JustWatch API      │
      │ (Show Metadata, Cast,   │    │ (Streaming Providers,   │
      │  Posters & Episode Data)│    │  Deep Links & Geo-Data) │
      └─────────────────────────┘    └─────────────────────────┘
```

---

## 🛠️ Ready-to-Run Development & Launch Assets

The project is fully equipped with turnkey, executable code assets, schemas, and legal documents:

| Asset | Path | Description & Purpose |
| :--- | :--- | :--- |
| **Roadmap** | [**`ROADMAP.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/ROADMAP.md) | Now / Next / Later themes linking to epic issues on the [Telly board](https://github.com/users/kandraos3/projects/1). |
| **Work Tracking** | [**`process/WORKFLOW.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/process/WORKFLOW.md) | Issues as tickets, board statuses, spec rules, `intake` / `shape` / `ship` skills. Decisions in [`decisions/`](file:///c:/Users/karla/Desktop/SeriesBeli/docs/decisions/), raw input in [`inbox/`](file:///c:/Users/karla/Desktop/SeriesBeli/docs/inbox/). |
| **Sprint History** | [**`history/SPRINTS_1-6_ROADMAP.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/history/SPRINTS_1-6_ROADMAP.md) | Frozen Sprints 1–6 roadmap and Sprint 6 handoff. |
| **Env Template** | [**`.env.example`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/.env.example) | Complete template for Supabase, TMDB, JustWatch, Twilio, Sentry, and OneSignal keys. |
| **DB Migrations** | [**`supabase/migrations/`**](file:///c:/Users/karla/Desktop/SeriesBeli/supabase/migrations/) | Executable schema, RLS policies, indexes and stored procedures (single source of truth; contract in TA-02). |
| **Seed Data** | [**`supabase/seed.sql`**](file:///c:/Users/karla/Desktop/SeriesBeli/supabase/seed.sql) | 50 real shows with accurate TMDB IDs, genres, and streaming services for immediate testing. |
| **Privacy Policy**| [**`PRIVACY_POLICY.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/legal/PRIVACY_POLICY.md) | App Store and Google Play compliant GDPR & CCPA privacy policy. |
| **Terms (EULA)** | [**`TERMS_OF_SERVICE.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/legal/TERMS_OF_SERVICE.md) | EULA with Apple Guideline 1.2 User-Generated Content and spoiler-masking rules. |

---

## 🚀 Quick Summary: Why Telly Wins
1. **No Star Inflation:** Unlike IMDb, where 90% of watchable shows cluster between 7.5 and 8.3, Telly's pairwise sorting creates a mathematically distributed personal canon from 1.0 to 10.0.
2. **Social-First Discovery:** Instead of trusting strangers, users follow their friends and rely on **Taste Match %** (Spearman Rank Correlation) to surface recommendations with near-guaranteed hit rates.
3. **Couch Indecision Eliminated:** The **"Two-to-Watch"** engine merges shared streaming subscriptions and friend watchlists to answer *"What should we watch tonight?"* in under 15 seconds.

