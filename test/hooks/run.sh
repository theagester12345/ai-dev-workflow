#!/usr/bin/env bash
# test/hooks/run.sh — the pre-commit hook's secret guard, each allowed case paired with its near miss.
# Repo-only; never copied into a project. Run: bash test/hooks/run.sh
#
# A guard that goes quiet on a real secret passes every test of what it allows, so every allowed
# case here has a twin that looks almost the same and must still be blocked. Secret-shaped values
# are built at run time and never committed: this repo's own guard would block them.
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HOOK="$ROOT/template/.githooks/pre-commit"
pass=0; fail=0
ok(){ echo "  ✔ $1"; pass=$((pass+1)); }
ko(){ echo "  ✖ $1"; fail=$((fail+1)); }

SBX=$(mktemp -d); trap 'rm -rf "$SBX"' EXIT
R="$SBX/r"; mkdir -p "$R/.githooks"
cp "$HOOK" "$R/.githooks/pre-commit"; chmod +x "$R/.githooks/pre-commit"
# The hook reads its secret patterns from the one file the adoption sweep reads too…
# Read through the one reader the sweep uses too (patterns.sh).
mkdir -p "$R/adapters/secret-sweep"; cp "$ROOT/template/adapters/secret-sweep/patterns.txt" "$R/adapters/secret-sweep/" 2>/dev/null || true
cp "$ROOT/template/adapters/secret-sweep/patterns.sh" "$R/adapters/secret-sweep/" 2>/dev/null || true
# …and what counts as a real env file, from the one definition the sweep reads too.
cp "$ROOT/template/adapters/secret-sweep/env-files.txt" "$ROOT/template/adapters/secret-sweep/env-files.sh" "$R/adapters/secret-sweep/" 2>/dev/null || true
G=(git -C "$R" -c user.name=t -c user.email=t@t -c core.hooksPath=.githooks)
"${G[@]}" init -q; echo base > "$R/README"; printf 'X=\n' > "$R/.env.example"
"${G[@]}" add -A; "${G[@]}" commit -qm init --no-verify

# $1 = allowed|blocked, $2 = description; the change is staged by the caller. The tree is reset after.
expect() {
  # Nothing staged would fail the commit too and read as "blocked": refuse to judge it.
  if "${G[@]}" diff --cached --quiet; then ko "harness: nothing staged for: $2"; return; fi
  # PRE (a command prefix, e.g. env VAR=…) and GX (git options) set up the user's own git settings.
  if ${PRE[@]+"${PRE[@]}"} "${G[@]}" ${GX[@]+"${GX[@]}"} commit -qm "$2" >/dev/null 2>&1; then got=allowed; else got=blocked; fi
  [ "$got" = "$1" ] && ok "$1: $2" || ko "expected $1, got $got: $2"
  "${G[@]}" reset -q --hard HEAD; "${G[@]}" clean -qfd
}
stage() { mkdir -p "$(dirname "$R/$1")"; printf '%s # %s\n' "$2" "$RANDOM" > "$R/$1"; "${G[@]}" add -- "$1"; }
rep() { printf "%${2}s" "" | tr ' ' "$1"; }  # $1 repeated $2 times

echo "▶ env files: a template is allowed, a real env file is not"
for t in .env.example .env.sample .env.template .env.dist config/.env.example; do
  stage "$t" "X="; expect allowed "a template, $t"
done
for f in .env .env.local .env.production config/.env .env.example.local; do
  stage "$f" "X=1"; expect blocked "a real env file, $f"
done
"${G[@]}" mv .env.example .env; expect blocked "a template renamed to .env"

echo "▶ one definition of a real env file, shared with the sweep"
stage .env.tmpl "X="; expect blocked "a suffix the shared file does not name (.env.tmpl) is a real env file"
sed -i 's/(example|sample|template|dist)/(example|sample|template|dist|tmpl)/' "$R/adapters/secret-sweep/env-files.txt" 2>/dev/null
stage .env.tmpl "X="; expect allowed "the shared file gains the suffix tmpl: the hook follows it"
# A malformed definition must never read as a rule that matches nothing.
EF="$R/adapters/secret-sweep/env-files.txt"
sed -i '/^(^|\/)\\.env/s/$/\r/' "$EF" 2>/dev/null; stage .env "X=1"; expect blocked "a stray CR on the env-file rule never disables the guard"
printf '# template-suffix\n\\.(example)$\n# env-file\n' > "$EF"; stage .env "X=1"; expect blocked "a rule comment on the last line never becomes the rule"
printf '# env-file\n# note\n(^|/)\\.env$\n# template-suffix\n\\.(example)$\n' > "$EF"; stage .env "X=1"; expect blocked "a comment after the rule comment never becomes the rule"
sed -i 's/(example|sample|template|dist)/(example|sample|template|dist|production)/' "$EF"; stage .env.production "X=1"; expect blocked "a template rule that would swallow .env.production is not trusted"
rm -f "$R/adapters/secret-sweep/env-files.sh"; stage .env.example "X="; expect blocked "without the shared reader, every .env* file is refused (fails closed)"

