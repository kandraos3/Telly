# Technical Architecture Spec 01: Tech Stack, Dependencies & Library Manifest

## 1. Technical Objectives & Constraints

To deliver an award-winning mobile experience that matches **Beli's** fluidity and speed, the technical stack must meet the following non-negotiable performance targets:
- **Frame Rate:** Sustained **60–120 fps** during pairwise card swipe battles, sheet pans, and drag-and-drop leaderboard reordering.
- **Cold-Start App Launch:** $< 800\text{ms}$ on modern devices (iPhone 13+, Pixel 7+).
- **Network Resilience (Offline-First):** Full ranking, browsing personal canon, and logging queue operates with zero network latency using local SQLite caching; syncs changes in the background.
- **Off-Screen Graphics Generation:** High-resolution (1080x1920 3x Retina) Instagram Story card generation in $< 350\text{ms}$ without server round-trips.

---

## 2. Core Stack Selection

```
┌────────────────────────────────────────────────────────────────────────┐
│                        TELLY ARCHITECTURE STACK                        │
├────────────────────────────────────────────────────────────────────────┤
│  MOBILE CLIENT (iOS & Android)                                         │
│  • Framework: Flutter 3.24+ (Dart 3.5+)                                │
│    (Delivers 120fps Impeller rendering engine, pixel-perfect dark UI,  │
│     and identical cross-platform physics on iOS & Android)            │
│  • State Management: Flutter Riverpod 2.5+ (Compile-safe, reactive)    │
│  • Local Database / Caching: Drift 2.20+ (Type-safe SQLite ORM)        │
│  • Routing & Deep-Linking: GoRouter 14.x                               │
│                                                                        │
│  BACKEND & DATABASE INFRASTRUCTURE                                     │
│  • Primary Database: Supabase (PostgreSQL 16) with Row-Level Security │
│  • In-Memory Cache & Leaderboards: Redis 7 (Upstash or Redis Cloud)   │
│  • API & Edge Compute: Supabase Edge Functions (Deno / TypeScript)     │
│  • Data Ingestion Workers: Go (Golang 1.23) / Python 3.12 microservice │
│                                                                        │
│  THIRD-PARTY DATA PROVIDERS & SERVICES                                 │
│  • Entertainment Metadata: TMDB (The Movie Database) API v3/v4         │
│  • Streaming Availability: JustWatch / Watchmode API                   │
│  • Authentication: Supabase Auth (Apple, Google, Twilio SMS OTP)      │
│  • Push Notifications: OneSignal / Firebase Cloud Messaging (FCM/APNs) │
│  • Crash & Error Monitoring: Sentry Flutter                            │
│  • Product Analytics: PostHog (Privacy-focused, self-hostable)         │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Client-Side Libraries & Dependency Manifest (`pubspec.yaml`)

Below is the verified, production-ready Flutter dependencies manifest:

```yaml
name: telly_app
description: "The Beli for Television — Pairwise Ranking and Social Discovery"
publish_to: "none"
version: 1.0.0+1

environment:
  sdk: ">=3.5.0 <4.0.0"
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter

  # --- Architecture & State Management ---
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0

  # --- Routing & Deep Linking ---
  go_router: ^14.2.7
  uni_links: ^0.5.1 # Native deep link listener (telly.app/u/...)

  # --- Networking & API ---
  dio: ^5.7.0
  dio_smart_retry: ^6.0.0
  graphql_flutter: ^5.1.2 # For AniList GraphQL API queries & sync
  supabase_flutter: ^2.6.0

  # --- Local Persistence & Offline-First (Drift SQLite) ---
  drift: ^2.20.1
  sqlite3_flutter_libs: ^0.5.24
  path_provider: ^2.1.4
  path: ^1.9.0
  flutter_secure_storage: ^9.2.2 # Encrypted token storage

  # --- UI, Animations & Card Duel Physics ---
  flutter_animate: ^4.5.0 # Spring curves & micro-interactions
  flutter_card_swiper: ^7.0.0 # High-performance card duel swiping
  reorderables: ^0.6.0 # Smooth drag-and-drop leaderboard
  shimmer: ^3.0.0 # Skeleton loading states
  cached_network_image: ^3.4.0 # Disk & RAM image caching

  # --- Sensory & Haptics ---
  flutter_vibrate: ^1.3.0

  # --- Off-Screen Graphic Generation & Social Sharing ---
  screenshot: ^3.0.0 # Render widget tree to PNG
  share_plus: ^10.0.2 # Native iOS & Android system share sheets
  social_share: ^2.3.1 # Direct Instagram / TikTok Story stickers

  # --- Utilities & Media ---
  intl: ^0.19.0
  uuid: ^4.5.1
  url_launcher: ^6.3.0 # Native app deep linking (max://, nflx://)

  # --- Telemetry & Analytics ---
  sentry_flutter: ^8.9.0
  posthog_flutter: ^4.3.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  build_runner: ^2.4.12
  riverpod_generator: ^2.4.2
  drift_dev: ^2.20.1
  freezed: ^2.5.7
  json_serializable: ^6.8.0
```

---

## 4. Component-by-Component Library & Tech Mapping

| Feature / UI Component | Technology / Library | Architectural Role |
| :--- | :--- | :--- |
| **Pairwise Duel Arena** | `flutter_card_swiper` + `flutter_animate` | 60fps card drag gestures, spring release, 1.04x winner scaling, and loser dismissal |
| **Canon Leaderboard** | `Drift` (SQLite) + `ReorderableListView` | Reorder shows with smooth drag-and-drop while executing atomic rank recalculations |
| **Off-Screen Story Cards** | `screenshot` (`RepaintBoundary`) | Paints a 1080x1920 widget tree off-screen, converts to PNG bytes, pipes to Instagram Stories |
| **1-Tap Streaming Launcher** | `url_launcher` | Evaluates native URI schemes (`nflx://`, `max://`, `https://`) with graceful browser fallback |
| **Network Image Caching** | `cached_network_image` | Multi-tier LRU cache (RAM 64MB + Disk 250MB) to prevent TMDB poster re-fetching |
| **Offline Sync Worker** | Custom Drift write-ahead log | Queues user rankings and duels locally during offline mode, syncs via Supabase batch RPC |
| **Spoiler Blur Masks** | `BackdropFilter` with `ImageFilter.blur` | Hardware-accelerated GPU Gaussian blur with tap-to-reveal toggle |

---

## 5. React Native Alternative Mapping (For Reference)

If the engineering team prefers a JavaScript/TypeScript ecosystem, the direct equivalent stack is:
- **Mobile Framework:** React Native 0.75+ with **New Architecture (Fabric + TurboModules)**.
- **State Management:** Zustand + TanStack Query (React Query v5).
- **Navigation:** React Navigation v6 / Expo Router.
- **Local Database:** WatermelonDB (SQLite backed) or OP-SQLite.
- **Gestures & Animations:** `react-native-reanimated` v3 + `react-native-gesture-handler`.
- **Card Swiper:** `react-native-deck-swiper`.
- **Off-Screen Render:** `react-native-view-shot`.
