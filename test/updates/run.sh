#!/usr/bin/env bash
#
# Contract tests for bin/apply-updates.sh.
# Dependency-free: bash + temp git fixtures + exit-code / substring asserts.
#
# Does NOT use this repo's own history. Each case builds a mini master (a copy of the
# real script under bin/, a minimal template and a CHANGELOG) and a mini project, then
# runs the script from that mini master so it resolves the mini master as its own.
#
# Usage:
#   bash test/updates/run.sh            # KEEP_TMP=1 keeps the fixtures for a look
#
set -euo pipefail
# `grep -q` stops reading at its first match, so the command writing into it can die of SIGPIPE,
# and under pipefail a match then reads as a failure, at random. quiet_grep reads all of its
# input instead: use it wherever grep sits on the right of a pipe.
quiet_grep() { grep "$@" >/dev/null; }

# ---- the harness must never exit without a verdict ---------------------------
# Under `set -euo pipefail` any unexpected non-zero status kills this script, and because it
# reports only by reaching the summary below, it would then exit silently, which looks like a
# truncated success. The guard names that case; it does not soften any failure.
SUMMARY_REACHED=0
guard_no_verdict() {
  local rc=${1:-$?}
  [ "$SUMMARY_REACHED" = 1 ] && return 0
  {
    echo
    echo "✖ test/updates/run.sh exited before its summary (status $rc) — this is a HARNESS bug, not a test result."
    echo "  Nothing above is a verdict: cases after the stopping point never ran. Usual causes are an"
    echo "  unguarded non-zero status under pipefail, or another session editing the tree mid-run."
  } >&2
  return 0
}
trap guard_no_verdict EXIT

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
APPLY_SRC=${APPLY_SRC:-"$ROOT/bin/apply-updates.sh"}   # override to run the cases against another copy
fail=0
KEEP_TMP=${KEEP_TMP:-0}

pass() { echo "  ✔ $1"; }
fail_case() { echo "  ✖ $1"; fail=1; }

# ---- fixture helpers -------------------------------------------------------

git_init() {
  git -C "$1" init -q
  git -C "$1" -c user.email=test@example.com -c user.name=Test commit --allow-empty -q -m "init empty"
}

git_commit_all() {
  git -C "$1" add -A
  git -C "$1" -c user.email=test@example.com -c user.name=Test commit -q -m "$2"
}

cleanup() {
  if [ "$KEEP_TMP" = 1 ]; then echo "  (KEEP_TMP=1 — left fixtures in place)"; return; fi
  for d in "$@"; do [ -n "$d" ] && [ -d "$d" ] && rm -rf "$d"; done
}

# Mini master: the script + a minimal template + a CHANGELOG of dated sections, as this
# edition writes it. Returns its path.
make_master() {
  local dir
  dir=$(mktemp -d)
  mkdir -p "$dir/bin" "$dir/template/backend"
  cp "$APPLY_SRC" "$dir/bin/apply-updates.sh"; chmod +x "$dir/bin/apply-updates.sh"
  printf '# WORKFLOW — shared operating conventions\n\n## Communication\n\nShort by default.\n' > "$dir/template/WORKFLOW.md"
  printf '# CLAUDE.md - {{PROJECT_NAME}} Backend\n\n## SCOPE\n\nStay in backend/.\n' > "$dir/template/backend/CLAUDE.md"
  cat > "$dir/CHANGELOG.md" << 'EOF'
# Changelog

## [2026-01-01]

### Added
- **A shared spine.** Every side reads `WORKFLOW.md`.
EOF
  git_init "$dir"
  git_commit_all "$dir" "baseline template"
  printf '%s' "$dir"
}

# A new dated section on top, as a release adds one.
add_section() {   # <changelog> <date> <body line>
  local f=$1 tmp
  tmp=$(mktemp)
  { sed -n '1,2p' "$f"; printf '## [%s]\n\n### Changed\n- %s\n\n' "$2" "$3"; sed -n '3,$p' "$f"; } > "$tmp"
  cat "$tmp" > "$f"; rm -f "$tmp"
}

# A master with two commits: BASE (where the projects are stamped) and HEAD (a template change
# and a new changelog section).
make_master_ahead() {
  local m
  m=$(make_master)
  printf '\n## Later\nA later rule.\n' >> "$m/template/WORKFLOW.md"
  add_section "$m/CHANGELOG.md" 2026-01-03 "A later rule."
  git_commit_all "$m" "later rule"
  printf '%s' "$m"
}

