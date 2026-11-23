---
name: diff-review
description: 'Use when the user asks to see the diffs of a change ("open diffs", "show me the changes"): open each changed file''s diff one at a time with the working file on the right, wait for each to close, then ask "collect or approve?". Never commit before the user says approve.'
license: MIT
---

# Diff review — one file at a time

When several sessions share one working tree, `git diff` mixes their work, and the reviewer cannot tell which change belongs to which task. A review is also easier when each file opens, gets read and closes before the next one opens, instead of a flood of tabs. This procedure opens **this change's own files**, one at a time, **only when asked**.

## The procedure

1. **Open nothing unasked.** Wait for the user to ask for the diffs.
2. **List the files this session changed**, from its own edits, never from `git status`. It is the same list a summary of the change already shows.
3. **Open them**, one at a time:
   ```sh
   bash <this skill's folder>/scripts/diff-open.sh [--opener difftool|vscode] [--base <rev>] <files…>
   ```
   **Run it in the background** where the host limits how long a command may run, and react when it exits. A careful review takes longer than most foreground limits, and a killed command leaves the remaining diffs unopened.
4. **When it exits** (the last diff closed), ask: ***collect or approve?***
   - **collect**: the user left questions in the files; answer them (see the `reviewer-questions` skill if it is installed). Show any change an answer causes in the chat, as a before and after.
   - **approve**: the user has reviewed it and it is good. Commit those files, and only those, as one commit.
5. **Never commit before *approve*.** Pushing is a separate, explicit request.

## Showing only what a review changed

To show the user only what an automated review changed, take a snapshot before the review runs. It is a commit object of the working tree, with nothing staged and nothing on a branch:

```sh
SNAPSHOT=$(git stash create)
```

After the review, open `--base "$SNAPSHOT"`: snapshot → now is exactly what the review changed.

## The script

`scripts/diff-open.sh` needs bash and git.
- **Openers:** `difftool` (the default) uses your configured `git difftool`, so any editor works. `vscode` runs `<bin> --wait --diff` for VS Code and its forks; set the binary with `--editor-bin` (`code`, `cursor`, `codium`). `DIFF_OPENER` and `DIFF_EDITOR_BIN` set the same from the environment.
- **The right side is the real working file,** so a comment typed in the diff lands in the code. The left side is a read-only copy of the base (`HEAD` by default).
- A new file diffs against empty. A deleted file is listed, not opened. An unchanged file opens nothing. Nothing is staged or committed.
- `--all-at-once` (`vscode` only) opens every diff as a tab without waiting, as an explicit request.

Tests: `bash scripts/diff-open.test.sh`.

---

Part of [AI Dev Workflow](https://github.com/theagester12345/ai-dev-workflow), which runs a software project with a team of AI agents.
