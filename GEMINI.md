# Telly: Autonomous Engineering Rules of Engagement (GEMINI.md)

> This project enforces strict Spec-Driven, Ticket-Anchored Development.
> Please review the master rules of engagement in [**`AGENTS.md`**](file:///c:/Users/karla/Desktop/SeriesBeli/AGENTS.md).

## Quick Reference
- **Roadmap & Tickets**: [`docs/PROJECT_ROADMAP_AND_SPRINT_PLAN.md`](file:///c:/Users/karla/Desktop/SeriesBeli/docs/PROJECT_ROADMAP_AND_SPRINT_PLAN.md)
- **Architecture & Test Pyramid**: [`docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md`](file:///c:/Users/karla/Desktop/SeriesBeli/docs/technical_architecture/06_TESTING_FRAMEWORK_AND_TEST_PYRAMID.md)
- **Design System Tokens**: [`docs/design_system/01_DESIGN_PHILOSOPHY_AND_STYLE_GUIDE.md`](file:///c:/Users/karla/Desktop/SeriesBeli/docs/design_system/01_DESIGN_PHILOSOPHY_AND_STYLE_GUIDE.md)

### Non-Negotiable Workflow
1. Never code without an active **Ticket ID** from the roadmap.
2. Always read the referenced **Spec Document** in `docs/` before coding.
3. Every ticket must include tests adhering to the **70/20/10 Test Pyramid**.
4. Pass `dart analyze` and `flutter test` before claiming completion.
5. Check off completed tasks `[x]` and update the **Active Sprint Execution Dashboard** in the roadmap.
6. Commit using `feat(<scope>): [<TICKET-ID>] <description>`.
