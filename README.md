# AI Dev Workflow

A **portable, self-bootstrapping** documentation + workflow scaffold for AI-assisted software projects (Claude Code, etc.). This repo is the **master**: `bin/` holds the tooling, `template/` holds the payload that gets stamped into each new project. Improvements flow back up here so every new project starts from your latest thinking.

## What this is

**Shared operating conventions** (modes, self-review, session-log, task-sync, tracker sync, communication, cross-side sync) live once in a root **`WORKFLOW.md`** that every workspace references — so a change to a shared rule is one edit, and backend/frontend never drift. Stack- and side-specific rules stay in each workspace's own docs.

The template carries the **values** of a mature AI coding workflow — immutability, layered architecture, separate Request/Response DTOs, a canonical task tracker (Plane), PLAN/BUILD operating modes, self-review-before-done, a session-decision log, a testing philosophy, a design workflow — written **stack-agnostically** with `{{PLACEHOLDERS}}`. The same `CLAUDE.md` becomes a Spring Boot doc, a Next.js doc, a Django doc, or a Go doc on first use: the principle stays, only the mechanism changes (Java `final` ↔ TS `const` ↔ Kotlin `val` ↔ Python `Final`).

## How it works — hybrid (script + agent)

Every run has two phases:
1. **`bin/scaffold.sh` (deterministic, zero tokens):** creates the chosen workspaces, copies template files (**never overwrites**), **substitutes placeholders you pass via `--set`/`--answers`** plus ones it derives (`SIDE`, `SIDE_DIR`, `OTHER_SIDE`), **strips the `⚠️ STARTER` banner from any file it fully resolves**, detects the stack, lists loose docs to classify, and writes a **`WORKORDER.md`**.
2. **The agent (semantic):** reads `WORKORDER.md` + `BOOTSTRAP.md`/`ADOPT.md` and does only what a script can't — fill *remaining* placeholders, translate principles in the engineering `CLAUDE.md`s, **classify & move loose docs (with your approval)**, and merge rules into existing docs.

> Why split it: creating/copying/substituting files is deterministic (script); deciding *"is this doc product or legal?"* and *merging into a rich existing `CLAUDE.md`* needs judgment (agent). The more you pass to the script, the less the agent does.

## The pipeline

The workspaces form a **product-first pipeline** — define before you build:

```
product/   shape idea → Ready for Engineering (specs, decisions, business logic,
           conceptual data model, UX flows + mockups)
   │  hands down Ready features + conceptual model + approved UX
   ▼
backend/ + frontend/   architect (PLAN) turns Ready features into TASK-XXX
                       → builder (BUILD) implements → Plane mirrors TASK.md
   ▲  (reads product/ as input; never edits it)
   ↔  backend & frontend sync cross-side changes via each other's INTERFACE.md
back-office/  legal (privacy, terms, contract) + official correspondence (emails)
infra/        overall deployment architecture (INFRA.md) — maintained by BE/FE agents, optional
```

## Layout

```
ai-dev-workflow/                     # the MASTER (this repo)
├── README.md                        # this file
├── CHANGELOG.md                     # master history + absorbed-ledger for upstream pulls
├── bin/                             # master-only tooling — NEVER copied into a project
│   ├── scaffold.sh                  # bootstrap/adopt a project → writes WORKORDER.md
│   └── pull-updates.sh              # pull a project's workflow changes up → PULL/HARVEST_WORKORDER.md
└── template/                        # THE PAYLOAD — everything stamped into a project
    ├── BOOTSTRAP.md                 # greenfield brain: procedure + placeholder registry + Principle→Binding
    ├── ADOPT.md                     # brownfield brain: merge into an existing repo (never overwrite)
    ├── STACK.md                     # resolved-stack answers (filled on bootstrap)
    ├── WORKFLOW.md                  # shared operating conventions — every workspace references it — stays in project
    ├── CONSOLIDATION.md             # keep append-only docs lean (ongoing token hygiene) — stays in project
    ├── WORKFLOW_CHANGELOG.md        # project's conceptual workflow changes (for upstreaming) — stays in project
    ├── product/                     # UPSTREAM: PM + design (SHAPE/DESIGN) — no code
    │   ├── CLAUDE.md · ARCHITECT.md (Product Lead) · SESSION_LOG.md · README.md
    │   ├── IMPLEMENTATION_PLAN.md · FEATURES.md · BUSINESS_LOGIC.md
    │   └── PRODUCT_DECISIONS.md · DATA_MODEL.md (→ backend) · UX.md (→ frontend)
    ├── backend/                     # server-side doc set (any backend stack)
    │   ├── CLAUDE.md · ARCHITECT.md (PLAN/BUILD) · TASK.md · SESSION_LOG.md · TEST_GUIDE.md · README.md
    │   └── INTERFACE.md             # cross-side sync outbox (frontend reads this one file)
    ├── frontend/                    # client-side doc set (any frontend stack)
    │   ├── CLAUDE.md · ARCHITECT.md · TASK.md · SESSION_LOG.md · TEST_GUIDE.md · README.md
    │   ├── DESIGN.md                # implementation design system (tokens + component contracts)
    │   └── INTERFACE.md             # cross-side sync outbox (backend reads this one file)
    ├── back-office/                 # legal + correspondence (drafts, not legal advice)
    │   └── CLAUDE.md · PRIVACY.md · TERMS.md · CONTRACT.md · EMAILS.md · SESSION_LOG.md · README.md
    └── infra/                       # overall deployment architecture (optional; BE/FE agents maintain it)
        └── INFRA.md · README.md
```

