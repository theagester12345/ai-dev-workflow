#!/usr/bin/env bash
#
# scaffold.sh — deterministic scaffolder for the AI workflow (HYBRID: script + agent).
#
# The script does the MECHANICAL bones with zero tokens:
#   - create the chosen workspaces, copy template .md files (NEVER overwrites existing)
#   - substitute placeholders you provide (--set / --answers) + ones it can derive
#     (SIDE, SIDE_DIR, OTHER_SIDE) — so the agent doesn't have to
#   - strip the `⚠️ STARTER` banner from any file it fully resolves
#   - list the loose DOCS that need classifying (it never touches source code)
#   - write WORKORDER.md
# The AGENT then does only the SEMANTIC remainder: translate principles in the
# engineering CLAUDE.md files, classify & move docs (with your approval), and
# (adopt) merge rules into existing docs.
#
set -euo pipefail

ALL_WS="product backend frontend back-office infra"
ENG_WS="backend frontend"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)   # bin/
MASTER_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
TEMPLATE_DIR="$MASTER_ROOT/template"
[ -d "$TEMPLATE_DIR" ] || { echo "template/ not found next to bin/ (expected $TEMPLATE_DIR)"; exit 1; }

MODE=""; WORKSPACES=""; TARGET="$PWD"
SET_SPECS=()
INTERACTIVE=false
NON_INTERACTIVE=false
# files the agent must finalize (principle translation) — never auto-stripped:
NO_STRIP="backend/CLAUDE.md frontend/CLAUDE.md"

usage() {
cat <<'EOF'
scaffold.sh — deterministic scaffolder for the AI workflow (hybrid: script + agent)

Usage:
  scaffold.sh bootstrap [options]   # fresh project
  scaffold.sh adopt     [options]   # existing project (never overwrites your files)

Options:
  --workspaces a,b,c     subset of: product backend frontend back-office infra (default: all)
  --target DIR           project to scaffold into (default: current dir)
  --set KEY=VALUE        fill a placeholder. Global, or per-workspace with WS.KEY=VALUE
                         e.g. --set PROJECT_NAME=Acme --set backend.LANGUAGE=Java
  --answers FILE         read many KEY=VALUE / WS.KEY=VALUE lines from a file (# = comment)
  --interactive          prompt for common placeholders (allows skipping unknowns)
  --non-interactive      skip prompts even if no --set/--answers provided
  -h, --help

The more you pass via --set/--answers, the more the script resolves and the fewer
tokens the agent spends. Anything left as {{...}} is finished by the agent.
After it runs, open the project in your agent and say "execute WORKORDER.md".

Derived automatically (no need to pass): SIDE, SIDE_DIR, OTHER_SIDE.
EOF
exit "${1:-0}"
}

prompt_value() {
  # $1 = prompt text, $2 = example/default hint (optional)
  local prompt="$1" hint="${2:-}" val
  if [ -n "$hint" ]; then
    read -r -p "$prompt [$hint]: " val
  else
    read -r -p "$prompt: " val
  fi
  printf '%s' "$val"
}

prompt_placeholders() {
  local val
  
  echo
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  AI Dev Workflow Setup — Interactive Mode"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo
  echo "Answer what you know now. Press Enter to skip anything you'll decide later."
  echo "The AI agent will fill remaining placeholders when you run WORKORDER.md."
  echo
  
  # Project-level
  echo "PROJECT INFORMATION"
  echo "───────────────────────────────────────────────────────────────────────────"
  val=$(prompt_value "Project name" "MyApp")
  [ -n "$val" ] && SET_SPECS+=("PROJECT_NAME=$val")
  
  case " $WORKSPACES " in
    *" back-office "*)
      val=$(prompt_value "Company name" "Acme Inc.")
      [ -n "$val" ] && SET_SPECS+=("COMPANY_NAME=$val")
      val=$(prompt_value "Jurisdiction" "Delaware, USA")
      [ -n "$val" ] && SET_SPECS+=("JURISDICTION=$val")
      ;;
  esac
  
  # Backend
  if [[ " $WORKSPACES " == *" backend "* ]]; then
    echo
    echo "BACKEND CONFIGURATION"
    echo "───────────────────────────────────────────────────────────────────────────"
    val=$(prompt_value "Language" "Java 21, Python 3.12, TypeScript 5, Go 1.21")
    [ -n "$val" ] && SET_SPECS+=("backend.LANGUAGE=$val")
    
    val=$(prompt_value "Framework" "Spring Boot 3.2, Django 5.0, Express, Gin")
    [ -n "$val" ] && SET_SPECS+=("backend.FRAMEWORK=$val")
    
    val=$(prompt_value "Build tool" "Maven, Gradle, npm, pip, go mod")
    [ -n "$val" ] && SET_SPECS+=("backend.BUILD_TOOL=$val")
    
    val=$(prompt_value "Database" "Supabase PostgreSQL, MongoDB Atlas")
    [ -n "$val" ] && SET_SPECS+=("backend.DB=$val")
    
    val=$(prompt_value "Auth mechanism" "Supabase Auth + JWT, Auth0, Firebase Auth")
    [ -n "$val" ] && SET_SPECS+=("backend.AUTH=$val")
    
    val=$(prompt_value "Backend architect persona name" "Jarvis")
    [ -n "$val" ] && SET_SPECS+=("backend.ARCHITECT_NAME=$val")
    
    val=$(prompt_value "API base path" "/api/v1")
    [ -n "$val" ] && SET_SPECS+=("backend.API_BASE_PATH=$val")
  fi
  
  # Frontend
  if [[ " $WORKSPACES " == *" frontend "* ]]; then
    echo
    echo "FRONTEND CONFIGURATION"
    echo "───────────────────────────────────────────────────────────────────────────"
    val=$(prompt_value "Language" "TypeScript 5, JavaScript ES2024")
    [ -n "$val" ] && SET_SPECS+=("frontend.LANGUAGE=$val")
    
    val=$(prompt_value "Framework" "Next.js 16, React 19, Vue 3, Svelte 5")
    [ -n "$val" ] && SET_SPECS+=("frontend.FRAMEWORK=$val")
    
    val=$(prompt_value "Build tool" "npm, pnpm, yarn, bun")
    [ -n "$val" ] && SET_SPECS+=("frontend.BUILD_TOOL=$val")
    
    val=$(prompt_value "Frontend architect persona name" "Nexus")
    [ -n "$val" ] && SET_SPECS+=("frontend.ARCHITECT_NAME=$val")
  fi
  
  # Product
  if [[ " $WORKSPACES " == *" product "* ]]; then
    echo
    echo "PRODUCT CONFIGURATION"
    echo "───────────────────────────────────────────────────────────────────────────"
    val=$(prompt_value "Product Lead persona name" "Atlas")
    [ -n "$val" ] && SET_SPECS+=("product.ARCHITECT_NAME=$val")
  fi
  
  echo
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo
}

