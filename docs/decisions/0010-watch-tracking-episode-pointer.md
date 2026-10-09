# 0010. Watch tracking uses one episode pointer per title, woven through the title page

- **Date**: 2026-10-09
- **Status**: Accepted
- **Issue**: #168 (alternatives in #170)
- **Mockup**: [0168-watch-tracking.html](../design_system/mockups/0168-watch-tracking.html)

## Context
Telly could only say a series was "watching" once it was already ranked: `user_rankings.status = 'WATCHING'`, set by the Log flow's *Up to date* and *Specific season* choices. There was no way to track a title before ranking it and no episode progress. People open the app between episodes, and Home (#45) needs a Currently watching section, so tracking needed its own model.

We compared three approaches:
- **A. Episode pointer**: one "next up" place per title (S2 · E6), moved forward one episode at a time.
- **B. Episode checklist**: a checkbox and a stored row for every watched episode, with bulk actions per season.
- **C. Watching shelf**: a Want → Watching → Finished state on Queue entries, with the season as the only progress.

## Decision
The owner chose **A**, over three rounds of mockups, with these refinements:
- **Title page** (SCR-08) carries the whole lifecycle:
  - The action row's Queue slot becomes one **Watch** slot: Start watching → Watching → Up to date / Finished.
  - Starting asks **Where are you?** (from the beginning, or the last episode watched).
  - While watching, a **Next episode** card replaces *Streaming now*, the header shows "Watching · S2 · E6 next", and the backdrop carries a progress line.
  - The seasons accordion shows progress: a ring per season, ticked episodes before your place, *You're here*, and blurred names and synopses after it.
  - Friends watching it (no episode numbers) and the community drop-off point join the page.
- **The episode button** reads **✓ Watched E6** (short form **✓ E6** in rows), not "+1". Every tap shows an Undo toast.
- **Un-logging**: tap a ticked episode → *Mark as not watched* moves your place back (with a confirm when that spans several episodes). *Rewatched it* logs a rewatch without moving your place.
- **New episodes**: a daily server check returns caught-up or finished titles to In progress when a new episode airs, under a *New episodes* group. A ranked *Up to date* series keeps its rank and is offered a re-duel when caught up again.
- **Tracking hub**: a new screen, *Watching* (`/more/watching`), opened from a full-width tile under Queue in More and from Home's *See all*. Home shows only a three-row summary.
- **Canon** (SCR-14): a Watching strip above the podium for the selected canon only, a ▶ S2 · E6 tag on ranked rows still being watched, and an *Episodes this year* (TV) or *Movies finished this year* (Movies) stats tile.
- **Smaller calls** from #170, accepted with the design:
  - Starting is manual, never inferred.
  - Finishing offers *Log and duel* with the watch status prefilled, and never opens it unasked.
  - Dropping prefills the drop point from your place.
  - Movies get a simple watching flag with ✓ Finished.
  - Friends see only "started" and "finished", never episode progress, and privacy modes apply.
  - Tracking stays separate from the canon.
  - Progress edits go through the offline write-ahead queue.

## Consequences
- One row per tracked title keeps the data small and offline-friendly. Telly can't know about skipped episodes; your place counts everything before it as watched.
- Episode names, stills and air dates need a cached TMDB episode fetch. When it's missing, the page falls back to "Episode 6".
- Checklist precision (option B) is still possible later. The pointer then becomes "the episode after the highest checked one".
- **Split out**: episode reactions, takes and season duels go to their own epic (#216), built on this progress data. The Undo tray and an episode page route are reserved for it. Push notifications for new episodes are #222.
- Spec changes land in #171 (Specify): screen specs SCR-08, SCR-13, SCR-14, SCR-21, SCR-22 and a new hub screen, feature spec 03, and the database spec.
