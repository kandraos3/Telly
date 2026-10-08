"""Telly work tracker: the only way agents touch issues and the board.

Conventions: docs/process/WORKFLOW.md. Stage definitions: tool/tracker/stages.json.
Issues on kandraos3/Telly are the tickets; the "Telly" user project (#1) holds
Status and Horizon. Every idea/epic gets standard stage sub-issues.

  python tool/tracker/tracker.py report                       # owner/PM summary
  python tool/tracker/tracker.py board [--status S] [--horizon H] [--label L]
  python tool/tracker/tracker.py new --title T --labels a,b [--body-file F] [--status S] [--horizon H] [--parent N]
  python tool/tracker/tracker.py track N [N ...] [--status S] [--horizon H]
  python tool/tracker/tracker.py stages N                     # an epic's stages and tasks
  python tool/tracker/tracker.py scaffold N [--no-board]      # create missing stage sub-issues
  python tool/tracker/tracker.py advance STAGE --comment C [--outcome go|skip|park|drop]
  python tool/tracker/tracker.py close N [--comment C] [--not-planned]
  python tool/tracker/tracker.py sub PARENT CHILD [CHILD ...]
  python tool/tracker/tracker.py pr N --title T [--refs M ...] [--body-file F] [--deploy] [--draft] [--no-close]
  python tool/tracker/tracker.py check-title T                # PR title follows the commit convention
  python tool/tracker/tracker.py sync [--archive-days D]      # repair board drift
  python tool/tracker/tracker.py labels [--dry-run]

Needs `gh` logged in with the `project` scope (`gh auth refresh -s project`).
"""

import argparse
import datetime
import json
import pathlib
import re
import subprocess
import sys
import tempfile

OWNER = "kandraos3"
REPO = "kandraos3/Telly"
PROJECT = "1"
STATUSES = ["Inbox", "Backlog", "Shaping", "Ready", "In progress", "Done"]
HORIZONS = ["Now", "Next", "Later"]
HERE = pathlib.Path(__file__).parent
STAGES = json.loads((HERE / "stages.json").read_text(encoding="utf-8"))
STAGE_KEYS = [s["key"] for s in STAGES["stages"]]
STAGE_RE = re.compile(r"<!-- telly-stage:(\w+) parent:(\d+) -->")
LOCAL_SCAFFOLD = "<!-- telly-scaffold: local -->"

sys.stdout.reconfigure(encoding="utf-8")


# ── gh plumbing ──────────────────────────────────────────────────────────────

def gh(*args, parse=False):
    out = subprocess.run(["gh", *args], capture_output=True, text=True, encoding="utf-8")
    if out.returncode != 0:
        sys.exit(f"gh {' '.join(args)} failed:\n{out.stderr.strip()}")
    return json.loads(out.stdout) if parse else out.stdout.strip()


def git(*args):
    out = subprocess.run(["git", *args], capture_output=True, text=True, encoding="utf-8")
    if out.returncode != 0:
        sys.exit(f"git {' '.join(args)} failed:\n{out.stderr.strip()}")
    return out.stdout.strip()


def issue(n):
    return gh("api", f"repos/{REPO}/issues/{n}", parse=True)


def sub_issues(n):
    return gh("api", f"repos/{REPO}/issues/{n}/sub_issues?per_page=100", parse=True)


def label_names(i):
    return [l["name"] for l in i.get("labels", [])]


def stage_of(i):
    """(stage key, parent number) when the issue is a stage sub-issue, else None."""
    m = STAGE_RE.search(i.get("body") or "")
    return (m.group(1), int(m.group(2))) if m else None


def stage_issues(parent):
    """The parent's stage sub-issues in stage order, keyed by stage key."""
    found = {}
    for child in sub_issues(parent):
        s = stage_of(child)
        if s and s[1] == parent:
            found[s[0]] = child
    return {k: found[k] for k in STAGE_KEYS if k in found}


def close_issue(n, comment=None, not_planned=False):
    args = ["issue", "close", str(n), "-R", REPO, "--reason", "not planned" if not_planned else "completed"]
    if comment:
        args += ["--comment", comment]
    gh(*args)


# ── board ────────────────────────────────────────────────────────────────────

def gql(query, **variables):
    args = ["api", "graphql", "-f", f"query={query}"]
    for k, v in variables.items():
        args += ["-F" if isinstance(v, int) else "-f", f"{k}={v}"]
    return gh(*args, parse=True)["data"]


