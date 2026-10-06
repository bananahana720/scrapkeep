#!/usr/bin/env bash
# Keep up to MAX writers busy from a queue file, so the coordinator reviews in batches.
# Usage: sol_queue.sh <queue.tsv> [max]
# Each queue line: role<TAB>wave<TAB>unit<TAB>cwd<TAB>brief
# A writer counts as active while its receipt folder has `started` and no `finished`,
# so units launched outside this queue count too. Prints one line per finished unit.

set -u
queue="$1"
max="${2:-8}"
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../../../.." && pwd)"
push="$repo/artifacts/local/alpha/push"

active_writers() {
  local n=0 d
  for d in "$push"/*/*/write; do
    if [ -f "$d/started" ] && [ ! -f "$d/finished" ]; then
      n=$((n + 1))
    fi
  done
  echo "$n"
}

pids=()
while IFS=$'\t' read -r role wave unit cwd brief; do
  if [ -z "$role" ] || [ "${role:0:1}" = "#" ]; then
    continue
  fi
  if [ "$role" = "write" ]; then
    while [ "$(active_writers)" -ge "$max" ]; do
      sleep 20
    done
  fi
  "$here/sol_dispatch.sh" --role "$role" --wave "$wave" --unit "$unit" --cwd "$cwd" --brief "$brief" \
    --add-dir "$HOME/.local/share/godot" > /dev/null 2>&1 &
  pids+=("$!")
  echo "launched $role $unit $(date -u +%H:%M:%S)"
  # Give the receipt folder time to appear before the next count.
  sleep 5
done < "$queue"

for p in "${pids[@]}"; do
  wait "$p"
done
for line in $(grep -v '^#' "$queue" | awk -F'\t' '{print $2"/"$3"/"$1}'); do
  if [ -f "$push/$line/exit" ]; then
    echo "done $line exit $(cat "$push/$line/exit")"
  fi
done
