# Secret sweep — `secret-sweep.sh`

**Find the credentials a project already holds, without ever printing one.** The pre-commit guard stops new leaks; nothing looked at what existed before the workflow arrived. A credential can sit in a comment, a task card or an agent's transcript, and a password written in a sentence is not shaped like a key, so a key-shaped scan misses it. This sweep is adoption's first card (`ADOPT.md`, step 0); run it again whenever a leak is suspected. The rule it serves: [`WORKFLOW.md` → Secrets & environment](../../WORKFLOW.md#secrets--environment).

```bash
bash adapters/secret-sweep/secret-sweep.sh                         # the working tree and the whole history
bash adapters/secret-sweep/secret-sweep.sh --path ~/.bash_history  # a path the user names: locations only
```

| Scope | What it reads | What it prints |
|---|---|---|
| `--tree` | tracked and untracked files; ignored files and **real env files** are skipped | `tree  <path>:<line>  <rule>  <ab…(len N)>`: never the line, which can hold a value no rule matched |
| `--history` | every added line on every branch; every real env file ever committed | `history  <commit>  <path>  <rule>  <ab…(len N)>`; an env file **by name only**, its values never read |
| `--path P` | a file or folder **the user names**: shell history, a database client's history, an agent's logs | `path  <file>:<line>  <rule>`: location and rule, never the line |

- **Masked, always:** a value prints as its first two characters and its length, and a line is never printed: a password in a URL beside a matched token is in that line too. The owner judges a find by opening the file at its location; an agent does not read the line, so the value never enters its context. The test checks that no fixture value appears in any output.
- **Paths are never guessed.** Where a tool keeps its logs differs by tool and version; the sweep reads only what the user names, and refuses a path that does not exist.
- **Exit:** 0 nothing found, 1 finds, 2 a usage error, a patterns file it cannot trust (below), or a file it could not read — each named, so the run is never a false all-clear.
- **Binary files are read too,** in the tree, under a named path and in history: a key in a lock file or an image's metadata is still a key. Each is read in full, so a large binary costs its size in time: in the tree (`--tree`, untracked files included), under a named path, and on every commit of `--history` that changed one.

## The patterns — one list, two readers

Each file is read, and checked before it is trusted, by one reader the hook and the sweep share: `patterns.sh` for the two pattern files, `env-files.sh` for `env-files.txt`. A stray carriage return (a Windows checkout) is stripped; a rule `grep -E` rejects, an empty file or a set that no longer catches a known sample is refused, never read as "nothing found". `patterns.txt` has one sample per shipped rule, built at run time in `patterns.sh`, so a broken edit to any of them is refused; removing a shipped rule on purpose means removing its sample there too. Both read git's own diff and paths as git writes them for scripts: an external diff tool, a textconv driver, a `-diff` attribute, a diff-prefix or root-commit setting, or a quoted path never hides a line or an env file.

- **`patterns.txt`** — key-shaped credentials: private-key headers, cloud keys, common tokens. One extended regex per line, named by the comment above it. **The pre-commit hook reads this same file** on every commit (added lines only), so a rule added here is enforced in both places. If the file (or its reader) is missing or unusable, the hook **refuses every commit**, naming the file and the `git commit --no-verify` escape, and the sweep refuses to run: a guard that cannot check never passes in silence.
- **`env-files.txt`** — what counts as a **real env file**: an `env-file` rule and a `template-suffix` rule (`.example`, `.sample`, `.template`, `.dist`). **The hook reads this same file** to refuse committing one; the sweep reads it to skip one in the tree and to name one in history. Add a template suffix here and both follow it. Each rule is checked against known names before it is trusted (it must match `.env`; the template rule must match `.env.example` and not `.env`), so a stray carriage return or a misplaced comment can never leave a rule that matches nothing. If the file is missing or malformed, the hook refuses every `.env*` file, templates included, and says how to restore it; the sweep refuses to run.
- **`patterns-words.txt`** — credentials written as words (`the admin password is …`, `password=…` in a comment). **The sweep alone reads it**, ignoring case: on every commit it would be noise. A value counts only if it is at least 6 characters and holds a digit or a symbol, so `the password is required`, `<your-password>` and `${API_TOKEN}` are not reported.

## After a find

**Each high-risk find becomes its own card**, naming the owner's steps, with acceptance criteria checkable without the value:

1. **The owner rotates it** — user-gated, like any change to a live environment. Removing the value from a file or from history does not un-leak it.
2. **The new credential lives only in the project's vault**, kept apart from the owner's personal one by default; the project's infrastructure notes record which vault and the rotation date, never the value.
3. **The owner scrubs their own machine** where the sweep found it: shell history, a database client, agent logs.
4. **Re-run the sweep:** the find should now be history only, of a value that no longer works.

## A CI scanner — Binding

A CI secret scanner catches key-shaped tokens and misses the words shape. Give it a custom rule for that shape, with the same regex as `patterns-words.txt`. Example, in [gitleaks](https://github.com/gitleaks/gitleaks)'s format (one tool among several; adapt to yours):

```toml
[[rules]]
id = "password-in-words"
description = "A credential written as words, e.g. in a migration comment"
regex = '''(?i)(password|passwd|passphrase|pwd|secret|token|api[ _-]?key)["']?\s*(=|:|\sis|\swas)\s*["']?[^\s'"<>{}$]*[0-9!@#%^&*_+=~-][^\s'"<>{}$]*'''
```

**Tests:** `bash adapters/secret-sweep/secret-sweep.test.sh` — a throwaway sandbox; fixture values are built at run time.
