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
# The runner must unset this before its base run, so every full case sets it.
LINKJA_GIT_BASE=https://example.invalid/wrong
export LINKJA_GIT_BASE

# Every case runs a copy of the runner next to stub files, so a runner that
# goes past --check runs the stubs and clones nothing. The runner finds its
# files in its own folder. The base run gets a folder and makes mirrors there.
dir="$work/stubs"
mkdir "$dir"
cp "$here/test-clone-all-mutations.sh" "$dir/"
# The stub prints the address it would mirror from, i.e. LINKJA_GIT_BASE or
# the default. Its base run (the one with a folder) must get no LINKJA_GIT_BASE,
# and makes no mirrors when clone-all.sh has the word "nomirrors".
cat > "$dir/test-clone-all.sh" <<'STUB'
#!/bin/sh
fail() { echo "FAIL: $*"; exit 1; }
echo "note: stub test ran. It fails when it saw LINKJA_GIT_BASE in its base run."
script="$(dirname "$0")/clone-all.sh"
src=${LINKJA_GIT_BASE:-https://example.invalid/org}
if [ -n "${1-}" ]; then
  [ -z "${LINKJA_GIT_BASE-}" ] || fail "stub test saw LINKJA_GIT_BASE in its base run"
  grep -q nomirrors "$script" || mkdir -p "$1/mirrors"
fi
if grep -q klone "$script"; then fail "stub test saw klone from $src"; fi
STUB
# clone_all TEXT: writes TEXT and "echo clone" into the stub clone-all.sh.
# The runner reads the default address from the base= line.
clone_all() {
  # shellcheck disable=SC2059 # the text is the format, so \n becomes a newline
  printf "$1\necho clone\n" > "$dir/clone-all.sh"
}
# shellcheck disable=SC2016 # the stub clone-all.sh expands it
base='base=${LINKJA_GIT_BASE:-https://example.invalid/org}'
clone_all "$base"
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

ok='a\tmirror\ts|x|y|\tstub test saw klone\tPR #1\n'
check 'valid line' 0 'OK: 1 mutation lines' "# comment\n\n$ok"
check 'last line without newline is read' 0 'OK: 2 mutation lines' "${ok}b\tmirror\ts|x|y|\tstub test saw klone\tPR #1"
check 'bad last line without newline' 1 'line 2 has 4 fields, want 5' "${ok}b\tmirror\ts|x|y|\tPR #1"
check 'expect of one space' 1 'line 1: field 4 (expect) is blank' 'a\tmirror\ts|x|y|\t \tPR #1\n'
check 'empty field' 1 'line 1 has 4 fields, want 5' 'a\tmirror\ts|x|y|\tPR #1\n'
check 'empty field between tabs' 1 'line 1: field 4 (expect) is blank' 'a\tmirror\ts|x|y|\t\tPR #1\n'
check 'six fields' 1 'line 1 has 6 fields, want 5' 'a\tmirror\textra\ts|x|y|\tsome test text\tPR #1\n'
check 'leading tab' 1 'line 1: field 1 (label) is blank' '\ta\tmirror\ts|x|y|\tsome test text\n'
check 'unknown source' 1 "line 1: unknown source 'mirorr'" 'a\tmirorr\ts|x|y|\tsome test text\tPR #1\n'
check 'no mutations' 1 'no mutations in' '# only a comment\n'
check 'label that starts with a space' 0 'OK: 1 mutation lines' ' lead\tmirror\ts|x|y|\tstub test saw klone\tPR #1\n'
check 'expect shorter than 10 characters, after a valid line' 1 "line 2: field 4 (expect) 'e' is too weak: want 10 or more" "${ok}b\tmirror\ts|x|y|\te\tPR #1\n"
check 'expect of 9 characters' 1 "line 1: field 4 (expect) '123456789' is too weak" 'a\tmirror\ts|x|y|\t123456789\tPR #1\n'
check 'expect of 10 characters' 0 'OK: 1 mutation lines' 'a\tmirror\ts|x|y|\ttest saw k\tPR #1\n'
check 'expect that matches two FAIL messages' 1 "line 1: field 4 (expect) 'stub test saw' matches 2 FAIL messages" 'a\tmirror\ts|x|y|\tstub test saw\tPR #1\n'
check 'expect that matches no FAIL message' 1 "line 1: field 4 (expect) 'aaaaaaaaaa' matches 0 FAIL messages" 'a\tmirror\ts|x|y|\taaaaaaaaaa\tPR #1\n'
check 'expect that ends in a variable of a FAIL message' 0 'OK: 1 mutation lines' 'a\tmirror\ts|x|y|\tsaw klone from somewhere\tPR #1\n'
check 'expect that starts inside a word' 0 'OK: 1 mutation lines' 'a\tmirror\ts|x|y|\tub test saw klone\tPR #1\n'
check 'expect of one word inside a message word' 0 'OK: 1 mutation lines' 'a\tmirror\ts|x|y|\tINKJA_GIT_BAS\tPR #1\n'
check 'expect FAIL' 1 "line 1: field 4 (expect) 'FAIL' is too weak" 'a\tmirror\ts|x|y|\tFAIL\tPR #1\n'
check 'expect with FAIL: in the middle' 1 "line 1: field 4 (expect) 'x FAIL: y z' is too weak" 'a\tmirror\ts|x|y|\tx FAIL: y z\tPR #1\n'
check 'expect with the FAIL: prefix' 1 "line 1: field 4 (expect) 'FAIL: unrelated' is too weak" 'a\tmirror\ts|x|y|\tFAIL: unrelated\tPR #1\n'

run='\tmirror\ts|clone|klone|\tstub test saw klone\tPR #1'
full 'full run: last line without newline' 0 'PASS: all 2 mutations caught' "a$run\nb$run" 2
full 'expect text the stub never prints' 1 'not caught' 'a\tmirror\ts|clone|klone|\tstub test saw LINKJA_GIT_BASE\tPR #1\n' 0
full 'expect text only outside a FAIL line' 1 'not caught' 'a\tmirror\ts|clone|klone|\tsaw LINKJA_GIT_BASE in its base run\tPR #1\n' 0
full 'mutation that changes nothing is not run' 1 'changes nothing in clone-all.sh' 'a\tmirror\ts|no such text|x|\tstub test saw klone\tPR #1\n' 0 '== mutation'
full 'default line clones from the default address' 0 'PASS: all 1 mutations caught' 'a\tdefault\ts|clone|klone|\tsaw klone from https://example.invalid/org\tPR #1\n' 1
clone_all "$base\n# klone"
full 'base run fails' 1 'the test fails on clone-all.sh as it is' "a$run\n" 0
clone_all "$base\n# nomirrors"
full 'base run makes no mirrors' 1 'FAIL: no mirrors at' "a$run\n" 0
clone_all '# no base line'
full 'no default address in clone-all.sh' 1 'cannot read the default address' "a$run\n" 0

[ "$failed" -eq 0 ] || exit 1
echo "PASS: all data cases"
