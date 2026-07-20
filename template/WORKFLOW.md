# WORKFLOW — Shared Operating Conventions

The single source for conventions that apply across all workspaces. Each workspace's `CLAUDE.md` references this file instead of duplicating rules.

## Communication (short by default)

**Short by default.** Lead with the answer. The user should never have to ask for brevity — if they do, the default has already failed.

- Answer the question asked, not the adjacent ones; unrequested findings go in the docs (`TASK.md`, `SESSION_LOG.md`), not the reply.
- Report outcomes, not the process the tool calls already show.
- No unrequested structure — prose over headers/tables for non-enumerable content.
- Auto-expand ONLY for high-stakes decisions (architecture, trade-offs, multi-step plans) — a narrow exception, not a licence to expand by default.

- **DA** = force a detailed answer. There is **no** force-short shorthand — short *is* the default, so one would be redundant; don't reintroduce it.

## Operating Modes (SPEC / BUILD)

Every session runs in ONE mode, declared at session start. If none is declared, assume **SPEC**.

### SPEC Mode (default)
- **Purpose:** Analysis, design, task breakdown
- **Output:** Tasks written to `TASK.md`
- **May:** Read anything, edit docs, create tasks
- **Must NOT:** Write application code, add dependencies, run builds/tests, move tasks to IN_PROGRESS

### BUILD Mode
- **Purpose:** Implementation
- **Input:** User names the task(s) to implement — BUILD never picks its own
- **Output:** Code changes, tests, task moved to COMPLETED
- **Process:** Read whole board → recommend order if needed → implement → verify → mark done

**An approved plan authorizes the plan, not the build.** However a SPEC is signed off — a verbal "looks good," an approved plan document, or an editor's/agent's built-in "plan mode" approval — that approves the **analysis**, not implementation. BUILD still requires the user to **name the task**. Don't treat plan-approval, mode-exit, or an enthusiastic reply as the go-ahead to write code. (The mode is named **SPEC**, not "PLAN", precisely so it can't be confused with an editor's built-in *plan mode*.)

> **Version control is user-gated — never autonomous.** `git commit` and `git push` are **NOT** part of the BUILD flow. Don't commit or push on your own initiative — **not** after a task is COMPLETED, **not** after tests/build go green. Completing a task ≠ permission to commit. Stop at a clean, verified working tree and **wait for the user's explicit command** to commit; pushing is a separate explicit command again. (Applies in every mode.)

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
