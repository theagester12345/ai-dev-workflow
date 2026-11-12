#!/usr/bin/env bash
# emit-agents.test.sh — the AGENTS.md emitter and the pre-commit hook that runs it, in a sandbox.
# Never touches a real project. Run: bash adapters/agents/emit-agents.test.sh
#
# The property under test: an emitted Binding is recognised by its marker, never by its
# name. An AGENTS.md without the marker is the project's own — never overwritten, never staged.
set -uo pipefail
# `grep -q` stops reading at its first match, so the command writing into it can die of SIGPIPE,
# and under pipefail a match then reads as a failure, at random. quiet_grep reads all of
# its input instead: use it wherever grep sits on the right of a pipe.
quiet_grep() { grep "$@" >/dev/null; }
HERE=$(cd "$(dirname "$0")" && pwd)
E="$HERE/emit-agents.sh"
HOOK="$HERE/../../.githooks/pre-commit"
pass=0; fail=0
ok(){ echo "PASS $1"; pass=$((pass+1)); }
ko(){ echo "FAIL $1${2:+ — $2}"; fail=$((fail+1)); }

SBX=$(mktemp -d); trap 'rm -rf "$SBX"' EXIT
P="$SBX/p"; mkdir -p "$P/backend" "$P/supabase/functions"
echo "# spine" > "$P/WORKFLOW.md"
echo "# backend persona" > "$P/backend/CLAUDE.md"

bash "$E" --target "$P" >/dev/null 2>&1
grep -q 'EMITTED Binding' "$P/AGENTS.md" && grep -q 'EMITTED Binding' "$P/backend/AGENTS.md" \
  && ok "a fresh tree emits the root and each side's Binding" || ko "fresh emit"
echo "# spine v2" > "$P/WORKFLOW.md"
bash "$E" --target "$P" --force >/dev/null 2>&1
grep -q 'spine v2' "$P/AGENTS.md" && ok "--force re-emits a marked Binding from its source" || ko "--force on a marked file"
listed=$(bash "$E" --target "$P" --force --list 2>/dev/null | sort | tr '\n' ' ')
[[ "$listed" == "AGENTS.md backend/AGENTS.md " ]] && ok "--list prints the emitted Bindings, one path per line, on stdout" || ko "--list" "$listed"

# The project's own AGENTS.md files: at the root, beside a side's CLAUDE.md, and deeper than either.
printf '# Lovable project rules\nkeep me\n' > "$P/AGENTS.md"
printf '# our backend rules\n' > "$P/backend/AGENTS.md"
printf '# edge function rules\n' > "$P/supabase/functions/AGENTS.md"
before=$(cd "$P" && md5sum AGENTS.md backend/AGENTS.md supabase/functions/AGENTS.md)
out=$(bash "$E" --target "$P" --force 2>&1); rc=$?
after=$(cd "$P" && md5sum AGENTS.md backend/AGENTS.md supabase/functions/AGENTS.md)
[[ "$before" == "$after" ]] && ok "--force leaves every unmarked AGENTS.md byte-identical" || ko "unmarked file overwritten" "$after"
[[ $rc -eq 0 ]] && ok "refusing the project's own file is not an error (the hook must not block its commit)" || ko "exit $rc"
grep -q "refuse AGENTS.md" <<<"$out" && grep -qi "project's own" <<<"$out" \
  && ok "the refusal names the file and says why" || ko "refusal message" "$out"
listed=$(bash "$E" --target "$P" --force --list 2>/dev/null)
[[ -z "$listed" ]] && ok "--list never names a file the project owns" || ko "--list named an unmarked file" "$listed"

