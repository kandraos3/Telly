# 0006. Every change reaches a protected `main` through an auto-merging pull request

- **Date**: 2026-10-07
- **Status**: Accepted
- **Issue**: #158

## Context
Agents committed straight to `main`, and CI ran only after the code had landed, so a red build was already everyone's problem. `main` had no protection, every merge style was allowed, workflow actions were referenced by movable tags, and a backend deploy could run from code that was never merged. The repo is public, and the Idea form labels issues `idea`, so any GitHub user could make the *Tracker* Action create stage issues.

## Decision
- One branch (`<type>/<N>-<slug>`) and one pull request per issue. An epic's tasks each get their own PR; an epic never gets one PR.
- A ruleset on `main`: PR required, required checks `CI passed` and `PR title`, branch up to date, squash merges only, linear history, no force pushes or deletion, no bypass. 0 approvals, because agents use the owner's account and GitHub doesn't let an author approve their own PR.
- **Owner's choice: agents turn on auto-merge**, so a PR merges as soon as CI is green. The owner can hold any PR (draft, or auto-merge off). The Android emulator CUJ job is required like every other job.
- `CI passed` is one job that sums up all of `ci.yml`, so path-filtered jobs that are skipped count as passed and the required check never waits for a job that won't run.
- PR titles follow the commit convention with no `(#N)`; the squash appends the PR number and the body carries `Fixes #N` / `Refs #M`.
- Production runs merged code only: the deploy script and the challenge publisher refuse to write to `telly-prod` off an up-to-date, clean `main`.
- Hardening: actions pinned to commit SHAs and kept current by Dependabot (with pub), Dependabot security updates, private vulnerability reporting (`SECURITY.md`), and stage scaffolding in the Action limited to the owner's and collaborators' issues.

## Consequences
- Supersedes the "Don't push unless the owner asks" rule: pushing branches and opening PRs is routine; pushing to `main` is impossible.
- `tracker.py pr` opens PRs consistently; `tracker.py report` lists open PRs, their CI state and any that are behind `main`.
- A flaky emulator run now blocks a merge until it is re-run; flaky tests get filed as bugs instead of being ignored.
- No merge queue (not available for user-owned repos), so a PR behind `main` needs `gh pr update-branch`.
- With no human approval, CI is the only gate. Coverage of the checks matters more than before.