# A project is a git repo under a temp root with a .workflow-sync stamp, which is how --status
# and --all find it. The master is elsewhere, so --root is always passed.
make_git_project() {   # <root> <name> <stamp-sha> → path
  local p="$1/$2"
  mkdir -p "$p/backend"
  printf '# WORKFLOW\n' > "$p/WORKFLOW.md"
  printf '# CLAUDE.md - %s Backend\n' "$2" > "$p/backend/CLAUDE.md"
  echo "MASTER_COMMIT=$3" > "$p/.workflow-sync"
  git -C "$p" init -q
  git_commit_all "$p" "project $2"
  printf '%s' "$p"
}
tree_hash() { (cd "$1" && find . -type f -print0 | sort -z | xargs -0 md5sum | md5sum); }

# ---- --status and --all: every project from one place ----------------------

test_apply_status() {
  echo "▶ apply --status: every project under the root, nothing written"
  local master root base head out rc before_root before_master
  master=$(make_master_ahead); root=$(mktemp -d)
  head=$(git -C "$master" rev-parse HEAD); base=$(git -C "$master" rev-parse HEAD~1)
  make_git_project "$root" behind "$base" >/dev/null
  make_git_project "$root" synced "$head" >/dev/null
  echo "OLD" > "$(make_git_project "$root" pending "$base")/UPGRADE_WORKORDER.md"
  make_git_project "$root" foreign 0123456789abcdef0123456789abcdef01234567 >/dev/null
  before_root=$(tree_hash "$root"); before_master=$(tree_hash "$master")
  set +e; out=$(bash "$master/bin/apply-updates.sh" --status --root "$root" 2>&1); rc=$?; set -e
  [ "$rc" -eq 0 ] && pass "exit 0" || fail_case "exit $rc: $out"
  printf '%s\n' "$out" | grep -E '^ *behind ' | quiet_grep '1 template commit' && printf '%s\n' "$out" | grep -E '^ *behind ' | quiet_grep '1 changelog section' \
    && pass "a behind project shows template commits and changelog sections behind" || fail_case "behind line missing its counts: $out"
  printf '%s\n' "$out" | grep -E '^ *synced ' | quiet_grep 'up to date' && pass "a synced project shows up to date" || fail_case "synced line wrong: $out"
  printf '%s\n' "$out" | grep -E '^ *pending ' | quiet_grep 'workorder pending (untouched)' && pass "a pending workorder shows its state" || fail_case "pending line wrong: $out"
  printf '%s\n' "$out" | grep -E '^ *foreign ' | quiet_grep 'stamped from another workflow repo' \
    && pass "a stamp this repo's history lacks is named as from another workflow repo, as --all counts it" || fail_case "foreign line wrong: $out"
  [ "$(tree_hash "$root")" = "$before_root" ] && pass "no project file changed" || fail_case "--status wrote into a project"
  [ "$(tree_hash "$master")" = "$before_master" ] && pass "the master is unchanged" || fail_case "--status wrote into the master"
  cleanup "$root" "$master"
}

test_apply_all() {
  echo "▶ apply --all: writes, skips synced, refreshes untouched, never overwrites in progress"
  local master root base head p1 p2 p3 p4 out rc
  master=$(make_master_ahead); root=$(mktemp -d)
  head=$(git -C "$master" rev-parse HEAD); base=$(git -C "$master" rev-parse HEAD~1)
  p1=$(make_git_project "$root" behind "$base")
  p2=$(make_git_project "$root" synced "$head")
  p3=$(make_git_project "$root" untouched "$base"); echo "OLD" > "$p3/UPGRADE_WORKORDER.md"
  p4=$(make_git_project "$root" midway "$base"); echo "OLD" > "$p4/UPGRADE_WORKORDER.md"; echo "applied" >> "$p4/WORKFLOW.md"
  set +e; out=$(bash "$master/bin/apply-updates.sh" --all --root "$root" 2>&1); rc=$?; set -e
  [ "$rc" -eq 0 ] && pass "exit 0" || fail_case "exit $rc: $out"
  grep -q "$head" "$p1/UPGRADE_WORKORDER.md" 2>/dev/null && pass "a behind project gets a workorder" || fail_case "no workorder in the behind project"
  [ ! -e "$p2/UPGRADE_WORKORDER.md" ] && pass "a synced project gets none" || fail_case "a synced project got a workorder"
  grep -q "$head" "$p3/UPGRADE_WORKORDER.md" && pass "an untouched pending workorder is replaced by the cumulative one" || fail_case "the untouched workorder was not replaced"
  [ "$(cat "$p4/UPGRADE_WORKORDER.md")" = "OLD" ] && pass "an in-progress workorder is left exactly as it was" || fail_case "an in-progress workorder was overwritten"
  printf '%s\n' "$out" | grep 'midway' | quiet_grep 'upgrade in progress' && pass "and reported as upgrade in progress" || fail_case "midway not reported in progress: $out"
  set +e; bash "$master/bin/apply-updates.sh" --all --force --root "$root" >/dev/null 2>&1; set -e
  grep -q "$head" "$p4/UPGRADE_WORKORDER.md" && pass "--force replaces it" || fail_case "--force did not replace the in-progress workorder"
  cleanup "$root" "$master"
}

