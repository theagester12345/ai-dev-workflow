# Diff Review

When several sessions share one working tree, `git diff` mixes their work, and a flood of open tabs makes a review harder. This skill opens only this change's own files, one at a time, when you ask.

## What it does

Say *open diffs* (or *show me the changes*). The agent lists the files it changed, from its own edits, and opens each diff in turn: the base on the left, read-only, and the real working file on the right, so a comment you type lands in the code. When the last diff closes, it asks ***collect or approve?***

- **collect**: answer the questions you left in the files (pairs with the Reviewer Questions plugin).
- **approve**: commit those files, and only those, as one commit. Nothing is committed before you approve, and pushing is a separate request.

To see only what an automated review changed, take a snapshot first (`git stash create`) and open the diffs with `--base` set to it.

## What it needs and what it sends

bash and git. It opens diffs in your configured `git difftool`, or in VS Code and its forks (`code`, `cursor`, `codium`). It writes the left-side base copies to a temporary folder (`$TMPDIR/diff-open.*`) and removes its own such folders once they are a day old. It changes nothing in your repository, stages nothing, and sends no data anywhere.

Licence: MIT. Part of [AI Dev Workflow](https://github.com/theagester12345/ai-dev-workflow).
