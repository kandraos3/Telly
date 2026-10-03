---
name: ticket-runner
description: >-
  Step-by-step workflow guide for selecting, executing, testing, and tracking
  roadmap tickets for Telly. Use whenever starting, working on, or completing a
  development ticket from docs/PROJECT_ROADMAP_AND_SPRINT_PLAN.md.
---

# Telly Ticket Runner & Implementation Guide

This skill guides the autonomous AI agent and developer through picking up, executing, verifying, and checking off tickets from the Telly engineering roadmap.

---

## 1. Ticket Lifecycle Checklist

Follow these 6 steps in sequence for every ticket:

### Step 1: Ticket Selection & Context Anchor
1. Open [`docs/PROJECT_ROADMAP_AND_SPRINT_PLAN.md`](file:///c:/Users/karla/Desktop/SeriesBeli/docs/PROJECT_ROADMAP_AND_SPRINT_PLAN.md).
2. Locate the active sprint and the next uncompleted ticket (e.g. `BE-101`, `FE-101`).
3. Check the ticket's **Dependencies** to ensure all prerequisite tickets are marked `[x]`.
4. Update the **Active Sprint Execution Dashboard** at the top of the roadmap with the current ticket ID.

### Step 2: Spec Grounding & Requirement Verification
1. Inspect the ticket's `- **Spec Reference**:` list.
2. Read the referenced file(s) and specific section(s) in `docs/`:
   - Design System: `docs/design_system/`
   - Feature Mechanics: `docs/features/`
   - Technical Specs: `docs/technical_architecture/`
   - Admin & Auth: `docs/adjacent_systems/`
3. Note exact requirements: color hex codes, font styles, widget hierarchies, API endpoints, table schemas, or mathematical formulas.

### Step 3: Granular Implementation
1. Review the ticket's checklist under `- **Granular Tasks**:`.
2. Implement classes, widgets, database migrations, or services step by step.
3. Follow Telly architectural conventions:
   - Feature-first folder structure (`lib/features/<feature>/domain|data|presentation`).
   - Riverpod for reactive state management.
   - Drift SQLite for local caching and offline WAL.
   - Dual-Canon segregation (movies and series/anime never mixed).

### Step 4: Test Authoring & Quality Gate Check
1. Implement the required tests specified under `- **Testing & Verification**:` according to [`docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md):
   - **Algorithms / DAOs / Parsers**: Unit tests (`package:test`).
   - **UI Components / Modals / Cards**: Widget tests (`package:flutter_test`).
   - **Database Procedures**: pgTAP tests (`database/tests/`).
   - **End-to-End CUJs**: Integration tests (`package:integration_test`).
2. Run analyzer and tests:
   ```bash
   dart analyze --fatal-infos
   flutter test
   ```
3. Fix any issues until 100% pass with zero warnings.

### Step 5: Roadmap Progress Accounting
1. Open [`docs/PROJECT_ROADMAP_AND_SPRINT_PLAN.md`](file:///c:/Users/karla/Desktop/SeriesBeli/docs/PROJECT_ROADMAP_AND_SPRINT_PLAN.md).
2. Mark all completed task checkboxes as `[x]`.
3. In the **Active Sprint Execution Dashboard**:
   - Increment the **Completed Tickets** counter.
   - Update the **Burn-Down %**.
   - Note the next upcoming ticket.

### Step 6: Atomic Git Commit
1. Stage modified files and the updated roadmap:
   ```bash
   git add <modified_code_files> docs/PROJECT_ROADMAP_AND_SPRINT_PLAN.md
   ```
2. Commit with conventional commit format:
   ```bash
   git commit -m "<type>(<scope>): [<TICKET-ID>] <summary>"
   ```
   - Types: `feat`, `fix`, `test`, `refactor`, `perf`, `chore`.
   - Examples:
     - `feat(theme): [FE-102] implement Midnight Cathode theme tokens and typography`
     - `test(ranking): [QA-201] add logarithmic bound unit tests for binary sort`

---

## 2. Invariant Rules Summary
- **No Ghost Code**: Never write code outside a ticket.
- **No Guesses**: Always ground implementation in the exact spec documents in `docs/`.
- **No Untested Code**: Every ticket must pass its test criteria before being marked complete.
