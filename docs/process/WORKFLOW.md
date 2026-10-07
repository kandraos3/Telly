# How work is tracked in Telly

One home for each kind of information. Agents do all of the tracking. The owner is the product manager: they bring ideas, answer decisions and do the few hands-on tasks only a human can do.

| What | Lives in | Holds |
|---|---|---|
| **Work**: bugs, ideas, features, chores | [GitHub issues](https://github.com/kandraos3/Telly/issues) on the [**Telly** board](https://github.com/users/kandraos3/projects/1) | What is being done and where it stands |
| **Product truth**: how the app behaves | `docs/` specs (`features/`, `design_system/`, `technical_architecture/`, `adjacent_systems/`) | The current, intended behaviour |
| **Decisions**: why we chose something | [`docs/decisions/`](../decisions/) | One short record per product or architecture decision |
| **Raw thinking**: voice notes, brain dumps | [`docs/inbox/`](../inbox/) | The owner's words, verbatim, linked to the issues they produced |
| **Direction**: what's now, next, later | [`docs/ROADMAP.md`](../ROADMAP.md) | One page of themes linking to epics |
| **Agent instructions** | [`AGENTS.md`](../../AGENTS.md) + [`.agents/skills/`](../../.agents/skills/) | Rules and skills for every agent. `CLAUDE.md`, `GEMINI.md` and `.claude/skills/` are generated copies |

Sprints 1–6 are frozen in [`docs/history/`](../history/).

---

## 1. Who does what

| Owner (PM) | Agents |
|---|---|
| Shares ideas, bugs and voice notes, in chat or via the GitHub **Idea** / **Bug** forms | Capture them (`intake`), triage, file, de-duplicate |
| Answers questions on issues labelled **`needs-owner`** | Ask those questions: options plus a recommendation, in a comment |
| Does issues labelled **`human-only`** (consoles, stores, devices) | Write those issues with exact steps |
| Sets direction ("this is Now", "drop that") | Move cards, set horizons, update `docs/ROADMAP.md` |
| Reads the board, or asks "what's the status?" | Keep the board true (`tracker.py sync`) and summarise (`tracker.py report`) |

Agents never ask the owner to move a card, add a label, close an issue or write a ticket.

## 2. Tickets are issues

- **The issue number is the ticket ID.** Write `#52`, never a hand-made code. Sprint-era IDs (`FE-601`, `FE-AUTH-01`) are history.
- **Title**: `<Area or screen>: <imperative summary>`. Stage issues are titled automatically.
- Every issue gets **one type label**, **one or more `area:` labels**, and **a priority** once triaged. The label set lives in [`tool/tracker/labels.json`](../../tool/tracker/labels.json). Edit it there, then run `tracker.py labels`.

| Type | Use for |
|---|---|
| `bug` | Behaviour differs from spec, or is plainly broken |
| `enhancement` | Small improvement to something that exists (no stages needed) |
| `feature` | New capability small enough to need no stages |
| `design` | Design output: IA, layout, mockups |
| `idea` | A new initiative not yet evaluated. **Gets stages automatically** |
| `epic` | An initiative that passed evaluation (ideas are promoted automatically) |
| `chore` | Process, tooling, CI, ops |
| `stage` | A standard stage of an idea/epic (§4). Created by the tracker |
| `human-only` | Needs the owner: consoles, secrets, stores, devices |
| `needs-owner` | Waiting on an owner decision; the question is in the latest comment |

**Rule of thumb:** anything that needs a design choice or touches several screens is an `idea`. A bug, or a small change with an obvious solution, is a plain issue.

## 3. Status lives on the board, never in labels

| Status | Meaning |
|---|---|
| **Inbox** | Captured, not triaged |
| **Backlog** | Accepted but not actionable yet: a later stage, a parked idea, or blocked |
| **Shaping** | An idea/epic in its Evaluate, Explore alternatives or Specify stage |
| **Ready** | Actionable now; an agent can pick it up |
| **In progress** | An agent is on it, or an epic is in Implement / Verify |
| **Done** | Closed. Items closed more than 30 days ago are archived by `sync` |

**Horizon** (Now / Next / Later) says when we intend to do something. It replaces sprints. Agents pick work from **Ready + Now** first.

Board views: **Board** (columns by status including Done; stage cards hidden, so it shows epics, bugs and tasks), **Needs you** (`needs-owner` + `human-only`), **Roadmap** (ideas and epics with sub-issue progress), **Inbox**, **All** (everything open, including stages).

## 4. Ideas and epics follow five standard stages

When an issue is labelled `idea` or `epic`, five **stage sub-issues** are created under it from [`tool/tracker/stages.json`](../../tool/tracker/stages.json). This happens through `tracker.py new`, or through the *Tracker* GitHub Action for ideas filed on GitHub.

| # | Stage | Skill | Outcome |
|---|---|---|---|
| 1 | **Evaluate** | `shape` | Go / park / drop, with reasons. Owner decides product calls (`needs-owner`). On *go*, `idea` becomes `epic` |
| 2 | **Explore alternatives** | `shape` | 2–3 options, mockups if visual, owner's pick, decision record. The approved mockup is saved in `docs/design_system/mockups/`. Skippable with a reason |
| 3 | **Specify** | `shape` | Spec section in `docs/`, plus **task sub-issues under the Implement stage** |
| 4 | **Implement** | `ship` | All task sub-issues done. It can't be advanced while any task is open |
| 5 | **Verify & release** | `ship` | End-to-end checks, both themes, spec marked shipped, roadmap updated, summary for the owner |

The project-specific work lives in **task sub-issues of stage 4**. They are ordinary issues (`feature`/`bug`/`chore` + areas), each shippable in one session with its own acceptance criteria.

Stages are finished with `tracker.py advance <stage#> --comment "…"`, never closed by hand. `advance` opens the next stage, keeps the epic's status right, and closes the epic after stage 5. Outcomes:

- `--outcome go` (default)
- `--outcome skip` (stage not needed; reason required)
- `--outcome park` (epic to Backlog/Later)
- `--outcome drop` (closes the epic and its remaining stages as not planned)

## 5. Specs stay true

- A change in behaviour **updates its spec in the same commit**. If the spec and the code disagree, that is a bug; file it.
- Spec files touched by an epic carry a tracking line at the top: `> Tracking: epic #NN · Status: draft | approved | shipped`
- Non-obvious decisions get a record in `docs/decisions/NNNN-short-title.md` (template in that folder's README).

## 6. Commits

```
<type>(<scope>): <concise description> (#N)

Fixes #N          ← only when the commit completes the issue (a task, bug or chore)
Refs #M           ← related issues or the parent epic
```

`type`: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`. One issue per commit where possible. The quality gate (`dart analyze --fatal-infos`, `flutter test`) must pass before committing code. Never put `Fixes` on a stage issue. Stages are finished with `advance`.

## 7. The skills and the tracker CLI

| Skill | Use when |
|---|---|
| **`intake`** | The owner shares anything: ideas, bugs, voice notes, screenshots. Also when triaging the Inbox |
| **`shape`** | Working stages 1–3 of an idea/epic, or an issue lacks acceptance criteria |
| **`ship`** | Implementing a Ready task, bug or chore, or doing stage 5 |
| **`supabase-deploy`** | Any backend migration, function, secret or "what's live" check |
| **`mobile-deploy`** | Running the app on a phone or emulator |

```bash
python tool/tracker/tracker.py report                 # owner summary: needs-you, in progress, ready, recently done, epic stages
python tool/tracker/tracker.py sync                   # repair the board: closed→Done, missing items, stage statuses, archive old Done
python tool/tracker/tracker.py board [--status Ready] [--horizon Now] [--label bug]
python tool/tracker/tracker.py new --title "..." --labels bug,area:profile,p2-medium --body-file body.md [--status Ready] [--horizon Next] [--parent N]
python tool/tracker/tracker.py stages 44              # an epic's stages and tasks
python tool/tracker/tracker.py advance 55 --comment "Go: ..." [--outcome go|skip|park|drop]
python tool/tracker/tracker.py track 52 --status "In progress"
python tool/tracker/tracker.py close 54 --comment "Resolved by abc1234"
python tool/tracker/tracker.py labels                 # labels.json → GitHub
```

Agents run `sync` before reading the board for planning, and after pushing commits. The board's built-in "Item closed → Done" workflow is off; `sync` and `close` do that job.

## 8. Issue body template

```markdown
### Summary
What and why, in two or three sentences.

### Context
- **Screen / code**: `lib/features/...`
- **Spec**: `docs/...` §N   (or "to be written in the Specify stage")
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

## 9. Changing this system

Edit this file, `AGENTS.md`, `.agents/skills/*` or `tool/tracker/*`, then run `python tool/agents/sync.py`. CI fails if `CLAUDE.md`, `GEMINI.md` or `.claude/skills/` drift from their sources.
