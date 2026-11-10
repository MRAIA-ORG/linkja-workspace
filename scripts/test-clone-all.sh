#!/bin/sh
# Check clone-all.sh against GitHub: a fresh clone, then a second run that
# fast-forwards a repo that is behind and skips a repo with local changes.
# Usage: scripts/test-clone-all.sh [empty-dir]   (default: a new temp dir)
set -eu

here=$(cd "$(dirname "$0")" && pwd)
dir=${1:-$(mktemp -d)}
fail() { echo "FAIL: $*"; exit 1; }

echo "== first run into $dir"
"$here/clone-all.sh" "$dir"

while read -r repo; do
  [ -d "$dir/$repo/.git" ] || fail "$repo was not cloned"
done < "$here/repos.txt"
[ "$(git -C "$dir/linkja-core" branch --show-current)" = develop ] || fail "linkja-core is not on develop"
[ "$(git -C "$dir/linkja-docker" branch --show-current)" = master ] || fail "linkja-docker is not on master"

# Put linkja-core one commit behind, and give linkja-hashing a local change.
git -C "$dir/linkja-core" reset --quiet --hard HEAD~1
echo "local work" > "$dir/linkja-hashing/local-change.txt"

echo "== second run"
out=$("$here/clone-all.sh" "$dir") || fail "second run exited non-zero"
echo "$out"

[ "$(git -C "$dir/linkja-core" rev-parse HEAD)" = "$(git -C "$dir/linkja-core" rev-parse origin/develop)" ] \
  || fail "linkja-core was not fast-forwarded"
echo "$out" | grep -q "linkja-hashing: skipped, local changes" || fail "linkja-hashing was not skipped"
[ -f "$dir/linkja-hashing/local-change.txt" ] || fail "local change in linkja-hashing was lost"

echo "PASS"