test_apply_single_guard() {
  echo "▶ apply <project>: the same guard on a single run, and the project-root header"
  local master root base p out rc
  master=$(make_master_ahead); root=$(mktemp -d)
  base=$(git -C "$master" rev-parse HEAD~1)
  p=$(make_git_project "$root" midway "$base"); echo "OLD" > "$p/UPGRADE_WORKORDER.md"
  git_commit_all "$p" "applied half the workorder"   # committed after the workorder was written
  touch -d '1 minute ago' "$p/UPGRADE_WORKORDER.md"
  set +e; out=$(bash "$master/bin/apply-updates.sh" "$p" 2>&1); rc=$?; set -e
  [ "$rc" -ne 0 ] && [ "$(cat "$p/UPGRADE_WORKORDER.md")" = "OLD" ] \
    && pass "a commit since the workorder was written refuses a single run, workorder kept" || fail_case "single run on an in-progress project: rc=$rc, $(head -c 40 "$p/UPGRADE_WORKORDER.md")"
  printf '%s' "$out" | quiet_grep 'upgrade in progress' && pass "and says upgrade in progress" || fail_case "no 'upgrade in progress' message: $out"
  set +e; bash "$master/bin/apply-updates.sh" --force "$p" >/dev/null 2>&1; set -e
  head -12 "$p/UPGRADE_WORKORDER.md" | quiet_grep -i 'project root' && pass "an incremental workorder opens by saying it runs from the project root" || fail_case "workorder lacks the project-root header"
  cleanup "$root" "$master"
}

# Each project runs in a subshell whose `set -e` must hold: bash switches it off inside anything
# on the left of `||`, and a failing step would then carry on with an empty project path.
test_apply_bad_path() {
  echo "▶ apply <project>: a path that does not exist fails, and claims nothing"
  local master out rc
  master=$(make_master)
  set +e; out=$(bash "$master/bin/apply-updates.sh" "$master/../no-such-project-$$" 2>&1); rc=$?; set -e
  if [ "$rc" -ne 0 ] && ! printf '%s' "$out" | quiet_grep '✔ wrote' && printf '%s' "$out" | quiet_grep 'not a readable directory'; then
    pass "non-zero, says why, and no 'wrote' claim"
  else fail_case "rc=$rc: $out"; fi
  cleanup "$master"
}

# ---- the intent: changelog sections, each found by its own heading ----------
intent_of() { sed -n '/^## Changes to apply/,/^## Ground-truth/p' "$1/UPGRADE_WORKORDER.md"; }