echo "▶ secret patterns: a look-alike is allowed, the real shape is not"
pairs=(
  "AKIA$(rep A 15)|AKIA$(rep A 16)|an AWS access key id (16 after AKIA)"
  "ghp_$(rep a 19)|ghp_$(rep a 20)|a GitHub token (20 after ghp_)"
  "sk-$(rep a 19)|sk-$(rep a 20)|an API key (20 after sk-)"
  "xoxb-$(rep 1 9)|xoxb-$(rep 1 10)|a Slack token (10 after xoxb-)"
  "-----BEGIN PUBLIC KEY-----|-----BEGIN OPENSSH PRIV""ATE KEY-----|a private key header"
)
for p in "${pairs[@]}"; do
  IFS='|' read -r near real what <<<"$p"
  stage notes.txt "value: $near"; expect allowed "the look-alike of $what"
  stage notes.txt "value: $real"; expect blocked "$what"
done

echo "▶ removing a secret is allowed; keeping or adding one is not"
key="AKIA$(rep A 16)"
# Each case starts from its own committed file holding the secret, so one case's commit cannot
# change what the next one tests.
n=0
seed() { n=$((n+1)); f="leak$n.txt"; printf 'id: %s\nother: 1\n' "$key" > "$R/$f"; "${G[@]}" add "$f"; "${G[@]}" commit -qm "seed $f" --no-verify; }
seed; "${G[@]}" rm -q "$f"; expect allowed "deleting a file that holds a secret"
seed; printf 'id: %s\nother: 2\n' "$key" > "$R/$f"; "${G[@]}" add "$f"
# git prints the line before a hunk in its @@ header, so a committed secret just above an edit
# appears in the diff without being added; only an added line counts.
expect allowed "editing another line of a file whose secret is already committed"
seed; printf 'id: %s # moved\nother: 1\n' "$key" > "$R/$f"; "${G[@]}" add "$f"
expect blocked "changing the line that holds the secret (it is added again)"
seed; "${G[@]}" mv "$f" "moved$n.txt" && printf 'second: %s\n' "AKIA$(rep B 16)" >> "$R/moved$n.txt" && "${G[@]}" add "moved$n.txt" \
  || ko "harness: the rename did not happen"
expect blocked "adding a secret in a file the commit renames"
# A rename re-adds nothing, so the secret already committed in the file does not count — even
# where the user's git config turns rename detection off.
G0=("${G[@]}"); G=(git -C "$R" -c user.name=t -c user.email=t@t -c core.hooksPath=.githooks -c diff.renames=false)
seed; "${G[@]}" mv "$f" "renamed$n.txt" || ko "harness: the rename did not happen"
expect allowed "renaming a file whose secret is already committed (rename detection off in config)"
G=("${G0[@]}")

echo "▶ an unusable patterns file never lets a key through: the commit is refused"
# Each case edits the working-tree copy the hook reads, unstaged; expect's reset restores it.
PF="$R/adapters/secret-sweep/patterns.txt"; KEY="AKIA$(rep D 16)"
sed -i 's/$/\r/' "$PF"; stage notes.txt "value: $KEY"; expect blocked "a CRLF patterns.txt (a Windows checkout) still catches the key"
printf '[unclosed\n' >> "$PF"; stage notes.txt "value: $KEY"; expect blocked "one malformed pattern (grep exits 2) never reads as no match"
printf '# only a comment\n\n' > "$PF"; stage notes.txt "value: $KEY"; expect blocked "an empty patterns.txt never reads as no match"
printf '# slack-token\nxox[baprs]-[0-9A-Za-z-]{10,}\n' > "$PF"; stage notes.txt "harmless"; expect blocked "a set that misses the known AWS sample is not trusted, even with no key staged"
printf '[unclosed\n' >> "$PF"; stage notes.txt "harmless"
out=$("${G[@]}" commit -qm "malformed" 2>&1); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'patterns.txt' && printf '%s' "$out" | grep -q -- '--no-verify' \
  && ok "the refusal names patterns.txt and the --no-verify escape" || ko "refusal message: rc=$rc $out"
