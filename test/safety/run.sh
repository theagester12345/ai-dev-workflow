#!/usr/bin/env bash
# test/safety/run.sh — the payload does on a machine exactly what template/SAFETY.md says it does.
# Part of the workflow's own repository; never copied into a project. Run: bash test/safety/run.sh
#
# 1. The real check: every hook, network call, dependency, program and home-directory use found in
#    template/ is on the page's allow-list, and nothing on the list is gone from the code.
# 2. The check can fail: a scratch copy of the payload gains one of each kind of thing, and each
#    must be named. A scanner that goes quiet passes every real run, so this half is not optional.
# 3. Its near misses: a URL in a comment, or in a doc, is not a call and must not be reported.
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SCAN="$ROOT/test/safety/scan.js"
PAGE="$ROOT/template/SAFETY.md"
pass=0; fail=0
ok(){ echo "  ✔ $1"; pass=$((pass+1)); }
ko(){ echo "  ✖ $1${2:+ — $2}"; fail=$((fail+1)); }

echo "▶ the payload against its page"
if [ ! -f "$PAGE" ]; then
  ko "template/SAFETY.md exists"
else
  out=$(node "$SCAN" "$ROOT/template" "$PAGE" 2>&1); rc=$?
  [ "$rc" -eq 0 ] && ok "every item found is listed, and every listed item is found" || { ko "page and payload differ"; printf '%s\n' "$out" | sed 's/^/      /'; }
fi

echo "▶ the check fails on what the page does not list"
SBX=$(mktemp -d); trap 'rm -rf "$SBX"' EXIT
cp -R "$ROOT/template" "$SBX/t"
[ -f "$PAGE" ] && cp "$PAGE" "$SBX/page.md" || printf '<!-- SAFETY:ALLOW START -->\n<!-- SAFETY:ALLOW END -->\n' > "$SBX/page.md"
printf 'fetch("https://example.com/collect", { method: "POST" });\n' > "$SBX/t/adapters/index/stray-fetch.js"
printf '#!/usr/bin/env bash\ncurl -s https://example.org/x >/dev/null\n' > "$SBX/t/adapters/index/stray.sh"
printf '#!/bin/sh\nexit 0\n' > "$SBX/t/.githooks/post-checkout"
printf 'const pad = require("left-pad");\n' > "$SBX/t/adapters/index/stray.js"
printf '#!/usr/bin/env bash\nmkdir -p "$HOME/.cache/x"\n' > "$SBX/t/adapters/index/stray-home.sh"
# A command inside arithmetic still runs: $(( … $(cmd) … )) must not hide cmd.
printf '#!/usr/bin/env bash\nn=$(( 1 + $(nproc) ))\nm=$((n + $(getconf PAGESIZE < "$x")))\n' > "$SBX/t/adapters/index/stray-arith.sh"
out=$(node "$SCAN" "$SBX/t" "$SBX/page.md" 2>&1); rc=$?
[ "$rc" -ne 0 ] && ok "a payload with unlisted items fails (exit $rc)" || ko "the planted items passed"
for want in "network  example.com" "network  (curl)" "program  curl" "hook  post-checkout" "import  left-pad" "home  adapters/index/stray-home.sh" "program  nproc" "program  getconf"; do
  grep -qF "UNLISTED  $want" <<<"$out" && ok "names it: $want" || ko "did not name: $want" "$(head -3 <<<"$out")"
done

echo "▶ the check fails on what the page lists but the payload no longer does"
cp -R "$ROOT/template" "$SBX/t2"
{ [ -f "$PAGE" ] && cat "$PAGE"; } | sed 's/<!-- SAFETY:ALLOW START -->/&\n| program | `telnet` | a stale row | — |/' > "$SBX/page2.md"
grep -q "SAFETY:ALLOW START" "$SBX/page2.md" || printf '<!-- SAFETY:ALLOW START -->\n| program | `telnet` | a stale row | — |\n<!-- SAFETY:ALLOW END -->\n' > "$SBX/page2.md"
out=$(node "$SCAN" "$SBX/t2" "$SBX/page2.md" 2>&1)
grep -qF "STALE     program  telnet" <<<"$out" && ok "a listed item the code no longer has is reported stale" || ko "a stale row passed"

