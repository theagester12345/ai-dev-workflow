#!/usr/bin/env bash
#
# emit-index.sh — regenerate the auto file index inside each workspace CLAUDE.md.
#
# BINDING, not a source. Everything between <!-- INDEX:START --> and
# <!-- INDEX:END --> is machine-written and every run overwrites it. Curated,
# annotated entries belong ABOVE the markers, where they are yours and survive
# regeneration.
#
# It lists the DOCS in a workspace's doc home — never code paths. Code location is
# declared per side in STACK.md and can run to thousands of files; this exists so an
# agent can see which docs are present without listing directories.
#
# Usage: bash adapters/index/emit-index.sh [--target DIR]
#        bash adapters/index/emit-index.sh --render WSDIR < CLAUDE.md > out
#   --target DIR    project root to operate on (default: current directory)
#   --only WS       refresh only that workspace (repeatable; default: every one). The
#                   pre-commit hook passes the sides a commit touched, so a side another
#                   session is editing is never rewritten under it.
#   --render WSDIR  print the CLAUDE.md read on stdin with WSDIR's listing in its block;
#                   writes nothing. The pre-commit hook feeds it the STAGED copy, so a
#                   commit never carries a hunk its author left unstaged.
#
# Run it BEFORE adapters/agents/emit-agents.sh: AGENTS.md is compiled from CLAUDE.md,
# so emitting agents first bakes in a stale index.
set -eu

TARGET="."
RENDER=""
ONLY=" "
while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="${2:?--target needs a directory}"; shift 2 ;;
    --only) ONLY="$ONLY${2:?--only needs a workspace} "; shift 2 ;;
    --render) RENDER="${2:?--render needs a workspace directory}"; shift 2 ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    *) echo "emit-index: unknown argument: $1" >&2; exit 1 ;;
  esac
done

# The listing of a doc home, and the file with it put between the markers (stdin → stdout).
# AGENTS.md is excluded: it is a Binding compiled FROM CLAUDE.md, and it is written
# AFTER this runs — listing it would make the index alternate between two states
# instead of settling.
listing_of() {
  find "$1" -maxdepth 2 -type f -name '*.md' ! -name 'AGENTS.md' | sed "s|^$1/||" | LC_ALL=C sort
}
render() {
  awk -v listing="$(listing_of "$1")" '
    /<!-- INDEX:START -->/ {
      print; inblock = 1
      n = split(listing, a, "\n")
      for (i = 1; i <= n; i++) if (a[i] != "") printf("- [`%s`](./%s)\n", a[i], a[i])
      next
    }
    /<!-- INDEX:END -->/ { inblock = 0; print; next }
    !inblock { print }
  '
}

if [ -n "$RENDER" ]; then
  # Same opt-in as the loop below: without both markers the input passes through unchanged.
  src=$(mktemp); trap 'rm -f "$src"' EXIT; cat > "$src"
  if grep -q '<!-- INDEX:START -->' "$src" && grep -q '<!-- INDEX:END -->' "$src"; then
    render "$RENDER" < "$src"
  else
    cat "$src"
  fi
  exit 0
fi

cd "$TARGET"

written=0
for claude in */CLAUDE.md; do
  [ -f "$claude" ] || continue
  [ "$ONLY" = " " ] || case "$ONLY" in *" $(dirname "$claude") "*) ;; *) continue ;; esac
  # Only rewrite files that opt in by carrying BOTH markers. A file with one marker
  # is malformed, and rewriting it would swallow everything after the opening one.
  grep -q '<!-- INDEX:START -->' "$claude" || continue
  if ! grep -q '<!-- INDEX:END -->' "$claude"; then
    echo "emit-index: $claude has INDEX:START but no INDEX:END — skipped" >&2
    continue
  fi

  tmp=$(mktemp)
  render "$(dirname "$claude")" < "$claude" > "$tmp"

  if cmp -s "$tmp" "$claude"; then
    rm -f "$tmp"
  else
    mv "$tmp" "$claude"
    written=$((written + 1))
    echo "  ✔ index updated: $claude"
  fi
done

[ "$written" -eq 0 ] && echo "  · index already current"
exit 0
