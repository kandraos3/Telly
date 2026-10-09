# 0012. "Rankings" replaces "Canon" in everything users see

- **Date**: 2026-10-09
- **Status**: Accepted
- **Issue**: #252

## Context
The app called a user's personal ranked list their "Canon", a word from fandom. No comparable app (Letterboxd, Trakt, Goodreads) uses it, so new users had to learn it before the Canon tab made sense. The owner asked for a plainer word in the UI while keeping the term inside the code.

## Decision
- **User-facing text says "Rankings"**: the nav tab and screen title, "Movie Rankings" / "TV Rankings" (Series & Anime Rankings in the type picker), the onboarding and reveal copy, empty states, settings and export text (the CSV header is "Telly Rankings"), share cards, the public site and the privacy policy.
- **"Canon" stays as an internal term**: `CanonTier`, `CanonType`, `TellyCanonSwitcher`, the `/canon` route and `?canon=` query, Drift and SQL names, test fixtures, and the Dual-Canon segregation rule. Renaming them would be a large, risky diff with no user benefit, and it would break old links and shares.
- **Tagline**: "Your personal TV rankings. Ranked, shared, settled."
- **Widget keys that came from the label change** (`nav_tab_canon` is now `nav_tab_rankings`).
- Specs use "Rankings" for anything shown on screen. Where a spec says "canon" without quotes or a screen name, it means the internal concept.

## Consequences
- New copy must say "Rankings" (or "ranking", "list"), never "Canon".
- The 20 affected goldens were regenerated.
- Decisions 0003, 0004 and 0007 and the files in `docs/history/` keep the old word, because they record what was decided at the time.
