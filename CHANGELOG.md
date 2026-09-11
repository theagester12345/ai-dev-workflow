# Changelog

Notable changes to **AI Dev Workflow (Community Edition)**. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); dates are `YYYY-MM-DD`.

## [2026-09-11]

### Added
- **Portable sync from the premium master (batch 3a)** — rewritten to this edition's register, as
  with earlier batches, rather than copied.
  - **Verification only a human can run gets its own task.** Criteria the implementing session
    cannot prove — a deploy, a dashboard read, a delivered email, a real handset — move to a
    dedicated verification task under four conditions (verbatim copy, same-change creation,
    both-way links, inherited priority). The argument is **actors**: an agent builds, a person
    observes, and a card holding both halves is never anybody's turn. Explicitly does **not**
    apply to the review gate, and `COMPLETED` narrows to *built and reviewed*.
  - **A card is not specced until BUILD can start from it without hunting** — exact paths,
    the signatures SPEC actually saw, ordered work steps, observable criteria.
  - **A regression test must be seen *red* before it is trusted green.** Author and test share
    assumptions, so a test written after the fix can encode the defect as expected behaviour
    and still pass.
  - **Plain first, precise second** — an internal id is a pointer to an argument, never the
    argument itself.
  - **A reviewer command is per host, not per project** — one row per host you actually use,
    rather than a stored verdict about which host you are on.
  - **A per-tool emit target earns its place only where `AGENTS.md` cannot reach** — a reach
    test, not a prohibition, in the emit adapter's own README.
- `Source:` is now part of the canonical task format, carrying the back-pointer for a split
  verification task.

### Changed
- **README rewritten.** It opened by calling itself a "documentation scaffold" and buried the
  actual idea — the script does the deterministic work, the agent does the semantic work, and the
  filesystem carries the structure — in a blockquote halfway down. That is now the first thing on
  the page, alongside the two properties that follow from it: rules enforced in git hooks rather
  than in one assistant's config, and one authored source compiled into the `AGENTS.md` tree.

### Fixed
- **README described `PLAN` mode**, renamed to `SPEC` some time ago and `SPEC` everywhere in the
  spine. A reader following the README would have declared a mode that does not exist.
- **README understated what ships.** Its layout omitted `REVIEW.md`, `STACK.md`,
  `CONSOLIDATION.md`, `WORKFLOW_CHANGELOG.md`, `.githooks/`, both adapters and `frontend/mockups/`,
  and its quick start said to read `BOOTSTRAP.md` where the script itself prints
  *"execute WORKORDER.md"*.

## [2026-08-19]

### Added
- **Portable sync from the premium master (batch 2).** Everything below is rewritten to this
  edition's shorter register rather than copied — the premium spine states the same rules at
  roughly twice the length.
  - **Review gate:** the reviewer's invocation is recorded in `STACK.md` → Commands (a new
    `Review` row) instead of re-derived each session; run an invocable reviewer without asking
    first; a reviewer that errors or times out is **not** a pass; `Review:` now records *what
    ran*, so a fallback pass and a real one are no longer indistinguishable; and the gate closes
    over the change **this task** authored — declare the file set, report only against it, prefer
    a worktree per session.
  - **Communication:** close out a finished BUILD task with a summary and the files touched;
    low density is a separate requirement from brevity; code comments carry the *why*.
  - **Task rules:** recommending next work must name a safe parallel companion or say there is
    none; a spec is a hypothesis until it meets the code — where they disagree, the
    implementation wins and the card gets corrected.
  - **Secrets:** exactly one `.env` at the code root; no doc-home duplicate.
  - **Mirror Principle:** duplicate source ids are a parse error; a one-way mirror must be able to
    **refuse** a destructive write rather than narrate one, and its safety check must fire on an
    artifact it observed; **removal propagates** — a task deleted from the source is deleted from
    the board, with dry-run listing deletions first and a zero-task run refusing to delete at all.

  - **Generated file index:** new `adapters/index/emit-index.sh` writes a listing of each
    workspace's docs between `INDEX:START` / `INDEX:END` markers in that workspace's `CLAUDE.md`.
    The script writes what exists; your curated, annotated entries live above the markers and
    survive regeneration. Docs only, never code paths. Run by `scaffold.sh` and by
    `.githooks/pre-commit`, both **before** the `AGENTS.md` emit, since that Binding is compiled
    from `CLAUDE.md`.

  - **UI mock design gate.** New spine section: when BUILD work for a UI screen uses a reviewable
    mock, the agent creates the mock, runs a design self-review against a checklist and fixes
    material findings, opens it in a real browser for the human, and only edits application source
    after approval — then implements from the approved mock as the visual source of truth. Every
    rendering mode the screen supports must be present on the artifact, and it is reviewed at the
    narrowest width the product supports. Ships with `frontend/mockups/DESIGN_REVIEW.md` (the
    checklist), `frontend/mockups/README.md`, and a self-contained frontend Binding.

### Not included (deliberately)
- Update automation (`apply-updates` / `pull-updates`) and its workorder rules — premium.
- Any tracker adapter code. This edition ships the mirror **Principle** only.

## [2026-07-31]

### Added
- **Portable sync from the premium master (batch 1).** Instruction precedence; BUILD⊇SPEC;
  self-review gate + `REVIEW.md`; commit-message Principle with `commit-msg` /
  `prepare-commit-msg` hooks; `AGENTS.md` emit adapter (`adapters/agents/`) with
  pre-commit re-emit; tracker-mirror *Principle* (no Plane Binding); `STACK.md`,
  `CONSOLIDATION.md`, `WORKFLOW_CHANGELOG.md`.
- **Scaffold ships what the docs promise** for the above (hooks install, AGENTS emit,
  REVIEW/STACK/CONSOLIDATION/WFC copies).

### Fixed
- **`scaffold.sh` `ALL_WS`** now matches shipped workspaces (`backend` / `frontend` only).
  Previously advertised product / back-office / infra without shipping those templates.

### Notes
- Sourced from the private premium master catalog (`EDITION_SYNC` / TASK-025). Premium
  pillars (product, legal/back-office, infra, apply/pull-updates) were **not** copied.

## [2026-07-07]

### Security
- **Secrets & environment convention.** New `WORKFLOW.md` section: agents read `.env.example`
  (variable *names*), never `.env` values; never print/echo/commit a secret; prefer keeping
  secrets out of a readable file entirely (injected env / keychain / secrets manager).
- **Portable enforcement.** `scaffold.sh` now gitignores `.env` / `.env.local` / `.env.*.local`
  and installs a dependency-free **pre-commit secret guard** (`.githooks/pre-commit`, wired via
  `core.hooksPath`) that blocks committing a real env file or an obvious secret — on any
  `git commit`, whichever agent staged it. Add [gitleaks](https://github.com/gitleaks/gitleaks)
  for deeper scanning.

### Changed
- **Architects load the rules, not just link them.** Both backend and frontend `ARCHITECT.md`
  now **read `WORKFLOW.md` at session start**. Previously the shared operating conventions
  (including the PLAN/BUILD boundary) were only referenced by link, so an agent could start a
  session without the rules actually in context.
- **PLAN/BUILD boundary reinforced.** PLAN sessions must refuse to write code, install, or run
  builds, and must not silently switch modes — say a BUILD session is needed.

---

_Community Edition — MIT licensed. Advanced editions (product workspace, legal, infra,
cross-repo update automation) are tracked separately._
