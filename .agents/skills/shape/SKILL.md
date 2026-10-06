---
name: shape
description: >-
  Work the first three standard stages of a Telly idea or epic — Evaluate, Explore
  alternatives, Specify — producing a go/park/drop recommendation, design options
  and mockups, decision records, an approved spec in docs/, and the task sub-issues
  under the Implement stage. Use when an Evaluate/Explore alternatives/Specify stage
  issue is Ready, when the owner asks to evaluate, design, spec, plan or break down
  a feature, or when an issue lacks acceptance criteria.
---

# Shape: stages 1–3 of an idea/epic

System rules: [`docs/process/WORKFLOW.md`](../../../docs/process/WORKFLOW.md) §4. Stage checklists are in each stage issue's body (from `tool/tracker/stages.json`). Work through that checklist; this skill says how.

## Start

```bash
python tool/tracker/tracker.py sync
python tool/tracker/tracker.py stages <epic#>         # find the open stage
python tool/tracker/tracker.py track <stage#> --status "In progress"
gh issue view <epic#> -R kandraos3/Telly --comments   # owner's words, decisions, source inbox file
```

Read the linked inbox file and the specs and code the epic touches. Write down how things work **today** (with file references) before proposing anything.

## Asking the owner

Post one comment per decision: the question, 2–3 options with trade-offs, and **your recommendation**. Then:
```bash
gh issue edit <stage#> -R kandraos3/Telly --add-label needs-owner
```
Stop that stage and work on something else Ready. Once the owner replies in the thread, continue (`advance` removes the label).

## Stage 1: Evaluate

Write a comment covering: problem and audience, current behaviour, size (S/M/L/XL), risks, dependencies, recommendation.
- An obvious *go* (the owner already asked for it outright) → `advance <stage#> --comment "Go: <summary>"`.
- A product call (unsure value, cost, monetization, scope) → `needs-owner`. After the reply, advance with the matching `--outcome go|park|drop`.

## Stage 2: Explore alternatives

- Show 2–3 genuinely different options. For visual or IA work, **show them**. Make HTML mockups as a published artifact, or render real screens via `tool/site/`. Use the style guide tokens, in dark and light.
- Owner picks (`needs-owner`) unless one option is clearly dominant. Then write `docs/decisions/NNNN-*.md` and add it to the index.
- Only one sensible approach → `advance <stage#> --outcome skip --comment "<why>"`.

## Stage 3: Specify

1. Write or update the spec in `docs/` (the right `features/` or `design_system/` file, or a new one for a new domain). Add the tracking line `> Tracking: epic #N · Status: approved`. Cover screens, states (empty/loading/error/offline), data, formulas, tokens, both themes and the dual-canon split.
2. Create **task sub-issues under the Implement stage** (find its number with `stages`). Each task must be shippable in one session and testable:
   ```bash
   python tool/tracker/tracker.py new --title "<Area>: <task>" --labels "feature,area:<x>" \
     --body-file <scratch> --status Ready --horizon <epic's> --parent <implement stage#>
   ```
   Usual order: schema/backend → data/state → UI → E2E/golden. Bodies cite the spec section and say `Blocked by #M` where relevant.
3. Commit the docs: `docs(<area>): spec <feature> (#<epic>)`.
4. `advance <stage#> --comment "Spec: docs/...; tasks #a–#b"`. This makes Implement Ready and puts the epic In progress.

## Plain issues without stages

If a bug or enhancement lacks acceptance criteria, write them into its body and move it to Ready. No stages needed.