echo "▶ near misses: a URL that is not a call is not reported"
mkdir -p "$SBX/n/adapters/x" "$SBX/n/.githooks"
cat > "$SBX/n/adapters/x/a.js" <<'EOF'
// see https://example.com/docs — fetch("https://example.com") is how you would call it
/* fetch("https://example.net") */
const url = "https://example.com"; // a string, not a call
EOF
printf '#!/usr/bin/env bash\n# curl https://example.com would be a call; this is a comment\necho "run curl yourself"\n' > "$SBX/n/adapters/x/b.sh"
printf 'Run `curl https://example.com` and fetch("https://example.org").\n' > "$SBX/n/adapters/x/README.md"
printf '<!-- SAFETY:ALLOW START -->\n| program | `echo` | | |\n<!-- SAFETY:ALLOW END -->\n' > "$SBX/n/page.md"
out=$(node "$SCAN" "$SBX/n" --list 2>&1)
[ -z "$out" ] && ok "comments, strings and docs produce nothing" || ko "reported a non-call" "$out"

echo "▶ node running a script: a fixed one beside it is node, a configured one is not"
mkdir -p "$SBX/c/adapters/y"
cat > "$SBX/c/adapters/y/runs-configured.mjs" <<'EOF'
import { execFileSync } from 'node:child_process';
import path from 'node:path';
const dir = process.argv[2];
execFileSync(process.execPath, [path.join(dir, 'x.mjs'), '--out', '/tmp/o']);
EOF
cat > "$SBX/c/adapters/y/runs-fixed.test.js" <<'EOF'
const { spawnSync } = require("node:child_process");
const path = require("node:path");
const SCRIPT = path.join(__dirname, "runs-fixed.js");
const HERE = __dirname;
const run = (...args) => spawnSync(process.execPath, [SCRIPT, ...args], { encoding: "utf8" });
spawnSync(process.execPath, [path.join(HERE, "other.js")]);
spawnSync(process.execPath, ["-e", "1"]);
EOF
out=$(node "$SCAN" "$SBX/c" --list 2>&1)
printf '%s\n' "$out" | grep -qxF "program	(configured) adapters/y/runs-configured.mjs	adapters/y/runs-configured.mjs" \
  && ok "node running a script from a configured folder is (configured) <file>" || ko "configured script not named" "$out"
printf '%s\n' "$out" | grep -qxF "program	node	adapters/y/runs-fixed.test.js" \
  && ok "node running a fixed script beside it, a literal, or a HERE-joined literal stays node" || ko "fixed script misread" "$out"

echo "▶ a function from a file the script sources is not a program"
mkdir -p "$SBX/d/adapters/z"
printf 'lib_fn() { printf x; }\n' > "$SBX/d/adapters/z/lib.sh"
printf '#!/usr/bin/env bash\nHERE=$(dirname "$0")\n. "$HERE/lib.sh"\nlib_fn\nnot_defined_fn\n' > "$SBX/d/adapters/z/uses.sh"
out=$(node "$SCAN" "$SBX/d" --list 2>&1)
printf '%s\n' "$out" | grep -q "program	lib_fn	" && ko "a sourced file's function was read as a program" "$out" \
  || ok "a function defined in a sourced payload file is not a program"
printf '%s\n' "$out" | grep -q "program	not_defined_fn	adapters/z/uses.sh" \
  && ok "near miss: a name defined nowhere is still a program" || ko "the near miss went unreported" "$out"

echo "== $pass passed, $fail failed"
[ "$fail" -eq 0 ]
