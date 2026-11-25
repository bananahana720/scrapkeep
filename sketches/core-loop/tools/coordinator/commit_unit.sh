#!/usr/bin/env bash
set -u
wt="$1" unit="$2" subject="$3" body="$4"
msg="$(mktemp)"
{
  echo "$subject"
  echo
  echo "$body"
  echo "Writer: gpt-6.1-sol high, fast tier (dress push unit $unit); committed by the coordinator."
  echo
  echo "Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
  echo "Claude-Session: https://claude.ai/code/session_01PRLxKDAz1nADH3YEVUStR3"
} > "$msg"
n=0
while IFS= read -r f; do
  git -C "$wt" add -- "$f"
  n=$((n + 1))
done < <(git -C "$wt" status --porcelain -uall | cut -c4- | grep -v -E '\.(uid|import)$' | grep -v '^artifacts/')
if [ "$n" -gt 0 ]; then
  git -C "$wt" commit -q -F "$msg"
  echo "$unit committed $n files at $(git -C "$wt" rev-parse HEAD)"
else
  echo "$unit had nothing to commit"
fi
rm -f "$msg"
