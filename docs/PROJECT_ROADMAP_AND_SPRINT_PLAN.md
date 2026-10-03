# Telly: Engineering Roadmap & Granular 10-Week Sprint Plan

> **Comprehensive engineering execution blueprint breaking down all features, designs, database procedures, APIs, and tests into granular, standalone developer tickets with direct specification links.**

---

## 🧭 Master Project Timeline & Sprint Architecture

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                               10-WEEK PRODUCTION TIMELINE                              │
├────────────────────────────────────────────────────────────────────────────────────────┤
│  Sprint 1 (Weeks 1–2): Infrastructure, Auth, Foundation & Data Ingestion               │
│  Sprint 2 (Weeks 3–4): The Pairwise Duel Engine, Scoring & The Personal Dual-Canon     │
│  Sprint 3 (Weeks 5–6): Social Graph, Feeds, Reactions, Squads & TV Graveyard           │
│  Sprint 4 (Weeks 7–8): Taste Match %, Co-Watch Decider, Streaming Deep Links & Queue   │
│  Sprint 5 (Weeks 9–10): Viral Story Studio, Offline Sync, DevOps, Testing & Launch     │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 📊 Active Sprint Execution Dashboard

- **Current Active Sprint**: **Sprint 1 (Weeks 1–2): Infrastructure, Auth, Foundation & Data Ingestion**
- **Current Active Ticket**: `FE-106`: `SCR-01` Splash & Social / Phone Auth Screen
- **Overall Roadmap Progress**: **6 / 81 Tickets Completed** (7.4%)
- **Active Quality Gate**: Static Analysis (`dart analyze --fatal-infos`), Unit Tests (100% pass)
- **Last Updated**: 2026-10-03

| Sprint | Status | Total Tickets | Completed | Progress |
| :---: | :---: | :---: | :---: | :--- |
| **Sprint 1** | 🟡 **Active** | 15 | 6 | `██████░░░░` 40.0% |
| **Sprint 2** | ⚪ Queued | 16 | 0 | `░░░░░░░░░░` 0% |
| **Sprint 3** | ⚪ Queued | 16 | 0 | `░░░░░░░░░░` 0% |
| **Sprint 4** | ⚪ Queued | 16 | 0 | `░░░░░░░░░░` 0% |
| **Sprint 5** | ⚪ Queued | 18 | 0 | `░░░░░░░░░░` 0% |
| **Total** | | **81** | **6** | **7.4%** |

---

## 📅 Sprint 1: Infrastructure, Auth, Foundation & Data Ingestion (Weeks 1–2)

### Sprint Objective
Establish the Supabase PostgreSQL database, local Drift SQLite persistence, authentication pipelines, core UI design system primitives, and 1-click import parsers for Letterboxd and AniList.

---

### Track 1: Database & Backend Infrastructure

#### `BE-101`: Supabase Project Initialization & Database Migration
- **Spec Reference**: 
  - [**`database/migrations/01_initial_schema.sql`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/database/migrations/01_initial_schema.sql) (Complete executable SQL schema)
  - [**`technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md) §1–§3 (Tables, Indexes, RLS)
- **Scope & Objectives**: Deploy the production database schema to Supabase PostgreSQL 16.
- **Granular Tasks**:
  - [ ] Create Supabase project (`telly-backend-prod`) in US-East / EU-Central.
  - [ ] Execute `01_initial_schema.sql` migration creating core tables: `users`, `titles`, `user_rankings`, `pairwise_duels`, `user_watchlist`, `social_follows`, `squads`, `squad_members`, `comments`, `reports`.
  - [ ] Verify `media_type` enum (`'movie'`, `'tv'`) and indexes on `(user_id, media_type, rank_position)`.
  - [ ] Enable PostgreSQL Row-Level Security (RLS) policies on all tables.
  - [ ] Verify connection strings and configure Supabase Service Role keys in `.env`.
- **Testing & Verification**:
  - [ ] Run verification script to assert 9 tables, 14 indexes, and 18 RLS policies are active.
  - [ ] Verify non-authenticated client cannot bypass RLS on `user_rankings`.
- **Dependencies**: None.

#### `BE-102`: Top 50 Seed Ingestion & Streaming Platform Setup
- **Spec Reference**:
  - [**`database/seeds/top_50_shows_seed.sql`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/database/seeds/top_50_shows_seed.sql) (Seed dataset)
  - [**`technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md) §2.1 (`titles` schema)
- **Scope & Objectives**: Populate the initial recognition dataset with top movies, series, and anime.
- **Granular Tasks**:
  - [ ] Execute `top_50_shows_seed.sql` into the `titles` table.
  - [ ] Verify 20 prestige TV series (*Succession*, *The Bear*, *Severance*), 15 anime classics (*Attack on Titan*, *Frieren*, *Death Note*), and 15 films (*The Dark Knight*, *Parasite*, *Spirited Away*) are seeded.
  - [ ] Verify `streaming_services` JSONB payloads contain valid IDs (`netflix`, `max`, `hulu`, `apple_tv`, `crunchyroll`, `prime_video`).
  - [ ] Create database trigger updating `titles.updated_at` automatically on modification.
- **Testing & Verification**:
  - [ ] Query `SELECT COUNT(*) FROM titles WHERE media_type = 'movie'` returns 15.
  - [ ] Query `SELECT COUNT(*) FROM titles WHERE media_type = 'tv'` returns 35.
- **Dependencies**: `BE-101`.

#### `BE-103`: Supabase GoTrue Auth & Twilio SMS Gateway Integration
- **Spec Reference**:
  - [**`adjacent_systems/01_AUTH_REGISTER_AND_LOGIN_FLOWS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/adjacent_systems/01_AUTH_REGISTER_AND_LOGIN_FLOWS.md) §1–§3 (Social Auth & SMS OTP)
  - [**`technical_architecture/03_EXTERNAL_APIS_AND_DATA_PIPELINES.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/03_EXTERNAL_APIS_AND_DATA_PIPELINES.md) §4 (Twilio Verify)
- **Scope & Objectives**: Configure multi-provider authentication with Apple, Google, and SMS Phone OTP.
- **Granular Tasks**:
  - [ ] Configure Sign in with Apple in Supabase Dashboard with Apple Service ID and private key.
  - [ ] Configure Google OAuth Client ID & Secret for iOS and Android.
  - [ ] Configure Twilio Verify Service SID and Auth Token in Supabase Phone Auth settings.
  - [ ] Create Postgres trigger `on_auth_user_created` to automatically insert a skeleton profile into `public.users`.
- **Testing & Verification**:
  - [ ] Send test SMS OTP to staging test numbers; verify 6-digit code delivery.
  - [ ] Test token issuance and JWT claims including `sub` and `aud`.
- **Dependencies**: `BE-101`.

#### `BE-104`: Edge Function for TMDB Title Search Proxy & Edge Caching
- **Spec Reference**:
  - [**`technical_architecture/03_EXTERNAL_APIS_AND_DATA_PIPELINES.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/03_EXTERNAL_APIS_AND_DATA_PIPELINES.md) §1 (TMDB Integration)
  - [**`features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md) §1 (Catalog Search)
- **Scope & Objectives**: Build a secured Supabase Edge Function proxying TMDB requests with Cloudflare edge caching.
- **Granular Tasks**:
  - [ ] Write Supabase Edge Function `functions/tmdb-search/index.ts` using Deno.
  - [ ] Handle queries for `/search/multi` returning normalized title, year, poster path, and media type.
  - [ ] Inject `Cache-Control: public, max-age=86400, s-maxage=604800` headers for static title lookups.
  - [ ] Configure TMDB Bearer Token in Supabase Secrets vault.
- **Testing & Verification**:
  - [ ] Invoke Edge Function with `"Oppenheimer"`; verify normalized JSON containing `media_type: 'movie'`.
  - [ ] Assert Edge Function fails gracefully with 429 when rate limits are exceeded.
- **Dependencies**: `BE-101`.

---

### Track 2: Flutter Shell & Design System Core

#### `FE-101`: Flutter 3.24+ Shell & Feature-First Directory Architecture
- **Spec Reference**:
  - [**`technical_architecture/01_TECH_STACK_AND_LIBRARIES.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/01_TECH_STACK_AND_LIBRARIES.md) §1 (Flutter & Dart versions)
  - [**`technical_architecture/04_CLIENT_ARCHITECTURE_AND_OFFLINE_SYNC.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/04_CLIENT_ARCHITECTURE_AND_OFFLINE_SYNC.md) §1 (Folder Structure)
- **Scope & Objectives**: Initialize Flutter 3.24+ / Dart 3.5+ project structured strictly by feature slices.
- **Granular Tasks**:
  - [x] Initialize Flutter project: `flutter create --org com.telly.app telly_client`.
  - [x] Configure `pubspec.yaml` with core dependencies: `flutter_riverpod`, `drift`, `supabase_flutter`, `go_router`, `flutter_animate`.
  - [x] Setup folder structure:
    `lib/core/` (network, theme, utils, error),
    `lib/features/auth/`, `lib/features/onboarding/`, `lib/features/ranking/`, `lib/features/feed/`, `lib/features/profile/`, `lib/features/cowatch/`.
  - [x] Configure `analysis_options.yaml` with strict linter rules and `--fatal-infos`.
- **Testing & Verification**:
  - [x] Run `dart analyze` to ensure zero errors and zero warnings.
  - [x] Execute `flutter run` on iOS Simulator and Android Emulator.
- **Dependencies**: None.

#### `FE-102`: Theme, Color Palette & Typography Tokens Setup
- **Spec Reference**:
  - [**`design_system/01_DESIGN_PHILOSOPHY_AND_STYLE_GUIDE.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/01_DESIGN_PHILOSOPHY_AND_STYLE_GUIDE.md) §2–§4 (Palette, Typography)
  - [**`technical_architecture/01_TECH_STACK_AND_LIBRARIES.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/01_TECH_STACK_AND_LIBRARIES.md) §2 (Theme Dependencies)
- **Scope & Objectives**: Codify the *Midnight Cathode* OLED design system into strongly-typed Flutter constants.
- **Granular Tasks**:
  - [x] Create `lib/core/theme/telly_colors.dart`:
    - Backgrounds: `backgroundPrimary` (`#0A0A0C`), `backgroundSurface` (`#141419`), `backgroundCard` (`#1C1C24`).
    - Accents: `phosphorLime` (`#CCFF00`), `neonCoral` (`#FF3366`), `warmAmber` (`#FFB800`), `electricCyan` (`#00F0FF`).
    - Borders: `borderGlass` (`rgba(255, 255, 255, 0.08)`).
  - [x] Add Google Fonts package or local assets for `GT Super Display` (serif headlines) and `Plus Jakarta Sans` (body & numerals).
  - [x] Create `lib/core/theme/telly_typography.dart` with `TextStyle` presets (`displayLarge`, `headlineMedium`, `scoreMono`, `bodySmall`).
  - [x] Assemble `TellyTheme.dark` into `ThemeData` configuring color schemes, app bars, and scaffold backgrounds.
- **Testing & Verification**:
  - [x] Unit test verifying color contrast ratios of `phosphorLime` and `neonCoral` against `#0A0A0C` meet WCAG $\ge 4.5:1$.
  - [x] Widget test rendering all typography variants in a sandbox screen.
- **Dependencies**: `FE-101`.

#### `FE-103`: Haptic Feedback Engine (`HapticsService`)
- **Spec Reference**:
  - [**`design_system/01_DESIGN_PHILOSOPHY_AND_STYLE_GUIDE.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/01_DESIGN_PHILOSOPHY_AND_STYLE_GUIDE.md) §5 (Haptic Sensations)
- **Scope & Objectives**: Build central haptic abstraction delivering customized tactile feedback.
- **Granular Tasks**:
  - [x] Create `lib/core/services/haptics_service.dart`.
  - [x] Implement `duelWinner()` $\to$ `HapticFeedback.mediumImpact()`.
  - [x] Implement `duelSelectCandidate()` $\to$ `HapticFeedback.selectionClick()`.
  - [x] Implement `upsetAlertTriggered()` $\to$ double `HapticFeedback.heavyImpact()` pulse.
  - [x] Implement `scoreReveal()` $\to$ sequential light haptic vibration.
  - [x] Provide toggle in Riverpod user preferences to disable haptics globally.
- **Testing & Verification**:
  - [x] Unit test verifying `HapticsService` respects user `haptics_enabled: false` setting.
- **Dependencies**: `FE-101`.

#### `FE-104`: Core Component Primitives (Buttons, Sheets, Badges)
- **Spec Reference**:
  - [**`design_system/02_COMPONENT_LIBRARY_AND_PATTERNS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/02_COMPONENT_LIBRARY_AND_PATTERNS.md) §1–§5 (Component Library)
