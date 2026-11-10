#!/bin/sh
# Check clone-all.sh against GitHub: a fresh clone, then a second run that
# fast-forwards a repo that is behind, skips repos with untracked, staged or
# unstaged changes, skips a folder that is not a git repo, and leaves alone a
# repo with a local commit and a repo on a detached HEAD.
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

# Stage a new file in linkja-crypto. Change a tracked file in linkja-docker without staging it.
echo "staged work" > "$dir/linkja-crypto/staged-change.txt"
git -C "$dir/linkja-crypto" add staged-change.txt
tracked=$(git -C "$dir/linkja-docker" ls-files | head -n 1)
echo "unstaged work" >> "$dir/linkja-docker/$tracked"

# Replace linkja-test-data with a folder that is not a git repo.
rm -rf "$dir/linkja-test-data"
mkdir "$dir/linkja-test-data"
echo "not a repo" > "$dir/linkja-test-data/keep.txt"

# Give linkja-salt-engine a commit that is not on the remote.
# Put linkja-matching on a detached HEAD at a local commit, so a reset to any remote ref moves it.
local_commit() {
  git -C "$dir/$1" -c user.name=test -c user.email=test@example.invalid \
    commit --quiet --allow-empty -m "local commit"
}
local_commit linkja-salt-engine
local_commit=$(git -C "$dir/linkja-salt-engine" rev-parse HEAD)
git -C "$dir/linkja-matching" checkout --quiet --detach
local_commit linkja-matching
detached_at=$(git -C "$dir/linkja-matching" rev-parse HEAD)

echo "== second run"
out=$("$here/clone-all.sh" "$dir") || fail "second run exited non-zero"
echo "$out"

[ "$(git -C "$dir/linkja-core" rev-parse HEAD)" = "$(git -C "$dir/linkja-core" rev-parse origin/develop)" ] \
  || fail "linkja-core was not fast-forwarded"
echo "$out" | grep -q "linkja-hashing: skipped, local changes" || fail "linkja-hashing was not skipped"
[ -f "$dir/linkja-hashing/local-change.txt" ] || fail "local change in linkja-hashing was lost"

echo "$out" | grep -q "linkja-crypto: skipped, local changes" || fail "linkja-crypto was not skipped"
git -C "$dir/linkja-crypto" diff --cached --name-only | grep -qx staged-change.txt \
  || fail "staged change in linkja-crypto was lost"
echo "$out" | grep -q "linkja-docker: skipped, local changes" || fail "linkja-docker was not skipped"
git -C "$dir/linkja-docker" diff --name-only | grep -qxF "$tracked" \
  || fail "unstaged change in linkja-docker was lost"

echo "$out" | grep -q "linkja-test-data: skipped, .* is not a git repo" || fail "linkja-test-data was not skipped"
[ -f "$dir/linkja-test-data/keep.txt" ] || fail "file in the non-git linkja-test-data folder was lost"
[ ! -e "$dir/linkja-test-data/.git" ] || fail "linkja-test-data was cloned over the existing folder"

[ "$(git -C "$dir/linkja-salt-engine" rev-parse HEAD)" = "$local_commit" ] \
  || fail "local commit in linkja-salt-engine was lost"
[ -z "$(git -C "$dir/linkja-matching" branch --show-current)" ] || fail "linkja-matching is no longer detached"
[ "$(git -C "$dir/linkja-matching" rev-parse HEAD)" = "$detached_at" ] || fail "linkja-matching HEAD moved"

echo "PASS"