section_case() {   # <label> <edit-fn> <expected dates listed, space-separated, or none>
  local label=$1 edit=$2 expect=$3 master project out rc listed
  echo "▶ apply: $label"
  master=$(make_master)
  add_section "$master/CHANGELOG.md" 2026-01-02 "Second release."
  git_commit_all "$master" "second release"
  project=$(mktemp -d)
  printf '# WORKFLOW\n' > "$project/WORKFLOW.md"
  echo "MASTER_COMMIT=$(git -C "$master" rev-parse HEAD)" > "$project/.workflow-sync"
  printf '\n## Later\nA later rule.\n' >> "$master/template/WORKFLOW.md"   # so a workorder is written at all
  "$edit" "$master/CHANGELOG.md"
  git_commit_all "$master" "$label"
  set +e; out=$(bash "$master/bin/apply-updates.sh" "$project" 2>&1); rc=$?; set -e
  if [ "$rc" -ne 0 ] || [ ! -f "$project/UPGRADE_WORKORDER.md" ]; then
    fail_case "expected a workorder (rc=$rc): $out"
  else
    listed=$(intent_of "$project" | grep -oE '^## \[[0-9-]+\]' | sed -E 's/^## \[//; s/\]$//' | tr '\n' ' ' || true)
    if [ "$expect" = none ] && [ -z "$listed" ]; then pass "no section listed"
    elif [ "$listed" = "$expect " ]; then pass "listed exactly: $expect"
    else fail_case "listed: '${listed}' (expected: $expect)"
    fi
  fi
  cleanup "$master" "$project"
}
# A new release on top, and the two existing sections swapped: same text, new order.
add_and_move() {
  local f=$1
  cat > "$f" << 'EOF'
# Changelog

## [2026-01-03]

### Changed
- A third release.

## [2026-01-01]

### Added
- **A shared spine.** Every side reads `WORKFLOW.md`.

## [2026-01-02]

### Changed
- Second release.
EOF
}
# A new release whose own sub-heading and body cite an older release's date.
add_citing() {
  add_section "$1" 2026-01-03 "Extends the rule from [2026-01-01]."
  sed -i '0,/^### Changed$/s//### Changed (follows ## [2026-01-01])/' "$1"
}
amend_old() { sed -i 's/^- Second release\.$/- Second release, corrected./' "$1"; }
test_apply_section_added_moved()  { section_case "a new section is listed; one that only moved is not" add_and_move 2026-01-03; }
test_apply_section_cited_once()   { section_case "a section that cites another's date does not copy that one in" add_citing 2026-01-03; }
test_apply_section_amended()      { section_case "a section amended since the stamp is listed" amend_old 2026-01-02; }

# ---- the mechanical part: adapters and hooks the script applies itself ------
# A master whose template changes between BASE and HEAD: an adapter script and its README, a hook,
# an adapter the project edited, a new and a deleted adapter file, the spine (one hunk the project
# never touched, one it did), and a persona doc. The project is the template at BASE, as scaffold
# leaves it: STARTER banners stripped, persona doc filled.
make_mech_master() {
  local m; m=$(make_master)
  mkdir -p "$m/template/adapters/tool" "$m/template/adapters/edited" "$m/template/adapters/gone" "$m/template/.githooks"
  printf '#!/bin/sh\necho v1\n' > "$m/template/adapters/tool/run.sh"; chmod +x "$m/template/adapters/tool/run.sh"
  printf '# tool\n\n> ⚠️ STARTER — unbootstrapped.\n\nreadme v1\n' > "$m/template/adapters/tool/README.md"
  printf '#!/bin/sh\necho edited v1\n' > "$m/template/adapters/edited/x.sh"
  printf '#!/bin/sh\necho old\n' > "$m/template/adapters/gone/old.sh"
  printf '#!/bin/sh\necho hook v1\n' > "$m/template/.githooks/pre-commit"; chmod +x "$m/template/.githooks/pre-commit"
  printf '# WORKFLOW\n\n## Alpha\n\nalpha v1\n\n## Beta\n\nbeta v1\n\n## Gamma\n\ngamma v1\n' > "$m/template/WORKFLOW.md"
  git_commit_all "$m" "BASE: mechanical fixture"
  printf '%s' "$m"
}
advance_mech_master() {   # <master> → HEAD
  local m=$1
  printf '#!/bin/sh\necho v2\n' > "$m/template/adapters/tool/run.sh"
  printf '# tool\n\n> ⚠️ STARTER — unbootstrapped.\n\nreadme v2\n' > "$m/template/adapters/tool/README.md"
  printf '#!/bin/sh\necho edited v2\n' > "$m/template/adapters/edited/x.sh"
  printf '#!/bin/sh\necho new\n' > "$m/template/adapters/tool/new.sh"; chmod +x "$m/template/adapters/tool/new.sh"
  git -C "$m" rm -q template/adapters/gone/old.sh
  printf '#!/bin/sh\necho hook v2\n' > "$m/template/.githooks/pre-commit"
  printf '# WORKFLOW\n\n## Alpha\n\nalpha v2\n\n## Beta\n\nbeta v2 from the master\n\n## Gamma\n\ngamma v1\n' > "$m/template/WORKFLOW.md"
  printf '\n## Later\nA later rule.\n' >> "$m/template/backend/CLAUDE.md"
  add_section "$m/CHANGELOG.md" 2026-01-03 "Mechanical changes."
  git_commit_all "$m" "HEAD: mechanical changes"
}
make_mech_project() {   # <root> <name> <master> <stamp> → path (a git repo, committed)
  local p="$1/$2" m=$3
  mkdir -p "$p"
  git -C "$m" archive "$4" template | tar -x -C "$p" --strip-components=1
  sed -i '/^> ⚠️ STARTER/d' "$p/adapters/tool/README.md"
  printf '#!/bin/sh\necho edited LOCALLY\n' > "$p/adapters/edited/x.sh"
  sed -i 's/^beta v1$/beta v1, edited in this project/' "$p/WORKFLOW.md"
  printf '# CLAUDE.md - Acme Backend\n\nFilled for this project.\n' > "$p/backend/CLAUDE.md"
  echo "MASTER_COMMIT=$4" > "$p/.workflow-sync"
  git -C "$p" init -q; git_commit_all "$p" "project at BASE"
  printf '%s' "$p"
}

