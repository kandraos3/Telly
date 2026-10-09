# Telly UI/UX Design System: 05 — Public Website

> Tracking: epic #254 · Status: approved
> Decision: [0013](../decisions/0013-website-five-chapters-with-playable-duel.md) · Mockup: [0254-website-chapters.html](mockups/0254-website-chapters.html)

The public website at `https://kandraos3.github.io/Telly/` is a static site. It sells the app as it is today, hosts the privacy policy, terms and support pages, and links to the stores. Everything about it is built from the app on each push (`.github/workflows/site.yml`):

| Part | Source |
|---|---|
| Words, structure, which screenshot goes where, links | `site/content.yaml` |
| Layout and styling | `site/static/site.css` (tokens only) |
| Behaviour (the hero duel) | `site/static/site.js` |
| Colors and type | `tokens.css`, generated from `lib/core/theme/` |
| Screenshots | Scenes in `tool/site/src/scenes.dart`, rendered from the real widgets with fakes |
| Poster art | `GeneratedPosterImage` (`tool/site/src/poster_art.dart`); the site never shows studio artwork |
| Legal pages | `docs/legal/*.md`, rendered with the app's legal parser |

Build locally with `bash tool/site/build.sh`, then open `build/site/index.html`.

---

## 1. Landing page structure

In order, top to bottom:

1. **Nav bar** (glass, sticky): brand, one link per chapter (`#track`, `#rank`, `#discover`, `#friends`, `#play`), *Support*, and **Get the app** (`#download`). Below 1000 px the chapter links hide; below 560 px only the brand and *Get the app* show.
2. **Hero** (§2): eyebrow chip, headline, body, store badges, and the duel card.
3. **Chapter strip**: five cards in a row (scrolling sideways below 700 px), one per chapter: number, name, one-line summary. Each links to its chapter and uses the chapter's accent for its number.
4. **Five chapters** (§3), in the order Track, Rank, Discover, Friends, Play.
5. **Extras**: three cards (import, offline, export).
6. **Closing call to action** (`#download`): title, body, store badges.
7. **Footer**: unchanged from WEB-03 (copyright, attribution, trademark and font notices, legal links).

Privacy, terms, support and 404 pages keep their WEB-03 layout. The site stays dark only (`color-scheme: dark`).

## 2. Hero duel

The duel card teaches the core idea by doing it once.

**Content** (`hero.duel` in `content.yaml`):
- `media_type`: `tv` or `movie`. Every pair is from that one ranking (dual-canon rule: a film never duels a show).
- `pairs`: one or more pairs of two highly rated titles of that type. The first pair shows on load.
- `total`: the size of the example ranking the scores come from (40).

**Scores**: the builder computes the example scores with the app's `ScoreCurveCalculator.calculateRoundedScore(rank, total)` for ranks 1 and 2. A tie shows both titles at rank 1 with the rank-1 score. The scores are illustrative and labelled *Example scores in a ranking of {total} shows* (or *films*).

**Posters**: one PNG per duel title from `GeneratedPosterImage` without the drawn title (the card sets the title over it), written to `assets/posters/<slug>.png` at 342 × 513. `<slug>` is the title in lowercase with every run of other characters replaced by `-`.

**States**:

| State | Shows |
|---|---|
| Pick (on load) | "Which did you like more?", the media label, two poster buttons with the titles, *vs*, the hint "Tap the one you liked more" and **Too close to call** |
| Result | "{Winner} takes the higher spot" (or "Called it a tie"), a two-row ranking (rank, poster, title, score in JetBrains Mono, the winner row outlined in Phosphor Lime), the example-scores label and **Next duel** |
| Next duel | The next pair's Pick state, cycling back to the first after the last |
| No JavaScript | The Pick state. The poster buttons are inert. |

In every state, one line under the card explains what a duel does: "That's a duel. A few of these after each watch and every title lands in its exact place, scored from 1.00 to 10.00."

**Behaviour**: `site.js` reads the pairs and scores from a `data-duel` JSON attribute on the card and swaps the card's content in place. The card has `aria-live="polite"` so the result is announced, and focus moves to the result's heading. The pick buttons are real `<button>`s with the title as their accessible name. The hover lift is turned off under `prefers-reduced-motion`. The script loads with `defer`, uses no library and makes no network requests.

## 3. Chapters

Each chapter is a section with `id`, `eyebrow` ("01 · Track"), `title`, `body`, an `accent` color token, and one or two `screenshots` (scene ids). It can also have `points` (a bullet list), `cards` (two short title-and-body cards) and `show_tiers` (the score-tier strip). Text and screens alternate sides from chapter to chapter. The first screenshot is the lead. The second sits offset beside it on wide screens and is hidden below 700 px.

| Chapter | Accent | Screens | Covers |
|---|---|---|---|
| Track | `electricCyan` | `home`, `watching` | Home's Tonight hero and Your moves; episode progress in the Watching hub |
| Rank | `phosphorLime` | `reveal`, `canon` | Duels, the score reveal, the podium; the score tiers |
| Discover | `electricViolet` | `explore`, `queue` | Explore rows; Queue Up next and streaming; Two-to-Watch |
| Friends | `neonCoral` | `feed`, `taste-match` | Upsets and reactions; Taste Match; user search and private profiles; squads |
| Play | `warmAmber` | `achievements`, `level` | Medals and collections; monthly and squad challenges; levels, XP, streaks and rewards |

Copy uses today's names: Home, Explore, Rankings, Social, More, Movie Rankings and TV Rankings (decision 0012).

## 4. Screenshot scenes

Scenes added for this design (`tool/site/src/scenes.dart`). Each renders the real screen with fakes and example data that read like a real user's:

| Scene | Screen | State shown |
|---|---|---|
| `home` | SCR-21 Home, tab 0 | Tonight hero on a tracked show's next episode, two or more moves, the friends line, a streak chip |
| `watching` | SCR-29 Watching hub | Shows grouped by state (new episodes, in progress, finished not ranked, caught up), each with its progress bar and next-episode button, and this week's totals |
| `achievements` | Achievements, Medals tab | A mix of gold, silver, bronze, special and locked medals, and a collection in progress |
| `level` | Your level | Level, XP bar, streak, weekly quests in mixed states, friends this week |

Existing scenes keep rendering the current widgets, so `canon` (podium), `explore`, `queue`, `feed` and `taste-match` update automatically. Backdrops in scenes use `backdropPathFor(title)`, which draws the same generated art without the title, so text laid over it stays readable. Scenes the page no longer uses can stay in `scenes.dart`; the builder only copies screenshots the page references.

## 5. Build checks

`dart run tool/site/build.dart` fails, and the deploy doesn't run, when:
- `site.css` has a hex or `rgb()` color literal, or a `var()` that nothing defines;
- `content.yaml` references a screenshot with no scene or an unknown accent token;
- chapter ids aren't unique, a chapter has no screenshots or more than two, or there are no chapters;
- the duel has no pairs, a pair doesn't have exactly two different titles, or `media_type` isn't `tv` or `movie`;
- any internal link or asset (including `assets/site.js` and duel posters) points at a file the build didn't write.

## 6. Tests

- **Unit** (`test/site/`): parsing and validation of `chapters` and `hero.duel`; duel scores match `ScoreCurveCalculator`; the landing page renders every chapter with its anchor, accent and screenshots, the duel card with its `data-duel` JSON, and the nav links; no broken links in a built page.
- **Scenes** (`test/site/scenes_test.dart`): the new scene ids are present and URL-safe.
- The full build (`bash tool/site/build.sh`) runs in the site workflow and renders every scene.
