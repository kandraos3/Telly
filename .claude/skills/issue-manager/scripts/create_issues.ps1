# Batch script to create all 38 issues in kandraos3/Telly using gh CLI.
param(
    [string]$Repo = "kandraos3/Telly"
)

$issues = @(
    @{
        Title = "[FE-AUTH-01] AuthScreen: Implement Official Telly Logo & Dynamic Poster Backdrop"
        Labels = "enhancement,design,area:auth,p2-medium,status:ready"
        Body = @"
### Summary
The startup authentication screen is currently plain black with a placeholder TV logo and text.

### Context & Screen Location
- **Screen**: `AuthScreen (SCR-01)`
- **File**: `lib/features/auth/presentation/screens/auth_screen.dart`
- **Spec Reference**: `docs/design_system/01_DESIGN_PHILOSOPHY_AND_STYLE_GUIDE.md` §2

### Current Behavior (As-Is)
The login screen has an unadorned black background and a generic TV icon / text logo.

### Proposed Solution (To-Be)
- Replace placeholder text/icon with the official bespoke vector Telly logo.
- Implement an ambient poster grid mosaic background with dark gradient scrim overlay (`#08090C`, 80% opacity) meeting WCAG AA contrast for text.

### Acceptance Criteria
- [ ] Official vector Telly logo renders crisply on all screen densities.
- [ ] Startup screen displays subtle ambient poster mosaic with dark scrim overlay.
"@
    },
    @{
        Title = "[FE-AUTH-02] AuthScreen: Hook Up 'Continue with Apple' and 'Continue with Google' OAuth Flows"
        Labels = "feature,area:auth,p1-high,status:ready"
        Body = @"
### Summary
Continue with Apple and Continue with Google social login buttons exist in the UI but are not wired up to OAuth providers.

### Context & Screen Location
- **Screen**: `AuthScreen (SCR-01)`
- **File**: `lib/features/auth/presentation/screens/auth_screen.dart`, `lib/features/auth/data/auth_repository.dart`
- **Spec Reference**: `docs/adjacent_systems/02_AUTHENTICATION_AND_USER_MANAGEMENT_SPEC.md`

### Current Behavior (As-Is)
Clicking Apple or Google sign-in buttons does nothing or logs a placeholder message.

### Proposed Solution (To-Be)
- Hook up Supabase OAuth via `supabase.auth.signInWithOAuth(OAuthProvider.apple)` and `OAuthProvider.google`.
- Configure deep-link redirect handling into GoRouter.

### Acceptance Criteria
- [ ] Tapping Continue with Apple opens Apple OAuth flow.
- [ ] Tapping Continue with Google opens Google account chooser.
- [ ] Successful OAuth redirects to user handle reservation / feed shell.
"@
    },
    @{
        Title = "[FE-AUTH-03] AuthScreen: Implement 'Forgot Password' & Email Password Reset Flow"
        Labels = "feature,area:auth,p2-medium,status:ready"
        Body = @"
### Summary
Users logging in with email have no way to recover or reset forgotten passwords.

### Context & Screen Location
- **Screen**: `AuthScreen (SCR-01)`
- **File**: `lib/features/auth/presentation/screens/auth_screen.dart`, `lib/features/auth/data/auth_repository.dart`
- **Spec Reference**: `docs/adjacent_systems/02_AUTHENTICATION_AND_USER_MANAGEMENT_SPEC.md`

### Current Behavior (As-Is)
Email sign-in lacks a 'Forgot Password' option.

### Proposed Solution (To-Be)
- Add a 'Forgot Password?' action adjacent to password input.
- Present a modal bottom sheet requesting the user's email address and calling `authRepository.sendPasswordResetEmail()`.
- Display confirmation banner and route password recovery deep links.

### Acceptance Criteria
- [ ] 'Forgot Password?' opens password reset sheet.
- [ ] Submitting email triggers Supabase password reset email.
"@
    },
    @{
        Title = "[FE-AUTH-04] AuthScreen: Hook Up In-App Terms of Service & Privacy Policy Navigation"
        Labels = "bug,area:auth,p2-medium,status:ready"
        Body = @"
### Summary
Terms of Service and Privacy Policy agreement spans on the login screen do not navigate or point to dead web links.

### Context & Screen Location
- **Screen**: `AuthScreen (SCR-01)`
- **File**: `lib/features/auth/presentation/screens/auth_screen.dart`
- **Spec Reference**: `docs/legal/TERMS_OF_SERVICE.md`, `docs/legal/PRIVACY_POLICY.md`

### Current Behavior (As-Is)
Agreement text spans are either unclickable or point to unavailable `telly.app` URLs.

### Proposed Solution (To-Be)
- Wire clickable text spans to open an in-app bottom sheet / viewer rendering bundled markdown docs (`TERMS_OF_SERVICE.md`, `PRIVACY_POLICY.md`).

### Acceptance Criteria
- [ ] Tapping Terms of Service opens in-app legal viewer.
- [ ] Tapping Privacy Policy opens in-app legal viewer.
"@
    },
    @{
        Title = "[FE-LOG-01] LoggingStudio: Make Director & Standout Performance Fields Empty and Optional"
        Labels = "enhancement,area:logging,p2-medium,status:ready"
        Body = @"
### Summary
Logging a new movie or TV show auto-populates or enforces Director and Standout Performance fields.

### Context & Screen Location
- **Screen**: `LoggingStudioScreen (SCR-09)`
- **File**: `lib/features/logging/presentation/screens/logging_studio_screen.dart`
- **Spec Reference**: `docs/features/01_LOGGING_FLOW_AND_STUDIO_SPEC.md`

### Current Behavior (As-Is)
Fields are pre-populated or always expanded, cluttering the logging process.

### Proposed Solution (To-Be)
- Make Director and Standout Performance empty by default.
- Keep them completely optional with clear placeholder text (e.g. *'Optional — e.g. Denis Villeneuve'*).

### Acceptance Criteria
- [ ] Director and Standout Performance inputs are blank on load.
- [ ] Logging a title without filling these fields succeeds seamlessly.
"@
    },
    @{
        Title = "[FE-LOG-02] LoggingStudio Redesign: Implement Star Rating, Streamlined Layout & Feed Broadcast Checkbox"
        Labels = "enhancement,design,area:logging,p1-high,status:ready"
        Body = @"
### Summary
The logging screen is crowded, lacks a granular star rating selector, and forces broadcast to the feed via a combined button.

### Context & Screen Location
- **Screen**: `LoggingStudioScreen (SCR-09)`
- **File**: `lib/features/logging/presentation/screens/logging_studio_screen.dart`
- **Spec Reference**: `docs/features/01_LOGGING_FLOW_AND_STUDIO_SPEC.md`

### Current Behavior (As-Is)
Button says 'Publish to Canon and broadcast feed'. Only broad sentiment brackets are available.

### Proposed Solution (To-Be)
- Add an interactive 5-star (half-star increments) or 10-star rating selector for granular initial sentiment.
- Simplify primary action button to 'Publish'.
- Add explicit `[x] Broadcast to Feed` checkbox (default checked) allowing users to log privately.
- Increase layout breathing room and declutter input groups.

### Acceptance Criteria
- [ ] Star rating component allows selecting half-star / star rating values.
- [ ] Primary button labeled 'Publish'.
- [ ] Checkbox allows opting out of broadcasting log to the feed.
"@
    },
    @{
        Title = "[FE-ALGO-01] DuelFlow: Enforce Minimum Verification Duel Threshold for Placement Stability"
        Labels = "enhancement,area:ranking,p2-medium,status:ready"
        Body = @"
### Summary
Titles placed near the top or bottom of a list can complete after only 1 duel, feeling abrupt and unverified.

### Context & Screen Location
- **Screen**: `LogDuelScreen (SCR-10)`
- **File**: `lib/features/ranking/domain/binary_search_sorter.dart`, `lib/features/logging/presentation/screens/log_flow_screens.dart`
- **Spec Reference**: `docs/features/02_BINARY_SEARCH_TOURNAMENT_SPEC.md`

### Current Behavior (As-Is)
Binary insertion sort terminates immediately upon boundary reach without adjacent verification.

### Proposed Solution (To-Be)
- Implement a minimum duel guarantee (at least 2-3 duels) when a candidate reaches top rank (#1) or bottom rank.
- Duel candidate against adjacent neighbor before finalizing rank commitment.

### Acceptance Criteria
- [ ] High-rank candidate undergoes at least 2 comparison duels against top titles.
- [ ] Placement stability verified prior to committing ranking.
"@
    },
    @{
        Title = "[FE-GESTURE-01] DuelSwipe: Fix Dual-Card and VS Badge Simultaneous Drag Glitch"
        Labels = "bug,area:ranking,p1-high,status:ready"
        Body = @"
### Summary
Swiping up or down drags both contender cards and the 'VS' badge simultaneously as one static block.

### Context & Screen Location
- **Screen**: `LogDuelScreen (SCR-10)`
- **File**: `lib/features/logging/presentation/screens/log_flow_screens.dart`
- **Spec Reference**: `docs/design_system/01_DESIGN_PHILOSOPHY_AND_STYLE_GUIDE.md` §6

### Current Behavior (As-Is)
Both contender cards translate together along with the VS badge during drag gestures.

### Proposed Solution (To-Be)
- Decouple card gesture listeners.
- Dragging upward animates only the top card with Phosphor Lime border glow; bottom card stays anchored with subtle dimming.
- The 'VS' badge remains fixed in viewport center during gestures.

### Acceptance Criteria
- [ ] Swiping one card animates only that contender.
- [ ] The 'VS' badge remains anchored in viewport center.
"@
    },
    @{
        Title = "[FE-SHARE-01] LogReveal: Hook Up Instagram Story Share & 5-Item Leaderboard Ranking Snippet"
        Labels = "enhancement,area:logging,p2-medium,status:ready"
        Body = @"
### Summary
'Share to Instagram Story' button is unhooked. Reveal screen only states 'Ahead of X, behind Y' without visual ranking context.

### Context & Screen Location
- **Screen**: `LogRevealScreen (SCR-12)`
- **File**: `lib/features/logging/presentation/screens/log_flow_screens.dart`, `lib/features/sharing/data/story_share_service.dart`
- **Spec Reference**: `docs/features/05_STORY_SHARING_AND_VIRALITY_SPEC.md`

### Current Behavior (As-Is)
Instagram share button is non-functional. Minimal ranking context is shown.

### Proposed Solution (To-Be)
- Hook up `SharePlusStoryShareService` to generate a 9:16 story image for system share sheet.
- Render a 5-item leaderboard snippet (+2 above, newly ranked title highlighted in lime, -2 below) with posters and scores.

### Acceptance Criteria
- [ ] Tapping Instagram Share opens system share sheet with 9:16 story asset.
- [ ] 5-item leaderboard snippet displays ranking context.
"@
    },
    @{
        Title = "[FE-DETAIL-01] TitleDetail: Add Grade Tooltip & Fix '+ Queue' Redundant Labeling"
        Labels = "enhancement,area:title-detail,p2-medium,status:ready"
        Body = @"
### Summary
Grade (e.g. 8.0) and tier lack an explanation of how they are calculated. Queue button has a plus icon and says '+ Queue' ('two pluses').

### Context & Screen Location
- **Screen**: `ShowDetailScreen (SCR-08)`
- **File**: `lib/features/title_detail/presentation/screens/show_detail_screen.dart`
- **Spec Reference**: `docs/features/08_TITLE_DETAIL_PAGE_SPEC.md`

### Current Behavior (As-Is)
No explanation for percentile grade. Queue button shows double plus.

### Proposed Solution (To-Be)
- Add an info (i) tooltip next to Grade explaining percentile score calculation and tier bands.
- Change button label to 'Add to Queue' with single plus icon (and 'In Queue' with checkmark when saved).

### Acceptance Criteria
- [ ] Tooltip explains grade calculation and tier system.
- [ ] Queue button displays single plus and reads 'Add to Queue'.
"@
    },
    @{
        Title = "[FE-DETAIL-02] TitleDetail: Replace Hardcoded Dueling/Survival Placeholders with Live Data or Clean Empty State"
        Labels = "bug,area:title-detail,p2-medium,status:ready"
        Body = @"
### Summary
ShowDetailScreen displays hardcoded placeholder stats ('85% community survival rate', '82% duel win rate, 1477 matches', static tier chart).

### Context & Screen Location
- **Screen**: `ShowDetailScreen (SCR-08)`
- **File**: `lib/features/title_detail/presentation/screens/show_detail_screen.dart`
- **Spec Reference**: `docs/features/08_TITLE_DETAIL_PAGE_SPEC.md`

### Current Behavior (As-Is)
Displays fabricated numbers for all titles.

### Proposed Solution (To-Be)
- Fetch real aggregated duel stats from Supabase RPC `get_title_duel_stats(title_id)`.
- If no community duels exist yet, show an honest empty state: *'Not enough duel data yet. Duel this title to establish its record!'*
- Clarify survival rate as *'Completed all seasons'* and hide for standalone movies.

### Acceptance Criteria
- [ ] Hardcoded 82% win rate and 1477 matches removed.
- [ ] Live stats shown when available; informative empty state shown when unranked.
"@
    },
    @{
        Title = "[BE-DETAIL-01] MediaMetadata: Implement Live TMDB Cast & Crew Fetching and Real Streaming Availability"
        Labels = "feature,area:title-detail,p1-high,status:ready"
        Body = @"
### Summary
Cast and crew section shows 'Cast and crew information syncing from TMDB' indefinitely. Streaming provider section frequently shows 'No streaming services currently available'.

### Context & Screen Location
- **Screen**: `ShowDetailScreen (SCR-08)`
- **File**: `lib/features/title_detail/presentation/screens/show_detail_screen.dart`, `lib/features/discovery/data/discovery_repository.dart`
- **Spec Reference**: `docs/technical_architecture/04_TMDB_INGESTION_AND_CATALOG_SYNC.md`

### Current Behavior (As-Is)
Cast and crew never finish syncing; watch providers missing.

### Proposed Solution (To-Be)
- Wire TMDB `/movie/{id}/credits` and `/tv/{id}/aggregate_credits` to render real cast avatars and director.
- Query TMDB `/watch/providers` via Supabase Edge Function to show real JustWatch streaming badges (Netflix, Max, Apple TV+, etc.).

### Acceptance Criteria
- [ ] Cast cards render actor photos and character names.
- [ ] Valid streaming provider badges render for licensed titles.
"@
    },
    @{
        Title = "[FE-DETAIL-03] Navigation: Wire Up 'Co-watch' Button to Active Two-To-Watch Hub (SCR-16) and Support Backstack History"
        Labels = "bug,area:title-detail,p1-high,status:ready"
        Body = @"
### Summary
Clicking 'Co-watch' on ShowDetailScreen navigates to an obsolete placeholder saying 'Two-to-watch is not built yet tracked by FE-610' even though SCR-16 exists. Navigating back from detail page does not always preserve scroll position.

### Context & Screen Location
- **Screen**: `ShowDetailScreen (SCR-08)`
- **File**: `lib/features/title_detail/presentation/screens/show_detail_screen.dart`, `lib/core/router/app_router.dart`
- **Spec Reference**: `docs/features/08_TITLE_DETAIL_PAGE_SPEC.md`

### Current Behavior (As-Is)
Routes to placeholder stub screen instead of active TwoToWatchScreen.

### Proposed Solution (To-Be)
- Route Co-watch button to `/cowatch?titleId={id}` pre-populating title in `TwoToWatchScreen`.
- Ensure GoRouter uses proper push navigation so back button preserves scroll state.

### Acceptance Criteria
- [ ] Tapping Co-watch opens `TwoToWatchScreen` with title pre-selected.
- [ ] Hardware/app bar back button returns user to previous screen at preserved scroll position.
"@
    },
    @{
        Title = "[FE-PROFILE-01] Profile: Rename 'Canon' to 'Movies' / 'TV Shows', Standardize Tab Order & Enable Swiping"
        Labels = "enhancement,design,area:profile,p1-high,status:ready"
        Body = @"
### Summary
'Canon' terminology is unfamiliar to casual users. Tab order differs across screens. Users cannot swipe between tabs.

### Context & Screen Location
- **Screen**: `DualCanonProfileScreen (SCR-14)`
- **File**: `lib/features/profile/presentation/screens/dual_canon_profile_screen.dart`
- **Spec Reference**: `docs/features/03_PROFILE_AND_DUAL_CANON_SPEC.md`

### Current Behavior (As-Is)
Tabs are named 'Movie Canon' and 'Series & Anime'. User must tap tabs; swipe gesture is unhandled.

### Proposed Solution (To-Be)
- Rename tab headers to 'Movies' and 'TV Shows' (with subtle subtitle *'Includes anime'*).
- Standardize ordering app-wide: Movies on Left, TV Shows on Right.
- Wrap content in `TabBarView` to enable smooth horizontal swiping between tabs.

### Acceptance Criteria
- [ ] Tabs labeled 'Movies' (left) and 'TV Shows' (right).
- [ ] Horizontal swipe transitions between Movies and TV Shows.
"@
    },
    @{
        Title = "[FE-PROFILE-02] Profile: Route Avatar Tap to Profile Details, Enable Profile Share & Redesign Top Bar"
        Labels = "enhancement,area:profile,p2-medium,status:ready"
        Body = @"
### Summary
Tapping profile photo does not navigate to profile editing. Share button in top right is non-functional. Top bar logo looks dated.

### Context & Screen Location
- **Screen**: `DualCanonProfileScreen (SCR-14)`
- **File**: `lib/features/profile/presentation/screens/dual_canon_profile_screen.dart`
- **Spec Reference**: `docs/features/03_PROFILE_AND_DUAL_CANON_SPEC.md`

### Current Behavior (As-Is)
Profile avatar is not interactive; share button does nothing.

### Proposed Solution (To-Be)
- Conceptualize screen as 'Profile'.
- Tapping user avatar navigates to `EditProfileStudioScreen`.
- Hook up Share button to generate public profile share URL.
- Redesign top bar with sleek typography and remove old TV icon.

### Acceptance Criteria
- [ ] Tapping avatar opens Edit Profile.
- [ ] Tapping Share triggers native share sheet.
- [ ] Top bar redesigned with clean branding.
"@
    },
    @{
        Title = "[FE-PROFILE-03] Profile: Expand Overview Stats Header with Filterable Hours Watched, Genre Affinity & Director Counts"
        Labels = "feature,area:profile,p2-medium,status:ready"
        Body = @"
### Summary
Top profile summary only displays '13 movies, 9 series' without rich viewing insights.

### Context & Screen Location
- **Screen**: `DualCanonProfileScreen (SCR-14)`
- **File**: `lib/features/profile/presentation/screens/dual_canon_profile_screen.dart`
- **Spec Reference**: `docs/features/03_PROFILE_AND_DUAL_CANON_SPEC.md`

### Current Behavior (As-Is)
Minimal title count only.

### Proposed Solution (To-Be)
- Expand stats card into an aggregated dashboard: total hours watched, top genre (with percentage), top director (with title count), and total titles.
- Dynamically recalculate and filter stats when switching between Movies and TV Shows.

### Acceptance Criteria
- [ ] Displays hours watched, top genre, and top director.
- [ ] Stats adapt dynamically when switching between Movies and TV Shows tabs.
"@
    },
    @{
        Title = "[FE-CANON-01] Canon: Add 'Delete Title' Action and Move Rollup Toggle to Overflow Options Sheet"
        Labels = "enhancement,area:profile,p1-high,status:ready"
        Body = @"
### Summary
Users cannot delete an entry from their list. The 'Franchise Rollup' toggle is excessively prominent on the main screen.

### Context & Screen Location
- **Screen**: `DualCanonProfileScreen (SCR-14)`
- **File**: `lib/features/profile/presentation/screens/dual_canon_profile_screen.dart`
- **Spec Reference**: `docs/features/03_PROFILE_AND_DUAL_CANON_SPEC.md`

### Current Behavior (As-Is)
No delete option available. Rollup switch occupies prime header space.

### Proposed Solution (To-Be)
- Add swipe-to-delete or context menu action ('Remove from List') with confirmation dialog.
- Move Rollup toggle into a 3-dots (⋮) View Options sheet.

### Acceptance Criteria
- [ ] Users can delete any ranked title with immediate rank recalculation.
- [ ] Rollup toggle relocated to options sheet.
"@
    },
    @{
        Title = "[FE-CANON-02] Canon: Replace 3x3 Grid Limit with Full Scrollable Poster Grid"
        Labels = "enhancement,area:profile,p2-medium,status:ready"
        Body = @"
### Summary
The poster grid view is artificially capped at a 3x3 matrix (9 titles only).

### Context & Screen Location
- **Screen**: `DualCanonProfileScreen (SCR-14)`
- **File**: `lib/features/profile/presentation/screens/dual_canon_profile_screen.dart`
- **Spec Reference**: `docs/features/03_PROFILE_AND_DUAL_CANON_SPEC.md`

### Current Behavior (As-Is)
Only 9 items displayed in 3x3 grid tab.

### Proposed Solution (To-Be)
- Upgrade grid tab into an infinite scrollable 3-column poster grid displaying all ranked titles in order with rank badges.

### Acceptance Criteria
- [ ] Grid view scrolls through all user titles beyond 9 items.
- [ ] Each poster displays rank badge overlay.
"@
    },
    @{
        Title = "[FE-ALGO-02] RankingEngine: Remove Arbitrary Manual Drag-and-Drop Re-Ranking"
        Labels = "enhancement,area:ranking,p1-high,status:ready"
        Body = @"
### Summary
Manual drag-and-drop reordering breaks the mathematical Elo/TrueSkill and binary tournament sort model.

### Context & Screen Location
- **Screen**: `DualCanonProfileScreen (SCR-14)`
- **File**: `lib/features/profile/presentation/screens/dual_canon_profile_screen.dart`
- **Spec Reference**: `docs/features/02_BINARY_SEARCH_TOURNAMENT_SPEC.md`

### Current Behavior (As-Is)
List items have drag handles allowing arbitrary manual reordering.

### Proposed Solution (To-Be)
- Remove arbitrary drag-and-drop re-sorting from the list.
- Provide a 'Re-duel Title' action that triggers 2-3 targeted comparison duels to organically recalibrate rank.

### Acceptance Criteria
- [ ] Manual drag handles removed from list view.
- [ ] 'Re-duel' option recalibrates title position through pairwise match-ups.
"@
    },
    @{
        Title = "[ALGO-SCORE-01] Scoring: Decouple Lower Ranks from 'Dropped/DNF' and Smooth Score Distribution"
        Labels = "bug,area:ranking,p1-high,status:ready"
        Body = @"
### Summary
Titles ranked lower in a list receive harsh scores (1.0-2.0) and are automatically tagged as 'Dropped / DNF' even when fully completed and liked.

### Context & Screen Location
- **Screen**: `DualCanonProfileScreen (SCR-14)`
- **File**: `lib/features/ranking/domain/percentile_score_calculator.dart`
- **Spec Reference**: `docs/features/02_BINARY_SEARCH_TOURNAMENT_SPEC.md` §3

### Current Behavior (As-Is)
Lower-ranked completed titles get tagged as Dropped/DNF and crushed below 2.0.

### Proposed Solution (To-Be)
- Recalibrate percentile curve so completed titles occupy sensible score bands (e.g. 6.0-8.5 for typical watched titles; scores < 5.0 reserved strictly for disliked titles).
- Restrict 'Dropped / DNF' tier strictly to titles explicitly marked abandoned in logging studio, never by rank order alone.

### Acceptance Criteria
- [ ] Completed titles never receive 'Dropped / DNF' badge unless explicitly flagged by user.
- [ ] Score distribution curve smoothed to prevent artificial compression.
"@
    },
    @{
        Title = "[FE-EXPLORE-01] Explore: Unify Header to 'Explore', Hook Up Search Icon & Reset State on Tab Return"
        Labels = "bug,enhancement,area:explore,p2-medium,status:ready"
        Body = @"
### Summary
Bottom nav says 'Explore' while top header says 'Discover'. Top-bar search icon is unhooked. Stale search text remains when returning to tab.

### Context & Screen Location
- **Screen**: `ExploreDiscoverScreen (SCR-07)`
- **File**: `lib/features/discovery/presentation/screens/explore_discover_screen.dart`, `lib/core/widgets/telly_app_bar.dart`
- **Spec Reference**: `docs/features/07_EXPLORE_AND_DISCOVER_SPEC.md`

### Current Behavior (As-Is)
Inconsistent title; unhooked search icon; sticky search state on tab switch.

### Proposed Solution (To-Be)
- Unify header title to 'Explore'.
- Hook up top-bar search icon to focus the search bar.
- Reset search query and filter chips when navigating back to Explore tab.

### Acceptance Criteria
- [ ] Header reads 'Explore'.
- [ ] Top bar search icon focuses search input.
- [ ] Re-entering Explore resets search query to default state.
"@
    },
    @{
        Title = "[FE-EXPLORE-02] Explore: Fix Truncated Scroll Behavior for Curated Canons Bottom Sheet"
        Labels = "bug,area:explore,p1-high,status:ready"
        Body = @"
### Summary
Tapping a Curated Canon opens a sheet covering only ~25% of screen height at the bottom with broken scrolling that cuts off titles.

### Context & Screen Location
- **Screen**: `ExploreDiscoverScreen (SCR-07)`
- **File**: `lib/features/discovery/presentation/screens/explore_discover_screen.dart`
- **Spec Reference**: `docs/features/07_EXPLORE_AND_DISCOVER_SPEC.md`

### Current Behavior (As-Is)
Modal covers only 25% of screen; internal scroll does not reveal all titles cleanly.

### Proposed Solution (To-Be)
- Replace fixed sheet with a `DraggableScrollableSheet` (initial size 0.85, max 1.0) or dedicated `CuratedCanonDetailScreen`.
- Ensure all featured titles scroll smoothly with full poster cards.

### Acceptance Criteria
- [ ] Curated Canon opens full/expandable view.
- [ ] All titles in the curated canon are scrollable and clickable.
"@
    },
    @{
        Title = "[FE-EXPLORE-03] Discovery: Add 'Recommended for You' Carousel & Search Zero-State Recommendations"
        Labels = "feature,area:explore,p1-high,status:ready"
        Body = @"
### Summary
Explore lacks personalized recommendations. Tapping the search bar shows an empty screen until typing begins.

### Context & Screen Location
- **Screen**: `ExploreDiscoverScreen (SCR-07)`
- **File**: `lib/features/discovery/presentation/screens/explore_discover_screen.dart`
- **Spec Reference**: `docs/features/07_EXPLORE_AND_DISCOVER_SPEC.md`

### Current Behavior (As-Is)
No personalized recommendations section; search zero-state is blank.

### Proposed Solution (To-Be)
- Add a 'Recommended for You' carousel based on user top-ranked titles and genre affinities.
- Display trending/suggested titles and recent searches when search input is focused before typing.

### Acceptance Criteria
- [ ] 'Recommended for You' carousel displays on Explore screen.
- [ ] Focusing search input immediately displays trending/suggested titles.
"@
    },
    @{
        Title = "[FE-SQUADS-01] Squads: Surface Squads on Main Navigation & Implement Delete/Leave Squad Actions"
        Labels = "enhancement,area:squads,p1-high,status:ready"
        Body = @"
### Summary
Squads are buried in a secondary side tab. There is no way to delete a created squad or leave a squad.

### Context & Screen Location
- **Screen**: `SquadsListScreen (SCR-17a)`, `SquadHubScreen (SCR-17b)`
- **File**: `lib/features/squads/presentation/screens/squads_list_screen.dart`, `lib/features/squads/presentation/screens/squad_hub_screen.dart`
- **Spec Reference**: `docs/features/04_SQUADS_AND_CONSENSUS_CANON_SPEC.md`

### Current Behavior (As-Is)
Squads lack visibility; squads cannot be deleted or exited.

### Proposed Solution (To-Be)
- Elevate Squads access in main navigation or profile hub.
- Add 'Delete Squad' action for owners and 'Leave Squad' action for members with confirmation dialogs.

### Acceptance Criteria
- [ ] Owner can permanently delete a squad.
- [ ] Member can leave a squad.
- [ ] Squads entry point elevated in navigation.
"@
    },
    @{
        Title = "[FE-SQUADS-02] Squads: Add Invite by Email, Live Handle Validation & Standardize Tab Ordering"
        Labels = "enhancement,area:squads,p2-medium,status:ready"
        Body = @"
### Summary
Invites only support handles (not email). Invalid handles can be submitted without real-time validation. Tab order has TV shows on left and movies on right.

### Context & Screen Location
- **Screen**: `SquadHubScreen (SCR-17b)`
- **File**: `lib/features/squads/presentation/screens/squad_hub_screen.dart`
- **Spec Reference**: `docs/features/04_SQUADS_AND_CONSENSUS_CANON_SPEC.md`

### Current Behavior (As-Is)
Handle-only invite; no live validation; inverted tab order.

### Proposed Solution (To-Be)
- Support inviting by either handle or email address in invite modal.
- Live validate handle/email existence with visual indicator (checkmark or error message).
- Standardize tab order to Movies on Left, TV Shows on Right.

### Acceptance Criteria
- [ ] Invite modal supports handle and email with live validation.
- [ ] Squad Hub tabs show Movies on the left and TV Shows on the right.
"@
    },
    @{
        Title = "[FE-COWATCH-01] TwoToWatch: Streamline IA, Fix Quick Swipe Missing Posters & Resolve Mock Title Data"
        Labels = "bug,design,area:co-watch,p1-high,status:ready"
        Body = @"
### Summary
Screen feels overwhelming. Quick Swipe Duel displays blank/missing posters. Clicking picks opens mock title 'Show Detail (tv/201)' with hardcoded 8.0 score.

### Context & Screen Location
- **Screen**: `TwoToWatchScreen (SCR-16)`
- **File**: `lib/features/cowatch/presentation/screens/two_to_watch_screen.dart`
- **Spec Reference**: `docs/features/06_TWO_TO_WATCH_CO_WATCHING_SPEC.md`

### Current Behavior (As-Is)
Overcrowded layout; posters missing in quick duel; mock title bugs when tapping recommendations.

### Proposed Solution (To-Be)
- Streamline layout into clean 3-step card flow (Friend -> Vibe -> Match).
- Fix poster URLs in Quick Swipe duel contender cards.
- Wire real TMDB titles and scores into recommendations.

### Acceptance Criteria
- [ ] Quick Swipe duel renders posters correctly.
- [ ] Tapping pick opens real Title Detail screen with accurate poster, title, and synopsis.
"@
    },
    @{
        Title = "[FE-COWATCH-02] CoWatch: Gate 'Top Picks' Behind Selections, Add Dynamic Vibe Filtering & Watchlist Button"
        Labels = "enhancement,area:co-watch,p2-medium,status:ready"
        Body = @"
### Summary
'Top Picks for Tonight' shows prematurely before selecting friend/vibe. Changing vibe chips does not update recommendations. Cards lack an 'Add to Watchlist' button.

### Context & Screen Location
- **Screen**: `TwoToWatchScreen (SCR-16)`
- **File**: `lib/features/cowatch/presentation/screens/two_to_watch_screen.dart`
- **Spec Reference**: `docs/features/06_TWO_TO_WATCH_CO_WATCHING_SPEC.md`

### Current Behavior (As-Is)
Recommendations show without selections; changing vibes has no effect; no quick add button.

### Proposed Solution (To-Be)
- Hide 'Top Picks for Tonight' until a friend and vibe filter are selected.
- Dynamically re-filter picks when vibe chips change.
- Add an 'Add to Watchlist' button on each recommendation card.

### Acceptance Criteria
- [ ] Top Picks reveals only after friend and vibe selection.
- [ ] Vibe selection updates pick results dynamically.
- [ ] 'Add to Watchlist' button adds title to user queue.
"@
    },
    @{
        Title = "[FE-LISTS-01] SmartQueue: Implement Custom User Lists, Privacy Controls & Shared Friend Lists"
        Labels = "feature,design,area:queue,p1-high,status:ready"
        Body = @"
### Summary
Queue is a single flat list. Users cannot create multiple custom lists, share lists with friends, or browse friends' curated lists.

### Context & Screen Location
- **Screen**: `SmartQueueScreen (SCR-13)`
- **File**: `lib/features/queue/presentation/screens/smart_queue_screen.dart`
- **Spec Reference**: `docs/features/09_SMART_QUEUE_AND_RADAR_SPEC.md`

### Current Behavior (As-Is)
Single flat watchlist without custom list support.

### Proposed Solution (To-Be)
- Overhaul Queue into a comprehensive 'Lists & Queue' hub:
  - Default Watchlist plus custom user lists (e.g. 'Criterion Must-Sees', 'Spooky Season').
  - Summary cards showing counts (movies vs shows) and privacy badge (Public / Private).
  - List Detail view showing titles, collaborators, and 'Share List' link.
  - Ability to browse and save friends' shared lists.

### Acceptance Criteria
- [ ] Users can create named custom lists with public/private toggle.
- [ ] List Detail screen displays titles with reorder and delete options.
- [ ] Users can share lists with friends via deep link.
"@
    },
    @{
        Title = "[FE-FEED-01] Feed: Compact Bookmark Icon for 'Want to Watch' and Modernized Reaction Emoji Bar"
        Labels = "enhancement,design,area:feed,p2-medium,status:ready"
        Body = @"
### Summary
'Want to Watch' button is too large/prominent on feed cards. Current emojis (fire, mind-blown, trash) look childish/unprofessional.

### Context & Screen Location
- **Screen**: `ActivityFeedScreen (SCR-05)`
- **File**: `lib/features/feed/presentation/widgets/feed_activity_card.dart`
- **Spec Reference**: `docs/features/10_SOCIAL_ACTIVITY_FEED_SPEC.md`

### Current Behavior (As-Is)
Large 'Want to Watch' banner button; limited/childish emoji reactions.

### Proposed Solution (To-Be)
- Replace large 'Want to Watch' banner with a sleek bookmark icon in the top right corner of the card.
- Redesign reaction bar: use sleek presets (Cinema, Kudos, Stunned, Heartbreak, Masterpiece) plus an emoji picker (+).

### Acceptance Criteria
- [ ] Bookmark icon replaces large 'Want to Watch' button.
- [ ] Reaction bar displays refined presets plus an expandable emoji picker.
"@
    },
    @{
        Title = "[FE-FEED-02] Feed: Introduce Algorithmic Recommendation Cards Between Feed Posts"
        Labels = "feature,area:feed,p2-medium,status:ready"
        Body = @"
### Summary
Feed contains only social logs; missing algorithmic discovery opportunities.

### Context & Screen Location
- **Screen**: `ActivityFeedScreen (SCR-05)`
- **File**: `lib/features/feed/presentation/screens/activity_feed_screen.dart`
- **Spec Reference**: `docs/features/10_SOCIAL_ACTIVITY_FEED_SPEC.md`

### Current Behavior (As-Is)
Feed is purely chronological social activity.

### Proposed Solution (To-Be)
- Periodically insert algorithmic recommendation cards (e.g. every 6-8 posts):
  - *'Because you loved Succession: Industry (HBO) is streaming on Max'*
  - Includes quick 'Add to Queue' and 'Rate / Rank' buttons.

### Acceptance Criteria
- [ ] Recommendation cards periodically appear in activity feed.
- [ ] Card provides reason for recommendation and direct Add to Queue action.
"@
    },
    @{
        Title = "[FE-SOCIAL-01] Profile: Disallow Self-Following in Explore/Social and Route Self-Clicks to Own Profile"
        Labels = "bug,area:profile,p1-high,status:ready"
        Body = @"
### Summary
Searching for own username in Explore opens FriendProfileScreen where user can follow themselves.

### Context & Screen Location
- **Screen**: `FriendProfileScreen (SCR-15)`
- **File**: `lib/features/profile/presentation/screens/friend_profile_screen.dart`
- **Spec Reference**: `docs/features/03_PROFILE_AND_DUAL_CANON_SPEC.md`

### Current Behavior (As-Is)
Users can open their own profile as a friend and tap 'Follow'.

### Proposed Solution (To-Be)
- If target user ID matches current user ID:
  - Route directly to `DualCanonProfileScreen` (user's own profile).
  - If viewed as public preview, replace 'Follow' button with 'Edit Profile'.

### Acceptance Criteria
- [ ] Users cannot follow themselves.
- [ ] Clicking own profile navigates to own editable profile.
"@
    },
    @{
        Title = "[ALGO-TASTE-01] TasteMatch: Fix Self-Comparison 50% Anomaly and Clarify Taste Breakdown Metrics"
        Labels = "bug,area:ranking,p1-high,status:ready"
        Body = @"
### Summary
Comparing taste with oneself evaluates to 50% 'Casual Acquaintances'. Taste breakdown shows arbitrary letter grades ('Movie Match: AA', 'Series Match: A').

### Context & Screen Location
- **Screen**: `FriendProfileScreen (SCR-15)`
- **File**: `lib/features/profile/domain/taste_compatibility_calculator.dart`
- **Spec Reference**: `docs/technical_architecture/03_SPEARMAN_RANK_CORRELATION_TASTE_MATCH.md`

### Current Behavior (As-Is)
Self-comparison evaluates to 50% match; letter grades lack clarity.

### Proposed Solution (To-Be)
- Fix Spearman rank correlation math to return 100% 'Taste Twin' when comparing identical lists.
- Replace letter grades with transparent percentage match (e.g. *94% Movie Alignment*, *88% Series Alignment*) and shared titles count.

### Acceptance Criteria
- [ ] Self-taste match evaluates to 100% / Taste Twin.
- [ ] Letter grades replaced with transparent percentage match and shared titles count.
"@
    },
    @{
        Title = "[FE-SETTINGS-01] EditProfile: Auto-Pop Back to Profile/Settings on Successful Profile Save"
        Labels = "bug,area:settings,p2-medium,status:ready"
        Body = @"
### Summary
Clicking 'Save Profile Changes' displays 'Profile saved' but remains on the edit screen.

### Context & Screen Location
- **Screen**: `EditProfileStudioScreen (SCR-21)`
- **File**: `lib/features/profile/presentation/screens/edit_profile_studio_screen.dart`
- **Spec Reference**: `docs/features/03_PROFILE_AND_DUAL_CANON_SPEC.md`

### Current Behavior (As-Is)
Save button displays snackbar but does not pop screen.

### Proposed Solution (To-Be)
- Show success toast and automatically pop navigation back to previous screen (Profile or Settings).

### Acceptance Criteria
- [ ] Saving profile pops back to prior screen upon success.
"@
    },
    @{
        Title = "[FE-SETTINGS-02] DataPortability: Implement UI for Importing Watch History (Letterboxd CSV / AniList GraphQL)"
        Labels = "feature,area:settings,p1-high,status:ready"
        Body = @"
### Summary
Settings has 'Data & Exports', but no 'Data Imports' option to import watch history from Letterboxd CSV or AniList GraphQL.

### Context & Screen Location
- **Screen**: `SettingsHubScreen (SCR-20)`
- **File**: `lib/features/profile/presentation/screens/settings_hub_screen.dart`
- **Spec Reference**: `docs/features/01_LOGGING_FLOW_AND_STUDIO_SPEC.md` §4

### Current Behavior (As-Is)
Import parsers exist in core domain, but no UI in Settings exposes them.

### Proposed Solution (To-Be)
- Add 'Import Watch History' section in Settings.
- Allow uploading Letterboxd `watched.csv` / `ratings.csv` or entering an AniList username to bulk import rated titles into Telly.

### Acceptance Criteria
- [ ] Import button in Settings allows picking Letterboxd CSV or entering AniList username.
- [ ] Imported titles are parsed and added to the user's catalog pool.
"@
    },
    @{
        Title = "[FE-SETTINGS-03] Notifications: Add Master 'Enable All / Disable All' Push Notification Toggle"
        Labels = "enhancement,area:settings,p3-low,status:ready"
        Body = @"
### Summary
Users must toggle individual notification categories one by one.

### Context & Screen Location
- **Screen**: `SettingsHubScreen (SCR-20)`
- **File**: `lib/features/profile/presentation/screens/settings_hub_screen.dart`
- **Spec Reference**: `docs/features/11_NOTIFICATIONS_AND_ENGAGEMENT_SPEC.md`

### Current Behavior (As-Is)
No master toggle for notifications.

### Proposed Solution (To-Be)
- Add a master switch at the top of the Notifications settings group: 'All Notifications' (Enable All / Disable All).

### Acceptance Criteria
- [ ] Toggling master switch toggles all notification categories simultaneously.
"@
    },
    @{
        Title = "[FE-SETTINGS-04] Sanitization: Remove Internal Document Codes from Production UI Labels"
        Labels = "bug,area:settings,p2-medium,status:ready"
        Body = @"
### Summary
Production UI displays internal developer spec references (e.g. 'Face ID / Fingerprint to unlock app (AUTH §4.1)', '30-day self-deletion grace period (LEGAL-601)').

### Context & Screen Location
- **Screen**: `SettingsHubScreen (SCR-20)`
- **File**: `lib/features/profile/presentation/screens/settings_hub_screen.dart`
- **Spec Reference**: `docs/adjacent_systems/04_SETTINGS_AND_APP_CONFIG_SPEC.md`

### Current Behavior (As-Is)
Developer spec citations visible to end users.

### Proposed Solution (To-Be)
- Sanitize all user-facing strings to clean product copy:
  - *'Face ID / Fingerprint unlock'*
  - *'Account deletion takes effect after a 30-day grace period'*

### Acceptance Criteria
- [ ] Zero internal spec citations or ticket IDs visible in production UI labels.
"@
    },
    @{
        Title = "[FE-THEME-01] Theme: Implement Day Cathode Light Mode & Theme Switcher in Settings"
        Labels = "feature,design,area:theme,p1-high,status:ready"
        Body = @"
### Summary
App is hardcoded dark-mode only (`TellyColors.backgroundCanvasOled`). No theme selection in Settings.

### Context & Screen Location
- **Screen**: `SettingsHubScreen (SCR-20)`
- **File**: `lib/core/theme/telly_theme.dart`, `lib/core/theme/telly_colors.dart`, `lib/features/profile/presentation/screens/settings_hub_screen.dart`
- **Spec Reference**: `docs/design_system/01_DESIGN_PHILOSOPHY_AND_STYLE_GUIDE.md` §2

### Current Behavior (As-Is)
No theme options; dark mode only.

### Proposed Solution (To-Be)
- Add Theme Selector in Settings: System Preference, Dark Mode, Light Mode.
- Create cohesive 'Day Cathode' light theme:
  - Canvas: `#F6F7F9`, Card Surface: `#FFFFFF`, Stroke: `#E2E5EC`.
  - Maintain Phosphor Lime, Neon Coral, and Electric Violet adjusted for light-mode contrast.
  - Preserve existing typography, border radiuses, and glass cards.

### Acceptance Criteria
- [ ] Settings allows selecting System, Dark, or Light theme.
- [ ] Light theme renders with complete WCAG AA contrast across all screens while retaining brand aesthetic.
"@
    },
    @{
        Title = "[FE-LEGAL-01] Legal: Replace Broken telly.app Web Links with In-App Native Markdown Viewers"
        Labels = "bug,area:settings,p2-medium,status:ready"
        Body = @"
### Summary
Privacy Policy, Terms of Service, and Share link point to `https://telly.app/...` which is not yet deployed, returning broken links.

### Context & Screen Location
- **Screen**: `SettingsHubScreen (SCR-20)`
- **File**: `lib/core/router/routes.dart`, `lib/features/profile/presentation/screens/settings_hub_screen.dart`
- **Spec Reference**: `docs/legal/TERMS_OF_SERVICE.md`, `docs/legal/PRIVACY_POLICY.md`

### Current Behavior (As-Is)
Clicking legal links fails because external web domain is not deployed.

### Proposed Solution (To-Be)
- Implement an in-app `LegalDocumentScreen(title: ..., assetPath: ...)` rendering the bundled `docs/legal/` markdown files.
- Update Share link generator to fall back to deep link / store link scheme until web landing page is live.

### Acceptance Criteria
- [ ] Terms and Privacy links open native in-app markdown viewer without web failures.
"@
    }
)

Write-Host "Creating $($issues.Count) issues in $Repo..."

foreach ($issue in $issues) {
    Write-Host "Creating: $($issue.Title)"
    gh issue create --repo $Repo --title $issue.Title --body $issue.Body --label $issue.Labels
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to create: $($issue.Title)" -ForegroundColor Red
    }
}

Write-Host "Finished creating all issues."
