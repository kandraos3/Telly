# How work is tracked in Telly

One home for each kind of information. Agents and humans follow the same rules.

| What | Lives in | Holds |
|---|---|---|
| **Work** — bugs, ideas, features, chores | [GitHub issues](https://github.com/kandraos3/Telly/issues) on the [**Telly** board](https://github.com/users/kandraos3/projects/1) | What is being done and where it stands |
| **Product truth** — how the app behaves | `docs/` specs (`features/`, `design_system/`, `technical_architecture/`, `adjacent_systems/`) | The current, intended behaviour |
| **Decisions** — why we chose something | [`docs/decisions/`](../decisions/) | One short record per product or architecture decision |
| **Raw thinking** — voice notes, brain dumps | [`docs/inbox/`](../inbox/) | The owner's words, verbatim, linked to the issues they produced |
| **Direction** — what's now, next, later | [`docs/ROADMAP.md`](../ROADMAP.md) | One page of themes linking to epics |

Sprints 1–6 are frozen in [`docs/history/`](../history/). Nothing new is added there.

---

## 1. Tickets are issues

- **The issue number is the ticket ID.** Write `#52`, never a hand-made code like `FE-EXPLORE-04`. Old IDs (`FE-601`, `FE-AUTH-01`, …) stay valid as history.
- **Title**: `<Area or screen>: <imperative summary>`, e.g. `Explore: add "Because you ranked X" rows`.
- **Epics** are issues labelled `epic`. They link to a spec, and their work items are attached as GitHub **sub-issues**. Most features are one epic with its sub-issues: design → backend → frontend → QA.
- Every issue gets **one type label**, **one or more `area:` labels**, and **a priority** once it leaves the Inbox. The label set lives in [`tool/tracker/labels.json`](../../tool/tracker/labels.json). Change it there and run `python tool/tracker/tracker.py labels`.

| Type | Use for |
|---|---|
| `bug` | Behaviour differs from spec, or is plainly broken |
| `enhancement` | Improves something that exists |
| `feature` | New capability |
| `design` | Needs design output: IA, layout, mockups |
| `idea` | Not committed to. May be shaped, parked or closed |
| `epic` | Parent of sub-issues |
| `chore` | Process, tooling, CI, ops |
| `human-only` | Needs the owner: consoles, secrets, stores, devices |

## 2. Status lives on the board, never in labels

The board's **Status** field is the lifecycle:

```
Inbox ──► Shaping ──► Ready ──► In progress ──► Done
  │                                 
  └──► closed as wontfix / duplicate (ideas we drop)
```

| Status | Meaning | Exit condition |
|---|---|---|
| **Inbox** | Captured, untriaged | Owner or agent triages: labels and priority set, or closed |
| **Shaping** | Being specified | Spec section written or updated, decision recorded if any, acceptance criteria in the issue |
| **Ready** | Can be picked up | All acceptance criteria are concrete and testable |
| **In progress** | Being built | Quality gate green, spec still true, commit references `#N` |
| **Done** | Merged and verified | — (closing an issue moves it here automatically) |

**Horizon** (Now / Next / Later) is a separate field that says when we intend to do something. It replaces sprints. Bugs usually skip Shaping when the fix is obvious.

Board views: **Board** (open work as columns), **Inbox**, **Roadmap** (open, triaged work), **Epics**, **All**.

## 3. Specs stay true

- A change in behaviour **updates its spec in the same commit**. If the spec and the code disagree, that is a bug in one of them, so file it.
- New features get a spec before code. Usually that's a new or updated section in an existing `docs/features/` or `docs/design_system/` file. A brand-new file is only needed for a new domain. The epic links to that section.
- Spec files begin with a one-line tracking note once they're touched by an epic:
  `> Tracking: epic #NN · Status: draft | approved | shipped`
- Decisions that are not obvious from the spec (removing a feature, choosing between designs, policy calls) get a record in `docs/decisions/NNNN-short-title.md`. Use the template in that folder's README.

## 4. Commits and PRs

```
<type>(<scope>): <concise description> (#N)

Fixes #N          ← only when the commit completes the issue
Refs #M           ← related issues or the parent epic
```

`type` is one of `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`. `scope` is the area (`explore`, `ranking`, `nav`, …). One issue per commit where possible. The quality gate (`dart analyze --fatal-infos`, `flutter test`) must pass before committing code.

When an issue is resolved by a commit that isn't pushed yet, leave it open in **In progress**. `Fixes #N` closes it on push. If it was resolved some other way, close it with a comment naming the commit.

## 5. The agent skills

| Skill | When | Does |
|---|---|---|
| **`intake`** | The owner shares a voice note, brain dump, bug report or screenshot | Saves the raw text to `docs/inbox/` and splits it into atomic items. Checks for existing issues that cover the same thing, proposes the list, files the confirmed items in **Inbox**, and links them back from the inbox file |
| **`shape`** | An idea or epic is picked for work | Writes or updates the spec, records decisions, and creates sub-issues with acceptance criteria. Moves them to **Ready** |
| **`ship`** | A Ready issue is picked up | Moves it to In progress, reads the spec, implements, tests, runs the gate, updates the spec, and commits with `Fixes #N` |

The CLI helper used by all three:

```bash
python tool/tracker/tracker.py board                          # open work, grouped by status
python tool/tracker/tracker.py board --status Inbox
python tool/tracker/tracker.py new --title "..." --labels bug,area:profile,p2-medium --body-file body.md [--status Ready] [--horizon Next] [--parent 41]
python tool/tracker/tracker.py track 52 --status "In progress"
python tool/tracker/tracker.py sub 41 52 53 54                # attach sub-issues to epic #41
python tool/tracker/tracker.py labels                         # sync labels.json → GitHub
```

## 6. Issue body template

```markdown
### Summary
What and why, in two or three sentences.

### Context
- **Screen / code**: `lib/features/...`
- **Spec**: `docs/...` §N   (or "to be written while shaping")
- **Source**: docs/inbox/YYYY-MM-DD-....md   (when it came from a brain dump)

### Current behaviour
(bugs and enhancements)

### Proposed solution
Concrete plan. For ideas: options and a recommendation.

### Acceptance criteria
- [ ] Verifiable outcome
- [ ] Tests at the right pyramid level
- [ ] Spec updated
```
