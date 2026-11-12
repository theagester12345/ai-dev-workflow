# AI Dev Workflow

**Run a software project with a team of AI agents** — a backend agent and a frontend agent — each with its own role, both working from the same plan, with you making the calls.

The agents don't need a framework to work together. They coordinate through plain records in your repo: one shared rulebook, a task board for each side, and a log of decisions with the options that were turned down. You name the work, approve the plans, and make the commits. It works with any AI coding tool: it is plain markdown and a shell script, with no runtime and no lock-in.

**Getting started is one command.** It sets the team up in a new repo or an existing one — see [Quick start](#quick-start).

**The idea in one line:** a script does the deterministic work, the agent does the semantic work, and the filesystem carries the structure that people usually reach for an orchestration framework to provide.

Creating directories, copying files and substituting values is mechanical — a script should do it, identically every time. Translating *"prefer immutability"* into `final` or `const` or `Final` requires reading your codebase and making a judgement — only a model can do that. Most of the friction in AI-assisted development comes from pushing work across that line in one direction or the other. This repo draws the line and keeps it.

## What it gives you

- **One set of operating conventions** every workspace references instead of restating, so a shared rule changes in one place.
- **Rules enforced where every tool shares a layer** — git. Committing a secret, or a commit message advertising the coding agent, is blocked by a hook, whichever assistant made the change.
- **One authored source, compiled per tool.** You write `WORKFLOW.md` and each side's `CLAUDE.md`; `AGENTS.md` is emitted from them, so a non-Claude host boots with the same rules rather than a second copy that drifts.
- **A review gate that can't quietly evaporate.** Work isn't done until a reviewer has seen the diff; where the best available reviewer is one only a human can start, the task stays open and says so rather than marking itself complete.
- **Task state in the repo**, in a format stable enough to mirror to a tracker, next to the code it describes.

Nothing here is specific to one language, one framework, or one AI tool. Tool-specific pieces are isolated as *Bindings* and clearly labelled.

## Running the team

How to drive the two agents without losing the thread. This is advice from running it, not a rule; nothing enforces it.

- **Build the provider before the consumer: backend → frontend.** For a feature that touches both, plan both sides before either builds. A backend that finishes first gives the frontend something real to build on.
- **Small changes follow the request chain.** When one side needs the other to change something, it says so and you carry the request to the other side's session, which files it as a task. Finish the side nobody is waiting on first. When that task is done, tell the side that asked.
- **Plan the cross-side needs you can see.** A planning session files them before the work starts: an endpoint for backend, a screen for frontend. Then a build does not stop halfway to switch sides. Needs that only show up in the code still surface while building, and that is fine.
- **One building session at a time works best for one person.** Every finished task hands its own files to you for review, and your attention is the limit.

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

## Keeping a project up to date

A scaffold is a snapshot. The template keeps improving, and without a way to carry those improvements forward, a project made from it slowly falls behind.

`bin/apply-updates.sh` closes that gap:

```bash
./bin/apply-updates.sh --status        # which projects beside this repo are behind; writes nothing
./bin/apply-updates.sh ../my-project   # one project
./bin/apply-updates.sh --all           # every project that is behind
```

Projects are found by their `.workflow-sync` stamp in the folder this repo sits in (`--root DIR` to look elsewhere). For each one it writes an `UPGRADE_WORKORDER.md` **into that project** with the exact `template/` diff since the project last synced and the changelog sections that changed since then. The mechanical part is done for you: adapters and hooks the project never edited are replaced, new ones copied, and the spine is merged into `WORKFLOW.md.upgrade`. Nothing is deleted, and nothing is committed. You then open the project in your agent and say *"execute UPGRADE_WORKORDER.md"* — it plans first, waits for your approval, and only then edits. It ports the rest **conceptually** into your real, filled docs rather than pasting template text back over them.

`bin/scaffold.sh` writes a `.workflow-sync` stamp recording the commit a project was made from, which is what makes each later run an exact diff rather than a guess. **Commit that file** — don't gitignore it.

Two behaviours worth knowing:

- **A workorder somebody has started is never overwritten** without `--force`. One nobody has touched (holding only the script's own changes) is replaced by the cumulative one.
- **It refuses to run on a dirty checkout.** Updates are computed from committed history, so uncommitted template work would be silently skipped while the project got stamped as up to date. `--allow-dirty` is the deliberate override.
- **A project with no stamp** (scaffolded before this existed) falls back to a catalog of changes rather than a diff, and this edition's changelog is written as release notes rather than as a machine-readable ledger — so the catalog will tell you it has nothing to list. Re-scaffolding over the project writes the stamp and makes every future run incremental.

## What's in the payload

```
ai-dev-workflow/                  # this repo
├── bin/scaffold.sh               # bootstrap / adopt
├── bin/apply-updates.sh          # carry template improvements into a scaffolded project
├── skills/                       # two review procedures that also work on their own (below)
├── test/                         # this repo's own checks (never copied into a project)
└── template/                     # everything stamped into a project
    ├── WORKFLOW.md               # the shared spine — conventions every side follows
    ├── BOOTSTRAP.md              # first-run guide + Principle→Binding table
    ├── ADOPT.md                  # retrofitting an existing codebase
    ├── STACK.md                  # this project's stack facts and commands
    ├── REVIEW.md                 # fallback review procedure (see the review gate)
    ├── SAFETY.md                 # what the workflow does on your machine, checked by test/safety/
    ├── CONSOLIDATION.md          # keeping append-only docs from growing forever
    ├── WORKFLOW_CHANGELOG.md     # where you record convention changes you make
    ├── .githooks/                # secret and env-file guard, commit-message rules, binding refresh
    ├── adapters/
    │   ├── agents/               # emits the AGENTS.md tree from the authored sources
    │   ├── index/                # generates the per-workspace file index
    │   └── secret-sweep/         # finds credentials a project already holds, never printing one; the hook's rules
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

## Skills

Two of the workflow's review procedures also work on their own, in any git repo, as [Agent Skills](https://agentskills.io) (`SKILL.md`). Each needs only git and a shell.

- **[`reviewer-questions`](skills/reviewer-questions/SKILL.md)** — after a change, the agent stops and asks whether you left questions in the code. *collect* gathers every one in the files that change touched as one set; *proceed* runs a guard scan that refuses while any remain.
- **[`diff-review`](skills/diff-review/SKILL.md)** — on request, opens the diffs of the files a change touched, one at a time, then asks *collect or approve?*. Nothing is committed before *approve*.

```sh
npx skills add theagester12345/ai-dev-workflow --skill reviewer-questions
npx skills add theagester12345/ai-dev-workflow --skill diff-review
```

The skills are single procedures. The full workflow, with the team, the gates and the task board, is the rest of this repo.

## Contributing

Issues and PRs welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
