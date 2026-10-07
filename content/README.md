# Challenge content

Challenges are data, so new ones never need an app update ([features/10 §8](../docs/features/10_GAMIFICATION_MEDALS_CHALLENGES_AND_LEVELS.md)). Everything here is validated in CI and published with:

```bash
python tool/challenges/publish.py --dry-run   # validate and show the SQL
python tool/challenges/publish.py --publish   # apply to telly-prod (needs `supabase login`)
```

Publishing upserts templates, one-off challenges and calendar entries, then creates this month's and next month's calendar challenges right away. Re-publishing is safe. After publishing, the `challenge-scheduler` edge function keeps the calendar running on its own (the 25th prepares next month; the 1st is a safety net).

## Rules (all files)

A rule is a media type plus filters that must **all** match:

```yaml
rule:
  media_type: movie          # movie | tv | any
  filters:
    - type: genre            # genre | decade | collection | titles | network | company | tv_type
      any: [Horror]          # a title matches when it has any of these
```

| Filter | Values | Example |
|---|---|---|
| `genre` | TMDB genre names | `[Horror, Thriller]` |
| `decade` | first year of the decade | `[1970, 1980]` |
| `collection` | TMDB collection ids | `[263]` |
| `titles` | `{id, media_type}` pairs | `[{id: 603, media_type: movie}]` |
| `network` | TMDB network names (series) | `[HBO]` |
| `company` | production company names | `[A24]` |
| `tv_type` | TMDB TV types | `[Miniseries]` |

`art` is one of `horror`, `noir`, `gold`, `cyan`, `violet`, `coral`, `lime`. `medal_glyph` is 1–4 characters (quote numbers: `"8"`). `target` is 1–1000.

## `challenges/*.yaml`: one-off challenges

```yaml
slug: spooktober-2026            # lowercase words joined by hyphens, at most 50 characters
name: Spooktober                 # at most 64 characters
description: Rank 8 horror films by Oct 31
art: horror
medal_glyph: "8"
starts_at: 2026-10-01T00:00:00Z  # always with a time zone
ends_at: 2026-11-01T00:00:00Z    # optional: leave out for an open-ended challenge
rule: {media_type: movie, filters: [{type: genre, any: [Horror]}]}
target: 8
featured: true                   # optional; only one featured challenge may run at a time
status: live                     # optional; draft hides it
```

## `challenge_templates/*.yaml`: templates

Squads create challenges from these, and so does the calendar. `$name` strings in the rule are filled from `params`; in the description, `$target` and every param are filled in.

```yaml
key: genre_month
name: Genre month
description: Rank $target $genre films
art: gold
medal_glyph: G
params: [genre]                  # must match the rule's placeholders exactly
rule: {media_type: movie, filters: [{type: genre, any: [$genre]}]}
target: 8                        # default; squads and calendar entries may override it
sort: 1
```

## `challenge_calendar.yaml`: the calendar

Months (quoted `"YYYY-MM"`) map to the challenges created for them. Each runs from the 1st to the end of the month (UTC). At most one entry a month is featured.

```yaml
"2026-11":
  - slug: noirvember-2026
    template: decade
    name: Noirvember
    params: {decade: 1940}
    target: 6                    # optional; defaults to the template's
    featured: true
    medal_glyph: NV              # optional; defaults to the template's
```

## Urgent fixes

For a typo or a deadline change you can edit the `challenges` row in the Supabase table editor, but copy the change back into these files the same week, or the next publish will undo it.
