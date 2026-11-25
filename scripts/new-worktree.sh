#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "new-worktree: $*" >&2
  exit 1
}

[ "$#" -eq 2 ] || fail "usage: scripts/new-worktree.sh <task-id> <base-sha>"
task="$1"
base="$2"
[[ "$task" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail "task id must be alphanumeric with . _ - only: $task"
[[ "$base" =~ ^[0-9a-f]{40}$ ]] || fail "base must be a full 40-hex commit SHA, not a branch or short id: $base"

repo="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
target="$(dirname "$repo")/scrapkeep-wt-$task"
branch="wt/$task"

[ ! -e "$target" ] || fail "path already exists, refusing to touch it: $target"
! git -C "$repo" show-ref --verify --quiet "refs/heads/$branch" || fail "branch already exists, refusing to reset it: $branch"
git -C "$repo" cat-file -e "$base^{commit}" 2>/dev/null || fail "commit not found in this repository: $base"

git -C "$repo" worktree add -b "$branch" "$target" "$base" >/dev/null
head="$(git -C "$target" rev-parse HEAD)"
[ "$head" = "$base" ] || fail "HEAD $head differs from base $base in $target"

echo "worktree: $target"
echo "branch: $branch"
echo "head: $head"