test_apply_mechanical() {
  echo "▶ apply: the script applies adapters and hooks, and prepares the spine"
  local master root base p wo out rc wf_before cl_before diffpart left
  master=$(make_mech_master); base=$(git -C "$master" rev-parse HEAD); root=$(mktemp -d)
  p=$(make_mech_project "$root" acme "$master" "$base")
  advance_mech_master "$master"
  wf_before=$(md5sum < "$p/WORKFLOW.md"); cl_before=$(md5sum < "$p/backend/CLAUDE.md")
  set +e; out=$(bash "$master/bin/apply-updates.sh" "$p" 2>&1); rc=$?; set -e
  wo="$p/UPGRADE_WORKORDER.md"
  [ "$rc" -eq 0 ] && [ -f "$wo" ] || { fail_case "no workorder (rc=$rc): $out"; cleanup "$root" "$master"; return; }
  grep -q 'echo v2' "$p/adapters/tool/run.sh" && [ -x "$p/adapters/tool/run.sh" ] \
    && pass "an unchanged script is replaced, executable bit kept" || fail_case "run.sh not replaced, or lost its executable bit"
  grep -q 'readme v2' "$p/adapters/tool/README.md" && ! grep -q 'STARTER' "$p/adapters/tool/README.md" \
    && pass "a README differing only by the stripped banner is replaced, banner still absent" || fail_case "README: $(cat "$p/adapters/tool/README.md")"
  grep -q 'hook v2' "$p/.githooks/pre-commit" && [ -x "$p/.githooks/pre-commit" ] \
    && pass "the hook is replaced the same way" || fail_case "hook not replaced cleanly"
  left=$(sed -n '/^## Left for you/,/^## [^L]/p' "$wo")
  grep -q 'LOCALLY' "$p/adapters/edited/x.sh" && printf '%s' "$left" | quiet_grep 'adapters/edited/x.sh' \
    && pass "a locally edited adapter is untouched and listed" || fail_case "the locally edited adapter was overwritten or not listed"
  [ -f "$p/adapters/tool/new.sh" ] && [ -x "$p/adapters/tool/new.sh" ] \
    && pass "a new template file is copied, executable bit included" || fail_case "new.sh not copied"
  [ -f "$p/adapters/gone/old.sh" ] && printf '%s' "$left" | quiet_grep 'adapters/gone/old.sh' \
    && pass "a file the template deleted is listed, not deleted" || fail_case "the deleted template file was removed or not listed"
  [ "$(md5sum < "$p/WORKFLOW.md")" = "$wf_before" ] && grep -q '^alpha v2$' "$p/WORKFLOW.md.upgrade" \
    && [ "$(grep -c '^<<<<<<<' "$p/WORKFLOW.md.upgrade")" = 1 ] && grep -qi '1 conflict' "$wo" \
    && pass "the spine merge is in WORKFLOW.md.upgrade with its one conflict counted; WORKFLOW.md unchanged" \
    || fail_case "spine: upgrade=$(grep -c '^<<<<<<<' "$p/WORKFLOW.md.upgrade" 2>/dev/null || true) conflicts; workorder says: $(grep -i conflict "$wo" | head -2 || true)"
  [ "$(md5sum < "$p/backend/CLAUDE.md")" = "$cl_before" ] && pass "persona docs are untouched" || fail_case "backend/CLAUDE.md was edited"
  [ "$(git -C "$p" rev-list --count HEAD)" = 1 ] \
    && pass "nothing is committed" || fail_case "the script committed in the project"
  diffpart=$(sed -n '/^## Ground-truth/,$p' "$wo")
  if printf '%s' "$diffpart" | quiet_grep -E 'template/(adapters/tool/run\.sh|adapters/tool/README\.md|\.githooks/pre-commit|WORKFLOW\.md)'; then
    fail_case "the embedded diff still carries a handled file"
  elif printf '%s' "$diffpart" | quiet_grep 'template/backend/CLAUDE.md' && printf '%s' "$diffpart" | quiet_grep 'template/adapters/edited/x.sh'; then
    pass "the embedded diff omits every handled file and keeps the rest"
  else fail_case "the embedded diff lost an unhandled file"; fi
  set +e; out=$(bash "$master/bin/apply-updates.sh" "$p" 2>&1); rc=$?; set -e
  [ "$rc" -eq 0 ] && printf '%s' "$out" | quiet_grep 'replaced an untouched workorder' && grep -q 'LOCALLY' "$p/adapters/edited/x.sh" \
    && pass "a second run with only the script's changes replaces the workorder, the edited adapter still untouched" || fail_case "second run: rc=$rc $out"
  printf '\nAn upgrade edit.\n' >> "$p/backend/CLAUDE.md"
  set +e; out=$(bash "$master/bin/apply-updates.sh" "$p" 2>&1); rc=$?; set -e
  [ "$rc" -ne 0 ] && printf '%s' "$out" | quiet_grep 'upgrade in progress' \
    && pass "once the project has an edit of its own, a run is refused as an upgrade in progress" || fail_case "third run: rc=$rc $out"
  cleanup "$root" "$master"
}

