# AI Dev Workflow

Structure for AI-assisted development, as plain markdown and a shell script — no framework, no runtime, no lock-in to one AI tool.

**The idea in one line:** a script does the deterministic work, the agent does the semantic work, and the filesystem carries the structure that people usually reach for an orchestration framework to provide.

Creating directories, copying files and substituting values is mechanical — a script should do it, identically every time. Translating *"prefer immutability"* into `final` or `const` or `Final` requires reading your codebase and making a judgement — only a model can do that. Most of the friction in AI-assisted development comes from pushing work across that line in one direction or the other. This repo draws the line and keeps it.

## What it gives you

- **One set of operating conventions** every workspace references instead of restating, so a shared rule changes in one place.
- **Rules enforced where every tool shares a layer** — git. Committing a secret, or a commit message advertising the coding agent, is blocked by a hook, whichever assistant made the change.
- **One authored source, compiled per tool.** You write `WORKFLOW.md` and each side's `CLAUDE.md`; `AGENTS.md` is emitted from them, so a non-Claude host boots with the same rules rather than a second copy that drifts.
- **A review gate that can't quietly evaporate.** Work isn't done until a reviewer has seen the diff; where the best available reviewer is one only a human can start, the task stays open and says so rather than marking itself complete.
- **Task state in the repo**, in a format stable enough to mirror to a tracker, next to the code it describes.

Nothing here is specific to one language, one framework, or one AI tool. Tool-specific pieces are isolated as *Bindings* and clearly labelled.

## Quick start

**A new project:**

```bash
cd my-new-project
/path/to/ai-dev-workflow/bin/scaffold.sh bootstrap \
  --set PROJECT_NAME=Acme \
  --set backend.LANGUAGE=Java
```

**An existing codebase:**

```bash
cd my-existing-project
/path/to/ai-dev-workflow/bin/scaffold.sh adopt
```

Either way the script finishes by writing a `WORKORDER.md`. Open the project in your AI assistant and say **"execute WORKORDER.md"** — that's the handoff from the mechanical half to the semantic half.

Options: `--workspaces backend,frontend` (choose a subset), `--set KEY=VALUE` (fill placeholders upfront, repeatable), `--target DIR` (scaffold elsewhere).

## How it works

**Phase 1 — `bin/scaffold.sh`, deterministic.** Creates the workspaces you asked for, copies the payload (never overwriting anything that exists), substitutes the placeholders you supplied, installs the git hooks, emits the `AGENTS.md` tree, generates each workspace's file index, and writes a `WORKORDER.md` listing exactly what it could not decide.

**Phase 2 — the agent, semantic.** It reads `WORKORDER.md` and `BOOTSTRAP.md` and does the work a script can't: translating each principle into your stack's idiom via the [Principle → Binding](./template/BOOTSTRAP.md#principle--binding-translation) table, filling the placeholders that need a judgement, classifying any documents already lying around, and deleting the scaffolding when it's done.

The templates ship with `{{PLACEHOLDERS}}` precisely so the second phase has something to resolve. A principle like immutability becomes `final` in Java, `const` in TypeScript, `val` in Kotlin, `Final` in Python — same rule, four bindings.

## What's in the payload

```
ai-dev-workflow/                  # this repo
├── bin/scaffold.sh               # bootstrap / adopt
└── template/                     # everything stamped into a project
    ├── WORKFLOW.md               # the shared spine — conventions every side follows
    ├── BOOTSTRAP.md              # first-run guide + Principle→Binding table
    ├── ADOPT.md                  # retrofitting an existing codebase
    ├── STACK.md                  # this project's stack facts and commands
    ├── REVIEW.md                 # fallback review procedure (see the review gate)
    ├── CONSOLIDATION.md          # keeping append-only docs from growing forever
    ├── WORKFLOW_CHANGELOG.md     # where you record convention changes you make
    ├── .githooks/                # secret guard, commit-message rules, binding refresh
    ├── adapters/
    │   ├── agents/               # emits the AGENTS.md tree from the authored sources
    │   └── index/                # generates the per-workspace file index
    ├── backend/                  # CLAUDE.md · ARCHITECT.md · TASK.md · SESSION_LOG.md
    └── frontend/                 # the same, plus mockups/ for the UI design gate
```

A scaffolded project gets the same shape, with `AGENTS.md` emitted beside each `CLAUDE.md`.

## Core concepts

**Principle → Binding.** State the portable rule once; put the concrete mechanism where it belongs. The rule *"secrets never enter agent context"* is the principle; a `.gitignore` entry plus a pre-commit hook is the binding. One translates across stacks and tools, the other doesn't.

| Principle | Java | TypeScript | Python | Go |
|-----------|------|------------|--------|-----|
| Immutability | `final` | `const` | `Final` | value semantics |
| Dependency injection | constructor injection | constructor params | `__init__` params | struct fields |
| Validation | Bean Validation | Zod schemas | Pydantic | validator functions |

**Operating modes.** Every session runs in exactly one, declared at the start. **SPEC** analyses, designs and writes tasks — it never touches application source. **BUILD** implements a task the user has named. BUILD may do anything SPEC may do; the reverse never holds. An approved plan authorises the plan, not the build.

**Enforce at the layer every tool shares.** A rule written only in one assistant's config protects you only while you use that assistant, and a rule written only in prose is one an agent can rationalise around. The rules that matter are in git hooks, so they fire on any commit regardless of what produced it.

**One source, referenced — never copied.** Shared rules live once in `WORKFLOW.md` and every side points at them. Two files stating the same rule is not redundancy, it's a pending contradiction.

## Contributing

Issues and PRs welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
