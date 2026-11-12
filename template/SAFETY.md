# SAFETY — what the workflow does on your machine

> ⚠️ STARTER — unbootstrapped. After [`BOOTSTRAP.md`](./BOOTSTRAP.md), remove this banner. This file **stays** in the project (not deleted).

This page is for an engineer deciding whether to install the workflow. It lists everything the workflow's code does on a computer: the git hooks it installs, the programs its scripts run, and what it reads or writes outside the repository. Everything else in the workflow is Markdown, which does nothing on its own.

**The list is checked.** The workflow's own repository has a test (`test/safety/`) that scans this payload's code and fails if the code runs a hook, a program, a network call or a dependency that the table at the end of this page does not list. It also fails if the table lists something the code no longer does. The page and the code change together.

## In short

- **No dependencies.** Nothing is installed from a package registry. The scripts need `bash`, `git` and standard Unix tools.
- **Three git hooks, which run on every commit** once `git config core.hooksPath .githooks` is set (the scaffold sets it). They never push and never contact the network.
- **No network calls.** Nothing in the workflow opens a connection. No telemetry, no update check.
- **Outside the repository:** nothing is written. The adoption sweep reads a path outside the repository only when you name it. Temporary files go under the system temp directory and are removed when each script exits.

## The git hooks

They live in `.githooks/` and run only after `core.hooksPath` points there. `git commit --no-verify` skips `pre-commit` and `commit-msg` for one commit; git never skips `prepare-commit-msg`.

- **`pre-commit`** blocks a commit that stages a real env file (`.env`, `.env.local`, …; `.env.example` is allowed) or adds a line that looks like a private key or API token. What counts as either is read from `adapters/secret-sweep/` (`env-files.txt`, `patterns.txt`); if one is missing or unusable, it refuses (every `.env*` file, or every commit) rather than skip the check. It **writes** only generated files: the file index inside each workspace's `CLAUDE.md`, and the `AGENTS.md` files compiled from `WORKFLOW.md` and each `CLAUDE.md`, and only for the sides the commit touched. What it **adds to the commit** is built from what you staged: a file you left unstaged, or the unstaged part of a staged file, stays out. An `AGENTS.md` that is your own (no "EMITTED Binding" first line) is never touched.
- **`prepare-commit-msg`** removes trailers that credit a coding agent or AI host (for example `Co-authored-by: <tool>`) from the commit message. Human co-authors are kept.
- **`commit-msg`** rejects the commit if such a trailer is still there.

## Outside the repository

- **Paths you name, read only** (`adapters/secret-sweep/secret-sweep.sh --path`). The adoption sweep reads a shell history, a database client's history or an agent's logs only at a path you give it, never a guessed one, and prints locations, never values. It writes nothing. It also reads the repository's whole history, on every branch.
- **Temporary files** under the system temp directory, removed when each script exits.

## Programs the scripts run

These are standard Unix tools plus `git` and `bash`, listed one per row below. No adapter runs a program you configure.

The test scripts (`*.test.sh`) run only when you run them. They work in temporary sandboxes and run the script under test through a variable.

## The allow-list

One row per thing the code does. The test reads the first two columns: **Kind** and **Item**. `(configured) <file>` means that file runs a program named by a setting or a variable, explained in the last column.

<!-- SAFETY:ALLOW START -->
| Kind | Item | Where | What it does |
|---|---|---|---|
| hook | `pre-commit` | `.githooks/` | Secret and env-file guard; refreshes generated files and commits only what you staged |
| hook | `prepare-commit-msg` | `.githooks/` | Removes agent/host attribution trailers from the message |
| hook | `commit-msg` | `.githooks/` | Rejects a message that still has one |
| program | `(configured) adapters/agents/emit-agents.test.sh` | test | `git` through a variable, in a sandbox |
| program | `(configured) adapters/secret-sweep/secret-sweep.test.sh` | test | The sweep under test, in a sandbox |
| program | `git` | hooks, adapters | Reads and updates the repository; never pushes |
| program | `bash` | hooks, adapters | Runs the shell adapters |
| program | `awk` | hooks, adapters | Text processing |
| program | `sed` | adapters | Text processing |
| program | `grep` | hooks, adapters | Text search |
| program | `tr` | hooks, adapters | Text processing |
| program | `sort` | adapters | Sorting |
| program | `cut` | hooks, adapters | Text processing |
| program | `wc` | adapters | Counting lines |
| program | `head` | adapters | Reading the start of a file |
| program | `tail` | a test | Reading the end of a file |
| program | `cat` | hooks, adapters | Reading files |
| program | `cmp` | hooks, adapters | Comparing files |
| program | `diff` | adapters | Printing a diff |
| program | `find` | adapters | Listing files |
| program | `ls` | a test | Listing files |
| program | `env` | tests | Running a command with a variable set |
| program | `basename` | adapters | Path handling |
| program | `dirname` | adapters | Path handling |
| program | `mktemp` | hooks, adapters | Temporary files, removed on exit |
| program | `mkdir` | adapters | Creating folders |
| program | `cp` | tests | Copying files |
| program | `mv` | adapters | Replacing a generated file |
| program | `rm` | hooks, adapters | Removing temporary files |
| program | `chmod` | tests | Making a sandboxed script executable |
| program | `seq` | a test | Generating lines |
| program | `md5sum` | tests | Comparing file contents |
<!-- SAFETY:ALLOW END -->

There are no `network`, `import` or `home` rows: the payload makes no network call, loads no module that is not built in, and writes nothing in your home directory.
