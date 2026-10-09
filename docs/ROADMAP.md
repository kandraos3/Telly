# Telly Roadmap

Direction at a glance. Every idea and epic below goes through the standard stages (Evaluate → Explore alternatives → Specify → Implement → Verify & release). The live state of every item is on the [**Telly board**](https://github.com/users/kandraos3/projects/1). How tracking works: [`process/WORKFLOW.md`](process/WORKFLOW.md). Sprints 1–6 (v1 build) are archived in [`history/`](history/SPRINTS_1-6_ROADMAP.md).

_Updated 2026-10-09. Change this page when the direction changes, not for status updates._

## Now
- **Tracking system**: standard idea stages, PM operating model, drift-proof agent instructions ([#112](https://github.com/kandraos3/Telly/issues/112))
- **Launch setup**: remaining human-only console, secrets and store tasks ([#43](https://github.com/kandraos3/Telly/issues/43))

## Next
- **Light-mode lime contrast** ([#54](https://github.com/kandraos3/Telly/issues/54))
- **Push notifications** ([#42](https://github.com/kandraos3/Telly/issues/42))
- **Apple & Google sign-in** ([#3](https://github.com/kandraos3/Telly/issues/3))

## Later
- **Squad chat + share-to-squad** ([#49](https://github.com/kandraos3/Telly/issues/49))
- **Referrals** ([#51](https://github.com/kandraos3/Telly/issues/51)), building on gamification
- **Alternate app icons**, the level 20 reward (stubbed as "Coming soon", [#154](https://github.com/kandraos3/Telly/issues/154))
- **Telly Pro** (idea, [#52](https://github.com/kandraos3/Telly/issues/52))
- **Watch party** (idea, [#53](https://github.com/kandraos3/Telly/issues/53))
- **Episode reactions, takes and season duels**, built on watch tracking (idea, [#216](https://github.com/kandraos3/Telly/issues/216))
- **Smart "Up next" pick** for the Queue, replacing the random pick (idea, [#124](https://github.com/kandraos3/Telly/issues/124))

## Recently shipped
- **Home tab**: a Tonight hero with your next episode and one-tap logging (falling back to your Queue pick, then a welcome or an Explore nudge), up to four ranked moves (rank what you finished, new seasons, keep your streak, challenges close to done, friends' rankings you can compare, your Queue pick), one friends line and a streak chip in the header. The canon top 3 and friend rows left Home ([#45](https://github.com/kandraos3/Telly/issues/45), [decision 0011](decisions/0011-home-tonight-hero-and-moves.md), [SCR-21](design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md))
- **Watch tracking**: currently watching on Home with episode progress, a Watching hub (`SCR-29`), start flow from Queue and title pages, episode sheet and spoiler guard, and finishing into the log and duel flow ([#168](https://github.com/kandraos3/Telly/issues/168), [decision 0010](decisions/0010-watch-tracking-episode-pointer.md), [features/11](features/11_WATCH_TRACKING_AND_EPISODE_PROGRESS.md))
- **Friends outside squads & public profiles**: discover and follow users via `@handle` and display name search (`SCR-28`), send follow requests, and view profiles with taste comparison dials. Added account privacy controls (`PUBLIC`, `FRIENDS_ONLY`, `GHOST`) in settings (`SCR-20`) and locked private profile gates (`SCR-15`) ([#48](https://github.com/kandraos3/Telly/issues/48), [decision 0009](decisions/0009-social-friends-search-and-privacy.md), [features/04](features/04_SOCIAL_GRAPH_FEED_AND_UPSETS.md), [adjacent/02](adjacent_systems/02_PROFILE_MANAGEMENT_AND_CUSTOMIZATION.md))
- **Explore rows + recommendation engine**: a hero pick and Netflix-style rows (Trending now, Top picks, Because you ranked *X*, Your friends are watching, Leaving your services soon, Something different), each with a See all grid. The server gathers candidates from TMDB recommendations of your top titles, trending lists and friends; a documented, unit-tested ranker on the device scores them by taste, seeds, friends, quality and your services. Curated canons are gone, and Not for me hides a pick with Undo ([#46](https://github.com/kandraos3/Telly/issues/46), decisions [0007](decisions/0007-explore-hero-rows-and-client-ranker.md) and [0008](decisions/0008-explore-dismissals-own-table.md), [features/07 §7](features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md#7-explore-rows--recommendation-engine))
- **Gamification**: medals and a trophy case, film collections, seasonal and squad challenges, XP, levels, weekly quests and streaks, cosmetic rewards, and a weekly friends table. Only rankings placed through duels count, so imports can't farm it ([#50](https://github.com/kandraos3/Telly/issues/50), [decision 0005](decisions/0005-gamification-medals-challenges-levels.md), [spec 10](features/10_GAMIFICATION_MEDALS_CHALLENGES_AND_LEVELS.md))
- **Rankings & Queue layout pass**: the Rankings tab opens on a #1–#3 podium, with stats and views in header sheets; the Queue leads with a random "Up next" card under one control row, with lists on their own screen ([#47](https://github.com/kandraos3/Telly/issues/47), [decision 0004](decisions/0004-canon-podium-and-queue-up-next.md))
- **Navigation & app structure**: five tabs (Home · Explore · Rankings · Social · More), floating Log button, More hub with the Queue, interim Home ([#44](https://github.com/kandraos3/Telly/issues/44), [decision 0003](decisions/0003-five-tab-shell-with-more-hub.md))
