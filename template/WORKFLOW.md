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
- Close out a finished BUILD task with a short summary and the files touched — created, changed, or deleted, as links. It reuses the file set the [review gate](#self-review-before-declaring-done-build--mandatory) already makes you declare: one list, two readers.
- Low density, not just short: one idea per sentence, plain words, no stacked clauses. A brief paragraph can still be slow to read — length and density are separate faults.
- Plain first, precise second — a reference is never the explanation. Lead with the plain statement, then the precise form for whoever needs it. An internal id (a task, a ticket, a commit) is a **pointer to an argument, not the argument**: check it by asking whether the sentence still says anything to a reader who cannot open what it names. (Cards and logs are reference material and keep the dense register — this governs replies.)
- Code comments carry the *why* — the constraint or the non-obvious reason. The code already says what it does, and a comment that narrates it becomes wrong at the next edit.
- Auto-expand ONLY for high-stakes decisions (architecture, trade-offs, multi-step plans) — a narrow exception, not a licence to expand by default.

- **DA** = force a detailed answer. There is **no** force-short shorthand — short *is* the default, so one would be redundant; don't reintroduce it.

## Operating Modes (SPEC / BUILD)

Every session runs in ONE mode, declared at session start. If none is declared, assume **SPEC**. The mode is a HARD boundary — if asked to act outside it, refuse and say which mode is needed.

### SPEC Mode (default)
- **Purpose:** Analysis, design, task breakdown
- **Output:** Tasks written to `TASK.md` that meet [Canonical Task Format](#canonical-task-format)
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

**The reviewer is chosen by capability, not vendor.** Its invocation is recorded in [`STACK.md`](./STACK.md) → Commands — one command per host this project actually uses, and you try the row for *this* session. Record the command to **try**, never a verdict about the host, since running it is what tells you which rung you are on. Select the **best reviewer available**, in this order:

1. **A reviewer the agent can invoke itself** → run it at the tier below, passed to the recorded command. Stamp `Review: <reviewer> (<tier>)`; the gate closes in-session and the task proceeds to `COMPLETED`.
2. **A better reviewer exists but is human-only** → stop short of `COMPLETED`. Report review outstanding, name the reviewer and tier, stamp `Review: PENDING (<tier>)` on the task. **An outstanding review blocks `COMPLETED`**. Do **not** substitute the fallback here.
3. **No reviewer at all** → run [`REVIEW.md`](./REVIEW.md), the workflow's own fallback, and close the gate — stamped `Review: fallback (<tier>)`, since a fallback pass must never look like a real reviewer's pass.

> **Never launder an unreviewed diff.** Where a better reviewer exists, running a weaker one *and recording the gate as satisfied* is worse than recording nothing.

> **Run it — do not ask first.** Completing the BUILD task *is* the authorization to invoke a reviewer the agent can call. A host skill's "when the user asks" wording is not a reason to skip the gate or demote to case 2; only a reviewer the human must start is case 2. **A reviewer that fails to run has not run** — an error, timeout or rate-limit is not a pass: retry if it looks transient, otherwise drop a rung and say which one you landed on.

- **No separately-billed tier is ever part of the gate.** Any tier that executes remotely or bills apart from ordinary session usage is a standing prohibition.
- **Per-task while the change is fresh** — never batched to a merge point.

**The gate closes over the change *this task* authored** — not whatever sits in the working tree. In a shared checkout the working diff is global and attributes nothing, so a task can close its gate on a diff it did not write.

- Declare the file set before reviewing — the files this session edited, from its own writes.
- Scope the findings, not the reading: the reviewer may read the whole repository, but reports only against that set.
- Out-of-scope findings are reported, never fixed — route them to the owning task or the user.
- Prefer isolation: a worktree or branch per session makes the diff correct by construction and needs none of the above.

**Tier by what the change *touches*, not its size.** **high** — auth/security, money/payments, data integrity/migrations/state machines, or a public API-contract change. **medium** — everything else. **The agent selects the tier itself.**

**Re-review the fixes — then stop on severity, not on count.** Re-run the review **scoped to the fix diff**. Continue only while findings are **material** (correctness, security, money, data integrity, contract); once what remains is advisory or stylistic, **record it and stop**. When the best reviewer is human-only, fix-diff re-review **also hard-blocks `COMPLETED`**.

**Addressing returned findings is named BUILD work.** Open a BUILD session and **name the task**.

- **A regression test must be seen *red* before it is trusted green.** When a fix ships with a test, run that test against the **unfixed** code and watch it fail. A test written after the fix passes — which is not the same as a test that would have caught the bug. Author and test share assumptions, so the test can encode the defect as expected behaviour and still go green; one extra run is the only direct evidence it is coupled to the defect rather than to your implementation.

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

**When the review is human-only:** the task stays `IN_PROGRESS` with `Review: PENDING (<tier>)`. It is **not** `BLOCKED`. Replace `PENDING` with what ran only when a pass returns **no material findings**.

**Recommending what is next — name the companion, or say there isn't one.** Give the next task *and* whichever task could safely run alongside it in another session: its `Depends On` are satisfied and its file set is **disjoint** from the first. "None" is a valid and often correct answer — never manufacture a pairing, since a fabricated one produces exactly the collision the review scoping rule exists to prevent.

## Verification only a human can run — split it, don't park the card

Some acceptance criteria cannot be met by the session that wrote the code: a deploy has to happen, a dashboard has to be read, an email has to arrive, a real handset has to be held. Left on the implementing card they hold it `IN_PROGRESS` indefinitely, and a board carrying several stops distinguishing *still being built* from *built, waiting on somebody to look*.

**Split the observation into its own task.** The implementing card keeps every criterion its own session can prove and closes normally; a **verification task** carries the ones needing a person, the exact steps, and what counts as a pass.

**Why a split and not a new status:** the two halves have **different actors**. An agent builds; a person deploys and observes. One card owned by two actors is never actually anybody's turn, which is why it sits. A `VERIFYING` status leaves that unchanged while costing every tracker adapter a value to learn.

**This does not apply to the [review gate](#self-review-before-declaring-done-build--mandatory).** A human-only *review* still holds its task open under that section's own rule — splitting it would let unreviewed code read as done.

**Four conditions, all required** — without them this is a way to mark unfinished work `COMPLETED`:

1. **Criteria move; they never evaporate.** Unmet criteria are copied across **verbatim**; dropping one is a scope change and is recorded as one.
2. **Created in the same change** that closes the implementing card — never "filed later."
3. **Linked both ways.** The implementing card names its verification task; that task carries the implementing card as its `Source:`.
4. **It inherits at least the implementing card's priority**, so a Critical proof is not quietly demoted.

`COMPLETED` then means **built and reviewed, not proven in production** — so the implementing card says which task holds its proof. Where that narrowing is unacceptable (a regulated claim, a client sign-off, anything where "done" is contractual), **do not split; hold the card open.**

## Canonical Task Format

```markdown
### TASK-XXX: [Task Title]
**Status:** [TODO | IN_PROGRESS | COMPLETED | BLOCKED]
**Priority:** [Critical | High | Normal | Low]
**Duration:** [X hours/days]
**Category:** [per-workspace]
**Depends On:** [TASK-XXX, ...] or None
**Source:** [FEATURE-XXX or TASK-XXX] (optional — what this implements, or the card whose proof this verifies)
**Review:** PENDING (<tier>) (optional — set when a human-only review is outstanding)

**Description:** ...
**Technical Constraints:** ...
**Acceptance Criteria:**
- [ ] Criterion 1
- [ ] Criterion 2

**References:** ...
```

- **A card is not specced until BUILD can start from it without hunting.** Required on the card: exact file paths (or an explicit `discover under <path>` where the read did not find them); the function and type names SPEC actually saw, and how they change; ordered work steps; observable acceptance criteria. A title-plus-wish card fails this bar. Still forbidden: inventing a public API the product has not decided; line-by-line pseudocode the source must match (a second copy of the code — it rots); naming a path SPEC never opened. The next bullet is the correction valve for a card that was wrong about the code; it is not a ban on naming how.
- **A card whose proof was split names the task holding it**, and that task carries this one as its `Source:` — see [Verification only a human can run](#verification-only-a-human-can-run--split-it-dont-park-the-card). No new field.
- **A spec is a hypothesis until it meets the code.** When the implementation contradicts the card, the implementation wins: correct the card and record what was wrong and why. Never contort code to satisfy a spec that turned out wrong about the codebase, and never deviate silently.

## Task Tracker Sync — the mirror Principle

These rules are **tracker-agnostic**. The concrete tool (if any) is a **Binding** that lives in an adapter, not here. This community edition ships the Principle only — add a Binding if you want a live board mirror.

- **`TASK.md` is the single source of truth.** The tracker is a **one-way, downstream mirror** — the sync **never writes back**.
- **After every `TASK.md` edit, run the sync** (dry-run, then live) when you have a Binding configured. If the tracker is unreachable, note sync as **pending**.
- **One card per task, zero duplicates:** correlate on a deterministic external id.
- **Refuse duplicate source ids.** Two blocks in the source file carrying one id is a **parse error** — refused before any write, in dry-run as much as live. Otherwise it creates two cards for one id and every later run updates whichever the index returns.
- **A one-way mirror must be able to refuse a destructive write, not merely narrate one.** An update landing on a card the source file did not author replaces it silently, and the mirror never reads back to notice. Fail rather than proceed — and the check must fire on an artifact the run actually observed, not one it assumed.
- **Removal propagates.** A task deleted from the source is **deleted from the board** on the next run: a card the source no longer declares is stale, not extra, and leaving it makes the mirror disagree with the source silently. Dry-run must list every deletion first, and a run that parses **zero** tasks must refuse to delete anything — that is a misconfigured path, never a request to empty the board.
- **Scoped writes:** only touch issues carrying your workflow's source marker; never modify or delete anything else.
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
- **The file index is generated, never hand-written.** Each workspace `CLAUDE.md` carries an auto listing of its docs between `<!-- INDEX:START -->` / `<!-- INDEX:END -->`, rewritten by `adapters/index/emit-index.sh` and by `.githooks/pre-commit`. Never edit inside the markers; curated, annotated entries go above them. It lists docs only — code paths belong in [`STACK.md`](./STACK.md).
- **`AGENTS.md` Binding (same change):** when you edit this `WORKFLOW.md` or a workspace `CLAUDE.md`, prefer letting `.githooks/pre-commit` re-emit on commit; mid-session run `bash adapters/agents/emit-agents.sh --force`. Do not hand-edit `AGENTS.md`.

---

## UI mock design self-review — before human approval

Sibling of the [code self-review gate](#self-review-before-declaring-done-build--mandatory): same *role* (agent catches defects before human sign-off), different *surface* (reviewable UI mock, not application diff).

When BUILD work for a UI screen uses a reviewable mock (static HTML or equivalent):

1. **Create or update the mock first** — do not ask for approval on an empty mock.
2. **Agent design self-review (mandatory)** — run a design checklist and **fix material findings** before showing the human. Minimum checks: adjacent sections must not share the same dominant surface; one job per section; clear primary vs secondary CTA; readable contrast; brand/palette coherence; first viewport not cluttered; primary actions tappable on small screens.
2b. **Review the mock at the narrowest width the product supports, not only at the reviewer's window width.** A layout that fails at ~375px can pass on a laptop, and the defect surfaces after ship. Same principle as presenting every rendering mode: a width the gate never looks at is a width nobody approved.
2c. **Every rendering mode the screen supports must be present on the reviewable artifact** (theme, density, contrast, RTL, …), switchable in place, so one human pass approves all modes. Modes a screen deliberately does **not** support are recorded as **exempt** on the checklist — "absent" must be distinguishable from "forgotten." Mode-specific checks belong in the Binding checklist (surfaces that separate in one mode can collapse in another; contrast must be verified per mode).
3. **Open the mock in a real browser view for the human** after that pass (and after every edit round). A path or description alone is not review.
4. **Human approval** stamps the section record — only then may application source for that screen be edited.
5. **Implement from the approved mock as visual source of truth** — match section surfaces, palette, spacing hierarchy, and CTA treatment from the mock. Do **not** reinterpret mock colors through app theme tokens when that collapses adjacent contrast or flattens bands the mock kept distinct. Map to design-system tokens only when the visual relationships stay the same; otherwise use mock literals (or extend tokens to match the mock). Before marking the UI task done, open the shipped screen and confirm it reads like the approved mock (same section rhythm — not “same idea, different wash”), in every mode the screen supports.
6. Naming the BUILD task authorizes this full loop for **that screen only**.

**External “design score” tools are not part of the gate** — optional for accessibility/contrast doubt only. Human approval remains the taste/sign-off gate; the agent pass exists so structural failures (e.g. two adjacent same-tone bands) do not depend on the human noticing them.

Side Bindings (paths, checklist file, mock folder layout) live in that side's `CLAUDE.md` → Design Workflow — they may **narrow** this section, never widen past “src before approval,” skip the agent pass, or treat theme tokens as trumping an approved mock.

---

---

## Secrets & environment

Secrets must never enter agent context. The contract is `.env.example` (variable **names**); the real `.env` (values) is off-limits.

**One `.env` at the code root.** Exactly one `.env` / `.env.example` pair per runnable app, at the **code root** — where the stack's install and build run. Persona doc homes must not keep a second copy for the same secrets: a tool invoked from a doc home would then load a different, often stale file than the app. When a tool runs from a doc home, point it at the code-root `.env` (`--env` or equivalent) rather than making a local copy.

- **Read `.env.example`, never `.env`/`.env.*` values.** Need a var that's missing? Add its **name** to `.env.example` and ask the user to fill `.env`.
- **Never print, paste, echo, or commit a secret value** — refer to it by variable name.
- **Run, don't read.** Commands load env at runtime, so you never open the file to make them work.
- **Best of all, keep secrets out of a readable file** — injected env vars, an OS keychain, or a secrets manager. `.env` is a dev-only convenience, **untrusted-by-agents**.

Enforcement is portable, not tool-specific: `.env`/`.env.local`/`.env.*.local` are gitignored, and a dependency-free **pre-commit hook** (`.githooks/pre-commit`, wired via `git config core.hooksPath .githooks`) blocks committing a real env file or an obvious secret — on any `git commit`, whichever agent made the change. For deeper scanning, add [gitleaks](https://github.com/gitleaks/gitleaks).

---

_Shared spine. Change a rule here once — it applies everywhere._
