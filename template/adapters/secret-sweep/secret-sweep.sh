#!/usr/bin/env bash
# secret-sweep.sh — find credentials a project already holds, without ever printing one.
#
# The workflow's secret rules and the pre-commit guard stop NEW leaks. Nothing looked at what a
# project held before it adopted the workflow: a password in a migration comment, a token in an
# old commit, a value pasted into a shell history. This sweep is adoption's first card
# (ADOPT.md); run it again when a leak is suspected. Canonical rule: WORKFLOW.md → Secrets.
#
# Usage, from the project root:
#   bash adapters/secret-sweep/secret-sweep.sh [--tree] [--history] [--path FILE_OR_DIR]... [--patterns DIR]
#     --tree      tracked and untracked files (ignored ones and real env files excluded)
#     --history   every added line on every branch, and any real env file ever committed (by name)
#     --path P    a file or folder the user names: shell or database-client history, an agent's
#                 logs. Locations and rules only, never the line. Repeatable. Never guessed.
#     --patterns  where patterns.txt, patterns-words.txt and env-files.txt are (default: adapters/secret-sweep)
#   No scope given → --tree --history.
#
# Output, one find per line, every value masked to its first two characters and its length:
#   tree  <path>:<line>  <rule>  <ab…(len N)>
#   history  <commit>  <path>  <rule>  <ab…(len N)>
#   history  <commit>  <path>  env file committed (its values are not read)
#   path  <file>:<line>  <rule>
# Never the line itself: a line holds values no rule matched (a password in a URL beside a token),
# and masking only what matched printed those. The owner opens the location to judge a find.
# Exit: 0 nothing found · 1 finds · 2 usage error, a patterns file it cannot trust, or a file it could not read.
set -euo pipefail

