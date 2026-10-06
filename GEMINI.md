# Telly: Autonomous Engineering Rules of Engagement (GEMINI.md)

> This project enforces strict Spec-Driven, Issue-Anchored Development.
> Please review the master rules of engagement in [**`AGENTS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/AGENTS.md).

## Quick Reference
- **How work is tracked**: [`docs/process/WORKFLOW.md`](file:///c:/Users/karla/Desktop/SeriesBeli/docs/process/WORKFLOW.md) (GitHub issues + [Telly board](https://github.com/users/kandraos3/projects/1))
- **Direction**: [`docs/ROADMAP.md`](file:///c:/Users/karla/Desktop/SeriesBeli/docs/ROADMAP.md)
- **Architecture & Test Pyramid**: [`docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md)
- **Supabase Deployment Skill**: [`.agents/skills/supabase-deploy/SKILL.md`](file:///c:/Users/karla/Desktop/SeriesBeli/.agents/skills/supabase-deploy/SKILL.md)
- **Design System Tokens**: [`docs/design_system/01_DESIGN_PHILOSOPHY_AND_STYLE_GUIDE.md`](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/01_DESIGN_PHILOSOPHY_AND_STYLE_GUIDE.md)

### Non-Negotiable Workflow
1. Never code without a **GitHub issue** (`#N`). Use the `intake` / `shape` / `ship` skills in `.agents/skills/`.
2. Always read the spec sections the issue cites in `docs/` before coding.
3. Every issue must include tests adhering to the **70/20/10 Test Pyramid**.
4. Pass `dart analyze` and `flutter test` before claiming completion.
5. Move the issue on the board (`python tool/tracker/tracker.py track N --status ...`) and update the spec in the same commit as any behaviour change.
6. Commit using `<type>(<scope>): <description> (#N)` with `Fixes #N`.
7. Do all Supabase backend work (migrations, edge functions, secrets, pgTAP) through the **`supabase-deploy`** skill. Start with its `status` action; the human only runs `supabase login`; confirm before writing to `telly-prod`.
