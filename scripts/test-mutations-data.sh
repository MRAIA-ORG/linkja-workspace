#!/bin/sh
# Recorded broken lines for clone-all-mutations.txt. Each one must make
# "test-clone-all-mutations.sh --check" exit nonzero with its own problem text.
# The valid cases must pass. The full cases run the whole runner loop on stubs
# in a temp folder. Runs in seconds: nothing is cloned or downloaded.
# Usage: scripts/test-mutations-data.sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failed=0

# check NAME WANT_EXIT WANT_TEXT DATA: DATA is a printf format for the whole file.
check() {
  # shellcheck disable=SC2059 # the case text is the format, so \t and \n become tabs and newlines
  printf "$4" > "$work/data"
  status=0
  out=$("$here/test-clone-all-mutations.sh" --check "$work/data" 2>&1) || status=$?
  if [ $(($2 != 0)) -eq $((status != 0)) ] && printf '%s\n' "$out" | grep -qF "$3"; then
    echo "ok: $1"
  else
    echo "FAIL: $1. Want exit $2 and '$3'. Got exit $status: $out"
    failed=1
  fi
}

# full NAME WANT_EXIT WANT_TEXT DATA: runs a copy of the runner, with no --check,
# next to stub files. The runner finds its files in its own folder. The stub test
# makes the mirrors folder on the first run. It fails with a FAIL line on every
# mutation run, so each mutation whose expect is in that line is caught.
full() {
  dir="$work/full"
  rm -rf "$dir" && mkdir "$dir"
  cp "$here/test-clone-all-mutations.sh" "$dir/"
  # shellcheck disable=SC2016 # the stub expands $1 when it runs
  printf '#!/bin/sh\nif [ -n "${1-}" ]; then mkdir -p "$1/mirrors"; exit 0; fi\necho "FAIL: stub test"; exit 1\n' > "$dir/test-clone-all.sh"
  # shellcheck disable=SC2016 # the runner reads the default address from this line
  printf 'base=${LINKJA_GIT_BASE:-https://example.invalid/org}\necho clone\n' > "$dir/clone-all.sh"
  : > "$dir/repos.txt"
  chmod +x "$dir/test-clone-all.sh"
  # shellcheck disable=SC2059 # the case text is the format, as in check
  printf "$4" > "$dir/clone-all-mutations.txt"
  status=0
  out=$(sh "$dir/test-clone-all-mutations.sh" 2>&1 </dev/null) || status=$?
  if [ $(($2 != 0)) -eq $((status != 0)) ] && printf '%s\n' "$out" | grep -qF "$3"; then
    echo "ok: $1"
  else
    echo "FAIL: $1. Want exit $2 and '$3'. Got exit $status: $out"
    failed=1
  fi
}

ok='a\tmirror\ts|x|y|\tsome text\tPR #1\n'
check 'valid line' 0 'OK: 1 mutation lines' "# comment\n\n$ok"
check 'last line without newline is read' 0 'OK: 2 mutation lines' "${ok}b\tmirror\ts|x|y|\tsome text\tPR #1"
check 'bad last line without newline' 1 'line 2 has 4 fields, want 5' "${ok}b\tmirror\ts|x|y|\tPR #1"
check 'expect of one space' 1 'line 1: field 4 (expect) is blank' 'a\tmirror\ts|x|y|\t \tPR #1\n'
check 'empty field' 1 'line 1 has 4 fields, want 5' 'a\tmirror\ts|x|y|\tPR #1\n'
check 'empty field between tabs' 1 'line 1: field 4 (expect) is blank' 'a\tmirror\ts|x|y|\t\tPR #1\n'
check 'six fields' 1 'line 1 has 6 fields, want 5' 'a\tmirror\textra\ts|x|y|\tsome text\tPR #1\n'
check 'leading tab' 1 'line 1: field 1 (label) is blank' '\ta\tmirror\ts|x|y|\tsome text\n'
check 'unknown source' 1 "line 1: unknown source 'mirorr'" 'a\tmirorr\ts|x|y|\tsome text\tPR #1\n'
check 'no mutations' 1 'no mutations in' '# only a comment\n'
check 'label that starts with a space' 0 'OK: 1 mutation lines' ' lead\tmirror\ts|x|y|\tsome text\tPR #1\n'

run='\tmirror\ts|clone|klone|\tstub test\tPR #1'
full 'full run: last line without newline' 0 'PASS: all 2 mutations caught' "a$run\nb$run"

[ "$failed" -eq 0 ] || exit 1
echo "PASS: all data cases"
