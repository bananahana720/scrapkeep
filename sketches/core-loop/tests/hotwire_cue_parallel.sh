#!/bin/bash
# Eight copies of the cue test at once, the machine load that made it flake. Exits non-zero if any fails.
G="${GODOT:-$(node "$(dirname "$0")/../../../scripts/godot-home.mjs" --bin)}"
[ -n "$G" ] || { echo "hotwire_cue_parallel: no Godot found; set GODOT or GODOT_BIN" >&2; exit 2; }
LOGS=${LOGS:-/tmp/claude-1000}
cd "$(dirname "$0")/.."
pids=()
for i in 1 2 3 4 5 6 7 8; do
  "$G" --headless --path . --script res://tests/hotwire_cue_test.gd > "$LOGS/hwc-$i.log" 2>&1 &
  pids+=($!)
done
fail=0
failed=0
for p in "${pids[@]}"; do
  if wait "$p"; then
    :
  else
    fail=1
    failed=$((failed + 1))
  fi
done
echo "failed $failed of 8"
exit $fail
