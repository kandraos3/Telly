---
name: intake
description: >-
  Turn anything the owner shares (voice-note transcripts, brain dumps, complaints,
  bug reports, screenshots, "what if" thoughts, review notes) into tracked GitHub
  issues on the Telly board, and triage the Inbox. Saves raw text to docs/inbox/,
  splits it into atomic items, de-duplicates, files ideas (which get the standard
  stages automatically), bugs and enhancements, and links everything back. Use
  whenever the owner shares ideas, problems or feature thoughts, even casually and
  even mid-conversation, and whenever asked to triage, capture, file or log
  something.
---

# Intake: owner input → tracked issues

System rules: [`docs/process/WORKFLOW.md`](../../../docs/process/WORKFLOW.md). Read §1–§4 once per session. The owner is the PM: you do all the filing and tracking.

## 0. Sync first

```bash
python tool/tracker/tracker.py sync
```

## 1. Save the raw input

For anything longer than a one-line bug, write it verbatim to `docs/inbox/YYYY-MM-DD-<slug>.md`:

```markdown
# <Short title> (YYYY-MM-DD)

Source: voice note | chat | review | bug report

## Raw
<verbatim; strip only timestamps>

## Filed as
## Not filed
```

## 2. Split and classify

Read everything first, then make one entry per distinct point:

| The point is… | File as | Stages? |
|---|---|---|
| Broken, or differs from the spec | `bug` + priority | No |
| A small change with an obvious solution | `enhancement` | No |
| A new initiative, a design question, or touches several screens | **`idea`** | **Yes, automatic** |
| Something the owner already decided ("get rid of X") | A line under **Owner decisions** in the relevant idea | — |
| Something needing an owner answer before it can be filed | Ask in chat now | — |

Several points about one feature become **one idea**, with the points as notes. Keep one short quote of the owner's words per item.

## 3. De-duplicate

```bash
python tool/tracker/tracker.py board
gh issue list -R kandraos3/Telly --state all --search "<keywords>" --limit 20
```

If an item matches an open issue, comment on that issue. If it matches a closed one, file a new issue and link the old one.

## 4. File

Show the owner a compact table of what you'll file (kind · title · labels · horizon), unless they already said "capture", "file" or "log". In that case, file straight away and report afterwards.

```bash
python tool/tracker/tracker.py new --title "<Area>: <summary>" --labels "<type>,area:<x>[,pN-...]" \
  --body-file <scratch file> [--horizon Now|Next|Later]
```

- Write body files in the scratchpad, never in the repo. Use the template in WORKFLOW §8, with **Source** set to the inbox file.
- For ideas, *Proposed solution* gives a direction and the open questions. Don't just restate the owner. `new` creates the five stage sub-issues for you, with Evaluate set to Ready.
- Bugs get a priority now. If a bug is small and clear, `--status Ready`.

## 5. Triage mode ("triage the inbox", or items filed via the GitHub forms)

For each Inbox item:
- Set type, area and priority labels (`gh issue edit`).
- Ideas: check that their stages exist (`tracker.py stages N`; `sync` creates missing ones).
- Bugs and enhancements: write acceptance criteria into the body, then `track N --status Ready` (or `Backlog`).
- Duplicates and non-issues: `tracker.py close N --not-planned --comment "<why>"`.

## 6. Close the loop

- Fill in the inbox file's **Filed as** list (`- #N title`) and **Not filed** (with a reason).
- If direction changed, update `docs/ROADMAP.md`.
- Commit: `docs(inbox): capture <slug> (#a-#b)` with `Refs` for every issue.

Never write code during intake.
