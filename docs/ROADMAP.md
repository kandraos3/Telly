# Telly Roadmap

Direction at a glance. Every idea and epic below goes through the standard stages (Evaluate → Explore alternatives → Specify → Implement → Verify & release). The live state of every item is on the [**Telly board**](https://github.com/users/kandraos3/projects/1). How tracking works: [`process/WORKFLOW.md`](process/WORKFLOW.md). Sprints 1–6 (v1 build) are archived in [`history/`](history/SPRINTS_1-6_ROADMAP.md).

_Updated 2026-10-08. Change this page when the direction changes, not for status updates._

## Now
- **Tracking system**: standard idea stages, PM operating model, drift-proof agent instructions ([#112](https://github.com/kandraos3/Telly/issues/112))
- **Launch setup**: remaining human-only console, secrets and store tasks ([#43](https://github.com/kandraos3/Telly/issues/43))

## Next
- **Home tab + currently watching** ([#45](https://github.com/kandraos3/Telly/issues/45))
- **Light-mode lime contrast** ([#54](https://github.com/kandraos3/Telly/issues/54))
- **Push notifications** ([#42](https://github.com/kandraos3/Telly/issues/42))
- **Apple & Google sign-in** ([#3](https://github.com/kandraos3/Telly/issues/3))

## Later
- **Friends & public profiles** ([#48](https://github.com/kandraos3/Telly/issues/48))
- **Squad chat + share-to-squad** ([#49](https://github.com/kandraos3/Telly/issues/49))
- **Referrals** ([#51](https://github.com/kandraos3/Telly/issues/51)), building on gamification
- **Alternate app icons**, the level 20 reward (stubbed as "Coming soon", [#154](https://github.com/kandraos3/Telly/issues/154))
- **Telly Pro** (idea, [#52](https://github.com/kandraos3/Telly/issues/52))
- **Watch party** (idea, [#53](https://github.com/kandraos3/Telly/issues/53))
- **Smart "Up next" pick** for the Queue, replacing the random pick (idea, [#124](https://github.com/kandraos3/Telly/issues/124))

## Recently shipped
- **Explore rows + recommendation engine**: a hero pick and Netflix-style rows (Trending now, Top picks, Because you ranked *X*, Your friends are watching, Leaving your services soon, Something different), each with a See all grid. The server gathers candidates from TMDB recommendations of your top titles, trending lists and friends; a documented, unit-tested ranker on the device scores them by taste, seeds, friends, quality and your services. Curated canons are gone, and Not for me hides a pick with Undo ([#46](https://github.com/kandraos3/Telly/issues/46), decisions [0007](decisions/0007-explore-hero-rows-and-client-ranker.md) and [0008](decisions/0008-explore-dismissals-own-table.md), [features/07 §7](features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md#7-explore-rows--recommendation-engine))
- **Gamification**: medals and a trophy case, film collections, seasonal and squad challenges, XP, levels, weekly quests and streaks, cosmetic rewards, and a weekly friends table. Only rankings placed through duels count, so imports can't farm it ([#50](https://github.com/kandraos3/Telly/issues/50), [decision 0005](decisions/0005-gamification-medals-challenges-levels.md), [spec 10](features/10_GAMIFICATION_MEDALS_CHALLENGES_AND_LEVELS.md))
- **Canon & Queue layout pass**: the Canon tab opens on a #1–#3 podium, with stats and views in header sheets; the Queue leads with a random "Up next" card under one control row, with lists on their own screen ([#47](https://github.com/kandraos3/Telly/issues/47), [decision 0004](decisions/0004-canon-podium-and-queue-up-next.md))
- **Navigation & app structure**: five tabs (Home · Explore · Canon · Social · More), floating Log button, More hub with the Queue, interim Home ([#44](https://github.com/kandraos3/Telly/issues/44), [decision 0003](decisions/0003-five-tab-shell-with-more-hub.md))
