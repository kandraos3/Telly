# 0003. Five-tab shell with a More hub and a floating Log button

- **Date**: 2026-10-06
- **Status**: Accepted
- **Issue**: #44 (alternatives in #103)

## Context
The shell had four tabs (Feed · Explore · Queue · Canon) around a centre `+` that opened the Log flow. Secondary screens (Settings, Graveyard, Wrapped, Squads) lived behind header icons, and there was no room for the Phase-two features: Home tracking (#45), friends (#48), squad chat (#49), achievements (#50), referrals (#51) and Telly Pro (#52). We compared three structures in [mockups](https://claude.ai/artifact/KrxRKUaSeqeEMSSoP7o5Zo):
- **A**: Home · Explore · Canon · Social · More, with logging started from Home and title pages.
- **B**: Home · Explore · Queue · Canon · More, with the feed folded into Home and a floating Log button.
- **C**: today's centre `+` kept, with Home · Explore · Canon · More around it.

## Decision
The owner chose **A, with two changes**:
- **Tabs**: Home · Explore · Canon · Social · More. There is no centre `+`.
- **Log**: a floating lime **`+ Log`** button (taken from B) sits above the tab bar on Home, Explore, Canon and Social. It is hidden on More and on pushed screens. Title pages keep their own rank action.
- **Queue** moves into the **More** hub, as its first, full-width tile.
- **Social** holds the activity feed (Friends / Squads / Global) and Squads. It is the home for future social features.
- **More** (WHOOP-style hub) holds the profile card, Queue, Achievements, Wrapped, Graveyard, Invite friends, Telly Pro, Settings, and Help & feedback (once a support channel exists). Features that aren't built yet don't appear until they ship.

## Consequences
- Logging stays one tap away on every tab that has the floating button. CUJ-02 keeps its tap count.
- The Queue is two taps away (More → Queue). Saving to the Queue from title pages and Explore is unchanged. Home (#45) may show an "Up next" preview.
- Routes move:
  - `/feed` becomes `/social`, and `/feed/activity/:id` becomes `/social/activity/:id`.
  - `/queue` becomes `/more/queue`.
  - `/canon/{settings,edit,graveyard,wrapped}` become `/more/{…}`.
  - The old paths redirect.
- Until #45 ships, Home shows only existing data (top of each canon, latest friends' activity) rather than the full feed.
- The spec changes are in component library §2.1 and §2.3, screen specs §0.0, SCR-21 and SCR-22, and interaction flows Flow 1 (logging trigger). The implementation tasks are under #105.
