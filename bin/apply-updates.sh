#!/usr/bin/env bash
#
# apply-updates.sh — push this repo's template/convention improvements DOWN into an
# existing scaffolded project, so a project scaffolded months ago can still receive
# them. Without this, a scaffold is a snapshot: the template improves and the
# projects made from it do not.
#
# Run from the MASTER ai-dev-workflow repo:   ./apply-updates.sh <project-dir>
#
# Two modes, auto-detected:
#   INCREMENTAL — the project has a `.workflow-sync` stamp (the master commit it last
#                 synced to) AND that commit is in this master's history → embed the exact
#                 `template/` git diff since then + the MOC changelog entries added in range.
#   CATALOG     — no usable stamp → list every `MOC-<date>-NN` entry from the master
#                 CHANGELOG as a candidate; the agent + user skip any already applied.
# Either way it writes `UPGRADE_WORKORDER.md` INTO THE PROJECT; an AGENT then applies the
# changes to the project's real (filled) docs — propose-then-approve, never re-introducing
# placeholders — and stamps `.workflow-sync` to the new master HEAD so the next run is
# incremental.
#
# Why hybrid: the master template carries {{PLACEHOLDERS}} and generic prose; the project's
# docs are concrete and filled. Only an agent can translate a template-level change into the
# project's real wording, handle file moves/deletes, and merge into rich existing docs.
#
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)   # bin/
MASTER_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
TEMPLATE="$MASTER_ROOT/template"
ALLOW_DIRTY="${ALLOW_DIRTY:-0}"
ARGS=()
for a in "$@"; do
  case "$a" in
    --allow-dirty) ALLOW_DIRTY=1 ;;
    *) ARGS+=("$a") ;;
  esac
done
PROJECT="${ARGS[0]:-}"
[ -n "$PROJECT" ] || { echo "usage: apply-updates.sh [--allow-dirty] <project-dir>"; exit 1; }
PROJECT=$(cd "$PROJECT" && pwd)
MCL="$MASTER_ROOT/CHANGELOG.md"
STAMP="$PROJECT/.workflow-sync"
[ -f "$MCL" ] || { echo "no CHANGELOG.md in master ($MASTER_ROOT)"; exit 1; }
[ -d "$TEMPLATE" ] || { echo "template/ not found (expected $TEMPLATE)"; exit 1; }
[ "$PROJECT" = "$MASTER_ROOT" ] && { echo "project dir must differ from the master"; exit 1; }

# --- master HEAD (only if the master is a git checkout) ---
MASTER_HEAD=""
if git -C "$MASTER_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  MASTER_HEAD=$(git -C "$MASTER_ROOT" rev-parse HEAD 2>/dev/null || echo "")
fi

# --- refuse to run on a dirty master (the silent-omission footgun) ---
# Everything downstream is computed from COMMITTED history (`git diff SINCE..HEAD`),
# so uncommitted template/ or CHANGELOG.md work is invisible here: the run reports
# "nothing to apply" and stamps the project as synced, silently skipping the change.
# Fail loudly instead. `--allow-dirty` is the deliberate override.
if [ -n "$MASTER_HEAD" ] && [ "${ALLOW_DIRTY:-}" != 1 ]; then
  DIRTY=$(git -C "$MASTER_ROOT" status --porcelain -- template/ CHANGELOG.md 2>/dev/null || true)
  if [ -n "$DIRTY" ]; then
    echo "✖ the master has UNCOMMITTED changes that this run would silently ignore:"
    echo "$DIRTY" | sed 's/^/    /'
    echo
    echo "  Updates are derived from committed history, so anything above would NOT reach"
    echo "  the project — and the run would stamp it as up to date anyway."
    echo "  Commit them first, or re-run with --allow-dirty if you truly mean to ship only"
    echo "  what is already committed."
    exit 1
  fi
fi

# pull one "### MOC-… " block out of the master changelog by id
moc_block() { awk -v id="$1" 'index($0,id) && /^### / {p=1; print; next} /^### / {p=0} p {print}' "$MCL"; }

# --- read the project's last-synced sha from the stamp (if any) ---
SINCE=""
[ -f "$STAMP" ] && SINCE=$(grep -oE 'MASTER_COMMIT=[0-9a-f]+' "$STAMP" 2>/dev/null | head -1 | cut -d= -f2 || echo "")

# usable only if it's a real commit object in this master
USABLE_SINCE=""
if [ -n "$SINCE" ] && [ -n "$MASTER_HEAD" ] && git -C "$MASTER_ROOT" cat-file -e "${SINCE}^{commit}" 2>/dev/null; then
  USABLE_SINCE="$SINCE"
fi

banner() { echo "$1"; }

