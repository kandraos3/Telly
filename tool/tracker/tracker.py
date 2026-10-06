"""Telly work tracker: thin wrapper over `gh` for the conventions in docs/process/WORKFLOW.md.

Issues on kandraos3/Telly are the tickets; the "Telly" user project (#1) holds
Status (Inbox/Shaping/Ready/In progress/Done) and Horizon (Now/Next/Later).

  python tool/tracker/tracker.py labels [--dry-run]
  python tool/tracker/tracker.py new --title T --labels a,b [--body-file F] [--status S] [--horizon H] [--parent N]
  python tool/tracker/tracker.py track N [N ...] [--status S] [--horizon H]
  python tool/tracker/tracker.py sub PARENT CHILD [CHILD ...]
  python tool/tracker/tracker.py board [--status S] [--horizon H] [--label L]

Needs `gh` logged in with the `project` scope (`gh auth refresh -s project`).
"""

import argparse
import json
import pathlib
import subprocess
import sys

OWNER = "kandraos3"
REPO = "kandraos3/Telly"
PROJECT = "1"
STATUSES = ["Inbox", "Shaping", "Ready", "In progress", "Done"]
HORIZONS = ["Now", "Next", "Later"]

sys.stdout.reconfigure(encoding="utf-8")


def gh(*args, parse=False):
    out = subprocess.run(
        ["gh", *args], capture_output=True, text=True, encoding="utf-8"
    )
    if out.returncode != 0:
        sys.exit(f"gh {' '.join(args)} failed:\n{out.stderr.strip()}")
    return json.loads(out.stdout) if parse else out.stdout.strip()


def project_meta():
    project_id = gh(
        "project", "view", PROJECT, "--owner", OWNER, "--format", "json", "--jq", ".id"
    )
    fields = gh(
        "project", "field-list", PROJECT, "--owner", OWNER, "--format", "json", parse=True
    )["fields"]
    by_name = {f["name"]: f for f in fields}
    return project_id, by_name


def set_option(project_id, item_id, field, value):
    options = {o["name"].lower(): o["id"] for o in field["options"]}
    if value.lower() not in options:
        sys.exit(f"{field['name']} must be one of: {', '.join(o['name'] for o in field['options'])}")
    gh(
        "project", "item-edit", "--id", item_id, "--project-id", project_id,
        "--field-id", field["id"], "--single-select-option-id", options[value.lower()],
    )


def track(numbers, status=None, horizon=None):
    project_id, fields = project_meta()
    for n in numbers:
        url = f"https://github.com/{REPO}/issues/{n}"
        item = gh(
            "project", "item-add", PROJECT, "--owner", OWNER, "--url", url,
            "--format", "json", parse=True,
        )
        if status:
            set_option(project_id, item["id"], fields["Status"], status)
        if horizon:
            set_option(project_id, item["id"], fields["Horizon"], horizon)
        print(f"#{n} on board" + (f" · {status}" if status else "") + (f" · {horizon}" if horizon else ""))


def add_sub_issues(parent, children):
    for child in children:
        child_id = gh("api", f"repos/{REPO}/issues/{child}", "--jq", ".id")
        gh(
            "api", "-X", "POST", f"repos/{REPO}/issues/{parent}/sub_issues",
            "-F", f"sub_issue_id={child_id}",
        )
        print(f"#{child} is now a sub-issue of #{parent}")


def cmd_labels(args):
    spec = json.loads((pathlib.Path(__file__).parent / "labels.json").read_text(encoding="utf-8"))
    existing = {l["name"] for l in gh("label", "list", "-R", REPO, "--limit", "200", "--json", "name", parse=True)}
    for label in spec["labels"]:
        verb = "update" if label["name"] in existing else "create"
        print(f"{verb} {label['name']}")
        if not args.dry_run:
            gh(
                "label", "create", label["name"], "-R", REPO, "--force",
                "--color", label["color"], "--description", label["description"],
            )
    for name in spec["remove"]:
        if name in existing:
            print(f"delete {name}")
            if not args.dry_run:
                gh("label", "delete", name, "-R", REPO, "--yes")


def cmd_new(args):
    create = ["issue", "create", "-R", REPO, "--title", args.title]
    if args.labels:
        create += ["--label", args.labels]
    create += ["--body-file", args.body_file] if args.body_file else ["--body", ""]
    url = gh(*create).splitlines()[-1]
    number = url.rsplit("/", 1)[-1]
    print(url)
    track([number], args.status or "Inbox", args.horizon)
    if args.parent:
        add_sub_issues(args.parent, [number])


def cmd_board(args):
    items = gh(
        "project", "item-list", PROJECT, "--owner", OWNER, "--format", "json", "--limit", "1000",
        parse=True,
    )["items"]
    rows = []
    for it in items:
        content = it.get("content", {})
        labels = it.get("labels") or []
        status, horizon = it.get("status") or "-", it.get("horizon") or "-"
        if args.status and status.lower() != args.status.lower():
            continue
        if args.horizon and horizon.lower() != args.horizon.lower():
            continue
        if args.label and args.label not in labels:
            continue
        if not args.status and status == "Done":
            continue
        rows.append((STATUSES.index(status) if status in STATUSES else -1, status, horizon,
                     content.get("number", "?"), content.get("title", it.get("title", "")), labels))
    def order(row):
        horizon = HORIZONS.index(row[2]) if row[2] in HORIZONS else len(HORIZONS)
        return row[0], horizon, int(row[3]) if str(row[3]).isdigit() else 0

    for _, status, horizon, number, title, labels in sorted(rows, key=order):
        print(f"{status:<12} {horizon:<6} #{number:<4} {title}  [{', '.join(labels)}]")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("labels", help="sync labels from labels.json")
    s.add_argument("--dry-run", action="store_true")
    s.set_defaults(func=cmd_labels)

    s = sub.add_parser("new", help="create an issue and put it on the board")
    s.add_argument("--title", required=True)
    s.add_argument("--labels", default="")
    s.add_argument("--body-file")
    s.add_argument("--status", choices=STATUSES)
    s.add_argument("--horizon", choices=HORIZONS)
    s.add_argument("--parent", type=int, help="epic issue number to attach to")
    s.set_defaults(func=cmd_new)

    s = sub.add_parser("track", help="add issues to the board and/or set Status/Horizon")
    s.add_argument("numbers", nargs="+")
    s.add_argument("--status", choices=STATUSES)
    s.add_argument("--horizon", choices=HORIZONS)
    s.set_defaults(func=lambda a: track(a.numbers, a.status, a.horizon))

    s = sub.add_parser("sub", help="attach sub-issues to a parent (epic)")
    s.add_argument("parent", type=int)
    s.add_argument("children", nargs="+", type=int)
    s.set_defaults(func=lambda a: add_sub_issues(a.parent, a.children))

    s = sub.add_parser("board", help="list board items (open work by default)")
    s.add_argument("--status", choices=STATUSES)
    s.add_argument("--horizon", choices=HORIZONS)
    s.add_argument("--label")
    s.set_defaults(func=cmd_board)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