# --only and --render, the two options the hook uses to touch only what a commit holds.
O="$SBX/only"; mkdir -p "$O/backend" "$O/frontend"
echo "# spine" > "$O/WORKFLOW.md"; echo "# be" > "$O/backend/CLAUDE.md"; echo "# fe" > "$O/frontend/CLAUDE.md"
listed=$(bash "$E" --target "$O" --list --only backend/AGENTS.md 2>/dev/null | tr '\n' ' ')
[[ "$listed" == "backend/AGENTS.md " ]] && [ ! -e "$O/AGENTS.md" ] && [ ! -e "$O/frontend/AGENTS.md" ] \
  && ok "--only emits that Binding and no other" || ko "--only" "$listed; $(cd "$O" && ls AGENTS.md frontend/AGENTS.md 2>&1 | tr '\n' ' ')"
rendered=$(printf '# be from stdin\n' | bash "$E" --target "$O" --render frontend/AGENTS.md); rc=$?
[[ $rc -eq 0 ]] && head -n 1 <<<"$rendered" | quiet_grep 'EMITTED Binding' && quiet_grep -x '# be from stdin' <<<"$rendered" \
  && quiet_grep 'source: \[`frontend/CLAUDE.md`\]' <<<"$rendered" && [ ! -e "$O/frontend/AGENTS.md" ] \
  && ok "--render prints the Binding compiled from stdin and writes nothing" || ko "--render" "rc=$rc $rendered"
# Start here is authored in each side's CLAUDE.md, so the emit adds none: the two files cannot disagree.
echo "# arch" > "$O/backend/ARCHITECT.md"
bash "$E" --target "$O" --force --only backend/AGENTS.md >/dev/null 2>&1
[[ "$(tail -n +5 "$O/backend/AGENTS.md")" == "# be" ]] \
  && ok "a side's Binding is its CLAUDE.md verbatim after the marker; no Start here is added" \
  || ko "the emit added to the side's CLAUDE.md" "$(tail -n +5 "$O/backend/AGENTS.md" | head -3 | tr '\n' ' ')"

# The hook, in a real repo: a commit that stages the project's own AGENTS.md commits it as written,
# and stages no emitted copy over it — nor any unmarked AGENTS.md the commit did not stage.
R="$SBX/r"; mkdir -p "$R/adapters/agents" "$R/.githooks" "$R/backend" "$R/frontend" "$R/docs"
cp "$E" "$R/adapters/agents/"; cp "$HOOK" "$R/.githooks/pre-commit"; chmod +x "$R/.githooks/pre-commit"
# The hook refuses every commit without its secret patterns, so the sandbox carries them.
SECRET="$HERE/../secret-sweep"
mkdir -p "$R/adapters/secret-sweep"; cp "$SECRET/patterns.txt" "$SECRET/patterns.sh" "$R/adapters/secret-sweep/"
echo "# spine" > "$R/WORKFLOW.md"; echo "# be" > "$R/backend/CLAUDE.md"; echo "# fe" > "$R/frontend/CLAUDE.md"
printf '# client rules\n' > "$R/AGENTS.md"; printf '# docs rules\n' > "$R/docs/AGENTS.md"
bash "$R/adapters/agents/emit-agents.sh" --target "$R" >/dev/null 2>&1
G=(git -C "$R" -c user.name=t -c user.email=t@t -c core.hooksPath=.githooks)
"${G[@]}" init -q && "${G[@]}" add -A && "${G[@]}" commit -qm init >/dev/null 2>&1
printf '# client rules\nedited by the client\n' > "$R/AGENTS.md"
printf '# docs rules\nunstaged edit\n' > "$R/docs/AGENTS.md"
echo "# fe v2" > "$R/frontend/CLAUDE.md"
"${G[@]}" add AGENTS.md frontend/CLAUDE.md
if "${G[@]}" commit -qm "client edit" >/dev/null 2>&1; then
  [[ "$("${G[@]}" show HEAD:AGENTS.md)" == "$(printf '# client rules\nedited by the client')" ]] \
    && [[ "$(head -2 "$R/AGENTS.md")" == "$(printf '# client rules\nedited by the client')" ]] \
    && ok "hook: the project's own AGENTS.md is committed exactly as staged, and left as written" \
    || ko "hook replaced the project's AGENTS.md" "$("${G[@]}" show HEAD:AGENTS.md | head -2)"
  "${G[@]}" diff --quiet HEAD -- docs/AGENTS.md && ko "hook staged an unmarked AGENTS.md the commit never staged" \
    || ok "hook: an unmarked AGENTS.md the commit did not stage stays unstaged"
  "${G[@]}" show HEAD:frontend/AGENTS.md | quiet_grep 'fe v2' \
    && ok "hook: a marked Binding is still re-emitted and staged" || ko "hook did not re-emit frontend/AGENTS.md"
