---
name: intake
description: >-
  Turn raw input from the owner (voice-note transcripts, brain dumps, bug reports,
  screenshots, review notes) into tracked GitHub issues in Telly's Inbox. Saves the
  raw text to docs/inbox/, splits it into atomic items, de-duplicates against
  existing issues, proposes the list, files what the owner confirms, and links
  everything back. Use whenever the owner shares ideas, complaints, bugs or
  feature thoughts — even phrased casually — rather than asking for code.
---

# Intake: raw input → Inbox issues

Rules of the system: [`docs/process/WORKFLOW.md`](../../../docs/process/WORKFLOW.md). Read it once per session if you haven't.

## 1. Save the raw input

Write the input verbatim to `docs/inbox/YYYY-MM-DD-<short-slug>.md` (today's date):

```markdown
# <Short title> (YYYY-MM-DD)

Source: voice note | chat | review | bug report

## Raw
<verbatim text, lightly cleaned only of timestamps and filler; never reworded>

## Filed as
(filled in at step 5)
```

Skip this step only for a single, one-line bug report.

## 2. Split into atomic items

Read the whole input before splitting. For each distinct point, record:

- **Kind**: `bug` · `enhancement` · `feature` · `design` · `idea` · `question` (needs an owner decision) · `decision` (the owner already decided something). Choose `idea` when the owner sounds unsure ("maybe", "I don't know if").
- **Area**: one or more `area:` labels from `tool/tracker/labels.json`.
- **Grouping**: points that belong to one feature become **one epic** plus notes, not many issues. Don't create sub-issues at intake. That is `shape`'s job.
- **Owner's words**: one short quote, so the issue keeps their intent.

Decisions the owner states outright (e.g. "get rid of curated canons") go into the relevant epic's body as **Owner decisions**. They don't get their own issues.

## 3. De-duplicate

```bash
python tool/tracker/tracker.py board                       # open work
gh issue list -R kandraos3/Telly --state all --search "<keywords>" --limit 20
```

If an item matches an open issue, plan a comment on that issue instead of a new one. If it matches a closed issue (a regression or a reopened request), file a new issue that links the old one.

## 4. Propose, then file

Show the owner a compact table: kind · title · labels · horizon guess · new or existing. Ask once and wait.

- **Skip the confirmation** if the owner already asked to "capture", "file" or "log" it. Then file directly and report what you filed.
- Bugs get a priority right away. Ideas and epics stay unprioritised until triage.

File each item:

```bash
python tool/tracker/tracker.py new --title "<Area>: <imperative summary>" \
  --labels "<type>,<area:...>[,pN-...]" --body-file <tmp body> --status Inbox [--horizon Now|Next|Later]
```

Write temporary body files in the scratchpad, not in the repo. Use the issue body template in WORKFLOW §6, with **Source** pointing at the inbox file. For ideas and epics, the *Proposed solution* section should give options and a recommendation. Fill in the owner's half-formed thought; don't just restate it.

## 5. Close the loop

- Fill in the inbox file's **Filed as** list: `- #N <title>` (and `- commented on #M` for de-duplicated items).
- If the input changes direction (new epics, re-ordered priorities), update `docs/ROADMAP.md`.
- Commit: `docs(inbox): capture <slug> (#first..#last)`. List all the issue numbers in the body with `Refs`.

## Don't

- Don't write code during intake.
- Don't mark anything Ready. Shaping does that.
- Don't drop items silently. If something isn't worth an issue, list it under **Not filed** in the inbox file with a one-line reason.
