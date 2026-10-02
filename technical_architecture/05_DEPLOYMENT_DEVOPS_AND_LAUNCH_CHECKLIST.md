# Technical Architecture Spec 05: Deployment, DevOps & Production Launch Checklist

## 1. Environments & Infrastructure Topology

Telly operates across three isolated environments to ensure zero downtime and reliable schema migrations:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        ENVIRONMENT SPECIFICATIONS                      │
├────────────────────────────────────────────────────────────────────────┤
│  1. LOCAL / DEVELOPMENT                                                │
│     • Client: Flutter Web / iOS Simulator / Android Emulator           │
│     • Backend: Local Supabase CLI (Dockerized Postgres, GoTrue, S3)    │
│     • TMDB: Live Sandbox with local mock responses                     │
│                                                                        │
│  2. STAGING                                                            │
│     • Client: iOS TestFlight (Internal) & Google Play Closed Testing   │
│     • Backend: Supabase Staging Project                                │
│     • Domain: `staging-api.telly.app`                                  │
│                                                                        │
│  3. PRODUCTION                                                         │
│     • Client: Apple App Store & Google Play Store (Production Track)   │
│     • Backend: Supabase Pro Compute Cluster (Multi-AZ, Daily Backups)   │
│     • Cache: Upstash Redis (Serverless High-Availability)              │
│     • CDN & Edge: Cloudflare Enterprise / Workers                       │
│     • Primary Domain: `api.telly.app` / `telly.app`                    │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. CI/CD Automation Pipeline (GitHub Actions + Fastlane)

Automated workflows ensure every pull request is analyzed and releases are dispatched to app stores without manual human intervention.

```yaml
# .github/workflows/mobile_release.yml
name: Deploy Mobile Beta to TestFlight & Google Play

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  build-and-deploy:
    runs-on: macos-14 # Apple Silicon M2 runner for high-speed builds
    steps:
      - name: Checkout Codebase
        uses: actions/checkout@v4

      - name: Set up Java 17
        uses: actions/setup-java@v3
        with:
          distribution: 'zulu'
          java-version: '17'

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.3'
          channel: 'stable'
          cache: true

      - name: Install Dependencies
        run: flutter pub get

      - name: Run Static Analysis & Unit Tests
        run: |
          flutter analyze
          flutter test

      - name: Build & Deploy iOS to TestFlight
        env:
          APP_STORE_CONNECT_API_KEY: ${{ secrets.APP_STORE_KEY }}
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
        run: |
          cd ios
          bundle install
          bundle exec fastlane beta

      - name: Build & Deploy Android App Bundle (AAB) to Google Play
        env:
          PLAY_STORE_JSON_KEY: ${{ secrets.PLAY_STORE_KEY }}
        run: |
          cd android
          bundle install
          bundle exec fastlane beta
```

---

## 3. Observability, Telemetry & Crash Monitoring

### 3.1 Error Reporting with Sentry
- Sentry captures all uncaught exceptions, Flutter widget layout errors, and failed Drift database migrations.
- Configured with custom breadcrumbs to trace the exact user journey preceding a crash:
  - `Breadcrumb: Launched Duel Arena for Show TMDB #110492`
  - `Breadcrumb: Tap Winner (Severance over Succession)`
  - `Exception: SQLite Write Error: Disk Full`

### 3.2 Product Telemetry (PostHog Events)
To measure virality and retention without compromising user privacy:
- `event: onboarding_completed` (Properties: `canon_seed_count`, `duration_seconds`)
- `event: duel_battle_won` (Properties: `winner_id`, `loser_id`, `is_upset`)
- `event: canon_published` (Properties: `rank_slot`, `score`, `has_hot_take`)
- `event: two_to_watch_started` (Properties: `friend_count`, `shared_providers_count`)
- `event: story_card_exported` (Properties: `template_type: top9 | upset | match`)

---

## 4. Production Launch Checklist (App Store & Google Play)

### 4.1 iOS App Store Requirements
- [x] **Privacy Manifest (`PrivacyInfo.xcprivacy`):** Fully declared data collection types (User ID for analytics, zero third-party tracking).
- [x] **Sign-in with Apple Requirement:** Configured according to Apple Guideline 4.8 (required because Google and SMS login are offered).
- [x] **User-Generated Content (Guideline 1.2):**
  - EULA terms requiring respectful discussion.
  - In-app 1-tap **"Report Content"** button on every review card.
  - Ability to **"Block User"** with immediate 0ms content removal.
  - 24-hour moderation response SLA via `admin.telly.app`.

### 4.2 Google Play Requirements
- [x] **Target SDK 34+ (Android 14):** Modern API level compliance.
- [x] **Data Safety Form:** Declared data encryption in transit (HTTPS/TLS 1.3) and account deletion URL (`telly.app/account/delete`).
- [x] **64-bit App Bundle (`.aab`):** Universal binary with split APK resource tables.
