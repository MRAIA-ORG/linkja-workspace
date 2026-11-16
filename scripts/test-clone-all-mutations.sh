#!/bin/sh
# Run test-clone-all.sh on clone-all.sh as it is. Then run it once for each
# mutation in clone-all-mutations.txt. A mutation is caught when the test exits
# nonzero and prints the expected FAIL text. Exits 1 when the first run fails
# or a mutation is not caught.
# Each mutation changes a copy of clone-all.sh. The file in the repo stays as it is.
# Every data line is checked before any run. --check FILE only checks FILE.
# Usage: scripts/test-clone-all-mutations.sh [--check FILE]
set -eu

here=$(cd "$(dirname "$0")" && pwd)
data="$here/clone-all-mutations.txt"

# Prints the number of mutation lines in $1, or one FAIL line and exits 1.
# A line needs exactly 5 tab-separated fields. A blank field (e.g. an expect of
# one space) matches almost every FAIL line, so that check could never fail.
# An expect shorter than min characters (e.g. "e") or with "FAIL:" in it (e.g.
# "FAIL: x") also matches an unrelated FAIL line, so it cannot tie a failure to its mutation.
check_data() {
  awk -v min=10 -F'\t' '
    /^#/ || $0 == "" { next }
    NF != 5 { printf "FAIL: %s line %d has %d fields, want 5 separated by one tab\n", FILENAME, FNR, NF; bad = 1; exit 1 }
    {
      split("label source perl expect proof", name, " ")
      for (i = 1; i <= 5; i++)
        if ($i ~ /^[ \t]*$/) { printf "FAIL: %s line %d: field %d (%s) is blank\n", FILENAME, FNR, i, name[i]; bad = 1; exit 1 }
      if (length($4) < min || index($4, "FAIL:")) { printf "FAIL: %s line %d: field 4 (expect) '\''%s'\'' is too weak: want %d or more characters and no '\''FAIL:'\''\n", FILENAME, FNR, $4, min; bad = 1; exit 1 }
      if ($2 != "mirror" && $2 != "default") { printf "FAIL: %s line %d: unknown source '\''%s'\''\n", FILENAME, FNR, $2; bad = 1; exit 1 }
      n++
    }
    END { if (bad) exit 1; if (!n) { printf "FAIL: no mutations in %s\n", FILENAME; exit 1 }; print n }
  ' "$1"
}

if [ "${1-}" = --check ]; then
  count=$(check_data "$2") || { printf '%s\n' "$count"; exit 1; }
  echo "OK: $count mutation lines"
  exit 0
fi
want=$(check_data "$data") || { printf '%s\n' "$want"; exit 1; }

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
# check_data has checked every line. The "|| [ -n ... ]" reads a last line with no newline.
while IFS=$tab read -r label source expr expect proof || [ -n "$label" ]; do
  case $label in '' | '#'*) continue ;; esac
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
done < "$data"

[ "$n" -eq "$want" ] || { echo "FAIL: ran $n mutations, but clone-all-mutations.txt has $want"; exit 1; }
[ "$failed" -eq 0 ] || exit 1
echo "PASS: all $n mutations caught"
