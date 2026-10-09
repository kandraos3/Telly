# Rename "Canon" to "Rankings" in user-facing text (2026-10-09)

Source: chat

## Raw

In Telly, a user's personal ranked list is called their "Canon" — borrowed from fandom terminology. This jargon is unfamiliar to most users; apps like Letterboxd, Trakt and Goodreads never use this word. It should stay as internal code (CanonTier, CanonType, /canon route, etc.), but all user-facing strings should use "Rankings" instead.

**Changes:**
1. Nav tab and screen title: "Canon" → "Rankings"
2. Auth tagline: "Your Personal TV Canon." → "Your Personal TV Rankings." (or "Rank what you watch. Share it. Settle it.")
3. Type labels: "Movie Canon" / "Series Canon" → "Movie Rankings" / "TV Rankings"
4. Progress text: onboarding "Calibrating your Movie Canon" → "Calibrating your Movie Rankings", etc.
5. Slot reveal: "Ranked #N in Your Movie Canon" → "Ranked #N in Your Movie Rankings"
6. Empty states: "No titles ranked in this Canon yet" → "No titles ranked in your Rankings yet"
7. Settings/export: "Export My Canon (CSV)" → "Export My Rankings (CSV)"
8. CSV header: "Telly Entertainment Canon" → "Telly Rankings"
9. Share cards: Wrapped studio ("Top 9 Movie Canon" → "Top 9 Movie Rankings")
10. Privacy text: "Anyone can see your Canon" → "Anyone can see your Rankings"
11. Specs: Update all design system and feature docs with the new terminology
12. Golden files: Regenerate nav bar and shell screen goldens

Internal identifiers (CanonTier, CanonType, canon_tier.dart, /canon route, SQL columns) remain unchanged.

**Scope:** ~40 user-facing strings across 20 lib/ files, 50+ test updates, 7 integration test updates, 300+ spec hits across 42 docs.

## Filed as
- #252 copy(rankings): rename Canon to Rankings in user-facing text

## Not filed
