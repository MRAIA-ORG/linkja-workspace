#!/bin/sh
# Mutation gate for a mutation runner. Runs the runner's data cases on the
# runner as it is, which must pass. Then for each line in the mutations file it
# changes a copy of the runner, runs a copy of the data cases beside it, and
# requires a nonzero exit.
# The runner in the repo stays as it is. Every run uses the offline stubs.
# Usage: scripts/test-runner-mutations.sh [RUNNER CASES MUTATIONS]
#   File names in scripts/. Default: test-clone-all-mutations.sh
#   test-mutations-data.sh runner-mutations.txt. The golden matching runner:
#   test-golden-matching-mutations.sh test-golden-mutations-data.sh golden-runner-mutations.txt
set -eu

here=$(cd "$(dirname "$0")" && pwd)
runner=${1:-test-clone-all-mutations.sh}
data_cases=${2:-test-mutations-data.sh}
data="$here/${3:-runner-mutations.txt}"
tab=$(printf '\t')
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
trap 'exit 1' INT TERM

# cases DIR: runs the data cases on the runner in DIR. A run that hangs is
# stopped after 60 seconds and counts as a nonzero exit.
cases() {
  perl -e 'alarm 60; exec @ARGV' -- sh "$1/$data_cases" >"$1/out" 2>&1 </dev/null
}

# check_entry LABEL PERL PROOF FILE: prints one FAIL line and returns 1 when
# the entry has no proof, or when its pattern does not match FILE exactly once.
# perl -0pi changes only the first match, so a second match would go untested.
check_entry() {
  [ -n "$3" ] || { echo "FAIL: '$1' has no proof field"; return 1; }
  matches=$(perl -0ne "print 0 + ${2}g" "$4")
  [ "$matches" -eq 1 ] || { echo "FAIL: '$1' ($3) matches $matches times in $4, want 1"; return 1; }
}

# Recorded cases for check_entry. Each entry must be refused.
printf 'aa\n' > "$work/text"
for bad in "no proof${tab}s{aa}{b}${tab}" "two matches${tab}s{a}{b}${tab}ticket #74"; do
  IFS=$tab read -r label expr proof <<EOF
$bad
EOF
  if check_entry "$label" "$expr" "$proof" "$work/text" >/dev/null; then
    echo "FAIL: the gate accepts the entry '$label'"
    exit 1
  fi
done

mkdir "$work/base"
cp "$here/$runner" "$here/$data_cases" "$work/base/"
cases "$work/base" || { cat "$work/base/out"; echo "FAIL: the data cases fail on the runner as it is"; exit 1; }

failed=0
n=0
while IFS=$tab read -r label expr proof || [ -n "$label" ]; do
  case $label in '' | '#'*) continue ;; esac
  n=$((n + 1))
  check_entry "$label" "$expr" "$proof" "$here/$runner" || { failed=1; continue; }
  run="$work/mutation-$n"
  mkdir "$run"
  cp "$here/$runner" "$here/$data_cases" "$run/"
  perl -0pi -e "$expr" "$run/$runner"
  if cmp -s "$here/$runner" "$run/$runner"; then
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
echo "PASS: all $n runner mutations of $runner killed"