_FIELD_VALUES = """
    s: fieldValueByName(name: "Status") { ... on ProjectV2ItemFieldSingleSelectValue { name } }
    h: fieldValueByName(name: "Horizon") { ... on ProjectV2ItemFieldSingleSelectValue { name } }"""


class Board:
    """The Telly project, via small targeted GraphQL queries (gh project item-list is far too expensive)."""

    def __init__(self):
        data = gql("""query($login: String!, $number: Int!) { user(login: $login) { projectV2(number: $number) {
            id fields(first: 50) { nodes { ... on ProjectV2SingleSelectField { id name options { id name } } } } } } }""",
                   login=OWNER, number=int(PROJECT))["user"]["projectV2"]
        self.project_id = data["id"]
        self.fields = {f["name"]: f for f in data["fields"]["nodes"] if f}

    def state(self, n):
        """(item id, status, horizon) for an issue, adding it to the board if missing."""
        owner, name = REPO.split("/")
        data = gql(f"""query($owner: String!, $name: String!, $n: Int!) {{ repository(owner: $owner, name: $name) {{
            issue(number: $n) {{ id projectItems(first: 20) {{ nodes {{ id project {{ id }} {_FIELD_VALUES} }} }} }} }} }}""",
                   owner=owner, name=name, n=int(n))["repository"]["issue"]
        for node in data["projectItems"]["nodes"]:
            if node["project"]["id"] == self.project_id:
                return node["id"], (node.get("s") or {}).get("name"), (node.get("h") or {}).get("name")
        added = gql("""mutation($p: ID!, $c: ID!) { addProjectV2ItemById(input: {projectId: $p, contentId: $c}) {
            item { id } } }""", p=self.project_id, c=data["id"])
        return added["addProjectV2ItemById"]["item"]["id"], None, None

    def item(self, n):
        return self.state(n)[0]

    def set(self, item_id, field, value):
        options = {o["name"].lower(): o["id"] for o in self.fields[field]["options"]}
        if value.lower() not in options:
            sys.exit(f"{field} must be one of: {', '.join(o['name'] for o in self.fields[field]['options'])}")
        gql("""mutation($p: ID!, $i: ID!, $f: ID!, $o: String!) { updateProjectV2ItemFieldValue(input: {
            projectId: $p, itemId: $i, fieldId: $f, value: {singleSelectOptionId: $o}}) { clientMutationId } }""",
            p=self.project_id, i=item_id, f=self.fields[field]["id"], o=options[value.lower()])

    def track(self, n, status=None, horizon=None):
        item_id, current_status, current_horizon = self.state(n)
        if status and status != current_status:
            self.set(item_id, "Status", status)
        if horizon and horizon != current_horizon:
            self.set(item_id, "Horizon", horizon)
        return item_id

    def archive(self, item_id):
        gql("""mutation($p: ID!, $i: ID!) { archiveProjectV2Item(input: {projectId: $p, itemId: $i}) {
            clientMutationId } }""", p=self.project_id, i=item_id)

    def items(self):
        """Every non-archived issue on the board as flat dicts."""
        out, cursor = [], None
        while True:
            after = f', after: "{cursor}"' if cursor else ""
            data = gql(f"""query($id: ID!) {{ node(id: $id) {{ ... on ProjectV2 {{ items(first: 100{after}) {{
                pageInfo {{ hasNextPage endCursor }}
                nodes {{ id {_FIELD_VALUES}
                  content {{ ... on Issue {{ number title state closedAt repository {{ nameWithOwner }}
                    labels(first: 20) {{ nodes {{ name }} }} }} }} }} }} }} }} }}""", id=self.project_id)
            page = data["node"]["items"]
            for node in page["nodes"]:
                c = node.get("content") or {}
                if "number" not in c:
                    continue
                out.append({
                    "id": node["id"], "status": (node.get("s") or {}).get("name"),
                    "horizon": (node.get("h") or {}).get("name"), "number": c["number"], "title": c["title"],
                    "state": c["state"], "closedAt": c["closedAt"], "repo": c["repository"]["nameWithOwner"],
                    "labels": [l["name"] for l in c["labels"]["nodes"]],
                })
            if not page["pageInfo"]["hasNextPage"]:
                return out
            cursor = page["pageInfo"]["endCursor"]


_board = None


def board():
    global _board
    if _board is None:
        _board = Board()
    return _board


