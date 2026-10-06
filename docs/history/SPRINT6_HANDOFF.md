> **Frozen 2026-10-06.** Historical record of Sprints 1–6; do not edit. Work is now tracked as GitHub issues on the [Telly board](https://github.com/users/kandraos3/projects/1) — see [`docs/process/WORKFLOW.md`](../process/WORKFLOW.md) and decision [0001](../decisions/0001-issues-are-the-ticket-system.md). Open items were carried over as issues.

# Sprint 6 Handoff — State, Lessons & How to Continue

_Written 2026-10-03 for the next agent. Read `AGENTS.md` first (ticket anchoring, spec-first, 70/20/10 tests, gate before commit, roadmap accounting, atomic commits). This file is the "what happened and what's next"; the roadmap (`docs/PROJECT_ROADMAP_AND_SPRINT_PLAN.md`) is the source of truth for tickets._

---

## 1. Where things stand

| | |
|---|---|
| Sprint 6 dashboard | **18 / 32 tickets committed** (DOC-601 … FE-608). Active ticket: **FE-609** (not started). |
| Flutter gate | `dart analyze --fatal-infos` clean · `flutter test` **369 passing** |
| Database gate | `supabase test db` **155 assertions / 9 files passing** |
| Deno edge tests | 12 passing (`npx --yes deno@2 test` in `supabase/functions/tests`) |
| Git | branch `main`, ~17 commits ahead of origin, **nothing pushed** (never push unless asked). |

> **Update (FE-608 committed):** Edit Profile now runs on `EditProfileController` (`edit_profile_controller.dart`) with the `AvatarPicker` seam (`data/avatar_picker.dart`: image_picker → image_cropper 1:1 circle → upload on save). The Top 3 is picked from my canon and saved to `pinned_showcase`, and SCR-14's showcase row leads with the pinned titles (`myPinnedShowcaseProvider`). The profile `StateProvider`s became `NotifierProvider<Selection<T>, T>` (override in tests with `() => Selection(x)`). TA-02 §3.3 now documents the 0600/0700 RPCs and the `avatars` bucket. On Windows, `bash` resolves to WSL here, so run `ft.sh`'s steps directly in PowerShell (attrib -R + remove `build\unit_test_assets`, then `flutter test`). Section 1's FE-608 notes below are kept for history.

### Committed tickets (one commit each, `feat(<scope>): [ID] …`)
DOC-601, DOC-602, BE-601…605, QA-601, FE-601, FE-602, ALGO-601, ALGO-602, FE-603, FE-604, FE-605, FE-606, FE-607, FE-608.

### FE-608 — what is done in the working tree (not committed)
Spec refs: features/06, features/05 §2 §4, features/03, adjacent_systems/03.

Done:
- **Server** (with pgTAP):
  - `20261010000600_profile_lookup_and_avatars.sql`: `lookup_profile_card(handle)` (finds FRIENDS_ONLY users so you can request to follow; bio/showcase only when visible) + public `avatars` bucket, write-only-own-folder policies. Test `008`.
  - `20261010000700_squad_members_and_watchlist.sql`: `get_squad_members`, `squad_shared_watchlist` (member-gated SECURITY DEFINER; RLS alone can't serve them). Test `009`.
- **SCR-15 Friend profile**: `ProfileRepository` (`lib/features/profile/data/profile_repository.dart`), `FriendProfileController` + `TasteComparisons` (agreements/clashes/gems across both canons, never cross-canon), screen loads by handle (`/u/:handle` no longer needs `extra`), follow/unfollow/pending, friends-only card state.
- **SCR-14 header**: real user from `authControllerProvider`; fabricated defaults ("Jordan Miller", "3,120 eps", "412h") removed; Squads button added.
- **SCR-18 Graveyard**: `GraveyardRepository` ↔ `user_dropped_shows`, `GraveyardController` (dropping a ranked title removes it from the canon via `RankingRepository.remove`), `LogDroppedShowSheet` returns `DropDetails` with form state in `DropFormController`, Logging Studio "Dropped" persists then goes to SCR-18, `DropReasonTaxonomy.toDbValue/fromDbValue`.
- **SCR-17 Squads**: `SquadRepository`, `SquadsListController`, `SquadHubController` (per-canon Borda leaderboard, shared watchlist, debates tab, invite by handle for owner/admin), new `SquadsListScreen` at `/squads`, hub at `/squads/:id`. `SquadRole` gained `owner`.
- **SCR-20 Settings**: `settings_controllers.dart` (`AppPreferences` persisted to `users.preferences` incl. spec S3 notification defaults; `SubscriptionsController` loads/saves `user_streaming_subscriptions`), `settings_services.dart` (`ImageCacheService`, `CanonExportService` → CSV / Letterboxd via `share_plus`), `hapticsEnabledProvider` now derives from preferences, queue's `userSubscriptionsProvider` derives from saved subscriptions, visibility dropdown, sign-out. CSV export gained a `media_type` column (TMDB ids collide across canons).
- Packages added: `share_plus`, `image_picker`, `image_cropper` (+ `UCropActivity` in AndroidManifest), `flutter_cache_manager`, `path_provider` (direct).

**Remaining for FE-608 before committing:**
1. **Edit Profile** (`edit_profile_studio_screen.dart`, still mock + business `setState`): `image_picker` → `image_cropper` (1:1) → `ProfileRepository.uploadAvatar` → `updateProfile(avatarUrl:)`; display name/bio save; Top‑3 showcase saved to `pinned_showcase` (column is `pinned_showcase`, JSON array of `{title_id, media_type}`, max 3). Move state to a Notifier; widget tests (crop result updates preview; save success/failure). Legacy items 1203/1208.
2. `grep -rn "StateProvider\|setState(" lib/features/profile lib/features/squads` — convert any remaining *business* state (ticket task 5). `selectedCanonProvider`, `canonViewModeProvider`, `franchiseRollupProvider` in `profile_controller.dart` are still `StateProvider`s.
3. Run the gate, then update the roadmap: annotate deviations (below), run `python tool/handoff/complete_ticket.py FE-608 FE-609 "<FE-609 title>"`, **review the diff for over-flips** (it flips every Sprint 1–5 item tagged `→ remediated by \`FE-608\``; e.g. line ~1192 "1-tap download and OS share sheet" and ~1177–1181 settings items are covered, but double-check each), commit `feat(profile): [FE-608] …` including `supabase/` and `pubspec.*`/platform registrant changes.

Deviations to annotate in the FE-608 roadmap entry:
- Squads needed two new RPCs (members across `users` RLS; shared watchlist across `user_watchlist` RLS) and a `/squads` list screen (no entry point existed).
- Friend lookup needed `lookup_profile_card` (friends-only profiles were unfollowable).
- Account deletion and Terms/Privacy links intentionally left to **LEGAL-601**; biometric unlock removed until **DEV-601** (it was a fake toggle). The rows say so.
- Letterboxd export has no Year column data (local canon doesn't store release year) — note or fix via `CachedTitles.releaseDate`.

---

## 2. Remaining tickets after FE-608 (15)
FE-609 Smart Queue · FE-610 Two-to-Watch · FE-611 Show Detail (SCR-08) · FE-612 Explore (SCR-07) · DEV-601 (Sentry/PostHog/share_plus story share/local_auth — `StoryShareService` in `lib/features/sharing/data/story_share_service.dart` is the seam; it currently throws `StoryShareUnavailable`) · LEGAL-601 (deletion flow → `request_account_deletion`, legal URLs, PrivacyInfo.xcprivacy) · DEV-602 · QA-602…QA-608 (QA-608 fails if any `PendingScreen` remains — grep `PendingScreen(` in `app_router.dart`: Explore, Show Detail, Two-to-Watch fallback).

FE-609 notes: `lib/features/queue/data/streaming_availability_service.dart` still has `_mockAvailability`; real data is the `streaming-availability` edge function (BE-605). `userSubscriptionsProvider` already reads saved subscriptions.

---

## 3. Architecture you must keep consistent

- **Dual canon** everywhere: `'movie'` / `'tv'`, title key is `(id, media_type)`. Never key anything by TMDB id alone (seed grid, exports, comparisons were all fixed for this).
- **Local-first ranking**: all canon writes go through `RankingRepository` (`lib/features/ranking/data/ranking_repository.dart`) which writes Drift **and** appends a `PendingMutations` row in one transaction (`MutationKind`: `log_title`, `move`, `delete`, `duels`, `editorial`). `SyncEngine` (`lib/core/sync/sync_engine.dart`) replays FIFO via `SupabaseMutationTransport`, halts on first failure, backoff 2 s→5 min, flushes on enqueue/reconnect/resume/sign-in. Every RPC call carries `client_mutation_id` (server idempotency, invariant I‑5).
- **Drift schema v2** (`lib/core/database/database.dart`); v1 fixture at `test/fixtures/drift_schema_v1.sql`; migration test in `ranking_repository_test.dart`. Regenerate with `dart run build_runner build`.
- **Routing**: `lib/core/router/app_router.dart` + pure `auth_redirect.dart`. Shell has 4 branches + center Log action pushing `/log` (studio) → `/log/duel` → `/log/reveal`. `AppShell` keeps `canonHydrationProvider` and `syncEngineProvider` alive.
- **Riverpod only** (Notifier/AsyncNotifier/families). Repositories are interfaces with `Supabase*` impls taking an injectable `currentUserId` for tests. Business state never in `setState`; purely visual state (spoiler reveal, dialog text controllers) may stay in widgets.
- **Honest placeholders**: unbuilt screens use `PendingScreen(title, ticket)`; unbuilt services throw a named exception. Never fake success (several fakes were found and removed: fake "14% agree", fake export, fake cache size, fake deletion, fake "Jordan" header).
- **Server**: migrations `supabase/migrations/2026101000xx00_*.sql` (clean baseline + additive files); TA-02 (`docs/technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md`) is the normative contract — update it when an RPC contract changes. pgTAP in `supabase/tests/database/0NN_*.test.sql` (each test must be able to fail).

---

## 4. Environment gotchas (Windows) — these cost time

- **Read-only directories**: Windows keeps marking `build/unit_test_assets`, `.dart_tool/build/generated` and `windows|linux/flutter/ephemeral/.plugin_symlinks` read-only, which breaks `flutter test`, `build_runner` and `pub get` ("failed to delete … Access is denied"). Use **`tool/handoff/ft.sh <args>`** (bash) instead of `flutter test`; for build_runner delete `.dart_tool/build` (`rm -rf`); for pub get clear the ephemeral dir (`attrib -R … /S /D` then `rmdir /s /q`).
- **Bash heredocs** containing apostrophes sometimes fail in the tool ("unexpected EOF"): write Python edit scripts to a file and run them.
- **Local Supabase** runs in Docker on ports **643xx** (Windows reserves 54252–54351). `supabase db reset` then `supabase test db`. Storage container may be stopped; the `storage` schema still exists. `storage.buckets` has its own RLS — assert on it as the owner.
- **Deno** via `npx --yes deno@2` (Docker Hub pulls failed).
- **Widget tests**: use an 800-wide surface (the FlutterTest font is 1em/glyph; 390 px causes fake overflows). A second `pumpWidget` reuses the same `ProviderScope` → cached providers; use separate tests. `dart:io` file futures don't complete in fake async → unit-test file I/O separately. `CachedNetworkImage` never settles in tests → override `posterNetworkImagesProvider` to `false`. Screens reading `authControllerProvider` need `authRepositoryProvider.overrideWithValue(FakeAuthRepository(...))`.
- **Test fakes** live in `test/fakes/` (auth, title, social, profile, graveyard, onboarding); helpers in `test/helpers/` (`router_harness.dart` renders other routes as `route:<uri>`, `canon_seed.dart`).

## 5. Roadmap tooling
- `tool/handoff/complete_ticket.py TICKET NEXT "next title" [keep-open-substr…]` — ticks the ticket's tasks, flips legacy items tagged `→ remediated by \`TICKET\``, advances the dashboard. **Always review `git diff docs/PROJECT_ROADMAP_AND_SPRINT_PLAN.md`** and annotate deviations inline as `*(…)*` rather than silently ticking.
- The dashboard title argument must match the next ticket's real title (check `#### \`ID\`` heading).

## 6. Human prerequisites (unchanged)
Copy `env/example.json` → `env/dev.json` (anon key from `supabase status`), run with `--dart-define-from-file=env/dev.json`; add `app.telly.mobile://login-callback` to Supabase Auth redirect URLs; push a branch to verify CI; set TMDB/Watchmode secrets for edge functions.
