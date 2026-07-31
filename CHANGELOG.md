# Changelog

Notable changes to **AI Dev Workflow (Community Edition)**. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); dates are `YYYY-MM-DD`.

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