- **Scope & Objectives**: Implement reusable atomic UI components matching the design specification.
- **Granular Tasks**:
  - [x] Build `TellyPrimaryButton`: 52dp height, Phosphor Lime fill, black bold text, 12dp rounded corners.
  - [x] Build `TellyFrostedSheet`: `BackdropFilter` with `sigmaX: 20`, `sigmaY: 20`, `rgba(20, 20, 25, 0.85)` surface.
  - [x] Build `TellyNeonBadge`: Pill container with glowing outline, supporting `NeonCoral` (Upset) and `PhosphorLime` (Winner).
  - [x] Build `TellyTextField`: Dark card fill, border highlight on focus, error state animation.
- **Testing & Verification**:
  - [x] Widget tests for each component checking tap states, disabled states, and color token consistency.
- **Dependencies**: `FE-102`.

#### `FE-105`: Local Drift SQLite Database & Repositories Setup
- **Spec Reference**:
  - [**`technical_architecture/01_TECH_STACK_AND_LIBRARIES.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/01_TECH_STACK_AND_LIBRARIES.md) §2 (Drift ORM)
  - [**`technical_architecture/04_CLIENT_ARCHITECTURE_AND_OFFLINE_SYNC.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/04_CLIENT_ARCHITECTURE_AND_OFFLINE_SYNC.md) §3 (Drift SQLite Tables)
- **Scope & Objectives**: Implement offline-first local storage with Drift SQLite ORM.
- **Granular Tasks**:
  - [x] Create `lib/core/database/database.dart` defining Drift tables: `CachedTitles`, `LocalRankings`, `OfflineDuelQueue`, `WatchlistCache`.
  - [x] Configure `build_runner` and generate `.g.dart` schema files.
  - [x] Implement `LocalTitleDao` and `LocalRankingDao` with reactive `Stream` watchers.
  - [x] Configure in-memory database setup for automated test environments (`NativeDatabase.memory()`).
- **Testing & Verification**:
  - [x] Execute `dart run build_runner build --delete-conflicting-outputs`.
  - [x] Unit tests for `LocalRankingDao` verifying CRUD and stream emissions.
- **Dependencies**: `FE-101`.

---

### Track 3: Auth & Onboarding Flow

#### `FE-106`: `SCR-01` Splash & Social / Phone Auth Screen
- **Spec Reference**:
  - [**`design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md) §1 (`SCR-01`)
  - [**`adjacent_systems/01_AUTH_REGISTER_AND_LOGIN_FLOWS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/adjacent_systems/01_AUTH_REGISTER_AND_LOGIN_FLOWS.md) §1 (Auth UI Wireframe)
- **Scope & Objectives**: Build the landing screen offering Apple, Google, and SMS Phone OTP sign-in.
- **Granular Tasks**:
  - [ ] Create `lib/features/auth/presentation/screens/auth_screen.dart`.
  - [ ] Render full-screen dark aesthetic with animated phosphor glow background.
  - [ ] Implement Apple Sign In button invoking Supabase Apple OAuth.
  - [ ] Implement Google Sign In button invoking Supabase Google OAuth.
  - [ ] Implement Phone Number input sheet with country code picker and SMS OTP submission dialog.
  - [ ] Wire up Riverpod `authControllerProvider` handling auth states and session persistence.
- **Testing & Verification**:
  - [ ] Widget test verifying all 3 login buttons are rendered and accessible.
  - [ ] Integration test simulating successful phone OTP authentication.
- **Dependencies**: `FE-102`, `FE-104`, `BE-103`.

#### `FE-107`: Handle Reservation Screen with Debounced RPC Availability
- **Spec Reference**:
  - [**`adjacent_systems/01_AUTH_REGISTER_AND_LOGIN_FLOWS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/adjacent_systems/01_AUTH_REGISTER_AND_LOGIN_FLOWS.md) §2 (Handle Reservation)
  - [**`design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md) §1 (`SCR-01`)
- **Scope & Objectives**: Allow new users to claim an `@handle` with real-time uniqueness validation.
- **Granular Tasks**:
  - [ ] Create `lib/features/auth/presentation/screens/handle_reservation_screen.dart`.
  - [ ] Add `TextFormField` enforcing regex `^[a-zA-Z0-9_]{3,20}$`.
  - [ ] Implement debounced Riverpod state checking `check_handle_available(handle)` via Supabase RPC every 300ms.
  - [ ] Display green checkmark when available, red error text when taken or invalid.
  - [ ] Submit reservation writing `username` to `public.users`.
- **Testing & Verification**:
  - [ ] Unit test regex validator against edge cases (`"a"`, `"very_long_handle_exceeding_twenty"`, `"with-hyphen"`).
  - [ ] Widget test verifying loading spinner during debounced RPC check.
- **Dependencies**: `FE-106`, `BE-101`.

#### `FE-108`: `SCR-02` Streaming Provider Household Setup
- **Spec Reference**:
  - [**`design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md) §2 (`SCR-02`)
  - [**`features/01_ONBOARDING_AND_TASTE_SEEDING.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/01_ONBOARDING_AND_TASTE_SEEDING.md) §2 (Provider Grid)
- **Scope & Objectives**: Allow users to select active streaming subscriptions with 1-tap card toggles.
- **Granular Tasks**:
  - [ ] Create `lib/features/onboarding/presentation/screens/streaming_setup_screen.dart`.
  - [ ] Render 8 provider cards (Netflix, Max, Hulu, Prime Video, Apple TV+, Disney+, Crunchyroll, Paramount+).
  - [ ] Implement multi-select state persisting selected provider IDs to Drift local database and Supabase `users.streaming_providers`.
  - [ ] Include *"I don't have streaming services / Skip for now"* secondary action.
- **Testing & Verification**:
  - [ ] Widget test verifying provider cards toggle selection state on tap and update counter.
- **Dependencies**: `FE-104`, `FE-105`.

#### `FE-109`: `SCR-03` 50-Title Seed Recognition Grid (Movies, TV, Anime)
- **Spec Reference**:
  - [**`design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md) §3 (`SCR-03`)
  - [**`features/01_ONBOARDING_AND_TASTE_SEEDING.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/01_ONBOARDING_AND_TASTE_SEEDING.md) §3 (Seed Matrix)
- **Scope & Objectives**: 50-poster multi-select grid with category filter chips and dynamic progress counter.
- **Granular Tasks**:
  - [ ] Create `lib/features/onboarding/presentation/screens/seed_grid_screen.dart`.
  - [ ] Implement category filter tabs: `[ All (50) ]`, `[ 🎬 Movies ]`, `[ 📺 TV Series ]`, `[ ⛩️ Anime ]`.
  - [ ] Render 3-column poster grid using `CachedNetworkImage` with shimmer placeholders.
  - [ ] Add checkmark badge overlay on selected posters with Phosphor Lime border highlight.
  - [ ] Render sticky bottom CTA bar displaying `"Select at least 5 titles (X/5 selected)"`, enabling when $X \ge 5$.
- **Testing & Verification**:
  - [ ] Widget test verifying CTA button remains disabled at 4 items and enables at 5 items.
  - [ ] Test category filter tab switches grid contents correctly.
- **Dependencies**: `FE-104`, `BE-102`.

#### `FE-110`: 1-Click AniList & MyAnimeList Profile Importer
- **Spec Reference**:
  - [**`features/08_ANIME_INTEGRATION_AND_HYBRID_CANON.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/08_ANIME_INTEGRATION_AND_HYBRID_CANON.md) §1 (AniList Sync)
  - [**`technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) §2.2 (GraphQL Deserializer)
- **Scope & Objectives**: Automatically pull user's completed anime list via public GraphQL/REST APIs without passwords.
- **Granular Tasks**:
  - [ ] Create `lib/features/onboarding/domain/anilist_importer.dart`.
  - [ ] Query AniList GraphQL endpoint `https://graphql.anilist.co` for `MediaListCollection(userName, type: ANIME, status: COMPLETED)`.
  - [ ] Map AniList titles and MAL IDs to internal TMDB IDs via title matching index.
  - [ ] Seed imported entries into sentiment brackets based on user's 10-point AniList score.
- **Testing & Verification**:
  - [ ] Unit test parsing mock AniList GraphQL JSON fixture into list of `MediaItem` models.
  - [ ] Handle 404 User Not Found gracefully with an in-app error snackbar.
- **Dependencies**: `FE-105`.

#### `FE-111`: 1-Click Letterboxd CSV Importer Parser
- **Spec Reference**:
  - [**`features/09_MOVIE_INTEGRATION_AND_DUAL_CANON.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/09_MOVIE_INTEGRATION_AND_DUAL_CANON.md) §4 (Letterboxd Importer)
  - [**`technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) §2.2 (CSV Ingestion)
- **Scope & Objectives**: Parse uploaded Letterboxd `diary.csv` files and populate the Movie Canon.
- **Granular Tasks**:
  - [ ] Create `lib/features/onboarding/domain/letterboxd_csv_parser.dart` using `package:csv`.
  - [ ] Parse columns: `Date`, `Name`, `Year`, `Letterboxd URI`, `Rating`, `Rewatch`.
  - [ ] Map star ratings to sentiment brackets ($5.0\star \to \text{Top 10\%}$, $0.5\star \to \text{Bottom 5\%}$).
  - [ ] Batch match titles against TMDB API using Edge Function.
- **Testing & Verification**:
  - [ ] Unit test parsing mock `diary.csv` containing commas in title (*"Everything Everywhere All at Once"*).
  - [ ] Assert parsing completes for 500 rows in $< 300\text{ ms}$.
- **Dependencies**: `FE-105`, `BE-104`.

---

### Track 4: Sprint 1 Quality Assurance & Testing

#### `QA-101`: Test Pyramid Setup & CI Analyzer Enforcement
- **Spec Reference**:
  - [**`technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) §1, §7 (Test Pyramid & CI Gates)
- **Scope & Objectives**: Configure automated test harness, mock generators, and GitHub Actions PR checks.
- **Granular Tasks**:
  - [ ] Add `build_runner`, `mockito`, `package:test`, `flutter_test` to dev dependencies.
  - [ ] Configure `.github/workflows/ci.yml` running `dart analyze --fatal-infos` and `flutter test --coverage`.
  - [ ] Assert CI fails if test coverage on core models drops below 80%.
- **Testing & Verification**:
  - [ ] Trigger CI build via test pull request; assert pipeline succeeds in $< 90\text{ seconds}$.
- **Dependencies**: `FE-101`.

#### `QA-102`: Unit Tests for Ingestion Parsers
- **Spec Reference**:
  - [**`technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) §2.2 (Parsers)
- **Scope & Objectives**: Test edge cases and data resiliency in Letterboxd and AniList parsing code.
- **Granular Tasks**:
  - [ ] Write unit tests for `letterboxd_csv_parser_test.dart` (escaped quotes, missing ratings, empty lines).
  - [ ] Write unit tests for `anilist_importer_test.dart` (manga ignored, franchise rollups combined).
- **Testing & Verification**:
  - [ ] 100% code coverage on `letterboxd_csv_parser.dart` and `anilist_importer.dart`.
- **Dependencies**: `FE-110`, `FE-111`.

#### `QA-103`: In-Memory Drift SQLite DAO Unit Tests
- **Spec Reference**:
  - [**`technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) §2.3 (Drift DAOs)
- **Scope & Objectives**: Test offline table CRUD and reactive stream emission using in-memory SQLite.
- **Granular Tasks**:
  - [x] Write `test/core/database/local_ranking_dao_test.dart`.
  - [x] Test inserting, updating ranks, and query filtering by `media_type`.
  - [x] Test transaction rollback upon failure.
- **Testing & Verification**:
  - [x] Run tests on pure Dart VM; all tests pass in $< 1\text{ second}$.
- **Dependencies**: `FE-105`.

#### `QA-104`: Widget Tests for Auth & Onboarding Screens
- **Spec Reference**:
  - [**`technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) §3.1 (Widget Tests)
- **Scope & Objectives**: Component-level widget testing for `SCR-01`, `SCR-02`, and `SCR-03`.
- **Granular Tasks**:
  - [ ] Write `test/features/auth/auth_screen_test.dart`.
  - [ ] Write `test/features/onboarding/streaming_setup_screen_test.dart`.
  - [ ] Write `test/features/onboarding/seed_grid_screen_test.dart`.
- **Testing & Verification**:
  - [ ] Assert tapping 5 cards triggers button enable without UI overflow errors.
- **Dependencies**: `FE-106`, `FE-108`, `FE-109`.

