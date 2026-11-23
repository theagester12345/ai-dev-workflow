# Reviewer Questions

When you review an agent's work as it streams past, you leave questions where they come up, as comments in the code. Some get noticed in passing; the rest are never seen. This skill collects them instead.

## What it does

After a change is finished, the agent stops and asks: *"Any questions in the code? Say **collect** or **proceed**."*

- **collect**: one scan, and every question in the files this change touched is presented as a single set. Questions elsewhere are listed by path and never edited. Each is answered where it belongs: in the code, in your decision record, or as a comment saying why.
- **proceed**: a silent guard scan. If questions remain, the agent refuses to go on and shows them.

Markers are deleted last, as their own step, once the discussion is closed.

## How to use it

Leave a comment with the marker `AI-Questions:` (any comment syntax, any case; `AI-Question:` works too) wherever you have a question. Use `--marker <token>` for another word. Files that only define the marker (`AGENTS.md`, `STACK.md`) are skipped by default; add others with `--exempt <path>`.

## What it needs and what it sends

POSIX `sh` and git, nothing else. The scan reads the files in your repository, untracked ones included, to find markers. It writes nothing and sends no data anywhere.

Licence: MIT. Part of [AI Dev Workflow](https://github.com/theagester12345/ai-dev-workflow).
