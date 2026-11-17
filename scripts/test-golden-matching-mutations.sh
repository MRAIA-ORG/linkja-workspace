#!/bin/sh
# Proves that the checks of test-golden-matching.sh can fail. Each case runs a
# copy of the script on a copy of tests/golden-matching/ and must see the
# script fail with the case's own text. Then for each line in
# golden-matching-mutations.txt it changes a copy of the script, runs the case
# that the line names, and requires that case to stop seeing that failure.
# The script and the expected files in the repo stay as they are.
#
# Usage: scripts/test-golden-matching-mutations.sh [parent-dir]
#   parent-dir  folder with linkja-matching in it, as for test-golden-matching.sh.
# Each case that gets past the script's first checks builds and runs
# linkja-matching, so a full run takes some minutes.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
parent=$(cd "${1:-$(dirname "$(dirname "$here")")}" && pwd)
data="$here/golden-matching-mutations.txt"
tab=$(printf '\t')
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
trap 'exit 1' INT TERM
# Every match rule but the last one.
fewer=0,1,2,3,4,5,6,7,8,9,10,11
cases="fewer_rules update_fewer_rules siteid_differs"

# copy DIR: a copy of the script and its expected files, in the repo layout.
copy() {
  mkdir -p "$1/scripts" "$1/tests"
  cp "$here/test-golden-matching.sh" "$1/scripts/"
  cp -R "$(dirname "$here")/tests/golden-matching" "$1/tests/"
}

# caught DIR CASE: runs CASE on the copy in DIR. Returns 0 when the script
# fails with the text of that case. The output is in DIR/out.
caught() {
  script="$1/scripts/test-golden-matching.sh"
  status=0
  case $2 in
  fewer_rules)
    want="FAIL: rules.txt differs"
    GOLDEN_RULES=$fewer sh "$script" "$parent" >"$1/out" 2>&1 </dev/null || status=$?
    ;;
  update_fewer_rules)
    want="FAIL: GOLDEN_UPDATE=1 with GOLDEN_RULES"
    GOLDEN_UPDATE=1 GOLDEN_RULES=$fewer sh "$script" "$parent" >"$1/out" 2>&1 </dev/null || status=$?
    # The expected files must stay as they are.
    diff -r "$(dirname "$here")/tests/golden-matching" "$1/tests/golden-matching" >>"$1/out" 2>&1 || status=0
    ;;
  siteid_differs)
    want="FAIL: a row of"
    input="$1/tests/golden-matching/input"
    mv "$input/hashes_002.csv" "$input/hashes_003.csv"
    sh "$script" "$parent" >"$1/out" 2>&1 </dev/null || status=$?
    ;;
  esac
  [ "$status" -ne 0 ] && grep -q "^$want" "$1/out"
}

# check_entry LABEL PERL CASE PROOF: prints one FAIL line and returns 1 when
# the entry has no proof, names no known case, or its pattern does not match
# the script exactly once. perl -0pi changes only the first match.
check_entry() {
  [ -n "$4" ] || { echo "FAIL: '$1' has no proof field"; return 1; }
  case " $cases " in *" $3 "*) ;; *) echo "FAIL: '$1' names no known case: '$3'"; return 1 ;; esac
  matches=$(perl -0ne "print 0 + ${2}g" "$here/test-golden-matching.sh")
  [ "$matches" -eq 1 ] || { echo "FAIL: '$1' ($4) matches $matches times, want 1"; return 1; }
}

failed=0
for c in $cases; do
  copy "$work/base-$c"
  if caught "$work/base-$c" "$c"; then
    echo "ok: the script fails on case $c"
  else
    cat "$work/base-$c/out"
    echo "FAIL: the script as it is does not fail on case $c with its text"
    failed=1
  fi
done
[ "$failed" -eq 0 ] || exit 1

n=0
while IFS=$tab read -r label expr name proof || [ -n "$label" ]; do
  case $label in '' | '#'*) continue ;; esac
  n=$((n + 1))
  check_entry "$label" "$expr" "$name" "$proof" || { failed=1; continue; }
  run="$work/mutation-$n"
  copy "$run"
  perl -0pi -e "$expr" "$run/scripts/test-golden-matching.sh"
  if cmp -s "$here/test-golden-matching.sh" "$run/scripts/test-golden-matching.sh"; then
    echo "FAIL: '$label' ($proof) changes nothing in the script"
    failed=1
  elif caught "$run" "$name"; then
    echo "SURVIVED: '$label' ($proof). Case $name still fails on this mutation."
    failed=1
  else
    echo "killed: $label"
  fi
done <"$data"

[ "$n" -gt 0 ] || { echo "FAIL: no mutations in $data"; exit 1; }
[ "$failed" -eq 0 ] || exit 1
echo "PASS: all $n mutations of test-golden-matching.sh killed"
