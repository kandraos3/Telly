# Decision records

Short records of product and architecture decisions whose reasons are not obvious from the spec. Examples: removing a feature, picking one design over another, a policy or pricing call.

- File name: `NNNN-short-kebab-title.md`, numbered in order.
- Never edit an accepted record's decision. Write a new one that supersedes it, and mark the old one `Superseded by NNNN`.
- Link the record from the epic or issue it came from, and from the spec section it shapes.

## Template

```markdown
# NNNN. Title

- **Date**: YYYY-MM-DD
- **Status**: Proposed | Accepted | Superseded by NNNN
- **Issue**: #N

## Context
What forced a decision.

## Decision
What we chose.

## Consequences
What changes, what we give up, what follow-up work this creates.
```

## Index

| # | Decision | Status |
|---|---|---|
| [0001](0001-issues-are-the-ticket-system.md) | GitHub issues are the ticket system; the sprint roadmap is frozen | Accepted |
| [0002](0002-standard-stages-for-ideas.md) | Every idea follows five standard stages; agents own all tracking | Accepted |
