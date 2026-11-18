#!/bin/sh
# Recorded cases for test-golden-matching-mutations.sh (the runner). Each broken
# data line must make the runner exit nonzero with its own text. The valid cases
# must pass. Every case runs a copy of the runner beside a stub
# test-golden-matching.sh, so nothing is built. Runs in seconds.
# Usage: scripts/test-golden-mutations-data.sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failed=0
tab=$(printf '\t')

# The runner finds the script, its data file and tests/golden-matching/ from
# its own folder, so the copy gets the repo layout.
dir="$work/repo/scripts"
mkdir -p "$dir" "$work/repo/tests/golden-matching/input"
cp "$here/test-golden-matching-mutations.sh" "$dir/"
{
  echo siteid
  seq 599 | sed 's/.*/002,x/'
} >"$work/repo/tests/golden-matching/input/hashes_002.csv"
# The stub fails with the text of each case of the runner. The line
# "# marker" is the target of mutations that change nothing it does.
cat >"$dir/test-golden-matching.sh" <<'STUB'
#!/bin/sh
fail() { echo "FAIL: $*"; exit 1; }
f="$(dirname "$0")/../tests/golden-matching/input/hashes_002.csv"
# marker
[ "${GOLDEN_UPDATE:-}" = 1 ] && [ -n "${GOLDEN_RULES:-}" ] && fail "GOLDEN_UPDATE=1 with GOLDEN_RULES"
{ [ -f "$f" ] && ! grep -q '^003,' "$f"; } || fail "a row of $f has another siteid"
case ${GOLDEN_RULES:-} in
*,12) fail "report.txt differs" ;;
?*) fail "rules.txt differs" ;;
esac
echo "PASS: stub"
STUB

# full NAME WANT_EXIT WANT_TEXT DATA [NOT_TEXT]: DATA is a printf format for
# the whole mutations file. Runs the runner copy on it. The output must not
# have NOT_TEXT.
full() {
  # shellcheck disable=SC2059 # the case text is the format, so \t and \n become tabs and newlines
  printf "$4" >"$dir/golden-matching-mutations.txt"
  status=0
  out=$(sh "$dir/test-golden-matching-mutations.sh" 2>&1 </dev/null) || status=$?
  if [ $(($2 != 0)) -eq $((status != 0)) ] && printf '%s\n' "$out" | grep -qF "$3" &&
    { [ -z "${5-}" ] || ! printf '%s\n' "$out" | grep -qF "$5"; }; then
    echo "ok: $1"
  else
    echo "FAIL: $1. Want exit $2 and '$3'. Got exit $status: $out"
    failed=1
  fi
}

kill="kill${tab}s{fail \"rules.txt differs\"}{true}${tab}fewer_rules${tab}PR #1\n"
full 'mutation killed' 0 'PASS: all 1 mutations' "# comment\n\n$kill"
full 'mutant survives' 1 "SURVIVED: 'live'" "live${tab}s{# marker}{# changed}${tab}fewer_rules${tab}PR #1\n"
full 'no proof field' 1 "FAIL: 'a' has no proof field" "a${tab}s{# marker}{# changed}${tab}fewer_rules${tab}\n"
full 'unknown case' 1 "FAIL: 'a' names no known case: 'nope'" "a${tab}s{# marker}{# changed}${tab}nope${tab}PR #1\n"
full 'pattern matches 0 times' 1 "FAIL: 'a' (PR #1) matches 0 times, want 1" "a${tab}s{no such text}{x}${tab}fewer_rules${tab}PR #1\n"
full 'pattern matches 2 times' 1 "FAIL: 'a' (PR #1) matches 2 times, want 1" "a${tab}s{differs}{x}${tab}fewer_rules${tab}PR #1\n"
full 'mutation changes nothing' 1 "FAIL: 'a' (PR #1) changes nothing in the script" "a${tab}s{(# marker)}{\$1}${tab}fewer_rules${tab}PR #1\n"
full 'no mutations' 1 'FAIL: no mutations in' '# only a comment\n'
# A mutant that hangs is stopped and does not count as caught. With no time
# limit it would sleep, then fail with the case text, so it would survive.
GOLDEN_CASE_SECONDS=1 full 'mutant that hangs' 0 'PASS: all 1 mutations' "hang${tab}s{# marker}{sleep 5}${tab}fewer_rules${tab}PR #1\n"
# The runner must stop before any mutation when the script as it is does not
# fail on a case.
perl -pi -e 's/fail "rules.txt differs"/true/' "$dir/test-golden-matching.sh"
full 'base run does not fail' 1 'FAIL: the script as it is does not fail on case fewer_rules' \
  "kill${tab}s{fail \"report.txt differs\"}{true}${tab}fewer_groups${tab}PR #1\n" 'killed: '

[ "$failed" -eq 0 ] || exit 1
echo "PASS: all data cases"
