#!/bin/bash
# Draw reference sheets with the Codex image engine (gpt-6.2-astra on Andrew's Plus login),
# one parallel run per unit folder. Each folder holds a PROMPT.md (from split.py); the run
# writes its PNGs, a REVIEW.md and run.log there, and done.txt holds the exit code.
#
#   tools/refsheets/draw.sh <work dir> <unit> [<unit> ...] [-- <ref image> ...]
#
# Reference images after -- go to every run (approved boards first). Runs at nice 10 on the
# default service tier, which spends far less usage than the configured priority tier.
set -u
if [ "$#" -lt 2 ]; then
  echo "usage: draw.sh <work dir> <unit> [<unit> ...] [-- <ref image> ...]" >&2
  exit 2
fi
work=$1
shift
units=()
while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
  units+=("$1")
  shift
done
refs=()
if [ "$#" -gt 0 ]; then
  shift
  for r in "$@"; do
    refs+=(-i "$(realpath "$r")")
  done
fi
pids=()
for u in "${units[@]}"; do
  if [ ! -f "$work/$u/PROMPT.md" ]; then
    echo "$u: no PROMPT.md in $work/$u" >&2
    exit 2
  fi
  ( cd "$work/$u" && nice -n 10 codex exec --skip-git-repo-check -m gpt-6.2-astra -s workspace-write \
      -c service_tier='"default"' "${refs[@]}" -- "$(cat PROMPT.md)" > run.log 2>&1
    echo "exit $?" > done.txt ) &
  pids+=($!)
done
for p in "${pids[@]}"; do
  wait "$p"
done
for u in "${units[@]}"; do
  echo "$u $(cat "$work/$u/done.txt") images=$(find "$work/$u" -maxdepth 1 -name '*.png' | wc -l)"
done
