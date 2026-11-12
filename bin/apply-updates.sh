#!/usr/bin/env bash
#
# apply-updates.sh — push this repo's template/convention improvements DOWN into an
# existing scaffolded project, so a project scaffolded months ago can still receive
# them. Without this, a scaffold is a snapshot: the template improves and the
# projects made from it do not.
#
# Run from the MASTER ai-dev-workflow repo:
#   bin/apply-updates.sh [--allow-dirty] [--force] <project-dir>   one project
#   bin/apply-updates.sh --status [--root DIR]                     every project: how far behind; writes nothing
#   bin/apply-updates.sh --all [--root DIR] [--force]              a workorder for every project that is behind
#
# Projects are found by their `.workflow-sync` stamp under DIR (default: this repo's parent
# directory), never from a list. An existing UPGRADE_WORKORDER.md is replaced only while it is
# untouched; once the project has changed since it was written, it is an upgrade in progress
# and is left alone unless --force.
#
# Two modes, auto-detected:
#   INCREMENTAL — the project has a `.workflow-sync` stamp (the master commit it last
#                 synced to) AND that commit is in this master's history → apply the
#                 mechanical part (below), then embed the `template/` git diff since then
#                 + the CHANGELOG sections added or changed in range.
#   CATALOG     — no usable stamp → list every `MOC-<date>-NN` entry from the master
#                 CHANGELOG as a candidate; the agent + user skip any already applied.
#                 This edition's changelog is dated release notes, not such a ledger, so
#                 catalog mode reports nothing to list; re-scaffolding writes the stamp.
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
MODE=one; FORCE=0; ROOT=""; ARGS=()
usage() { echo "usage: apply-updates.sh [--allow-dirty] [--force] <project-dir> | --status [--root DIR] | --all [--root DIR] [--force]"; exit 1; }
while [ $# -gt 0 ]; do
  case "$1" in
    --allow-dirty) ALLOW_DIRTY=1 ;;
    --force)       FORCE=1 ;;
    --status)      MODE=status ;;
    --all)         MODE=all ;;
    --root)        [ $# -ge 2 ] || usage; ROOT="$2"; shift ;;
    -h|--help)     usage ;;
    -*)            echo "unknown option: $1"; usage ;;
    *)             ARGS+=("$1") ;;
  esac
  shift
done
if [ "$MODE" = one ]; then [ -n "${ARGS[0]:-}" ] || usage; else [ -z "${ARGS[0]:-}" ] || usage; fi
MCL="$MASTER_ROOT/CHANGELOG.md"
[ -f "$MCL" ] || { echo "no CHANGELOG.md in master ($MASTER_ROOT)"; exit 1; }
[ -d "$TEMPLATE" ] || { echo "template/ not found (expected $TEMPLATE)"; exit 1; }
ROOT=$(cd "${ROOT:-$MASTER_ROOT/..}" && pwd)

# --- master HEAD (only if the master is a git checkout) ---
MASTER_HEAD=""
if git -C "$MASTER_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  MASTER_HEAD=$(git -C "$MASTER_ROOT" rev-parse HEAD 2>/dev/null || echo "")
fi

# --- refuse to run on a dirty master (the silent-omission footgun) ---
# Everything downstream is computed from COMMITTED history (`git diff SINCE..HEAD`),
# so uncommitted template/ or CHANGELOG.md work is invisible here: the run reports
# "nothing to apply" and stamps the project as synced, silently skipping the change.
# Fail loudly instead. `--allow-dirty` is the deliberate override. --status only reads,
# so there it is a warning.
if [ -n "$MASTER_HEAD" ] && [ "${ALLOW_DIRTY:-}" != 1 ]; then
  DIRTY=$(git -C "$MASTER_ROOT" --no-optional-locks status --porcelain -- template/ CHANGELOG.md 2>/dev/null || true)
  if [ -n "$DIRTY" ] && [ "$MODE" = status ]; then
    echo "⚠ the master has uncommitted template/ or CHANGELOG.md changes; the counts below are from committed history only."
    echo
  elif [ -n "$DIRTY" ]; then
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