def track(numbers, status=None, horizon=None):
    for n in numbers:
        board().track(n, status, horizon)
        print(f"#{n} on board" + (f" | {status}" if status else "") + (f" | {horizon}" if horizon else ""))


def add_sub_issues(parent, children):
    for child in children:
        child_id = gh("api", f"repos/{REPO}/issues/{child}", "--jq", ".id")
        gh("api", "-X", "POST", f"repos/{REPO}/issues/{parent}/sub_issues", "-F", f"sub_issue_id={child_id}")
        print(f"#{child} is now a sub-issue of #{parent}")


# ── stages ───────────────────────────────────────────────────────────────────

def stage_body(parent, index, stage):
    total = len(STAGES["stages"])
    lines = [
        f"<!-- telly-stage:{stage['key']} parent:{parent} -->",
        f"**Stage {index + 1} of {total} of #{parent}** · skill: `{stage['skill']}`",
        "",
        f"**Goal**: {stage['goal']}",
        "",
        *[f"- [ ] {item}" for item in stage["checklist"]],
        "",
    ]
    if stage.get("skippable"):
        lines += [f"_Skippable_: {stage['skippable']}", ""]
    lines += [
        "Finish this stage with `python tool/tracker/tracker.py advance <this issue> --comment \"<outcome>\"`.",
        "Never close stage issues by hand. `advance` opens the next stage and keeps the epic's status right.",
    ]
    return "\n".join(lines)


def scaffold(parent, use_board=True):
    p = issue(parent)
    if not set(label_names(p)) & set(STAGES["applies_to"]):
        sys.exit(f"#{parent} is not labelled {' or '.join(STAGES['applies_to'])}; nothing to scaffold")
    if p["state"] != "open":
        sys.exit(f"#{parent} is closed")
    existing = stage_issues(parent)
    areas = [l for l in label_names(p) if l.startswith("area:")]
    created = {}
    for i, stage in enumerate(STAGES["stages"]):
        if stage["key"] in existing:
            continue
        title = f"[{i + 1}/{len(STAGES['stages'])} {stage['name']}] {p['title']}"
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False, encoding="utf-8") as f:
            f.write(stage_body(parent, i, stage))
        url = gh("issue", "create", "-R", REPO, "--title", title, "--label", ",".join(["stage", *areas]),
                 "--body-file", f.name).splitlines()[-1]
        n = int(url.rsplit("/", 1)[-1])
        add_sub_issues(parent, [n])
        created[stage["key"]] = n
    if use_board:
        refresh_stage_statuses(parent)
    print(f"#{parent}: created {len(created)} stage(s)" + (f" {sorted(created.values())}" if created else ""))


def refresh_stage_statuses(parent):
    """Make the board match the stages: first open stage Ready, later ones Backlog, done ones Done."""
    b = board()
    _, parent_status, horizon = b.state(parent)
    stages = stage_issues(parent)
    first_open = next((k for k, s in stages.items() if s["state"] == "open"), None)
    for key, s in stages.items():
        item_id, status, h = b.state(s["number"])
        want = "Done" if s["state"] == "closed" else ("Ready" if key == first_open else "Backlog")
        if status not in (want, "In progress") or (status == "In progress" and want != "Ready"):
            b.set(item_id, "Status", want)
        if horizon and h != horizon:
            b.set(item_id, "Horizon", horizon)
    if first_open and parent_status not in ("Backlog",):
        want = "Shaping" if STAGE_KEYS.index(first_open) < STAGE_KEYS.index("implement") else "In progress"
        if parent_status != want:
            b.set(b.item(parent), "Status", want)


