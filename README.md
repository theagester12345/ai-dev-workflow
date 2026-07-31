# AI Dev Workflow

A **lightweight, portable** documentation scaffold for AI-assisted software development. Get your AI coding assistant (Claude, Cursor, etc.) aligned with best practices from day one.

## What this is

**Shared operating conventions** for AI-assisted development:
- Stack-agnostic architectural principles that translate to any language
- Structured task tracking integrated with your workflow
- Clear communication protocols between you and your AI assistant
- Separation of concerns across backend/frontend workspaces

The templates carry **proven patterns** — immutability, layered architecture, dependency injection, separate Request/Response DTOs — written with `{{PLACEHOLDERS}}` that resolve to your concrete stack on first use. The same principle becomes `final` in Java, `const` in TypeScript, `val` in Kotlin, or `Final` in Python.

## How it works

Every run has two phases:
1. **`bin/scaffold.sh` (deterministic):** creates the chosen workspaces, copies template files (**never overwrites**), **substitutes placeholders** you provide, installs portable **git hooks**, **emits `AGENTS.md`** from `WORKFLOW.md` / each side's `CLAUDE.md`, and writes a **`WORKORDER.md`** + **`BOOTSTRAP.md`** guide.
2. **The agent (semantic):** reads `WORKORDER.md` / `BOOTSTRAP.md` and does what a script can't — translate principles to your stack via the [Principle → Binding](./template/BOOTSTRAP.md#principle--binding-translation) table, fill remaining placeholders, and remove scaffolding.

> Why split it: creating/copying/substituting files is deterministic (script); translating architectural principles to language-specific idioms needs judgment (agent).

## Workspace Structure

### Single-stack
Just use `backend/` or `frontend/` workspace:
```
my-project/
├── BOOTSTRAP.md
├── WORKFLOW.md
└── backend/  (or frontend/)
    ├── CLAUDE.md
    ├── ARCHITECT.md
    ├── TASK.md
    └── SESSION_LOG.md
```

### Monorepo
Both workspaces with clear boundaries:
```
my-project/
├── BOOTSTRAP.md
├── WORKFLOW.md
├── backend/
│   ├── CLAUDE.md
│   ├── ARCHITECT.md
│   ├── TASK.md
│   └── SESSION_LOG.md
└── frontend/
    ├── CLAUDE.md
    ├── ARCHITECT.md
    ├── TASK.md
    └── SESSION_LOG.md
```

## Layout

```
ai-dev-workflow/                     # this repo
├── README.md                        # this file
├── LICENSE                          # MIT License
├── CONTRIBUTING.md                  # contribution guidelines
├── bin/
│   └── scaffold.sh                  # bootstrap/adopt a project
└── template/                        # payload stamped into projects
    ├── BOOTSTRAP.md                 # setup guide with Principle→Binding table
    ├── ADOPT.md                     # brownfield integration guide
    ├── WORKFLOW.md                  # shared operating conventions
    ├── backend/
    │   ├── CLAUDE.md                # AI assistant context
    │   ├── ARCHITECT.md             # PLAN mode guide
    │   ├── TASK.md                  # task tracker
    │   └── SESSION_LOG.md           # decision log
    └── frontend/
        ├── CLAUDE.md
        ├── ARCHITECT.md
        ├── TASK.md
        └── SESSION_LOG.md
```

## Quick Start

### Fresh project

```bash
cd my-new-project
/path/to/ai-dev-workflow/bin/scaffold.sh bootstrap \
  --set PROJECT_NAME=Acme \
  --set backend.LANGUAGE=Java
```

Then open the project in your AI assistant: **"Read BOOTSTRAP.md and follow the procedure."**

### Existing project

```bash
cd my-existing-project
/path/to/ai-dev-workflow/bin/scaffold.sh adopt
```

Then: **"Read ADOPT.md and retrofit the workflow."**

### Options
- `--workspaces backend,frontend` — choose subset (default: both)
- `--set KEY=VALUE` — fill placeholders upfront (repeatable)
- `--target DIR` — scaffold into a different directory

## Core Concepts

### Stack-Agnostic Principles

Instead of prescribing specific tools, we define principles that work everywhere:

| Principle | Java | TypeScript | Python | Go |
|-----------|------|------------|--------|-----|
| Immutability | `final` | `const` | `Final` | value semantics |
| Dependency Injection | Constructor `@Autowired` | Constructor params | `__init__` params | Struct fields |
| Validation | Bean Validation | Zod schemas | Pydantic | validator functions |

### Operating Modes

Every session runs in one mode:
- **PLAN**: Analysis, design, task breakdown → writes to `TASK.md`
- **BUILD**: Implementation → code changes, moves tasks to completion

## Contributing

Issues and PRs welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License - see [LICENSE](LICENSE) file for details.
