#!/bin/sh
# Mutation gate for test-clone-all-mutations.sh (the runner). Runs
# test-mutations-data.sh on the runner as it is, which must pass. Then for each
# line in runner-mutations.txt it changes a copy of the runner, runs a copy of
# test-mutations-data.sh beside it, and requires a nonzero exit.
# The runner in the repo stays as it is. Every run uses the offline stubs.
# Usage: scripts/test-runner-mutations.sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
data="$here/runner-mutations.txt"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
trap 'exit 1' INT TERM

# cases DIR: runs the data cases on the runner in DIR. A run that hangs is
# stopped after 60 seconds and counts as a nonzero exit.
cases() {
  perl -e 'alarm 60; exec @ARGV' -- sh "$1/test-mutations-data.sh" >"$1/out" 2>&1 </dev/null
}

mkdir "$work/base"
cp "$here/test-clone-all-mutations.sh" "$here/test-mutations-data.sh" "$work/base/"
cases "$work/base" || { cat "$work/base/out"; echo "FAIL: the data cases fail on the runner as it is"; exit 1; }

tab=$(printf '\t')
failed=0
n=0
while IFS=$tab read -r label expr proof || [ -n "$label" ]; do
  case $label in '' | '#'*) continue ;; esac
  n=$((n + 1))
  [ -n "$proof" ] || { echo "FAIL: '$label' has no proof field"; failed=1; continue; }
  run="$work/mutation-$n"
  mkdir "$run"
  cp "$here/test-clone-all-mutations.sh" "$here/test-mutations-data.sh" "$run/"
  perl -0pi -e "$expr" "$run/test-clone-all-mutations.sh"
  if cmp -s "$here/test-clone-all-mutations.sh" "$run/test-clone-all-mutations.sh"; then
    echo "FAIL: '$label' ($proof) changes nothing in the runner"
    failed=1
  elif cases "$run"; then
    echo "SURVIVED: '$label' ($proof). The data cases pass on this mutation."
    failed=1
  else
    echo "killed: $label"
  fi
done < "$data"

[ "$n" -gt 0 ] || { echo "FAIL: no mutations in $data"; exit 1; }
[ "$failed" -eq 0 ] || exit 1
echo "PASS: all $n runner mutations killed"
