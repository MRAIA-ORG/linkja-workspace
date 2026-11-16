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

# Every case runs a copy of the runner next to stub files, so a runner that
# goes past --check runs the stubs and clones nothing. The runner finds its
# files in its own folder. The base run gets a folder and makes mirrors there.
dir="$work/stubs"
mkdir "$dir"
cp "$here/test-clone-all-mutations.sh" "$dir/"
# shellcheck disable=SC2016 # the stub expands its variables when it runs
printf '#!/bin/sh\necho "note: stub test ran"\nif grep -q klone "$(dirname "$0")/clone-all.sh"; then echo "FAIL: stub test saw klone"; exit 1; fi\nif [ -n "${1-}" ]; then mkdir -p "$1/mirrors"; fi\n' > "$dir/test-clone-all.sh"
# shellcheck disable=SC2016 # the runner reads the default address from this line
printf 'base=${LINKJA_GIT_BASE:-https://example.invalid/org}\necho clone\n' > "$dir/clone-all.sh"
: > "$dir/repos.txt"
chmod +x "$dir/test-clone-all.sh"

# check NAME WANT_EXIT WANT_TEXT DATA: DATA is a printf format for the whole file.
# The case fails when the runner goes past --check.
check() {
  # shellcheck disable=SC2059 # the case text is the format, so \t and \n become tabs and newlines
  printf "$4" > "$work/data"
  status=0
  out=$(sh "$dir/test-clone-all-mutations.sh" --check "$work/data" 2>&1 </dev/null) || status=$?
  # The runner prints "== " only when it runs past --check into the full loop.
  if [ $(($2 != 0)) -eq $((status != 0)) ] && printf '%s\n' "$out" | grep -qF "$3" &&
    ! printf '%s\n' "$out" | grep -q '^== '; then
    echo "ok: $1"
  else
    echo "FAIL: $1. Want exit $2 and '$3'. Got exit $status: $out"
    failed=1
  fi
}

# full NAME WANT_EXIT WANT_TEXT DATA CAUGHT [NOT_TEXT]: runs the runner copy
# with no --check. The stub test fails only when the clone-all.sh next to it
# has the mutated text "klone", so a mutation is caught only when the runner
# tests the mutated copy. Each mutation must print its own "caught:" line.
# The output must have CAUGHT such lines, and must not have NOT_TEXT.
full() {
  # shellcheck disable=SC2059 # the case text is the format, as in check
  printf "$4" > "$dir/clone-all-mutations.txt"
  status=0
  out=$(sh "$dir/test-clone-all-mutations.sh" 2>&1 </dev/null) || status=$?
  caught=$(printf '%s\n' "$out" | grep -c '^caught: ') || true
  if [ $(($2 != 0)) -eq $((status != 0)) ] && printf '%s\n' "$out" | grep -qF "$3" && [ "$caught" -eq "$5" ] &&
    { [ -z "${6-}" ] || ! printf '%s\n' "$out" | grep -qF "$6"; }; then
    echo "ok: $1"
  else
    echo "FAIL: $1. Want exit $2, '$3' and $5 caught lines. Got exit $status, $caught caught lines: $out"
    failed=1
  fi
}

ok='a\tmirror\ts|x|y|\tsome test text\tPR #1\n'
check 'valid line' 0 'OK: 1 mutation lines' "# comment\n\n$ok"
check 'last line without newline is read' 0 'OK: 2 mutation lines' "${ok}b\tmirror\ts|x|y|\tsome test text\tPR #1"
check 'bad last line without newline' 1 'line 2 has 4 fields, want 5' "${ok}b\tmirror\ts|x|y|\tPR #1"
check 'expect of one space' 1 'line 1: field 4 (expect) is blank' 'a\tmirror\ts|x|y|\t \tPR #1\n'
check 'empty field' 1 'line 1 has 4 fields, want 5' 'a\tmirror\ts|x|y|\tPR #1\n'
check 'empty field between tabs' 1 'line 1: field 4 (expect) is blank' 'a\tmirror\ts|x|y|\t\tPR #1\n'
check 'six fields' 1 'line 1 has 6 fields, want 5' 'a\tmirror\textra\ts|x|y|\tsome test text\tPR #1\n'
check 'leading tab' 1 'line 1: field 1 (label) is blank' '\ta\tmirror\ts|x|y|\tsome test text\n'
check 'unknown source' 1 "line 1: unknown source 'mirorr'" 'a\tmirorr\ts|x|y|\tsome test text\tPR #1\n'
check 'no mutations' 1 'no mutations in' '# only a comment\n'
check 'label that starts with a space' 0 'OK: 1 mutation lines' ' lead\tmirror\ts|x|y|\tsome test text\tPR #1\n'
check 'expect shorter than 10 characters' 1 "line 1: field 4 (expect) 'e' is too weak" 'a\tmirror\ts|x|y|\te\tPR #1\n'
check 'expect with the FAIL: prefix' 1 "line 1: field 4 (expect) 'FAIL: unrelated' is too weak" 'a\tmirror\ts|x|y|\tFAIL: unrelated\tPR #1\n'

run='\tmirror\ts|clone|klone|\tstub test saw klone\tPR #1'
full 'full run: last line without newline' 0 'PASS: all 2 mutations caught' "a$run\nb$run" 2
full 'expect text the stub never prints' 1 'not caught' 'a\tmirror\ts|clone|klone|\tnever printed\tPR #1\n' 0
full 'expect text only outside a FAIL line' 1 'not caught' 'a\tmirror\ts|clone|klone|\tstub test ran\tPR #1\n' 0
full 'mutation that changes nothing is not run' 1 'changes nothing in clone-all.sh' 'a\tmirror\ts|no such text|x|\tsome test text\tPR #1\n' 0 '== mutation'

[ "$failed" -eq 0 ] || exit 1
echo "PASS: all data cases"
