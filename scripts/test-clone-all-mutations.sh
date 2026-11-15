#!/bin/sh
# Run test-clone-all.sh on clone-all.sh as it is. Then run it once for each
# mutation in clone-all-mutations.txt. A mutation is caught when the test exits
# nonzero and prints the expected FAIL text. Exits 1 when the first run fails
# or a mutation is not caught.
# Each mutation changes a copy of clone-all.sh. The file in the repo stays as it is.
# Usage: scripts/test-clone-all-mutations.sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
trap 'exit 1' INT TERM
# A missing repo at a wrong address must fail, and must not ask for a password.
GIT_TERMINAL_PROMPT=0
export GIT_TERMINAL_PROMPT
unset LINKJA_GIT_BASE

# This is the only run that downloads the repos from the default address.
# The test keeps its mirrors in the folder that we give it.
echo "== test-clone-all.sh on clone-all.sh as it is"
"$here/test-clone-all.sh" "$work/first" || { echo "FAIL: the test fails on clone-all.sh as it is"; exit 1; }
copies="$work/first/mirrors"
[ -d "$copies" ] || { echo "FAIL: no mirrors at $copies, so the mutations cannot use local copies"; exit 1; }

# Some mutations ignore LINKJA_GIT_BASE and clone from the default address.
# Send that address to the local copies, so these runs do not download the repos again.
GIT_CONFIG_COUNT=1
GIT_CONFIG_KEY_0="url.$copies/.insteadOf"
GIT_CONFIG_VALUE_0="$(sed -n 's/^base=.*:-\(.*\)}$/\1/p' "$here/clone-all.sh")/"
export GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0
[ "$GIT_CONFIG_VALUE_0" != / ] || { echo "FAIL: cannot read the default address from clone-all.sh"; exit 1; }
# Gap: nothing proves that git uses this redirect. Without it, the runs still pass, only slower.

tab=$(printf '\t')
failed=0
n=0
while IFS=$tab read -r label source expr expect proof; do
  case $label in '' | '#'*) continue ;; esac
  # A tab read collapses an empty field, so a missing field leaves the last one empty.
  # An empty expect matches every FAIL line, so that check could never fail.
  if [ -z "$source" ] || [ -z "$expr" ] || [ -z "$expect" ] || [ -z "$proof" ]; then
    echo "FAIL: '$label' has an empty field. Each line needs 5 fields, separated by one tab." && exit 1
  fi
  case $source in mirror | default) ;; *) echo "FAIL: '$label' has the unknown source '$source'" && exit 1 ;; esac
  n=$((n + 1))
  run="$work/mutation-$n"
  mkdir "$run"
  cp "$here/clone-all.sh" "$here/test-clone-all.sh" "$here/repos.txt" "$run/"
  perl -0pi -e "$expr" "$run/clone-all.sh"
  if cmp -s "$here/clone-all.sh" "$run/clone-all.sh"; then
    echo "FAIL: '$label' ($proof) changes nothing in clone-all.sh"
    failed=1
    continue
  fi
  case $source in
    mirror) LINKJA_GIT_BASE=$copies && export LINKJA_GIT_BASE ;;
    default) unset LINKJA_GIT_BASE ;;
  esac
  echo "== mutation $n: $label"
  status=0
  out=$("$run/test-clone-all.sh" 2>&1 </dev/null) || status=$?
  if [ "$status" -ne 0 ] && printf '%s\n' "$out" | grep '^FAIL: ' | grep -qF "$expect"; then
    echo "caught: $expect"
  else
    printf '%s\n' "$out" | tail -n 5
    echo "FAIL: '$label' ($proof) not caught. Want a nonzero exit and '$expect'. Got exit $status."
    failed=1
  fi
done < "$here/clone-all-mutations.txt"

[ "$n" -gt 0 ] || { echo "FAIL: no mutations in clone-all-mutations.txt"; exit 1; }
[ "$failed" -eq 0 ] || exit 1
echo "PASS: all $n mutations caught"
