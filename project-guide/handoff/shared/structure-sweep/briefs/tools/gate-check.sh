#!/bin/sh
# The checks the coordinator runs in the integration checkout before it pushes
# origin/entropy/gate, as one call with one line of result for each step.
#
# Usage, from the root of the integration checkout (macOS):
#   sh <path>/gate-check.sh <full SHA of the last pushed gate tip> [node]
# "node" skips the Godot run, for a merge that changes no file the game loads.
# Each step's full output goes to artifacts/local/gate-check/<step>.log.
# Safe to rerun: it only overwrites those logs. Exit 1 if any step failed.
# The last line printed is "GATE CHECK: PASS" or "GATE CHECK: FAIL ...": read that line, because a
# caller that pipes the output through tail or cut sees the pipe's exit status, not this script's.
set -u
base="$1"
only="${2:-all}"
case "$base" in
  ????????????????????????????????????????) ;;
  *) echo "pass the full 40-character SHA of the last pushed gate tip"; exit 2 ;;
esac
export PATH="/opt/homebrew/bin:$PATH"
export GODOT_BIN="${GODOT_BIN:-$HOME/Applications/Godot_4.7.2.app/Contents/MacOS/Godot}"
logs="artifacts/local/gate-check"
scratch_home="$PWD/artifacts/local/mac-home"
mkdir -p "$logs" "$scratch_home"
failed=0

step() {
  name="$1"
  shift
  start=$(date +%s)
  if "$@" >"$logs/$name.log" 2>&1; then
    echo "PASS $name $(($(date +%s) - start))s"
  else
    failed=1
    echo "FAIL $name $(($(date +%s) - start))s  ($logs/$name.log)"
    grep -E '^(FAIL|TIMEOUT|CRASH)|✖|^not ok|FAILURE|error:' "$logs/$name.log" | sort -u | head -15 | cut -c1-240
  fi
}

if [ "$only" = all ]; then
  step sketch-fast env HOME="$scratch_home" SMOKE_SLOTS=3 npm run sketch:fast -- --base "$base"
fi
step sketch-lint npm run sketch:lint
step node-tests npm test
step node-shuffle node scripts/ci/node-tests.mjs --shuffle
step lint-js npm run lint:js
step check-docs npm run check:docs
step check-project npm run check:project
step check-skills npm run check:skills
grep -h 'baseline entries' "$logs/sketch-lint.log" | tail -1 | cut -c1-240
if [ "$failed" = 0 ]; then echo "GATE CHECK: PASS"; else echo "GATE CHECK: FAIL (see the FAIL lines above and $logs/)"; fi
exit "$failed"
