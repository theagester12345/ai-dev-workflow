#!/usr/bin/env bash
#
# emit-agents.sh — compile the AGENTS.md tree from authored sources.
#
# Authored (edit these):  WORKFLOW.md, <workspace>/CLAUDE.md
# Emitted (Binding):      AGENTS.md,   <workspace>/AGENTS.md
#
# Same altitude as the source — see WORKFLOW.md → Instruction precedence.
# Never invent project rules here; only add the standard Binding/init preamble
# and copy the authored source.
#
# An emitted file is recognised by its first line (the EMITTED Binding marker), never by its name.
# An AGENTS.md without it is the project's own — Lovable, Codex and Copilot users write one — and is
# never overwritten, --force included.
#
set -euo pipefail

TARGET="$PWD"
FORCE=0
LIST=0
RENDER=""
ONLY=" "
while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET=$(cd "$2" && pwd); shift 2;;
    --force)  FORCE=1; shift;;
    --list)   LIST=1; shift;;
    --only)   ONLY="$ONLY${2:?--only needs a Binding path} "; shift 2;;
    --render) RENDER="${2:?--render needs a Binding path}"; shift 2;;
    -h|--help)
      echo "Usage: emit-agents.sh [--target DIR] [--force] [--list]"
      echo "       emit-agents.sh --render <AGENTS.md | ws/AGENTS.md> < source > out"
      echo "  Regenerate AGENTS.md from WORKFLOW.md and each workspace CLAUDE.md."
      echo "  --force  overwrite an existing emitted Binding (never a file without the marker)"
      echo "  --list   print each emitted Binding's path on stdout, the log on stderr"
      echo "  --only   emit only that Binding (AGENTS.md or <ws>/AGENTS.md; repeatable; default: all)"
      echo "  --render print that Binding compiled from the source read on stdin; writes nothing"
      echo "           (the pre-commit hook feeds it the STAGED source; ownership is the caller's check)"
      exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 2;;
  esac
done

MARKER='> ⚙️ **EMITTED Binding**'
log() { if [ "$LIST" -eq 1 ]; then echo "$@" >&2; else echo "$@"; fi; }
# Printed as each is decided, not at the end, so a run that fails part-way still names what it owns.
owned() { [ "$LIST" -eq 1 ] && printf '%s\n' "$1"; return 0; }
# Read into a variable, not piped into grep -q: under pipefail an early match can cut head off.
is_emitted() { local first; first=$(head -n 1 "$1" 2>/dev/null) || return 1; [[ $first == *"$MARKER"* ]]; }

# The Binding for $1 (dest relpath) compiled from $2 (source relpath), source text on stdin.
render_emitted() {
  local dest_rel=$1 src_rel=$2
  local src_link wf_link dest_dir
  dest_dir=$(dirname "$dest_rel")
  case "$dest_dir" in
    .)
      src_link="$src_rel"
      wf_link="WORKFLOW.md"
      ;;
    *)
      wf_link="../WORKFLOW.md"
      if [ "$(dirname "$src_rel")" = "$dest_dir" ]; then
        src_link="$(basename "$src_rel")"
      else
        src_link="../$src_rel"
      fi
      ;;
  esac

  {
    printf '%s\n' \
      "$MARKER — source: [\`$src_rel\`]($src_link). Same altitude as that source — see [\`WORKFLOW.md\` → Instruction precedence]($wf_link#instruction-precedence)." \
      ">" \
      "> **Do not hand-edit.** Change the source. Re-emit is automatic on \`git commit\` (pre-commit); mid-session run \`adapters/agents/emit-agents.sh --force\`." \
      ""
    # No "Start here" is added here: each side's CLAUDE.md carries its own, so a host
    # reading either file gets the same line, and the two cannot disagree.
    cat
  }
}

# $1 = dest relpath, $2 = source relpath
write_emitted() {
  local dest_rel=$1 src_rel=$2
  local dest="$TARGET/$dest_rel" src="$TARGET/$src_rel"
  [ -f "$src" ] || return 0
  [ "$ONLY" = " " ] || case "$ONLY" in *" $dest_rel "*) ;; *) return 0 ;; esac
  if [ -e "$dest" ] && ! is_emitted "$dest"; then
    log "  refuse $dest_rel (the project's own file: no EMITTED Binding marker, so never overwritten; hosts that read only AGENTS.md do not see $src_rel — adapters/agents/README.md)"
    return 0
  fi
  if [ -e "$dest" ] && [ "$FORCE" -eq 0 ]; then
    log "  skip $dest_rel (exists; pass --force to overwrite)"
    owned "$dest_rel"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  render_emitted "$dest_rel" "$src_rel" < "$src" > "$dest"
  log "  emit $dest_rel ← $src_rel"
  owned "$dest_rel"
}

if [ -n "$RENDER" ]; then
  case "$RENDER" in
    AGENTS.md) render_emitted AGENTS.md WORKFLOW.md ;;
    */AGENTS.md) render_emitted "$RENDER" "${RENDER%AGENTS.md}CLAUDE.md" ;;
    *) echo "emit-agents: --render takes AGENTS.md or <workspace>/AGENTS.md, not $RENDER" >&2; exit 2 ;;
  esac
  exit 0
fi

log "▶ emit AGENTS.md tree → $TARGET"

if [ -f "$TARGET/WORKFLOW.md" ]; then
  write_emitted "AGENTS.md" "WORKFLOW.md"
else
  echo "  ! no WORKFLOW.md — skip root AGENTS.md" >&2
fi

shopt -s nullglob
for claude in "$TARGET"/*/CLAUDE.md; do
  [ -f "$claude" ] || continue
  ws=$(basename "$(dirname "$claude")")
  write_emitted "$ws/AGENTS.md" "$ws/CLAUDE.md"
done

log "✔ emit done"