else
  ko "hook blocked a commit of the project's own AGENTS.md"
fi

# Two shapes a naive hook aborts on: a commit where the emit names
# nothing (every AGENTS.md is the project's own), and a project that ignores the Bindings, where
# `git add` of each one the emit names fails.
hook_repo() {  # $1 = dir; a repo with the adapter and hook, whose root AGENTS.md is its own
  mkdir -p "$1/adapters/agents" "$1/.githooks"
  cp "$E" "$1/adapters/agents/"; cp "$HOOK" "$1/.githooks/pre-commit"; chmod +x "$1/.githooks/pre-commit"
  mkdir -p "$1/adapters/secret-sweep"; cp "$SECRET/patterns.txt" "$SECRET/patterns.sh" "$1/adapters/secret-sweep/"
  echo "# spine" > "$1/WORKFLOW.md"; printf '# client rules\n' > "$1/AGENTS.md"
  git -C "$1" init -q
}
H=(-c user.name=t -c user.email=t@t -c core.hooksPath=.githooks)
N="$SBX/none"; hook_repo "$N"
git -C "$N" "${H[@]}" add -A && git -C "$N" "${H[@]}" commit -qm init >/dev/null 2>&1
echo "edit" >> "$N/AGENTS.md"; git -C "$N" add AGENTS.md
git -C "$N" "${H[@]}" commit -qm edit >/dev/null 2>&1 \
  && ok "hook: a commit is not blocked when the emit names no Binding" || ko "hook aborted on an empty emit list"
I="$SBX/ignored"; hook_repo "$I"; mkdir -p "$I/backend"; echo "# be" > "$I/backend/CLAUDE.md"
git -C "$I" add AGENTS.md && git -C "$I" "${H[@]}" commit -qm own --no-verify >/dev/null 2>&1
printf '/backend/\n/WORKFLOW.md\n/adapters/\n/.githooks/\n' >> "$I/.git/info/exclude"
bash "$I/adapters/agents/emit-agents.sh" --target "$I" >/dev/null 2>&1
echo "edit" >> "$I/AGENTS.md"; git -C "$I" add AGENTS.md
if git -C "$I" "${H[@]}" commit -qm edit >/dev/null 2>&1; then
  [ -z "$(git -C "$I" ls-files backend)" ] \
    && ok "hook: with the Bindings ignored, the project's AGENTS.md commits and no ignored Binding is staged" \
    || ko "hook staged an ignored Binding"
else
  ko "hook: blocked a commit of the project's own AGENTS.md when the Bindings are ignored"
fi

# A project that adopted the workflow but has not committed it yet. The hook stages a
# side's CLAUDE.md, or a Binding, only when this commit staged it or the Binding's source.
U="$SBX/uncommitted"; hook_repo "$U"; mkdir -p "$U/adapters/index" "$U/backend" "$U/frontend"
cp "$HERE/../index/emit-index.sh" "$U/adapters/index/"
git -C "$U" add AGENTS.md && git -C "$U" "${H[@]}" commit -qm own --no-verify >/dev/null 2>&1
echo "# be" > "$U/backend/CLAUDE.md"; echo "# fe" > "$U/frontend/CLAUDE.md"
bash "$U/adapters/agents/emit-agents.sh" --target "$U" >/dev/null 2>&1
echo "edit" >> "$U/AGENTS.md"; git -C "$U" add AGENTS.md
if git -C "$U" "${H[@]}" commit -qm edit >/dev/null 2>&1; then
  got=$(git -C "$U" show --name-only --format= HEAD | tr '\n' ' ')
  [[ "$got" == "AGENTS.md " ]] && ok "hook: a commit staging only the project's own AGENTS.md contains exactly that file" \
    || ko "hook committed files nobody staged" "$got"