# A --force re-run must recognise its own earlier output — a copy equal to the template at the
# commit the old workorder names, or at HEAD — and never list it as the project's edit; a file the
# project really edited is still listed.
test_apply_mechanical_rerun() {
  echo "▶ apply: a --force re-run does not take its own earlier mechanical apply for the project's edits"
  local master root base p wo left
  master=$(make_mech_master); base=$(git -C "$master" rev-parse HEAD); root=$(mktemp -d)
  p=$(make_mech_project "$root" again "$master" "$base")
  advance_mech_master "$master"
  set +e; bash "$master/bin/apply-updates.sh" "$p" >/dev/null 2>&1; set -e
  printf '#!/bin/sh\necho v3\n' > "$master/template/adapters/tool/run.sh"
  git_commit_all "$master" "HEAD: run.sh changes a second time"
  set +e; bash "$master/bin/apply-updates.sh" --force "$p" >/dev/null 2>&1; set -e
  wo="$p/UPGRADE_WORKORDER.md"
  [ -f "$wo" ] || { fail_case "no workorder after the re-run"; cleanup "$root" "$master"; return; }
  left=$(sed -n '/^## Left for you/,/^## [^L]/p' "$wo")
  if printf '%s' "$left" | quiet_grep -E 'adapters/tool/(run\.sh|new\.sh|README\.md)|\.githooks/pre-commit'; then
    fail_case "the re-run lists its own earlier output as the project's: $(printf '%s' "$left" | grep -E 'tool/|githooks' | head -4 | tr '\n' ' ')"
  else pass "nothing the first run wrote is listed for a hand-merge or a compare"; fi
  grep -q 'echo v3' "$p/adapters/tool/run.sh" && [ -x "$p/adapters/tool/run.sh" ] \
    && pass "a file the master changed again since the first run is brought to HEAD" || fail_case "run.sh: $(cat "$p/adapters/tool/run.sh")"
  grep -q 'LOCALLY' "$p/adapters/edited/x.sh" && printf '%s' "$left" | quiet_grep 'adapters/edited/x.sh' \
    && pass "a file the project edited is still untouched and listed" || fail_case "the edited adapter was overwritten or not listed"
  cleanup "$root" "$master"
}