## Quickstart

### Fresh project

Dump any notes/specs you've already collected into the **repo root**, then:

```bash
cd my-new-project
/path/to/ai-dev-workflow/bin/scaffold.sh bootstrap
# Interactive mode prompts for project details (press Enter to skip unknowns)

# OR pass what you know up front (more answers = fewer agent tokens):
/path/to/ai-dev-workflow/bin/scaffold.sh bootstrap \
  --set PROJECT_NAME=Acme \
  --set backend.LANGUAGE=Java --set frontend.LANGUAGE=TypeScript

# OR use a reusable answers file:
/path/to/ai-dev-workflow/bin/scaffold.sh bootstrap --answers project.config

# Single-stack (no monorepo):
/path/to/ai-dev-workflow/bin/scaffold.sh bootstrap --workspaces frontend
```
Then open the project in your agent: **"execute WORKORDER.md."** It confirms the stack (tracker is fixed to **Plane**), fills remaining placeholders, translates principles via the [Principle → Binding](./template/BOOTSTRAP.md#principle--binding-translation-table) table, **classifies the notes you dumped in the root** (proposing moves for approval), then removes banners and deletes the scaffolding.

### Existing project (adopt)

```bash
cd my-existing-project
/path/to/ai-dev-workflow/bin/scaffold.sh adopt                 # adds only what's missing; never overwrites
/path/to/ai-dev-workflow/bin/scaffold.sh adopt --workspaces product,frontend
```
Then: **"execute WORKORDER.md."** The agent reviews your **docs in place**, classifies each, **proposes a `git mv` plan and waits for approval**, then surgically merges the new rules into your existing docs. **It never touches source/application code.** Full procedure: [`template/ADOPT.md`](./template/ADOPT.md).

### Options
- `--workspaces a,b,c` — any subset of `product backend frontend back-office infra` (default: all). This is how you do a **single-stack** (non-monorepo) setup.
- `--interactive` — prompt for common placeholders interactively (allows skipping unknowns with Enter).
- `--non-interactive` — skip interactive prompts even when no configuration is provided.
- `--set KEY=VALUE` — fill a placeholder up front; global, or per-workspace as `WS.KEY=VALUE` (e.g. `backend.LANGUAGE=Java`). Repeatable.
- `--answers FILE` — read many `KEY=VALUE` lines from a file (reusable across projects).
- `--target DIR` — scaffold into `DIR` instead of the current directory.

Derived automatically (no need to pass): `SIDE`, `SIDE_DIR`, `OTHER_SIDE`.

### Available Placeholders

The script (and agent) recognize these placeholders. The more you provide via `--interactive`, `--set`, or `--answers`, the fewer tokens the agent uses.

**Project-level (all workspaces):**
- `PROJECT_NAME` — Product/repo name (e.g., `VovoSpaces`)
- `COMPANY_NAME` — Legal entity for back-office workspace (e.g., `Acme Inc.`)
- `JURISDICTION` — Governing law jurisdiction (e.g., `Delaware, USA`, `Ghana`)

**Backend workspace (prefix with `backend.`):**
- `LANGUAGE` — e.g., `Java 21`, `Python 3.12`, `TypeScript 5`, `Go 1.21`
- `FRAMEWORK` — e.g., `Spring Boot 3.2`, `Django 5.0`, `Express`, `Gin`
- `BUILD_TOOL` — e.g., `Maven`, `Gradle`, `pip`, `npm`, `go mod`
- `RUN_CMD` — e.g., `mvn spring-boot:run`, `python manage.py runserver`
- `BUILD_CMD` — e.g., `mvn package`, `npm run build`
- `TEST_CMD` — e.g., `mvn verify`, `pytest`, `npm test`
- `LINT_CMD` — e.g., `mvn checkstyle:check`, `npm run lint`
- `TEST_FRAMEWORK` — e.g., `JUnit 5 + Testcontainers`, `pytest + Hypothesis`
- `DB` — e.g., `Supabase PostgreSQL`, `MongoDB Atlas`
- `AUTH` — e.g., `Supabase Auth + JWT`, `Auth0`, `Firebase Auth`
- `ARCHITECT_NAME` — Persona name (e.g., `Jarvis`)
- `API_BASE_PATH` — e.g., `/api/v1`
- `PKG_ROOT` — Source root (e.g., `src/main/java/com/acme`, `src/`)

**Frontend workspace (prefix with `frontend.`):**
- Same keys as backend (adapt values: `Next.js 16`, `npm run dev`, `TypeScript 5`, etc.)
- `ARCHITECT_NAME` — e.g., `Nexus`

**Product workspace (prefix with `product.`):**
- `ARCHITECT_NAME` — Product Lead persona (e.g., `Atlas`)

**Example answers file** (`spring-nextjs.answers`):
```
PROJECT_NAME=VovoSpaces
COMPANY_NAME=Acme Inc.
backend.LANGUAGE=Java 21
backend.FRAMEWORK=Spring Boot 3.2
backend.BUILD_TOOL=Maven
backend.DB=Supabase PostgreSQL
backend.AUTH=Supabase Auth + JWT
backend.ARCHITECT_NAME=Jarvis
frontend.LANGUAGE=TypeScript 5
frontend.FRAMEWORK=Next.js 16
frontend.BUILD_TOOL=npm
frontend.ARCHITECT_NAME=Nexus
product.ARCHITECT_NAME=Atlas
```

### Verify
```bash
grep -rn "{{" .        # nothing → every placeholder resolved
```

### Manual (no script)
Skip `scaffold.sh` and just copy the payload to your repo root, then tell the agent to read `BOOTSTRAP.md`/`ADOPT.md`:
```bash
cp -r /path/to/ai-dev-workflow/template/* my-project/   # whole payload
# (or cherry-pick: cp -r template/{BOOTSTRAP.md,STACK.md,product,frontend} my-project/)
```

## Ongoing (during a project's life)

- **Cross-side sync (`INTERFACE.md`):** when a backend/frontend decision needs the other side to change, the agent writes a `REQUEST` into its own `INTERFACE.md` (no copy-paste). The other side reads it at session start or on **"sync"**, turns each into a `TASK-XXX`, and posts a `RESPONSE`. Each side writes only its own file and reads the peer's one file. (OpenAPI still carries API *shape*.)
- **Consolidation ([`template/CONSOLIDATION.md`](./template/CONSOLIDATION.md)):** append-only docs (`SESSION_LOG`, `TASK` COMPLETED, `INTERFACE`, …) are periodically distilled — archive stale entries, keep the live doc lean. The ongoing token saver.
- **Deployment ([`template/infra/INFRA.md`](./template/infra/INFRA.md)):** overall deployment architecture (Cloudflare/DNS/envs/secrets/CI-CD); BE/FE agents update it on deployment decisions — only if the project has an `infra/` dir.

## Keeping the workflow alive (upstream)

This repo is the **master** and a **testing ground**. When a project surfaces a better convention:
1. In the project, the change is logged **conceptually** (stack-agnostic) in its `WORKFLOW_CHANGELOG.md` (each entry gets a `WFC-…` id).
2. From here, run `bin/pull-updates.sh <project-dir>` — it finds entries not yet in `CHANGELOG.md` and writes `PULL_WORKORDER.md`.
3. Open this repo in your agent: **"execute PULL_WORKORDER.md"** — it applies each change to the templates (generalized, propose-then-approve) and records the id in `CHANGELOG.md`.

**No changelog in that project?** `bin/pull-updates.sh` **auto-detects** it and switches to **harvest mode**: it diffs the project's workflow docs against `template/` by *section heading* (normalized so filled placeholders don't count), lists the sections the project added, and writes `HARVEST_WORKORDER.md`. The agent extracts the portable improvements, applies them, and **backfills a `WORKFLOW_CHANGELOG.md`** into the project so it's incremental from then on. _(Heading-diff catches added/renamed sections; a rule reworded inside an existing section won't show — diff that doc directly if needed.)_

---

_Bootstrap once. Reuse forever. Improve in one place._
