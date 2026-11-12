#!/usr/bin/env bash
# secret-sweep.test.sh — the adoption sweep finds old credentials and never prints one.
# Run: bash adapters/secret-sweep/secret-sweep.test.sh   (a throwaway sandbox; touches nothing else)
#
# Every secret-shaped value is built at run time: committed, it would trip this repo's own guard.
# The one property that matters most is checked last, over every output: no fixture value appears.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
pass=0; fail=0
ok(){ echo "  ✔ $1"; pass=$((pass+1)); }
ko(){ echo "  ✖ $1"; fail=$((fail+1)); }
rep() { printf "%${2}s" "" | tr ' ' "$1"; }

SBX=$(mktemp -d); trap 'rm -rf "$SBX"' EXIT
R="$SBX/project"; mkdir -p "$R/adapters/secret-sweep" "$R/db"
cp "$HERE/secret-sweep.sh" "$HERE/patterns.txt" "$HERE/patterns-words.txt" "$HERE/env-files.txt" "$HERE/env-files.sh" "$R/adapters/secret-sweep/" 2>/dev/null
cp "$HERE/patterns.sh" "$R/adapters/secret-sweep/" 2>/dev/null
G=(git -C "$R" -c user.name=t -c user.email=t@t -c core.hooksPath=/dev/null)
"${G[@]}" init -q

AWS="AKIA$(rep Q 16)"                 # in a tracked file today
OLD="ghp_$(rep z 24)"                 # committed once, removed later: only history has it
WORD="Tr0ub4dor$(rep k 3)!9"          # a password written in words, in a comment
ENVV="sk-$(rep e 24)"                 # in a real env file: never read in the tree
ENVH="sk-$(rep h 24)"                 # in a real env file committed once
LOGV="xoxb-$(rep 7 14)"               # in a log the user names
DBPW="Pg$(rep w 8)42"                 # a password in a URL no rule matches, beside a matched token
COLON="ab:cd1234XYZ"                  # a value holding the separator: only its first two characters may show
ALL=("$AWS" "$OLD" "$WORD" "$ENVV" "$ENVH" "$LOGV" "$DBPW" "$COLON")

printf 'old: %s\n' "$OLD" > "$R/old.txt"
printf 'API=%s\n' "$ENVH" > "$R/.env.production"
printf 'API=\n' > "$R/.env.tmpl"
"${G[@]}" add -A; "${G[@]}" commit -qm "first"
"${G[@]}" rm -q old.txt .env.production; "${G[@]}" commit -qm "remove them"
printf 'key = "%s"\n' "$AWS" > "$R/config.py"
printf -- '-- seed the admin; the admin password is %s for now\n' "$WORD" > "$R/db/seed.sql"
printf 'password: <your-password>\nthe password is required\ntoken: ${API_TOKEN}\n' > "$R/README.md"
printf '# %s=abcdef1 DATABASE_URL=postgres://app:%s@db/app\n' token "$DBPW" > "$R/db/url.sh"
printf 'password=%s\n' "$COLON" > "$R/db/colon.cfg"
"${G[@]}" add -A; "${G[@]}" commit -qm "today"
printf 'API=%s\n' "$ENVV" > "$R/.env"
mkdir -p "$SBX/logs"; printf 'line one\nexport SLACK=%s\nline three\n' "$LOGV" > "$SBX/logs/history.log"

run() { (cd "$R" && bash adapters/secret-sweep/secret-sweep.sh "$@" 2>&1); }

echo "▶ the working tree"
out=$(run --tree); rc=$?
printf '%s\n' "$out" | grep -q '^tree  config.py:1  aws-access-key-id  AK…(len 20)$' \
  && ok "a key-shaped credential: location, rule, value masked to two characters and its length" || ko "tree key: $out"
printf '%s\n' "$out" | grep -q '^tree  db/seed.sql:1  password-in-words  Tr…(len 14)$' \
  && ok "a password in words: location, rule and the masked value, never its line" || ko "tree word: $out"