---

## 📅 Sprint 2: The Pairwise Duel Engine, Scoring & The Personal Dual-Canon (Weeks 3–4)

### Sprint Objective
Build the mathematical core of Telly: the binary insertion duel tournament, dynamic percentile score curve generator, TrueSkill uncertainty tracking, and the personal Dual-Canon profile with segregated Movie and Series leaderboards.

---

### Track 1: Algorithmic Core & State Machines

#### `ALGO-201`: Binary Insertion Sort Domain Logic & Boundary Handlers
- **Spec Reference**:
  - [**`features/02_PAIRWISE_RANKING_ENGINE_AND_LOGGING.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/02_PAIRWISE_RANKING_ENGINE_AND_LOGGING.md) §1 (The Beli Duel Mechanic)
  - [**`technical_architecture/04_CLIENT_ARCHITECTURE_AND_OFFLINE_SYNC.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/04_CLIENT_ARCHITECTURE_AND_OFFLINE_SYNC.md) §2 (Duel Engine Algorithm)
- **Scope & Objectives**: Pure Dart implementation of binary insertion sort with logarithmic bounds ($\mathcal{O}(\log_2 N)$).
- **Granular Tasks**:
  - [ ] Create `lib/features/ranking/domain/binary_insertion_tournament.dart`.
  - [ ] Implement `BinaryInsertionTournament<T>` taking existing sorted list and new candidate item.
  - [ ] Implement `low`, `high`, `mid = (low + high) ~/ 2` index pointer calculations.
  - [ ] Handle sentiment bracket seeding (`seedBracket`) to narrow search bounds before starting duels.
  - [ ] Implement `onCandidateWins()` moving `low = mid + 1` and `onOpponentWins()` moving `high = mid - 1`.
  - [ ] Handle termination when `low > high`, returning exact insertion slot index.
- **Testing & Verification**:
  - [ ] Test insertion into 100-item list requires $\le 7$ comparisons.
  - [ ] Test insertion into list of size 0 requires 0 comparisons; size 1 requires 1 comparison.
- **Dependencies**: None.

#### `ALGO-202`: Dynamic Percentile Score Curve Calculator ($0.0 - 10.0$)
- **Spec Reference**:
  - [**`features/02_PAIRWISE_RANKING_ENGINE_AND_LOGGING.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/02_PAIRWISE_RANKING_ENGINE_AND_LOGGING.md) §2 (Score Formula)
  - [**`technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) §2.1 (Dynamic Score Curve)
- **Scope & Objectives**: Mathematical formula mapping rank positions $1 \dots N$ to a normalized $0.00 - 10.00$ decimal score.
- **Granular Tasks**:
  - [ ] Create `lib/features/ranking/domain/score_curve_calculator.dart`.
  - [ ] Implement formula: $\text{Score}(r, N) = 1.00 + 9.00 \times \left(1.0 - \frac{r - 1}{N - 1}\right)^p$.
  - [ ] Apply power exponent $p = 1.15$ to slightly weight top echelon titles.
  - [ ] Implement Bayesian smoothing prior for profiles with $N < 10$ ranked titles.
- **Testing & Verification**:
  - [ ] Verify $\text{Score}(1, N) == 10.00$ and $\text{Score}(N, N) == 1.00$ for all $N > 1$.
  - [ ] Verify monotonic strictly decreasing property: $\forall i < j, \text{Score}(i, N) \ge \text{Score}(j, N)$.
- **Dependencies**: None.

#### `ALGO-203`: TrueSkill Uncertainty ($\sigma$) Decay & Confidence Tracking
- **Spec Reference**:
  - [**`features/08_ANIME_INTEGRATION_AND_HYBRID_CANON.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/08_ANIME_INTEGRATION_AND_HYBRID_CANON.md) §3 (TrueSkill & Confidence)
  - [**`technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) §2.1 (TrueSkill Invariants)
- **Scope & Objectives**: Track Bayesian ranking confidence $\sigma$ and transition titles between `Provisional` and `Locked`.
- **Granular Tasks**:
  - [ ] Create `lib/features/ranking/domain/trueskill_confidence.dart`.
  - [ ] Implement initial uncertainty $\sigma_0 = 1.20$ for newly inserted titles.
  - [ ] Apply decay multiplier $\sigma_{t+1} = \max(0.15, \sigma_t \times 0.75)$ on every completed duel involving the title.
  - [ ] Mark titles with $\sigma < 0.50$ as `RankingStatus.locked` (solid gold badge); otherwise `RankingStatus.provisional` (dashed badge).
- **Testing & Verification**:
  - [ ] Unit test verifying 4 consecutive duels decay $\sigma$ from $1.20 \to 0.38$, transitioning status to `Locked`.
- **Dependencies**: None.

#### `ALGO-204`: Dual-Canon Media-Type Segregation Rules
- **Spec Reference**:
  - [**`features/09_MOVIE_INTEGRATION_AND_DUAL_CANON.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/09_MOVIE_INTEGRATION_AND_DUAL_CANON.md) §2 (Dual-Canon Architecture)
- **Scope & Objectives**: Strictly segregate Movie duels and scores from Series/Anime duels to prevent apples-to-oranges comparisons.
- **Granular Tasks**:
  - [ ] Create `lib/features/ranking/domain/canon_type.dart` enum: `movie`, `series`.
  - [ ] Enforce tournament partition: Candidate of type `movie` is matched ONLY against titles in the user's Movie Canon.
  - [ ] Enforce tournament partition: Candidate of type `tv` (including anime) is matched ONLY against Series Canon.
  - [ ] Ensure distinct percentile rank lists and distinct score curves for movies and series.
- **Testing & Verification**:
  - [ ] Unit test asserting inserting *The Dark Knight* never pairs it with *Breaking Bad* in any duel step.
- **Dependencies**: `ALGO-201`.

#### `ALGO-205`: Riverpod `DuelController` State Machine
- **Spec Reference**:
  - [**`technical_architecture/04_CLIENT_ARCHITECTURE_AND_OFFLINE_SYNC.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/04_CLIENT_ARCHITECTURE_AND_OFFLINE_SYNC.md) §2 (Duel State Machine)
  - [**`design_system/04_USER_INTERACTION_FLOWS_AND_GESTURES.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/04_USER_INTERACTION_FLOWS_AND_GESTURES.md) §1 (Duel Sequence)
- **Scope & Objectives**: Reactive Riverpod notifier orchestrating tournament progression, UI events, and persistence.
- **Granular Tasks**:
  - [ ] Create `lib/features/ranking/presentation/controllers/duel_controller.dart`.
  - [ ] Implement states: `DuelInitial`, `DuelActive(candidateA, candidateB, step, totalSteps)`, `DuelResolving`, `DuelComplete(insertedIndex, finalScore)`.
  - [ ] Handle `vote(winnerId)`: updates binary search bounds, persists duel record to offline queue, advances to next step.
  - [ ] Handle `skipOrTie()`: steps to $\pm 1$ neighbor without altering bounds irreversibly.
- **Testing & Verification**:
  - [ ] State machine unit test stepping through 4 mock duels to `DuelComplete`.
- **Dependencies**: `ALGO-201`, `ALGO-204`.

---

### Track 2: Database Stored Procedures & Backend

#### `BE-201`: PostgreSQL Procedure `insert_user_ranking_atomic`
- **Spec Reference**:
  - [**`technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md) §3.1 (Atomic Stored Procedure)
- **Scope & Objectives**: PL/pgSQL function shifting existing rows by +1 and recomputing dynamic scores atomically.
- **Granular Tasks**:
  - [ ] Write PL/pgSQL function `insert_user_ranking_atomic(p_user_id, p_title_id, p_media_type, p_rank_position)`.
  - [ ] Execute `UPDATE user_rankings SET rank_position = rank_position + 1 WHERE user_id = p_user_id AND media_type = p_media_type AND rank_position >= p_rank_position`.
  - [ ] Insert new row at `p_rank_position`.
  - [ ] Recalculate dynamic percentile scores for all rows of `(p_user_id, p_media_type)` in the same transaction.
- **Testing & Verification**:
  - [ ] pgTAP test verifying concurrent insertions never create duplicate rank positions.
- **Dependencies**: `BE-101`.

#### `BE-202`: Pairwise Duels Audit Logging
- **Spec Reference**:
  - [**`technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md) §2.3 (`pairwise_duels` table)
- **Scope & Objectives**: Record every head-to-head decision to power taste match and upset detection.
- **Granular Tasks**:
  - [ ] Create table `pairwise_duels` tracking `user_id`, `winner_id`, `loser_id`, `media_type`, `decision_time_ms`, `is_upset`.
  - [ ] Add check constraint `winner_id != loser_id`.
  - [ ] Create composite index on `(winner_id, loser_id)` for global win-rate aggregations.
- **Testing & Verification**:
  - [ ] Test inserting duel records and querying win rates by title.
- **Dependencies**: `BE-101`.

---

### Track 3: Duel Arena & Logging UI

#### `FE-201`: `SCR-10` Binary Duel Arena Screen & Card Layout
- **Spec Reference**:
  - [**`design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md) §10 (`SCR-10`)
  - [**`design_system/02_COMPONENT_LIBRARY_AND_PATTERNS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/02_COMPONENT_LIBRARY_AND_PATTERNS.md) §4 (Duel Arena Card Physics)
- **Scope & Objectives**: Render the duel cards with poster images, title, release year, runtime, and central `VS` badge.
- **Granular Tasks**:
  - [ ] Create `lib/features/ranking/presentation/screens/duel_arena_screen.dart`.
  - [ ] Build top status bar: `"DUEL 2 OF 4"`, step indicator dots, and close button.
  - [ ] Build upper Candidate Card A and lower Candidate Card B with 2:3 aspect ratio posters and glass gradients.
  - [ ] Place central glowing `━ VS ━` badge over the boundary between cards.
  - [ ] Add bottom secondary button: *"Can't Compare / Equal"*.
- **Testing & Verification**:
  - [ ] Widget test verifying Candidate A, Candidate B, and VS badge are visible and mounted.
- **Dependencies**: `FE-102`, `FE-104`.

#### `FE-202`: Card Swipe Gestures, Spring Physics & Winner Transitions
- **Spec Reference**:
  - [**`design_system/04_USER_INTERACTION_FLOWS_AND_GESTURES.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/04_USER_INTERACTION_FLOWS_AND_GESTURES.md) §1 (Duel Gestures)
  - [**`design_system/01_DESIGN_PHILOSOPHY_AND_STYLE_GUIDE.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/01_DESIGN_PHILOSOPHY_AND_STYLE_GUIDE.md) §5 (Haptic Sensations)
- **Scope & Objectives**: Implement fluid 60fps swipe/tap card interactions with physics spring-back.
- **Granular Tasks**:
  - [ ] Wrap Duel Cards with `GestureDetector` and `AnimatedBuilder`.
  - [ ] Tap on Card: scale winner to 1.04x with Phosphor Lime glow; fade loser downward with opacity $0.0$.
  - [ ] Vertical drag gestures: drag up to select Candidate A ($> 100\text{ dp}$ threshold); drag down for Candidate B.
  - [ ] Trigger `HapticsService.duelWinner()` on vote confirmation.
  - [ ] Reset positions with spring physics curve `Curves.elasticOut` if drag cancelled.
- **Testing & Verification**:
  - [ ] Widget test asserting swipe $> 100\text{ dp}$ calls `vote()` callback; swipe $< 50\text{ dp}$ snaps back.
- **Dependencies**: `FE-201`, `FE-103`.

#### `FE-203`: `SCR-11` Editorial Tagging Modal (MVP Character, Vibe Tags, Sub/Dub)
- **Spec Reference**:
  - [**`design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md) §11 (`SCR-11`)
  - [**`features/02_PAIRWISE_RANKING_ENGINE_AND_LOGGING.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/02_PAIRWISE_RANKING_ENGINE_AND_LOGGING.md) §3 (Editorial Tagging)
- **Scope & Objectives**: Bottom sheet appearing post-tournament to capture subjective nuances.
- **Granular Tasks**:
  - [ ] Create `lib/features/ranking/presentation/widgets/editorial_tagging_sheet.dart`.
  - [ ] MVP Character dropdown populated from TMDB cast credits.
  - [ ] Multi-select vibe tag chips (*"Masterpiece Acting"*, *"Mind-bending"*, *"Cozy"*, *"Dark & Gritty"*).
  - [ ] Anime-specific audio toggle: `[ Sub ]` vs `[ Dub ]`.
  - [ ] 280-character micro-review input field with remaining counter.
- **Testing & Verification**:
  - [ ] Widget test verifying selecting 2 vibe tags updates local tagging model.
- **Dependencies**: `FE-104`.

#### `FE-204`: Movie-Specific Logging Tags in `SCR-11` (Cinema Venue, Rewatch Flag)
- **Spec Reference**:
  - [**`features/09_MOVIE_INTEGRATION_AND_DUAL_CANON.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/09_MOVIE_INTEGRATION_AND_DUAL_CANON.md) §3 (Theatrical Tracking)