def advance(n, comment, outcome):
    s = issue(n)
    st = stage_of(s)
    if not st:
        sys.exit(f"#{n} is not a stage issue; use `close` for ordinary issues")
    key, parent = st
    if s["state"] != "open":
        sys.exit(f"#{n} is already closed")
    if outcome in ("go", "skip"):
        open_children = [c["number"] for c in sub_issues(n) if c["state"] == "open"]
        if open_children:
            sys.exit(f"#{n} still has open sub-issues: {', '.join('#' + str(c) for c in open_children)}")
    if outcome in ("skip", "park", "drop") and not comment:
        sys.exit(f"--comment is required for outcome '{outcome}'")

    b = board()
    gh("issue", "edit", str(n), "-R", REPO, "--remove-label", "needs-owner")
    if outcome == "park":
        gh("issue", "comment", str(n), "-R", REPO, "--body", f"**Parked.** {comment}")
        b.track(n, "Backlog")
        b.track(parent, "Backlog", "Later")
        print(f"#{parent} parked (Backlog, Later)")
        return
    if outcome == "drop":
        close_issue(n, f"**Dropped.** {comment}")
        b.track(n, "Done")
        for other in stage_issues(parent).values():
            if other["state"] == "open" and other["number"] != n:
                close_issue(other["number"], f"Not needed: #{parent} was dropped in #{n}.", not_planned=True)
                b.track(other["number"], "Done")
        close_issue(parent, f"Dropped after evaluation in #{n}: {comment}", not_planned=True)
        b.track(parent, "Done")
        print(f"#{parent} dropped")
        return

    prefix = "**Skipped.** " if outcome == "skip" else ""
    close_issue(n, f"{prefix}{comment}" if comment else None, not_planned=outcome == "skip")
    b.track(n, "Done")
    p = issue(parent)
    if key == "evaluate" and "idea" in label_names(p):
        gh("issue", "edit", str(parent), "-R", REPO, "--add-label", "epic", "--remove-label", "idea")
        print(f"#{parent} promoted from idea to epic")
    remaining = [x for x in stage_issues(parent).values() if x["state"] == "open"]
    if remaining:
        refresh_stage_statuses(parent)
        print(f"#{n} done; next stage #{remaining[0]['number']} is Ready")
    else:
        close_issue(parent, f"All stages complete (last: #{n}).")
        b.track(parent, "Done")
        print(f"#{n} done; #{parent} complete and closed")


# ── pull requests ────────────────────────────────────────────────────────────

# A squash merge makes the PR title the commit subject on main, and GitHub appends "(#PR)",
# so the title carries no issue number of its own (WORKFLOW.md §6).
TITLE_RE = re.compile(r"^(feat|fix|refactor|perf|test|docs|chore|ci|build|revert)(\([a-z0-9][a-z0-9/._-]*\))?!?: \S.*$")
REVERT_RE = re.compile(r'^Revert ".+"$')
TITLE_MAX = 100


def title_problem(title):
    """Why a PR title breaks the commit convention, or None when it is fine."""
    if REVERT_RE.match(title):
        return None
    if not TITLE_RE.match(title):
        return ("use `<type>(<scope>): <description>` with type one of "
                "feat, fix, refactor, perf, test, docs, chore, ci, build, revert")
    if re.search(r"\(#\d+\)\s*$", title):
        return "drop the trailing (#N): the squash merge appends the PR number, and the body links the issue"
    if len(title) > TITLE_MAX:
        return f"keep it under {TITLE_MAX} characters"
    return None


def pr_body(n, closes, refs, summary, deploy):
    lines = [f"{'Fixes' if closes else 'Refs'} #{n}", *[f"Refs #{r}" for r in refs], "",
             "### What changed", summary.strip() or "_See the commits._", "",
             "### Backend",
             f"- [{'x' if deploy else ' '}] Needs `supabase-deploy` from `main` after merge "
             "(migrations, functions or challenge content)", "",
             "### Checklist",
             "- [x] `dart analyze --fatal-infos` and `flutter test` pass locally (or the change can't affect them)",
             "- [x] Tests at the right pyramid level; spec and decisions updated where needed"]
    return "\n".join(lines) + "\n"


def should_scaffold(status, author):
    """Outside ideas wait in the Inbox until triage, so strangers can't make the bot create stages."""
    return author == OWNER or status not in (None, "Inbox")


def check_rollup(checks):
    states = {(c.get("conclusion") or c.get("state") or c.get("status") or "").upper() for c in checks or []}
    if states & {"FAILURE", "ERROR", "CANCELLED", "TIMED_OUT", "ACTION_REQUIRED", "STARTUP_FAILURE"}:
        return "CI failing"
    if not states or states & {"PENDING", "QUEUED", "IN_PROGRESS", "EXPECTED", "WAITING", ""}:
        return "CI running"
    return "CI green"


def cmd_check_title(args):
    problem = title_problem(args.title)
    if problem:
        sys.exit(f"PR title {args.title!r}: {problem}")
    print("PR title OK")


