#!/bin/sh
# Recorded broken lines for clone-all-mutations.txt. Each one must make
# "test-clone-all-mutations.sh --check" exit nonzero with its own problem text.
# The valid cases must pass. Runs in seconds: --check clones nothing.
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

[ "$failed" -eq 0 ] || exit 1
echo "PASS: all data cases"
