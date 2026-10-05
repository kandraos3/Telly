---
name: issue-manager
description: >-
  Standardized protocol for ingesting user feedback, breaking it into granular,
  ticket-anchored GitHub issues, applying consistent naming and label conventions,
  and reading/managing issues using the GitHub CLI (`gh`).
---

# Telly Issue Manager & Feedback Ingestion Guide

This skill establishes the standardized operating procedure for taking user feedback (audio transcripts, design reviews, QA logs, or feature requests) and turning them into granular, developer-ready GitHub issues in `kandraos3/Telly`, as well as reading and managing them via `gh`.

---

## 1. Core Operating Philosophy

Every issue created in Telly must follow four core principles:
1. **Granular & Isolated**: Break feedback into the smallest independent work units. A single developer on their own Git branch must have enough context to implement, test, and ship the issue without blocker dependencies.
2. **Spec-Anchored**: Every issue references its exact Flutter screen/service (`lib/...`) and architectural spec in `docs/`.
3. **Completed Thoughts**: If user feedback is exploratory or incomplete (e.g. *"I don't like this layout, do something better"*), the author must propose a concrete, high-taste solution consistent with the *Midnight Cathode* design system.
4. **Standardized Taxonomy**: Every issue follows the strict title syntax and tag conventions defined below.

---

## 2. Naming & Tagging Conventions

### 2.1 Issue Title Syntax
```
[<TIER>-<DOMAIN>-<NUMBER>] <Subsystem or Screen>: <Imperative Action Summary>
```
- `<TIER>`: `FE` (Frontend / Flutter UI), `BE` (Backend / Supabase / Edge Functions), `ALGO` (Algorithms / Math), `QA` (Testing / Golden / A11y), `CI` (DevOps / Workflows).
- `<DOMAIN>`: `AUTH`, `LOG`, `DETAIL`, `PROFILE`, `CANON`, `EXPLORE`, `SQUADS`, `COWATCH`, `QUEUE`, `FEED`, `SETTINGS`, `THEME`, `LEGAL`.
- `<NUMBER>`: 2-digit sequential counter (e.g. `01`, `02`).

**Examples**:
- `[FE-AUTH-01] AuthScreen: Implement Official Telly Logo & Dynamic Poster Backdrop`
- `[FE-DETAIL-03] Title Detail: Route Co-Watch Button to Two-To-Watch Hub (SCR-16)`
- `[ALGO-TASTE-01] Taste Match: Fix Self-Comparison 50% Anomaly and Clarify Metrics`
- `[FE-THEME-01] Theme System: Implement Day Cathode Light Mode & Theme Switcher`

### 2.2 Standardized Label Taxonomy

Every issue must have at least one **Type**, one **Area**, and one **Priority** label.

#### Issue Types
| Label | Color | Description |
|---|---|---|
| `bug` | `#FF4B6E` | Something isn't working as expected, broken UI, or failing math |
| `enhancement` | `#D2FF52` | Quality-of-life upgrade, refined interaction, or UI polish |
| `feature` | `#7C5CFF` | Major new functional capability |
| `design` | `#FFA733` | Layout overhaul, typography, colors, or visual tokens |

#### Functional Areas
| Label | Color | Associated Screens & Code Locations |
|---|---|---|
| `area:auth` | `#6E7681` | `AuthScreen` (`SCR-01`), OAuth, password recovery |
| `area:logging` | `#D2FF52` | `LoggingStudioScreen` (`SCR-09`), `LogRevealScreen` (`SCR-12`) |
| `area:ranking` | `#FFA733` | `LogDuelScreen` (`SCR-10`), `BinarySearchSorter`, TrueSkill, Elo |
| `area:profile` | `#7C5CFF` | `DualCanonProfileScreen` (`SCR-14`), `FriendProfileScreen` (`SCR-15`) |
| `area:title-detail` | `#2EA043` | `ShowDetailScreen` (`SCR-08`), cast, crew, streaming providers |
| `area:explore` | `#0075CA` | `ExploreDiscoverScreen` (`SCR-07`), search, curated canons |
| `area:squads` | `#A371F7` | `SquadsListScreen` (`SCR-17a`), `SquadHubScreen` (`SCR-17b`) |
| `area:co-watch` | `#E85AAD` | `TwoToWatchScreen` (`SCR-16`), quick swipe duel, vibe picker |
| `area:queue` | `#F9D0C4` | `SmartQueueScreen` (`SCR-13`), custom lists, shared watchlists |
| `area:feed` | `#1D76DB` | `ActivityFeedScreen` (`SCR-05`), reactions, in-feed discovery |
| `area:settings` | `#8A99AD` | `SettingsHubScreen` (`SCR-20`), `EditProfileStudioScreen` |
| `area:theme` | `#E36209` | `TellyTheme`, dark/light mode switcher, color tokens |