def cmd_pr(args):
    problem = title_problem(args.title)
    if problem:
        sys.exit(f"PR title: {problem}")
    branch = git("rev-parse", "--abbrev-ref", "HEAD")
    if branch in ("main", "HEAD"):
        sys.exit("Work on a branch named <type>/<N>-<slug>, never on main (WORKFLOW.md §6)")
    if git("status", "--porcelain"):
        sys.exit("Commit or drop local changes first")
    closes = not args.no_close and not stage_of(issue(args.number))  # stages finish with `advance`, never a merge
    summary = pathlib.Path(args.body_file).read_text(encoding="utf-8") if args.body_file else ""
    with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False, encoding="utf-8") as f:
        f.write(pr_body(args.number, closes, args.refs, summary, args.deploy))
    git("push", "-u", "origin", branch)
    existing = gh("pr", "list", "-R", REPO, "--head", branch, "--state", "open", "--json", "url", parse=True)
    if existing:
        url = existing[0]["url"]
        gh("pr", "edit", url, "--title", args.title, "--body-file", f.name)
    else:
        create = ["pr", "create", "-R", REPO, "--base", "main", "--head", branch, "--title", args.title,
                  "--body-file", f.name]
        url = gh(*create, *(["--draft"] if args.draft else [])).splitlines()[-1]
    if not args.draft:
        gh("pr", "merge", url, "--auto", "--squash")
    board().track(args.number, "In progress")
    print(url + ("  (draft: merge held)" if args.draft else "  (auto-merge on: squashes when CI passes)"))


def open_prs():
    return gh("pr", "list", "-R", REPO, "--state", "open", "--limit", "100", "--json",
              "number,title,isDraft,mergeStateStatus,autoMergeRequest,statusCheckRollup", parse=True)


# ── commands ─────────────────────────────────────────────────────────────────

def cmd_labels(args):
    spec = json.loads((HERE / "labels.json").read_text(encoding="utf-8"))
    existing = {l["name"] for l in gh("label", "list", "-R", REPO, "--limit", "200", "--json", "name", parse=True)}
    for label in spec["labels"]:
        print(f"{'update' if label['name'] in existing else 'create'} {label['name']}")
        if not args.dry_run:
            gh("label", "create", label["name"], "-R", REPO, "--force",
               "--color", label["color"], "--description", label["description"])
    for name in spec["remove"]:
        if name in existing:
            print(f"delete {name}")
            if not args.dry_run:
                gh("label", "delete", name, "-R", REPO, "--yes")


def cmd_new(args):
    labels = [l for l in args.labels.split(",") if l]
    staged = bool(set(labels) & set(STAGES["applies_to"]))
    body = pathlib.Path(args.body_file).read_text(encoding="utf-8") if args.body_file else ""
    if staged:
        body += f"\n\n{LOCAL_SCAFFOLD}\n"
    with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False, encoding="utf-8") as f:
        f.write(body)
    create = ["issue", "create", "-R", REPO, "--title", args.title, "--body-file", f.name]
    if labels:
        create += ["--label", ",".join(labels)]
    url = gh(*create).splitlines()[-1]
    number = int(url.rsplit("/", 1)[-1])
    print(url)
    track([number], args.status or "Inbox", args.horizon)
    if args.parent:
        add_sub_issues(args.parent, [number])
    if staged:
        scaffold(number)


def cmd_stages(args):
    stages = stage_issues(args.number)
    if not stages:
        print(f"#{args.number} has no stages (scaffold it if it is an idea/epic)")
    for key, s in stages.items():
        mark = "x" if s["state"] == "closed" else " "
        print(f"[{mark}] #{s['number']:<4} {s['title']}")
        if key == "implement":
            for t in sub_issues(s["number"]):
                print(f"      [{'x' if t['state'] == 'closed' else ' '}] #{t['number']:<4} {t['title']}")


def cmd_close(args):
    if stage_of(issue(args.number)):
        sys.exit(f"#{args.number} is a stage issue; use `advance`")
    close_issue(args.number, args.comment, args.not_planned)
    board().track(args.number, "Done")
    print(f"#{args.number} closed and Done")