# ======================= INCREMENTAL MODE =======================
if [ -n "$USABLE_SINCE" ]; then
  if [ "$USABLE_SINCE" = "$MASTER_HEAD" ]; then
    echo "✔ $(basename "$PROJECT") is already synced to master HEAD (${MASTER_HEAD:0:12}). Nothing to apply."
    exit 0
  fi
  tdiff=$(git -C "$MASTER_ROOT" diff "$USABLE_SINCE..HEAD" -- template/ 2>/dev/null || true)
  if [ -z "$tdiff" ]; then
    echo "✔ no template/ changes between ${USABLE_SINCE:0:12} and HEAD — nothing to apply."
    echo "  (Bumping the stamp so future runs stay incremental.)"
    { echo "MASTER_COMMIT=$MASTER_HEAD"; } > "$STAMP"
    exit 0
  fi
  # MOC ids whose entry was ADDED to CHANGELOG in this range (precise intent list)
  new_mocs=$(git -C "$MASTER_ROOT" diff "$USABLE_SINCE..HEAD" -- CHANGELOG.md 2>/dev/null \
             | grep -oE '^\+### MOC-[0-9]{8}-[0-9]+' | sed -E 's/^\+### //' | awk '!s[$0]++' || true)
  wo="$PROJECT/UPGRADE_WORKORDER.md"
  {
    echo "# UPGRADE WORKORDER — apply master workflow updates (incremental)"
    echo; echo "_Master: \`$MASTER_ROOT\` @ \`${MASTER_HEAD}\`_  ·  _Project last synced: \`${USABLE_SINCE}\`_"
    echo
    echo "The master template changed since this project last synced. Below is the **intent**"
    echo "(changelog entries) followed by the **ground-truth \`template/\` diff**. Apply each change"
    echo "to *this project's real, filled docs* — not by copying template text verbatim."
    echo
    echo "## Agent instructions"
    echo "0. **Plan first (spine):** publish a short apply plan (which MOCs / diff hunks, which project files, deliberate skips), then **stop and wait for explicit approval**. Do **not** edit docs until the plan is approved. Canonical: \`WORKFLOW.md\` → Workflow sync workorders."
    echo "1. For each approved change: read the affected doc **in this project** (filled, concrete)."
    echo "2. Port the change **conceptually** — translate the template's generic/\`{{PLACEHOLDER}}\` wording"
    echo "   into this project's real stack/wording. **Never introduce \`{{PLACEHOLDERS}}\` into filled docs.**"
    echo "3. Honor **file moves/renames/deletes** in the diff (e.g. \`git mv\`, remove a retired doc) — preserve history."
    echo "4. Keep the project's own content (domain model, endpoints, real tasks/decisions); edit only the affected section."
    echo "5. Nothing moved or deleted silently — only what the approved plan covers."
    echo "6. Fix any inbound links to moved/removed files. Verify \`grep -rn '{{' .\` finds nothing new."
    echo "7. If \`WORKFLOW.md\` or any \`CLAUDE.md\` changed, keep the \`AGENTS.md\` Binding in sync:"
    echo "   mid-session \`bash adapters/agents/emit-agents.sh --force\`, or rely on \`.githooks/pre-commit\` (see \`adapters/agents/README.md\`)."
    echo "8. When done + approved, write the stamp so the next run is incremental:"
    echo "   \`\`\`"
    echo "   printf 'MASTER_COMMIT=%s\\n' $MASTER_HEAD > .workflow-sync"
    echo "   \`\`\`"
    echo "   then delete this \`UPGRADE_WORKORDER.md\`."
    echo "9. **Mid-session re-read (important):** you just edited docs you operate under (\`WORKFLOW.md\`, \`ARCHITECT.md\`, \`CLAUDE.md\`) — but their **old** text is still in your context. Before doing any further work, **re-read every changed rulebook** so the new rules actually take effect this session; if the changes alter your operating rules, prefer **restarting the session clean**. A rule you edited but didn't reload does not change your behavior."
    echo
    if [ -n "$new_mocs" ]; then
      echo "## Changes to apply (intent)"
      for id in $new_mocs; do echo; moc_block "$id"; done
      echo
    else
      echo "## Changes to apply (intent)"
      echo "_(No new \`MOC-…\` changelog entries in range — rely on the diff below. Consider adding MOC ids upstream.)_"
      echo
    fi
    echo "## Ground-truth \`template/\` diff (${USABLE_SINCE:0:12}..${MASTER_HEAD:0:12})"
    echo '```diff'
    echo "$tdiff"
    echo '```'
  } > "$wo"
  echo "✔ wrote ${wo#"$PROJECT"/} into $(basename "$PROJECT")  (incremental)"
  echo "  next: open THAT PROJECT in your agent and say \"execute UPGRADE_WORKORDER.md\""
  echo "        (agent must plan first → wait for approval → then edit; see WORKFLOW.md → Workflow sync workorders)"
  exit 0
fi

# ======================= CATALOG MODE =======================
echo "▶ no usable \`.workflow-sync\` stamp in $(basename "$PROJECT") — catalog mode (all MOC entries as candidates)."
mocs=$(grep -oE 'MOC-[0-9]{8}-[0-9]+' "$MCL" | awk '!s[$0]++' || true)
if [ -z "$mocs" ]; then
  echo "✔ the master CHANGELOG has no MOC-<date>-NN entries to apply."
  echo "  (Master-originated changes need MOC ids to be trackable downstream — add them, then re-run.)"
  exit 0