else
  ko "hook blocked a commit of the project's own AGENTS.md with the workflow uncommitted"
fi
echo "# be v2" > "$U/backend/CLAUDE.md"; git -C "$U" add backend/CLAUDE.md
if git -C "$U" "${H[@]}" commit -qm be >/dev/null 2>&1; then
  got=$(git -C "$U" show --name-only --format= HEAD | sort | tr '\n' ' ')
  [[ "$got" == "backend/AGENTS.md backend/CLAUDE.md " ]] \
    && git -C "$U" show HEAD:backend/AGENTS.md | quiet_grep 'be v2' \
    && ok "hook: staging a side's CLAUDE.md commits it with its re-emitted Binding, and nothing else" \
    || ko "hook: a staged CLAUDE.md commit" "$got"
else
  ko "hook blocked a commit of a staged CLAUDE.md"
fi
# A path-limited commit (`git commit <path>`) runs the hook on a temporary index while git holds
# the real one's new state in index.lock. A Binding written only to the temporary index
# went into the commit but not the real index, which the next commit would then quietly revert.
echo "# be v3" > "$U/backend/CLAUDE.md"
if git -C "$U" "${H[@]}" commit -qm be3 backend/CLAUDE.md >/dev/null 2>&1; then
  git -C "$U" show HEAD:backend/AGENTS.md | quiet_grep 'be v3' && git -C "$U" diff --cached --quiet \
    && [ -z "$(git -C "$U" status --porcelain -- backend)" ] \
    && ok "hook, path-limited commit: the Binding is committed and the real index matches the commit" \
    || ko "hook, path-limited commit: the real index is stale" "$(git -C "$U" status --porcelain -- backend | tr '\n' ' ')"
else
  ko "hook blocked a path-limited commit of a side's CLAUDE.md"
fi
# The repeat is only for git's own partial-commit index: a user's GIT_INDEX_FILE never makes the
# hook write .git/index.lock, which then belongs to another process (an IDE, another git).
echo "# be v4" > "$U/backend/CLAUDE.md"; cp "$U/.git/index" "$SBX/myidx"
GIT_INDEX_FILE="$SBX/myidx" git -C "$U" add backend/CLAUDE.md
cp "$U/.git/index" "$U/.git/index.lock"; lock_before=$(md5sum < "$U/.git/index.lock")   # a valid index, as another git would hold
if GIT_INDEX_FILE="$SBX/myidx" git -C "$U" "${H[@]}" commit -qm be4 >/dev/null 2>&1; then
  [ "$(md5sum < "$U/.git/index.lock")" = "$lock_before" ] && ok "hook, a user's own GIT_INDEX_FILE: another process's index.lock is never written" \
    || ko "hook wrote a foreign .git/index.lock"
else ko "harness: the commit with a user's GIT_INDEX_FILE failed"; fi
rm -f "$U/.git/index.lock"; git -C "$U" reset -q
# Path-limited under a user's own GIT_INDEX_FILE: git's temporary index is still
# next-index-*.lock, but its real lock is <own index>.lock, so .git/index.lock is another process's.
# The hook writes a lock only when it holds this commit's entries, and says the user's index is stale.
echo "# be v5" > "$U/backend/CLAUDE.md"; cp "$U/.git/index" "$SBX/myidx"
cp "$U/.git/index" "$U/.git/index.lock"; lock_before=$(md5sum < "$U/.git/index.lock")
if out=$(GIT_INDEX_FILE="$SBX/myidx" git -C "$U" "${H[@]}" commit -qm be5 backend/CLAUDE.md 2>&1); then
  [ "$(md5sum < "$U/.git/index.lock")" = "$lock_before" ] && git -C "$U" show HEAD:backend/AGENTS.md | quiet_grep 'be v5' \
    && ok "hook, path-limited with a user's own GIT_INDEX_FILE: another process's index.lock is never written" \
    || ko "hook wrote a foreign .git/index.lock on a path-limited commit"
  printf '%s\n' "$out" | quiet_grep "does not hold this commit's entries" \
    && ok "hook, path-limited with a user's own GIT_INDEX_FILE: says the lock is not this commit's, and that index keeps the old copies" \
    || ko "hook: the warning does not name a lock holding other entries" "$out"
