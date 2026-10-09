# 0013. The website tells the app's story in five chapters, opening with a playable duel

- **Date**: 2026-10-09
- **Status**: Accepted
- **Issue**: #254 (alternatives in #256)
- **Mockup**: [0254-website-chapters.html](../design_system/mockups/0254-website-chapters.html)

## Context
The website went live on Oct 5 (WEB-03) with a hero, eight equal feature rows, a gallery and extras. Since then the app has shipped the five-tab shell, Home's Tonight hero and moves, watch tracking, the new Explore rows, the Rankings podium, Queue Up next, medals, challenges and levels, and user search with private profiles. None of these was on the site.

We compared three directions in [mockups](https://claude.ai/artifact/X3VfCccdARCLdB1siViPNf):
- **A. Five chapters**: one long page in the order people use the app, Track → Rank → Discover → Friends → Play. Each chapter has one or two lead screens and a few short cards.
- **B. Play a duel first**: a working duel as the hero, then a bento grid with one tile per feature.
- **C. Hub and feature pages**: a short landing page with five pillar cards, each linking to its own page.

## Decision
The owner chose **A, with a playable duel between two highly rated shows as the hero**:
- **Hero**: headline, short body and store badges beside a duel card. The visitor taps one of two acclaimed shows (or *Too close to call*). The card then shows the two titles ranked with example scores, a line explaining that this is how every title gets its place, and *Next duel*, which cycles through a short list of pairs. Without JavaScript the card still shows the pair and the explanation.
- **Chapters**: Track (Home and episode progress), Rank (duels, reveal, tiers, podium), Discover (Explore, Queue Up next, Two-to-Watch), Friends (feed and upsets, Taste Match, search and private profiles, squads), Play (medals, challenges, levels). A strip under the hero lists the five chapters and links to each.
- **Kept**: extras (import, offline, export), closing call to action, footer, legal and support pages, dark only.
- **Dropped**: the eight-row feature list and the screenshot gallery. Their features move into chapters.

## Consequences
- Every shipped headline feature has a place, and a new feature joins an existing chapter instead of adding a row.
- The site gets its first script (`site/static/site.js`), small and dependency-free. The page must read completely without it.
- The duel cards need poster art. It is generated at build time with the same `GeneratedPosterImage` the screenshots use, so the site still never shows studio artwork.
- New scenes are needed for Home, title-page tracking, Achievements, Your level and Challenges. They render the real widgets with fakes, as the existing scenes do.
- `site/content.yaml` changes shape: `features` and `gallery` give way to `duel` and `chapters`. The content parser, builder and site tests change with it.
- Spec: [`docs/design_system/05_WEBSITE.md`](../design_system/05_WEBSITE.md), written in #257.
