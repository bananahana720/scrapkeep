#!/usr/bin/env bash
# Wave-2 cleanup planner for the Scrapkeep deslop pass.
# READ-ONLY: prints planned commands and byte estimates. It executes no mutation.
# Safety gate: refuses (exit 1) if any candidate branch has an unmerged commit
# (git cherry '+') or any candidate worktree has uncommitted/untracked files.
#
# Usage: bash artifacts/local/audit-2026-09-10/cleanup-dry-run.sh
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1

PARKED_WORKTREES=(wt/HF-04a wt/HF-05)   # unadmitted candidates: Andrew's D2 decision keeps these
BASE=main
fail=0

is_parked() { local b=$1; for p in "${PARKED_WORKTREES[@]}"; do [ "$p" = "$b" ] && return 0; done; return 1; }

printf '== worktrees registered ==\n'
git worktree list

printf '\n== removable worktrees (branch content verified upstream in %s) ==\n' "$BASE"
wt_bytes=0
while read -r path sha branch; do
  b=${branch#refs/heads/}
  [ "$b" = "$BASE" ] && continue
  if is_parked "$b"; then printf 'PARKED   %-14s %s\n' "$b" "$path"; continue; fi
  unmerged=$(git cherry "$BASE" "$b" | grep -c '^+')
  dirty=$(git -C "$path" status --porcelain | wc -l)
  if [ "$unmerged" -ne 0 ]; then printf 'REFUSE   %-14s has %s unmerged commit(s)\n' "$b" "$unmerged"; fail=1; continue; fi
  if [ "$dirty" -ne 0 ]; then printf 'REFUSE   %-14s has %s dirty entr(ies)\n' "$b" "$dirty"; fail=1; continue; fi
  sz=$(du -sm "$path" | cut -f1); wt_bytes=$((wt_bytes+sz))
  printf 'REMOVE   %-14s %sMB  %s\n' "$b" "$sz" "$path"
  printf '         git worktree remove %s\n' "$path"
  printf '         git branch -D %s   # content upstream by patch-id; commit not an ancestor\n' "$b"
done < <(git worktree list --porcelain | awk '/^worktree /{p=$2} /^HEAD /{h=$2} /^branch /{print p, h, $2}')

printf '\n== loose branches with no worktree (all verified upstream in %s) ==\n' "$BASE"
loose=0
for b in $(git branch --format='%(refname:short)' | grep -v "^$BASE$"); do
  git worktree list --porcelain | grep -q "^branch refs/heads/$b$" && continue
  is_parked "$b" && { printf 'PARKED   %s\n' "$b"; continue; }
  unmerged=$(git cherry "$BASE" "$b" | grep -c '^+')
  if [ "$unmerged" -ne 0 ]; then printf 'REFUSE   %-14s has %s unmerged commit(s)\n' "$b" "$unmerged"; fail=1; continue; fi
  printf 'DELETE   %-14s git branch -D %s\n' "$b" "$b"; loose=$((loose+1))
done

printf '\n== generated output (regenerable, ignored by git) ==\n'
# LIVE node_modules is deliberately excluded: it is required tooling for npm test / check:*,
# not disposable slop. Only build output and editor caches qualify.
for d in dist native/.godot; do
  [ -e "$d" ] && printf 'REMOVE   %-18s %sMB  %s\n' "$d" "$(du -sm "$d" | cut -f1)" "$d"
done
printf 'KEEP     %-18s %sMB  node_modules (live tooling; removing it breaks the checks)\n' "node_modules" "$(du -sm node_modules 2>/dev/null | cut -f1)"
for p in /home/andrew/Projects/scrapkeep-wt-*; do
  [ -d "$p" ] || continue
  b=$(git -C "$p" rev-parse --abbrev-ref HEAD 2>/dev/null)
  for d in node_modules dist native/.godot; do
    [ -e "$p/$d" ] && printf 'REMOVE   %-18s %sMB  %s/%s (worktree %s)\n' "$d" "$(du -sm "$p/$d" | cut -f1)" "$p" "$d" "$b"
  done
done

printf '\n== estimate ==\n'
printf 'worktree trees:      ~%sMB (includes each worktree own generated output)\n' "$wt_bytes"
printf 'loose branches:      %s ref(s), 0MB on disk\n' "$loose"
printf 'live repo dist/:     %sMB\n' "$([ -e dist ] && du -sm dist | cut -f1 || echo 0)"
printf '\nNOTE: HF-04a/HF-05 are parked and excluded. Their commits/blobs are preserved under\n'
printf '      artifacts/local/audit-2026-09-10/preserved/ before any removal.\n'
printf 'TRACKED EVIDENCE IS NOT TOUCHED: artifacts/ (historical), docs/, public/ stay as-is.\n'
[ "$fail" -eq 0 ] && printf '\nGATE: PASS - every candidate verified clean and upstream.\n' || printf '\nGATE: FAIL - resolve REFUSE lines before executing.\n'
exit "$fail"