else ko "harness: the path-limited commit with a user's GIT_INDEX_FILE failed" "$out"; fi
rm -f "$U/.git/index.lock"; git -C "$U" reset -q
# The same with no .git/index.lock at all: git's lock is then the user's own index's, so
# the warning names GIT_INDEX_FILE as the cause, not a foreign lock.
echo "# be v6" > "$U/backend/CLAUDE.md"; cp "$U/.git/index" "$SBX/myidx"
if out=$(GIT_INDEX_FILE="$SBX/myidx" git -C "$U" "${H[@]}" commit -qm be6 backend/CLAUDE.md 2>&1); then
  [ ! -e "$U/.git/index.lock" ] && printf '%s\n' "$out" | quiet_grep "is not .git/index.lock, so the commit runs on your own GIT_INDEX_FILE" \
    && ok "hook, path-limited with a user's own GIT_INDEX_FILE and no .git/index.lock: names GIT_INDEX_FILE as the cause" \
    || ko "hook: the warning does not name GIT_INDEX_FILE when git's lock is elsewhere" "$out"
else ko "harness: the path-limited commit with a user's GIT_INDEX_FILE and no lock failed" "$out"; fi
git -C "$U" reset -q
# Git's pathspec settings: GIT_GLOB_PATHSPECS and GIT_ICASE_PATHSPECS make
# --literal-pathspecs fail, and a check that used it read git's own lock as foreign, so the real
# index went stale again. With either set, a path-limited commit leaves it matching the commit.
for pv in GIT_GLOB_PATHSPECS GIT_ICASE_PATHSPECS; do
  echo "# be $pv" > "$U/backend/CLAUDE.md"
  if out=$(env "$pv=1" git -C "$U" "${H[@]}" commit -qm "be $pv" backend/CLAUDE.md 2>&1); then
    git -C "$U" show HEAD:backend/AGENTS.md | quiet_grep "be $pv" && git -C "$U" diff --cached --quiet \
      && [ -z "$(git -C "$U" status --porcelain -- backend)" ] \
      && ok "hook, path-limited commit with $pv set: git's own lock is accepted, the real index matches the commit" \
      || ko "hook, path-limited commit with $pv set: the real index is stale" "$(git -C "$U" status --porcelain -- backend | tr '\n' ' ') $out"
  else ko "harness: the path-limited commit with $pv set failed" "$out"; fi
done
# Under GIT_GLOB_PATHSPECS (and GIT_ICASE_PATHSPECS alike) check-ignore exits 128, which read as
# "not ignored": a Binding the repo ignores was staged into the commit. The hook clears
# both settings for its own calls.
I="$SBX/ignored-glob"; hook_repo "$I"; mkdir -p "$I/backend"; echo "# be" > "$I/backend/CLAUDE.md"
echo "backend/AGENTS.md" > "$I/.gitignore"
git -C "$I" add -A && git -C "$I" "${H[@]}" commit -qm init --no-verify >/dev/null 2>&1
bash "$I/adapters/agents/emit-agents.sh" --target "$I" >/dev/null 2>&1
echo "# be v2" > "$I/backend/CLAUDE.md"; git -C "$I" add backend/CLAUDE.md
if out=$(GIT_GLOB_PATHSPECS=1 git -C "$I" "${H[@]}" commit -qm be2 2>&1); then
  [ -z "$(git -C "$I" ls-tree -r --name-only HEAD -- backend/AGENTS.md)" ] \
    && ok "hook with GIT_GLOB_PATHSPECS set: a Binding the repo ignores is never staged" \
    || ko "hook staged an ignored Binding under GIT_GLOB_PATHSPECS"