# ---- parse args ----
[ $# -ge 1 ] || usage 1
case "${1:-}" in
  bootstrap|adopt) MODE=$1; shift;;
  -h|--help) usage 0;;
  *) echo "first arg must be 'bootstrap' or 'adopt'"; echo; usage 1;;
esac
while [ $# -gt 0 ]; do
  case "$1" in
    --workspaces) WORKSPACES="${2//,/ }"; shift 2;;
    --target) TARGET=$(cd "$2" && pwd); shift 2;;
    --set) SET_SPECS+=("$2"); shift 2;;
    --answers)
      while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -n "$line" ] && SET_SPECS+=("$line")
      done < "$2"; shift 2;;
    --interactive) INTERACTIVE=true; shift;;
    --non-interactive) NON_INTERACTIVE=true; shift;;
    -h|--help) usage 0;;
    *) echo "unknown option: $1"; echo; usage 1;;
  esac
done
[ -n "$WORKSPACES" ] || WORKSPACES="$ALL_WS"
for ws in $WORKSPACES; do
  case " $ALL_WS " in *" $ws "*) ;; *) echo "unknown workspace: $ws (valid: $ALL_WS)"; exit 1;; esac
done

# ---- interactive mode decision ----
# If no --set or --answers provided and not explicitly non-interactive, offer interactive mode
if [ "${#SET_SPECS[@]}" -eq 0 ] && [ "$INTERACTIVE" = false ] && [ "$NON_INTERACTIVE" = false ]; then
  echo "No configuration provided. Would you like to use interactive mode? [Y/n]"
  read -r reply
  case "${reply:-y}" in [Yy]*) INTERACTIVE=true;; [Nn]*) ;; *) INTERACTIVE=true;; esac