- **Scope & Objectives**: Dynamically display cinema venue options and rewatch counters when logging a film.
- **Granular Tasks**:
  - [ ] In `SCR-11`, inspect candidate `media_type`: if `'movie'`, render Theatrical Venue selector.
  - [ ] Options: `[ 🛋️ Home / Streaming ]`, `[ 🍿 Theatrical ]`, `[ 📽️ IMAX 70mm / Dolby ]`.
  - [ ] Add Rewatch counter badge: `First Watch` vs `Rewatch (x2, x3...)`.
  - [ ] Auto-tag director name from TMDB crew metadata.
- **Testing & Verification**:
  - [ ] Widget test asserting venue chips render for movies and are omitted for TV shows.
- **Dependencies**: `FE-203`.

#### `FE-205`: `SCR-12` Celebration Slot Reveal Modal with Number Ticker
- **Spec Reference**:
  - [**`design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md) §12 (`SCR-12`)
  - [**`features/02_PAIRWISE_RANKING_ENGINE_AND_LOGGING.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/02_PAIRWISE_RANKING_ENGINE_AND_LOGGING.md) §4 (Slot Reveal)
- **Scope & Objectives**: Full-screen celebration screen revealing new title rank position and dynamic score.
- **Granular Tasks**:
  - [ ] Create `lib/features/ranking/presentation/screens/slot_reveal_modal.dart`.
  - [ ] Animate slot rank reveal: *"#4 of 48 Titles in your Movie Canon"*.
  - [ ] Animate score counter ticker from `0.00` to target score (e.g., `9.42`) over 1200ms using `Tween<double>`.
  - [ ] Trigger sequential haptic feedback during number roll.
  - [ ] Provide primary button: *"View in My Canon"*; secondary: *"Share Story"*.
- **Testing & Verification**:
  - [ ] Widget test verifying animation completes and displays formatted score text `9.42`.
- **Dependencies**: `FE-102`, `FE-103`.

---

### Track 4: The Personal Dual-Canon Profile UI

#### `FE-206`: `SCR-14` Dual-Canon Profile Header & Segmented Pill Switcher
- **Spec Reference**:
  - [**`design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md) §14 (`SCR-14`)
  - [**`features/06_PROFILE_THE_CANON_AND_STATS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/06_PROFILE_THE_CANON_AND_STATS.md) §1 (Profile Header)
  - [**`features/09_MOVIE_INTEGRATION_AND_DUAL_CANON.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/09_MOVIE_INTEGRATION_AND_DUAL_CANON.md) §2 (Dual-Canon Switcher)
- **Scope & Objectives**: Profile screen featuring prominent segmented pill switching between Movie Canon and Series Canon.
- **Granular Tasks**:
  - [ ] Create `lib/features/profile/presentation/screens/dual_canon_profile_screen.dart`.
  - [ ] Build segmented control: `[ 🎬 Movie Canon (42) ]` | `[ 📺 Series & Anime (58) ]`.
  - [ ] Render profile avatar, handle, bio, and Top 3 Showcase row.
  - [ ] Wire switcher to Riverpod `selectedCanonProvider` to filter displayed list instantly.
- **Testing & Verification**:
  - [ ] Widget test asserting tapping "Movie Canon" updates list to movie items only.
- **Dependencies**: `FE-104`.

#### `FE-207`: Three Canon View Modes (Ranked List, Tier View, 3x3 Grid)
- **Spec Reference**:
  - [**`features/06_PROFILE_THE_CANON_AND_STATS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/06_PROFILE_THE_CANON_AND_STATS.md) §2 (Multi-View Canon)
  - [**`design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md) §14 (`SCR-14`)
- **Scope & Objectives**: Implement 3 distinct visual presentations of the user's ranked list.
- **Granular Tasks**:
  - [ ] Mode 1: **Ranked List** — numbered rows (#1, #2), poster thumbnail, dynamic score pill, and MVP badge.
  - [ ] Mode 2: **Tier View** — grouped buckets `Tier S (9.0+)`, `Tier A (8.0-8.9)`, `Tier B (7.0-7.9)`, `Tier C`, `Tier D`.
  - [ ] Mode 3: **3x3 Poster Grid** — aesthetic Instagram-style grid showing user's top 9 titles without text clutter.
  - [ ] Add view switcher icon row in the sub-header.
- **Testing & Verification**:
  - [ ] Widget test verifying view mode switcher renders correct layout widget for each mode.
- **Dependencies**: `FE-206`.

#### `FE-208`: Anime Franchise Rollup Aggregator & Unbundle Toggle
- **Spec Reference**:
  - [**`features/08_ANIME_INTEGRATION_AND_HYBRID_CANON.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/08_ANIME_INTEGRATION_AND_HYBRID_CANON.md) §2 (Franchise Rollup)
- **Scope & Objectives**: Allow users to collapse anime seasons/cours into a single franchise entity or unbundle them.
- **Granular Tasks**:
  - [ ] Create `lib/features/ranking/domain/franchise_rollup_service.dart`.
  - [ ] When collapsed: aggregate *Attack on Titan Season 1–4* into a single entry with composite score.
  - [ ] When unbundled: show individual seasons as standalone ranked entries.
  - [ ] Provide user toggle switch: `[ Franchise Rollup: ON / OFF ]`.
- **Testing & Verification**:
  - [ ] Unit test verifying rollup combines 4 seasons into 1 parent entry with weighted mean score.
- **Dependencies**: `FE-206`.