# A project whose only changes are the script's own (the workorder, WORKFLOW.md.upgrade, the
# adapters and hooks it wrote) is untouched, so --all refreshes it; any other change, or an
# adapter edited afterwards, still holds it.
test_apply_all_refreshes_own_changes() {
  echo "▶ apply --all: a workorder holding only the script's own changes is refreshed without --force"
  local master root base p p1 p2 p3 head
  master=$(make_mech_master); base=$(git -C "$master" rev-parse HEAD); root=$(mktemp -d)
  p1=$(make_mech_project "$root" ownonly "$master" "$base")
  p2=$(make_mech_project "$root" persona "$master" "$base")
  p3=$(make_mech_project "$root" adapter "$master" "$base")
  advance_mech_master "$master"
  set +e; for p in "$p1" "$p2" "$p3"; do bash "$master/bin/apply-updates.sh" "$p" >/dev/null 2>&1; done; set -e
  printf '\nAn upgrade edit.\n' >> "$p2/backend/CLAUDE.md"
  printf '#!/bin/sh\necho changed after the first run\n' > "$p3/adapters/tool/run.sh"
  printf '#!/bin/sh\necho v3\n' > "$master/template/adapters/tool/run.sh"
  git_commit_all "$master" "HEAD: the master moves on"; head=$(git -C "$master" rev-parse HEAD)
  set +e; bash "$master/bin/apply-updates.sh" --all --root "$root" >/dev/null 2>&1; set -e
  grep -q "$head" "$p1/UPGRADE_WORKORDER.md" 2>/dev/null && grep -q 'echo v3' "$p1/adapters/tool/run.sh" \
    && pass "only the script's own changes: refreshed to HEAD without --force" || fail_case "the own-changes-only workorder was not refreshed"
  [ -f "$p2/UPGRADE_WORKORDER.md" ] && ! grep -q "$head" "$p2/UPGRADE_WORKORDER.md" \
    && pass "a persona-doc edit keeps it in progress" || fail_case "a project with a persona-doc edit was refreshed (or never got a workorder)"
  [ -f "$p3/UPGRADE_WORKORDER.md" ] && ! grep -q "$head" "$p3/UPGRADE_WORKORDER.md" && grep -q 'changed after the first run' "$p3/adapters/tool/run.sh" \
    && pass "an adapter edited after the first run keeps it in progress, untouched" || fail_case "a project with an adapter edited after the first run was refreshed or overwritten"
  cleanup "$root" "$master"
}

# WORKFLOW.md.upgrade is the script's own only while it is byte-identical to what the script
# wrote. A user who resolved its conflicts has started the upgrade: a re-run must hold the
# workorder, and even --force must never rewrite the resolution or, on a merge error, delete it.
test_apply_resolved_spine_upgrade() {
  echo "▶ apply: a resolved WORKFLOW.md.upgrade is never overwritten or deleted"
  local master root base p up out rc
  master=$(make_mech_master); base=$(git -C "$master" rev-parse HEAD); root=$(mktemp -d)
  p=$(make_mech_project "$root" resolved "$master" "$base")
  advance_mech_master "$master"
  set +e; bash "$master/bin/apply-updates.sh" "$p" >/dev/null 2>&1; set -e
  up="$p/WORKFLOW.md.upgrade"
  [ -f "$up" ] && quiet_grep '^<<<<<<<' "$up" || { fail_case "harness: the first run wrote no conflicted WORKFLOW.md.upgrade"; cleanup "$root" "$master"; return; }
  printf '# WORKFLOW\n\nRESOLVED by the user\n' > "$up"
  printf '#!/bin/sh\necho v3\n' > "$master/template/adapters/tool/run.sh"
  git_commit_all "$master" "HEAD: the master moves on"
  set +e; out=$(bash "$master/bin/apply-updates.sh" "$p" 2>&1); rc=$?; set -e
  [ "$rc" -ne 0 ] && printf '%s' "$out" | quiet_grep 'upgrade in progress' \
    && pass "a resolved WORKFLOW.md.upgrade holds the workorder without --force" || fail_case "resolved .upgrade: rc=$rc $out"
  grep -q 'RESOLVED by the user' "$up" && pass "and the resolution is still there" || fail_case "the resolution was overwritten: $(head -3 "$up" 2>/dev/null)"
  set +e; out=$(bash "$master/bin/apply-updates.sh" --force "$p" 2>&1); rc=$?; set -e
  grep -q 'RESOLVED by the user' "$up" && sed -n '/^## Left for you/,/^## [^L]/p' "$p/UPGRADE_WORKORDER.md" | quiet_grep 'WORKFLOW.md.upgrade' \
    && pass "--force replaces the workorder but never rewrites the resolution; it is listed" || fail_case "--force over a resolution: rc=$rc $(head -3 "$up" 2>/dev/null)"
  chmod 000 "$p/WORKFLOW.md"
  set +e; out=$(bash "$master/bin/apply-updates.sh" --force "$p" 2>&1); rc=$?; set -e
  chmod 644 "$p/WORKFLOW.md"
  grep -q 'RESOLVED by the user' "$up" && pass "a merge that cannot run never deletes the user's WORKFLOW.md.upgrade" || fail_case "merge error: the .upgrade is gone or changed (rc=$rc)"
  cleanup "$root" "$master"
}