fi

# Run interactive prompts if requested
if [ "$INTERACTIVE" = true ]; then
  prompt_placeholders
fi
if [ "$TARGET" = "$TEMPLATE_DIR" ] || [ "$TARGET" = "$MASTER_ROOT" ]; then echo "refusing to scaffold the workflow into itself"; exit 1; fi

ENG_COUNT=0
for ws in $WORKSPACES; do case " $ENG_WS " in *" $ws "*) ENG_COUNT=$((ENG_COUNT+1));; esac; done

# ---- substitution helpers ----
esc_repl() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }

auto_sets() {  # $1 = workspace → KEY=VALUE lines the script can derive
  case "$1" in
    backend)  printf 'SIDE=Backend\nSIDE_DIR=backend\n';;
    frontend) printf 'SIDE=Frontend\nSIDE_DIR=frontend\n';;
    product)  printf 'SIDE=Product\nSIDE_DIR=product\n';;
    back-office) printf 'SIDE_DIR=back-office\n';;
    infra)    printf 'SIDE_DIR=infra\n';;
  esac
  if [ "$ENG_COUNT" -ge 2 ]; then
    case "$1" in
      backend)  printf 'OTHER_SIDE=frontend\n';;
      frontend) printf 'OTHER_SIDE=backend\n';;
    esac
  fi
}

user_sets() {  # $1 = workspace → applicable user KEY=VALUE lines (ws-scoped first, then global)
  local ws=$1 spec key val scope
  for spec in "${SET_SPECS[@]:-}"; do
    [ -n "$spec" ] || continue
    key="${spec%%=*}"; val="${spec#*=}"
    case "$key" in
      *.*) scope="${key%%.*}"; [ "$scope" = "$ws" ] && printf '%s=%s\n' "${key#*.}" "$val";;
    esac
  done
  for spec in "${SET_SPECS[@]:-}"; do
    [ -n "$spec" ] || continue
    key="${spec%%=*}"; val="${spec#*=}"
    case "$key" in *.*) ;; *) printf '%s=%s\n' "$key" "$val";; esac
  done
}

SEDDIR=$(mktemp -d)
trap 'rm -rf "$SEDDIR"' EXIT
sedfile_for_ws() {  # $1 = workspace ("" = root) → path to a cached sed script
  local ws=$1 key kv k v f
  key="${1:-_root}"; f="$SEDDIR/$key.sed"
  if [ ! -f "$f" ]; then
    { user_sets "$ws"; auto_sets "$ws"; } | while IFS= read -r kv; do
      [ -n "$kv" ] || continue
      k="${kv%%=*}"; v="${kv#*=}"
      printf 's|{{%s}}|%s|g\n' "$k" "$(esc_repl "$v")"
    done > "$f"
  fi
  printf '%s' "$f"
}