# pull one "### MOC-… " block out of the master changelog by id (catalog mode). The entry whose
# OWN heading is the id: a heading that merely cites it is another entry. The id must end there,
# so …-1 never matches …-10.
moc_block() { awk -v id="$1" '$0 ~ ("^### " id "([^0-9]|$)") {p=1; print; next} /^### / {p=0} p {print}' "$MCL"; }

# ---- the intent: CHANGELOG sections this project has not seen ------------------------------
# This edition's CHANGELOG is dated release notes: one `## [YYYY-MM-DD]` section per release.
# A section is found by its OWN heading, never by a line that cites its date, or a later section
# that mentions an earlier one would copy that one in again. A section is listed when its text at
# HEAD differs from its text at the stamp: a new release, or one amended since. Sections are
# compared whole, not as diff lines, so one that only moved is not listed.
section_dates() { grep -oE '^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]' | sed -E 's/^## \[//; s/\]$//' | awk '!s[$0]++' || true; }
section_block() {   # date; the changelog on stdin → that section, heading included
  awk -v d="$1" 'BEGIN { h = "## [" d "]" } index($0, h) == 1 { p = 1; print; next } /^## / { p = 0 } p { print }'
}
new_sections_since() {
  local old new d
  old=$(git -C "$MASTER_ROOT" show "$USABLE_SINCE:CHANGELOG.md" 2>/dev/null || true)
  new=$(git -C "$MASTER_ROOT" show "HEAD:CHANGELOG.md" 2>/dev/null || true)
  for d in $(section_dates <<<"$new"); do
    [ "$(section_block "$d" <<<"$new")" = "$(section_block "$d" <<<"$old")" ] || echo "$d"
  done
}

# --- one project's stamp: SINCE is what it says, USABLE_SINCE only if this master has that commit ---
load_project() {
  PROJECT=$(cd "$1" 2>/dev/null && pwd) || { echo "✖ not a readable directory: $1"; return 1; }
  STAMP="$PROJECT/.workflow-sync"
  SINCE=""; USABLE_SINCE=""
  [ -f "$STAMP" ] && SINCE=$(grep -oE 'MASTER_COMMIT=[0-9a-f]+' "$STAMP" 2>/dev/null | head -1 | cut -d= -f2 || echo "")
  if [ -n "$SINCE" ] && [ -n "$MASTER_HEAD" ] && git -C "$MASTER_ROOT" cat-file -e "${SINCE}^{commit}" 2>/dev/null; then
    USABLE_SINCE="$SINCE"
  fi
}