printf '%s\n' "$out" | grep -q '^tree  db/url.sh:1  password-in-words  ab…(len 7)$' \
  && ok "a token beside an unmatched credential: the find is reported" || ko "tree url line: $out"
printf '%s' "$out" | grep -qF -- "$DBPW" && ko "an unmatched DATABASE_URL password beside a matched token was printed: $out" \
  || ok "an unmatched credential on a find's line is never printed"
printf '%s\n' "$out" | grep -q '^tree  db/colon.cfg:1  password-in-words  ab…(len 12)$' \
  && ok "a value holding a colon is masked whole: its first two characters and its full length" || ko "tree colon: $out"
printf '%s' "$out" | grep -qE 'cd1|ab:c' && ko "part of a value past its first two characters was printed: $out" \
  || ok "nothing past the mask of password=ab:cd… is printed"
printf '%s\n' "$out" | grep -q '^tree  README.md' && ko "a placeholder, a word with no value, or a variable reference was reported: $out" \
  || ok "near misses: <your-password>, 'is required', \${API_TOKEN} are not reported"
printf '%s\n' "$out" | grep -q '\.env' && ko "the real env file was read in the tree: $out" || ok "a real env file in the tree is never read"
[ "$rc" -eq 1 ] && ok "exit 1 when something is found" || ko "exit $rc with finds"

echo "▶ the full history"
out=$(run --history)
printf '%s\n' "$out" | grep -qE '^history  [0-9a-f]{7,}  old.txt  github-token  gh…\(len 28\)$' \
  && ok "a credential removed since is still found in history, with its commit" || ko "history key: $out"
printf '%s\n' "$out" | grep -qE '^history  [0-9a-f]{7,}  \.env\.production  env file committed \(its values are not read\)$' \
  && ok "a real env file ever committed is named, its values not read" || ko "history env: $out"

echo "▶ a path the user names (shell history, a database client, agent logs): locations only"
out=$(run --path "$SBX/logs")
printf '%s\n' "$out" | grep -q "^path  $SBX/logs/history.log:2  slack-token$" \
  && ok "a log find gives its location and rule, nothing else" || ko "path: $out"
