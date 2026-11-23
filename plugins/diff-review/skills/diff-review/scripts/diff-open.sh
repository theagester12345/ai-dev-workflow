#!/usr/bin/env bash
# diff-open.sh — open the diffs of the files one change touched, one at a time, for review.
#
# Several sessions can share one working tree, so `git diff` mixes their work and a reviewer
# cannot tell which files belong to which change. The caller lists THIS change's files and,
# only when the reviewer asks, opens their diffs through this script.
#
# Usage:
#   diff-open.sh [--project <dir>] [--opener difftool|vscode] [--editor-bin <bin>]
#                [--base <rev>] [--all-at-once] <file>...
#
#   --project     the checkout (default: the git top level of the current directory)
#   --opener      difftool (default; portable — `git difftool`, one file at a time, any editor)
#                 or vscode (`<bin> --wait --diff <base> <file>`, also one at a time)
#                 default: $DIFF_OPENER, else difftool
#   --editor-bin  the VS Code-family binary (code, cursor, codium, …)
#                 default: $DIFF_EDITOR_BIN, else code
#   --base <rev>  the left side's revision (default HEAD). A snapshot taken before a review
#                 (`git stash create`) is a revision too: snapshot → now is exactly what the
#                 review changed.
#   --all-at-once vscode only: open every diff as tabs at once, without waiting. An explicit
#                 request — one at a time is the default because all at once floods the editor.
#   <file>        paths relative to the project root
#
# The RIGHT side is always the real working file, never a copy: a comment typed into the diff
# lands in the code, where a later scan for review questions finds it. The left side is a
# read-only copy of the base. A new file diffs against empty; a deleted file is listed, never
# opened. Nothing is staged and nothing is committed. Nothing is derived from where this script
# sits — one copy serves every project.
#
# ONE AT A TIME, AND IT WAITS: each diff opens, the reviewer reads and closes it, then the next
# opens; the script returns when the last one closes and says "collect or approve?", so the
# agent asks instead of the reviewer having to remember the word. A whole review can take longer
# than a host lets a foreground command run, so run it in the background and react when it exits.
set -euo pipefail

die() { echo "diff-open: $*" >&2; exit 2; }

PROJECT=""; OPENER="${DIFF_OPENER:-difftool}"; EDITOR_BIN="${DIFF_EDITOR_BIN:-code}"
BASE="HEAD"; ALL_AT_ONCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)    [[ $# -ge 2 ]] || die "--project needs a directory"; PROJECT="$2"; shift 2 ;;
    --opener)     [[ $# -ge 2 ]] || die "--opener needs difftool or vscode"; OPENER="$2"; shift 2 ;;
    --editor-bin) [[ $# -ge 2 ]] || die "--editor-bin needs a binary"; EDITOR_BIN="$2"; shift 2 ;;
    --base)       [[ $# -ge 2 ]] || die "--base needs a revision"; BASE="$2"; shift 2 ;;
    --all-at-once) ALL_AT_ONCE=1; shift ;;
    -h|--help)    sed -n '2,34p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --)           shift; break ;;
    -*)           die "unknown option: $1" ;;
    *)            break ;;
  esac
done
case "$OPENER" in difftool|vscode) ;; *) die "unknown opener '$OPENER' — use difftool or vscode" ;; esac
[[ $ALL_AT_ONCE -eq 0 || "$OPENER" == vscode ]] || die "--all-at-once applies to the vscode opener only; difftool opens one diff at a time"
[[ $# -gt 0 ]] || die "name the files to open (this task's declared files)"

if [[ -z "$PROJECT" ]]; then
  PROJECT="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git checkout — pass --project"
fi
PROJECT="$(cd "$PROJECT" 2>/dev/null && pwd -P)" || die "project not found: $PROJECT"
git -C "$PROJECT" rev-parse --verify --quiet "$BASE^{commit}" >/dev/null || die "unknown revision: $BASE"

# Validate every path before opening anything.
FILES=()
for f in "$@"; do
  [[ -n "$f" ]] || die "blank path"
  if [[ "$f" == /* ]]; then
    [[ "$f" == "$PROJECT/"* ]] || die "path outside the project: $f"
    f="${f#"$PROJECT"/}"
  fi
  case "/$f/" in */../*|*/./*) die "'.' and '..' path segments are not allowed: $f" ;; esac
  FILES+=("$f")
done

# The base copies are kept after exit on purpose: an editor opened non-blocking reads them later.
# Day-old ones (copies of possibly private docs) are pruned instead.
find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'diff-open.*' -type d -mmin +1440 -exec rm -rf {} + 2>/dev/null || true
TMP="$(mktemp -d "${TMPDIR:-/tmp}/diff-open.XXXXXX")"

opened=0
for f in "${FILES[@]}"; do
  base="$TMP/base/$f"; mkdir -p "$(dirname "$base")"
  in_base=0
  if git -C "$PROJECT" cat-file -e "$BASE:$f" 2>/dev/null; then
    git -C "$PROJECT" show "$BASE:$f" > "$base"; in_base=1
  else
    : > "$base"
  fi
  work="$PROJECT/$f"
  if [[ ! -e "$work" ]]; then
    if [[ $in_base -eq 1 ]]; then echo "deleted: $f"; else echo "missing: $f (not in the base or the working tree)"; fi
    continue
  fi
  if cmp -s "$base" "$work"; then echo "unchanged: $f"; continue; fi
  [[ $in_base -eq 1 ]] && echo "opening: $f" || echo "opening: $f (new — against empty)"
  opened=$((opened + 1))
  if [[ "$OPENER" == vscode && $ALL_AT_ONCE -eq 1 ]]; then
    # Explicitly requested: every diff as a tab at once, without waiting.
    "$EDITOR_BIN" --diff "$base" "$work" || echo "diff-open: '$EDITOR_BIN --diff' failed for $f" >&2
  elif [[ "$OPENER" == vscode ]]; then
    # One at a time: --wait blocks until this diff is closed, then the loop opens the next.
    "$EDITOR_BIN" --wait --diff "$base" "$work" || echo "diff-open: '$EDITOR_BIN --wait --diff' failed for $f" >&2
  else
    # Portable: the user's own configured difftool, one file at a time. Run outside the project
    # (-C "$TMP") so no repo config is consulted; hooks stay off.
    git -C "$TMP" -c core.hooksPath=/dev/null difftool --no-prompt --no-index -- "$base" "$work" || true
  fi
done
echo "$opened diff(s) opened against $BASE"
# The review is over only when every diff has been closed, which is true here unless they were
# opened all at once. Then the next move is the user's: collect their questions, or approve.
if [[ $opened -gt 0 && $ALL_AT_ONCE -eq 0 ]]; then
  echo "All diffs closed — collect or approve?"
fi