# ---- copy + process ----
COPIED=(); SKIPPED=(); RESOLVED=()
copy_if_missing() {
  local src=$1 dest=$2
  if [ -e "$dest" ]; then SKIPPED+=("${dest#"$TARGET"/}"); return 0; fi
  cp "$src" "$dest"; COPIED+=("${dest#"$TARGET"/}")
}
process_file() {  # $1 = relpath of a freshly-copied file → substitute + maybe strip banner
  local rel=$1 abs="$TARGET/$1" ws sf
  case "$(basename "$rel")" in BOOTSTRAP.md|ADOPT.md) return 0;; esac  # keep examples/table intact
  case "$rel" in */*) ws="${rel%%/*}";; *) ws="";; esac
  sf=$(sedfile_for_ws "$ws")
  [ -s "$sf" ] && sed -i -f "$sf" "$abs"
  case " $NO_STRIP " in *" $rel "*) return 0;; esac          # agent finalizes these
  grep -q '{{' "$abs" 2>/dev/null && return 0                # placeholders remain → keep banner
  if grep -q '^> ⚠️ STARTER' "$abs" 2>/dev/null; then
    sed -i '/^> ⚠️ STARTER/d' "$abs"; RESOLVED+=("$rel")
  fi
}

echo "▶ scaffold $MODE → $TARGET"
echo "  workspaces: $WORKSPACES"

copy_if_missing "$TEMPLATE_DIR/STACK.md" "$TARGET/STACK.md"
copy_if_missing "$TEMPLATE_DIR/BOOTSTRAP.md" "$TARGET/BOOTSTRAP.md"   # Principle→Binding table (both modes)
copy_if_missing "$TEMPLATE_DIR/WORKFLOW.md" "$TARGET/WORKFLOW.md"                 # shared operating conventions; stays in the project
copy_if_missing "$TEMPLATE_DIR/CONSOLIDATION.md" "$TARGET/CONSOLIDATION.md"       # stays in the project
copy_if_missing "$TEMPLATE_DIR/WORKFLOW_CHANGELOG.md" "$TARGET/WORKFLOW_CHANGELOG.md"  # upstream log; stays in the project
if [ "$MODE" = adopt ]; then copy_if_missing "$TEMPLATE_DIR/ADOPT.md" "$TARGET/ADOPT.md"; fi
# NOTE: CHANGELOG.md + bin/ (scaffold.sh, pull-updates.sh) are MASTER-only — never copied into a project.

for ws in $WORKSPACES; do
  if [ ! -d "$TEMPLATE_DIR/$ws" ]; then echo "  ! no template for '$ws', skipping"; continue; fi
  mkdir -p "$TARGET/$ws"
  while IFS= read -r -d '' f; do
    base=$(basename "$f")
    # a lone engineering side has no peer to sync with → skip its INTERFACE.md
    if [ "$base" = "INTERFACE.md" ] && [ "$ENG_COUNT" -lt 2 ]; then continue; fi
    copy_if_missing "$f" "$TARGET/$ws/$base"
  done < <(find "$TEMPLATE_DIR/$ws" -maxdepth 1 -type f -print0)
done

# substitute + banner-strip every freshly-copied file (never touches existing files)
for rel in "${COPIED[@]:-}"; do [ -n "$rel" ] && process_file "$rel"; done

# ---- .gitignore (mockups) ----
gi="$TARGET/.gitignore"; touch "$gi"
add_ignore() { grep -qxF "$1" "$gi" 2>/dev/null || echo "$1" >> "$gi"; }
case " $WORKSPACES " in *" product "*) add_ignore "product/mockups/";; esac
case " $WORKSPACES " in *" frontend "*) add_ignore "frontend/mockups/";; esac

# ---- stack detection (best-effort; agent confirms) ----
detect_stack() {
  local d=$TARGET out=""
  if [ -f "$d/pom.xml" ]; then out+="Java/Maven "; fi
  if [ -f "$d/build.gradle" ] || [ -f "$d/build.gradle.kts" ]; then out+="JVM/Gradle "; fi
  if [ -f "$d/go.mod" ]; then out+="Go "; fi
  if [ -f "$d/Cargo.toml" ]; then out+="Rust "; fi
  if [ -f "$d/pyproject.toml" ] || [ -f "$d/requirements.txt" ]; then out+="Python "; fi
  if [ -f "$d/package.json" ]; then
    out+="Node"
    if grep -q '"next"' "$d/package.json" 2>/dev/null; then out+="/Next.js"; fi
    if grep -q '"react"' "$d/package.json" 2>/dev/null; then out+="/React"; fi
    out+=" "
  fi
  if [ -n "$out" ]; then printf '%s' "$out"; else printf 'unknown — ask the user'; fi
}
DETECTED=$(detect_stack)

# ---- loose DOCS to classify (root for new; docs/ in place for existing). NEVER source code. ----
candidates() {
  local f base
  while IFS= read -r -d '' f; do
    base=$(basename "$f")
    case "$base" in README.md|BOOTSTRAP.md|ADOPT.md|STACK.md|WORKFLOW.md|WORKORDER.md|CONSOLIDATION.md|WORKFLOW_CHANGELOG.md|CHANGELOG.md|PULL_WORKORDER.md|HARVEST_WORKORDER.md) continue;; esac
    echo "- \`${f#"$TARGET"/}\` (root-level doc — which workspace?)"
  done < <(find "$TARGET" -maxdepth 1 -type f -name '*.md' -print0 2>/dev/null)
  if [ "$MODE" = adopt ] && [ -d "$TARGET/docs" ]; then
    while IFS= read -r -d '' f; do
      base=$(basename "$f")
      case "$base" in CLAUDE.md|PRIVACY.md|TERMS.md|CONTRACT.md|EMAILS.md|SESSION_LOG.md|README.md) continue;; esac
      echo "- \`${f#"$TARGET"/}\` (in docs/ — product? legal? technical?)"
    done < <(find "$TARGET/docs" -maxdepth 1 -type f -print0 2>/dev/null)
  fi
}
CANDS=$(candidates || true)

# ---- remaining agent work ----
NEEDS_FILL=(); ENG_CLAUDE=()
for rel in "${COPIED[@]:-}"; do
  [ -n "$rel" ] || continue
  case "$(basename "$rel")" in BOOTSTRAP.md|ADOPT.md|WORKORDER.md) continue;; esac
  case "$rel" in backend/CLAUDE.md|frontend/CLAUDE.md) ENG_CLAUDE+=("$rel"); continue;; esac
  grep -q '{{' "$TARGET/$rel" 2>/dev/null && NEEDS_FILL+=("$rel")
done

# ---- write WORKORDER.md ----
wo="$TARGET/WORKORDER.md"
agent_doc=$([ "$MODE" = adopt ] && echo "ADOPT.md" || echo "BOOTSTRAP.md")
{
  echo "# WORKORDER — generated by scaffold.sh ($MODE)"
  echo
  echo "_Generated $(date '+%Y-%m-%d %H:%M')._ The script did the mechanical scaffolding + filled every placeholder it could. **An AI agent now does only the semantic remainder below**, then deletes this file."
  echo
  echo "## Context"
  echo "- Mode: **$MODE** · Workspaces: \`$WORKSPACES\` · Detected stack: **$DETECTED**"
  echo "- Created: ${#COPIED[@]} file(s) · left untouched (already present): ${#SKIPPED[@]} _(never overwrites)_ · **fully resolved by the script (agent can skip): ${#RESOLVED[@]}**"
  echo
  echo "## Agent tasks — read [\`$agent_doc\`](./$agent_doc), then:"
  echo
  if [ "${#ENG_CLAUDE[@]}" -gt 0 ]; then
    echo "1. **Translate principles** in the engineering \`CLAUDE.md\`(s) — rewrite the Critical Rules / Code Style in the project's language per BOOTSTRAP's Principle→Binding table, then remove their \`⚠️ STARTER\` banner:"
    printf '%s\n' "${ENG_CLAUDE[@]}" | sed 's/^/   - /'
    echo
  fi
  echo "2. **Fill remaining placeholders** (files still containing \`{{...}}\`):"
  if [ "${#NEEDS_FILL[@]}" -gt 0 ]; then printf '%s\n' "${NEEDS_FILL[@]}" | sed 's/^/   - /'; else echo "   - (none — the script resolved them all)"; fi
  echo
  echo "3. **Classify & route loose docs** — for **new** projects these are dumped in the root; for **existing** projects they're docs sitting in the wrong place. Decide each one's workspace, **propose a \`git mv\` plan, and WAIT for approval** before moving. **Never move source/application code** — its location is set by the stack, not by this workflow."
  if [ -n "$CANDS" ]; then printf '%s\n' "$CANDS" | sed 's/^/   /'; else echo "   - (none found)"; fi
  echo
  if [ "$MODE" = adopt ]; then
    echo "4. **Merge, don't overwrite** — retrofit new rules (multi-workspace SCOPE, the product→engineering handoff, the \`Source: FEATURE-XXX\` task field) into existing docs by editing ONLY the affected sections."
    echo
    echo "5. **Clean up** — remove any leftover \`⚠️ STARTER\` banners; verify \`grep -rn '{{' .\` is clean; delete \`$agent_doc\` and this \`WORKORDER.md\`."
  else
    echo "4. **Clean up** — remove any leftover \`⚠️ STARTER\` banners; verify \`grep -rn '{{' .\` is clean; delete \`$agent_doc\` and this \`WORKORDER.md\`."
  fi
} > "$wo"

echo "✔ wrote ${wo#"$TARGET"/}  (created ${#COPIED[@]}, resolved ${#RESOLVED[@]}, skipped ${#SKIPPED[@]})"
echo "  next: open the project in your agent and say \"execute WORKORDER.md\""