else ko "harness: the commit with GIT_GLOB_PATHSPECS set failed" "$out"; fi


# A partly staged source. The commit carries the staged hunks
# only, the unstaged ones stay in the working tree, and each Binding matches its STAGED source —
# another session's notes in the same file never ride along.
S="$SBX/partial"; hook_repo "$S"; mkdir -p "$S/adapters/index" "$S/backend"
cp "$HERE/../index/emit-index.sh" "$S/adapters/index/"
pad=$(seq 1 12 | sed 's/^/line /')
printf '# be\n%s\n<!-- INDEX:START -->\n<!-- INDEX:END -->\nend\n' "$pad" > "$S/backend/CLAUDE.md"
printf '# spine\n%s\nend\n' "$pad" > "$S/WORKFLOW.md"
rm "$S/AGENTS.md"   # hook_repo's root AGENTS.md is the project's own; here the root Binding is under test
bash "$S/adapters/agents/emit-agents.sh" --target "$S" >/dev/null 2>&1
git -C "$S" "${H[@]}" add -A && git -C "$S" "${H[@]}" commit -qm init >/dev/null 2>&1
printf '# be STAGED\n%s\n<!-- INDEX:START -->\n<!-- INDEX:END -->\nend\n' "$pad" > "$S/backend/CLAUDE.md"
printf '# spine STAGED\n%s\nend\n' "$pad" > "$S/WORKFLOW.md"
echo "# notes" > "$S/backend/NOTES.md"
git -C "$S" add backend/CLAUDE.md WORKFLOW.md backend/NOTES.md
printf '# be STAGED\n%s\n<!-- INDEX:START -->\n<!-- INDEX:END -->\nend UNSTAGED\n' "$pad" > "$S/backend/CLAUDE.md"
printf '# spine STAGED\n%s\nend UNSTAGED\n' "$pad" > "$S/WORKFLOW.md"
if git -C "$S" "${H[@]}" commit -qm partial >/dev/null 2>&1; then
  for f in backend/CLAUDE.md WORKFLOW.md backend/AGENTS.md AGENTS.md; do
    c=$(git -C "$S" show "HEAD:$f")
    grep -q STAGED <<<"$c" && ! grep -q UNSTAGED <<<"$c" \
      && ok "hook, partly staged source: HEAD:$f has the staged hunk and not the unstaged one" \
      || ko "hook, partly staged source: HEAD:$f" "$(grep -c UNSTAGED <<<"$c") unstaged line(s)"
  done
  grep -q 'end UNSTAGED' "$S/backend/CLAUDE.md" && grep -q 'end UNSTAGED' "$S/WORKFLOW.md" \
    && ! git -C "$S" diff --quiet -- backend/CLAUDE.md WORKFLOW.md \
    && ok "hook, partly staged source: the unstaged hunks are still in the working tree, still unstaged" \
    || ko "hook, partly staged source: the unstaged hunks were lost or staged"
  git -C "$S" show HEAD:backend/CLAUDE.md | quiet_grep 'NOTES.md' \
    && ok "hook, partly staged source: the committed CLAUDE.md still carries the refreshed index" \
    || ko "hook, partly staged source: the committed index was not refreshed"
else
  ko "hook blocked a commit of a partly staged CLAUDE.md"
fi
# A staged hand-edit of a Binding is overwritten from its source as committed, not as edited on disk.
printf '# be STAGED\n%s\n<!-- INDEX:START -->\n<!-- INDEX:END -->\nend UNSTAGED 2\n' "$pad" > "$S/backend/CLAUDE.md"
echo "hand edit" >> "$S/backend/AGENTS.md"; git -C "$S" add backend/AGENTS.md
if git -C "$S" "${H[@]}" commit -qm binding >/dev/null 2>&1; then
  c=$(git -C "$S" show HEAD:backend/AGENTS.md)
  ! grep -q 'hand edit' <<<"$c" && ! grep -q UNSTAGED <<<"$c" && grep -q 'be STAGED' <<<"$c" \
    && ok "hook: a staged Binding alone is re-emitted from its committed source, not the working tree" \
    || ko "hook: a staged Binding alone" "$(tail -2 <<<"$c" | tr '\n' ' ')"
