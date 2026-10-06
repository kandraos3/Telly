---
name: shape
description: >-
  Take a Telly idea or epic from Inbox to Ready: research the current code, write or
  update the spec section, record decisions, produce design options or mockups when
  the work is visual, and split it into sub-issues with testable acceptance criteria.
  Use when the owner picks an epic or idea to work on next, asks to "design",
  "spec", "plan" or "break down" a feature, or when an issue lacks acceptance
  criteria.
---

# Shape: idea → spec → Ready sub-issues

Rules of the system: [`docs/process/WORKFLOW.md`](../../../docs/process/WORKFLOW.md).

## 1. Claim it

```bash
python tool/tracker/tracker.py track <N> --status Shaping
gh issue view <N> -R kandraos3/Telly --comments
```

Read the source inbox file if the issue links one.

## 2. Ground it

- Read the specs the issue touches, and find the code (`lib/features/<area>/`, `supabase/`).
- Write down how things work **today**, with file references, before proposing changes. Many complaints come from undocumented current behaviour.
- Check the design system ([style guide](../../../docs/design_system/01_DESIGN_PHILOSOPHY_AND_STYLE_GUIDE.md), [components](../../../docs/design_system/02_COMPONENT_LIBRARY_AND_PATTERNS.md)) so proposals reuse existing tokens and components.

## 3. Decide with the owner

- When there's a real choice, present **2–3 options with a recommendation**. Don't present a survey.
- For visual or IA work, show it. Make HTML mockups as a published artifact, or render real screens with the website screenshot pipeline (`tool/site/`). Keep the mockups' tokens consistent with the style guide (dark and light).
- Record every non-obvious choice in `docs/decisions/NNNN-*.md` and add it to the index in that folder's README.

## 4. Write the spec

- Update the relevant `docs/features/` / `docs/design_system/` section, or add a new file for a new domain. Add the tracking line at the top of each spec file you touch:
  `> Tracking: epic #N · Status: approved`
- The spec says **what** and **why** precisely: screens, states, data, formulas, tokens, and edge cases including empty, error, offline, light mode, and the dual-canon split. Tickets then say **how much** and **in what order**.

## 5. Break it down

Create sub-issues that are each shippable in one focused session, with tests:

```bash
python tool/tracker/tracker.py new --title "..." --labels "feature,area:..." \
  --body-file <tmp> --status Ready --horizon <same as epic> --parent <N>
```

Each body cites the exact spec section and lists acceptance criteria, including which tests at which pyramid level. Usual order: backend/schema → state/data → UI → E2E/golden. Note dependencies as `Blocked by #M` in the body.

Then label the parent `epic` if it isn't already, write the plan and the sub-issue list in a comment, and move the epic to **Ready**.

## 6. Commit

`docs(<area>): spec <feature> (#N)`. Include the spec, decision records and roadmap updates.
