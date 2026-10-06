---
name: ship
description: >-
  Implement a Ready Telly issue end to end: claim it on the board, read its spec,
  build it, write tests per the 70/20/10 pyramid, pass the quality gate, keep the
  spec true, and commit with the issue reference. Use whenever starting, working on
  or finishing a development issue, fixing a bug, or when the owner says "work on
  #N", "pick up the next thing", or "fix this".
---

# Ship: Ready issue → verified commit

Rules of the system: [`docs/process/WORKFLOW.md`](../../../docs/process/WORKFLOW.md). Engineering rules: [`AGENTS.md`](../../../AGENTS.md).

## 1. Pick and claim

- If the owner named an issue, use it. Otherwise list Ready work and take the highest priority in the **Now** horizon. Check that nothing it's `Blocked by` is still open:
  ```bash
  python tool/tracker/tracker.py board --status Ready
  ```
- If the issue has no concrete acceptance criteria, stop and run **`shape`** first. Exception: a bug whose fix is obvious. Write the criteria into the issue yourself and proceed.
- Claim it:
  ```bash
  python tool/tracker/tracker.py track <N> --status "In progress"
  gh issue view <N> -R kandraos3/Telly --comments
  ```

## 2. Read the spec

Read every spec section the issue cites. Never guess tokens, dimensions, column types or formulas; take them from the spec. If the spec is silent or wrong, fix the spec as part of this issue and say so in the commit.

## 3. Build

Conventions are in `AGENTS.md`: feature-first folders under `lib/features/<feature>/`, Riverpod Notifier/AsyncNotifier only, Drift for local data, dual-canon segregation, and Midnight Cathode tokens in **both** dark and light themes. Backend changes go through the **`supabase-deploy`** skill.

## 4. Test

Write tests at the right level of the pyramid ([spec](../../../docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md)): unit for logic/DAOs/parsers, widget/provider for UI and state, pgTAP for SQL (written, not run locally; CI runs it), and `integration_test` only for CUJs. Bug fixes get a regression test that fails without the fix.

## 5. Gate

```bash
dart analyze --fatal-infos
bash tool/ft.sh        # flutter test (clears Windows' read-only test assets first)
```

Zero issues and zero failures. Don't commit red.

## 6. Keep the docs true

- Update the spec where behaviour changed, and its tracking line (`Status: shipped` once the epic's last sub-issue lands).
- Tick the acceptance criteria in the issue body (`gh issue edit <N> --body-file …`) or comment with what was verified and anything deviated or deferred. File deferred work as new issues, never as silent TODOs.

## 7. Commit

```bash
git commit -m "<type>(<scope>): <description> (#N)" -m "Fixes #N" [-m "Refs #<epic>"]
```

One issue per commit. Don't push unless the owner asked. Pushing closes the issue via `Fixes`. If not pushing, leave it **In progress** and tell the owner it's committed locally.
