# 0009. Social friends search in the Social tab and profile privacy boundaries

- **Date**: 2026-10-08
- **Status**: Accepted
- **Issue**: #48 (evaluation in #82, alternatives in #83)
- **Mockup**: [0048-social-friends.html](../design_system/mockups/0048-social-friends.html)

## Context
Telly users previously only had squads as a shared space, with no way to discover or add friends directly outside a squad. Users also could not easily search for their real-life friends by handle or toggle their own profile visibility between public and private.

In the *Explore alternatives* stage (#83), three information architecture approaches were evaluated:
1. **Search in the Social (Feed) Tab**: An action in the Social tab app bar leading to a dedicated user search screen, coupled with explicit privacy settings in Profile Settings.
2. **Global Search in the More Hub**: A "Find Friends" entry point in the More hub.
3. **Auto-Discovery Only**: Relying solely on Taste Match suggestions, squads, and direct referral links with no search bar.

## Decision
The owner selected **Option 1**:
- **Entry point**: An action icon (`Icons.person_search` / `Icons.search`) in the `Social` (`ActivityFeedScreen`) app bar opens `SearchUsersScreen`.
- **User search**: Real-time debounce search querying users by `@handle` or display name. Results display avatar, handle, display name, mutual/taste indicators, and an inline `+ Follow` / `Requested` / `Following` button.
- **Privacy settings**: Under `Settings > Privacy & Boundaries`, users can select their account visibility:
  - `Public` (default): Anyone can view their Canon, stats, and compare taste.
  - `Friends Only (Private)`: Follow requests must be approved. Canon and taste match are hidden behind a private profile gate until approved.
  - `Ghost Mode`: Excluded from user search results. Discoverable only via direct profile link or referral.
- **Profile navigation**: Clicking any user avatar or handle from the Feed, Squads, Comments, or Search navigates to their profile (`/u/:handle`), honoring their privacy visibility settings.

## Consequences
- Requires adding `SearchUsersScreen` and route `/social/search`.
- Requires profile search capability in `ProfileRepository` / Supabase with privacy filtering (`visibility_mode != 'GHOST'`).
- Wires the privacy setting in `SettingsHubScreen` to update `user_profile_settings.visibility_mode`.
- Keeps the social graph operations directly connected to the Social tab.
