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

## 6. Branches, pull requests and commits

Every change reaches `main` through a pull request ([decision 0006](../decisions/0006-branches-and-pull-requests.md)). A ruleset on `main` enforces it:

| Rule | Setting |
|---|---|
| Pull request required | Yes, with 0 approvals. Agents work through the owner's account, and GitHub never lets an author approve their own PR; CI is the gate |
| Required checks | **`CI passed`** (`ci.yml`; sums up every job, and a job skipped by the change filter counts as passed) and **`PR title`** (`pr-title.yml`) |
| Up to date with `main` | Required before merging |
| History | Squash merges only, linear, no force pushes, no deletion, nobody can bypass |

### The flow

1. **Claim**: `tracker.py track N --status "In progress"`.
2. **Branch** from an up-to-date `main`: `git switch main && git pull --ff-only && git switch -c <type>/<N>-<slug>` (e.g. `fix/152-edge-jwt`, `feat/52-because-you-ranked`, `docs/160-inbox-voice-note`).
3. **Commit** on the branch as often as useful. Run the quality gate (`dart analyze --fatal-infos`, `flutter test`) before each commit.
4. **Open the PR**: `tracker.py pr N --title "<type>(<scope>): <description>" [--refs <epic>] --body-file <summary> [--deploy]`. It pushes the branch, writes the body (from the same shape as the PR template) and turns on auto-merge.
5. **CI decides.** Green → GitHub squash-merges, `Fixes #N` closes the issue, and the branch is deleted. Then `tracker.py sync` (moves the issue to Done) and `git switch main && git pull --ff-only`.
   - **Red**: fix it on the branch and push; auto-merge stays on. A job that fails and then passes on a re-run with no change is flaky: file a `bug` for it.
   - **Behind `main`**: `gh pr update-branch <PR>`. GitHub doesn't update branches by itself, and `tracker.py report` flags PRs that are behind.
   - **Hold a merge** (the owner wants a look, or it must wait for something): `tracker.py pr … --draft`, or `gh pr merge <PR> --disable-auto`.

### What gets its own PR

- Each task sub-issue, bug, enhancement and chore: **one PR per issue, never one PR per epic**. Two tasks that can't pass CI separately were split wrong; merge them into one task.
- An `intake` capture (`docs(inbox): …`, with `--no-close`, so the filed issues stay open).
- A stage that produces files: the Explore alternatives mockups and decision record, the Specify spec. Stage PRs say `Refs #<stage>`; stages are still finished with `advance`, after the PR merges.

### Titles and commit messages

```
<type>(<scope>): <concise description>       ← PR title = the commit subject on main; GitHub appends (#PR)

Fixes #N          ← PR body; only when the PR completes the issue (a task, bug or chore)
Refs #M           ← related issues or the parent epic
```

`type`: `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `chore`, `ci`, `build`, `revert`. No `(#N)` in the title: issue and PR numbers share one sequence, and the PR links the issue. `tracker.py check-title` is the rule CI applies. Never put `Fixes` on a stage issue.

### Backend changes

Production only runs merged code. Migrations, edge functions and challenge content are deployed from `main`, level with `origin/main`, **after** the PR merges; the `supabase-deploy` script and `publish.py --publish` refuse anywhere else. A PR that needs a deploy ticks the *Backend* box (`--deploy`), and the agent that shipped it deploys once it merges. Migrations stay backward compatible (`supabase-deploy` §4), so the gap between merge and deploy is safe.

### Dependency updates

Dependabot opens weekly PRs for the pinned workflow actions and Dart packages, **minor and patch versions only**. Agents read the release notes during `report`, then `gh pr merge <PR> --auto --squash`. They go through the same checks as any change. Changes to `cache`, `upload-pages-artifact` or `deploy-pages` are only exercised by the site deploy after the merge, so check that run.

A **major** upgrade is never auto-merged: it gets its own issue, done on purpose with the migration notes read, when there's a reason (a security fix, a runtime GitHub is retiring, a feature we need). Security fixes arrive separately, through Dependabot security updates.

### Repository security

- Secret scanning with push protection; Dependabot alerts and security updates.
- Workflow actions are pinned to full commit SHAs; the default workflow token is read-only.
- PRs from outside contributors need approval before CI runs.
- Vulnerabilities are reported privately ([`SECURITY.md`](../../SECURITY.md)).
- The *Tracker* Action only scaffolds stages for issues from the owner or collaborators. Ideas from anyone else wait in the Inbox, and `sync` scaffolds them once triaged.

## 7. The skills and the tracker CLI

| Skill | Use when |
|---|---|
| **`intake`** | The owner shares anything: ideas, bugs, voice notes, screenshots. Also when triaging the Inbox |
| **`shape`** | Working stages 1–3 of an idea/epic, or an issue lacks acceptance criteria |
| **`ship`** | Implementing a Ready task, bug or chore, or doing stage 5 |
| **`supabase-deploy`** | Any backend migration, function, secret or "what's live" check |
| **`mobile-deploy`** | Running the app on a phone or emulator |

```bash
python tool/tracker/tracker.py report                 # owner summary: needs-you, in progress, ready, open PRs, recently done, epic stages
python tool/tracker/tracker.py sync                   # repair the board: closed→Done, missing items, stage statuses, archive old Done
python tool/tracker/tracker.py board [--status Ready] [--horizon Now] [--label bug]
python tool/tracker/tracker.py new --title "..." --labels bug,area:profile,p2-medium --body-file body.md [--status Ready] [--horizon Next] [--parent N]
python tool/tracker/tracker.py stages 44              # an epic's stages and tasks
python tool/tracker/tracker.py advance 55 --comment "Go: ..." [--outcome go|skip|park|drop]
python tool/tracker/tracker.py track 52 --status "In progress"
python tool/tracker/tracker.py close 54 --comment "Resolved by abc1234"
python tool/tracker/tracker.py labels                 # labels.json → GitHub
python tool/tracker/tracker.py pr 52 --title "feat(explore): …" --refs 44 --body-file summary.md [--deploy] [--draft] [--no-close]
python tool/tracker/tracker.py check-title "fix(theme): …"   # the PR title rule CI applies
```

Agents run `sync` before reading the board for planning, and after a pull request merges. The board's built-in "Item closed → Done" workflow is off; `sync` and `close` do that job.

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