def cmd_board(args):
    rows = []
    for it in board().items():
        status, horizon = it["status"] or "-", it["horizon"] or "-"
        if args.status and status.lower() != args.status.lower():
            continue
        if args.horizon and horizon.lower() != args.horizon.lower():
            continue
        if args.label and args.label not in it["labels"]:
            continue
        if not args.status and status == "Done":
            continue
        rows.append((STATUSES.index(status) if status in STATUSES else -1, status, horizon,
                     it["number"], it["title"], it["labels"]))

    def order(row):
        return row[0], HORIZONS.index(row[2]) if row[2] in HORIZONS else len(HORIZONS), row[3]

    for _, status, horizon, number, title, labels in sorted(rows, key=order):
        print(f"{status:<12} {horizon:<6} #{number:<4} {title}  [{', '.join(labels)}]")


def cmd_report(args):
    items = [it for it in board().items() if it["state"] == "OPEN" or it["closedAt"]]
    open_items = [it for it in items if it["state"] == "OPEN"]

    def section(title, rows):
        print(f"\n## {title} ({len(rows)})")
        for it in sorted(rows, key=lambda r: r["number"]):
            print(f"- #{it['number']} {it['title']}")

    section("Needs you: decisions (needs-owner)", [i for i in open_items if "needs-owner" in i["labels"]])
    section("Needs you: hands-on tasks (human-only)", [i for i in open_items if "human-only" in i["labels"]])
    section("In progress", [i for i in open_items if i["status"] == "In progress"])
    section("Ready, horizon Now", [i for i in open_items if i["status"] == "Ready" and i["horizon"] == "Now"])
    print(f"\n## Inbox: {sum(1 for i in open_items if i['status'] in (None, 'Inbox'))} untriaged")
    prs = open_prs()
    print(f"\n## Open pull requests ({len(prs)})")
    for pr in sorted(prs, key=lambda r: r["number"]):
        notes = ["draft" if pr["isDraft"] else check_rollup(pr["statusCheckRollup"])]
        if pr["mergeStateStatus"] == "BEHIND":
            notes.append("behind main: `gh pr update-branch`")
        if not pr["isDraft"] and not pr["autoMergeRequest"]:
            notes.append("auto-merge off")
        print(f"- #{pr['number']} {pr['title']}: {', '.join(notes)}")
    since = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=7)
    section("Closed in the last 7 days", [
        i for i in items if i["state"] == "CLOSED" and "stage" not in i["labels"]
        and datetime.datetime.fromisoformat(i["closedAt"].replace("Z", "+00:00")) >= since])
    stage_rows = {}
    for i in open_items:
        m = re.match(r"^\[\d+/\d+ (.*?)\] ", i["title"])
        if "stage" in i["labels"] and m and i["status"] != "Backlog":
            stage_rows.setdefault(i["title"][m.end():], m.group(1))
    print("\n## Epics and ideas: current stage")
    for i in sorted(open_items, key=lambda r: (HORIZONS.index(r["horizon"]) if r["horizon"] in HORIZONS else 9,
                                                r["number"])):
        if {"epic", "idea"} & set(i["labels"]):
            where = "parked" if i["status"] == "Backlog" else stage_rows.get(i["title"], "no open stage")
            print(f"- #{i['number']} [{i['horizon'] or '-'}] {i['title']}: {where}")