"${G[@]}" reset -q --hard HEAD; "${G[@]}" clean -qfd
# A rule line's surroundings never switch it off: a tab in its comment, a stray space, a byte-order mark.
GH="ghp_$(rep a 30)"
sed -i 's/^# github-token$/# github\ttoken/' "$PF"; stage notes.txt "tok: $GH"; expect blocked "a tab in a rule's comment line never turns that rule off"
sed -i 's/^\(gh\[pousr\]_.*\)$/\1 /' "$PF"; stage notes.txt "tok=${GH};"; expect blocked "a trailing space on a rule never turns it off"
sed -i '1s/^/\xEF\xBB\xBF/' "$PF"; stage notes.txt "tok: $GH"; expect blocked "a byte-order mark at the start of patterns.txt is harmless"
printf '# anything\n.\n' >> "$PF"; stage notes.txt "harmless"
out=$("${G[@]}" commit -qm "match-all" 2>&1); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'patterns.txt' && ok "a rule that matches ordinary text is refused as unusable, naming the file" || ko "match-all rule: rc=$rc $out"
"${G[@]}" reset -q --hard HEAD; "${G[@]}" clean -qfd
# An added line whose content starts with "++" reads "+++" in the diff, like a header: still checked.
stage g.c "++count; key = \"AKIA$(rep E 16)\";"; expect blocked "an added line starting with ++ is still checked for a key"

echo "▶ the user's diff settings and git's quoted paths never hide a key or an env file"
KEY2="AKIA$(rep F 16)"; PRE=(); GX=()
GX=(-c diff.external=/bin/true); stage notes.txt "value: $KEY2"; expect blocked "an external diff tool (diff.external) never blinds the guard"; GX=()
PRE=(env GIT_EXTERNAL_DIFF=/bin/true); stage notes.txt "value: $KEY2"; expect blocked "an external diff tool (GIT_EXTERNAL_DIFF) never blinds the guard"; PRE=()
# A textconv driver shows a converted file in diffs; one that prints nothing would hide every line.
printf '*.txt diff=hide\n' > "$R/.git/info/attributes"
GX=(-c diff.hide.textconv=true); stage notes.txt "value: $KEY2"; expect blocked "a textconv driver never hides a staged key"; GX=()
# A -diff (binary) attribute, common on lock files, makes git print "Binary files differ" instead of lines.
printf '*.lock -diff\n' > "$R/.git/info/attributes"
stage x.lock "value: $KEY2"; expect blocked "a -diff attribute never hides a staged key"
rm -f "$R/.git/info/attributes"
stage "configuración/notes.txt" "value: $KEY2"; expect blocked "a key in a file under a non-ASCII path"
stage "$(printf '.env.example\nfoo')" "X=1"; expect blocked "a name holding a newline is refused (it would split into a template and another name)"
stage "configuración/.env.example" "X="; expect allowed "a template under a non-ASCII path"
stage "configuración/.env" "X=1"; expect blocked "a real env file under a non-ASCII path (git quotes it)"
stage 'we"ird/.env' "X=1"; expect blocked "a real env file under a path git quotes even with quotePath off"

echo "▶ a missing patterns file or reader refuses the commit, never skips the check"
pbase=$("${G[@]}" rev-parse HEAD)
"${G[@]}" rm -q adapters/secret-sweep/patterns.txt; "${G[@]}" commit -qm "patterns removed" --no-verify
stage notes.txt "value: AKIA$(rep C 16)"
out=$("${G[@]}" commit -qm "no patterns" 2>&1); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'patterns.txt' && printf '%s' "$out" | grep -q -- '--no-verify' \
  && ok "without patterns.txt a staged key is refused, naming the file and the escape" || ko "missing patterns.txt: rc=$rc $out"
if [ "$rc" -eq 0 ]; then "${G[@]}" reset -q --hard HEAD~1; else "${G[@]}" reset -q --hard HEAD; fi; "${G[@]}" clean -qfd
[ ! -e "$R/adapters/secret-sweep/patterns.txt" ] || ko "harness: the patterns file came back"
stage notes.txt "harmless"; expect blocked "without patterns.txt any commit is refused (fails closed)"
stage .env "X=1"; expect blocked "without the patterns file, a real env file is still blocked"
"${G[@]}" checkout -q "$pbase" -- adapters/secret-sweep/patterns.txt; "${G[@]}" commit -qm "patterns back" --no-verify
rm -f "$R/adapters/secret-sweep/patterns.sh"; stage notes.txt "harmless"; expect blocked "without the shared reader (patterns.sh) the commit is refused"

echo "▶ a missing env-file definition is said, and the guard gets stricter, never off"
"${G[@]}" rm -q adapters/secret-sweep/env-files.txt 2>/dev/null; "${G[@]}" commit -qm "env rule removed" --no-verify 2>/dev/null
stage .env.example "X="
out=$("${G[@]}" commit -qm "a template, no rule" 2>&1); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'env-files.txt is missing or malformed' && ok "without the definition every .env* file is refused, templates included, and it says why" \
  || ko "missing env-files.txt: rc=$rc $out"
"${G[@]}" reset -q --hard HEAD; "${G[@]}" clean -qfd
stage .env "X=1"; expect blocked "without the definition, a real env file is still blocked"

echo "== $pass passed, $fail failed"
[ "$fail" -eq 0 ]
