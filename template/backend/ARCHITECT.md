# ARCHITECT.md - {{PROJECT_NAME}} Backend

Guide for PLAN mode sessions. See [WORKFLOW.md → Operating Modes](../WORKFLOW.md#operating-modes-plan--build).

## PLAN Mode Responsibilities

**Purpose:** Analysis, architecture, task breakdown

**You MAY:**
- Read any file
- Edit documentation
- Create/update tasks in `TASK.md`
- Research patterns and best practices

**You MUST NOT:**
- Write application code
- Add dependencies
- Run build/test commands
- Move tasks to IN_PROGRESS

**To implement:** Open a BUILD mode session. If asked to write code, install, or run builds while in PLAN, **refuse and say a BUILD session is needed** — never silently switch modes.

## Session Initialization (PLAN)

1. Read [`../WORKFLOW.md`](../WORKFLOW.md) — the shared operating conventions that **govern this session** (the PLAN/BUILD boundary and its MUST-NOTs, task-sync, session-log). A link elsewhere is not enough — load the file so the rules are in context.
2. Read [`TASK.md`](./TASK.md) — understand current state
3. Review relevant documentation (`CLAUDE.md`, `SESSION_LOG.md`)
4. Clarify requirements if ambiguous

## Task Creation Guidelines

When breaking down work into tasks:

**Good task qualities:**
- Clear acceptance criteria (testable/observable)
- Single responsibility (one thing done well)
- Right-sized (2-8 hours ideal; flag bigger tasks for breakdown)
- Dependency-aware (`Depends On` field filled)
- Category-tagged for filtering

**Task categories:**
- **Feature** — new functionality
- **Bug** — fix broken behavior
- **Refactor** — improve structure without changing behavior
- **Infrastructure** — build, deploy, CI/CD, tooling
- **Documentation** — user/dev docs, API docs

## Architecture Decision Template

When making significant architectural decisions, document:

```markdown
## [YYYY-MM-DD] - [Decision Title]
**Context:** What problem are we solving?
**Options considered:**
1. Option A — pros/cons
2. Option B — pros/cons
**Decision:** Chosen option and why
**Consequences:** What changes, what stays same
```

Log to `SESSION_LOG.md` only if it meets SESSION_LOG criteria.

## Design Patterns

**When to introduce patterns:**
- Duplication across 3+ places → extract abstraction
- Growing complexity → introduce layer/pattern
- Future scaling needs → design for it

**When NOT to introduce patterns:**
- Premature optimization (YAGNI)
- Single use case
- Adds complexity without clear benefit

## Handoff to BUILD

When tasks are ready for implementation:
1. All tasks have clear acceptance criteria
2. Dependencies are explicit
3. Technical constraints documented
4. Ambiguities resolved

Then: Open BUILD mode session, name the task(s) to implement.

---

_Architecture is decision-making. Make decisions explicit, reversible where possible._
