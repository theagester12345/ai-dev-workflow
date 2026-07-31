# WORKFLOW — Shared Operating Conventions

The single source for conventions that apply across all workspaces. Each workspace's `CLAUDE.md` references this file instead of duplicating rules.

## Instruction precedence

When two instructions disagree, **do not invent a tie-break ad-hoc.** Resolve by this ladder. Higher on this list constrains lower. A lower layer may **narrow** a higher one; it may **never widen** a higher one (grant a write scope denies, skip the review gate, treat plan-approval as BUILD authorization, or exit SPEC into source edits).

| Priority (highest → lowest) | Layer | What it governs |
|---|---|---|
| 1 | **Spine** — this `WORKFLOW.md` | Shared hard rules: modes, review gate, task sync, secrets |
| 2 | **Side persona docs** — that workspace's `CLAUDE.md` / `ARCHITECT.md` | Side-specific procedure, stack bindings, extra MUST NOTs |
| 2 | **`AGENTS.md` tree** (when present) | Tool-facing carrier of the **same** content: root file ≡ spine (altitude 1); per-workspace file ≡ that side's persona docs (altitude 2). **Not a second authority** |
| 3 | **Named task** — the `TASK.md` card in force | *What* to build: acceptance criteria, technical constraints, `Review:` state |
| 4 | **In-session user instruction** | Priority, clarification, and explicit protocol moves (declare mode, name the task, `DA`) |

**Same-altitude files must not disagree.** A workspace `AGENTS.md` that contradicts that side's `CLAUDE.md`/`ARCHITECT.md`, or a root `AGENTS.md` that contradicts this spine, is **content drift** — fix the source; do not pick a winner by ordering.

**`AGENTS.md` is an emitted Binding**, not an authored source. `scaffold.sh` (and `adapters/agents/emit-agents.sh`) compile it from this spine (root) and from each side's `CLAUDE.md` (per workspace). Edit the source — **do not hand-edit** the Binding. Re-emit is **automatic on `git commit`** when a source or `AGENTS.md` is staged (`.githooks/pre-commit`); you can also run `bash adapters/agents/emit-agents.sh --force` mid-session. See [`adapters/agents/README.md`](./adapters/agents/README.md).

**How user instruction fits.** The user directs *which* work and clarifies ambiguity **within** the layers above. Ambiguous signals ("continue", enthusiasm, an approved plan) never widen BUILD authorization — refuse and say which mode or named task is required. An explicit `DA` widens *verbosity only*.

---

## Communication (short by default)

**Short by default.** Lead with the answer. The user should never have to ask for brevity — if they do, the default has already failed.

- Answer the question asked, not the adjacent ones; unrequested findings go in the docs (`TASK.md`, `SESSION_LOG.md`), not the reply.
- Report outcomes, not the process the tool calls already show.
- No unrequested structure — prose over headers/tables for non-enumerable content.
- Auto-expand ONLY for high-stakes decisions (architecture, trade-offs, multi-step plans) — a narrow exception, not a licence to expand by default.

- **DA** = force a detailed answer. There is **no** force-short shorthand — short *is* the default, so one would be redundant; don't reintroduce it.

## Operating Modes (SPEC / BUILD)

Every session runs in ONE mode, declared at session start. If none is declared, assume **SPEC**. The mode is a HARD boundary — if asked to act outside it, refuse and say which mode is needed.

### SPEC Mode (default)
- **Purpose:** Analysis, design, task breakdown
- **Output:** Tasks written to `TASK.md`
- **May:** Read anything, edit docs, create tasks
- **Must NOT:** Write application code, add dependencies, run builds/tests, move tasks to `IN_PROGRESS`

### BUILD Mode
- **Purpose:** Implementation
- **Input:** User names the task(s) to implement — BUILD never picks its own
- **Output:** Code changes, tests, task moved to COMPLETED
- **Process:** Read whole board → recommend order if needed → implement → verify → review gate → mark done

**BUILD contains SPEC; SPEC does not contain BUILD.** A BUILD session MAY analyse, design, and write or refile tasks in `TASK.md` without a separate session. Speccing a task inside BUILD does **not** authorize building it — implementing still requires the user to **name** it.

**An approved plan authorizes the plan, not the build.** However a SPEC is signed off — a verbal "looks good," an approved plan document, or an editor's/agent's built-in "plan mode" approval — that approves the **analysis**, not implementation. BUILD still requires the user to **name the task**. Don't treat plan-approval, mode-exit, or an enthusiastic reply as the go-ahead to write code. (The mode is named **SPEC**, not "PLAN", precisely so it can't be confused with an editor's built-in *plan mode*.)

> **Version control is user-gated — never autonomous.** `git commit` and `git push` are **NOT** part of the BUILD flow. Don't commit or push on your own initiative — **not** after a task is COMPLETED, **not** after tests/build go green. Completing a task ≠ permission to commit. Stop at a clean, verified working tree and **wait for the user's explicit command** to commit; pushing is a separate explicit command again. (Applies in every mode.)

