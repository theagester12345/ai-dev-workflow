# Changelog

Notable changes to **AI Dev Workflow (Community Edition)**. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); dates are `YYYY-MM-DD`.

## [2026-11-24]

### Added
- **This repo is a Claude Code plugin marketplace.** `.claude-plugin/marketplace.json` lists both
  plugins, so `/plugin marketplace add theagester12345/ai-dev-workflow` then
  `/plugin install <name>@ai-dev-workflow` installs either one. The README shows both install routes.

### Fixed
- **Both plugins install again.** Their manifests carried a `displayName` key that Claude Code 2.1.41
  rejects (*Unrecognized key*), so neither validated nor installed. The key is removed and each plugin
  is now version 1.0.1.

## [2026-11-20]

### Changed
- **The two skills are now Claude plugins as well.** `skills/reviewer-questions/` and
  `skills/diff-review/` moved to `plugins/<name>/skills/<name>/`; each plugin folder adds a
  `.claude-plugin/plugin.json` and a README. The skills themselves are unchanged.

## [2026-11-12]

### Added
- **A credential sweep for adopting a project** (`template/adapters/secret-sweep/`). It finds the
  credentials a repository already holds, in the working tree, in the whole history and in paths you
  name, and prints where each one sits, never its value or its line: every value is masked to two
  characters and its length. Adopting an existing codebase now starts with it (`ADOPT.md`, step 0). A leaked
  credential is replaced, not hidden: its owner rotates it, and the new value lives only in the
  project's vault.
- **`SAFETY.md`: what the workflow does on your machine,** in plain words: the three git hooks, every
  program the scripts run, and the fact that nothing opens a network connection. A test in this repo
  (`test/safety/`) scans the payload and fails when the code and the page disagree.
- **Session start ends with a receipt.** Open a session with `ARCHITECT.md spec` or
  `ARCHITECT.md build TASK-XXX`; initialization ends with one line naming the persona, the mode, the
  files read and the counts in `TASK.md`. No receipt, no work. Each side's
  `CLAUDE.md` now carries its own *Start here*.
- **`apply-updates.sh --status` and `--all`.** `--status` lists which projects beside this repo are
  behind and writes nothing; `--all` writes a workorder into each. The script now does the mechanical
  part itself: adapters and hooks a project never edited are replaced, new ones copied, and the spine
  is merged into `WORKFLOW.md.upgrade`, with nothing deleted or committed. A workorder somebody has
  started is never overwritten without `--force`.
- **This repo's own tests** under `test/`: the hook's guards (each allowed case paired with its near
  miss), the update script's contract, and the safety page.

### Changed
- **The pre-commit hook commits only what you staged.** Generated files (each side's `AGENTS.md`, the
  file index in `CLAUDE.md`) are built from the staged copy and written straight into the commit, and
  refreshed only for the sides the commit touched, so another person's unstaged edits never ride along.
- **The secret guard checks renamed files and added lines only.** A template renamed to `.env` is
  caught, and deleting a committed secret, or editing next to one, is no longer blocked.
- **What counts as a real env file, and the secret patterns, are defined once** in
  `adapters/secret-sweep/`, read and checked by both the hook and the sweep. If one is missing or
  unusable (a rule `grep` rejects, a set that no longer catches a known key), the hook refuses rather
  than skip the check (every `.env*` file, or every commit, naming the file and `--no-verify`), and
  the sweep refuses to run. An added line starting with `++` is checked too.
- **The hook and the sweep read git's own diff, not the one you configured for reading.** An external
  diff tool, a textconv driver, a `-diff` attribute, a diff-prefix or root-commit setting, or a path
  git quotes (a non-ASCII name such as `configuración/.env`) no longer hides a key or an env file. A
  file whose name holds a line break is refused, and every shipped key rule has its own run-time
  sample, so a broken edit to any one of them is refused.
- **"What is next" says what each card is:** the table's columns are now *Card · What it is ·
  Run as · Waits on*.