def cmd_sync(args):
    b = board()
    on_board = {it["number"]: it for it in b.items() if it["repo"] == REPO}
    open_issues = {i["number"]: i for i in gh("issue", "list", "-R", REPO, "--state", "open", "--limit", "1000",
                                              "--json", "number,body,labels,author", parse=True)}
    cutoff = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=args.archive_days)
    touched_parents = set()

    for n, i in open_issues.items():
        labels = [l["name"] for l in i["labels"]]
        st = stage_of(i)
        it = on_board.get(n)
        status = it["status"] if it else None
        if st:
            if not status or status == "Done":
                touched_parents.add(st[1])
            continue
        if set(labels) & set(STAGES["applies_to"]) and not stage_issues(n):
            if not should_scaffold(status, (i.get("author") or {}).get("login")):
                print(f"#{n}: outside idea, stages wait for triage")
                continue
            print(f"#{n}: scaffolding missing stages")
            scaffold(n)
            continue
        if not status:
            b.track(n, "Inbox")
            print(f"#{n}: added to Inbox")
        elif status == "Done":
            b.track(n, "Ready")
            print(f"#{n}: reopened, moved to Ready")

    for n, it in on_board.items():
        if it["state"] != "CLOSED":
            continue
        if it["status"] != "Done":
            b.set(it["id"], "Status", "Done")
            print(f"#{n}: closed, moved to Done")
        closed_at = datetime.datetime.fromisoformat(it["closedAt"].replace("Z", "+00:00"))
        if closed_at < cutoff:
            b.archive(it["id"])
            print(f"#{n}: archived (closed {closed_at.date()})")

    for parent in sorted(touched_parents):
        if parent in open_issues:
            refresh_stage_statuses(parent)
            print(f"#{parent}: stage statuses refreshed")

    for n, i in open_issues.items():
        st = stage_of(i)
        if st and st[0] == "implement":
            tasks = sub_issues(n)
            if tasks and all(t["state"] == "closed" for t in tasks):
                print(f"hint: all tasks of #{n} are closed; verify, then `advance {n}`")
    print("sync complete")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("report", help="owner/PM summary")
    s.set_defaults(func=cmd_report)

    s = sub.add_parser("board", help="list board items (open work by default)")
    s.add_argument("--status", choices=STATUSES)
    s.add_argument("--horizon", choices=HORIZONS)
    s.add_argument("--label")
    s.set_defaults(func=cmd_board)

    s = sub.add_parser("new", help="create an issue, put it on the board, scaffold stages for idea/epic")
    s.add_argument("--title", required=True)
    s.add_argument("--labels", default="")
    s.add_argument("--body-file")
    s.add_argument("--status", choices=STATUSES)
    s.add_argument("--horizon", choices=HORIZONS)
    s.add_argument("--parent", type=int, help="parent issue, e.g. an Implement stage for a task")
    s.set_defaults(func=cmd_new)

    s = sub.add_parser("track", help="add issues to the board and/or set Status/Horizon")
    s.add_argument("numbers", nargs="+", type=int)
    s.add_argument("--status", choices=STATUSES)
    s.add_argument("--horizon", choices=HORIZONS)
    s.set_defaults(func=lambda a: track(a.numbers, a.status, a.horizon))

    s = sub.add_parser("stages", help="show an idea/epic's stages and implementation tasks")
    s.add_argument("number", type=int)
    s.set_defaults(func=cmd_stages)

    s = sub.add_parser("scaffold", help="create missing stage sub-issues for an idea/epic")
    s.add_argument("number", type=int)
    s.add_argument("--no-board", action="store_true", help="skip board updates (CI without project access)")
    s.set_defaults(func=lambda a: scaffold(a.number, not a.no_board))

    s = sub.add_parser("advance", help="finish a stage and open the next one")
    s.add_argument("number", type=int)
    s.add_argument("--comment", default="")
    s.add_argument("--outcome", choices=["go", "skip", "park", "drop"], default="go")
    s.set_defaults(func=lambda a: advance(a.number, a.comment, a.outcome))

    s = sub.add_parser("close", help="close an ordinary issue and mark it Done")
    s.add_argument("number", type=int)
    s.add_argument("--comment")
    s.add_argument("--not-planned", action="store_true")
    s.set_defaults(func=cmd_close)

    s = sub.add_parser("sub", help="attach sub-issues to a parent")
    s.add_argument("parent", type=int)
    s.add_argument("children", nargs="+", type=int)
    s.set_defaults(func=lambda a: add_sub_issues(a.parent, a.children))

    s = sub.add_parser("pr", help="push this branch, open its PR and turn on auto-merge")
    s.add_argument("number", type=int, help="the issue this branch implements")
    s.add_argument("--title", required=True, help="<type>(<scope>): <description>, no (#N)")
    s.add_argument("--refs", nargs="*", type=int, default=[], help="related issues, e.g. the parent epic")
    s.add_argument("--body-file", help="what changed, in a few lines")
    s.add_argument("--deploy", action="store_true", help="tick 'needs supabase-deploy after merge'")
    s.add_argument("--draft", action="store_true", help="open as a draft and hold the merge")
    s.add_argument("--no-close", action="store_true", help="Refs instead of Fixes (e.g. an intake capture)")
    s.set_defaults(func=cmd_pr)

    s = sub.add_parser("check-title", help="check a PR title against the commit convention (CI)")
    s.add_argument("title")
    s.set_defaults(func=cmd_check_title)

    s = sub.add_parser("sync", help="repair drift between issues and the board")
    s.add_argument("--archive-days", type=int, default=30, help="archive Done items closed longer ago than this")
    s.set_defaults(func=cmd_sync)

    s = sub.add_parser("labels", help="sync labels from labels.json")
    s.add_argument("--dry-run", action="store_true")
    s.set_defaults(func=cmd_labels)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
