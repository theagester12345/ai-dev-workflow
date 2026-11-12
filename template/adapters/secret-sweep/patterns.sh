# patterns.sh — reads a secret-patterns file (patterns.txt, patterns-words.txt). Sourced, never run.
# The one reader for both users of those files: .githooks/pre-commit (POSIX sh) and secret-sweep.sh
# (bash), so it is written in POSIX sh. The env-file rules have their own reader, env-files.sh, of
# the same shape.
#
#   patterns_load <patterns file> <out file> [-i]
#     writes "<name><TAB><regex>" per rule to <out file>, the name taken from the comment line above
#     it, and returns 0 only when the set passes the checks below; returns 1 otherwise, and the
#     caller fails closed (the hook refuses the commit, the sweep refuses to run). -i: the file is
#     matched ignoring case (patterns-words.txt).
#
# A set is checked before it is trusted. A carriage return (a Windows checkout) is stripped, so it
# never turns a rule into one that matches nothing. A rule grep -E rejects is refused: grep exits 2
# on it, and a caller reading that as "no match" lets every key through. An empty set is refused.
# And the set must match a known sample of each shipped rule: a private-key header, an AWS key id,
# a GitHub, a Slack and an sk- token for patterns.txt; a password written as words for patterns-words.txt. Samples are built here at run time, so this
# file never holds a secret-shaped string the guard would refuse.

patterns_sample() {  # $1 = -i or "" → the samples the set must match, one per line
  if [ "${1:-}" = -i ]; then
    printf '%s%s: %s%s\n' pass word ab12 cd34   # split, so the sweep never finds this file
  else
    # One per shipped rule, so a broken edit to any of them is refused, not silent.
    pl_a8=AAAAAAAA; pl_l8=aaaaaaaa; pl_d8=11111111
    printf 'AKIA%s%s\n' "$pl_a8" "$pl_a8"
    printf '%s %s %s\n' '-----BEGIN RSA' 'PRIVATE' 'KEY-----'
    printf 'gh%s_%s%s%s\n' p "$pl_l8" "$pl_l8" "$pl_l8"
    printf 'xox%s-%s%s\n' b "$pl_d8" "$pl_d8"
    printf 's%s-%s%s%s\n' k "$pl_l8" "$pl_l8" "$pl_l8"
  fi
}

patterns_load() {
  [ -f "$1" ] || return 1
  # A rule's surroundings never change it: a byte-order mark, a CR, spaces around it, a tab in its
  # name (the name and the rule are joined by a tab, so a tab in the name would shift the rule).
  awk 'NR == 1 { sub(/^\357\273\277/, "") }
       { sub(/\r$/, "") }
       /^#/ { name = $0; sub(/^#[ \t]*/, "", name); gsub(/\t/, " ", name); next }
       /^[[:space:]]*$/ { next }
       { r = $0; sub(/^[ \t]+/, "", r); sub(/[ \t]+$/, "", r); print name "\t" r }' "$1" > "$2" || return 1
  [ -s "$2" ] || return 1
  pl_re=$(mktemp) || return 1
  cut -f2- "$2" > "$pl_re"
  pl_i=${3:-}; pl_ok=0
  while IFS= read -r pl_one; do   # each rule alone: grep exits 2 on one it rejects
    printf '%s\n' "$pl_one" > "$pl_re.1"
    pl_rc=0; printf '\n' | grep -E $pl_i -f "$pl_re.1" >/dev/null 2>&1 || pl_rc=$?
    [ "$pl_rc" -le 1 ] || { pl_ok=1; break; }
    # A rule that matches ordinary text would block every commit and, in the sweep, print a piece
    # of every line: refused like a broken one.
    if printf '%s\n' 'the quick brown fox jumps over the lazy dog 0123456789 config.yaml' \
       | grep -E $pl_i -f "$pl_re.1" >/dev/null 2>&1; then pl_ok=1; break; fi
  done < "$pl_re"
  if [ "$pl_ok" -eq 0 ]; then     # then the whole set against each known sample
    patterns_sample "$pl_i" > "$pl_re.s"
    while IFS= read -r pl_one; do
      printf '%s\n' "$pl_one" | grep -E $pl_i -f "$pl_re" >/dev/null 2>&1 || { pl_ok=1; break; }
    done < "$pl_re.s"
  fi
  rm -f "$pl_re" "$pl_re.1" "$pl_re.s"
  return "$pl_ok"
}
