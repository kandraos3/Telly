# 0004. Canon leads with a podium; Queue leads with "Up next"

- **Date**: 2026-10-06
- **Status**: Accepted
- **Issue**: #47 (alternatives in #88)
- **Mockup**: [0047-canon-queue-layouts.html](../design_system/mockups/0047-canon-queue-layouts.html)

## Context
Users open the Canon tab to see their rankings and scores. Before this change the profile card, Movies / TV switcher, stats panel, Top 3 showcase and view-mode row filled about 700 dp, so rank #1 started behind the tab bar. The Queue stacked three control rows (Watchlist / My Lists / Friends' Lists, Movies / TV, On My Services) before its first card, and every card had two buttons. Since decision 0003 the profile card also lives in More, so the Canon tab no longer needs it.

We compared three layouts for each screen:
- **Canon**: A *Stat strip* (a chip row of key stats over the list), B *Podium* (ranks #1–3 as large poster cards, with stats in the header), C *Stats as a view* (a fourth view next to Ranked / Tiers / 3x3).
- **Queue**: A *One row of controls* (Movies / Series plus Filter, compact rows), B *Up next hero* (one large card, then compact rows), C *Hubs kept, filters merged*.

## Decision
The owner chose **Canon B** and **Queue B**, with these changes:
- **Canon**:
  - The view switcher leaves the page. A header button, whose icon shows the current view, opens a View sheet with Ranked / Tiers / 3x3. The Series-only anime franchise rollup toggle moves into the same sheet, replacing the ⋮ menu.
  - The podium appears in **Ranked** only. Tiers and 3x3 use the whole page under the switcher.
  - Stats stay at the top as a header button that opens a Stats sheet (today's stats panel plus the pinned Top 3).
  - The profile card is removed from the tab (it lives in More).
- **Queue**:
  - The Movies / Series switcher is the same compact switcher as Canon, next to one **Filter** chip that opens a sheet with Sort and On My Services. This was option A's control row.
  - My Lists and Friends' Lists move to a **Lists** screen opened from the app bar.
  - "Up next" is a **random** title from the ones the current filter shows. It's re-rolled each time the Queue opens, and ↻ picks another. A smart pick is tracked in #124.
- **Shared**: the compact `TellyCanonSwitcher` look becomes the only look, everywhere it's used (Canon, Queue, Home, Squad hub).

## Consequences
- Rank #1 starts about 158 dp below the header instead of about 700 dp. Changing view takes two taps instead of one.
- Stats and the pinned Top 3 are one tap away (the Stats sheet). They're no longer visible on open.
- The Queue shows about 6 titles above the fold instead of about 4. Lists are one tap deeper (☷ → Lists). Each row has a single ▶ Watch action, and Mark seen moves to the Up next card and a swipe right, which also opens the Log flow.
- New route `/more/queue/lists`. Custom list detail stays at `/more/queue/list/:id`.
- The spec changes are in screen specs SCR-13, SCR-14, §0 and §0.2; component library §5.4–§5.6; and feature specs 06 §2–§3 and 07 §2. The implementation tasks are under #90.
- The friend profile (SCR-15) doesn't show canon lists today. When #48 adds them, it should reuse these views.
