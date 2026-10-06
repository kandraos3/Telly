---
name: ship
description: >-
  Implement a Ready Telly issue end to end — a task under an epic's Implement stage,
  a bug, an enhancement or a chore — and finish the Implement and Verify & release
  stages of epics. Claims it on the board, reads the spec, builds it, writes tests
  per the 70/20/10 pyramid, passes the quality gate, keeps the spec true, commits
  with the issue reference and keeps the board current. Use whenever writing or
  fixing code, when the owner says "work on #N", "fix this", "pick up the next
  thing", or when a Verify & release stage is Ready.
---

# Ship: Ready issue → verified commit

System rules: [`docs/process/WORKFLOW.md`](../../../docs/process/WORKFLOW.md). Engineering rules: [`AGENTS.md`](../../../AGENTS.md).

## 1. Pick and claim

```bash
python tool/tracker/tracker.py sync
python tool/tracker/tracker.py board --status Ready --horizon Now     # then Next
```
- Take the owner's named issue, or else the highest-priority Ready item in Now. Skip stage issues for Evaluate, Explore alternatives and Specify (those belong to `shape`), and anything whose `Blocked by` issue is still open.
- No concrete acceptance criteria? Run **`shape`** first. Exception: a bug whose fix is obvious. Write the criteria yourself and proceed.
- `python tool/tracker/tracker.py track <N> --status "In progress"` and `gh issue view <N> -R kandraos3/Telly --comments`.
- If the owner asks for code with no issue, file one first (`tracker.py new … --status "In progress"`).

## 2. Read the spec

Read every spec section the issue cites. Never guess tokens, dimensions, column types or formulas. If the spec is silent or wrong, fix it in this change and say so in the commit.

## 3. Build

Follow `AGENTS.md`: feature-first `lib/features/<feature>/`, Riverpod Notifier/AsyncNotifier only, Drift for local data, dual-canon segregation, Midnight Cathode tokens in **both** themes. Backend work goes through **`supabase-deploy`**.

## 4. Test and gate

Write tests at the right pyramid level ([spec](../../../docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md)):
- unit tests for logic, DAOs and parsers;
- widget/provider tests for UI and state;
- pgTAP for SQL (written, not run locally; CI runs it);
- `integration_test` for CUJs.

Bug fixes get a regression test that fails without the fix.

```bash
dart analyze --fatal-infos
bash tool/ft.sh            # flutter test (clears Windows' read-only test assets first)
```
Zero issues and zero failures. Never commit red.

## 5. Keep the docs true, then commit

- Update the spec where behaviour changed. File deferred or discovered work as new issues (under the same Implement stage if it belongs to the epic).
- Tick the issue's acceptance criteria (`gh issue edit <N> --body-file …`) or comment with what was verified.
- `git commit -m "<type>(<scope>): <description> (#N)" -m "Fixes #N" -m "Refs #<epic>"`. One issue per commit.
- Push only when the owner asked. Not pushed → leave the issue **In progress** and say it's committed locally. Pushed → run `tracker.py sync` (moves the closed issue to Done).

## 6. Finishing an epic's stages

- **Implement**: once all its tasks are closed (`sync` prints a hint), `tracker.py advance <implement stage#> --comment "Tasks #a–#b done"`.
- **Verify & release**: work through its checklist. That covers E2E/golden/a11y at the right level, both themes, and backend deployed. If a physical-device run is needed, file a `human-only` issue with exact steps. Set the spec's tracking line to `Status: shipped`, update `docs/ROADMAP.md`, and post a short owner-facing summary on the epic. Then `advance <verify stage#> --comment "<summary>"`, which closes the epic.
