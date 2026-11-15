#!/bin/sh
# Check clone-all.sh against mirrors of the GitHub repos: a fresh clone that
# puts every repo with develop on develop and the others on their default
# branch, then a second run that fast-forwards a repo that is behind, skips
# repos with untracked, staged or unstaged changes, skips a folder that is not
# a git repo, and leaves alone a repo that is ahead and behind and a repo on a
# detached HEAD.
# Usage: scripts/test-clone-all.sh [empty-dir]
#   Default: a new temp dir, deleted on exit. A dir you give is kept.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
if [ $# -gt 0 ]; then
  dir=$1
else
  dir=$(mktemp -d)
  trap 'rm -rf "$dir"' EXIT
  trap 'exit 1' INT TERM
fi
fail() { echo "FAIL: $*"; exit 1; }

# On GitHub, develop is the default branch of every repo that has it, so a plain
# clone is on develop anyway. The mirrors point HEAD at another branch, so the
# test sees whether clone-all.sh checks out develop itself.
src=${LINKJA_GIT_BASE:-https://github.com/MRAIA-ORG}
echo "== mirroring the repos from $src into $dir/mirrors"
while read -r repo; do
  mirror="$dir/mirrors/$repo.git"
  git clone --quiet --mirror "$src/$repo.git" "$mirror"
  if git -C "$mirror" show-ref --verify --quiet refs/heads/develop; then
    other=$(git -C "$mirror" for-each-ref --format='%(refname)' refs/heads | grep -vx refs/heads/develop | head -n 1)
    git -C "$mirror" symbolic-ref HEAD "$other"
  fi
done < "$here/repos.txt"
LINKJA_GIT_BASE="$dir/mirrors"
export LINKJA_GIT_BASE

echo "== first run into $dir"
"$here/clone-all.sh" "$dir"

while read -r repo; do
  [ -d "$dir/$repo/.git" ] || fail "$repo was not cloned"
  if git -C "$dir/$repo" show-ref --verify --quiet refs/remotes/origin/develop; then
    want=develop
  else
    want=$(git -C "$dir/$repo" symbolic-ref --short refs/remotes/origin/HEAD)
    want=${want#origin/}
  fi
  [ "$(git -C "$dir/$repo" branch --show-current)" = "$want" ] || fail "$repo is not on $want"
done < "$here/repos.txt"

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

# Put linkja-salt-engine one commit behind and give it a commit that is not on the remote.
# Put linkja-matching on a detached HEAD at a local commit, so a reset to any remote ref moves it.
local_commit() {
  git -C "$dir/$1" -c user.name=test -c user.email=test@example.invalid \
    commit --quiet --allow-empty -m "local commit"
}
git -C "$dir/linkja-salt-engine" reset --quiet --hard HEAD~1
local_commit linkja-salt-engine
salt_branch=$(git -C "$dir/linkja-salt-engine" branch --show-current)
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

while read -r repo; do
  echo "$out" | grep -q "^$repo: " || fail "second run did not reach $repo"
done < "$here/repos.txt"

echo "$out" | grep -q "linkja-salt-engine: fetched only, .* local commit" \
  || fail "linkja-salt-engine was not left alone"
[ "$(git -C "$dir/linkja-salt-engine" branch --show-current)" = "$salt_branch" ] \
  || fail "linkja-salt-engine left $salt_branch"
[ "$(git -C "$dir/linkja-salt-engine" rev-parse HEAD)" = "$local_commit" ] \
  || fail "local commit in linkja-salt-engine was lost"
[ -z "$(git -C "$dir/linkja-matching" branch --show-current)" ] || fail "linkja-matching is no longer detached"
[ "$(git -C "$dir/linkja-matching" rev-parse HEAD)" = "$detached_at" ] || fail "linkja-matching HEAD moved"

echo "PASS"
