# WORKFLOW — Shared Operating Conventions

The single source for conventions that apply across all workspaces. Each workspace's `CLAUDE.md` references this file instead of duplicating rules.

## Communication (default concise)

**Default = concise.** Lead with the answer; keep it skimmable.

- **SA** = short answer (force brevity)
- **DA** = detailed answer (force depth)

Auto-expand only for high-stakes decisions (architecture, trade-offs, multi-step plans).

## Operating Modes (PLAN / BUILD)

Every session runs in ONE mode, declared at session start.

### PLAN Mode (default)
- **Purpose:** Analysis, design, task breakdown
- **Output:** Tasks written to `TASK.md`
- **May:** Read anything, edit docs, create tasks
- **Must NOT:** Write application code, add dependencies, run builds/tests, move tasks to IN_PROGRESS

### BUILD Mode
- **Purpose:** Implementation
- **Input:** User names the task(s) to implement
- **Output:** Code changes, tests, task moved to COMPLETED
- **Process:** Read whole board → recommend order if needed → implement → verify → mark done

## Task Synchronization Protocol

`TASK.md` is the single source of truth for task state.

**Before work:**
- Read `TASK.md`
- Ensure no other agent is on the same task
- Move task to `IN_PROGRESS`
- Verify `Depends On` are `COMPLETED`

**During work:**
- Keep it `IN_PROGRESS` until all acceptance criteria met
- File newly-discovered tasks immediately

**After work:**
- Move to `COMPLETED`
- Add `Completed: YYYY-MM-DD`
- Update `_Last Updated:_`

## Canonical Task Format

```markdown
### TASK-XXX: [Task Title]
**Status:** [TODO | IN_PROGRESS | COMPLETED | BLOCKED]
**Priority:** [Critical | High | Normal | Low]
**Duration:** [X hours/days]
**Category:** [per-workspace]
**Depends On:** [TASK-XXX, ...] or None

**Description:** ...
**Technical Constraints:** ...
**Acceptance Criteria:**
- [ ] Criterion 1
- [ ] Criterion 2

**References:** ...
```

## SESSION_LOG Protocol

Log to `SESSION_LOG.md` ONLY when at least one holds:
1. **Workflow lesson** — process discovery worth remembering
2. **Non-obvious gotcha** — bug/surprise that took real time
3. **Judgement call** with rejected alternatives

**Don't log:** routine pattern application, acceptance criteria recaps, files changed.

```markdown
## [YYYY-MM-DD] - [Title]
**Decision / Lesson:** ...
**Reasoning:** ...
**Trigger criterion:** [workflow lesson / gotcha / judgement call]
```

## Documentation Update Protocol

After architecture/structure changes:
- Update affected `CLAUDE.md` section (only that section)
- Keep docs minimal and current
- Don't restate what's already in other files

---

## Secrets & environment

Secrets must never enter agent context. The contract is `.env.example` (variable **names**); the real `.env` (values) is off-limits.

- **Read `.env.example`, never `.env`/`.env.*` values.** Need a var that's missing? Add its **name** to `.env.example` and ask the user to fill `.env`.
- **Never print, paste, echo, or commit a secret value** — refer to it by variable name.
- **Run, don't read.** Commands load env at runtime, so you never open the file to make them work.
- **Best of all, keep secrets out of a readable file** — injected env vars, an OS keychain, or a secrets manager. `.env` is a dev-only convenience, **untrusted-by-agents**.

Enforcement is portable, not tool-specific: `.env`/`.env.local`/`.env.*.local` are gitignored, and a dependency-free **pre-commit hook** (`.githooks/pre-commit`, wired via `git config core.hooksPath .githooks`) blocks committing a real env file or an obvious secret — on any `git commit`, whichever agent made the change. For deeper scanning, add [gitleaks](https://github.com/gitleaks/gitleaks).

---

_Shared spine. Change a rule here once — it applies everywhere._
