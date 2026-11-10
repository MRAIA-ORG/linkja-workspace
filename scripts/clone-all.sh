#!/bin/sh
# Clone every MRAIA linkja repo (listed in repos.txt) side by side in one folder.
#
# Usage: scripts/clone-all.sh [parent-dir]
#   parent-dir  folder that gets one subfolder per repo.
#               Default: the folder that holds this workspace repo.
#
# First run: clones each repo and checks out develop where the repo has one.
# Later runs: fetches each repo and fast-forwards its current branch.
# A repo with local changes (staged, unstaged or untracked) is skipped and left as it is.
# Set LINKJA_GIT_BASE to clone from another place, e.g. a fork or a local mirror.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
base=${LINKJA_GIT_BASE:-https://github.com/MRAIA-ORG}
parent=${1:-$(dirname "$(dirname "$here")")}

mkdir -p "$parent"
parent=$(cd "$parent" && pwd)
echo "Parent folder: $parent"

clone() {
  git clone --quiet "$base/$1.git" "$parent/$1"
  if git -C "$parent/$1" show-ref --verify --quiet refs/remotes/origin/develop; then
    git -C "$parent/$1" checkout --quiet develop
  fi
  echo "$1: cloned, on $(git -C "$parent/$1" branch --show-current)"
}

update() {
  if [ -n "$(git -C "$parent/$1" status --porcelain)" ]; then
    echo "$1: skipped, local changes"
    return
  fi
  git -C "$parent/$1" fetch --quiet --prune origin
  branch=$(git -C "$parent/$1" branch --show-current)
  if ! git -C "$parent/$1" rev-parse --quiet --verify '@{upstream}' >/dev/null; then
    echo "$1: fetched only, branch '${branch:-detached HEAD}' has no upstream"
    return
  fi
  # Prints "<commits only on the branch><tab><commits only on the upstream>".
  counts=$(git -C "$parent/$1" rev-list --left-right --count 'HEAD...@{upstream}')
  ahead=${counts%%[[:space:]]*}
  behind=${counts##*[[:space:]]}
  if [ "$ahead" -gt 0 ]; then
    echo "$1: fetched only, $branch has $ahead local commit(s) that are not on its upstream"
  elif [ "$behind" -eq 0 ]; then
    echo "$1: already up to date, on $branch"
  else
    git -C "$parent/$1" merge --quiet --ff-only '@{upstream}'
    echo "$1: fast-forwarded $behind commit(s), on $branch"
  fi
}

# The list is read on fd 3 so that git cannot eat it from stdin.
while read -r repo <&3; do
  if [ -e "$parent/$repo/.git" ]; then
    update "$repo"
  elif [ -e "$parent/$repo" ]; then
    echo "$repo: skipped, $parent/$repo exists and is not a git repo"
  else
    clone "$repo"
  fi
done 3< "$here/repos.txt"