# Is an existing UPGRADE_WORKORDER.md safe to replace? Decided by the project's state, never by
# the workorder's age:
#   untouched   — nothing changed since it was written but what the script itself wrote: replace
#                 it with the cumulative one, which is also smaller than two in sequence (a change
#                 later reversed cancels out);
#   in_progress — any other uncommitted change, or a commit made after it was written: leave it,
#                 because half its changes are applied and a new workorder would repeat them.
# A project whose state cannot be read counts as in progress: skipping one is safe, overwriting a
# half-run one is not. --no-optional-locks keeps git from refreshing the index, so --status
# really writes nothing.
# The first run itself leaves changes (the mechanical apply), and those are not progress:
# only_ours reads one path per line and accepts the workorder, a WORKFLOW.md.upgrade still
# byte-identical to the one the script wrote (one whose conflicts the user resolved is the upgrade
# under way), and a file under the mechanical dirs that `ours` recognises. Anything else — a
# persona doc, WORKFLOW.md, an adapter edited afterwards, a path it cannot read — is progress.
only_ours() {
  local f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in
      UPGRADE_WORKORDER.md) ;;
      WORKFLOW.md.upgrade) upgrade_is_ours || return 1 ;;
      adapters/*|.githooks/*) [ -f "$PROJECT/$f" ] && ours "$f" || return 1 ;;
      *) return 1 ;;
    esac
  done
  return 0
}

workorder_state() {
  local p=$1 wo="$1/UPGRADE_WORKORDER.md" changes written last
  [ -f "$wo" ] || { echo absent; return; }
  git -C "$p" rev-parse --git-dir >/dev/null 2>&1 || { echo in_progress; return; }
  PREV_WO=$(prev_workorder_commit)
  # Porcelain "XY path"; a rename ("old -> new") or a quoted path is never ours.
  changes=$(git -C "$p" --no-optional-locks status --porcelain --untracked-files=all 2>/dev/null || echo '?? <unreadable>')
  printf '%s\n' "$changes" | sed -E 's/^.. //; s/^.* -> .*$/<rename>/' | only_ours || { echo in_progress; return; }
  written=$(stat -c %Y "$wo" 2>/dev/null || stat -f %m "$wo")
  last=$(git -C "$p" log -1 --format=%ct 2>/dev/null || echo 0)
  [ "${last:-0}" -le "$written" ] || { echo in_progress; return; }
  echo untouched
}

# Every workorder opens with where it runs. An upgrade touches every side, and a side's agent may
# not write another side's files, so a side session would stop at the scope walls halfway through.
root_header() {
  echo "> **Run this from the project root**, in a session opened there — never from a side's folder."
  echo "> An upgrade touches every side, and a side's agent may not edit another side's files. A session"
  echo "> opened in a side that finds this file reports it and stops."
}

# The guard, before any write. Prints why it stopped; returns 3 so --all can count it.
guard_workorder() {
  REPLACED=""
  case "$(workorder_state "$PROJECT")" in
    in_progress)
      if [ "$FORCE" != 1 ]; then
        echo "⏸ $(basename "$PROJECT"): upgrade in progress — UPGRADE_WORKORDER.md is there and the project has"
        echo "  changed since it was written. Finish it (or delete it), then re-run; --force replaces it."
        return 3
      fi
      REPLACED=" (replaced an in-progress workorder: --force)" ;;
    untouched) REPLACED=" (replaced an untouched workorder with the cumulative one)" ;;
  esac
  return 0
}

# ---- the mechanical part of an upgrade ----------------------------------------------------
# Most of a workorder needs no judgement. Adapters and hooks are meant to be identical in every
# project, so the script replaces one only when the project's copy is still exactly the template
# at the stamp (ignoring a STARTER banner the project stripped, which is all scaffold changes); a
# copy the project edited is left alone and listed. The spine has no placeholders and merges
# mostly clean, so it is merged, but only into WORKFLOW.md.upgrade: not a .md, so no scanner or
# emitter reads it, and conflict markers never sit in the file every session reads at start-up.
# Persona and root docs stay the agent's: there a clean merge can be wrong with no signal.
# Nothing is deleted and nothing is committed.
MECH_DIRS="template/adapters template/.githooks"
strip_banner() { sed '/^> ⚠️ STARTER/d'; }
tpl_at() { git -C "$MASTER_ROOT" show "$1:template/$2" 2>/dev/null; }
same_as_tpl() {   # rel commit → 0 if the project's copy is the template at that commit, banner aside
  [ -n "$2" ] && cmp -s <(strip_banner < "$PROJECT/$1") <(tpl_at "$2" "$1" | strip_banner)
}
# The commit the waiting workorder was written from (its "_Master: … @ `<sha>`_" line), if this
# master has it. A re-run (--force) finds that run's mechanical output in the project: a copy equal
# to the template there, or at HEAD, is the script's own and is replaced, never listed as the
# project's edit.
prev_workorder_commit() {
  local sha
  sha=$(grep -m1 -oE '^_Master: .* @ `[0-9a-f]{7,40}`' "$PROJECT/UPGRADE_WORKORDER.md" 2>/dev/null | grep -oE '[0-9a-f]{7,40}`$' | tr -d '`') || true
  [ -n "$sha" ] && git -C "$MASTER_ROOT" cat-file -e "${sha}^{commit}" 2>/dev/null && printf '%s' "$sha"
  return 0
}
ours() {   # rel → 0 if the project's copy is one this script wrote or would write
  same_as_tpl "$1" "$USABLE_SINCE" || same_as_tpl "$1" "$PREV_WO" || same_as_tpl "$1" HEAD
}
# The spine merge: this project's WORKFLOW.md against the template at the stamp and at $1, into
# the file $2. Returns merge-file's status: the number of conflicts, or >127 when it could not run.
spine_merge() {
  local base theirs rc=0
  base=$(mktemp); theirs=$(mktemp)
  tpl_at "$USABLE_SINCE" WORKFLOW.md > "$base" || true; tpl_at "$1" WORKFLOW.md > "$theirs" || true
  git merge-file -p -L "this project" -L "template at the last sync" -L "template now" \
    "$PROJECT/WORKFLOW.md" "$base" "$theirs" > "$2" 2>/dev/null || rc=$?
  rm -f "$base" "$theirs"
  return "$rc"
}
# Is WORKFLOW.md.upgrade the one the run that wrote the waiting workorder wrote, byte for byte?
# Recomputed, not remembered: the same merge from the same inputs. Anything else — the user
# resolved a conflict, that commit is gone, WORKFLOW.md changed, the merge cannot run — is not the
# script's, so it is never overwritten, deleted, or counted as untouched.
upgrade_is_ours() {
  local tmp rc=0
  [ -n "$PREV_WO" ] && [ -n "$USABLE_SINCE" ] && [ -f "$PROJECT/WORKFLOW.md" ] || return 1
  tmp=$(mktemp)
  spine_merge "$PREV_WO" "$tmp" || rc=$?
  if [ "$rc" -le 127 ] && cmp -s "$tmp" "$PROJECT/WORKFLOW.md.upgrade"; then rc=0; else rc=1; fi
  rm -f "$tmp"; return "$rc"
}
apply_mechanical() {   # → APPLIED, LEFT (lines), HANDLED (rels whose diff the workorder omits)
  local st path rel dst tmp
  PREV_WO=$(prev_workorder_commit)
  while IFS=$'\t' read -r st path; do
    [ -n "$path" ] || continue
    rel=${path#template/}; dst="$PROJECT/$rel"
    # The payload's own tests stay in the workflow repo, as in scaffold: never copied, never listed.
    case "$rel" in *.test.sh) HANDLED+=("$rel"); continue ;; esac
    case "$st" in
      A)
        if [ -e "$dst" ] && ! ours "$rel"; then LEFT+="- \`$rel\` — new in the template, but this project already has a file there: compare by hand"$'\n'; continue; fi
        mkdir -p "$(dirname "$dst")"
        # Scaffold's banner rule (bin/scaffold.sh → process_file): a file with no placeholders
        # arrives without its STARTER banner, so a copied one looks like a scaffolded one.
        # A here-string, never `| grep -q`: grep quitting at an early match cuts git show off, and
        # under pipefail a large file's placeholder then reads as absent.
        if grep -q '{{' <<<"$(tpl_at HEAD "$rel")"; then tpl_at HEAD "$rel" > "$dst"; else tpl_at HEAD "$rel" | strip_banner > "$dst"; fi
        [[ $(git -C "$MASTER_ROOT" ls-tree HEAD -- "$path") == 100755* ]] && chmod +x "$dst"
        APPLIED+="- \`$rel\` (new)"$'\n'; HANDLED+=("$rel") ;;
      M)
        if [ ! -e "$dst" ]; then LEFT+="- \`$rel\` — changed in the template; this project has no copy"$'\n'
        elif ours "$rel"; then
          tmp=$(mktemp)
          if grep -q '^> ⚠️ STARTER' "$dst"; then tpl_at HEAD "$rel" > "$tmp"; else tpl_at HEAD "$rel" | strip_banner > "$tmp"; fi
          cat "$tmp" > "$dst"; rm -f "$tmp"     # written in place, so the file keeps its mode
          APPLIED+="- \`$rel\`"$'\n'; HANDLED+=("$rel")
        else LEFT+="- \`$rel\` — changed in the template **and edited in this project**: merge by hand (its diff is below)"$'\n'
        fi ;;
      D)
        [ -e "$dst" ] && LEFT+="- \`$rel\` — deleted from the template. Delete it here unless something of this project's uses it"$'\n' ;;
    esac
  done < <(git -C "$MASTER_ROOT" diff --name-status --no-renames "$USABLE_SINCE..HEAD" -- $MECH_DIRS)
}
prepare_spine() {   # → SPINE_CONFLICTS ("" = the spine did not change), HANDLED
  local tmp rc=0
  SPINE_CONFLICTS=""
  git -C "$MASTER_ROOT" diff --quiet "$USABLE_SINCE..HEAD" -- template/WORKFLOW.md && return 0
  if [ ! -f "$PROJECT/WORKFLOW.md" ]; then LEFT+="- \`WORKFLOW.md\` — the spine changed, and this project has none at its root"$'\n'; return 0; fi
  # A WORKFLOW.md.upgrade that is not the script's own holds the user's work: left exactly as it is,
  # even under --force, and the spine's diff stays in the workorder for a hand-merge.
  if [ -e "$PROJECT/WORKFLOW.md.upgrade" ] && ! upgrade_is_ours; then
    LEFT+="- \`WORKFLOW.md.upgrade\` — holds this project's edits (a resolution under way), so the script did not rewrite it: finish it into \`WORKFLOW.md\` and delete it, then apply the spine's diff below by hand, or re-run"$'\n'
    return 0
  fi
  # Merged into a temporary file first: a merge that cannot run never touches the project.
  tmp=$(mktemp)
  spine_merge HEAD "$tmp" || rc=$?
  # merge-file exits with the number of conflicts, or a negative status (seen as >127) on error.
  if [ "$rc" -gt 127 ]; then rm -f "$tmp"; LEFT+="- \`WORKFLOW.md\` — the merge could not run: apply its diff by hand"$'\n'; return 0; fi
  cat "$tmp" > "$PROJECT/WORKFLOW.md.upgrade"; rm -f "$tmp"
  SPINE_CONFLICTS=$rc; HANDLED+=("WORKFLOW.md")
}

# One project → 0 wrote a workorder · 2 nothing to apply · 3 skipped (upgrade in progress) · 1 error.
# A subshell, so each `exit` ends this project only, and --all moves on to the next. Call it as
# `set +e; apply_one …; rc=$?; set -e`, never `apply_one … || rc=$?`: bash ignores `set -e` inside
# anything on the left of `||`, so a failing step would carry on (an empty PROJECT would then
# "write" a workorder to /). The `set -e` below then holds for the whole body.
apply_one() (
  set -e
  load_project "$1" || exit 1
  [ "$PROJECT" = "$MASTER_ROOT" ] && { echo "project dir must differ from the master"; exit 1; }
# ======================= INCREMENTAL MODE =======================
if [ -n "$USABLE_SINCE" ]; then
  if [ "$USABLE_SINCE" = "$MASTER_HEAD" ]; then
    echo "✔ $(basename "$PROJECT") is already synced to master HEAD (${MASTER_HEAD:0:12}). Nothing to apply."
    exit 2
  fi
  tdiff=$(git -C "$MASTER_ROOT" diff "$USABLE_SINCE..HEAD" -- template/ 2>/dev/null || true)
  if [ -z "$tdiff" ]; then
    echo "✔ no template/ changes between ${USABLE_SINCE:0:12} and HEAD — nothing to apply."
    echo "  (Bumping the stamp so future runs stay incremental.)"
    { echo "MASTER_COMMIT=$MASTER_HEAD"; } > "$STAMP"
    exit 2
  fi
  new_sections=$(new_sections_since)
  guard_workorder || exit 3
  wo="$PROJECT/UPGRADE_WORKORDER.md"
  APPLIED=""; LEFT=""; HANDLED=()
  apply_mechanical
  prepare_spine
  # The workorder embeds the diff only for what the script did not handle.
  excl=(); for r in ${HANDLED[@]+"${HANDLED[@]}"}; do excl+=(":(exclude)template/$r"); done
  tdiff=$(git -C "$MASTER_ROOT" diff "$USABLE_SINCE..HEAD" -- template/ ${excl[@]+"${excl[@]}"} 2>/dev/null || true)
  {
    echo "# UPGRADE WORKORDER — apply master workflow updates (incremental)"
    echo; root_header
    echo; echo "_Master: \`$MASTER_ROOT\` @ \`${MASTER_HEAD}\`_  ·  _Project last synced: \`${USABLE_SINCE}\`_"
    echo
    echo "The master template changed since this project last synced. Below is the **intent**"
    echo "(changelog sections) followed by the **ground-truth \`template/\` diff**. Apply each change"
    echo "to *this project's real, filled docs* — not by copying template text verbatim."
    echo
    echo "## Agent instructions"
    echo "0. **Plan first (spine):** publish a short apply plan (which changes / diff hunks, which project files, deliberate skips), then **stop and wait for explicit approval**. Do **not** edit docs until the plan is approved. Canonical: \`WORKFLOW.md\` → Workflow sync workorders."
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
    echo "## Already applied by the script"
    if [ -n "$APPLIED" ]; then
      echo "These matched the template at this project's last sync, so the script replaced them with its current"
      echo "version, or copied them where they are new. **Nothing is committed.** Show them at the plan step:"
      echo "\`git diff\` and \`git status\` here."
      echo
      printf '%s' "$APPLIED"
    else
      echo "_Nothing: no adapter or hook both changed and still matched the template at the last sync._"
    fi
    echo
    if [ -n "$SPINE_CONFLICTS" ]; then
      echo "## Spine: \`WORKFLOW.md.upgrade\` — $SPINE_CONFLICTS conflict region$([ "$SPINE_CONFLICTS" = 1 ] || echo s)"
      echo "The script merged the template's spine changes into this project's \`WORKFLOW.md\` and wrote the result"
      echo "to \`WORKFLOW.md.upgrade\`. **\`WORKFLOW.md\` itself is unchanged.** Resolve each \`<<<<<<<\` … \`>>>>>>>\` region"
      echo "(this project's text first, the template's last), read the clean hunks once, then replace \`WORKFLOW.md\` with"
      echo "it and delete \`WORKFLOW.md.upgrade\`. Re-emit afterwards (below)."
      echo
    fi
    if [ -n "$LEFT" ]; then
      echo "## Left for you — the script did not touch these"
      printf '%s' "$LEFT"
      echo
    fi
    echo "## After the edits: re-emit"
    echo "\`bash adapters/agents/emit-agents.sh --force\` · \`bash adapters/index/emit-index.sh --target .\`"
    echo "— the generated copies (\`AGENTS.md\`, the file indexes) follow their sources."
    echo
    echo "## Changes to apply (intent)"
    if [ -n "$new_sections" ]; then
      echo "_The master's \`CHANGELOG.md\` sections added or changed since this project last synced._"
      for d in $new_sections; do echo; section_block "$d" < <(git -C "$MASTER_ROOT" show "HEAD:CHANGELOG.md"); done
      echo
    else
      echo "_(No \`CHANGELOG.md\` section added or changed in range — rely on the diff below.)_"
      echo
    fi
    echo "## Ground-truth \`template/\` diff (${USABLE_SINCE:0:12}..${MASTER_HEAD:0:12}) — files the script did not handle"
    echo '```diff'
    echo "$tdiff"
    echo '```'
  } > "$wo"
  echo "✔ wrote ${wo#"$PROJECT"/} into $(basename "$PROJECT")  (incremental)$REPLACED"
  echo "  next: open your agent at THAT PROJECT'S ROOT and say \"execute UPGRADE_WORKORDER.md\""
  echo "        (agent must plan first → wait for approval → then edit; see WORKFLOW.md → Workflow sync workorders)"
  exit 0
fi

# ======================= CATALOG MODE =======================
echo "▶ no usable \`.workflow-sync\` stamp in $(basename "$PROJECT") — catalog mode (all MOC entries as candidates)."
mocs=$(grep -oE 'MOC-[0-9]{8}-[0-9]+' "$MCL" | awk '!s[$0]++' || true)
if [ -z "$mocs" ]; then
  echo "✔ the master CHANGELOG has no MOC-<date>-NN entries to apply."
  echo "  (Master-originated changes need MOC ids to be trackable downstream — add them, then re-run.)"
  exit 2
fi
guard_workorder || exit 3
wo="$PROJECT/UPGRADE_WORKORDER.md"
{
  echo "# UPGRADE WORKORDER — apply master workflow updates (catalog)"
  echo; root_header
  echo; echo "_Master: \`$MASTER_ROOT\`${MASTER_HEAD:+ @ \`$MASTER_HEAD\`}_"
  echo
  echo "This project has no \`.workflow-sync\` stamp, so there's no baseline to diff from. Below is the"
  echo "**full catalog** of master-originated changes. Some may already be present — check each before applying."
  echo
  echo "## Agent instructions"
  echo "0. **Plan first (spine):** publish a short apply plan (which changes are already present vs to apply, which files to copy/edit, deliberate skips), then **stop and wait for explicit approval**. Do **not** edit docs until the plan is approved. Canonical: \`WORKFLOW.md\` → Workflow sync workorders. \"Execute\" starts this step — it does **not** authorize silent edits."
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
    case "$(basename "$rel")" in BOOTSTRAP.md|ADOPT.md|STACK.md|WORKORDER.md|*.test.sh) continue;; esac
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
echo "✔ wrote ${wo#"$PROJECT"/} into $(basename "$PROJECT")  ($(printf '%s\n' $mocs | wc -l | tr -d ' ') MOC candidate(s), catalog)$REPLACED"
echo "  next: open your agent at THAT PROJECT'S ROOT and say \"execute UPGRADE_WORKORDER.md\""
echo "        (agent must plan first → wait for approval → then edit; see WORKFLOW.md → Workflow sync workorders)"
exit 0
)

# --- every project under ROOT, found by its stamp, never from a list ---
find_projects() {
  find "$ROOT" -maxdepth 4 -name .workflow-sync -type f -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null \
    | while IFS= read -r f; do
        d=$(dirname "$f")
        case "$d" in "$MASTER_ROOT"|"$MASTER_ROOT"/*) continue ;; esac
        echo "$d"
      done | sort
}

plural() { if [ "$1" = 1 ]; then echo "$1 $2"; else echo "$1 $3"; fi; }

# One line per project for --status. Reads only: no stamp bump, no workorder.
status_line() (
  load_project "$1" || exit 1
  local name=${PROJECT#"$ROOT"/} detail pend t n
  case "$(workorder_state "$PROJECT")" in
    absent) pend="no workorder" ;;
    untouched) pend="workorder pending (untouched)" ;;
    *) pend="upgrade in progress" ;;
  esac
  if [ -z "$USABLE_SINCE" ]; then
    # What a run would do: catalog mode, which lists only MOC-<date>-NN entries (--all counts a
    # project with none to list as up to date).
    if [ -z "$SINCE" ]; then t="stamp has no commit"; else t="stamped from another workflow repo"; fi
    if grep -qE 'MOC-[0-9]{8}-[0-9]+' "$MCL"; then detail="$t — catalog mode"
    else detail="$t — catalog mode lists nothing here"; fi
  elif [ "$USABLE_SINCE" = "$MASTER_HEAD" ]; then
    detail="up to date"
  else
    t=$(git -C "$MASTER_ROOT" rev-list --count "$USABLE_SINCE..HEAD" -- template/)
    n=$(new_sections_since | grep -c . || true)
    detail="synced $(git -C "$MASTER_ROOT" log -1 --format=%cs "$USABLE_SINCE") · $(plural "$t" "template commit" "template commits"), $(plural "$n" "changelog section" "changelog sections") behind"
  fi
  printf '  %-26s %s · %s\n' "$name" "$detail" "$pend"
)

case "$MODE" in
  one)
    set +e; apply_one "${ARGS[0]}"; rc=$?; set -e
    case "$rc" in 0|2) exit 0 ;; *) exit 1 ;; esac ;;
  status|all)
    mapfile -t projects < <(find_projects)
    if [ ${#projects[@]} -eq 0 ]; then echo "no projects under $ROOT (none has a .workflow-sync stamp)"; exit 0; fi
    if [ "$MODE" = status ]; then
      echo "Projects under $ROOT — master @ ${MASTER_HEAD:0:12}:"
      # Read-only, so one unreadable project is reported and the listing goes on.
      for p in "${projects[@]}"; do status_line "$p" || echo "  ${p#"$ROOT"/}: could not be read"; done
      exit 0
    fi
    wrote=0; current=0; held=0; failed=0
    for p in "${projects[@]}"; do
      set +e; apply_one "$p"; rc=$?; set -e
      case "$rc" in 0) wrote=$((wrote+1)) ;; 2) current=$((current+1)) ;; 3) held=$((held+1)) ;; *) failed=$((failed+1)) ;; esac
    done
    echo
    echo "== ${#projects[@]} project(s): $wrote workorder(s) written, $current up to date, $held upgrade(s) in progress left alone, $failed failed"
    echo "   Each workorder runs from its project's root: open the agent there and say \"execute UPGRADE_WORKORDER.md\"."
    [ "$failed" -eq 0 ] ;;
esac
