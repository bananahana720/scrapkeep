#!/bin/sh
# The checks the coordinator runs in the integration checkout before it pushes
# origin/entropy/gate, as one call with one line of result for each step.
#
# Usage, from the root of the integration checkout (macOS):
#   sh <path>/gate-check.sh <full SHA of the last pushed gate tip> [node]
# "node" skips the Godot run, for a merge that changes no file the game loads.
# "reds" runs nothing and only reads the last Godot run's log for old reds (below).
#
# The Godot run calls a test "base-red" when it is also red on the commit it was compared with.
# That commit is the previous gate tip, so a red this sweep let in once would count as old for
# ever. An old red is one that is red on main: this script fails on any base-red test that has no
# row of kind "red" in the checked-out project-guide/handoff/KNOWN-FAILING.tsv whose cause starts
# "red on main at ". That ledger is the one home of the list; a row is added only after a run on main.
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
ledger="project-guide/handoff/KNOWN-FAILING.tsv"
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

old_reds() {
  [ -r "$ledger" ] || { echo "cannot read $ledger"; return 1; }
  [ -s "$logs/sketch-fast.log" ] || { echo "no Godot run log at $logs/sketch-fast.log"; return 1; }
  bad=0
  for t in $(sed -n 's/.*base-red (red on the merge base too; not this PR): //p' "$logs/sketch-fast.log" | tr ',' ' '); do
    red=$(basename "$t" .gd)
    if ! awk -F'\t' '$2=="red" && $3 ~ /^red on main at /{print $1}' "$ledger" | grep -qx "$red"; then
      bad=1
      echo "$red is red here and on the previous gate tip, and has no red-on-main row in $ledger: run it on main; red there, add its row through a unit; green there, this sweep broke it"
    fi
  done
  return "$bad"
}

if [ "$only" = reds ]; then
  if old_reds; then echo "GATE CHECK: PASS (old reds only)"; exit 0; else echo "GATE CHECK: FAIL (a red that is not old)"; exit 1; fi
fi
if [ "$only" = all ]; then
  step sketch-fast env HOME="$scratch_home" SMOKE_SLOTS=3 npm run sketch:fast -- --base "$base"
  step old-reds old_reds
  cat "$logs/old-reds.log" | cut -c1-240
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