# The payload's own tests stay in the workflow repo: scaffold copies no *.test.sh, and an upgrade
# must not deliver one either (one rule for both).
test_apply_skips_payload_tests() {
  echo "▶ apply: a new *.test.sh under the template is not copied into the project"
  local master root base p wo
  master=$(make_mech_master); base=$(git -C "$master" rev-parse HEAD); root=$(mktemp -d)
  p=$(make_mech_project "$root" tests "$master" "$base")
  advance_mech_master "$master"
  printf '#!/usr/bin/env bash\necho test\n' > "$master/template/adapters/tool/tool.test.sh"
  git_commit_all "$master" "HEAD: a payload test"
  set +e; bash "$master/bin/apply-updates.sh" "$p" >/dev/null 2>&1; set -e
  wo="$p/UPGRADE_WORKORDER.md"
  [ -f "$wo" ] && [ -f "$p/adapters/tool/new.sh" ] || { fail_case "harness: no workorder, or the new adapter was not copied"; cleanup "$root" "$master"; return; }
  [ ! -e "$p/adapters/tool/tool.test.sh" ] && pass "the payload's test is not copied" || fail_case "adapters/tool/tool.test.sh was copied into the project"
  quiet_grep 'tool.test.sh' "$wo" && fail_case "the workorder still asks for the payload's test: $(grep 'tool.test.sh' "$wo" | head -2)" \
    || pass "and the workorder does not list it"
  cleanup "$root" "$master"
}

# A new file that still has a placeholder keeps its STARTER banner (scaffold's rule), even when it
# is larger than a pipe buffer. Read as `git show | grep -q '{{'`, grep quits at the early match,
# git show is cut off, and under pipefail the match reads as a miss.
test_apply_new_large_placeholder() {
  echo "▶ apply: a new file with a placeholder keeps its banner, however large"
  local master root base p f
  master=$(make_mech_master); base=$(git -C "$master" rev-parse HEAD); root=$(mktemp -d)
  p=$(make_mech_project "$root" big "$master" "$base")
  advance_mech_master "$master"
  mkdir -p "$master/template/adapters/big"
  { printf '# big\n\n> ⚠️ STARTER — unbootstrapped.\n\nFor {{PROJECT_NAME}}.\n'
    seq 1 300000 | sed 's/^/filler line /'; } > "$master/template/adapters/big/README.md"
  git_commit_all "$master" "HEAD: a large new adapter doc with a placeholder"
  set +e; bash "$master/bin/apply-updates.sh" "$p" >/dev/null 2>&1; set -e
  f="$p/adapters/big/README.md"
  [ -f "$f" ] && grep -q '{{PROJECT_NAME}}' "$f" && grep -q '^> ⚠️ STARTER' "$f" \
    && pass "a large new file with a placeholder is copied with its STARTER banner" \
    || fail_case "the large new file lost its banner (or was not copied): $(head -c 200 "$f" 2>/dev/null | tr '\n' ' ')"
  cleanup "$root" "$master"
}

test_apply_status
test_apply_all
test_apply_single_guard
test_apply_bad_path
test_apply_section_added_moved
test_apply_section_cited_once
test_apply_section_amended
test_apply_mechanical
test_apply_mechanical_rerun
test_apply_all_refreshes_own_changes
test_apply_resolved_spine_upgrade
test_apply_skips_payload_tests
test_apply_new_large_placeholder

SUMMARY_REACHED=1
if [ "$fail" -ne 0 ]; then
  echo
  echo "✖ test/updates/run.sh FAILED"
  exit 1
fi
echo
echo "✔ test/updates/run.sh passed"
exit 0
