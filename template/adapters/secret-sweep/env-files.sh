# env-files.sh — reads env-files.txt: what counts as a real env file. Sourced, never run.
# The one reader for both users of that file: .githooks/pre-commit (POSIX sh) and secret-sweep.sh
# (bash), so it is written in POSIX sh. A copy of these functions in each would be the drift that
# env-files.txt exists to remove.
#
#   env_files_load <path to env-files.txt>
#     sets ENV_RE and TPL_RE and returns 0 only when both rules pass the checks below;
#     returns 1 otherwise, and the caller fails closed (the hook refuses every .env* file).
#
# A rule is checked against known names before it is trusted. A stray carriage return, a comment
# taken for the rule, or a template rule broad enough to swallow a real env file would otherwise
# leave a guard that matches nothing, with no warning.

env_rule() {  # $1 file, $2 name → the line after "# <name>", unless it is missing or a comment
  awk -v k="# $2" '{ sub(/\r$/, "") } $0 == k { if ((getline l) > 0) { sub(/\r$/, "", l); if (l !~ /^#/) print l } exit }' "$1"
}
env_matches() { printf '%s\n' "$2" | grep -E -- "$1" >/dev/null 2>&1; }

env_files_load() {
  ENV_RE=""; TPL_RE=""
  [ -f "$1" ] || return 1
  ENV_RE=$(env_rule "$1" env-file); TPL_RE=$(env_rule "$1" template-suffix)
  [ -n "$ENV_RE" ] && [ -n "$TPL_RE" ] || return 1
  for real in .env .env.local .env.production config/.env.local sub/.env .env.example.production; do
    env_matches "$ENV_RE" "$real" || return 1
    if env_matches "$TPL_RE" "$real"; then return 1; fi
  done
  env_matches "$TPL_RE" .env.example && env_matches "$TPL_RE" config/.env.example
}