out=$(run --path "$SBX/nothing-here"); rc=$?
[ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'not found' && ok "a named path that does not exist is refused, not skipped" || ko "missing path: rc=$rc $out"

echo "▶ nothing found"
C="$SBX/clean"; mkdir -p "$C/adapters/secret-sweep"; cp "$R/adapters/secret-sweep/"* "$C/adapters/secret-sweep/"
git -C "$C" init -q; echo hello > "$C/a.txt"; git -C "$C" -c user.name=t -c user.email=t@t add -A
git -C "$C" -c user.name=t -c user.email=t@t -c core.hooksPath=/dev/null commit -qm c
out=$( (cd "$C" && bash adapters/secret-sweep/secret-sweep.sh) 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'nothing found' && ok "a clean project: exit 0, and it says so" || ko "clean: rc=$rc $out"

echo "▶ one definition of a real env file, shared with the hook"
out=$(run --history)
printf '%s\n' "$out" | grep -qE '^history  [0-9a-f]{7,}  \.env\.tmpl  env file committed' \
  && ok "a suffix the shared file does not name (.env.tmpl) is a real env file" || ko "near miss tmpl: $out"
sed -i 's/(example|sample|template|dist)/(example|sample|template|dist|tmpl)/' "$R/adapters/secret-sweep/env-files.txt" 2>/dev/null
out=$(run --history)
printf '%s\n' "$out" | grep -q '\.env\.tmpl  env file' && ko "the shared file gained tmpl, but the sweep still calls .env.tmpl a real env file: $out" \
  || ok "the shared file gains the suffix tmpl: the sweep follows it"
cp "$R/adapters/secret-sweep/env-files.txt" "$SBX/env-files.good" 2>/dev/null
sed -i '/^(^|\/)\\.env/s/$/\r/' "$R/adapters/secret-sweep/env-files.txt"
out=$(run --history); rc=$?
printf '%s\n' "$out" | grep -qE '^history  [0-9a-f]{7,}  \.env\.production  env file committed' \
  && ok "a stray CR on the env-file rule never turns it into a rule that matches nothing" || ko "CR rule: rc=$rc $out"
printf '# template-suffix\n\\.(example)$\n# env-file\n' > "$R/adapters/secret-sweep/env-files.txt"
out=$(run --history); rc=$?
[ "$rc" -eq 2 ] && ok "a rule comment on the last line is refused, never taken as the rule" || ko "comment-last: rc=$rc $out"
sed 's/(example|/(example|production|/' "$SBX/env-files.good" > "$R/adapters/secret-sweep/env-files.txt"
out=$(run --history); rc=$?
[ "$rc" -eq 2 ] && ok "a template rule that would swallow .env.production is refused" || ko "broad template rule: rc=$rc $out"
cp "$SBX/env-files.good" "$R/adapters/secret-sweep/env-files.txt" 2>/dev/null
mv "$R/adapters/secret-sweep/env-files.txt" "$SBX/env-files.saved" 2>/dev/null
out=$(run --history); rc=$?
[ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'env-files.txt' && ok "a missing env-file definition is refused, naming the file" || ko "missing env-files.txt: rc=$rc $out"
mv "$SBX/env-files.saved" "$R/adapters/secret-sweep/env-files.txt" 2>/dev/null

echo "▶ an unusable patterns file is refused, never read as nothing found"
U="$SBX/unusable"; mkdir -p "$U/adapters/secret-sweep"; cp "$R/adapters/secret-sweep/"* "$U/adapters/secret-sweep/"
git -C "$U" init -q; printf 'key = "%s"\n' "$AWS" > "$U/a.txt"; git -C "$U" -c user.name=t -c user.email=t@t add -A
git -C "$U" -c user.name=t -c user.email=t@t -c core.hooksPath=/dev/null commit -qm c
UP="$U/adapters/secret-sweep/patterns.txt"; cp "$UP" "$SBX/patterns.good"
runu() { (cd "$U" && bash adapters/secret-sweep/secret-sweep.sh --tree 2>&1); }
sed -i 's/$/\r/' "$UP"; out=$(runu); rc=$?
[ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q '^tree  a.txt:1  aws-access-key-id' \
  && ok "a CRLF patterns.txt is read through its carriage returns: the key is still found" || ko "CRLF patterns: rc=$rc $out"
cp "$SBX/patterns.good" "$UP"; printf '# broken\n[unclosed\n' >> "$UP"; out=$(runu); rc=$?
[ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'patterns.txt' && ! printf '%s' "$out" | grep -q 'nothing found' \
  && ok "a malformed pattern is refused (exit 2), naming the file" || ko "malformed patterns: rc=$rc $out"
printf '# only a comment\n' > "$UP"; out=$(runu); rc=$?
[ "$rc" -eq 2 ] && ok "an empty patterns.txt is refused (exit 2)" || ko "empty patterns: rc=$rc $out"
cp "$SBX/patterns.good" "$UP"; cp "$U/adapters/secret-sweep/patterns-words.txt" "$SBX/words.good"
printf '# broken\n(password\n' >> "$U/adapters/secret-sweep/patterns-words.txt"; out=$(runu); rc=$?
[ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'patterns-words.txt' && ok "a malformed words pattern is refused (exit 2), naming the file" || ko "malformed words: rc=$rc $out"
cp "$SBX/words.good" "$U/adapters/secret-sweep/patterns-words.txt"
# A rule line's surroundings never switch it off, here in the sweep (a false all-clear otherwise).
V="$SBX/variants"; mkdir -p "$V/adapters/secret-sweep"; cp "$SBX/patterns.good" "$V/adapters/secret-sweep/patterns.txt"
cp "$R/adapters/secret-sweep/patterns-words.txt" "$R/adapters/secret-sweep/patterns.sh" "$R/adapters/secret-sweep/env-files.txt" "$R/adapters/secret-sweep/env-files.sh" "$R/adapters/secret-sweep/secret-sweep.sh" "$V/adapters/secret-sweep/"
git -C "$V" init -q; printf 'tok: %s\n' "ghp_$(rep b 30)" > "$V/g.txt"; git -C "$V" -c user.name=t -c user.email=t@t add -A
git -C "$V" -c user.name=t -c user.email=t@t -c core.hooksPath=/dev/null commit -qm c
VP="$V/adapters/secret-sweep/patterns.txt"; runv() { (cd "$V" && bash adapters/secret-sweep/secret-sweep.sh --tree 2>&1); }
sed -i 's/^# github-token$/# github\ttoken/' "$VP"; out=$(runv); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'g.txt:1' && ok "a tab in a rule's comment never turns the rule off (the token is found)" || ko "tab comment: rc=$rc $out"
cp "$SBX/patterns.good" "$VP"; sed -i 's/^\(gh\[pousr\]_.*\)$/\1 /' "$VP"; out=$(runv); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'g.txt:1' && ok "a trailing space on a rule never turns it off" || ko "trailing space: rc=$rc $out"
cp "$SBX/patterns.good" "$VP"; printf '# anything\n.\n' >> "$VP"; out=$(runv); rc=$?
[ "$rc" -eq 2 ] && ok "a rule that matches ordinary text is refused (exit 2), never run over every line" || ko "match-all: rc=$rc $out"
cp "$SBX/patterns.good" "$VP"
rm -f "$U/adapters/secret-sweep/patterns.sh"; out=$(runu); rc=$?
[ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'patterns.sh' && ok "without the shared reader the sweep is refused, naming it" || ko "no reader: rc=$rc $out"

echo "▶ history is read the way git writes it: ++ lines, quoted paths, the user's diff settings"
H="$SBX/hist"; mkdir -p "$H/adapters/secret-sweep" "$H/configuración" "$H/we\"ird"
cp "$HERE/secret-sweep.sh" "$HERE/patterns.txt" "$HERE/patterns-words.txt" "$HERE/env-files.txt" "$HERE/env-files.sh" "$HERE/patterns.sh" "$H/adapters/secret-sweep/" 2>/dev/null
GH=(git -C "$H" -c user.name=t -c user.email=t@t -c core.hooksPath=/dev/null)
"${GH[@]}" init -q
PPK="AKIA$(rep P 16)"; PBK="ghp_$(rep p 24)"; NAK="AKIA$(rep N 16)"; TCK="AKIA$(rep T 16)"
printf '++ diff marker\nkey = %s\n' "$PPK" > "$H/pp.txt"
printf '++ b/LINECONTENT\ntok = %s\n' "$PBK" > "$H/pb.txt"
printf 'key = %s\n' "$NAK" > "$H/configuración/k.txt"
printf 'API=1\n' > "$H/configuración/.env"; printf 'API=1\n' > "$H/we\"ird/.env"
printf 'key = %s\n' "$TCK" > "$H/tc.dat"
SPK="AKIA$(rep S 16)"; SQK="AKIA$(rep U 16)"; BNK="AKIA$(rep B 16)"
mkdir -p "$H/plain dir" "$H/we\"ird dir"
printf 'key = %s\n' "$SPK" > "$H/plain dir/k.txt"; printf 'key = %s\n' "$SQK" > "$H/we\"ird dir/k.txt"
printf 'key = %s\n' "$BNK" > "$H/x.lock"
"${GH[@]}" add -A; "${GH[@]}" commit -qm h
runh() { (cd "$H" && bash adapters/secret-sweep/secret-sweep.sh "$@" 2>&1); }
out=$(runh --history)
printf '%s\n' "$out" | grep -qE '^history  [0-9a-f]{7,}  pp\.txt  aws-access-key-id  AK…\(len 20\)$' \
  && ok "a key added after a line starting with ++ is found" || ko "++ line hid a key: $out"
printf '%s\n' "$out" | grep -qE '^history  [0-9a-f]{7,}  pb\.txt  github-token' \
  && ok "a key after a ++ b/… line is found under its real path" || ko "++ b/ line: $out"
printf '%s' "$out" | grep -q 'LINECONTENT' && ko "line content was printed in the path field: $out" \
  || ok "a ++ b/… line's content never reaches the path field"
printf '%s\n' "$out" | grep -qE '^history  [0-9a-f]{7,}  configuración/k\.txt  aws-access-key-id' \
  && ok "a key in a file under a non-ASCII path is found, the path printed as written" || ko "non-ASCII path: $out"
printf '%s\n' "$out" | grep -qE '^history  [0-9a-f]{7,}  configuración/\.env  env file committed' \
  && ok "a real env file under a non-ASCII path is named" || ko "non-ASCII env: $out"
printf '%s\n' "$out" | grep -qE '^history  [0-9a-f]{7,}  we"ird/\.env  env file committed' \
  && ok "a real env file under a path git always quotes is named" || ko "quoted env: $out"
printf '%s\n' "$out" | grep -qE '^history  [0-9a-f]{7,}  plain dir/k\.txt  aws-access-key-id' \
  && ok "a key in a file whose path holds a space is found (git ends that header with a tab)" || ko "space path: $out"
printf '%s\n' "$out" | grep -qE '^history  [0-9a-f]{7,}  we"ird dir/k\.txt  aws-access-key-id' \
  && ok "a key under a path with a space and a quote is found" || ko "space+quote path: $out"
# The user's own settings, each one that changes what git prints: none may hide a key or an env file.
printf '*.dat diff=hide\n*.lock -diff\n' > "$H/.git/info/attributes"; "${GH[@]}" config diff.hide.textconv true
"${GH[@]}" config diff.noprefix true; "${GH[@]}" config diff.dstPrefix z/; "${GH[@]}" config log.showRoot false
out=$(runh --history)
printf '%s\n' "$out" | grep -qE '^history  [0-9a-f]{7,}  tc\.dat  aws-access-key-id' \
  && ok "a textconv driver never hides a key in history" || ko "textconv: $out"
printf '%s\n' "$out" | grep -qE '^history  [0-9a-f]{7,}  x\.lock  aws-access-key-id' \
  && ok "a -diff attribute never hides a key in history" || ko "-diff: $out"
printf '%s\n' "$out" | grep -qE '^history  [0-9a-f]{7,}  pp\.txt  aws-access-key-id' \
  && ok "diff.noprefix, diff.dstPrefix and log.showRoot=false never hide the root commit's keys" || ko "prefix/root config: $out"
printf '%s\n' "$out" | grep -qE '^history  [0-9a-f]{7,}  configuración/\.env  env file committed' \
  && ok "log.showRoot=false never hides an env file in the root commit" || ko "root env: $out"
"${GH[@]}" config --unset diff.noprefix; "${GH[@]}" config --unset diff.dstPrefix; "${GH[@]}" config --unset log.showRoot
leak=0; for v in "$PPK" "$PBK" "$NAK" "$TCK" "$SPK" "$SQK" "$BNK"; do printf '%s' "$out" | grep -qF -- "$v" && leak=1; done
[ "$leak" -eq 0 ] && ok "none of these values is printed" || ko "a value was printed: $out"
# Every key rule is checked against a sample built at run time: a broken edit to one is refused.
HP="$H/adapters/secret-sweep/patterns.txt"; cp "$HP" "$SBX/hist-patterns.good"
for rule in 'gh\[pousr\]_' 'xox\[baprs\]-' 'sk-'; do
  cp "$SBX/hist-patterns.good" "$HP"; sed -i "s/^\(${rule}.*\){[0-9]*,}\$/\1{200,}/" "$HP"
  cmp -s "$HP" "$SBX/hist-patterns.good" && { ko "harness: the $rule rule was not broken"; continue; }
  out=$(runh --tree); rc=$?
  [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'patterns.txt' && ok "a broken rule ($rule) is refused (exit 2)" || ko "broken $rule rule: rc=$rc $out"
done
cp "$SBX/hist-patterns.good" "$HP"

echo "▶ a file holding a NUL byte is read, in the tree and under a named path"
Y="$SBX/binary"; mkdir -p "$Y/adapters/secret-sweep" "$Y/logs"
cp "$HERE/secret-sweep.sh" "$HERE/patterns.txt" "$HERE/patterns-words.txt" "$HERE/env-files.txt" "$HERE/env-files.sh" "$HERE/patterns.sh" "$Y/adapters/secret-sweep/" 2>/dev/null
BINK="AKIA$(rep Y 16)"; printf 'x\000y\nkey = "%s"\n' "$BINK" > "$Y/bin.lock"; cp "$Y/bin.lock" "$Y/logs/history.bin"
git -C "$Y" init -q; git -C "$Y" -c user.name=t -c user.email=t@t add -A; git -C "$Y" -c user.name=t -c user.email=t@t -c core.hooksPath=/dev/null commit -qm c
out=$( (cd "$Y" && bash adapters/secret-sweep/secret-sweep.sh --tree) 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q '^tree  bin.lock:2  aws-access-key-id  AK…(len 20)$' \
  && ok "a key in a tracked binary file is found, masked" || ko "binary tree file: rc=$rc $out"
out=$( (cd "$Y" && bash adapters/secret-sweep/secret-sweep.sh --path "$Y/logs") 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'history.bin:2  aws-access-key-id' && ok "a key in a binary file under a named path is found" || ko "binary path file: rc=$rc $out"
printf '%s' "$out" | grep -qF -- "$BINK" && ko "the value was printed" || ok "and its value is never printed"

echo "▶ a file the sweep cannot read is named and the run exits 2, never an all-clear"
if [ "$EUID" -eq 0 ]; then echo "  (skipped: root reads a chmod 000 file)"; else
  X="$SBX/unreadable"; mkdir -p "$X/adapters/secret-sweep" "$X/logs"
  cp "$HERE/secret-sweep.sh" "$HERE/patterns.txt" "$HERE/patterns-words.txt" "$HERE/env-files.txt" "$HERE/env-files.sh" "$HERE/patterns.sh" "$X/adapters/secret-sweep/" 2>/dev/null
  git -C "$X" init -q; printf 'key = "%s"\n' "AKIA$(rep L 16)" > "$X/locked.txt"; printf 'hello\n' > "$X/ok.txt"
  git -C "$X" -c user.name=t -c user.email=t@t add -A; git -C "$X" -c user.name=t -c user.email=t@t -c core.hooksPath=/dev/null commit -qm c
  cp "$X/locked.txt" "$X/logs/locked.log"; chmod 000 "$X/locked.txt" "$X/logs/locked.log"
  out=$( (cd "$X" && bash adapters/secret-sweep/secret-sweep.sh --tree) 2>&1); rc=$?
  [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'could not read' && printf '%s' "$out" | grep -q 'locked.txt' \
    && ! printf '%s' "$out" | grep -q 'nothing found' && ok "an unreadable tracked file: named, exit 2, no 'nothing found'" || ko "unreadable tree file: rc=$rc $out"
  out=$( (cd "$X" && bash adapters/secret-sweep/secret-sweep.sh --path "$X/logs") 2>&1); rc=$?
  [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'locked.log' && ok "an unreadable file under a named path: named, exit 2" || ko "unreadable path file: rc=$rc $out"
  chmod 644 "$X/locked.txt" "$X/logs/locked.log"
fi

echo "▶ no value is ever printed"
out=$(run --tree --history --path "$SBX/logs")
leak=0; for v in "${ALL[@]}"; do printf '%s' "$out" | grep -qF -- "$v" && leak=1; done
[ "$leak" -eq 0 ] && ok "no fixture value appears in any output" || ko "a value was printed"

echo "== $pass passed, $fail failed"
[ "$fail" -eq 0 ]
