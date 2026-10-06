# 0001. GitHub issues are the ticket system; the sprint roadmap is frozen

- **Date**: 2026-10-06
- **Status**: Accepted
- **Issue**: #40

## Context
Sprints 1–6 were tracked in `docs/PROJECT_ROADMAP_AND_SPRINT_PLAN.md`, which grew to 2,300+ lines. From Sprint 6 on, feedback was also filed as GitHub issues and then copied back into the roadmap. The two drifted apart: closed issues still carried `status:ready`. Ticket IDs were hand-numbered per sprint (`FE-601`, `FE-AUTH-01`), so parallel agents could pick the same number. The next phase of work is driven by voice-note brain dumps, which need a place to land before they're fully specified.

## Decision
- GitHub issues are the only tickets. The issue number is the ID.
- The **Telly** project board holds status (Inbox → Shaping → Ready → In progress → Done) and horizon (Now / Next / Later). Status labels are removed.
- `docs/` remains the source of truth for behaviour; specs are updated in the same commit as behaviour changes.
- Raw input is kept verbatim in `docs/inbox/`; decisions in `docs/decisions/`.
- The sprint roadmap and Sprint 6 handoff are moved to `docs/history/` unchanged. Their open items were carried over as issues.
- Agents use the `intake`, `shape` and `ship` skills, which replace `issue-manager` and `ticket-runner`.

## Consequences
- Rules 1, 5 and 6 in `AGENTS.md` changed: anchor to `#N`, account progress on the board, commit as `type(scope): … (#N)`.
- `tool/handoff/complete_ticket.py` and the one-off issue-creation script are deleted. `tool/tracker/tracker.py` replaces them.
- Sprint-era IDs remain searchable in git history and `docs/history/`.
