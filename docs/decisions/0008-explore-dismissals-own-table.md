# 0008. "Not for me" on Explore stores dismissals in their own table

- **Date**: 2026-10-08
- **Status**: Accepted
- **Issue**: #189 (epic #46). Amends [0007](0007-explore-hero-rows-and-client-ranker.md)'s consequence about `user_muted_titles`.

## Context
Decision 0007 planned the Explore hero's **Not for me** as an insert into `user_muted_titles`, because `get_explore_candidates` already excluded muted titles. While building it we noticed that `user_muted_titles` is the Spoiler Shield list, and `get_activity_feed` hides muted titles. Dismissing a recommendation would therefore also have hidden friends' feed posts about that title, which nobody would expect.

## Decision
The owner chose a separate table, `user_dismissed_recommendations (user_id, title_id, media_type, dismissed_at)`, which only users can read and write, and only their own rows. `get_explore_candidates` excludes these titles as well as ranked and muted ones. **Undo** deletes the row.

## Consequences
- A dismissal affects Explore only. The feed and the Spoiler Shield are untouched.
- There's one more table and migration (`20261010003000_dismissed_recommendations.sql`) and two repository calls (`dismissRecommendation`, `undoDismissRecommendation`).
- Dismissals don't expire. A screen to review or clear them isn't planned; file one if it's needed.
- The spec changes are in features/07 §7.3 and §7.5, and spec 02 §2.2.