#### `FE-209`: Reorderable Drag-and-Drop Manual Re-Indexing
- **Spec Reference**:
  - [**`design_system/04_USER_INTERACTION_FLOWS_AND_GESTURES.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/04_USER_INTERACTION_FLOWS_AND_GESTURES.md) §3 (Canon Reordering)
- **Scope & Objectives**: Allow users to manually drag titles to new positions with live score recalculation.
- **Granular Tasks**:
  - [ ] Wrap Ranked List with `ReorderableListView.builder`.
  - [ ] Provide drag handle icon triggering `HapticFeedback.selectionClick()` on pick up.
  - [ ] On drop: update `rank_position` in local Drift database, recalculate percentile scores, and sync to Supabase.
- **Testing & Verification**:
  - [ ] Widget test dragging row #4 to row #1 updates rank text to `#1`.
- **Dependencies**: `FE-207`, `ALGO-202`.

---

### Track 5: Sprint 2 Quality Assurance & Testing

#### `QA-201`: Unit Tests for Binary Insertion Sort Tournament Algorithm
- **Spec Reference**:
  - [**`technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) §2.1 (Tournament Invariants)
- **Scope & Objectives**: Stress test binary insertion sort across edge cases and large lists.
- **Granular Tasks**:
  - [ ] Write `test/features/ranking/binary_insertion_tournament_test.dart`.
  - [ ] Test insertion into list of $N=100$ titles never exceeds 7 comparisons.
  - [ ] Test tie-break logic steps to neighbor without deadlocking.
- **Testing & Verification**:
  - [ ] 100% code coverage on `binary_insertion_tournament.dart`.
- **Dependencies**: `ALGO-201`.

#### `QA-202`: Unit Tests for Dynamic Percentile Score Monotonicity
- **Spec Reference**:
  - [**`technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) §2.1 (Score Monotonicity)
- **Scope & Objectives**: Mathematically verify scoring curve invariants.
- **Granular Tasks**:
  - [ ] Write `test/features/ranking/score_curve_calculator_test.dart`.
  - [ ] Assert $\text{Score}(1) = 10.00$ and $\text{Score}(N) = 1.00$ across $N \in [2, 10, 50, 500]$.
  - [ ] Assert strictly decreasing order: $\text{Score}(i) > \text{Score}(i+1)$.
- **Testing & Verification**:
  - [ ] Property-based tests passing with 10,000 generated datasets.
- **Dependencies**: `ALGO-202`.

#### `QA-203`: pgTAP Test Suite for `insert_user_ranking_atomic`
- **Spec Reference**:
  - [**`technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) §3.3, §6 (pgTAP Stored Procs)
- **Scope & Objectives**: Verify database stored procedure integrity in Supabase container.
- **Granular Tasks**:
  - [ ] Write `database/tests/01_insert_user_ranking_atomic_test.sql` using pgTAP.
  - [ ] Assert rank shifting maintains continuous integer sequences ($1, 2, 3, 4\dots$).
  - [ ] Assert movie insertions do not shift TV show rankings.
- **Testing & Verification**:
  - [ ] Execute `pg_prove` in CI; all tests pass.
- **Dependencies**: `BE-201`.

#### `QA-204`: Widget Tests for Duel Arena (`SCR-10`) & Slot Reveal (`SCR-12`)
- **Spec Reference**:
  - [**`technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) §3.1 (Duel Arena Widget Test)
- **Scope & Objectives**: Test card rendering, swipe callbacks, and animations.
- **Granular Tasks**:
  - [ ] Write `test/features/ranking/duel_arena_screen_test.dart`.
  - [ ] Write `test/features/ranking/slot_reveal_modal_test.dart`.
- **Testing & Verification**:
  - [ ] Assert tapping Candidate A calls `onSelectWinner` with Candidate A ID.
- **Dependencies**: `FE-201`, `FE-205`.

---

## 📅 Sprint 3: Social Graph, Activity Feeds, Squads & TV Graveyard (Weeks 5–6)

### Sprint Objective
Build social connections, the activity feed with real-time upset alert detection, spoiler-masked comments, Squad consensus leaderboards, and the TV Graveyard for logging dropped titles.

---

### Track 1: Backend Social & Feed Pipelines

#### `BE-301`: Social Graph Schema, Follow Requests & Activity Log
- **Spec Reference**:
  - [**`technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md) §2.4 (`social_follows` table)
  - [**`features/04_SOCIAL_GRAPH_FEED_AND_UPSETS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/04_SOCIAL_GRAPH_FEED_AND_UPSETS.md) §1 (Social Graph)
- **Scope & Objectives**: Manage bidirectional/unidirectional follow relationships with privacy boundaries.
- **Granular Tasks**:
  - [ ] Create `social_follows` table with `follower_id`, `following_id`, `status` (`pending`, `accepted`).
  - [ ] Add unique index on `(follower_id, following_id)`.
  - [ ] Create `activity_logs` table recording ranking events, comments, and queue additions.
  - [ ] Write RLS policies ensuring private accounts require follow approval before exposing activity.
- **Testing & Verification**:
  - [ ] Verify private account activities are hidden from unapproved users.
- **Dependencies**: `BE-101`.

#### `BE-302`: Upset Engine Algorithmic Detection ($\mu_{\text{diff}} \ge 0.25$)
- **Spec Reference**:
  - [**`features/04_SOCIAL_GRAPH_FEED_AND_UPSETS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/04_SOCIAL_GRAPH_FEED_AND_UPSETS.md) §2 (Upset Engine)
  - [**`technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md) §3.2 (Upset Trigger)
- **Scope & Objectives**: Detect when a user's duel decision defies platform consensus by $\ge 25\%$.
- **Granular Tasks**:
  - [ ] Create database trigger or function `detect_upset_duel(winner_id, loser_id)`.
  - [ ] Query platform win rates: if $\text{WinRate}(\text{loser}) - \text{WinRate}(\text{winner}) \ge 0.25$, set `pairwise_duels.is_upset = true`.
  - [ ] Write upset notification event to `activity_logs` with `is_upset: true`.
- **Testing & Verification**:
  - [ ] Unit test: Candidate A (20% win rate) beating Candidate B (80% win rate) flags `is_upset = true`.
- **Dependencies**: `BE-202`.

#### `BE-303`: Redis Timeline Fanout Caching for Friends Activity Feed
- **Spec Reference**:
  - [**`technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md) §4 (Redis Caching Keys)
- **Scope & Objectives**: Cache user activity feed in Redis ZSETs for $< 50\text{ ms}$ load times.
- **Granular Tasks**:
  - [ ] Configure Redis client in Supabase Edge Functions / background worker.
  - [ ] Fanout ranking events to follower timelines: `ZADD feed:timeline:{user_id} {timestamp} {activity_id}`.
  - [ ] Maintain fixed timeline buffer of 500 items per user (`ZREMRANGEBYRANK 0 -501`).
- **Testing & Verification**:
  - [ ] Benchmark feed query: retrieve top 20 feed items from Redis in $< 20\text{ ms}$.
- **Dependencies**: `BE-301`.

#### `BE-304`: Squads Database Schema & Borda Count Rank Aggregation RPC
- **Spec Reference**:
  - [**`features/04_SOCIAL_GRAPH_FEED_AND_UPSETS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/04_SOCIAL_GRAPH_FEED_AND_UPSETS.md) §4 (Squad Leaderboards)
  - [**`technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md) §2.5 (`squads` schema)
- **Scope & Objectives**: Group ranking aggregation combining individual canons into a consensus leaderboard.
- **Granular Tasks**:
  - [ ] Create `squads` and `squad_members` tables.
  - [ ] Write PostgreSQL RPC `calculate_squad_canon(p_squad_id, p_media_type)`.
  - [ ] Implement Borda Count aggregation assigning points based on each member's rank position.
  - [ ] Order consensus titles by cumulative Borda points.
- **Testing & Verification**:
  - [ ] Test 3 users with overlapping canons generate consistent consensus ranking.
- **Dependencies**: `BE-101`.

---

### Track 2: Activity Feeds & Social UI

#### `FE-301`: `SCR-05` Activity Feed Screen with Tabs (`Following`, `Squads`, `Global`)
- **Spec Reference**:
  - [**`design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md) §5 (`SCR-05`)
  - [**`features/04_SOCIAL_GRAPH_FEED_AND_UPSETS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/04_SOCIAL_GRAPH_FEED_AND_UPSETS.md) §1 (Feed UI)
- **Scope & Objectives**: Main social feed with infinite scrolling and filter tabs.
- **Granular Tasks**:
  - [ ] Create `lib/features/feed/presentation/screens/activity_feed_screen.dart`.
  - [ ] Implement top tab bar: `[ Following ]`, `[ Squads ]`, `[ Global ]`.
  - [ ] Implement pull-to-refresh and pagination using Riverpod `feedPaginationProvider`.
  - [ ] Handle empty state: *"Follow friends to see what they are watching and ranking!"*.
- **Testing & Verification**:
  - [ ] Widget test verifying feed scrolls and loads next page when reaching bottom.
- **Dependencies**: `FE-104`, `BE-303`.

#### `FE-302`: Standard Activity Feed Card Component
- **Spec Reference**:
  - [**`design_system/02_COMPONENT_LIBRARY_AND_PATTERNS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/02_COMPONENT_LIBRARY_AND_PATTERNS.md) §3.2 (Feed Card)
  - [**`design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md) §5 (`SCR-05`)
- **Scope & Objectives**: Render friend ranking activity with score badge, poster thumbnail, and tags.
- **Granular Tasks**:
  - [ ] Create `lib/features/feed/presentation/widgets/feed_activity_card.dart`.
  - [ ] Display friend avatar, name, handle, and relative timestamp (`"2h ago"`).
  - [ ] Render action text: *"ranked Dune: Part Two at #3 in Movie Canon"*.
  - [ ] Display dynamic score badge (Phosphor Lime `9.42`) and MVP character chip.
  - [ ] Include reaction buttons: flame 🔥, applause 👏, shock 🤯, and comment count.
- **Testing & Verification**:
  - [ ] Widget test verifying tapping reaction increments local count optimistically.
- **Dependencies**: `FE-301`.

#### `FE-303`: Spicy Upset Alert Feed Card with Neon Coral Badge
- **Spec Reference**:
  - [**`design_system/02_COMPONENT_LIBRARY_AND_PATTERNS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/02_COMPONENT_LIBRARY_AND_PATTERNS.md) §3.2 (Upset Card)
  - [**`features/04_SOCIAL_GRAPH_FEED_AND_UPSETS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/04_SOCIAL_GRAPH_FEED_AND_UPSETS.md) §2 (Upset Presentation)
- **Scope & Objectives**: High-visibility feed card highlighting controversial takes and spicy duels.
- **Granular Tasks**:
  - [ ] Create `lib/features/feed/presentation/widgets/upset_activity_card.dart`.
  - [ ] Add prominent header: `[ ⚡ SPICY UPSET ALERT ]` in Neon Coral outline.
  - [ ] Render duel matchup: Winner poster on left, Loser poster on right with red slash.
  - [ ] Display upset stat: *"Only 14% of Telly users agree with this pick"*.
  - [ ] Trigger subtle double-pulse animation on appearance.
- **Testing & Verification**:
  - [ ] Widget test verifying Neon Coral styling and consensus percentage display.
- **Dependencies**: `FE-302`.

#### `FE-304`: 1-Tap `[ + Want to Watch ]` Queue Quick-Action
- **Spec Reference**:
  - [**`features/04_SOCIAL_GRAPH_FEED_AND_UPSETS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/04_SOCIAL_GRAPH_FEED_AND_UPSETS.md) §3 (1-Tap Queue)
- **Scope & Objectives**: Allow users to save titles spotted in their feed directly to their watchlist in 1 tap.
- **Granular Tasks**:
  - [ ] Add bookmark icon button to all feed cards.
  - [ ] On tap: trigger `HapticFeedback.selectionClick()`, insert title into local Drift `WatchlistCache`, and sync to Supabase `user_watchlist`.
  - [ ] Display animated toast: *"Added to your Watchlist (available on Netflix)"*.
- **Testing & Verification**:
  - [ ] Widget test verifying tapping bookmark toggles state and invokes watchlist repository.
- **Dependencies**: `FE-302`, `FE-105`.

#### `FE-305`: `SCR-06` Spoiler-Safe Discussion Thread & Tap-to-Reveal Blur
- **Spec Reference**:
  - [**`design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md) §6 (`SCR-06`)
  - [**`features/04_SOCIAL_GRAPH_FEED_AND_UPSETS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/04_SOCIAL_GRAPH_FEED_AND_UPSETS.md) §3 (Spoiler Safe Comments)
  - [**`adjacent_systems/05_TRUST_SAFETY_MODERATION_AND_ADMIN.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/adjacent_systems/05_TRUST_SAFETY_MODERATION_AND_ADMIN.md) §1 (Spoiler Masks)
- **Scope & Objectives**: Comments thread with automatic and user-tagged spoiler masking.
- **Granular Tasks**:
  - [ ] Create `lib/features/feed/presentation/screens/comment_thread_screen.dart`.
  - [ ] Comments tagged with `is_spoiler: true` render frosted Gaussian blur overlay (`BackdropFilter`).
  - [ ] Tap on blur reveals content with label: *"Tap to reveal spoiler"*.
  - [ ] Add spoiler toggle switch on comment composer: `[ ⚠️ Contains Spoilers ]`.
- **Testing & Verification**:
  - [ ] Widget test verifying blurred comment text cannot be read until tapped.
- **Dependencies**: `FE-104`.

---

### Track 3: Squads Hub & TV Graveyard UI

#### `FE-306`: `SCR-17` Squads Hub with Shared Canon & Activity
- **Spec Reference**:
  - [**`design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md) §17 (`SCR-17`)
  - [**`features/04_SOCIAL_GRAPH_FEED_AND_UPSETS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/04_SOCIAL_GRAPH_FEED_AND_UPSETS.md) §4 (Squad Hub Specs)
- **Scope & Objectives**: Group hub for friend circles showing member avatars, joint consensus leaderboard, and squad feed.
- **Granular Tasks**:
  - [ ] Create `lib/features/squads/presentation/screens/squad_hub_screen.dart`.
  - [ ] Render squad banner, name, member avatars row, and invite link button.
  - [ ] Display Squad Consensus Leaderboard (calculated via Borda count RPC).
  - [ ] Provide toggle: `[ 🎬 Movie Canon ]` vs `[ 📺 Series Canon ]`.
- **Testing & Verification**:
  - [ ] Widget test verifying member avatars and ranked squad items render.
- **Dependencies**: `FE-207`, `BE-304`.

#### `FE-307`: `SCR-18` The TV Graveyard (Dropped Tracking & Milestones)
- **Spec Reference**:
  - [**`design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md) §18 (`SCR-18`)
  - [**`features/03_SERIES_VS_SEASONS_AND_DROPPED_TRACKING.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/03_SERIES_VS_SEASONS_AND_DROPPED_TRACKING.md) §2 (The TV Graveyard)
- **Scope & Objectives**: Dedicated profile tab for cataloging dropped series with milestone tracking.
- **Granular Tasks**:
  - [ ] Create `lib/features/profile/presentation/screens/tv_graveyard_screen.dart`.
  - [ ] Render grayscale/muted card styling with skull / tombstone icon 🪦.
  - [ ] Display drop milestone: *"Dropped at Season 3, Episode 4"*.
  - [ ] Display reason tag chip: `[ 📉 Quality Fell Off ]`, `[ 💤 Lost Interest ]`, `[ 😡 Disliked Character ]`.
  - [ ] Include revisit reminder toggle: *"Notify me if new season gets $\ge 90\%$ critical acclaim"*.
- **Testing & Verification**:
  - [ ] Widget test verifying dropped reason chip and milestone label render accurately.
- **Dependencies**: `FE-206`.

#### `FE-308`: Dropped Show Logging Sheet & Reason Taxonomy
- **Spec Reference**:
  - [**`features/03_SERIES_VS_SEASONS_AND_DROPPED_TRACKING.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/03_SERIES_VS_SEASONS_AND_DROPPED_TRACKING.md) §2 (Graveyard Taxonomies)
- **Scope & Objectives**: Action sheet allowing users to move an active show to the Graveyard.
- **Granular Tasks**:
  - [ ] Create `lib/features/profile/presentation/widgets/log_dropped_show_sheet.dart`.
  - [ ] Season/Episode picker dropdowns.
  - [ ] Standardized reason taxonomy chips.
  - [ ] Save mutation writing to `user_rankings` with `status: 'dropped'`.
- **Testing & Verification**:
  - [ ] Unit test confirming moving show to Graveyard removes it from active Canon without corrupting Canon rank indexes.
- **Dependencies**: `FE-307`, `BE-201`.

---

### Track 4: Sprint 3 Quality Assurance & Testing

#### `QA-301`: Algorithmic Unit Tests for Borda Count Consensus Aggregator
- **Spec Reference**:
  - [**`technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) §2.1 (Borda Count)
- **Scope & Objectives**: Test consensus rank ordering mathematically under missing/incomplete member data.
- **Granular Tasks**:
  - [ ] Write `test/features/squads/borda_count_aggregator_test.dart`.
  - [ ] Test tie-breaking rules and fractional scoring for unranked items.
- **Testing & Verification**:
  - [ ] 100% test pass on mock squad ranking sets.
- **Dependencies**: `BE-304`.

#### `QA-302`: Unit Tests for Upset Detection Logic
- **Spec Reference**:
  - [**`technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) §2.1 (Upset Invariants)
- **Scope & Objectives**: Validate mathematical condition $\mu_{\text{diff}} \ge 0.25$ triggers upsets reliably.
- **Granular Tasks**:
  - [ ] Write `test/features/ranking/upset_detector_test.dart`.
  - [ ] Verify borderline conditions ($0.249 \implies \text{false}$, $0.250 \implies \text{true}$).
- **Testing & Verification**:
  - [ ] All boundary assertions pass.
- **Dependencies**: `BE-302`.

#### `QA-303`: Widget Tests for Feed Card, Upset Alert Card & Spoiler Masks
- **Spec Reference**:
  - [**`technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) §3.1 (Social Widgets)
- **Scope & Objectives**: Verify UI rendering and tap interactions on social cards.
- **Granular Tasks**:
  - [ ] Write `test/features/feed/feed_activity_card_test.dart`.
  - [ ] Write `test/features/feed/upset_activity_card_test.dart`.
  - [ ] Write `test/features/feed/spoiler_comment_test.dart`.
- **Testing & Verification**:
  - [ ] Tap on spoiler mask removes `BackdropFilter` and displays text.
- **Dependencies**: `FE-302`, `FE-303`, `FE-305`.

#### `QA-304`: pgTAP Tests for Social Follows, RLS & Feeds
- **Spec Reference**:
  - [**`technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) §3.3 (RLS Policies)
- **Scope & Objectives**: Verify database security rules and follow isolation.
- **Granular Tasks**:
  - [ ] Write `database/tests/02_social_follows_rls_test.sql`.
  - [ ] Verify private user rankings cannot be selected by non-followers.
- **Testing & Verification**:
  - [ ] pgTAP suite passes in Supabase local test container.
- **Dependencies**: `BE-301`.

---

## 📅 Sprint 4: Taste Match %, Co-Watch Decider, Streaming Deep Links & Queue (Weeks 7–8)

### Sprint Objective
Solve couch indecision by deploying the Spearman Rank Taste Match % algorithm, the "Two-to-Watch" co-watching decider with shared streaming filters, native streaming app deep links, and the smart universal queue.

---

### Track 1: Mathematical Engine & Availability Pipelines

#### `BE-401`: Supabase `calculate_taste_match_rpc` Stored Procedure
- **Spec Reference**:
  - [**`features/05_TASTE_MATCH_AND_CO_WATCH_DECIDER.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/05_TASTE_MATCH_AND_CO_WATCH_DECIDER.md) §1 (Spearman Rank Math)
  - [**`technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md) §3.2 (Taste Match RPC)
- **Scope & Objectives**: PL/pgSQL function computing Spearman Rank Correlation ($\rho$) with Bayesian shrinkage.
- **Granular Tasks**:
  - [ ] Write procedure `calculate_taste_match_rpc(p_user_a, p_user_b, p_media_type)`.
  - [ ] Find mutual titles in both users' canons: $k = |C_A \cap C_B|$.
  - [ ] Compute rank differences: $d_i = \text{Rank}_A(i) - \text{Rank}_B(i)$.
  - [ ] Calculate correlation: $\rho = 1.0 - \frac{6 \sum d_i^2}{k(k^2 - 1)}$.
  - [ ] Apply Bayesian confidence shrinkage prior $k_0 = 5$:
    $$\rho_{\text{shrunk}} = \frac{k}{k + k_0} \cdot \rho + \frac{k_0}{k + k_0} \cdot \mu_0$$
  - [ ] Normalize to percentage: $\text{Match} \% = \text{round}\left(\frac{\rho_{\text{shrunk}} + 1.0}{2.0} \times 100\right)$.
- **Testing & Verification**:
  - [ ] pgTAP test verifying identical rankings yield $100\%$; completely reversed rankings yield $0\%$.
- **Dependencies**: `BE-101`, `BE-201`.

#### `BE-402`: JustWatch / Watchmode Real-Time Availability Scraper & Redis Cache
- **Spec Reference**:
  - [**`technical_architecture/03_EXTERNAL_APIS_AND_DATA_PIPELINES.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/03_EXTERNAL_APIS_AND_DATA_PIPELINES.md) §2 (JustWatch Pipeline)
  - [**`features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md) §2 (Streaming Availability)
- **Scope & Objectives**: Fetch streaming availability per title and cache in Redis with 24-hour TTL.
- **Granular Tasks**:
  - [ ] Create Supabase Edge Function `functions/streaming-availability/index.ts`.
  - [ ] Query JustWatch / Watchmode API by TMDB ID and ISO country code (e.g., `US`).
  - [ ] Extract subscription availability (`flatrate`) vs purchase (`rent`/`buy`).
  - [ ] Store in Redis: `SET title:availability:{tmdb_id}:{country} {json} EX 86400`.
- **Testing & Verification**:
  - [ ] Test query for *Severance* returns Apple TV+ with valid web and deep link URLs.
- **Dependencies**: `BE-101`.

#### `BE-403`: Streaming Provider Regional Catalog Synchronizer
- **Spec Reference**:
  - [**`technical_architecture/03_EXTERNAL_APIS_AND_DATA_PIPELINES.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/03_EXTERNAL_APIS_AND_DATA_PIPELINES.md) §2 (Catalog Updates)
  - [**`adjacent_systems/03_SETTINGS_AND_PREFERENCES_ARCHITECTURE.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/adjacent_systems/03_SETTINGS_AND_PREFERENCES_ARCHITECTURE.md) §2 (Streaming Settings)
- **Scope & Objectives**: Daily cron pipeline refreshing regional streaming catalog changes and expiration alerts.
- **Granular Tasks**:
  - [ ] Setup daily GitHub Actions / Supabase cron job querying catalog additions and removals.
  - [ ] Flag titles leaving a provider in $\le 7$ days (`is_leaving_soon: true`).
- **Testing & Verification**:
  - [ ] Verify titles flagged as leaving soon trigger notification events.
- **Dependencies**: `BE-402`.

---

### Track 2: Taste Match % & Friend Comparison UI

#### `FE-401`: `SCR-15` Friend Profile & Taste Comparison View
- **Spec Reference**:
  - [**`design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md) §15 (`SCR-15`)
  - [**`features/05_TASTE_MATCH_AND_CO_WATCH_DECIDER.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/05_TASTE_MATCH_AND_CO_WATCH_DECIDER.md) §2 (Comparison UI)
- **Scope & Objectives**: Dedicated friend profile view prominently showcasing mutual taste compatibility.
- **Granular Tasks**:
  - [ ] Create `lib/features/profile/presentation/screens/friend_profile_screen.dart`.
  - [ ] Render large Taste Match Dial widget (radial progress bar with Phosphor Lime glow).
  - [ ] Display mutual titles count: *"Based on 28 mutual titles ranked"*.
  - [ ] Render Primary Action: `[ 🍿 Two-to-Watch with @handle ]`.
- **Testing & Verification**:
  - [ ] Widget test verifying radial dial displays animated percentage text `88%`.
- **Dependencies**: `FE-102`, `FE-104`.

#### `FE-402`: Dual Taste Match Breakdown Widgets (Movie Match % vs Series Match %)
- **Spec Reference**:
  - [**`features/09_MOVIE_INTEGRATION_AND_DUAL_CANON.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/09_MOVIE_INTEGRATION_AND_DUAL_CANON.md) §5 (Dual Taste Match)
  - [**`features/05_TASTE_MATCH_AND_CO_WATCH_DECIDER.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/05_TASTE_MATCH_AND_CO_WATCH_DECIDER.md) §2 (Sub-scores)
- **Scope & Objectives**: Break down taste compatibility into Movie Taste Match % and Series Taste Match %.
- **Granular Tasks**:
  - [ ] Build sub-card displaying dual score pills:
    - `🎬 Movie Taste Match: 92%` (High alignment on cinematic pacing & directors).
    - `📺 Series Taste Match: 71%` (Divergent opinions on long-form TV series).
  - [ ] Add explanatory tooltips describing Spearman correlation and sample size.
- **Testing & Verification**:
  - [ ] Widget test verifying both movie and series pills render with correct scores.
- **Dependencies**: `FE-401`.

#### `FE-403`: Mutual Agreements & Disagreements Breakdown Row
- **Spec Reference**:
  - [**`features/05_TASTE_MATCH_AND_CO_WATCH_DECIDER.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/05_TASTE_MATCH_AND_CO_WATCH_DECIDER.md) §2 (Agreements / Clashes)
- **Scope & Objectives**: Highlight the exact titles two friends agree on most and argue about most.
- **Granular Tasks**:
  - [ ] Render *"Where You Agree"* row (both have in Top 5, e.g., *Succession*).
  - [ ] Render *"Spiciest Clashes"* row (User ranked #2; Friend ranked #38).
  - [ ] Tap on title navigates to dual comparison detail sheet showing side-by-side ranks and review notes.
- **Testing & Verification**:
  - [ ] Widget test displaying agree/disagree cards with correct rank differential chips ($\Delta = 36$).
- **Dependencies**: `FE-401`.

---

### Track 3: Two-to-Watch Co-Watching Engine & Streaming Links

#### `FE-404`: `SCR-16` "Two-to-Watch" Co-Watching Decider Hub
- **Spec Reference**:
  - [**`design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md) §16 (`SCR-16`)
  - [**`features/05_TASTE_MATCH_AND_CO_WATCH_DECIDER.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/05_TASTE_MATCH_AND_CO_WATCH_DECIDER.md) §3 (Decider Engine)
- **Scope & Objectives**: The couch decider screen combining shared subscriptions, watchlists, and candidate rankings.
- **Granular Tasks**:
  - [ ] Create `lib/features/cowatch/presentation/screens/two_to_watch_screen.dart`.
  - [ ] Automatically calculate intersection of streaming providers between both users:
    $$\text{Shared} = \text{Providers}_A \cap \text{Providers}_B$$
  - [ ] Display shared provider icons (e.g., Netflix + Max).
  - [ ] Query and rank candidate pool combining both watchlists sorted by joint predicted enjoyment.
- **Testing & Verification**:
  - [ ] Widget test verifying only shared providers appear in active filters.
- **Dependencies**: `FE-108`, `FE-401`.

#### `FE-405`: Format Toggle (`[ 🎬 Movie Night ]` vs `[ 📺 Series ]`) & Runtime Budget Filters
- **Spec Reference**:
  - [**`features/09_MOVIE_INTEGRATION_AND_DUAL_CANON.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/09_MOVIE_INTEGRATION_AND_DUAL_CANON.md) §5 (Movie Night Decider)
  - [**`features/05_TASTE_MATCH_AND_CO_WATCH_DECIDER.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/05_TASTE_MATCH_AND_CO_WATCH_DECIDER.md) §3 (Filters)
- **Scope & Objectives**: Quick filter pills to constrain co-watching candidates by format and available time.
- **Granular Tasks**:
  - [ ] Format Segmented Control: `[ 🎬 Movie Night ]` | `[ 📺 TV Series ]`.
  - [ ] Runtime Budget Pills (active when Movie selected):
    - `[ ⚡ Under 90m ]` (e.g., *Run Lola Run*, *Past Lives*).
    - `[ 🍿 90–120m ]` (Standard film length).
    - `[ 🛋️ 120m+ Epic ]` (e.g., *Oppenheimer*).
  - [ ] Filter candidate list dynamically without network roundtrips.
- **Testing & Verification**:
  - [ ] Unit test verifying selecting `< 90m` filters out movies with `runtime > 90`.
- **Dependencies**: `FE-404`.

#### `FE-406`: Mutual Quick-Swipe Mini-Game Card Swiper
- **Spec Reference**:
  - [**`features/05_TASTE_MATCH_AND_CO_WATCH_DECIDER.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/05_TASTE_MATCH_AND_CO_WATCH_DECIDER.md) §3 (Quick Swipe Mode)
  - [**`design_system/04_USER_INTERACTION_FLOWS_AND_GESTURES.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/04_USER_INTERACTION_FLOWS_AND_GESTURES.md) §2 (Co-Watch Gestures)
- **Scope & Objectives**: 15-second simultaneous card swiping session that resolves on first mutual right-swipe.
- **Granular Tasks**:
  - [ ] Build card deck presentation using `flutter_card_swiper`.
  - [ ] Swipe right = Want to watch tonight; swipe left = Pass.
  - [ ] Connect WebSocket / Supabase Realtime channel broadcasting user swipes to friend's device.
  - [ ] When both swipe right on same title $\to$ trigger full-screen Match Modal with confetti and stream deep link.
- **Testing & Verification**:
  - [ ] Integration test simulating mutual right-swipe triggers match state in $< 100\text{ ms}$.
- **Dependencies**: `FE-404`.

#### `FE-407`: `StreamingDeepLinkFactory` Service
- **Spec Reference**:
  - [**`technical_architecture/03_EXTERNAL_APIS_AND_DATA_PIPELINES.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/03_EXTERNAL_APIS_AND_DATA_PIPELINES.md) §3 (Deep Links)
  - [**`features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md) §2 (App Linking)
- **Scope & Objectives**: Generate native URI schemes launching directly into installed streaming apps.
- **Granular Tasks**:
  - [ ] Create `lib/core/services/streaming_deep_link_factory.dart`.
  - [ ] Implement URI builders:
    - Netflix: `nflx://www.netflix.com/title/{id}`
    - Max: `max://play/{id}`
    - Hulu: `hulu://play/{id}`
    - Apple TV+: `videos://tv.apple.com/...`
    - Crunchyroll: `crunchyroll://series/{id}`
    - Prime Video: `primevideo://watch/{id}`
  - [ ] Fallback: If native app fails to launch (`canLaunchUrl == false`), open provider web URL in external browser.
- **Testing & Verification**:
  - [ ] Unit tests verifying URI schemes generated accurately for all 6 providers.
- **Dependencies**: None.

#### `FE-408`: `SCR-13` Smart Queue Screen with Dual Watchlists
- **Spec Reference**:
  - [**`design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md) §13 (`SCR-13`)
  - [**`features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md) §1 (Smart Watchlist)
- **Scope & Objectives**: Universal queue with segregated Movie/Series watchlists and streaming filters.
- **Granular Tasks**:
  - [ ] Create `lib/features/queue/presentation/screens/smart_queue_screen.dart`.
  - [ ] Segregated tabs: `[ 🎬 Movies to Watch (18) ]` | `[ 📺 Series to Watch (12) ]`.
  - [ ] Master filter toggle: `[ Only Titles on My Subscriptions: ON ]`.
  - [ ] Render 1-tap "Watch Now" action with native provider badge.
- **Testing & Verification**:
  - [ ] Widget test verifying queue filters out unsubscribed titles when toggle is ON.
- **Dependencies**: `FE-104`, `FE-407`.

---

### Track 4: Sprint 4 Quality Assurance & Testing

#### `QA-401`: Mathematical Unit Tests for Spearman Rank Correlation ($\rho$) & Bayesian Shrinkage
- **Spec Reference**:
  - [**`technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) §2.1 (Correlation Invariants)
- **Scope & Objectives**: Test Spearman correlation formulas, low-sample shrinkage, and score stability.
- **Granular Tasks**:
  - [ ] Write `test/features/cowatch/spearman_correlation_test.dart`.
  - [ ] Test identical ranks yield $\rho = 1.0$; reverse ranks yield $\rho = -1.0$.
  - [ ] Test shrinkage: 2 overlapping titles with identical order yields $\le 65\%$ match due to prior $k_0 = 5$.
- **Testing & Verification**:
  - [ ] 100% test pass with KaTeX formula verification.
- **Dependencies**: `BE-401`.

#### `QA-402`: Unit Tests for `StreamingDeepLinkFactory`
- **Spec Reference**:
  - [**`technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) §2.1 (Deep Links)
- **Scope & Objectives**: Test URI construction and web fallback routes.
- **Granular Tasks**:
  - [ ] Write `test/core/services/streaming_deep_link_factory_test.dart`.
- **Testing & Verification**:
  - [ ] Assert valid scheme for all 6 supported streaming platforms.
- **Dependencies**: `FE-407`.

#### `QA-403`: Integration Tests for "Two-to-Watch" Joint Candidate Scoring
- **Spec Reference**:
  - [**`technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) §3.2 (Integration Tests)
- **Scope & Objectives**: Test candidate pool assembly and joint score calculation across two mock users.
- **Granular Tasks**:
  - [ ] Write `test/features/cowatch/two_to_watch_engine_test.dart`.
  - [ ] Assert candidate pool ranks mutual watchlist items higher than unranked titles.
- **Testing & Verification**:
  - [ ] Integration test passes with simulated provider overlap.
- **Dependencies**: `FE-404`.

#### `QA-404`: pgTAP Tests for `calculate_taste_match_rpc`
- **Spec Reference**:
  - [**`technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) §3.3 (Taste Match pgTAP)
- **Scope & Objectives**: Verify PostgreSQL PL/pgSQL procedure returns accurate percentages in $< 15\text{ ms}$.
- **Granular Tasks**:
  - [ ] Write `database/tests/03_taste_match_rpc_test.sql`.
- **Testing & Verification**:
  - [ ] pgTAP suite runs in Supabase container; latency under 15ms.
- **Dependencies**: `BE-401`.

---

## 📅 Sprint 5: Viral Sharing, Offline Hardening, DevOps & App Store Submission (Weeks 9–10)

### Sprint Objective
Build the high-resolution Instagram Story studio, harden offline Drift WAL synchronization, configure GitHub Actions CI/CD with Fastlane, complete full test pyramid audits, and submit the production app to Apple and Google.

---

### Track 1: Viral Studio, Export & Offline Sync

#### `FE-501`: `StoryCardRenderer` Off-Screen 1080x1920 9:16 Graphic Generator
- **Spec Reference**:
  - [**`adjacent_systems/04_VIRAL_SHARING_AND_EXPORT_STUDIO.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/adjacent_systems/04_VIRAL_SHARING_AND_EXPORT_STUDIO.md) §1 (Story Generator)
  - [**`technical_architecture/04_CLIENT_ARCHITECTURE_AND_OFFLINE_SYNC.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/04_CLIENT_ARCHITECTURE_AND_OFFLINE_SYNC.md) §4 (Story Card Renderer)
- **Scope & Objectives**: Render pixel-perfect 1080x1920 Instagram/TikTok story images off-screen without blocking UI.
- **Granular Tasks**:
  - [ ] Create `lib/features/sharing/presentation/widgets/story_card_renderer.dart`.
  - [ ] Wrap target card in off-screen `RepaintBoundary` with fixed $1080 \times 1920$ dimensions.
  - [ ] Convert boundary to PNG byte buffer using `toImage(pixelRatio: 3.0)`.
  - [ ] Invoke native OS sharing sheet via `package:share_plus`.
- **Testing & Verification**:
  - [ ] Unit test asserting generated image bytes correspond to valid PNG header and $1080 \times 1920$ size.
- **Dependencies**: `FE-102`.

#### `FE-502`: `SCR-19` Telly Wrapped Studio (Top 9 Grids & Annual Recaps)
- **Spec Reference**:
  - [**`design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md) §19 (`SCR-19`)
  - [**`adjacent_systems/04_VIRAL_SHARING_AND_EXPORT_STUDIO.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/adjacent_systems/04_VIRAL_SHARING_AND_EXPORT_STUDIO.md) §2 (Story Templates)
- **Scope & Objectives**: Studio screen offering aesthetic templates for social sharing.
- **Granular Tasks**:
  - [ ] Template 1: **Top 9 Movie Canon Grid** with aesthetic poster tiles and scores.
  - [ ] Template 2: **Top 9 Series Canon Grid**.
  - [ ] Template 3: **Spicy Upset Card** showcasing the user's most controversial duel.
  - [ ] Template 4: **Director Affinity Radar** (e.g., Nolan, Villeneuve, Miyazaki).
  - [ ] Export directly to Instagram Stories with 1 tap.
- **Testing & Verification**:
  - [ ] Widget test verifying template carousel switches cards cleanly.
- **Dependencies**: `FE-501`.

#### `FE-503`: Letterboxd Migration Celebration Card Generator
- **Spec Reference**:
  - [**`features/09_MOVIE_INTEGRATION_AND_DUAL_CANON.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/features/09_MOVIE_INTEGRATION_AND_DUAL_CANON.md) §4 (Celebration Card)
  - [**`adjacent_systems/04_VIRAL_SHARING_AND_EXPORT_STUDIO.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/adjacent_systems/04_VIRAL_SHARING_AND_EXPORT_STUDIO.md) §2 (Viral Templates)
- **Scope & Objectives**: High-converting shareable graphic for Letterboxd immigrants.
- **Granular Tasks**:
  - [ ] Generate graphic stating: *"Imported 412 films from Letterboxd to Telly — here is my true #1 ranked movie"*.
  - [ ] Include user's top-ranked movie poster, dynamic score (10.00), and custom QR code deep link.
- **Testing & Verification**:
  - [ ] Test graphic paints correct movie title and poster without rendering overflows.
- **Dependencies**: `FE-501`, `FE-111`.

#### `FE-504`: Drift SQLite Offline Write-Ahead Log (WAL) & Auto-Sync Engine
- **Spec Reference**:
  - [**`technical_architecture/04_CLIENT_ARCHITECTURE_AND_OFFLINE_SYNC.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/04_CLIENT_ARCHITECTURE_AND_OFFLINE_SYNC.md) §3 (Offline Sync Architecture)
- **Scope & Objectives**: 0ms optimistic UI updates during airplane mode with FIFO queue flushing on reconnect.
- **Granular Tasks**:
  - [ ] Create `lib/core/network/offline_sync_manager.dart`.
  - [ ] When offline: persist ranking/duel mutations to Drift `OfflineDuelQueue` with pending UUIDs.
  - [ ] Update local Drift tables immediately for zero perceived latency.
  - [ ] Listen to `connectivity_plus` network transitions: when online, flush queued transactions in sequential FIFO order to Supabase.
- **Testing & Verification**:
  - [ ] Unit test queue: enqueue 3 offline duels $\to$ simulate reconnect $\to$ assert 3 calls executed in FIFO order.
- **Dependencies**: `FE-105`.

#### `FE-505`: `SCR-20` Settings Hub & Granular Preferences
- **Spec Reference**:
  - [**`design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md) §20 (`SCR-20`)
  - [**`adjacent_systems/03_SETTINGS_AND_PREFERENCES_ARCHITECTURE.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/adjacent_systems/03_SETTINGS_AND_PREFERENCES_ARCHITECTURE.md) §1–§4 (Settings Hierarchy)
- **Scope & Objectives**: Central configuration hub for account, streaming services, push notifications, and storage.
- **Granular Tasks**:
  - [ ] Account section: Change phone/email, FaceID biometric unlock toggle.
  - [ ] Streaming section: Edit active services and update JustWatch country region.
  - [ ] Notifications matrix: Granular toggles (Upset Alerts, Co-Watch Invites, Friend Activity) + Quiet Hours schedule.
  - [ ] Storage hygiene: Display local cached image size with *"Clear Image Cache"* action.
- **Testing & Verification**:
  - [ ] Widget test verifying toggle state changes update SharedPreferences / Drift settings.
- **Dependencies**: `FE-104`.

#### `FE-506`: Self-Service CSV, Notion & Letterboxd Data Exporter
- **Spec Reference**:
  - [**`adjacent_systems/04_VIRAL_SHARING_AND_EXPORT_STUDIO.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/adjacent_systems/04_VIRAL_SHARING_AND_EXPORT_STUDIO.md) §4 (Data Portability)
- **Scope & Objectives**: GDPR-compliant full data export in CSV, Notion-compatible schema, and Letterboxd format.
- **Granular Tasks**:
  - [ ] Create `lib/features/profile/domain/data_exporter.dart`.
  - [ ] Format 1: `telly_canon_export.csv` (Rank, Title, Media Type, Score, MVP, Vibe Tags, Date Added).
  - [ ] Format 2: `letterboxd_diary_export.csv` (compatible with Letterboxd re-import).
  - [ ] Provide 1-tap download and OS share sheet invocation.
- **Testing & Verification**:
  - [ ] Unit test asserting CSV output matches standard RFC 4180 format.
- **Dependencies**: `FE-105`.

#### `FE-507`: `SCR-08` Edit Profile Studio, Avatar Cropper & Top 3 Showcase
- **Spec Reference**:
  - [**`design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md) §8 (`SCR-08`)
  - [**`adjacent_systems/02_PROFILE_MANAGEMENT_AND_CUSTOMIZATION.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/adjacent_systems/02_PROFILE_MANAGEMENT_AND_CUSTOMIZATION.md) §1–§2 (Profile Studio)
- **Scope & Objectives**: Profile personalization screen with square avatar cropping and Top 3 title curation.
- **Granular Tasks**:
  - [ ] Implement avatar upload using `image_picker` and `image_cropper` (1:1 aspect ratio constraint).
  - [ ] Bio editor with 160-character ceiling.
  - [ ] Top 3 Showcase Selector: Pick 3 crowning titles pinned to top of profile.
  - [ ] Privacy Mode Toggle: `[ Public ]` | `[ Friends-Only ]` | `[ Ghost Mode ]`.
- **Testing & Verification**:
  - [ ] Widget test verifying avatar crop result updates preview state.
- **Dependencies**: `FE-104`.

#### `FE-508`: In-App Spoiler Shield & Report Content Sheets
- **Spec Reference**:
  - [**`adjacent_systems/05_TRUST_SAFETY_MODERATION_AND_ADMIN.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/adjacent_systems/05_TRUST_SAFETY_MODERATION_AND_ADMIN.md) §1–§2 (Trust & Safety)
- **Scope & Objectives**: Apple Guideline 1.2 compliant user reporting and proactive show muting shields.
- **Granular Tasks**:
  - [ ] Build Proactive Show Mute Sheet: Mute any series or movie (e.g., hide all posts about *House of the Dragon* until watched).
  - [ ] Build Content Reporting Bottom Sheet: Options (`Spoiler Unmasked`, `Harassment`, `Spam`, `Inaccurate Metadata`).
  - [ ] Submit reports to Supabase `reports` table for back-office moderation queue.
- **Testing & Verification**:
  - [ ] Test submitting a report creates row in `reports` and hides offending post immediately for current user.
- **Dependencies**: `FE-104`, `BE-101`.

---

### Track 2: DevOps, CI/CD & Production Infrastructure

#### `DEV-501`: GitHub Actions CI/CD Pipeline Configuration
- **Spec Reference**:
  - [**`technical_architecture/05_DEPLOYMENT_DEVOPS_AND_LAUNCH_CHECKLIST.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/05_DEPLOYMENT_DEVOPS_AND_LAUNCH_CHECKLIST.md) §2 (CI/CD Pipelines)
  - [**`technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) §7 (Quality Gates)
- **Scope & Objectives**: Automate linting, unit testing, widget testing, and build artifact creation on every pull request.
- **Granular Tasks**:
  - [ ] Configure `.github/workflows/pull_request.yml`.
  - [ ] Stage 1: `dart analyze --fatal-infos`.
  - [ ] Stage 2: `flutter test --coverage` (enforcing $\ge 80\%$ project coverage).
  - [ ] Stage 3: pgTAP database stored procedure checks.
  - [ ] Block PR merge automatically if any stage fails.
- **Testing & Verification**:
  - [ ] Verify workflow passes on clean branch and fails on intentional lint violation.
- **Dependencies**: `QA-101`.

#### `DEV-502`: Fastlane Automated TestFlight & Google Play Deployment
- **Spec Reference**:
  - [**`technical_architecture/05_DEPLOYMENT_DEVOPS_AND_LAUNCH_CHECKLIST.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/05_DEPLOYMENT_DEVOPS_AND_LAUNCH_CHECKLIST.md) §2 (Fastlane Lanes)
- **Scope & Objectives**: 1-command build and upload to Apple TestFlight and Google Play Internal Track.
- **Granular Tasks**:
  - [ ] Configure `ios/fastlane/Fastfile` with lane `beta` (Match code signing, build ipa, upload to TestFlight).
  - [ ] Configure `android/fastlane/Fastfile` with lane `beta` (sign AAB bundle, upload to Play Console).
  - [ ] Store App Store Connect API keys and Android service account JSON in GitHub Secrets.
- **Testing & Verification**:
  - [ ] Execute `fastlane beta` dry-run; verify IPA and AAB bundles compile successfully.
- **Dependencies**: `DEV-501`.

#### `DEV-503`: Sentry Error Monitoring & PostHog Telemetry SDK Setup
- **Spec Reference**:
  - [**`technical_architecture/05_DEPLOYMENT_DEVOPS_AND_LAUNCH_CHECKLIST.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/05_DEPLOYMENT_DEVOPS_AND_LAUNCH_CHECKLIST.md) §3 (Observability)
  - [**`technical_architecture/01_TECH_STACK_AND_LIBRARIES.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/01_TECH_STACK_AND_LIBRARIES.md) §2 (Monitoring Libs)
- **Scope & Objectives**: Real-time crash diagnostics, performance tracing, and product telemetry.
- **Granular Tasks**:
  - [ ] Initialize `sentry_flutter` in `main.dart` with DSN from `.env`.
  - [ ] Configure automatic breadcrumb capture (navigation routes, network calls, duel votes).
  - [ ] Initialize `posthog_flutter` tracking core product events (`duel_completed`, `upset_alert_shared`, `cowatch_matched`).
- **Testing & Verification**:
  - [ ] Trigger test exception `Sentry.captureException()`; verify error appears in Sentry dashboard.
- **Dependencies**: `FE-101`.

#### `DEV-504`: Cloudflare Turnstile & Edge Caching Configuration
- **Spec Reference**:
  - [**`technical_architecture/03_EXTERNAL_APIS_AND_DATA_PIPELINES.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/03_EXTERNAL_APIS_AND_DATA_PIPELINES.md) §1 (Edge Caching)
- **Scope & Objectives**: Protect public endpoints and cache static poster metadata at the edge.
- **Granular Tasks**:
  - [ ] Route `api.telly.app` through Cloudflare proxy.
  - [ ] Configure Cloudflare Cache Rules: cache image responses for 30 days; cache TMDB metadata for 7 days.
  - [ ] Enable Turnstile bot protection on SMS auth endpoints.
- **Testing & Verification**:
  - [ ] Verify response headers contain `CF-Cache-Status: HIT` on subsequent title queries.
- **Dependencies**: `BE-104`.

---

### Track 3: Legal, App Store Compliance & Submission

#### `LEGAL-501`: Deploy Live Privacy Policy & EULA Web Endpoints
- **Spec Reference**:
  - [**`legal/PRIVACY_POLICY.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/legal/PRIVACY_POLICY.md) (Full Privacy Policy)
  - [**`legal/TERMS_OF_SERVICE.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/legal/TERMS_OF_SERVICE.md) (Standard EULA)
- **Scope & Objectives**: Host compliant legal documentation required for App Store and Google Play approval.
- **Granular Tasks**:
  - [ ] Host static markdown/HTML at `https://telly.app/privacy` and `https://telly.app/terms`.
  - [ ] Embed in-app web views in `SCR-20` Settings linking directly to both documents.
- **Testing & Verification**:
  - [ ] Verify public HTTP 200 response on both URLs.
- **Dependencies**: None.

#### `LEGAL-502`: Apple Guideline 1.2 UGC Compliance & 30-Day Account Deletion Pipeline
- **Spec Reference**:
  - [**`adjacent_systems/05_TRUST_SAFETY_MODERATION_AND_ADMIN.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/adjacent_systems/05_TRUST_SAFETY_MODERATION_AND_ADMIN.md) §5 (Account Deletion & UGC)
  - [**`technical_architecture/05_DEPLOYMENT_DEVOPS_AND_LAUNCH_CHECKLIST.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/05_DEPLOYMENT_DEVOPS_AND_LAUNCH_CHECKLIST.md) §4 (App Store Guidelines)
- **Scope & Objectives**: Satisfy Apple Guideline 1.2 (User Generated Content) and mandatory self-service account deletion.
- **Granular Tasks**:
  - [ ] Implement self-service "Delete Account" button in `SCR-20` Settings with confirmation dialog.
  - [ ] Queue account for 30-day soft deletion, revoking sessions and scrubbing user data permanently.
  - [ ] Include 1-tap user blocking and reporting on all user-generated comments.
- **Testing & Verification**:
  - [ ] Test account deletion marks profile `is_deleted: true` and logs user out immediately.
- **Dependencies**: `FE-505`, `BE-101`.

#### `LEGAL-503`: Production App Store Connect & Google Play Console Submission
- **Spec Reference**:
  - [**`technical_architecture/05_DEPLOYMENT_DEVOPS_AND_LAUNCH_CHECKLIST.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/05_DEPLOYMENT_DEVOPS_AND_LAUNCH_CHECKLIST.md) §4 (Launch Checklist)
- **Scope & Objectives**: Submit production binaries, localized metadata, and screenshots for store review.
- **Granular Tasks**:
  - [ ] Prepare 6.7" iPhone and 12.9" iPad App Store screenshots showcasing OLED dark theme.
  - [ ] Complete App Store Connect App Privacy nutrition labels.
  - [ ] Provide active demo credentials and test OTP phone number for App Reviewers.
  - [ ] Submit iOS build to Apple Review and Android build to Google Play Review.
- **Testing & Verification**:
  - [ ] Assert build passes Apple Automated Validation without missing icon/privacy manifest errors.
- **Dependencies**: `DEV-502`, `LEGAL-501`, `LEGAL-502`.

---

### Track 4: Sprint 5 Quality Assurance & Testing

#### `QA-501`: End-to-End Test Suite for All 4 Critical User Journeys (CUJ-01 to CUJ-04)
- **Spec Reference**:
  - [**`technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) §4 (E2E Test Specifications)
- **Scope & Objectives**: Automate complete user journeys using `package:integration_test`.
- **Granular Tasks**:
  - [ ] Write `integration_test/cuj_01_onboarding_test.dart` (Onboarding to Initial Canon calibration).
  - [ ] Write `integration_test/cuj_02_logging_movie_test.dart` (Search $\to$ 3 duels $\to$ venue tag $\to$ slot reveal).
  - [ ] Write `integration_test/cuj_03_cowatch_test.dart` (Two-to-Watch filter $\to$ Quick Swipe $\to$ match).
  - [ ] Write `integration_test/cuj_04_offline_wal_test.dart` (Airplane mode duel vote $\to$ reconnect $\to$ WAL sync).
- **Testing & Verification**:
  - [ ] Execute `flutter test integration_test/` on CI simulator; all 4 journeys pass in $< 3\text{ minutes}$.
- **Dependencies**: `FE-106`, `FE-201`, `FE-404`, `FE-504`.

#### `QA-502`: Visual Golden Regression Test Suite for OLED Dark Surfaces & Tokens
- **Spec Reference**:
  - [**`technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) §5.1 (Golden Tests)
- **Scope & Objectives**: Prevent visual regressions across design tokens, dark surfaces, and typography.
- **Granular Tasks**:
  - [ ] Create `test/goldens/screen_goldens_test.dart`.
  - [ ] Capture goldens for `SCR-10` (Duel Arena), `SCR-14` (Dual-Canon Profile), `SCR-05` (Feed Upset Card).
  - [ ] Compare using `matchesGoldenFile()`.
- **Testing & Verification**:
  - [ ] All golden snapshots match pixel-for-pixel on `@2x` and `@3x` retina scales.
- **Dependencies**: `FE-201`, `FE-206`, `FE-303`.

#### `QA-503`: WCAG 2.1 AA Accessibility Automated Semantics Audit
- **Spec Reference**:
  - [**`technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) §5.2 (Accessibility Audit)
- **Scope & Objectives**: Ensure screen reader accessibility and physical touch target sizes.
- **Granular Tasks**:
  - [ ] Write `test/a11y/accessibility_test.dart` using `tester.getSemantics()`.
  - [ ] Assert every tap target is at least $48 \times 48\text{ dp}$.
  - [ ] Assert every interactive icon has a descriptive `semanticsLabel`.
- **Testing & Verification**:
  - [ ] Automated semantics audit passes with zero violations.
- **Dependencies**: `FE-104`.

#### `QA-504`: 60fps/120fps Frame Rate Benchmarking & Jank Regression Profiling
- **Spec Reference**:
  - [**`technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) §5.3 (Frame Rate Profiling)
- **Scope & Objectives**: Profile rendering pipeline to eliminate dropped frames and memory leaks.
- **Granular Tasks**:
  - [ ] Write `test_driver/perf_driver.dart` measuring frame rasterization times during rapid feed scrolling and duel card swiping.
  - [ ] Assert 99th percentile frame build time remains $< 16.6\text{ ms}$ (60fps target).
- **Testing & Verification**:
  - [ ] Frame rate benchmark logs zero dropped frames over 500 simulated scroll events.
- **Dependencies**: `FE-202`, `FE-301`.

#### `QA-505`: Offline WAL Stress & Network Partitioning Recovery Tests
- **Spec Reference**:
  - [**`technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md) §4 (CUJ-04), §2.3 (WAL Storage)
- **Scope & Objectives**: Verify data consistency during erratic network dropouts and sudden app kills.
- **Granular Tasks**:
  - [ ] Test simulating 50 offline duel votes followed by process kill and restart.
  - [ ] Assert on restart, Drift WAL transaction queue remains intact and flushes cleanly upon network restore.
- **Testing & Verification**:
  - [ ] Zero lost duels, zero corrupted ranking indices.
- **Dependencies**: `FE-504`.

---

## 🏆 Sprint Deliverables Summary Matrix

| Sprint | Weeks | Primary Focus | Core Technical Deliverables | Critical Quality Gates |
| :---: | :---: | :--- | :--- | :--- |
| **Sprint 1** | Weeks 1–2 | **Foundation, Auth & Ingestion** | Supabase Postgres 16 schema, Drift SQLite, `SCR-01` Auth, Letterboxd/AniList parsers | `QA-101`, `QA-102` (100% parser coverage) |
| **Sprint 2** | Weeks 3–4 | **Duel Engine & Personal Canon** | Binary sort algorithm, dynamic score formula, `SCR-10` Duel Arena, `SCR-14` Dual-Canon | `QA-201`, `QA-202` ($\mathcal{O}(\log N)$ math & score monotonicity) |
| **Sprint 3** | Weeks 5–6 | **Social Graph & Activity Feeds** | Upset Engine ($\mu_{\text{diff}} \ge 0.25$), `SCR-05` Feed, `SCR-17` Squads, `SCR-18` TV Graveyard | `QA-301`, `QA-304` (Borda count & pgTAP RLS) |
| **Sprint 4** | Weeks 7–8 | **Taste Match % & Co-Watching** | Spearman correlation RPC, `SCR-16` Two-to-Watch, JustWatch links, `SCR-13` Queue | `QA-401`, `QA-404` (Taste match accuracy & deep links) |
| **Sprint 5** | Weeks 9–10 | **Viral Studio, DevOps & Launch** | `SCR-19` Wrapped Studio, Offline WAL sync, Fastlane CI/CD, Apple/Google Submission | `QA-501` to `QA-505` (E2E CUJs, Goldens, a11y, 60fps) |

---
*Roadmap Version: 2.0.0 (Production Breakdown)*  
*Engineered for: Antigravity Multi-Disciplinary Engineering Team*