> **Commit messages describe the change — not the coding agent.** Do not add trailers or lines that attribute, advertise, or co-author the commit to the AI host or coding agent (for example a `Co-authored-by:` naming the tool). Human co-authors remain fine. Enforcement (dependency-free, under [`.githooks/`](./.githooks/)): `prepare-commit-msg` **strips** known agent/host attribution trailers some hosts inject automatically; `commit-msg` **rejects** the commit if any remain. Same portable layer as the secret guard.

## Self-review before declaring done (BUILD — MANDATORY)

After the task is implemented and the build/tests are **green**, the BUILD session **MUST** have its own diff reviewed and fix what the review flags **before** marking the task done. This is in addition to (not a replacement for) human review.

**A gate the agent cannot invoke must block, not evaporate.** Where the best reviewer is human-only, the gate **holds the task open** instead of closing on a weaker stand-in. An honest blocked task is the correct outcome; a false pass never is.

**The reviewer is chosen by capability, not vendor.** Select the **best reviewer available**, in this order:

1. **A reviewer the agent can invoke itself** → run it, at the tier below. The gate closes in-session and the task proceeds to `COMPLETED`.
2. **A better reviewer exists but is human-only** → stop short of `COMPLETED`. Report review outstanding, name the reviewer and tier, stamp `Review: PENDING (<tier>)` on the task. **An outstanding review blocks `COMPLETED`**. Do **not** substitute the fallback here.
3. **No reviewer at all** → run [`REVIEW.md`](./REVIEW.md), the workflow's own fallback, and close the gate.

> **Never launder an unreviewed diff.** Where a better reviewer exists, running a weaker one *and recording the gate as satisfied* is worse than recording nothing.

- **No separately-billed tier is ever part of the gate.** Any tier that executes remotely or bills apart from ordinary session usage is a standing prohibition.
- **Per-task while the change is fresh** — never batched to a merge point.

**Tier by what the change *touches*, not its size.** **high** — auth/security, money/payments, data integrity/migrations/state machines, or a public API-contract change. **medium** — everything else. **The agent selects the tier itself.**

**Re-review the fixes — then stop on severity, not on count.** Re-run the review **scoped to the fix diff**. Continue only while findings are **material** (correctness, security, money, data integrity, contract); once what remains is advisory or stylistic, **record it and stop**. When the best reviewer is human-only, fix-diff re-review **also hard-blocks `COMPLETED`**.

**Addressing returned findings is named BUILD work.** Open a BUILD session and **name the task**.

**The review must be structurally independent of the author.** The fallback procedure that enforces this is [`REVIEW.md`](./REVIEW.md) — **last resort**, never a substitute for a host-provided reviewer.

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
- **First run the [review gate](#self-review-before-declaring-done-build--mandatory)** (BUILD) and fix what it flags
- Move to `COMPLETED`
- Add `Completed: YYYY-MM-DD`
- Update `_Last Updated:_`

**When the review is human-only:** the task stays `IN_PROGRESS` with `Review: PENDING (<tier>)`. It is **not** `BLOCKED`. Clear `Review:` only when a pass returns **no material findings**.

## Canonical Task Format

```markdown
### TASK-XXX: [Task Title]
**Status:** [TODO | IN_PROGRESS | COMPLETED | BLOCKED]
**Priority:** [Critical | High | Normal | Low]
**Duration:** [X hours/days]
**Category:** [per-workspace]
**Depends On:** [TASK-XXX, ...] or None
**Review:** PENDING (<tier>) (optional — set when a human-only review is outstanding)

**Description:** ...
**Technical Constraints:** ...
**Acceptance Criteria:**
- [ ] Criterion 1
- [ ] Criterion 2

**References:** ...
```

## Task Tracker Sync — the mirror Principle

These rules are **tracker-agnostic**. The concrete tool (if any) is a **Binding** that lives in an adapter, not here. This community edition ships the Principle only — add a Binding if you want a live board mirror.

- **`TASK.md` is the single source of truth.** The tracker is a **one-way, downstream mirror** — the sync **never writes back**.
- **After every `TASK.md` edit, run the sync** (dry-run, then live) when you have a Binding configured. If the tracker is unreachable, note sync as **pending**.
- **One card per task, zero duplicates:** correlate on a deterministic external id.
- **Scoped writes:** only touch issues carrying your workflow's source marker.
- **Idempotent:** a second run with no `TASK.md` change must write nothing.

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

> **Keep it lean:** when this log grows large, consolidate per [`CONSOLIDATION.md`](./CONSOLIDATION.md).

## Documentation Update Protocol

After architecture/structure changes:
- Update affected `CLAUDE.md` section (only that section)
- Keep docs minimal and current
- Don't restate what's already in other files
- **Workflow-convention changes (same change):** when you edit a *reusable* rule in this `WORKFLOW.md` or a `CLAUDE.md`/`ARCHITECT.md`, append a conceptual `WFC-…` entry to [`WORKFLOW_CHANGELOG.md`](./WORKFLOW_CHANGELOG.md). Write the **principle**, stack-agnostic.
- **`AGENTS.md` Binding (same change):** when you edit this `WORKFLOW.md` or a workspace `CLAUDE.md`, prefer letting `.githooks/pre-commit` re-emit on commit; mid-session run `bash adapters/agents/emit-agents.sh --force`. Do not hand-edit `AGENTS.md`.

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