fi
wo="$PROJECT/UPGRADE_WORKORDER.md"
{
  echo "# UPGRADE WORKORDER — apply master workflow updates (catalog)"
  echo; echo "_Master: \`$MASTER_ROOT\`${MASTER_HEAD:+ @ \`$MASTER_HEAD\`}_"
  echo
  echo "This project has no \`.workflow-sync\` stamp, so there's no baseline to diff from. Below is the"
  echo "**full catalog** of master-originated changes. Some may already be present — check each before applying."
  echo
  echo "## Agent instructions"
  echo "0. **Plan first (spine):** publish a short apply plan (which MOCs already present vs to apply, which files to copy/edit, deliberate skips), then **stop and wait for explicit approval**. Do **not** edit docs until the plan is approved. Canonical: \`WORKFLOW.md\` → Workflow sync workorders. \"Execute\" starts this step — it does **not** authorize silent edits."
  echo "1. For each approved MOC: check whether this project **already reflects it** (read the affected docs). Skip if so."
  echo "2. **New files (scripts, adapters, hooks): COPY them VERBATIM from the master — never retype or reconstruct them from the prose below.** Catalog mode carries **no diff**, so the entries describe *intent only*; they are NOT a substitute for file content. The master template is at:"
  echo "   \`\`\`"
  echo "   $TEMPLATE"
  echo "   \`\`\`"
  echo "   Copy the file byte-for-byte (e.g. \`cp \"$TEMPLATE/<rel>\" \"<rel>\"\`) and **preserve the executable bit** on scripts/hooks."
  echo "3. For doc changes, port the change **conceptually** into the project's real, filled docs —"
  echo "   translate generic/\`{{PLACEHOLDER}}\` wording to this project's stack. **Never add \`{{PLACEHOLDERS}}\`.**"
  echo "4. Honor file moves/renames/deletes the change describes (preserve git history); fix inbound links. If a MOC says a project-local copy of something is now superseded by a shipped file, **delete the local copy and repoint what referenced it** — leaving both is the drift the change exists to remove."
  echo "5. Edit only affected sections; keep all project-specific content — only what the approved plan covers."
  echo "6. If \`WORKFLOW.md\` or any \`CLAUDE.md\` changed (or \`adapters/agents/\` was newly copied), keep \`AGENTS.md\` in sync: mid-session \`bash adapters/agents/emit-agents.sh --force\`, or \`.githooks/pre-commit\` on commit."
  echo "7. When done + approved, establish the stamp so future runs are incremental:"
  echo "   \`\`\`"
  echo "   printf 'MASTER_COMMIT=%s\\n' ${MASTER_HEAD:-<master-HEAD-sha>} > .workflow-sync"
  echo "   \`\`\`"
  echo "   then delete this \`UPGRADE_WORKORDER.md\`."
  echo "8. **Mid-session re-read (important):** you just edited docs you operate under (\`WORKFLOW.md\`, \`ARCHITECT.md\`, \`CLAUDE.md\`) — their **old** text is still in your context. **Re-read every changed rulebook** before further work so the new rules take effect this session, or **restart the session clean**. A rule you edited but didn't reload does not change your behavior."
  echo
  echo "> Tip: to make the *next* upgrade a clean incremental diff, this stamp is all that's needed."
  echo

  # Files the master ships that this project lacks — the actionable copy-list for step 2.
  # (Scaffolding docs are excluded: they're consumed and deleted after bootstrap.)
  missing=""
  while IFS= read -r -d '' tf; do
    rel="${tf#"$TEMPLATE"/}"
    case "$(basename "$rel")" in BOOTSTRAP.md|ADOPT.md|STACK.md|WORKORDER.md) continue;; esac
    [ -e "$PROJECT/$rel" ] || missing+="- \`$rel\`"$'\n'
  done < <(find "$TEMPLATE" -type f -not -path '*/.git/*' -print0)
  if [ -n "$missing" ]; then
    echo "## Files the master ships that this project lacks"
    echo "Copy verbatim from \`$TEMPLATE/<path>\` **only where a MOC below calls for it.** Some may belong to workspaces this project doesn't use — skip those."
    echo
    printf '%s' "$missing"
    echo
  fi

  echo "## Candidate changes (newest first)"
  for id in $mocs; do echo; moc_block "$id"; done
} > "$wo"
echo "✔ wrote ${wo#"$PROJECT"/} into $(basename "$PROJECT")  ($(printf '%s\n' $mocs | wc -l | tr -d ' ') MOC candidate(s), catalog)"
echo "  next: open THAT PROJECT in your agent and say \"execute UPGRADE_WORKORDER.md\""
echo "        (agent must plan first → wait for approval → then edit; see WORKFLOW.md → Workflow sync workorders)"