- **Smaller rules:** edit `TASK.md` by anchored replacement, never by writing back the whole file;
  re-read the named card from the file before the first edit; a runbook only the user can run goes one
  verified step at a time; "execute `UPGRADE_WORKORDER.md`" means plan, approval, then edits.

### Fixed
- **The credential sweep never reports a false all-clear.** A file it cannot read is named and the
  run exits 2, and binary files (a lock file, a log holding a NUL) are read too.
- **A path-limited commit (`git commit <path>`) leaves your index matching the commit.** The
  regenerated `AGENTS.md` used to go into the commit but not into the index, so the next commit
  quietly reverted it. The hook only writes git's lock when it holds this commit's entries, says so
  when it cannot, and is unaffected by `GIT_GLOB_PATHSPECS` or `GIT_ICASE_PATHSPECS`.
- An upgrade no longer strips the STARTER banner from a large new file that still has placeholders.
- An upgrade never overwrites or deletes a `WORKFLOW.md.upgrade` whose conflicts you resolved, even
  with `--force`; it lists it for you instead.
- An upgrade no longer copies the workflow's own `*.test.sh` tests into a project, as scaffolding
  never did; `--status` names a project stamped from another workflow repo as such.

## [2026-10-29]

### Fixed
- **A project's own `AGENTS.md` is never overwritten.** Repos made with Lovable, Codex or Copilot
  often keep their own `AGENTS.md`. Before this fix, the first commit that staged it ran the
  pre-commit hook, which replaced it with the emitted copy of `WORKFLOW.md` and committed that
  instead. An emitted file is now recognised by its first line (the `EMITTED Binding` marker),
  never by its name: the emit refuses a file without it, `--force` included, and the hook stages
  only the files the emit names (`emit-agents.sh --list`). Adopting such a repo says so in
  `WORKORDER.md`. A test, `template/adapters/agents/emit-agents.test.sh`, holds it.
- **README:** the request chain no longer mentions an outbox, which this edition does not ship;
  the payload tree lists `bin/apply-updates.sh` and `skills/`.
- **LICENSE:** the copyright holder is Peter Agada.

### Changed
- **"What is next" is one table.** The cards that can run together come first: a BUILD, a second
  BUILD that can run beside it, and a card that needs specifying. Then come every other open card
  and what it waits on, which the board does not show. An empty slot reads *none — reason*.
- **Error codes are part of the API contract.** The backend keeps a registry of stable codes and
  their meanings, and the error body carries `code`. A code is never reused, and changing what one
  means is a breaking change.

## [2026-10-22]

### Added
- **Two standalone Agent Skills in `skills/`**, each a `SKILL.md` with its script and tests, needing
  only git and a shell:
  - **`reviewer-questions`** — after a change, stop and ask whether the reviewer left questions in
    the code; *collect* gathers every marker in the files the change touched as one set, *proceed*
    runs a guard scan that refuses while any remain, and markers are deleted last.
  - **`diff-review`** — on request, open each changed file's diff one at a time with the working
    file on the right, then ask *collect or approve?*; never commit before *approve*.
  Install with `npx skills add theagester12345/ai-dev-workflow --skill <name>`. See **Skills** in
  the README.

## [2026-09-11]

### Added
- **`bin/apply-updates.sh` — carry template improvements into a project you already scaffolded.**
  A scaffold was a snapshot: the template kept improving and projects made from it did not. The
  script writes an `UPGRADE_WORKORDER.md` into a project containing the exact `template/` diff
  since that project last synced; an agent then applies it **conceptually** to the project's real,
  filled docs — plan first, wait for approval, never paste template text back over concrete
  wording. `bin/scaffold.sh` now writes a `.workflow-sync` stamp (the commit a project was made
  from), which is what makes each later run a precise diff rather than a guess — **commit it**.
  It refuses to run on a dirty checkout, because updates come from committed history and
  uncommitted work would be skipped silently while the project was stamped as current
  (`--allow-dirty` overrides). A project with no stamp falls back to a catalog, and since this
  edition's changelog is release notes rather than a machine-readable ledger, that catalog will
  report nothing to list — re-scaffolding writes the stamp and makes future runs incremental.
  See **Keeping a project up to date** in the README.
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