#### Priority Tiers
| Label | Color | Criteria |
|---|---|---|
| `p0-blocker` | `#B60205` | Crashing app, broken build, auth loop, data corruption |
| `p1-high` | `#D93F0B` | Core feature broken, major visual regression, incorrect ranking math |
| `p2-medium` | `#FBCA04` | Secondary feature missing, UI clarity, layout polish |
| `p3-low` | `#0E8A16` | Minor cosmetic adjustment, developer note cleanup |

#### Workflow States
| Label | Description |
|---|---|
| `status:triage` | Newly ingested item awaiting review and full specification |
| `status:ready` | Ready for a developer to pick up on a dedicated branch |
| `status:in-progress` | Branch created, implementation active |
| `status:review` | Pull request opened and passing automated CI gates |
| `status:done` | PR merged to main and verified |

---

## 3. Issue Template & Markdown Structure

When creating an issue via CLI or web, use this standard template:

```markdown
### Summary
Concise description of the user feedback or bug report.

### Context & Screen Location
- **Screen**: `ShowDetailScreen (SCR-08)`
- **File**: `lib/features/title_detail/presentation/screens/show_detail_screen.dart`
- **Spec Reference**: `docs/features/08_TITLE_DETAIL_PAGE_SPEC.md`

### Current Behavior (As-Is)
Detailed explanation of what currently happens, what is missing, or what looks off.

### Proposed Solution (To-Be)
Step-by-step engineering plan, UI adjustments, architectural updates, and resolution of any open design questions.

### Acceptance Criteria
- [ ] Task 1 with verifiable outcome
- [ ] Task 2 with verifiable outcome
- [ ] Automated tests pass (`dart analyze --fatal-infos` & `flutter test`)
```

---

## 4. GitHub CLI (`gh`) Commands

Ensure you are logged into GitHub CLI (`gh auth login`).

### 4.1 Syncing Standardized Labels
Run the built-in label synchronization script:
```powershell
powershell -ExecutionPolicy Bypass -File .agents/skills/issue-manager/scripts/ensure_labels.ps1
```

### 4.2 Creating an Issue
```bash
gh issue create \
  --repo kandraos3/Telly \
  --title "[FE-AUTH-01] AuthScreen: Implement Official Telly Logo & Dynamic Poster Backdrop" \
  --label "enhancement,area:auth,p2-medium,status:ready" \
  --body-file issue_body.md
```

### 4.3 Reading & Filtering Issues
- **List ready issues for a domain**:
  ```bash
  gh issue list --label "area:ranking" --state open
  ```
- **List by priority**:
  ```bash
  gh issue list --label "p1-high" --state open
  ```
- **View full issue details**:
  ```bash
  gh issue view <issue-number>
  ```
- **Search issues**:
  ```bash
  gh issue list --search "swipe duel"
  ```

### 4.4 Picking Up an Issue to Work On
1. **Assign to yourself**:
   ```bash
   gh issue edit <issue-number> --add-assignee "@me" --add-label "status:in-progress" --remove-label "status:ready"
   ```
2. **Create feature branch**:
   ```bash
   git checkout -b feat/FE-AUTH-01-logo-backdrop
   ```
3. **Commit with conventional ticket anchor**:
   ```bash
   git commit -m "feat(auth): [FE-AUTH-01] implement official logo and dynamic poster backdrop"
   ```
4. **Link PR to auto-close issue**:
   In the PR description, include: `Fixes #<issue-number>`.

---

## 5. Feedback Ingestion Protocol

When presented with raw feedback (transcription, audio notes, bug reports):
1. **Listen / Parse**: Extract all discrete complaints, ideas, suggestions, and regressions.
2. **De-duplicate & Group**: Group feedback by functional area.
3. **Resolve Underspecified Points**: Formulate concrete UX/architectural recommendations before writing issues.
4. **Draft Proposal**: Present the proposed issue list to the user for confirmation.
5. **Batch Create**: Once confirmed, execute creation via `gh issue create` using the standardized taxonomy.
