---
name: supabase-deploy
description: Safe, non-interactive deployment of Telly's Supabase backend (telly-prod) — status checks, migration dry-runs and pushes with safety guards, edge-function deploys with secret checks, and local pgTAP runs. Use whenever a change touches supabase/migrations, supabase/functions or supabase secrets, when asked to deploy/apply/push the backend, or to check what is live. Also defines how to author migrations so they deploy safely.
---

# Supabase Deploy Skill: Telly Backend Deployment Guide

One script does every remote operation. **The only manual step is `supabase login`** (it opens a browser). The CLI then reaches the database through a temporary login role, so no database password, connection string or `.env` secret is ever needed.

| Item | Value |
|---|---|
| Project | `telly-prod`, ref `cdbfixrttnysqvtulufm` (us-east-1). The repo is linked to it. |
| Script | [`.agents/skills/supabase-deploy/scripts/supabase_deploy.ps1`](file:///c:/Users/karla/Desktop/SeriesBeli/.agents/skills/supabase-deploy/scripts/supabase_deploy.ps1) (mirrored under `.claude/skills/`) |
| Migrations | `supabase/migrations/YYYYMMDDHHMMSS_<snake_name>.sql` |
| DB tests | `supabase/tests/database/NNN_<name>.test.sql` (pgTAP, run in CI) |
| Edge functions | `supabase/functions/<name>/index.ts` + `handler.ts`; shared code in `_shared/`; Deno tests in `tests/` (CI) |

---

## 1. Commands

Run from the repo root:

```powershell
$S = ".agents/skills/supabase-deploy/scripts/supabase_deploy.ps1"
powershell -ExecutionPolicy Bypass -File $S                       # status (read-only)
powershell -ExecutionPolicy Bypass -File $S -Action plan          # + db push --dry-run (read-only)
powershell -ExecutionPolicy Bypass -File $S -Action push          # apply pending migrations + verify
powershell -ExecutionPolicy Bypass -File $S -Action functions     # deploy changed edge functions
powershell -ExecutionPolicy Bypass -File $S -Action functions -Functions tmdb-details,tmdb-search
powershell -ExecutionPolicy Bypass -File $S -Action deploy        # push, then changed functions
powershell -ExecutionPolicy Bypass -File $S -Action test          # local pgTAP (Docker Desktop required)
```

| Flag | Meaning |
|---|---|
| `-Functions changed` (default) | Deploys functions that were never deployed, or whose folder or `_shared/` has a commit or uncommitted edit newer than the live version. |
| `-Functions all` / `name1,name2` | Explicit selection. |
| `-AllowFullSchema` | Allows a push into a remote with **no** migration history. Only for a brand-new project. |
| `-ProjectRef <ref>` | Targets a different project deliberately. |

Exit codes:
- `0`: OK.
- `1`: failure.
- `2`: **not logged in**. Ask the user to run `supabase login`, then re-run.
- `3`: refused as unsafe. The message says why; fix the cause and never bypass it.

## 2. What the script guarantees

- **Never hangs on a prompt.** stdin is closed and `--yes` is passed.
- **Right project.** It verifies the login, that the project is visible and `ACTIVE_HEALTHY`, and that the repo is linked to the expected ref. It refuses a mismatched link.
- **Migration guards.** It refuses to push when:
  - the remote has migrations missing locally (drift);
  - a pending migration is older than the newest remote one (out of order);
  - the remote history is empty (would re-run the whole schema).
- **Safe push sequence.** It always dry-runs first, then pushes and re-lists to confirm nothing is still pending. Supabase's platform daily backups are the recovery path; the script takes no local backup.
- **Edge functions.** It bundles with `--use-api`, so Docker isn't needed. It checks each function's `Deno.env.get(...)` secrets against `supabase secrets list` and skips any function whose secret is missing. `TMDB_ACCESS_TOKEN` or `TMDB_API_KEY` satisfies the TMDB requirement; `WATCHMODE_API_KEY` is optional; the `SUPABASE_*` variables are provided by the platform.

## 3. Agent protocol

1. **Always start with `status`.** It is read-only and shows pending migrations, function drift and missing secrets.
2. **Get the user's go-ahead before writing to `telly-prod`** (`push`, `functions`, `deploy`), unless they asked for a deploy in the current conversation. Show them the `plan` output first.
3. **Deploy the backend before releasing an app build** that depends on it. Old apps must keep working against the new database (see §4).
4. **Exit code 2:** tell the user to run `supabase login` and wait. Never ask for tokens or passwords.
5. **Missing secret:** ask the user for the value and set it with `supabase secrets set NAME=value --project-ref cdbfixrttnysqvtulufm`. Never echo a secret value back, and never write one to a file.
6. **Report what happened:** applied migration file names, deployed function versions, and anything skipped and why.
7. **Never run** any of the following against the remote:
   - `supabase db reset --linked`
   - `supabase db push --include-all`
   - `supabase functions deploy --prune`
   - `supabase migration repair`, unless the user explicitly asks
   - hand-written SQL in the dashboard as a substitute for a migration

## 4. Authoring migrations so they deploy safely

- **New file per change.** Use the next timestamp after the newest file in `supabase/migrations/` (the series is `20261010000000`, `…000100`, … `…001000`, so the next is `…001100`). Never edit a migration that is already applied; `status` shows which ones are.
- **Header comment.** Include the migration file name, the ticket ID and the reason for the change.
- **Backward compatible.** Already-installed apps keep calling the old shape:
  - New RPC parameters get a `DEFAULT` that preserves old behaviour (e.g. `p_broadcast BOOLEAN DEFAULT TRUE`).
  - Never rename or remove a parameter, column or return field that a shipped app reads.
- **Changing a function signature.** `CREATE OR REPLACE` can't add parameters; it creates an overload, and PostgREST then fails on ambiguous calls. Instead:
  1. `DROP FUNCTION public.f(<old arg types>);`
  2. `CREATE OR REPLACE FUNCTION public.f(<new args>) …` with the full body.
  3. `REVOKE ALL ON FUNCTION public.f(<new arg types>) FROM PUBLIC;`
  4. `GRANT EXECUTE ON FUNCTION public.f(<new arg types>) TO authenticated;`
- **RPC conventions.** Follow `20261010000200_ranking_rpcs.sql`:
  - `LANGUAGE plpgsql SECURITY DEFINER SET search_path = public`
  - `PERFORM public._require_user();` (or `v_user UUID := public._require_user()`) as the first statement
  - exclude soft-deleted users (`JOIN public.users u … AND NOT u.is_deleted`) from community aggregates
- **Session flags** passed to triggers use `set_config('telly.<name>', …, true)` and are reset before the function returns (see `20261010000900_private_logging.sql`).
- **One pgTAP test per migration.** Name it `supabase/tests/database/NNN_<name>.test.sql`, continuing the numbering (next is `014`). Wrap it in `BEGIN; … SELECT * FROM finish(); ROLLBACK;` with a `plan(n)` that matches the assertion count, and use the seeded titles from `supabase/seed.sql` (e.g. 155, 238, 680, 1396, 76331, 8592, 66732).
- **Challenge content** (`content/`, #143) is data, not migrations: publish it with `python tool/challenges/publish.py --dry-run` then `--publish`. It runs through the same `supabase login` (`supabase db query --linked`), so treat `--publish` like a push: confirm first unless the owner asked to deploy in this session.
- **Dart side.** When an RPC gains a parameter, send it from `lib/core/sync/mutation_transport.dart` (or the repository) and extend the transport/repository unit test.

## 5. Authoring edge functions

- Keep request logic in `handler.ts` with injected deps (`fetch`, tokens, `store`) and a thin `index.ts` that calls `Deno.serve`.
- Add a Deno test to `supabase/functions/tests/edge_functions.test.ts` using `fakeFetch` / `MemoryStore`. CI runs `deno lint`, `deno check */index.ts` and `deno test`.
- Read secrets only through `Deno.env.get("NAME")`, so the script's secret check finds them.

## 6. Troubleshooting

| Symptom | Fix |
|---|---|
| Exit 2 / "Not logged in" | The user runs `supabase login`. |
| Exit 3 "linked to …" | The repo is linked elsewhere. Confirm the intended target with the user, then pass `-ProjectRef`. |
| Exit 3 "REMOTE-ONLY" | Someone applied a migration not in this branch. Pull it (`git pull`, or `supabase migration fetch --linked` with the user's OK) before pushing. |
| Exit 3 "older than the newest remote" | Rename the pending file to a newer timestamp (it isn't applied yet, so renaming is safe). |
| Function shows "missing secret" | See §3.5. |
| `-Action test` fails to start | Docker Desktop must be running; ports come from `supabase/config.toml` (643xx). |
