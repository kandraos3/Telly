# 0007. Explore leads with a hero pick and shaped rows; the server gathers candidates and the app ranks them

- **Date**: 2026-10-07
- **Status**: Accepted
- **Issue**: #46 (evaluation in #92, alternatives in #93)
- **Mockup**: [0046-explore-rows.html](../design_system/mockups/0046-explore-rows.html)

## Context
Explore showed one "Recommended for you" row and four curated canons hard-coded in the app. The owner couldn't tell how the recommendations were made, and asked for Netflix-style rows and for the curated canons to go. The #92 audit found three problems with `get_recommended_titles`:
- It only considers titles already in Telly's own `titles` table, so nothing new comes from TMDB.
- It scores a title by the raw count of genres it shares with each title the user ranked 7.80 or higher, so one broad favourite can outweigh the rest.
- It mixes both canons in one row and ignores the user's streaming services and friends.

All the scoring is in SQL, so the only tests are pgTAP.

We compared three layouts (A uniform rows, B a hero plus rows shaped to their job, C both canons interleaved without a switcher). We also compared three engines (E1 everything in SQL, E2 an edge function that calls TMDB and scores, E3 the server gathers candidates and the app ranks them).

## Decision
The owner chose **layout B** and **engine E3**.
- **Layout**: search, then the slim Movies / Series switcher (`TellyCanonSwitcher`, as in decision 0004), then a **Top pick for you** hero (why it fits, where it streams, + Queue / Details / Not for me). The rows below it each have their own card shape:
  - Top picks for you
  - Trending now (a numbered Top 10)
  - Up to three *Because you ranked X* rows, each led by the seed title
  - Your friends are watching (avatars and the friends' average)
  - Leaving your services soon (a coral day countdown)
  - Something different
- Every row belongs to one canon. A title appears in only one row on the screen.
- **Curated canons are removed.**
- **Network battlegrounds** stay, as the last row of the Series canon only. This was the recommended default; the owner didn't object.
- **Engine**: an edge function caches TMDB recommendations for users' top-ranked titles, plus TMDB trending, in Supabase. One RPC returns about 150 candidates per canon, each with its features (genres, the seeds it came from, friends' rankings, trending rank, whether it's on the user's services, leaving date, community score). A pure Dart `ExploreRanker` scores the candidates, removes duplicates and fills the rows. The rows are cached in Drift.

## Consequences
- The scoring is plain Dart, unit-tested with fixed examples (the 70% base of the test pyramid), and Explore opens from the cache offline. The Home feed's pick cards can reuse the same ranker.
- Changing the scoring weights needs an app release. If they need frequent tuning, a later decision can move the weights into remote config.
- New backend pieces: a related-titles cache table, an edge function that fills it (nightly, and when a user's top-5 changes), and the candidates RPC. `get_recommended_titles` stays for older clients until the Home feed moves to the ranker. Removing it is tracked as a task under #95.
- "Not for me" on the hero writes to `user_muted_titles`, which the candidates RPC already excludes. *Changed by [0008](0008-explore-dismissals-own-table.md): dismissals get their own table, so the feed isn't affected.*
- The spec changes are in screen specs SCR-07 and feature spec 07 §5. The implementation tasks are under #95.
