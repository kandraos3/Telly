# 0011. Home leads with a "Tonight" hero and a short list of moves

- **Date**: 2026-10-09
- **Status**: Accepted
- **Issue**: #45 (alternatives in #98)
- **Mockup**: [0045-home-tonight-moves.html](../design_system/mockups/0045-home-tonight-moves.html)

## Context
Home (SCR-21) has been an interim page since #44. It showed a Currently watching card (#168), the top 3 of the selected canon and three friend rows. The owner's complaint was that the app had no real home and felt like "pieces assembled as we go". Everything a home needs now exists: watch tracking with its groups (#168), the Queue's Up next pick (#47), the weekly streak, quests and challenges (#50), and the Following feed (#48).

We compared three layouts in [mockups](https://claude.ai/artifact/R3sdgQdh6HCMFdCnHEKaE2):
- **A. Dashboard**: one section per kind of content, in a fixed order (Currently watching, Rank what you finished, Up next, This week, friends, canon top 3).
- **B. Tonight + your moves**: one hero card for what to watch next, then up to four single-action cards and one friends line.
- **C. Rails**: horizontal rows like a streaming app, with top-10 rows for each canon.

## Decision
The owner chose **B, as mocked up, without the canon top 3**:
- **Hero ("Tonight")**: the most recently progressed tracked title, with its next episode and **✓ Watched E6** (or **✓ Finished** for a movie). Chips under it switch to the other titles you're watching, plus *All N ›* to the Watching hub. When nothing is tracked, the hero shows the Queue's Up next pick (▶ Start watching, ↻ Another). A new user with no rankings sees *Start your canon* with **+ Log a title**.
- **Your moves**: at most four cards, each with one action, chosen and ordered by a pure-Dart ranker from: a finished title waiting to be ranked, a new season out, a streak that needs a ranking this week, a challenge close to done, a friend who ranked a title you've also ranked, and the Queue's Up next pick when the hero isn't already showing it. A new user gets *track a show* and *find friends* moves.
- **Friends**: one line (faces, "Maya, Jordan and 4 others ranked 9 titles today") that opens Social.
- **Streak**: a 🔥 chip in the Home header that opens Your level. It's hidden until the first streak week.
- **Removed from Home**: the canon top 3 and its switcher (the Canon tab is one tap away), and the three friend rows.

## Consequences
- Home stays short: a hero, up to four moves and a friends line. A new feature that wants a spot on Home adds a move type to the ranker instead of a section.
- The moves ranker and the hero fallback chain are new pure-Dart logic with unit tests. What Home shows changes day to day, so the ranker needs a stable tie-break order.
- No new backend. Home reads only existing providers: tracking, Queue, levels (streak and quests), challenges, the Following feed and the canon (for the friend comparison).
- The interim *Currently watching* card (`HomeCurrentlyWatching`) is replaced by the hero and its chips. The Watching hub (SCR-29) is unchanged.
- The spec changes land in #99 (Specify): screen spec SCR-21 and the related flows.
