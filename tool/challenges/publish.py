#!/usr/bin/env python3
"""Validate and publish Telly's challenge content (#143, features/10 §8.4).

Content lives in the repo:
  content/challenges/*.yaml           one-off challenges (published as they are)
  content/challenge_templates/*.yaml  parameterised templates (squads and the calendar use them)
  content/challenge_calendar.yaml     month → planned challenges, created by the scheduler

Schema: content/README.md.

  python tool/challenges/publish.py --dry-run     # validate and print the SQL (CI runs this)
  python tool/challenges/publish.py --publish     # validate, then apply to telly-prod (main only)

Publishing runs the generated SQL through `supabase db query --linked` (the same login the
supabase-deploy skill uses; no keys are needed or read). It upserts templates, challenges and
calendar entries, then creates this month's and next month's calendar challenges straight away
(the scheduler would otherwise do it on the 25th and the 1st). Re-publishing is safe.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[2]

FILTERS = {'genre', 'decade', 'collection', 'titles', 'network', 'company', 'tv_type'}
MEDIA = {'movie', 'tv', 'any'}
ARTS = {'horror', 'noir', 'gold', 'cyan', 'violet', 'coral', 'lime'}
SLUG = re.compile(r'^[a-z0-9]+(-[a-z0-9]+)*$')
KEY = re.compile(r'^[a-z0-9_]{2,40}$')
PARAM = re.compile(r'^\$([a-z_]+)$')
MONTH = re.compile(r'^\d{4}-(0[1-9]|1[0-2])$')


# ------------------------------------------------------------------------------------- loading
def load(root: pathlib.Path = ROOT) -> dict:
    content = root / 'content'

    def read(path: pathlib.Path):
        with open(path, encoding='utf-8') as f:
            return yaml.safe_load(f)

    templates = {p.name: read(p) for p in sorted((content / 'challenge_templates').glob('*.yaml'))}
    challenges = {p.name: read(p) for p in sorted((content / 'challenges').glob('*.yaml'))}
    calendar_path = content / 'challenge_calendar.yaml'
    calendar = read(calendar_path) if calendar_path.exists() else {}
    return {'templates': templates, 'challenges': challenges, 'calendar': calendar or {}}


# ---------------------------------------------------------------------------------- validation
def _instant(value, where: str, errors: list[str]) -> dt.datetime | None:
    """A timestamp with a time zone; YAML may already have parsed it."""
    if isinstance(value, dt.datetime):
        parsed = value
    elif isinstance(value, str):
        try:
            parsed = dt.datetime.fromisoformat(value.replace('Z', '+00:00'))
        except ValueError:
            errors.append(f'{where}: not an ISO timestamp: {value!r}')
            return None
    else:
        errors.append(f'{where}: expected a timestamp, got {value!r}')
        return None
    if parsed.tzinfo is None:
        errors.append(f'{where}: timestamp needs a time zone (end it with Z)')
        return None
    return parsed


def rule_errors(rule, where: str, allow_params: bool) -> tuple[list[str], set[str]]:
    """Problems with a §8.2 rule, and the "$param" placeholders it uses."""
    errors: list[str] = []
    params: set[str] = set()
    if not isinstance(rule, dict):
        return [f'{where}: rule must be a mapping'], params
    if rule.get('media_type') not in MEDIA:
        errors.append(f'{where}: rule.media_type must be one of {sorted(MEDIA)}')
    filters = rule.get('filters', [])
    if not isinstance(filters, list):
        return errors + [f'{where}: rule.filters must be a list'], params
    for i, f in enumerate(filters):
        at = f'{where}: filter {i + 1}'
        if not isinstance(f, dict) or f.get('type') not in FILTERS:
            errors.append(f'{at}: type must be one of {sorted(FILTERS)}')
            continue
        values = f.get('any')
        if not isinstance(values, list) or not values:
            errors.append(f'{at}: "any" must be a non-empty list')
            continue
        for v in values:
            m = PARAM.match(v) if isinstance(v, str) else None
            if m:
                if not allow_params:
                    errors.append(f'{at}: placeholder {v} outside a template')
                params.add(m.group(1))
                continue
            kind = f['type']
            if kind == 'decade' and not (isinstance(v, int) and v % 10 == 0):
                errors.append(f'{at}: decades are years ending in 0, like 1980')
            elif kind == 'collection' and not isinstance(v, int):
                errors.append(f'{at}: collections are TMDB collection ids')
            elif kind == 'titles' and not (isinstance(v, dict) and isinstance(v.get('id'), int)
                                          and v.get('media_type') in ('movie', 'tv')):
                errors.append(f'{at}: titles are {{id: <tmdb id>, media_type: movie|tv}}')
            elif kind in ('genre', 'network', 'company', 'tv_type') and not (isinstance(v, str) and v.strip()):
                errors.append(f'{at}: {kind} values are names')
    return errors, params


def _common(item: dict, where: str, errors: list[str], *, name_required=True):
    name = item.get('name')
    if name_required and not (isinstance(name, str) and 0 < len(name.strip()) <= 64):
        errors.append(f'{where}: name must be 1 to 64 characters')
    desc = item.get('description', '')
    if desc is not None and (not isinstance(desc, str) or len(desc) > 200):
        errors.append(f'{where}: description must be text of at most 200 characters')
    art = item.get('art')
    if art is not None and art not in ARTS:
        errors.append(f'{where}: art must be one of {sorted(ARTS)}')
    glyph = item.get('medal_glyph')
    if glyph is not None and not (isinstance(glyph, str) and 1 <= len(glyph) <= 4):
        errors.append(f'{where}: medal_glyph must be 1 to 4 characters (quote numbers: "8")')
    target = item.get('target')
    if target is not None and not (isinstance(target, int) and 1 <= target <= 1000):
        errors.append(f'{where}: target must be a whole number from 1 to 1000')


def validate(content: dict) -> list[str]:
    errors: list[str] = []
    templates: dict[str, dict] = {}
    featured: list[tuple[dt.datetime, dt.datetime, str]] = []
    slugs: dict[str, str] = {}

    def claim_slug(slug, where):
        if not (isinstance(slug, str) and SLUG.match(slug) and 3 <= len(slug) <= 50):
            errors.append(f'{where}: slug must be lowercase words joined by hyphens, 3 to 50 characters')
        elif slug in slugs:
            errors.append(f'{where}: slug {slug} is also used by {slugs[slug]}')
        else:
            slugs[slug] = where

    for file, t in content['templates'].items():
        where = f'challenge_templates/{file}'
        if not isinstance(t, dict):
            errors.append(f'{where}: must be a mapping')
            continue
        key = t.get('key')
        if not (isinstance(key, str) and KEY.match(key)):
            errors.append(f'{where}: key must match {KEY.pattern}')
            continue
        if key in templates:
            errors.append(f'{where}: duplicate template key {key}')
        _common(t, where, errors)
        if t.get('target') is None:
            errors.append(f'{where}: target is required')
        rule_errs, used = rule_errors(t.get('rule'), where, allow_params=True)
        errors += rule_errs
        declared = t.get('params', [])
        if not (isinstance(declared, list) and all(isinstance(p, str) for p in declared)):
            errors.append(f'{where}: params must be a list of names')
            declared = []
        if set(declared) != used:
            errors.append(f'{where}: params {sorted(declared)} must match the rule placeholders {sorted(used)}')
        templates[key] = t

    for file, c in content['challenges'].items():
        where = f'challenges/{file}'
        if not isinstance(c, dict):
            errors.append(f'{where}: must be a mapping')
            continue
        claim_slug(c.get('slug'), where)
        _common(c, where, errors)
        if c.get('target') is None:
            errors.append(f'{where}: target is required')
        errors += rule_errors(c.get('rule'), where, allow_params=False)[0]
        if c.get('status', 'live') not in ('draft', 'live'):
            errors.append(f'{where}: status must be draft or live')
        start = _instant(c.get('starts_at'), f'{where}: starts_at', errors)
        end = _instant(c['ends_at'], f'{where}: ends_at', errors) if c.get('ends_at') is not None else None
        if start and end and end <= start:
            errors.append(f'{where}: ends_at must be after starts_at')
        if c.get('featured') and start:
            featured.append((start, end or dt.datetime.max.replace(tzinfo=dt.timezone.utc), where))

    calendar = content['calendar']
    if not isinstance(calendar, dict):
        errors.append('challenge_calendar.yaml: must map "YYYY-MM" months to lists of entries')
        calendar = {}
    for month, entries in calendar.items():
        month = str(month)
        where_month = f'challenge_calendar.yaml {month}'
        if not MONTH.match(month):
            errors.append(f'{where_month}: months are "YYYY-MM" (quote them)')
            continue
        if not isinstance(entries, list):
            errors.append(f'{where_month}: expected a list of entries')
            continue
        year, mon = map(int, month.split('-'))
        start = dt.datetime(year, mon, 1, tzinfo=dt.timezone.utc)
        end = dt.datetime(year + (mon == 12), mon % 12 + 1, 1, tzinfo=dt.timezone.utc)
        if sum(1 for e in entries if isinstance(e, dict) and e.get('featured')) > 1:
            errors.append(f'{where_month}: at most one featured challenge a month')
        for i, e in enumerate(entries):
            where = f'{where_month} entry {i + 1}'
            if not isinstance(e, dict):
                errors.append(f'{where}: must be a mapping')
                continue
            claim_slug(e.get('slug'), where)
            _common(e, where, errors)
            template = templates.get(e.get('template'))
            if template is None:
                errors.append(f'{where}: unknown template {e.get("template")!r}')
                continue
            params = e.get('params') or {}
            if not isinstance(params, dict) or set(params) != set(template.get('params', [])):
                errors.append(f'{where}: params must be exactly {sorted(template.get("params", []))}')
            if e.get('featured'):
                featured.append((start, end, where))

    featured.sort()
    for (s1, e1, w1), (s2, e2, w2) in zip(featured, featured[1:]):
        if s2 < e1:
            errors.append(f'{w2}: featured at the same time as {w1} (one featured challenge at a time)')
    return errors


# ----------------------------------------------------------------------------------------- SQL
def _jsonb(value) -> str:
    text = json.dumps(value, ensure_ascii=False, default=str, separators=(',', ':'))
    return "'" + text.replace("'", "''") + "'::jsonb"


def _iso(value) -> str | None:
    if value is None:
        return None
    if isinstance(value, dt.datetime):
        return value.isoformat()
    return str(value)


def to_sql(content: dict, today: dt.date | None = None) -> str:
    today = today or dt.datetime.now(dt.timezone.utc).date()
    lines = ['-- Generated by tool/challenges/publish.py (#143). Safe to re-run.', 'BEGIN;']
    for t in content['templates'].values():
        lines.append(f'SELECT public.admin_upsert_challenge_template({_jsonb(t)});')
    for c in content['challenges'].values():
        payload = {**c, 'starts_at': _iso(c.get('starts_at')), 'ends_at': _iso(c.get('ends_at')),
                   'status': c.get('status', 'live'), 'featured': bool(c.get('featured', False))}
        lines.append(f'SELECT public.admin_upsert_challenge({_jsonb(payload)});')
    for month, entries in content['calendar'].items():
        for e in entries:
            lines.append(f'SELECT public.admin_upsert_calendar_entry({_jsonb({**e, "month": f"{month}-01"})});')
    this_month = today.replace(day=1)
    next_month = (this_month + dt.timedelta(days=32)).replace(day=1)
    for m in (this_month, next_month):
        lines.append(f"SELECT public.schedule_calendar_challenges('{m.isoformat()}');")
    lines.append('COMMIT;')
    return '\n'.join(lines) + '\n'


# ---------------------------------------------------------------------------------------- main
def deploy_ref_problem(root: pathlib.Path = ROOT) -> str | None:
    """Why this checkout may not publish to telly-prod, or None (#158: production gets merged code only)."""
    def git(*args: str) -> str:
        return subprocess.run(['git', *args], cwd=root, capture_output=True, text=True).stdout.strip()

    branch = git('rev-parse', '--abbrev-ref', 'HEAD')
    if branch != 'main':
        return f'on branch {branch!r}: merge the PR, then publish from main'
    git('fetch', '--quiet', 'origin', 'main')
    if git('rev-parse', 'HEAD') != git('rev-parse', 'origin/main'):
        return 'local main differs from origin/main: run `git pull --ff-only`'
    if git('status', '--porcelain', '--', 'content'):
        return 'uncommitted changes under content/'
    return None


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--dry-run', action='store_true', help='validate and print the SQL; touch nothing')
    mode.add_argument('--publish', action='store_true', help='validate, then apply to the linked project')
    parser.add_argument('--root', type=pathlib.Path, default=ROOT, help=argparse.SUPPRESS)
    args = parser.parse_args(argv)

    content = load(args.root)
    errors = validate(content)
    counts = (f"{len(content['templates'])} templates, {len(content['challenges'])} challenges, "
              f"{sum(len(v or []) for v in content['calendar'].values())} calendar entries")
    if errors:
        print(f'Challenge content has {len(errors)} problem(s):', file=sys.stderr)
        for e in errors:
            print(f'  - {e}', file=sys.stderr)
        return 1
    sql = to_sql(content)
    print(f'OK: {counts}.')
    if args.dry_run:
        print(sql)
        return 0

    problem = deploy_ref_problem(args.root)
    if problem:
        print(f'Refusing to publish: {problem}.', file=sys.stderr)
        return 3
    with tempfile.NamedTemporaryFile('w', suffix='.sql', delete=False, encoding='utf-8') as f:
        f.write(sql)
        path = f.name
    print(f'Publishing to the linked project ({path}) ...')
    cli = shutil.which('supabase')  # on Windows the CLI is a .cmd/.exe shim
    if cli is None:
        print('The Supabase CLI is not on PATH.', file=sys.stderr)
        return 1
    result = subprocess.run([cli, 'db', 'query', '--linked', '--file', path], cwd=ROOT,
                            stdin=subprocess.DEVNULL, capture_output=True, text=True)
    print(result.stdout)
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        print('Publish failed. If it says you are not logged in, run `supabase login`.', file=sys.stderr)
        return result.returncode
    print('Published.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
