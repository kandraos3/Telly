# 0005. Gamification: medals, challenges and levels together

- **Date**: 2026-10-07
- **Status**: Accepted
- **Issue**: #50 (alternatives and the owner's answers in #73)
- **Mockup**: [0050-gamification-directions.html](../design_system/mockups/0050-gamification-directions.html)
- **Spec**: [features/10](../features/10_GAMIFICATION_MEDALS_CHALLENGES_AND_LEVELS.md)

## Context
The owner wants a game layer to bring people back between watches and give friends something to compare: achievements (including "finished the Batman films"), marathons and challenges, points, and streaks. Points might unlock things. We showed three directions:
- **A. Trophy case:** medals for milestones, film collections and taste moments, with three pinned to your profile.
- **B. Levels and weekly quests:** XP, levels, cosmetic rewards, three quests a week, and a weekly table against friends.
- **C. Challenges and marathons:** time-boxed challenges, seasonal or squad-made, raced with friends.

The risks:
- rewarding *logging* encourages ranking titles nobody watched, which would corrupt the canon;
- daily streaks punish people who don't watch every day;
- feature unlocks would compete with a future Telly Pro (#52).

## Decision
The owner chose **all three directions, as presented**, with these rules:
1. **Rewards are cosmetic:** profile frames, share-card styles, canon decorations, app icons. Physical rewards such as merch may come later, so XP is kept in an append-only, auditable ledger.
2. **Weekly streak:** a week counts if you rank at least one qualifying title. One freeze each calendar month covers a missed week automatically.
3. **Friends-only competition:** people you follow, and your squads, in weekly tables that reset each Monday. There are no global leaderboards; a medal's rarity ("Unlocked by 4.2% of viewers") gives the global flavour.
4. **Only duelled titles count.** A ranking qualifies when it was placed through duels, or was the first title in its canon. Imports (Letterboxd, AniList) never count. XP for ranking is capped at 10 titles per week.
5. **Feed:** medal unlocks and finished challenges post to your followers by default. Settings has a toggle to stop it. Quests and level-ups never post.
6. **Challenges are server-side data** with a fixed set of rule types. New challenges never need an app update. They come from:
   - the agent, through challenge files in the repo published by a script;
   - a scheduled job that creates recurring challenges from templates;
   - squads making their own from templates.
7. **Navigation:** as in the mockup, the More hub gets three entries: **Achievements** (medals), **Challenges** and **Your level**.

## Consequences
- **New backend:** medal catalogue and unlocks, a qualifying-ranking rule, streaks, challenges and their rules, an XP ledger, levels, weekly quests, rewards, TMDB collections, and a challenge scheduler. Each comes with pgTAP tests.
- **It ships in three slices**, so value lands early:
  1. medals and the weekly streak;
  2. collections and challenges;
  3. XP, levels, quests and rewards.
- **Feed:** gains two activity types (medal unlocked, challenge completed) and a privacy toggle in Settings.
- **The old badge sketch** in `docs/adjacent_systems/02` §3 is superseded by features/10.
- **Pro (#52):** must never move a cosmetic reward behind the paywall without a new decision.
- **Merch:** any future redemption needs its own decision covering costs, shipping, fraud and terms.
- **Follow-up epics:** push reminders for streaks and new challenges belong to #42. Friends (#48) improves the competitive parts but doesn't block them.