else
  ko "hook blocked a commit of a staged Binding"
fi

# Two sessions in one checkout. Side A (backend) has an
# unstaged edit and a new doc; side B (frontend) commits only its own files. The commit carries
# nothing of A's, and A's files — and the root Binding, whose source was not staged — are left
# byte-identical in the working tree: a side the commit did not touch is not rewritten under its session.
T="$SBX/two-sessions"; hook_repo "$T"; mkdir -p "$T/adapters/index" "$T/backend" "$T/frontend"
cp "$HERE/../index/emit-index.sh" "$T/adapters/index/"; rm "$T/AGENTS.md"
for s in backend frontend; do printf '# %s\n<!-- INDEX:START -->\n<!-- INDEX:END -->\n' "$s" > "$T/$s/CLAUDE.md"; done
bash "$T/adapters/index/emit-index.sh" --target "$T" >/dev/null 2>&1
bash "$T/adapters/agents/emit-agents.sh" --target "$T" >/dev/null 2>&1
git -C "$T" "${H[@]}" add -A && git -C "$T" "${H[@]}" commit -qm init >/dev/null 2>&1
echo "A's unfinished note" >> "$T/backend/CLAUDE.md"; echo "# draft" > "$T/backend/DRAFT.md"
echo "a spine edit in progress" >> "$T/WORKFLOW.md"
before=$(cd "$T" && md5sum backend/CLAUDE.md backend/AGENTS.md AGENTS.md WORKFLOW.md)
echo "B's change" >> "$T/frontend/CLAUDE.md"; git -C "$T" add frontend/CLAUDE.md
if git -C "$T" "${H[@]}" commit -qm "frontend only" >/dev/null 2>&1; then
  got=$(git -C "$T" show --name-only --format= HEAD | sort | tr '\n' ' ')
  [[ "$got" == "frontend/AGENTS.md frontend/CLAUDE.md " ]] \
    && ok "hook, two sessions: side B's commit holds B's files only" || ko "hook, two sessions: the commit" "$got"
  after=$(cd "$T" && md5sum backend/CLAUDE.md backend/AGENTS.md AGENTS.md WORKFLOW.md)
  [[ "$before" == "$after" ]] \
    && ok "hook, two sessions: side A's files and the root Binding are left byte-identical in the working tree" \
    || ko "hook, two sessions: rewrote a side the commit did not touch" "$(diff <(echo "$before") <(echo "$after") | grep '^>' | awk '{print $3}' | tr '\n' ' ')"
else
  ko "hook blocked side B's commit"
fi

# A rename counts as touching its side: renaming a doc
# in backend/ beside a frontend change refreshes backend's index in the working tree.
echo "# old" > "$T/backend/OLD.md"; git -C "$T" add backend/OLD.md
git -C "$T" "${H[@]}" commit -qm "add OLD" --no-verify >/dev/null 2>&1
git -C "$T" mv backend/OLD.md backend/RENAMED.md
echo "B again" >> "$T/frontend/CLAUDE.md"; git -C "$T" add frontend/CLAUDE.md
if git -C "$T" "${H[@]}" commit -qm "rename in backend" >/dev/null 2>&1; then
  grep -q 'RENAMED.md' "$T/backend/CLAUDE.md" \
    && ok "hook: a staged rename under a side counts as touching it (its index is refreshed)" \
    || ko "hook: a staged rename under backend/ left backend's index stale"
else
  ko "hook blocked a commit with a rename"
fi

echo "== $pass passed, $fail failed"
[ "$fail" -eq 0 ]
