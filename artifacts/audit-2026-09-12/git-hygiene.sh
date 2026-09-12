#!/usr/bin/env bash
# Rerunnable git-hygiene snapshot for the Scrapkeep audit.
cd "${1:-/home/andrew/Projects/scrapkeep}" || exit 1
echo "== main vs origin/main"; git fetch -q origin 2>/dev/null; git rev-list --left-right --count main...origin/main
echo "== branches merged into main"; git branch --merged main | grep -v '^\*'
echo "== branches NOT merged into main"; git branch --no-merged main
echo "== worktrees with uncommitted changes"
git worktree list --porcelain | awk '/^worktree /{print $2}' | while read -r w; do n=$(git -C "$w" status --porcelain 2>/dev/null | wc -l); [ "$n" -gt 0 ] && echo "$w: $n changed paths"; done
echo "== per-branch commits ahead of main"
for b in $(git branch --no-merged main | tr -d ' +'); do echo "$b: $(git rev-list --count main..$b) ahead, $(git rev-list --count $b..main) behind"; done
echo "== tracked weight by top dir (MB)"
git ls-files -z | xargs -0 du -k 2>/dev/null | awk '{split($2,p,"/"); w[p[1]]+=$1} END{for(k in w) printf "%6d %s\n", w[k]/1024, k}' | sort -rn | head -6
echo "== worktree disk"; du -sh .claude/worktrees /home/andrew/Projects/scrapkeep-wt-* 2>/dev/null