die() { echo "secret-sweep: $*" >&2; exit 2; }
PATDIR="adapters/secret-sweep"; TREE=0; HIST=0; PATHS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --tree) TREE=1; shift ;;
    --history) HIST=1; shift ;;
    --path) [ $# -ge 2 ] || die "--path needs a file or folder"; PATHS+=("$2"); shift 2 ;;
    --patterns) [ $# -ge 2 ] || die "--patterns needs a folder"; PATDIR=$2; shift 2 ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done
[ "$TREE$HIST" = 00 ] && [ ${#PATHS[@]} -eq 0 ] && { TREE=1; HIST=1; }
for f in patterns.txt patterns-words.txt patterns.sh env-files.txt env-files.sh; do [ -f "$PATDIR/$f" ] || die "missing $PATDIR/$f"; done
for p in ${PATHS[@]+"${PATHS[@]}"}; do [ -e "$p" ] || die "not found: $p (name the path the tool really writes; never a guess)"; done
if [ "$TREE$HIST" != 00 ]; then git rev-parse --git-dir >/dev/null 2>&1 || die "run it from the project's git checkout"; fi

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
# Rules as "<kind><TAB><name><TAB><regex>": kind k = key-shaped, w = words (matched ignoring case).
# Read and checked by the one reader the hook uses too (patterns.sh): an unusable file is
# refused, never read as one that finds nothing.
. "$PATDIR/patterns.sh"
patterns_load "$PATDIR/patterns.txt" "$WORK/k" \
  || die "$PATDIR/patterns.txt is missing, empty or unusable: a rule grep -E rejects, or a set that no longer matches a known key"
patterns_load "$PATDIR/patterns-words.txt" "$WORK/w" -i \
  || die "$PATDIR/patterns-words.txt is missing, empty or unusable: a rule grep -E rejects, or a set that no longer matches a password written in words"
sed 's/^/k\t/' "$WORK/k" > "$WORK/rules"; sed 's/^/w\t/' "$WORK/w" >> "$WORK/rules"

# A real env file: the one definition the hook reads too (env-files.txt).
# Read and checked by the one reader the hook uses too (env-files.sh): a malformed rule is refused,
# never trusted as a rule that matches nothing.
. "$PATDIR/env-files.sh"
env_files_load "$PATDIR/env-files.txt" \
  || die "$PATDIR/env-files.txt is malformed: it needs an env-file rule matching every real env file, and a template-suffix rule matching .env.example and no real env file"
is_env() { printf '%s\n' "$1" | grep -E "$ENV_RE" | grep -qvE "$TPL_RE"; }
# Two characters and the length; none at all for a value of 4 or fewer, where two would be half of it.
mask() { if [ "${#1}" -le 4 ]; then printf '…(len %d)' "${#1}"; else printf '%s…(len %d)' "${1:0:2}" "${#1}"; fi; }
# The value inside a match: all of it for a key-shaped rule; for one in words, what follows the
# FIRST separator after the key word, so a value holding a separator (password=ab:cd…) is masked
# whole, never cut at its last one. A words value shorter than 6 is prose ("secret: 3").
value_of() {
  if [ "$1" = k ]; then printf '%s' "$2"; return; fi
  printf '%s' "$2" | sed -E 's/^[A-Za-z_ -]*["'"'"']?[[:space:]]*(=|:|[[:space:]][Ii][Ss]|[[:space:]][Ww][Aa][Ss])[[:space:]]*["'"'"']?//'
}
FOUND=0
# Every find in one text line. $1 = where (printed as is), $2 = the line, $3 = path: location only.
finds_in() {
  local where=$1 text=$2 ctx=$3 kind name re m v
  while IFS=$'\t' read -r kind name re; do
    while IFS= read -r m; do
      [ -n "$m" ] || continue
      v=$(value_of "$kind" "$m")
      [ "$kind" = w ] && [ ${#v} -lt 6 ] && continue
      FOUND=$((FOUND + 1))
      if [ "$ctx" = path ]; then printf '%s  %s\n' "$where" "$name"
      else printf '%s  %s  %s\n' "$where" "$name" "$(mask "$v")"; fi
    done < <(if [ "$kind" = w ]; then printf '%s\n' "$text" | grep -oiE -- "$re" || true
             else printf '%s\n' "$text" | grep -oE -- "$re" || true; fi)
  done < "$WORK/rules"
}
# Only lines some rule matches are looked at one by one; a cheap pre-filter over a whole file.
# A file grep cannot read (exit 2) is never a silent skip: its error, which names the path and never
# a line, is kept and reported at the end, and the run exits 2 — a false all-clear otherwise.
# A binary file is read as text (-a): a key in a lock file or a log holding a NUL is still a key. NULs
# are dropped from the matched lines (pipefail keeps grep's status).
grep_any() {
  local rc
  rc=0; grep -naH -E -f <(awk -F'\t' '$1 == "k" { print $3 }' "$WORK/rules") "$@" 2>"$WORK/err.k" | tr -d '\000' || rc=$?
  [ "$rc" -le 1 ] || cat "$WORK/err.k" >> "$WORK/unread"
  rc=0; grep -naHi -E -f <(awk -F'\t' '$1 == "w" { print $3 }' "$WORK/rules") "$@" 2>"$WORK/err.w" | tr -d '\000' || rc=$?
  [ "$rc" -le 1 ] || cat "$WORK/err.w" >> "$WORK/unread"
  return 0
}

if [ "$TREE" = 1 ]; then
  git ls-files -z --cached --others --exclude-standard > "$WORK/files"
  while IFS= read -r -d '' f; do
    [ -f "$f" ] || continue
    is_env "$f" && continue
    grep_any -- "$f"
  done < "$WORK/files" | sort -t: -k1,1 -k2,2n -u > "$WORK/hits"
  while IFS= read -r hit; do
    f=${hit%%:*}; rest=${hit#*:}; n=${rest%%:*}; text=${rest#*:}
    finds_in "tree  $f:$n" "$text" 1
  done < "$WORK/hits"
fi

if [ "$HIST" = 1 ]; then
  # Every added line on every branch as "<commit><TAB><path><TAB><text>"; env files by name only.
  # Read as git writes it for scripts: no external diff tool or textconv driver, which
  # replace the lines read here, and paths unquoted. core.quotePath=false leaves a non-ASCII name
  # as written; a name holding '"' or '\' is still quoted, so unq() undoes that quoting.
  # A "+++ b/<path>" header sits between "diff --git" and the first "@@": it is told apart by that
  # position, never by prefix, since an added line starting with "++" reads "+++" too (the hook's rule).
  UNQ='function unq(s,   o, i, ch, nx) {
    if (s !~ /^".*"$/) return s
    s = substr(s, 2, length(s) - 2); o = ""
    for (i = 1; i <= length(s); i++) {
      ch = substr(s, i, 1); nx = substr(s, i + 1, 1)
      if (ch == "\\" && (nx == "\"" || nx == "\\")) { o = o nx; i++ } else o = o ch
    }
    return o
  }'
  # The user's settings that change what git prints are overridden too: --text for a -diff (binary)
  # attribute, --root for log.showRoot=false (the first commit would show nothing), and fixed a/ b/
  # prefixes for diff.noprefix / diff.dstPrefix. Git ends a "+++" header with a tab when the path
  # holds a space; it is stripped before the path is read. NULs from a binary file are dropped, since
  # grep reading one stops treating the stream as text and would skip it all.
  git -c core.quotePath=false log --all --root -p -U0 --no-color --no-ext-diff --no-textconv --text \
      --src-prefix=a/ --dst-prefix=b/ --format='commit %h' 2>/dev/null | tr -d '\000' | awk "$UNQ"'
    /^commit [0-9a-f]+$/ { c = $2; h = 0; next }
    /^diff --git /       { h = 1; p = ""; next }
    h && /^\+\+\+ /      { s = substr($0, 5); sub(/\t$/, "", s); p = unq(s); if (!sub(/^b\//, "", p)) p = ""; next }
    /^@@/                { h = 0; next }
    !h && /^\+/ && p != "" { print c "\t" p "\t" substr($0, 2) }' > "$WORK/added"
  git -c core.quotePath=false log --all --root --diff-filter=A --name-only --format='commit %h' 2>/dev/null | awk "$UNQ"'
    /^commit [0-9a-f]+$/ { c = $2; next } NF { print c "\t" unq($0) }' | while IFS=$'\t' read -r c p; do
      if is_env "$p"; then printf 'history  %s  %s  env file committed (its values are not read)\n' "$c" "$p"; fi
    done > "$WORK/envs"
  if [ -s "$WORK/envs" ]; then cat "$WORK/envs"; FOUND=$((FOUND + $(wc -l < "$WORK/envs"))); fi
  awk -F'\t' '{ print $3 }' "$WORK/added" | grep_any -- - | sed -E 's/^[^:]*:([0-9]+):.*/\1/' | sort -nu > "$WORK/lines" || true
  while IFS= read -r n; do
    IFS=$'\t' read -r c p text < <(sed -n "${n}p" "$WORK/added")
    is_env "$p" && continue
    finds_in "history  $c  $p" "$text" 0
  done < "$WORK/lines"
fi

for p in ${PATHS[@]+"${PATHS[@]}"}; do
  grep_any -r -- "$p" | sort -t: -k1,1 -k2,2n -u > "$WORK/phits"
  while IFS= read -r hit; do
    f=${hit%%:*}; rest=${hit#*:}; n=${rest%%:*}; text=${rest#*:}
    finds_in "path  $f:$n" "$text" path
  done < "$WORK/phits"
done

if [ -s "$WORK/unread" ]; then
  echo "secret-sweep: could not read these, so the sweep is incomplete (fix the permissions and re-run):" >&2
  sort -u "$WORK/unread" | sed 's/^/  /' >&2
  [ "$FOUND" -eq 0 ] || echo "secret-sweep: $FOUND find(s) in what it could read. Each high-risk one becomes a card: the owner rotates it; see adapters/secret-sweep/README.md."
  exit 2
fi
if [ "$FOUND" -eq 0 ]; then echo "secret-sweep: nothing found"; exit 0; fi
echo "secret-sweep: $FOUND find(s). Each high-risk one becomes a card: the owner rotates it; see adapters/secret-sweep/README.md."
exit 1
